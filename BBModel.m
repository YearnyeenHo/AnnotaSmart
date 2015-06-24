
classdef BBModel < handle
    properties(Access = private)
        m_objId
        m_pos %[tlX, tlY, width, height]
        m_drawHelper
        m_selectedCallbackFcn
    end
    
    methods
        function obj = BBModel(hFig, hAxes, selectedFcn, id, pos, isdraw)
            obj.m_pos = [];
            BBModel.figHandle(hFig);
            BBModel.axesHandle(hAxes);
            obj.m_selectedCallbackFcn = selectedFcn;
            if nargin < 4 || isempty(id)
                obj.m_objId = BBModel.increaseAndGetIdCounter();%create a new id BB  
                obj.drawRect();
            else
                if id < 1
                    obj.m_pos = pos;
                    obj.m_objId = BBModel.increaseAndGetIdCounter();%create a new id BB  
                    if ~isempty(isdraw)
                        if isdraw
                            obj.drawRect();
                        end
                    end
                else
                    obj.m_objId = id; %create an old id BB
                    obj.m_pos = pos;
                    if ~isempty(isdraw)
                        if isdraw
                            obj.drawRect();
                        end
                    end
                end
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
        
        function drawRect(obj)
            %if isempty(m_pos) true,it will set to invisible and wait 
            %else,draw a rect immediately
            hFig = BBModel.figHandle();
            hAxe = BBModel.axesHandle();
            selfunc = @obj.callback_rectSelected;
            setPosfunc = @obj.setPos;
            obj.m_drawHelper = DrawRectHelper(hFig, hAxe, obj.m_objId, obj.m_pos, setPosfunc, selfunc);
        end
        
        function deleteRect(obj)
            %delete the rect on the frame
            %delete the graphic handle when it is not visible
            if ~isempty(obj.m_drawHelper)
                obj.m_drawHelper.delete();
                obj.m_drawHelper = [];
            end
        end
        
        function delete(obj)
             obj.deleteRect();
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
        
%         function funcH = selectedCallbackFcn(cbfcn)
%             persistent callbackFcn;%应该是这里出了问题
%             if nargin == 1
%                 callbackFcn = cbfcn;
%             end
%             funcH = callbackFcn;
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
