classdef BBModel < handle
    properties(Access = private)
        m_objId
        m_pos %[tlX, tlY, width, height]
%         m_drawHelper
        m_selectedCallbackFcn
    end
    
    methods
        function obj = BBModel(hFig, hAxes, selectedFcn, id, pos)%, isdraw)
            obj.m_pos = [];
            BBModel.figHandle(hFig);
            BBModel.axesHandle(hAxes);
            obj.m_selectedCallbackFcn = selectedFcn;
            if nargin < 4 || isempty(id) || id < 1
                obj.m_objId = BBModel.increaseAndGetIdCounter();%create a new id BB
                %1,create a new drawhelper or just change the pos
                %of the exist one(i.e.new annotation or the video is playing) 
                %0,newly create bb,probably loading a file,but not show right now
%                 BBModel.drawRect(obj, 1);
            else
                obj.m_objId = id; %create an old id BB(i.e.the video is tracking(create new bb with exist id) or loading bb from a file)
                obj.m_pos = pos;
%                 if ~isempty(isdraw)
%                     if isdraw
%                         %1,create a new drawhelper or just change the pos
%                         %of the exist one(i.e.new annotation or the video is playing) 
%                         %0,newly create bb,probably loading a file,but not show right now
%                         BBModel.drawRect(obj, isdraw);
%                     end
%                 end
            end
            
        end
        
        function id = getObjId(obj)
            id = obj.m_objId;
        end
       
        function setPos(obj, newPos)
           obj.m_pos = newPos;
        end
        function pos = getPos(obj)
            pos = obj.m_pos;
        end
        
%         function updateRect(obj, isdraw)
%             BBModel.drawRect(obj, isdraw);
%         end
%         function drawRect(obj)
%             %if isempty(m_pos) true,it will set to invisible and wait 
%             %else,draw a rect immediately
%             if isempty(obj.m_drawHelper)
%                 hFig = BBModel.figHandle();
%                 hAxe = BBModel.axesHandle();
%                 selfunc = @obj.callback_rectSelected;
%                 setPosfunc = @obj.setPos;
%                 obj.m_drawHelper = DrawRectHelper(hFig, hAxe, obj.m_objId, obj.m_pos, setPosfunc, selfunc);
%             else
%                  obj.m_drawHelper.setPosAndUpdateAppearance(obj.m_pos);
%             end
%         end
        
%         function deleteRect(obj)
%             %delete the rect on the frame
%             %delete the graphic handle when it is not visible
%             if ~isempty(obj.m_drawHelper)
%                 obj.m_drawHelper.deleteFcn();
%                 
%                 obj.m_drawHelper.delete();
%                 obj.m_drawHelper = [];
%             end
%         end
        function delete(obj)
%             isdraw = 0;
%             BBModel.drawRect(obj, isdraw);
        end
        
        function callback_rectSelected(obj)
                if isempty(obj.m_selectedCallbackFcn)
                    return;
                end
                obj.m_selectedCallbackFcn(obj.m_objId);
        end
     
    end
  
    methods(Static)
        function nId = increaseAndGetIdCounter()
            persistent psisIdCounter;
            if isempty(psisIdCounter)
                psisIdCounter = 1;
            else
                psisIdCounter = psisIdCounter + 1;
            end
            nId = psisIdCounter;
        end
        
%         function drawRect(bbObj, isdraw)
%             persistent bbRectMap;
%             if isempty(bbRectMap)
%                 bbRectMap = containers.Map;
%             end
%             id = bbObj.m_objId;
%             pos = bbObj.m_pos;
%             if bbRectMap.Count
%                 if isdraw
%                     if isKey(bbRectMap, num2str(id))
%                         drawhelper = bbRectMap(num2str(id));
%                         drawhelper.setPosAndUpdateAppearance(pos)
%                         setPosfunc = @bbObj.setPos;
%                         selfunc = @bbObj.callback_rectSelected;
%                         oh = 'change pos'
%                         drawhelper.setInstanceCallbackFcn(setPosfunc, selfunc);
%                     else
%                         hFig = BBModel.figHandle();
%                         hAxe = BBModel.axesHandle();
%                         setPosfunc = @bbObj.setPos;
%                         selfunc = @bbObj.callback_rectSelected;
%                         ne='new rect'
%                         bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
%                     end
% 
%                 else
%                     if isKey(bbRectMap, num2str(id))
%                     %when the rect need not to show,delete it/or you just want to delete the BBobj,so delete the related rect first
%                         if bbRectMap.Count && isKey(bbRectMap, num2str(id))
%                         drawhelper = bbRectMap(num2str(id));
%                         drawhelper.delete();
%                         remove(bbRectMap, num2str(id));%remove drawhelper that belong to the id
%                         re='remove from map'
%                         end
%                     end
%                 end
%             else
%                 if isdraw
%                 hFig = BBModel.figHandle();
%                 hAxe = BBModel.axesHandle();
%                 setPosfunc = @bbObj.setPos;
%                 selfunc = @bbObj.callback_rectSelected;
%                 ne='new rect'
%                 bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
%                 else
%                     a = '想bye但是map为空'
%                 end                
%             end
%         end
     
            
            %%%%%%
%                 if bbRectMap.Count && isKey(bbRectMap, num2str(id)) %check if it is empty first!!!!!
%                     drawhelper = bbRectMap(num2str(id));
%                     drawhelper.setPosAndUpdateAppearance(pos)
%                     setPosfunc = @bbObj.setPos;
%                     selfunc = @bbObj.callback_rectSelected;
%                     oh = 'change pos'
%                     drawhelper.setInstanceCallbackFcn(setPosfunc, selfunc);
%                 else %add and create a new one.New an annotation/ BBobj already exist(i.e.loading from a annotation file),but is the first time to show the related id
%                     hFig = BBModel.figHandle();
%                     hAxe = BBModel.axesHandle();
%                     setPosfunc = @bbObj.setPos;
%                     selfunc = @bbObj.callback_rectSelected;
%                     ne='new rect'
%                     bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
%                 end
%             else
%                  %when the rect need not to show,delete it/or you just want to delete the BBobj,so delete the related rect first
%                 if bbRectMap.Count && isKey(bbRectMap, num2str(id))
%                 drawhelper = bbRectMap(num2str(id));
%                 drawhelper.delete();
%                 remove(bbRectMap, num2str(id));%remove drawhelper that belong to the id
%                 re='remove from map'
%                 end
%             end
%         end
        
        
        
%         function funcH = selectedCallbackFcn(cbfcn)
%             persistent callbackFcn;%应该是这里出了问题
%             if nargin == 1
%                 callbackFcn = cbfcn;
%             end
%             funcH = callbackFcn;
%         end
        
%         function drawRect(bbObj, isdraw)
%             persistent bbRectMap;
%             if isempty(bbRectMap)
%                 bbRectMap = containers.Map;
%             end
%             id = bbObj.m_objId;
%             pos = bbObj.m_pos;
%             if isdraw == 1
% %                 tf = isKey(bbRectMap, num2str(id));%if recthelper already exist(tracking or playing video),just change pos and show update
% %                 c = bbRectMap.Count; 
%                 if bbRectMap.Count && isKey(bbRectMap, num2str(id)) %check if it is empty first!!!!!
%                     drawhelper = bbRectMap(num2str(id));
% %                     if ~ishandle(drawhelper)
% %                         drawrec ='want to change pos,invalid handle!!!!how can you come in?!' 
% %                         return;
% %                     end
%                     drawhelper.setPosAndUpdateAppearance(pos)
%                     setPosfunc = @bbObj.setPos;
%                     selfunc = @bbObj.callback_rectSelected;
%                     oh = 'change pos'
%                     drawhelper.setInstanceCallbackFcn(setPosfunc, selfunc);
%                 else %add and create a new one.New an annotation/ BBobj already exist(i.e.loading from a annotation file),but is the first time to show the related id
%                     hFig = BBModel.figHandle();
%                     hAxe = BBModel.axesHandle();
%                     setPosfunc = @bbObj.setPos;
%                     selfunc = @bbObj.callback_rectSelected;
%                     ne='new rect'
%                     bbRectMap(num2str(id)) = DrawRectHelper(hFig, hAxe, id, pos, setPosfunc, selfunc);% m_pos maybe empty,i.e.create a new one;or pos exist(i.e.draw at onec)
%                 end
%             else
%                  %when the rect need not to show,delete it/or you just want to delete the BBobj,so delete the related rect first
%                 if bbRectMap.Count && isKey(bbRectMap, num2str(id))
%                 drawhelper = bbRectMap(num2str(id));
%                 drawhelper.delete();
%                 remove(bbRectMap, num2str(id));%remove drawhelper that belong to the id
%                 re='remove from map'
%                 end
%             end
%         end
   
        function hFig = figHandle(newHFig)
            persistent pstHFig;
            if nargin == 1
                pstHFig = newHFig;
            end
            hFig = pstHFig;
        end
            
        function hAxes = axesHandle(newHAxes)
            persistent pstHAxes;       
            if nargin == 1
                pstHAxes = newHAxes;
            end
            hAxes = pstHAxes;
        end
    end
   
 
    
end
