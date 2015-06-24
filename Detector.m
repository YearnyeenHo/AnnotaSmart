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
        %output:result sample cell，some elements may be empty
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
           finalSmplsParam = cell(numSeed, 1);%每个seed产生一个检测结果，但有些结果会被丢弃，即为空结果
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
        
        %model set与model origin相对应，所以，对各个不同的model set分别进行计算，个set有对应的model origin
        %输入：视频帧的灰度图， model sets中的所有model set，sample seeds中的某个seed
        %
        function detRes = est_condens_PLS_Multi(obj, img, modelSets, smplSeedParam)
            detRes = [];
            if isempty(modelSets) || isempty(smplSeedParam)
                return
            end
            numParticle = 100;%粒子数
            tmplSz = size(modelSets(1).mean);%得到的当然是32*32
            numPixel = tmplSz(1)*tmplSz(2);
            affsig = obj.m_affsig;
            detRes.param = repmat(affparam2geom(smplSeedParam), [1,numParticle]); %param.est存储的是affparam2mat格式的参数

            detRes.param = detRes.param + randn(6,numParticle).*repmat(affsig(:),[1,numParticle]); %以上一组参数为均值，以设定的参数为标准差，得到预测结果
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
                numModel = size(tmp,2);%说明了tmp是一个model set中的一员，它最多有opt.num_tmpl个元素
                distance = zeros(1,numModel);%存放到某个model最小的dis值
                index = zeros(1,numModel);%有dis值得对应的sample index
                %300 randonly generated samples should compare with each model
                %对当前model set中的每个model
                for modelNum =1:numModel%tmpl是个model set，只是式结构体的形式，将model的各个部件存到各个数组
                    %tmpl是有num个model的model set，现将model set的每个model取出计算
                    mean = curModelSet.mean(:,:,modelNum);
                    mean = mean(:);%化成列向量1024 x 1 double
                    template = curModelSet.template(:,modelNum);%template : 10 x 1
                    W = curModelSet.W(:,:,modelNum);%W: 1024 x 10
                    %对intensity进行计算
                    diff = reshape(wimgs,[numPixel,numParticle]) -  repmat(mean,[1,numParticle]);%1024 x 300 - 1024 x 300,one column one sample     
                    coef = W'*diff;%10 x 1024 * 1024 x 300得到一堆template，都是10 x 1double,这次一共有numsample（我设成300了）个，10 x 300 double   
                    diff = coef - repmat(template,[1,numParticle]); %10 x 300 - 10 x 300 = 10 x 300
                    diff = sum(diff.^2);%1 x 300,欧氏距离的平方
                    [mindis,minidx] = min(diff);%diff: 1 x 300 double,return the min dis value and the index of it
                    distance(modelNum) = mindis;%对于model i，300个sample中，与这个模型最接近的是[最近距离值， 下标表示第几个]
                    index(modelNum) = minidx;%放着到第i个model距离最近的sample的下标   ,candidates
                end
                %在candidates 中找出距离最小的，和距离最大的
                [mindis,minidx] = min(distance);%distance是300个samples的某几个（不知道是哪个反正就是到model i距离最小）到每个model的最短距离值集；求min，得到，全局最短距离值
                modelSetDis(i) = mindis;%存放这堆smpls到各个model set的最短距离
                minDisSmplIndx(i) = index(minidx);%获得有着最短距离model对应的smaple的index，这个smaple就是所求！
            end
                [minDisOfAll, modelSetIndx] = min(modelSetDis);%这堆smpl到某个model set 的有最近距离,距离要 < 0.8200才有用啊
                if minDisOfAll < 0.80
                    smplIndx = minDisSmplIndx(modelSetIndx);%这个smpl是
                %用于2阶段
                %获得到model set中model，有最近距离的smpl，以及该modelset的下标
                    detRes.est = affparam2mat(detRes.param(:,smplIndx));%获得这个sample，其实就是获得它的param，2mat后存到est，这是最新的结果
                    detRes.wimg = wimgs(:,:,smplIndx);%得到最新结果对应的wimg
                    detRes.modelSetIndx = modelSetIndx;%与这堆smpl最相似的model set
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
            diff = coef - repmat(modelOrigin.template,[1,numParticle]);%10x300 - 10x300;与原始模型比较
            
            diff = sum(diff.^2);%为欧氏距离的平方
            [mindis, minidx] = min(diff);
            finalSmplsParam.est = affparam2mat(finalSmplsParam.param(:,minidx));%从300个中找到
            finalSmplsParam.wimg = wimgs(:,:,minidx);
            finalSmplsParam.proj = coef(:,minidx);%在10x300中，找到maxdix的那个，10 x 1 
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
            param = [centerX, centerY, width/tmpSZ(1), angle,height/width, skewRatio];%param0,中心x，中心y，宽/32，旋转角度、高/宽，skew ratio
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
        
        %生成一些可能的pos中心（粒子），之后用其他函数以这些pos作为均值，洒粒子在生成更多samples
        function pointsMatrix = getSamplesPos(obj, bwImg, conImg)
            xBwSumVec = sum(bwImg);
            yBwSumVec = sum(bwImg, 2);
            xConSumVec = sum(conImg);%必要;所以，没有轮廓的地方必不检
            yConSumVec = sum(conImg, 2);
            %get row vector
            tmpVector = ~xConSumVec; %将0的位置置为1
            xIndVec = ~(~xBwSumVec) - tmpVector;
            xIndVec = xIndVec+(xIndVec == -1); %将-1的地方置为0
            xIndVec = xIndVec + xConSumVec;%加上那些必检的位置
            xIndVec = ~(xIndVec == 0);%all elements become logic: 1 or 0
            %get col vector
            tmpVector = ~yConSumVec; %将0的位置置为1
            yIndVec = ~(~yBwSumVec) - tmpVector;
            yIndVec = yIndVec+(yIndVec == -1); %将-1的地方置为0
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
        %获得sample的坐标宽高，[xtl, ytl, w, h]
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
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 这里要改！，不是yStart，而是取对应中垂线block的最大y值%%%%%%%%%%%%%%%%%%%%%%%%%%
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
        
        % 二分法将block分块，每个切割点就是一个sample point 
        %被分块的block长度不少于阈值，对Y而言就是要不小于最小人的高度
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