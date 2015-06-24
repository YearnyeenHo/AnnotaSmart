classdef AnnotaSmartController < handle   
    properties
        m_viewObj
        m_seqObj
        m_bbId
        m_isMultiTrack
        m_numFrmToTrack
        m_fps
        
        m_modelOrigins %cell
        m_modelSets % structure array
    end
    
    methods
        function obj = AnnotaSmartController(viewObj)
           obj.m_viewObj = viewObj;
           obj.m_viewObj.enableBtn('off');
           obj.m_seqObj = [];
           obj.m_bbId = 0;
           obj.m_isMultiTrack = 0;
           obj.m_numFrmToTrack = 20;
           obj.m_fps = -1;
           obj.m_modelOrigins = {};
           obj.m_modelSets = [];
%            parpool('local',2);
        end
        
        function deleteAnnotation(obj)
                if  obj.m_bbId == 0
                    return;
                end    
                obj.m_seqObj.deleteBBObj(obj.m_bbId);  
                obj.m_bbId = 0;
        end
        
        function pasteAnnotation(obj)
            frmNum = obj.m_seqObj.m_curFrm;
            if obj.m_bbId == 0|| frmNum == 0
                return;
            end
            funcH = @obj.callback_rectSelected;
            obj.m_seqObj.pasteAnnotation(funcH, obj.m_bbId);
        end
        
        function callback_playOrPauseBtn(obj, src, event)
           if obj.m_seqObj.getStatus() == obj.m_seqObj.STATUS_PlAY 
               obj.m_seqObj.videoPause();
           else
               obj.m_seqObj.videoPlay(obj.m_viewObj);
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
        
        function callback_rectChange(obj, bbId, rectPos)
            curFrmNum = obj.m_seqObj.m_curFrm;
            key = num2str(bbId);
            if ~isKey(obj.m_seqObj.m_objEndFrmMap, key)||~isKey(obj.m_seqObj.m_objEndFrmMap, key)
                return;
            end
            endFrmNum = obj.m_seqObj.m_objEndFrmMap(key);
            startFrmNum = obj.m_seqObj.m_objStartFrmMap(key);
            for i = startFrmNum:curFrmNum - 1
                frameObj = obj.m_seqObj.m_FrameObjArray(i);
                bbObj = frameObj.getObj(bbId);
                pos = bbObj.getPos();
                w = obj.weighFactor(i, curFrmNum);
                pos = (1-w)*pos + w*rectPos;
                bbObj.setPos(pos);
            end
            for i = curFrmNum + 1:endFrmNum
                 frameObj = obj.m_seqObj.m_FrameObjArray(i);
                bbObj = frameObj.getObj(bbId);
                pos = bbObj.getPos();
                w = obj.weighFactor(i, curFrmNum);
                pos = pos.*(1-w) + rectPos.*w;
                bbObj.setPos(pos);
            end
        end
        
        function w = weighFactor(obj, ind1,ind2)
            w = abs(ind2 - ind1);
            w = 1/(w*w);
        end
        function callback_deleteAnnotaBtn(obj, src, event)
                obj.deleteAnnotation();
        end
        
        function callback_detectAnnotaBtn(obj, src, event)
%             if length(obj.m_modelOrigins) >= 3
                detector = Detector(obj, obj.m_seqObj);
                detector.runDetect();
%             end
        end
        
        function callback_trackAnnotaBtn(obj, src, event)
            frmObj = obj.m_seqObj.getCurFrmObj();
            if ~obj.m_bbId || ~isKey(frmObj.m_bbMap, num2str(obj.m_bbId))
                return
            end
                
            obj.m_viewObj.enableBtn('off');
            funcH = @obj.callback_rectSelected;
            bbObj = obj.m_seqObj.getBBObj(obj.m_seqObj.m_curFrm, obj.m_bbId);
            tracker = Tracker(obj.m_seqObj, funcH, obj.m_bbId, bbObj.getPos(), obj.m_isMultiTrack, obj.m_numFrmToTrack);
            tracker.runTracker();
            obj.m_viewObj.enableBtn('on');
            len = length(obj.m_modelOrigins);
            tmpLen = length(tracker.m_tmplOrigins);
            for i = 1:tmpLen
                obj.m_modelOrigins{len + i} = tracker.m_tmplOrigins{i}; 
            end
            obj.m_modelSets = [obj.m_modelSets tracker.m_tmplSets];
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
           if isempty(obj.m_seqObj.m_seqFile)
               return;
           end
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
            elseif viewObj.m_keyStatus(viewObj.m_KEY.DEL)
                obj.deleteAnnotation();
            elseif viewObj.m_keyStatus(viewObj.m_KEY.V)
                obj.pasteAnnotation();
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
  
        function frameNumUpdate(obj)
            set(obj.m_viewObj.m_frames, 'String', num2str(obj.m_seqObj.m_curFrm)); 
        end
        function setFrameTotalNum(obj, viewObj)
             set(viewObj.m_totalFrames, 'String',['/ ' num2str(obj.m_seqObj.m_numFrm)]);
        end
        function callback_openVideo(obj, src, event)
            obj.m_viewObj.enableBtn('off');
            [fileName, pathName] = uigetfile('*.seq;*.avi','open annotation file');
            if fileName == 0
                return
            end
            filePath = [pathName fileName];
            obj.m_seqObj = SeqModel.getSeqFileInstance(filePath);
            obj.m_seqObj.setCurFigAndAxes(obj.m_viewObj.m_hFig, obj.m_viewObj.m_playerPanel.hAx);
            funcH = @obj.frameNumUpdate;
            obj.m_seqObj.setFrameNumChangeCallback(funcH);
            obj.m_viewObj.enableBtn('on');
            obj.frameNumUpdate();
            obj.setFrameTotalNum(obj.m_viewObj);
        end
        
        function callback_openAnnotation(obj, src, event)
             [fileName, pathName] = uigetfile('*.txt','open annotation file');
             if fileName == 0
                 return;
             end  
             funcH = @obj.callback_rectSelected;
             fileFullName = [pathName fileName];
             obj.m_seqObj.LoadAnnotaFile(funcH, fileFullName)
        end
        
        function callback_saveAnnotation(obj, src, event)
             [fileName, pathName]=uiputfile('*.txt','Select Annotation');
             if fileName == 0
                 return;
             end
              fileFullName = [pathName fileName];
              obj.m_seqObj.saveAnnotaFile(fileFullName);
        end
    end
    
end

