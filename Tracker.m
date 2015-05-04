classdef Tracker < handle
    properties
        m_seqObj
        m_startFrm 
        m_funcH
        m_bbId
        m_pos
        
        m_numFrm %the number of frames to tackle
        m_tmpSZ
        m_numObj
        m_param
        m_opt
%         m_tmpl
%         m_tmplOrigin
%         m_template
    end
    
    methods
        function obj = Tracker(seqObj, hFcn, bbId, curPos, isMultiTrack, numFrm)
            obj.m_seqObj = seqObj;
            obj.m_startFrm = seqObj.m_curFrm;
            obj.m_funcH = hFcn;
            obj.m_bbId = bbId;
            obj.m_pos = curPos;
            
            obj.m_numFrm = numFrm;
            obj.m_tmpSZ = 32;
            if isMultiTrack
                obj.m_numObj = obj.m_seqObj.bbObjNumInCurFrm();
            else
                 obj.m_numObj = 1;
            end
            obj.m_opt = struct('numsample', 600, 'condenssig',1, 'posNum',1, 'negNum',30, ...
        'tmplsize', [32,32], 'batchsize',15,'projNum',10, 'num_tmpl',5, 'r',1.5, 'posSig',[2,2,.01,.02,.002,.001]);
            obj.m_opt.affsig = [5,5,.01,0, 0, 0]; 

        end
        
         %general method
        function param = genParam(obj, pos)
            if isempty(pos)
                return;
            end
            [centerX, centerY, width, height] = obj.getPosInfo(pos);
            angle = 0;
            skewRatio = 0;
            param = [centerX, centerY, width/obj.m_tmpSZ, angle,height/width, skewRatio];%param0,中心x，中心y，宽/32，旋转角度、高/宽，skew ratio
            param = affparam2mat(param);
        end
        
        function pSmplsInfo = getPSmplsInfo(obj)
            if obj.m_numObj > 1
                frmObj = obj.m_seqObj.getCurFrmObj();

                bbobjSet = values(frmObj.m_bbMap);
                numObj = length(bbobjSet);

                id = zeros(numObj);
                param = cell(numObj,1);
                pSmplsInfo.id = id;
                pSmplsInfo.param = param;
                for i = 1:numObj
                    bbObj = bbobjSet{i};
                    pSmplsInfo.id(i) = bbObj.getObjId();
                    pSmplsInfo.param{i} = obj.genParam(bbObj.getPos());
                end 
            else
                pSmplsInfo.id(1) = obj.m_bbId;
                pSmplsInfo.param{1} = obj.genParam(obj.m_pos);
            end
        end

        function [centerX, centerY, width, height] = getPosInfo(obj, pos) 
            centerX = pos(1) + pos(3)/2;
            centerY = pos(2) + pos(4)/2;
            width = pos(3);
            height = pos(4);
        end
        
        function runTracker(obj)    
            img = obj.m_seqObj.getImg(obj.m_startFrm);
            imgI = rgb2gray(img);
            imgI =  double(imgI)/256;
            numP = obj.m_numObj;
            opt = obj.m_opt;
            
            pSmplsInfo = obj.getPSmplsInfo();
       
            %Init space
            curTmpl.mean = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);%32, 32, 5;num_tmpl是5？根据，模版大小生成全零矩阵，并且一共有5个
            curTmpl.template = zeros(opt.projNum, opt.num_tmpl);%projNum=10, 5
            curTmpl.W = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.projNum, opt.num_tmpl);%32*32, 10, 5
            curTmpl.sigma = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.num_tmpl);%32*32, 5
            curTmpl.mean_pos = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);
            curTmpl = repmat(curTmpl,numP,1);
           
            tmplOrigin = cell(numP,1);
            for i = 1:numP
                [positiveSample, ~] = SelectPos(imgI, pSmplsInfo.param{i}, opt);%对第一帧操作，[正样本， 正样本位置]
                [negSample, ~] = SelectNeg(imgI, pSmplsInfo.param{i}, opt);%选取负样本
                tmpl = PLS_sub(positiveSample, negSample, opt);%正负样本,PLS子空间   
                %assignment
                curTmpl(i).mean(:,:,1) = tmpl.mean;
                curTmpl(i).mean_pos(:,:,1) = positiveSample;
                curTmpl(i).template(:,1) = tmpl.template;
                curTmpl(i).W(:,:,1) = tmpl.W;
                curTmpl(i).sigma(:,1) = tmpl.sigma;   
                tmplOrigin{i} = tmpl;
            end       
            
            params = cell(numP,1);
            for i = 1:numP
            params{i}.est = pSmplsInfo.param{i}';
            end
            f = 0.9;
            
            for frmIndex = obj.m_startFrm+1 : obj.m_startFrm+obj.m_numFrm
                %read new img
                img = obj.m_seqObj.getImg(frmIndex); 
                imgI = rgb2gray(img); 
                imgI =  double(imgI)/256;
                for i = 1:numP
%                     param = [];
%                     param.est = pSmplsInfo.param{i}';
                    params{i} = est_condens_PLS_Multi(imgI, curTmpl(i), params{i}, opt);% first stage
                    tmp = estwarp_condens_PLS(imgI, tmplOrigin{i}, params{i}, opt);   % second stage
                    params{i}.est = tmp.est;
                    params{i}.wimg = tmp.wimg;

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% update %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   

                    tmp = curTmpl(i).template;
                    tmp(:,sum(abs(curTmpl(i).template),1)==0) = [];

                    num_tmpl = size(tmp,2);
                    min_tmplate = curTmpl(i).template(:,params{i}.mini_t_idx);

                    if params{i}.mini_t_dis < sum(min_tmplate.^2)/5          

                        curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx) = curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx)*f + (1-f)*params{i}.wimg;

                        [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                        tmp_t = PLS_sub(curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx), negSample, opt);

                        curTmpl(i).mean(:,:,params{i}.mini_t_idx) = tmp_t.mean;
                        curTmpl(i).template(:,params{i}.mini_t_idx) = tmp_t.template;
                        curTmpl(i).W(:,:,params{i}.mini_t_idx) = tmp_t.W;
                        curTmpl(i).sigma(:,params{i}.mini_t_idx) = tmp_t.sigma;
                    else  %add a new subspace and remove the subspace with largest reconstruction error
                        if num_tmpl < opt.num_tmpl % if the number of subspace is less than the setting
                            curTmpl(i).mean_pos(:,:,num_tmpl+1) = params{i}.wimg;
                            [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                            tmp_t = PLS_sub(params{i}.wimg, negSample, opt);
                            curTmpl(i).mean(:,:,num_tmpl+1) = tmp_t.mean;
                            curTmpl(i).template(:,num_tmpl+1) = tmp_t.template;
                            curTmpl(i).W(:,:,num_tmpl+1) = tmp_t.W;
                            curTmpl(i).sigma(:,num_tmpl+1) = tmp_t.sigma;
                        else            
                            if params{i}.max_t_idx ~= 1  
                                curTmpl(i).mean_pos(:,:,params{i}.max_t_idx) = params{i}.wimg;
                                [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                                tmp_t = PLS_sub(params{i}.wimg, negSample, opt);
                                curTmpl(i).mean(:,:,params{i}.max_t_idx) = tmp_t.mean;
                                curTmpl(i).template(:,params{i}.max_t_idx) = tmp_t.template;
                                curTmpl(i).W(:,:,params{i}.max_t_idx) = tmp_t.W;
                                curTmpl(i).sigma(:,params{i}.max_t_idx) = tmp_t.sigma;
                            end
                        end       
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% show the result %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    %                 paramRes = [paramRes param.est]; 
                    pos =  obj.getPosFromParam(opt.tmplsize, params{i}.est);   
                    obj.m_seqObj.addBBToAFrm(obj.m_funcH, frmIndex, pSmplsInfo.id(i), pos, 0);
                end
                obj.m_seqObj.seqPlay(frmIndex - 1,frmIndex);
            end
        end
        
        function [negSample, p] = SelectNeg0(I, param, opt)
            tmplSz = opt.tmplsize;
            numN = opt.negNum;
            numP = opt.posNum;
            r = opt.r;
            negSample = zeros(tmplSz(1), tmplSz(2), numN, numP);%4D array
            p = zeros(6, numN, numP);

            for i = 1:numP
                paramP = param{i}; 
                geoParamP = affparam2geom(param{i});
                x = geoParamP(1);
                y = geoParamP(2);
                width = geoParamP(3)*tmplSz(2); 

                height = width*geoParamP(5);

                [nrows, ncols] = size(I);

                inner = sqrt(width^2+height^2)/2+sqrt(tmplSz(1)^2+tmplSz(2)^2)/2;
                out = r*inner;
                count=0;
                while (1)
                    p_amplitude = inner+(out-inner)*rand(1);
                    p_angle = 2*pi*rand(1);
                    xx = p_amplitude*cos(p_angle);
                    xx = round(xx)+x; 
                    yy = p_amplitude*sin(p_angle);
                    yy = round(yy)+y;

                    left = round(xx - width/2);
                    right = round(xx + width/2);
                    top = round(yy - height/2);
                    bottom = round(yy + height/2);
                    if left>0 && right<ncols && top>0 && bottom<nrows
                        count = count+1;
                        paramN = paramP;
                        paramN(1:2) = [xx yy];
                        negSample(:, :, count, i) = warpimg(I, paramN, tmplSz);

                        p(:, count, i) = paramN; 
                    end
                    if count == numN
                        break;
                    end
                end
            end
        end
        
        function [posSample, p] = SelectPos0(I, param, opt)
            tmplsize = opt.tmplsize;
            posNum = opt.posNum;
            posSample = zeros(tmplsize(1), tmplsize(2), posNum);
            p = zeros(6, posNum);
            for i = 1:posNum
                posSample(:,:,i) = warpimg(I, param{i}, tmplsize);%get the sample region img patch
            end
        end
        
        function tmpl = PLS_sub0(posSample, negSample, opt)

            [nrows,ncols,numP] = size(posSample);%numP indicates the total number of positives
            numN = size(negSample, 3);%numN indicates the number of negatives that belongs to a positive
            numSmp = 1 + numN;%for one positive,numSmp = positive(one sample) +its negatives
            numPix = nrows*ncols;

            % samples,one positive sample follows numN negative
            %Init space


            tmpl.mean = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);%32, 32, 5;
            tmpl.mean_pos = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);%32, 32, 5
            tmpl.template = zeros(opt.projNum, opt.num_tmpl);%projNum=10, 5
            tmpl.W = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.projNum, opt.num_tmpl);%32*32, 10, 5
            tmpl.sigma = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.num_tmpl);%32*32, 5

            tmpl = repmat(tmpl, numP, 1);

            for i = 1:numP
                temp = reshape(posSample(:,:,i),[numPix,1]);% Reshape array.one column one sample.reshape the intensity matrix into one column
                smpData(1,:) = temp';%transpose,so one row one sample.
                temp = reshape(negSample(:,:,:,i),[numPix,numN]);%one column one sample
                smpData(2:numN + 1,:) = temp';
                % label
                smpLable = zeros(numSmp,1);    
                smpLable(1) = 1;

                [smpData,~,sigmaX] = zscore(smpData);
                [smpLable,~,sigmaY] = zscore(smpLable);
                % centering the training data
                muX = mean(smpData);%相同位置的像素为一个特征，所以一共有32*32个attribute？求各个特征的均值;calculate the mean of each cloumn
                muY = mean(smpLable,1);
                smpData = smpData -  ones(numSmp,1)*muX;
                smpLable = smpLable - ones(numSmp,1)*muY;


                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                [XL,YL,XS,YS,beta,PCTVAR,MSE,stats]  = plsregress(smpData, smpLable,opt.projNum); % SIMPLS
                tmpl(i).W = stats.W;          
                tmpl(i).mean =  reshape(muX', nrows, ncols);%make the sample pixels-wise intensity mean from row vector back to a intensity matrix 
                tmpl(i).sigma = sigmaX';
                %mean of the positive samples
                tmpl(i).template = tmpl.W'*smpData(1,:)'; 
            end
        end
        
        function pos = getPosFromParam(obj, tmplsize, param)
            w = tmplsize(1);
            param = affparam2geom(param);
            cenX = param(1);
            cenY = param(2);
            gScale = param(3);
            aspectRatio = param(5);
            
            w = w*gScale;
            h = w*aspectRatio;
    
            tlX = cenX - w/2;
            tlY = cenY - h/2;
            pos = [tlX, tlY, w, h];
        end
    
    end
    
end