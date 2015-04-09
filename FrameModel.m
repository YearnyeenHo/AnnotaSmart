classdef FrameModel < handle   
   %properties:
   %m_frameNum indicates which frame of the Video
   %m_objList is an array of objs that belong to this frame
    properties
        m_frameNum
        %confuse:Only record obj Id or record the whole obj?Should  update
        %the list obj'information after the concret obj change?
        %m_bbObjMap   %record the whole obj
        m_bbIdList = []                                                    %record the id and BBModel Obj id of objs that are within the frame
    end
    
    methods
        function obj = FrameModel(frmNum)
            obj.m_frameNum = frmNum;
            %obj.m_bbIdList = containers.Map;                               %mapObj = containers.Map constructs an empty Map container mapObj.
        end
        
        
        function registerObjId(obj, bbObj)
            obj.m_bbIdList = [obj.m_bbIdList, bbObj.m_objId];
        end
        
        function removeObjId(obj, bbObj)
            index = ~strcmp(obj.m_bbIdList ,bbObj.m_objId);
            obj.m_bbIdList = obj.m_bbIdList(index); 
        end
        
        %function registerMapObj(obj, bbObj)
        %    obj.m_bbObjMap = containers.Map(bbObj.m_objId, bbObj);
        %end
        
        %function removeMapObj(obj, bbObj) 
        %   remove(obj.m_bbObjMap, bbObj.m_objId);
        %end
        
    end
    
end

