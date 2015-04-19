classdef AnnotaSmartController < handle   
    properties
        m_viewObj
        m_seqObj
        m_curFrame
%         m_rectBBMap
        m_bbId
        %m_bbObj
        %m_frameObj
    end
    
    methods
        function obj = AnnotaSmartController(viewObj, seqObj)
           obj.m_viewObj = viewObj;
           obj.m_seqObj = seqObj;
           obj.m_curFrame = 0;
           obj.m_bbId = 0;
           funcH = @obj.callback_rectSelected;
           BBModel.selectedCallbackFcn(funcH)
%            obj.m_rectBBMap = containers.Map;
        end
        
        function callback_playOrPauseBtn(obj, src, event)
           if obj.m_seqObj.getStatus() == obj.m_seqObj.STATUS_PlAY 
               obj.m_seqObj.setStatus(obj.m_seqObj.STATUS_STOP);
           else
               numFrames = obj.m_seqObj.getNumFrames();
               obj.m_seqObj.setStatus(obj.m_seqObj.STATUS_PlAY);
               startFrmNum = obj.m_curFrame + 1;
               for i = startFrmNum:numFrames 
                   if obj.m_seqObj.getStatus() == obj.m_seqObj.STATUS_STOP
                        break;
                   end
                   obj.m_seqObj.seqPlay(i-1, i);
                   obj.m_curFrame = i;
                   drawnow();          
               end
           end
        end
        
        function callback_newAnnotaBtn(obj, src, event)
%             set(obj.m_viewObj.m_hFig, 'WindowButtonDownFcn', @obj.btnDown);
%             obj.m_rectVector = [obj.m_rectVector DrawRectHelper(obj.m_viewObj.m_hFig, obj.m_viewObj.m_playerPanel.hAx)];
            if obj.m_curFrame == 0
                return
            end
            obj.m_bbId = obj.m_seqObj.addBBToAFrm(obj.m_viewObj.m_hFig, obj.m_viewObj.m_playerPanel.hAx, obj.m_curFrame);
            
%             obj.m_rectBBMap(num2str(obj.m_bbId)) = DrawRectHelper(obj.m_viewObj.m_hFig, obj.m_viewObj.m_playerPanel.hAx);
        end
        function callback_deleteAnnotaBtn(obj, src, event)    

%                 bbObj = obj.m_seqObj.getBBObj(obj.m_curFrame, obj.m_bbId);
%                 bbObj.deleteRect();
                obj.m_seqObj.deleteBBObj(obj.curFrame, obj.m_bbId);
         
        end
        
        function callback_detectAnnotaBtn(obj, src, event)
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
                obj.displayNextFrame();
            elseif viewObj.m_keyStatus(viewObj.m_KEY.LEFT)
                obj.displayLastFrame();
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
        
        
        
        
        function displayNextFrame(obj)
            numFrames = obj.m_seqObj.getNumFrames();
            obj.m_curFrame = obj.m_curFrame + 1;

            if obj.m_curFrame <= numFrames
               obj.m_seqObj.seqPlay(obj.m_curFrame - 1,obj.m_curFrame);
               drawnow();
            else
               obj.m_curFrame = 0;
            end
        end
        
        function displayLastFrame(obj)
            obj.m_curFrame = obj.m_curFrame - 1;

            if obj.m_curFrame >= 1
                obj.m_seqObj.seqPlay(obj.m_curFrame + 1, obj.m_curFrame);
                drawnow();
            else
                obj.m_curFrame = 0;
            end
        end
        
%         function btnDown(obj, src, event)
%             obj.m_rectVector = [obj.m_rectVector DrawRectHelper(obj.m_viewObj.m_hFig, obj.m_viewObj.m_playerPanel.hAx)];
%             set(obj.m_viewObj.m_hFig, 'WindowButtonDownFcn', '');
%         end
        
%         function btnUp(obj, src, event)
%             set(obj.m_viewObj.m_hFig, 'WindowButtonDownFcn', '');
%         end
        function callback_rectSelected(obj, bbId)
            obj.m_bbId = bbId;
        end
    end
    
end

