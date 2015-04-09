classdef MainView < handle
    properties
        m_viewSize
        m_hfig
        m_playCanvas
        m_playOrPauseBtn
        m_newAnnotaBtn
        m_deleteAnnotaBtn
        m_detectAnnotaBtn
        %m_bbObj
        %m_frmObj
        m_seqObj
        m_ctrlObj
    end
    
    methods
        function obj = MainView(seqObj)
            obj.m_viewSize = [100, 100, 640, 480];
            obj.m_seqObj = seqObj;
            %register callback function
            obj.m_seqObj.addlistener('playStatusChange',@obj.playStatusChange);
            %obj.m_playCanvas.addlistener('updateAnnotations', @obj.updateAnnotations);
            obj.buildUI();
            obj.m_ctrlObj = obj.makeController();                          %view class is response to generate controller
            obj.attachToController(obj.m_ctrlObj);                         %register the conponent's callback function
        end
        
        function buildUI(obj)
            obj.m_hfig = figure('pos', obj.m_viewSize);
            fig.x = obj.m_viewSize(1);%bottom left,the origin is on the bottom left corner of the screen
            fig.y = obj.m_viewSize(2);
            fig.w = obj.m_viewSize(3);
            fig.h = obj.m_viewSize(4);
            %the component coordinate is within the figure
            obj.m_playOrPauseBtn = uicontrol('parent', obj.m_hfig, 'string', 'Play/Pause',...
                                'pos',[fig.w*0.5 - 30, fig.h*0.1, 60, 30]);
            obj.m_newAnnotaBtn =  uicontrol('parent', obj.m_hfig, 'string', 'New object',...
                                'pos',[fig.w*0.2, fig.h*0.9, 70, 30]);
            obj.m_deleteAnnotaBtn = uicontrol('parent', obj.m_hfig, 'string', 'Delete object',...
                                'pos',[fig.w*0.2 + 75, fig.h*0.9, 70, 30]);
            obj.m_detectAnnotaBtn = uicontrol('parent', obj.m_hfig, 'string', 'Detect object',...
                                'pos',[fig.w*0.2 + 150, fig.h*0.9, 70, 30]);
        end
        %update the annotations in the frame
        function updateAnnotations(obj)
        end
        function playStatusChange(obj)
        end
        %View is responsable for generating its controller
        function ctrlObj = makeController(obj)
            ctrlObj = AnnotaSmartController(obj, obj.m_seqObj);
        end
        %after controller'construction
        function attachToController(obj, controller)
            funcH = @controller.callback_playOrPauseBtn;
            %register callback function
            set(obj.m_playOrPauseBtn, 'callback', funcH);
            
            funcH = @controller.callback_newAnnotaBtn;
            set(obj.m_newAnnotaBtn, 'callback', funcH);
            
            funcH = @controller.callback_deleteAnnotaBtn;
            set(obj.m_deleteAnnotaBtn, 'callback', funcH);
            
            funcH = @controller.callback_detectAnnotaBtn;
            set(obj.m_detectAnnotaBtn, 'callback', funcH);
        end
        
    end
end