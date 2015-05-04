classdef SeqModel < handle
    properties
        m_seqFile
        m_hImg
        m_curFrm
        m_FrameObjArray = []
        m_objEndFrmMap
        m_objStartFrmMap
        m_hFig
        m_hAx
        m_state = 0
    end
    properties(Constant)
        STATUS_STOP = 0;
        STATUS_PlAY = 1;
    end
    events
        playStatusChange
    end
    %singleton: only one SeqModel instance but you can change the seqfile 
    methods(Static)                                     
        function obj = getSeqFileInstance(fName)         %Static API
            persistent localObj                          %Persistent Local obj
         
            if isempty(localObj)|| -isvalid(localObj)
                localObj = SeqModel(fName);
                obj = localObj;
            elseif ~strcmp(localObj.m_frame,fName)
                localObj.seqFile.close();            %close seq file
                localObj.openSeqFile(fName);
                obj = localObj;
                else
                obj = localObj;                      %if obj already exist,return the instance
            end
        end
        
    end
    
    methods(Access = private)
        function obj = SeqModel(fName)
                obj.openSeqFile(fName);
        end
    end

 
    
    methods
        function setCurFigAndAxes(obj, hFig, hAx)
            obj.m_hFig = hFig;
            obj.m_hAx = hAx;
        end
        
        function frmArray = getFrmArray(obj)
            frmArray = obj.m_FrameObjArray;
        end
        
        function bbId = addBBToAFrm(obj, selectedFcn, frmNum, oldBBId, pos, isdraw)
            if nargin < 3
                curFrmObj = obj.m_FrameObjArray(obj.m_curFrm);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn);%create a new id BB
                curFrmObj.addObj(bbObj);
                obj.m_objStartFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
                obj.m_objEndFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
            else
                curFrmObj = obj.m_FrameObjArray(frmNum);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn, oldBBId, pos, isdraw);%create an old id BB
                curFrmObj.addObj(bbObj);
                keyStr = num2str(bbObj.getObjId());
                if isKey(obj.m_objEndFrmMap, keyStr)
                    obj.m_objEndFrmMap(keyStr) = frmNum;
                else
                    obj.m_objStartFrmMap(keyStr) = frmNum;
                    obj.m_objEndFrmMap(keyStr) = frmNum;
                end  
            end
            bbId = bbObj.getObjId();
        end

        function numBB = bbObjNumInCurFrm(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
            numBB = frmObj.m_bbMap.Count;
        end
        function frmObj = getCurFrmObj(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
        end
        
        function bbObj = getBBObj(obj, frmNum, bbId)
            curFrmObj = obj.m_FrameObjArray(frmNum);
            bbObj = curFrmObj.getObj(bbId);
        end

        function openSeqFile(obj, fName)
            obj.m_seqFile = seqIo( fName,'r');
            info = obj.m_seqFile.getinfo();
            for i = 1:info.numFrames
                obj.m_FrameObjArray = [obj.m_FrameObjArray FrameModel()];
            end
            obj.m_state = obj.STATUS_STOP;
            obj.m_curFrm = 0;
            obj.m_objEndFrmMap = containers.Map();
            obj.m_objStartFrmMap = containers.Map();
        end
        
        function numFrames = getNumFrames(obj)
               info = obj.m_seqFile.getinfo();
               numFrames = info.numFrames;
        end
        
        function videoPlay(obj)
            obj.setStatus(obj.STATUS_PlAY);
            numFrames = obj.getNumFrames();
            startFrmNum = obj.m_curFrm + 1;
            for i = startFrmNum:numFrames 
                if obj.getStatus() == obj.STATUS_STOP
                     break;
                end
                obj.seqPlay(i-1, i);
                obj.m_curFrm = i;
%                 drawnow();          
            end
        end
        
        function videoPause(obj)
             obj.setStatus(obj.STATUS_STOP);
        end
        
        function displayNextFrame(obj)
            numFrames = obj.getNumFrames();
            obj.m_curFrm = obj.m_curFrm + 1;

            if obj.m_curFrm <= numFrames
                obj.seqPlay(obj.m_curFrm - 1,obj.m_curFrm);
%                 drawnow();
            else
                obj.m_curFrm = 0;
            end
        end
        
        function displayLastFrame(obj)
            obj.m_curFrm = obj.m_curFrm - 1;

            if obj.m_curFrm >= 1
                obj.seqPlay(obj.m_curFrm + 1, obj.m_curFrm);
%                 drawnow();
            else
                obj.m_curFrm = 0;
            end
        end

        function seqPlay(obj, lastFrmNum, curFrmNum)
            if isempty(obj.m_seqFile)
                return;
            end            
            obj.m_curFrm = curFrmNum;
            
            img = obj.getImg(curFrmNum);
            obj.setImgHandleForDisplay(img);
            obj.updateAnnotations(lastFrmNum, curFrmNum);
            drawnow();
        end
        
        function updateAnnotations(obj, lastFrmNum, curFrmNum)
          if  lastFrmNum > 0 && lastFrmNum <= obj.getNumFrames()
            lastFrmObj = obj.m_FrameObjArray(lastFrmNum);
            bbObjSet = values(lastFrmObj.m_bbMap);
            len = length(bbObjSet);
            if len ~= 0
                for i = 1:len
                    bbObjSet{i}.deleteRect();          
                end
            end
          end
          
           curFrmObj = obj.m_FrameObjArray(curFrmNum);
           bbObjSet = values(curFrmObj.m_bbMap);
           len = length(bbObjSet);
           if len ~= 0 
               for i = 1:len
                     bbObjSet{i}.drawRect();
               end
           end
        end
        
        function setImgHandleForDisplay(obj, img)
            if(isempty(obj.m_hImg)) 
                %IMAGE(C) displays matrix C as an image.IMAGE returns a handle to an IMAGE object.
                obj.m_hImg = image(img);
                axis off;
            else
                set(obj.m_hImg,'CData',img);
            end
        end
        
        function img = getImg(obj, index)
            obj.m_seqFile.seek(index);
            img = obj.m_seqFile.getframe();
            if(ismatrix(img))
                img = img(:, :, [1 1 1]);
            end
        end
        function state = getStatus(obj)
            state = obj.m_state;
        end
        
        function setStatus(obj, status)
            obj.m_state = status;
        end
        
        function deleteBBObj(obj, bbId)
            %delete obj from curframe to the endFrm
            endFrmNum = obj.m_objEndFrmMap(num2str(bbId));
            frmNum = obj.m_curFrm;
            for i = frmNum:endFrmNum
                frmObj = obj.m_FrameObjArray(i);
                frmObj.removeObj(bbId);%会触发BBModel会自动调用delete吗？不会的！
            end
        end
        
        function delete(obj)
            obj.m_seqFile.close();                                %release the memory
        end
    end
    
end

