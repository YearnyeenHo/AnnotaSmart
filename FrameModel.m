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
           bbObj = obj.m_bbMap(num2str(bbId));
        end
        
        function removeObj(obj, bbId)
            bbObj = obj.m_bbMap(num2str(bbId));
            bbObj.delete();
            remove(obj.m_bbMap, num2str(bbId));
        end
        
    end
    
end

