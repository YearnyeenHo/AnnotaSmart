classdef FrameModel < handle   

    properties
        m_bbMap                                      %record BBModel Obj that are within the frame
    end
    
    methods
        function obj = FrameModel()
            obj.m_bbMap = containers.Map;
        end
        
        function addObj(obj, bbObj)
            obj.m_bbMap(num2str(bbObj.getObjId())) = bbObj;
        end
        
        function bbObj = getObj(obj, bbId)
            bbObj = [];
            if bbId <= 0 || obj.m_bbMap.Count == 0
                return;
            end   
           bbObj = obj.m_bbMap(num2str(bbId));
        end
        
        function removeObj(obj, bbId)
            if obj.m_bbMap.Count <= 0
                return;
            end
            if ~isKey(obj.m_bbMap,num2str(bbId))
                return;
            end
             bbObj = obj.m_bbMap(num2str(bbId));
             bbObj.delete();
            remove(obj.m_bbMap, num2str(bbId));
        end
        
        function removeAllbb(obj)
            if obj.m_bbMap.Count <= 0
                return;
            end
            keySet = keys(obj.m_bbMap);
            len = length(keySet);
            for i = 1:len
               strId = keySet{i};
               obj.removeObj(strId);
            end
        end
        
    end
    
end

