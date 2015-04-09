
classdef BBModel < handle
%Matlab buid-in handle base class already defined default delete method 
%Observer Pattern
    properties
        m_objId
        %save frameNum and objPos as key-value pair in containers.Map,as
        %tracking info
        m_posPerFramesMap
        
    end
    
    methods
        function obj = BBModel()
            obj.m_objId = BBModel.increaseAndGetIdCounter();
            obj.m_posPerFramesMap = containers.Map;                        %constructs an empty Map container mapObj
        end
        function id = getObjId(obj)
            id = obj.m_objId;
        end
        %register To a new Frame that in the map,the key is frmNum and
        %value is objPos
        function RgistFrmToMap(obj, objFrm, pos)
            obj.m_posPerFramesMap(num2str(objFrm.m_frameNum)) = pos;       %Add a Single Value and Key to a Map
            objFrm.registerMapObj(obj);                                    %Add its record into a frame
        end
       
        %remove observer frame from map : remove(mapObj, key)
        function RemoveFrmFromMap(obj, objFrm)
            remove(obj.m_posPerFramesMap, num2str(objFrm.m_frameNum));
            objFrm.removeMapObj(obj);                                      %remove its record from a frame
        end
        
        function SetPosInFrm(obj, objFrm, newpos)
            obj.m_posPerFramesMap(num2str(objFrm)) = newpos;
        end
     
        %get the position of the obj in a specific frame
        function pos = getPosInFrameN(obj, frmNum)
            pos = obj.m_posPerFramesMap(num2str(frmNum));
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
