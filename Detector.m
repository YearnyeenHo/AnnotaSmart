classdef Detector < handle
    properties
        m_regionPos
        m_seqObj
        m_hFig
        m_hAxe
        m_rects%draw rect for test
        m_tmpSZ
        m_limitations
        m_funcH
        m_posfuncH
        
        m_affsig
        
        m_modelSets%model sets array;the elements are model-set,which is a struct,and the struct elements are arrays
        m_modelOrigins%cell array, one cell one ground truth model
    end
    methods
        function  obj = Detector(ctrlObj, seqObj)
            obj.m_hFig = ctrlObj.m_viewObj.m_hFig;
            obj.m_hAxe = ctrlObj.m_viewObj.m_playerPanel.hAx;
            obj.m_funcH = @ctrlObj.callback_rectSelected;
            obj.m_modelSets = ctrlObj.m_modelSets;
            obj.m_modelOrigins = ctrlObj.m_modelOrigins;
            
            obj.m_limitations = struct('wThreshold', 15, 'hThreshold', 30,...
                            'ratio_min', 1.0/6.0, 'ratio_max', 1.0/2.0);
                  
            rectObj = DrawRectHelper(obj.m_hFig, obj.m_hAxe, 0);
            
            obj.m_regionPos = rectObj.m_rectPos;
            obj.m_seqObj = seqObj;
            rectObj.deleteFcn();
            obj.m_rects = [];
            obj.m_tmpSZ = [32 32];
            obj.m_affsig = [5 5 0.100 0 0.1 0];
        end
        
        function runDetect(obj)
            if ~isempty(obj.m_modelSets)
                [binaryImg, contourImg] = obj.preprocess();
                
                 pointsMatrix = obj.getSamplesPos(binaryImg, contourImg);
                if isempty(pointsMatrix)
                    return;
                end

                pointsMatrix(:, 1) = pointsMatrix(:, 1) + obj.m_regionPos(1);
                pointsMatrix(:, 2) = pointsMatrix(:, 2) + obj.m_regionPos(2);
%                 obj.drawDetRects(pointsMatrix);
                finalSmplsParam = obj.genDetectParam(pointsMatrix);
                
                obj.addResToCurFrame(finalSmplsParam);
            end
        end
        
        %input:seed sample Matrix
        %output:result sample cell��some elements may be empty
        function finalSmplsParam = genDetectParam(obj, pointsMatrix)
            imgI = obj.m_seqObj.getImg( obj.m_seqObj.m_curFrm);
            imgI = rgb2gray(imgI);
            imgI = double(imgI)/256;
            
            numSeed = size(pointsMatrix, 1);
            smplSeedParams = cell(numSeed, 1);
            for i = 1:numSeed
                param = obj.genParam(pointsMatrix(i,:), obj.m_tmpSZ);
                smplSeedParams{i} = param';
            end
            
%             numModelSet = size(obj.m_modelSets, 2);
           finalSmplsParam = cell(numSeed, 1);%ÿ��seed����һ�������������Щ����ᱻ��������Ϊ�ս��
           mindisArray = ones(numSeed, 1);
           for seedNum = 1:numSeed 
                    detRes = obj.est_condens_PLS_Multi(imgI, obj.m_modelSets, smplSeedParams{seedNum});
                    if ~isempty(detRes)
                        [finalSmplsParam{seedNum},mindisArray(seedNum)] = obj.estwarp_condens_PLS(imgI, obj.m_modelOrigins{detRes.modelSetIndx}, detRes.est);
                    end
           end
           num = length(finalSmplsParam);
           i = 1;
           while i <= num
               if isempty(finalSmplsParam{i})
                   finalSmplsParam(i) = [];
                   mindisArray(i) = [];
                   i = i - 1;
                   num = num - 1;
               end
               i = i + 1;
           end
           
           finalSmplsParam = obj.reduceRes(finalSmplsParam, mindisArray, 30);
        end
        
        function paramCellRes = reduceRes(obj, paramCell, mindisArray, indis)
            paramCellRes = {};
            ind = 1;
            num = length(paramCell);
            counter = ones(num, 1);
            counter = counter.*1.1;
            counter(1) = 0;
            param0 = paramCell{1}.est;
            memArray = ones(num, 1);
            memArray(1) = mindisArray(1);
            while sum(counter)
                for i = 2:num
                    if 0 == counter(i)
                        continue;
                    end
                    param = paramCell{i}.est;
                    if abs(param0(1) - param(1)) < indis;
                        memArray(i) = mindisArray(i);
                        counter(i) = 0;
                    end
                end
                [~,minidx]=min(memArray);
                paramCellRes(ind) = paramCell(minidx);
                ind = ind + 1;
                [~,next_idx] = max(counter);
                param0 = paramCell{next_idx}.est;
                memArray = ones(num, 1);
                memArray(next_idx) = mindisArray(next_idx);
            end
        end
        
        %model set��model origin���Ӧ�����ԣ��Ը�����ͬ��model set�ֱ���м��㣬��set�ж�Ӧ��model origin
        %���룺��Ƶ֡�ĻҶ�ͼ�� model sets�е�����model set��sample seeds�е�ĳ��seed
        %
        function detRes = est_condens_PLS_Multi(obj, img, modelSets, smplSeedParam)
            detRes = [];
            if isempty(modelSets) || isempty(smplSeedParam)
                return
            end
            numParticle = 100;%������
            tmplSz = size(modelSets(1).mean);%�õ��ĵ�Ȼ��32*32
            numPixel = tmplSz(1)*tmplSz(2);
            affsig = obj.m_affsig;
            detRes.param = repmat(affparam2geom(smplSeedParam), [1,numParticle]); %param.est�洢����affparam2mat��ʽ�Ĳ���

            detRes.param = detRes.param + randn(6,numParticle).*repmat(affsig(:),[1,numParticle]); %����һ�����Ϊ��ֵ�����趨�Ĳ���Ϊ��׼��õ�Ԥ����
            %param.est 6 x 1
            %param.param 6 x 300
            wimgs = warpimg(img, affparam2mat(detRes.param), tmplSz);%wimgs: 32*32*300 double
            numModelSet = size(modelSets,2);
            
            modelSetDis = zeros(numModelSet, 1);
            minDisSmplIndx = zeros(numModelSet, 1);
            for i = 1:numModelSet
                curModelSet = modelSets(i);
                
                tmp = curModelSet.template;
                tmp(:,sum(abs(curModelSet.template),1)==0) = [];
                numModel = size(tmp,2);%˵����tmp��һ��model set�е�һԱ���������opt.num_tmpl��Ԫ��
                distance = zeros(1,numModel);%��ŵ�ĳ��model��С��disֵ
                index = zeros(1,numModel);%��disֵ�ö�Ӧ��sample index
                %300 randonly generated samples should compare with each model
                %�Ե�ǰmodel set�е�ÿ��model
                for modelNum =1:numModel%tmpl�Ǹ�model set��ֻ��ʽ�ṹ�����ʽ����model�ĸ��������浽��������
                    %tmpl����num��model��model set���ֽ�model set��ÿ��modelȡ������
                    mean = curModelSet.mean(:,:,modelNum);
                    mean = mean(:);%����������1024 x 1 double
                    template = curModelSet.template(:,modelNum);%template : 10 x 1
                    W = curModelSet.W(:,:,modelNum);%W: 1024 x 10
                    %��intensity���м���
                    diff = reshape(wimgs,[numPixel,numParticle]) -  repmat(mean,[1,numParticle]);%1024 x 300 - 1024 x 300,one column one sample     
                    coef = W'*diff;%10 x 1024 * 1024 x 300�õ�һ��template������10 x 1double,���һ����numsample�������300�ˣ�����10 x 300 double   
                    diff = coef - repmat(template,[1,numParticle]); %10 x 300 - 10 x 300 = 10 x 300
                    diff = sum(diff.^2);%1 x 300,ŷ�Ͼ����ƽ��
                    [mindis,minidx] = min(diff);%diff: 1 x 300 double,return the min dis value and the index of it
                    distance(modelNum) = mindis;%����model i��300��sample�У������ģ����ӽ�����[�������ֵ�� �±��ʾ�ڼ���]
                    index(modelNum) = minidx;%���ŵ���i��model���������sample���±�   ,candidates
                end
                %��candidates ���ҳ�������С�ģ��;�������
                [mindis,minidx] = min(distance);%distance��300��samples��ĳ��������֪�����ĸ��������ǵ�model i������С����ÿ��model����̾���ֵ������min���õ���ȫ����̾���ֵ
                modelSetDis(i) = mindis;%������smpls������model set����̾���
                minDisSmplIndx(i) = index(minidx);%���������̾���model��Ӧ��smaple��index�����smaple��������
            end
                [minDisOfAll, modelSetIndx] = min(modelSetDis);%���smpl��ĳ��model set �����������,����Ҫ < 0.8200�����ð�
                if minDisOfAll < 0.80
                    smplIndx = minDisSmplIndx(modelSetIndx);%���smpl��
                %����2�׶�
                %��õ�model set��model������������smpl���Լ���modelset���±�
                    detRes.est = affparam2mat(detRes.param(:,smplIndx));%������sample����ʵ���ǻ������param��2mat��浽est���������µĽ��
                    detRes.wimg = wimgs(:,:,smplIndx);%�õ����½����Ӧ��wimg
                    detRes.modelSetIndx = modelSetIndx;%�����smpl�����Ƶ�model set
                else
                    detRes = [];
                end
        end
        
        function [finalSmplsParam, mindis] = estwarp_condens_PLS(obj, img, modelOrigin, detEst)
            %tmpl is the ground truth model
            %param.est:6 x 1 double; param.param:6 x 300 double,min index max.....
            finalSmplsParam = [];
            if isempty(modelOrigin) || isempty(detEst)
                return
            end
            affsig = obj.m_affsig;
            numParticle = 100;%300
            sz = size(modelOrigin.mean);%32 x 32 x 5
            numPixel = sz(1)*sz(2);%1024

            finalSmplsParam.param = repmat(affparam2geom(detEst(:)), [1,numParticle]); %param.param: 6 x 300 double
            finalSmplsParam.param = finalSmplsParam.param + randn(6,numParticle).*repmat(affsig(:),[1,numParticle]); %(6 x 300 double) + (randn6 x 300) .* (6 x 300)=6 x 300
            wimgs = warpimg(img, affparam2mat(finalSmplsParam.param), sz);

            diff = reshape(wimgs,[numPixel,numParticle]) -  repmat(modelOrigin.mean(:),[1,numParticle]);%1024x300 - 1024x300    
            coef = modelOrigin.W'*diff;  
            diff = coef - repmat(modelOrigin.template,[1,numParticle]);%10x300 - 10x300;��ԭʼģ�ͱȽ�
            
            diff = sum(diff.^2);%Ϊŷ�Ͼ����ƽ��
            [mindis, minidx] = min(diff);
            finalSmplsParam.est = affparam2mat(finalSmplsParam.param(:,minidx));%��300�����ҵ�
            finalSmplsParam.wimg = wimgs(:,:,minidx);
            finalSmplsParam.proj = coef(:,minidx);%��10x300�У��ҵ�maxdix���Ǹ���10 x 1 
        end
        
        function addResToCurFrame(obj, params)
            len = length(params);
            for i =  1:len
                if ~isempty(params{i})
                   pos =  obj.getPosFromParam(obj.m_tmpSZ, params{i}.est);  
                   isdraw = 1;
                   obj.m_seqObj.addBBToAFrm(obj.m_funcH, obj.m_seqObj.m_curFrm, -1,pos, isdraw);
                end
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% detect %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [centerX, centerY, width, height] = getPosInfo(obj, pos)
            centerX = pos(1) + pos(3)/2;
            centerY = pos(2) + pos(4)/2;
            width = pos(3);
            height = pos(4);
        end
        
        function param = genParam(obj, pos, tmpSZ)
            if isempty(pos)
                return;
            end
            [centerX, centerY, width, height] = obj.getPosInfo(pos);
            angle = 0;
            skewRatio = 0;
            param = [centerX, centerY, width/tmpSZ(1), angle,height/width, skewRatio];%param0,����x������y����/32����ת�Ƕȡ���/��skew ratio
            param = affparam2mat(param);
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
         
         function drawDetRects(obj, rectMatrix)
            len = size(rectMatrix, 1);
            for i = 1:len
                pos = rectMatrix(i,:);
                 obj.m_rects = [obj.m_rects DrawRectHelper(obj.m_hFig, obj.m_hAxe,1, pos)];
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% preprocess %%%%%%%%%%%%%%%%%%%%%%
        function [binaryImg, contourImg] = preprocess(obj)
            tmpSZ = ceil([obj.m_regionPos(3), obj.m_regionPos(4)]);
            param = obj.genParam(obj.m_regionPos, tmpSZ);
            img = obj.m_seqObj.getImg(obj.m_seqObj.m_curFrm);
            imgI = rgb2gray(img);         
            imgI =  double(imgI)/256;
            wimg = warpimg(imgI, ceil(param),  ceil([obj.m_regionPos(3), obj.m_regionPos(4)]));
           %%%%%%%%%%%%%%%%%%%%%%%%%%%%% preprocessing %%%%%%%%%%%%%%%%%%%%
%              obj.segTest(wimg); 
            wimg = imadjust(wimg);
%             figure('Name','bw original');
%             obj.plotSurf(wimg);
            background = imopen(wimg,strel('disk',100));
%             figure('Name','bg1');
%             obj.plotSurf(background);
%             figure('Name','bg1');
%             imshow(background);
            binaryImg = wimg - background;
    
%             figure('Name','1:bw - bg');
%             imshow(binaryImg);
            background = imopen(wimg,strel('disk',35));
%             figure('Name','bg2');
%             obj.plotSurf(background);
%             figure('Name','bg2');
%             imshow(background);
            contourImg = wimg - background;

%             figure('Name','2:bw - bg');
%             imshow(contourImg);
            %%%%%%%%%%%%%%%%%%%%%%% binarize %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            binaryImg = Otsu(obj, uint8(binaryImg));
            binaryImg = imfill(binaryImg,'holes');
%             figure('Name','bw fill holes');
%             imshow(binaryImg);
            %%%%%%%%%%%%%%%%%%%%%%%% contour %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            contourImg = obj.Sober(contourImg); 
%             figure('Name','sober');
%             imshow(contourImg);
%             contourImg = imadjust(contourImg);
            contourImg = Otsu(obj, uint8(contourImg));
%             figure('Name','contourImg bw');
%             imshow(contourImg);
            contourImg=imopen(contourImg,strel('disk',1));
%             figure('Name','contourImg imerode');
%             imshow(contourImg);
        end
        function seg=segTest(obj, wimg)
            
            wimg = imadjust(wimg); 
            background = imopen(wimg,strel('disk',100));
            wimg = wimg - background;
            seg = double(wimg)*256;
            seg = segByDualthreshold_para1(seg);
            seg = bwareaopen(seg, 250);
            seg = imfill(seg,'holes');
%             figure('Name','seg By Dual threshold');
%             imshow(seg);
        end
        
        function plotSurf(obj, img)
            surf(double(img(1:8:end,1:8:end))),zlim([0 1]);
            set(gca,'ydir','reverse');
        end
        
        function img = Sober(obj, wimg)
            K = wimg*255;
            BW1=[-1,-2,-1;0,0,0;1,2,1];
            BW2=[-1,0,1;-2,0,2;-1,0,1];
            J1=filter2(BW1,K);
            J2=filter2(BW2,K);
            K1=double(J1);
            K2=double(J2);
            img=(abs(K1) +abs(K2));
            img = double(img)/256;
        end
        
        function bw = Otsu(obj, wimg)
            [T, ~] = graythresh(wimg);
            bw = im2bw(wimg, T);
            bw = bwareaopen(bw, 250);%remove noise
        end
        %%%%%%%%%%%%%%%%%%%%%%%%% gen sample seeds %%%%%%%%%%%%%%%%%%%%%%%%
        
        %����һЩ���ܵ�pos���ģ����ӣ���֮����������������Щpos��Ϊ��ֵ�������������ɸ���samples
        function pointsMatrix = getSamplesPos(obj, bwImg, conImg)
            xBwSumVec = sum(bwImg);
            yBwSumVec = sum(bwImg, 2);
            xConSumVec = sum(conImg);%��Ҫ;���ԣ�û�������ĵط��ز���
            yConSumVec = sum(conImg, 2);
            %get row vector
            tmpVector = ~xConSumVec; %��0��λ����Ϊ1
            xIndVec = ~(~xBwSumVec) - tmpVector;
            xIndVec = xIndVec+(xIndVec == -1); %��-1�ĵط���Ϊ0
            xIndVec = xIndVec + xConSumVec;%������Щ�ؼ��λ��
            xIndVec = ~(xIndVec == 0);%all elements become logic: 1 or 0
            %get col vector
            tmpVector = ~yConSumVec; %��0��λ����Ϊ1
            yIndVec = ~(~yBwSumVec) - tmpVector;
            yIndVec = yIndVec+(yIndVec == -1); %��-1�ĵط���Ϊ0
            yIndVec = yIndVec + yConSumVec;
            yIndVec = ~(yIndVec == 0);%all elements become logic: 1 or 0
            
            %get a new bwImg from the combination of these info,the 1
            bwImg = bwImg - repmat(~yIndVec, 1, size(bwImg,2));
            bwImg = bwImg + (bwImg == -1);
            bwImg = bwImg - repmat(~xIndVec, size(bwImg,1),1);
            bwImg = bwImg + (bwImg == -1);
            bwImg = bwImg + conImg;
            bwImg = ~(bwImg == 0);  
%             figure('Name','final bwImg');
%             imshow(bwImg);
            bwImg=imclose(bwImg,strel('disk',1));
%             figure('Name','final close');
%             imshow(bwImg);
            bwImg = imfill(bwImg,'holes');
%             figure('Name','final fill');
%             imshow(bwImg);
           %%%%%%%%%%%% get sample point's y %%%%%%%%%%%%%%%%%%
            yBlockIndicePairs = obj.getNonZeroBlocksFromVec(yIndVec);

            yValsVec = obj.getSmplVals(yBlockIndicePairs, obj.m_limitations.hThreshold);
           %%%%%%%%%%%% get sample point's x correspond with the y %%%%%%%%%%%%%%%%%%
           pointsMatrix = [];
           len  = length(yValsVec);
           for i = 1:len
               %for each y
                rowVec = bwImg(yValsVec(i),:);
                xBlockIndicePairs = obj.getNonZeroBlocksFromVec(rowVec);
         
                pMatrix= obj.genSamplePoints(bwImg, xBlockIndicePairs, yValsVec(i), yBlockIndicePairs);
                tmpLen = size(pMatrix,1);
                len = size(pointsMatrix, 1);
                if tmpLen
                pointsMatrix(len + 1:len + tmpLen, :) = pMatrix;
                end
           end
        end
        %���sample�������ߣ�[xtl, ytl, w, h]
        function pointsMatrix = genSamplePoints(obj, bwImg, xIndicePairs, y, yBlockIndicePairs)
            pointsMatrix = [];
            count = 1;
            len = length(xIndicePairs);
            for i = 1:len
                s = xIndicePairs(i).start;
                e = xIndicePairs(i).end;
                xCenter = round((s + e)/2);
                width = e - s;
                if width < obj.m_limitations.wThreshold
                    continue;
                end
   
                colVec = bwImg(:, xCenter);
                
                yStart = 0;
                yEnd = 0;
                for index = y:size(bwImg,1)
                    if colVec(index) == 1
                        yEnd = index;
                    else
                        break;
                    end
                end
                for index = y:-1:1
                    if colVec(index) == 1
                        yStart = index;
                    else
                        break;
                    end
                end
                height = yEnd - yStart;
                yCenter = (yStart + yEnd)/2;
                if obj.checkRatio(width, height)
                    pointsMatrix(count, :) = [xCenter - width/2, yCenter - height/2, width, height];%[xtl, ytl, w, h]
                    count = count + 1;
                end
                k = obj.getBlockIndx(yBlockIndicePairs, y);
                if k ~=-1
                    ys = yBlockIndicePairs(k).start;
                    ye = yBlockIndicePairs(k).end;
                    if yEnd < ye
                        yEnd = ye;
                        height = yEnd - yStart;
                        yCenter = (yStart + yEnd)/2;
                        if obj.checkRatio(width, height)
                            pointsMatrix(count, :) = [xCenter - width/2, yCenter - height/2, width, height];%[xtl, ytl, w, h]
                            count = count + 1;
                        end
                    end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ����Ҫ�ģ�������yStart������ȡ��Ӧ�д���block�����yֵ%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if yStart > ys
                        yStart = ys;
                        height = yEnd - yStart;
                        yCenter = (yStart + yEnd)/2;
                        if obj.checkRatio(width, height)
                            pointsMatrix(count, :) = [xCenter - width/2, yCenter - height/2, width, height];%[xtl, ytl, w, h]
                            count = count + 1;
                        end
                    end
                end
            end
        end
        
        function k = getBlockIndx(obj, yBlockIndicePairs, y)
            k = -1;
            numBlock = size(yBlockIndicePairs);
            for i = 1:numBlock
                if  y < yBlockIndicePairs(i).end && y > yBlockIndicePairs(i).start
                    k = i;
                    break;
                end
            end
        end
        
        function tf = checkRatio(obj, width, height)
            min = obj.m_limitations.ratio_min;
            max = obj.m_limitations.ratio_max;
            val = width/height;
            tf = (val > min) &&(val < max); 
        end
        
        function blockIndicePairs = getNonZeroBlocksFromVec(obj, indVec)
            blockIndicePairs = [];
            counter = 1;
            flag = 0;
            len = length(indVec);
            for i = 1:len
               if (indVec(i) == 0) && (flag == 0)
                    continue;
               else
                    if (flag == 0) 
                        if (i < length(indVec) - 15)%15 is the width of a sample
                            flag = 1;
                            index = floor(counter/2) + 1;
                            blockIndicePairs(index).start = i;
                            counter = counter + 1;
                        end
                    else
                        if indVec(i) == 0
                            index = floor(counter/2);
                            blockIndicePairs(index).end = i - 1;
                            flag = 0;
                            counter = counter + 1;
                        else
                           if i == length(indVec)
                                index = floor(counter/2);
                                blockIndicePairs(index).end = i;
                           end  
                        end
                    end
               end
            end
        end
        
        % ���ַ���block�ֿ飬ÿ���и�����һ��sample point 
        %���ֿ��block���Ȳ�������ֵ����Y���Ծ���Ҫ��С����С�˵ĸ߶�
        function valsVec = getSmplVals(obj, blockIndicePairs, threshold)
            valsVec = [];
            len = length(blockIndicePairs);
            for i = 1:len
                s = blockIndicePairs(i).start;
                e = blockIndicePairs(i).end;
                valsVec = obj.binaryDivide(s, e, threshold);
            end
        end
        
        function valsVec = binaryDivide(obj, s, e, threshold)
                valsVec = [];
            if (e - s) >= threshold
                pVal = round((s+e)/2);
                valsVec = [valsVec pVal];
                valsVec = [valsVec obj.binaryDivide(s, pVal, threshold)];
                valsVec = [valsVec obj.binaryDivide(pVal, e, threshold)];
            end
        end        
    end

end