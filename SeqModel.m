classdef SeqModel < handle
    properties
        m_seqFile
        m_hImg
        m_FrameObjArray = []
        m_objEndFrmMap
        m_objStartFrmMap
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
        function frmArray = getFrmArray(obj)
            frmArray = obj.m_FrameObjArray;
        end
        
        function bbId = addBBToAFrm(obj, hFig, hAx, selectedFcn, curfrmNum, oldBBId)
            curFrmObj = obj.m_FrameObjArray(curfrmNum);
            if nargin < 6
                bbObj = BBModel(hFig, hAx, selectedFcn);%create a new id BB
                curFrmObj.addObj(bbObj);
                obj.m_objStartFrmMap(num2str(bbObj.getObjId())) = curfrmNum;
                obj.m_objEndFrmMap(num2str(bbObj.getObjId())) = curfrmNum;
            else
                bbObj = BBModel(hFig, hAx, selectedFcn, oldBBId);%create an old id BB
                curFrmObj.addObj(bbObj);
                obj.m_objEndFrmMap(num2str(bbObj.getObjId())) = curfrmNum;
            end
            bbId = bbObj.getObjId();
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
        end
        
        function numFrames = getNumFrames(obj)
               info = obj.m_seqFile.getinfo();
               numFrames = info.numFrames;
        end
        
        function seqPlay(obj, lastFrmNum, curFrmNum)
            if isempty(obj.m_seqFile)
                return;
            end 
            img = obj.getImg(curFrmNum);
            obj.setImgHandleForDisplay(img);
            obj.updateAnnotations(lastFrmNum, curFrmNum);
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
        
        function deleteBBObj(obj, frmNum, bbId)
          %delete obj from curframe to the endFrm
          endFrmNum = obj.m_objEndFrmMap(num2str(bbId));
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

