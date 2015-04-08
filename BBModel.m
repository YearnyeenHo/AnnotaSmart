
classdef BBModel < handle
%Matlab buid-in handle base class already defined default delete method    
    properties
        m_objId
        %save frameNum and objPos as key-value pair in containers.Map,as
        %tracking info
        m_posPerFramesMap
        
    end
    
    methods
        function obj = BBModel()
            obj.m_objId = BBModel.increaseAndGetIdCounter();
        end
        function id = getObjId(obj)
            id = obj.m_objId;
        end
        function setPosPerFramesMap(obj, frmNum, pos)
            obj.m_posPerFramesMap = containers.Map(num2str(frmNum),pos);
        end
        %get the position of the obj in a specific frame
        function pos = getPosInFrameN(obj, frmNum)
            pos = obj.m_posPerFramesMap(num2str(frmNum));
        end
        %register To a new Frame that in the map
        function registerToFrame(obj, frmNum)
            frmNum.addObj(obj);
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
        
    end
    
end
