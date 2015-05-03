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
        m_bbRectMap
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
        
        function bbId = addBBToAFrm(obj, selectedFcn, frmNum, oldBBId, pos)
            if nargin < 3
                curFrmObj = obj.m_FrameObjArray(obj.m_curFrm);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn);%create a new id BB in curfrm
                curFrmObj.addObj(bbObj);
                
                isdraw = 1;
                obj.manageRectMap(bbObj, isdraw);
                
                obj.m_objStartFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
                obj.m_objEndFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
            else
                curFrmObj = obj.m_FrameObjArray(frmNum);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn, oldBBId, pos);%create an old id BB
                curFrmObj.addObj(bbObj);
%                 obj.manageRectMap(bbObj, isdraw);
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

        function bbObj = getBBObj(obj, frmNum, bbId)
            curFrmObj = obj.m_FrameObjArray(frmNum);
            bbObj = curFrmObj.getObj(bbId);
        end
        
        function bbNum = bbObjNumInCurFrm(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
            bbNum = frmObj.m_bbMap.Count;
        end
        
        function frmObj = getCurFrmObj(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
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
            obj.m_bbRectMap = containers.Map();
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
            dispNextFrm = 'come in dispNext'
            n =obj.m_curFrm
            numFrames = obj.getNumFrames();
            obj.m_curFrm = obj.m_curFrm + 1;

            if obj.m_curFrm <= numFrames
                obj.seqPlay(obj.m_curFrm - 1,obj.m_curFrm);
            else
                obj.m_curFrm = 0;
            end
            dispNextFrm = 'done dispNext'
            n
        end
        
        function displayLastFrame(obj)
            obj.m_curFrm = obj.m_curFrm - 1;

            if obj.m_curFrm >= 1
                obj.seqPlay(obj.m_curFrm + 1, obj.m_curFrm);
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function updateAnnotations(obj, lastFrmNum, curFrmNum)
%             updateAnno='want updateAnno?'
            curFrmObj = obj.m_FrameObjArray(curFrmNum);
            if curFrmObj.m_bbMap.Count
                if lastFrmNum > 0 && lastFrmNum <= obj.getNumFrames()
                    lastFrmObj = obj.m_FrameObjArray(lastFrmNum);
                    if  lastFrmObj.m_bbMap.Count
                        keysLast = keys(lastFrmObj.m_bbMap);
                        lastBBset = values(lastFrmObj.m_bbMap);
                        updateAnno='ready to kick'
                        isdraw = 0;
                        keyDifFlags = isKey(curFrmObj.m_bbMap, keysLast);
                        for i = 1:length(keysLast)
                            if ~keyDifFlags(i)
                            obj.manageRectMap(lastBBset{i},isdraw);
                            updateAnno='byebye'
                            end
                        end
                    end
                end
                curBBset = values(curFrmObj.m_bbMap);
                isdraw = 1;
                updateAnno='ready to draw!'
                for i = 1:length(curBBset)
                    obj.manageRectMap(curBBset{i}, isdraw);
                    updateAnno = 'draw next frm'
                end
            else
                if  lastFrmNum > 0 && lastFrmNum <= obj.getNumFrames()
                    lastFrmObj = obj.m_FrameObjArray(lastFrmNum);
                    if  lastFrmObj.m_bbMap.Count
                        lastBBset = values(lastFrmObj.m_bbMap);
                        isdraw = 0;
                        updateAnno='curFrm has nothing, ready to kick all in lastFrm'
                        for i = 1:length(lastBBset)
                            updateAnno='run All byebye'
                            obj.manageRectMap(lastBBset{i}, isdraw);
                            updateAnno='done All byebye'
                        end
                    end
                end
            end
        end
        
        function manageRectMap(obj, bbObj, isdraw)
            id = bbObj.getObjId;
            pos = bbObj.getPos();
            if obj.m_bbRectMap.Count
                if isdraw
                    if isKey(obj.m_bbRectMap, num2str(id))
                        drawhelper = obj.m_bbRectMap(num2str(id));
                        drawhelper.setPosAndUpdateAppearance(pos)
                        setPosfunc = @bbObj.setPos;
                        selfunc = @bbObj.callback_rectSelected;
                        drawhelper.setInstanceCallbackFcn(setPosfunc, selfunc);
                        rectMap = 'change pos'
                    else
                        hFig = BBModel.figHandle();
                        hAxe = BBModel.axesHandle();
                        setPosfunc = @bbObj.setPos;
                        selfunc = @bbObj.callback_rectSelected;
                        obj.m_bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
                        rectMap='new rectHelper'
                        numObjIn_RectMap=obj.m_bbRectMap.Count
                    end

                else
                    if isKey(obj.m_bbRectMap, num2str(id))
                    %when the rect need not to show,delete it/or you just want to delete the BBobj,so delete the related rect first                       
                        drawhelper = obj.m_bbRectMap(num2str(id));
                        drawhelper.delete();
                        remove(obj.m_bbRectMap, num2str(id));%remove drawhelper that belong to the id
                        rectMap='All bye~ remove obj from map'
                        numObjIn_RectMap=obj.m_bbRectMap.Count
                    end
                end
            else
                if isdraw
                    hFig = BBModel.figHandle();
                    hAxe = BBModel.axesHandle();
                    setPosfunc = @bbObj.setPos;
                    selfunc = @bbObj.callback_rectSelected;
                    obj.m_bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
                    rectMap='new rect'
                    numObjIn_RectMap=obj.m_bbRectMap.Count
                else
                    a = '想bye但是map为空'
                    numObjIn_RectMap=obj.m_bbRectMap.Count
                end                
            end
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
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
            curFrmObj = obj.m_FrameObjArray(frmNum);
            bbObj = curFrmObj.getObj(bbId);
            isdraw = 0;
            obj.manageRectMap(bbObj, isdraw);
            for i = frmNum:endFrmNum
                frmObj = obj.m_FrameObjArray(i);        
                frmObj.removeObj(bbId);
            end
        end
        
        function delete(obj)
            obj.m_seqFile.close();                                %release the memory
        end
    end
    
end

