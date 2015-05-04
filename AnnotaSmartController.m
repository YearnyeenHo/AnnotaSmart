classdef AnnotaSmartController < handle   
    properties
        m_viewObj
        m_seqObj
        m_bbId
        m_isMultiTrack
        m_numFrmToTrack
    end
    
    methods
        function obj = AnnotaSmartController(viewObj, seqObj)
           obj.m_viewObj = viewObj;
           obj.m_seqObj = seqObj;
           obj.m_bbId = 0;
           obj.m_isMultiTrack = 0;
           obj.m_numFrmToTrack = 20;
        end
        
        function callback_playOrPauseBtn(obj, src, event)
           if obj.m_seqObj.getStatus() == obj.m_seqObj.STATUS_PlAY 
               obj.m_seqObj.videoPause();
           else
               obj.m_seqObj.videoPlay();
           end
        end
        
        function callback_newAnnotaBtn(obj, src, event)
            if obj.m_seqObj.m_curFrm == 0
                return
            end
            funcH = @obj.callback_rectSelected;
            obj.m_bbId = obj.m_seqObj.addBBToAFrm(funcH);
        end
        
        function callback_rectSelected(obj, bbId)
            obj.m_bbId = bbId;
        end
        
        function callback_deleteAnnotaBtn(obj, src, event)
                if  obj.m_bbId == 0
                    return;
                end    
                obj.m_seqObj.deleteBBObj(obj.m_bbId);  
                obj.m_bbId = 0;
        end
        
        function callback_trackAnnotaBtn(obj, src, event)
            funcH = @obj.callback_rectSelected;
            bbObj = obj.m_seqObj.getBBObj(obj.m_seqObj.m_curFrm, obj.m_bbId);
            tracker = Tracker(obj.m_seqObj, funcH, obj.m_bbId, bbObj.getPos(), obj.m_isMultiTrack, obj.m_numFrmToTrack);
            tracker.runTracker();
        end
        
        function callback_setCheckBox(obj, src, event)
            if ~obj.m_isMultiTrack
                obj.m_isMultiTrack = 1;
            else
                obj.m_isMultiTrack = 0;
            end
        end
        
        function callback_setTrackFrmNum(obj, src, event)
            obj.m_numFrmToTrack = round(str2double(get(obj.m_viewObj.m_trackFrmNumEdit, 'string')));
        end
        
        function keyPressFcn_hotkeyDown(obj, src, event)
            viewObj = obj.m_viewObj;    
            key = get(viewObj.m_hFig,'CurrentKey');
            % e.g.,KeyNames = {'w', 'a','s', 'd', 'j', 'k'};
            % If 'd' and 'j' are already held down, and key == 's'is
            % pressed now
            % then KeyStatus == [0, 0, 0, 1, 1, 0] initially
            % strcmp(key, KeyNames) -> [0, 0, 1, 0, 0, 0, 0]
            % strcmp(key, KeyNames) | KeyStatus -> [0, 0, 1, 1, 1, 0]
            viewObj.m_keyStatus = (strcmp(key, viewObj.m_keyNames) | viewObj.m_keyStatus);
  
            if viewObj.m_keyStatus(viewObj.m_KEY.RIGHT)
                obj.m_seqObj.displayNextFrame();
            elseif viewObj.m_keyStatus(viewObj.m_KEY.LEFT)
                obj.m_seqObj.displayLastFrame();
            end
        end
        
        function keyReleaseFcn_hotkeyUp(obj, src, event)
             key = get(obj.m_viewObj.m_hFig,'CurrentKey');
%             % e.g., If 'd', 'j' and 's' are already held down, and key == 's'is
%             % released now
%             % then KeyStatus == [0, 0, 1, 1, 1, 0] initially
%             % strcmp(key, KeyNames) -> [0, 0, 1, 0, 0, 0]
%             % ~strcmp(key, KeyNames) -> [1, 1, 0, 1, 1, 1]
%             % ~strcmp(key, KeyNames) & KeyStatus -> [0, 0, 0, 1, 1, 0]
             obj.m_viewObj.m_keyStatus = (~strcmp(key, obj.m_viewObj.m_keyNames) & obj.m_viewObj.m_keyStatus);
        end
  
        function callback_openVideo(obj, src, event)
            
        end
        
        function callback_openAnnotation(obj, src, event)
             [fileName pathName] = uigetfile('*.txt','open annotation file');
             if flieName == 0
                 return;
             end      
        end
        
        function callback_saveAnnotation(obj, src, event)
        
        end
        
    end
    
end

