classdef FrameModel < handle   

    properties
        m_bbList = []                                                    %record BBModel Obj that are within the frame
    end
    
    methods
        function obj = FrameModel()
        end
        function AddObj(obj, bbObj)
            obj.m_bbList = [obj.m_bbList, bbObj];
        end
        
        function removeObj(obj, bbObj)
            index = ~strcmp(obj.m_bbList ,bbObj);
            obj.m_bbList = obj.m_bbList(index); 
        end

        
    end
    
end

