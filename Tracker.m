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

        m_tmplOrigins
        m_tmplSets
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
            
            obj.m_opt = struct('numsample', 50, 'condenssig',1, 'posNum',1, 'negNum',30, ...
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
            curTmpl.mean = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);
            curTmpl.template = zeros(opt.projNum, opt.num_tmpl);%projNum=10, 5
            curTmpl.W = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.projNum, opt.num_tmpl);%32*32, 10, 5
            curTmpl.sigma = zeros(opt.tmplsize(1)*opt.tmplsize(2), opt.num_tmpl);%32*32, 5
            curTmpl.mean_pos = zeros(opt.tmplsize(1), opt.tmplsize(2), opt.num_tmpl);
            curTmpl = repmat(curTmpl,numP,1);
           
            tmplOrigin = cell(numP,1);
            %first frame
            for i = 1:numP
                [positiveSample, ~] = SelectPos(imgI, pSmplsInfo.param{i}, opt);
                [negSample, ~] = SelectNeg(imgI, pSmplsInfo.param{i}, opt);
                tmpl = PLS_sub(positiveSample, negSample, opt);%object representation model
                %assignment，：，1）表示model set中的第一个元素，就是gt
                curTmpl(i).mean(:,:,1) = tmpl.mean;
                curTmpl(i).mean_pos(:,:,1) = positiveSample;%32*32intensity matrix
                curTmpl(i).template(:,1) = tmpl.template;%reshape the intensity matrix in to a row,then use the PLS weigth(cloumn vector) times the row,an get a matrix
                curTmpl(i).W(:,:,1) = tmpl.W;
                curTmpl(i).sigma(:,1) = tmpl.sigma;   
                tmplOrigin{i} = tmpl;
            end       
            
            params = cell(numP,1);
            for i = 1:numP
            params{i}.est = pSmplsInfo.param{i}';
            end
            f = 0.3;
            playFlag = 0;
            %other frames
            for frmIndex = obj.m_startFrm+1 : obj.m_startFrm+obj.m_numFrm
                %read new img
                img = obj.m_seqObj.getImg(frmIndex); 
                imgI = rgb2gray(img); 
                imgI =  double(imgI)/256;
                stopIdArray = zeros(obj.m_numObj);
                %for each obj
                for i = 1:numP
                    if stopIdArray(i) == 1 
                        continue;
                    end
                    %track obj
                    params{i} = est_condens_PLS_Multi(imgI, curTmpl(i), params{i}, opt);% first stage
                    tmp = estwarp_condens_PLS(imgI, tmplOrigin{i}, params{i}, opt);   % second stage
                    %already get the result
                    params{i}.est = tmp.est;
                    params{i}.wimg = tmp.wimg;

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% update %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   

                    tmp = curTmpl(i).template;%10 x 5；curTmpl是model set，curTmpl(i),是指，第i个物体gt对应的model set（因为改成多目标跟踪，而每个目标都会各自维护一个model set，以及对应ground truth）
                    tmp(:,sum(abs(curTmpl(i).template),1)==0) = [];%10 x 1     sum为零的那些列会被删除，abs的sum为零就是6个元素都为零，就是要删除那些没用的model？

                    num_tmpl = size(tmp,2);
                    min_tmplate = curTmpl(i).template(:,params{i}.mini_t_idx);

                    if params{i}.mini_t_dis < sum(min_tmplate.^2)/5        %less than threshold,update the coresponding model          
                         %使用遗忘因子更新模型
                        curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx) = curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx)*f + (1-f)*params{i}.wimg;
                        %每次都要重新选择negative
                        [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                        tmp_t = PLS_sub(curTmpl(i).mean_pos(:,:,params{i}.mini_t_idx), negSample, opt);

                        curTmpl(i).mean(:,:,params{i}.mini_t_idx) = tmp_t.mean;
                        curTmpl(i).template(:,params{i}.mini_t_idx) = tmp_t.template;
                        curTmpl(i).W(:,:,params{i}.mini_t_idx) = tmp_t.W;
                        curTmpl(i).sigma(:,params{i}.mini_t_idx) = tmp_t.sigma;
                    else %只维护一个要5个model的model set
                        if params{i}.mini_t_dis < 0.790
                            if num_tmpl < opt.num_tmpl % if the number of subspace is less than the setting, add a new subspace 
                                curTmpl(i).mean_pos(:,:,num_tmpl+1) = params{i}.wimg;
                                [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                                tmp_t = PLS_sub(params{i}.wimg, negSample, opt);
                                curTmpl(i).mean(:,:,num_tmpl+1) = tmp_t.mean;
                                curTmpl(i).template(:,num_tmpl+1) = tmp_t.template;
                                curTmpl(i).W(:,:,num_tmpl+1) = tmp_t.W;
                                curTmpl(i).sigma(:,num_tmpl+1) = tmp_t.sigma;
                            else  %add a new subspace and remove the subspace with largest reconstruction error           
                                if params{i}.max_t_idx ~= 1  %被替换掉的model的不能是第一个，因为第一个是ground truth
                                    curTmpl(i).mean_pos(:,:,params{i}.max_t_idx) = params{i}.wimg;
                                    [negSample,~] = SelectNeg(imgI, params{i}.est, opt);
                                    tmp_t = PLS_sub(params{i}.wimg, negSample, opt);
                                    curTmpl(i).mean(:,:,params{i}.max_t_idx) = tmp_t.mean;
                                    curTmpl(i).template(:,params{i}.max_t_idx) = tmp_t.template;
                                    curTmpl(i).W(:,:,params{i}.max_t_idx) = tmp_t.W;
                                    curTmpl(i).sigma(:,params{i}.max_t_idx) = tmp_t.sigma;
                                end
                            end
                        else
                            pos =  obj.getPosFromParam(opt.tmplsize, params{i}.est);  
                            if ~obj.isInScope(pos)
                                stopIdArray(i) = 1;
                                continue;                            
                            end
                        end      
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% show the result %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    %                 paramRes = [paramRes param.est]; 
                    pos =  obj.getPosFromParam(opt.tmplsize, params{i}.est);   
                    obj.m_seqObj.addBBToAFrm(obj.m_funcH, frmIndex, pSmplsInfo.id(i), pos, 0);
                end
                if playFlag
                    obj.m_seqObj.seqPlay(frmIndex - 2,frmIndex);
                    playFlag = 0;
                else
                    playFlag = 1;
                end
               
            end
            len = length(obj.m_tmplOrigins);
            tmpLen = length(tmplOrigin);
            for i = 1:tmpLen
                obj.m_tmplOrigins{len + i} = tmplOrigin{i};
            end
            
            obj.m_tmplSets = [obj.m_tmplSets curTmpl(:)'];
        end
        
        function tf = isInScope(obj, pos)
            tf = 0;
            [width, height] = obj.m_seqObj.getFrameSize();
            tlX = pos(1);
            tlY = pos(2);
            brX = pos(1) + pos(3);
            brY = pos(2) + pos(4);
            if brX < (width - 15) && brY < height && tlX > 0 && tlY > 0
                tf = 1;
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