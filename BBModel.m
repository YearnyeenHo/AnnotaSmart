
classdef BBModel < handle
    properties(Access = private)
        m_objId
        m_pos
        m_drawHelper
        m_selectedCallback
    end
    
    methods
        function obj = BBModel(hFig, hAxes, id)
            obj.m_pos = [];
            obj.m_selectedCallback = [];
            BBModel.figHandle(hFig);
            BBModel.axesHandle(hAxes);
            if nargin < 3 || isempty(id) || id < 1
                obj.m_objId = BBModel.increaseAndGetIdCounter();
                obj.drawRect();
            else
                obj.m_objId = id;  
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
            obj.m_drawHelper = DrawRectHelper(hFig, hAxe, obj.m_pos);
            funcH = @obj.callback_rectSelected;
            obj.m_drawHelper.setSelectedCallback(funcH);
        end
        
        function deleteRect(obj)
            %delete the rect on the frame
           obj.m_drawHelper.deleteFcn();
           obj.m_drawHelper.delete();
        end
        
        function callback_rectSelected(obj)
                funcH = BBModel.selectedCallbackFcn();
                if isempty(funcH)
                    return;
                end
                funcH(obj.m_objId);
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
        
        function funcH = selectedCallbackFcn(cbfcn)
            persistent callbackFcn;
            if isempty(callbackFcn)
                callbackFcn = cbfcn;
            end
            funcH = callbackFcn;
        end
        
        function hFig = figHandle(newHFig)
        persistent pstHFig;
        if isempty(pstHFig)
                pstHFig = newHFig;
        end
            hFig = pstHFig;
        end
            
        function hAxes = axesHandle(newHAxes)
            persistent pstHAxes;
            if isempty(pstHAxes)
                pstHAxes = newHAxes;
            end
            hAxes = pstHAxes;
        end
    end
   
 
    
end
