classdef FrameModel < handle   
   %properties:
   %m_frameNum indicates which frame of the Video
   %m_objList is an array of objs that belong to this frame
    properties
        m_frameNum
        m_objMap                    %record the id and pos of objs that are within the frame
    end
    
    methods
        function obj = FrameModel(frmNum)
            obj.m_frameNum = frmNum;
            obj.m_objMap
        end
        
        function registerObj(obj, bbObj)
            len = length(obj.m_objList);
            obj.m_objList(len+1) = bbObj;
        end
        function removeObserver(obj, bbObj)
            %find the index of bbObj 
            
        end
    end
    
end

