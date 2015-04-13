classdef SeqModel < handle
    properties
        m_seqFile
        m_hImg = []
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
            elseif ~strcmp(local.m_frame,fName)
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
        function seqPlay(obj, hFig, curAxes, frmIndex)
            set( hFig, 'CurrentAxes', curAxes ); 
            
%             if(replay) 
%                 ind=ind-nPlay;%current index minus the number of frames that just played 
%             end
            img = obj.getImg(frmIndex);
            obj.setImgHandleForDisplay(img);
        end
        
        function drawBBObj(obj, frmIndex)
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
        
        function delete(obj)
            obj.m_seqFile.close();                                %release the memory
        end
    end
    
end

