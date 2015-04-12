
classdef BBModel < handle
    properties(Access = private)
        m_objId
        m_pos = zeros(1,4)
    end
    
    methods
        function obj = BBModel()
            obj.m_objId = BBModel.increaseAndGetIdCounter();   
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
    
end
