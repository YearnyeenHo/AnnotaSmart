classdef AnnotaSmartController    
    properties
        m_viewObj
        m_seqObj
        %m_bbObj
        %m_frameObj
    end
    
    methods
        function obj = AnnotaSmartController(viewObj, seqObj)
           obj.m_viewObj = viewObj;
           obj.m_seqObj = seqObj;
        end
        
        function callback_playOrPauseBtn(obj, src, event)
           if obj.seqObj.getStatus()
               obj.seqObj.seqPause();
           else
               obj.seqObj.seqPlay();
           end
        end
        
        function callback_newAnnotaBtn(obj, src, event)
        end
        
        function callback_deleteAnnotaBtn(obj, src, event)
        end
        
        function callback_detectAnnotaBtn(obj, src, event)
        end
        
    end
    
end

