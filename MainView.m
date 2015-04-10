classdef MainView < handle
    properties
        m_viewSize
        m_hFig
        m_topMenu
        
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
            obj.m_hFig = figure( 'Name','AnnotaSmart', 'NumberTitle','off', ...
      'Toolbar','auto', 'MenuBar','none',...
      'Color','w', 'Visible','on', 'Position',obj.m_viewSize);
           
           obj.menuInit(obj.m_hFig);
  
  
  
  
  
            fig.x = obj.m_viewSize(1);%bottom left,the origin is on the bottom left corner of the screen
            fig.y = obj.m_viewSize(2);
            fig.w = obj.m_viewSize(3);
            fig.h = obj.m_viewSize(4);
            %the component coordinate is within the figure
            obj.m_playOrPauseBtn = uicontrol('parent', obj.m_hFig, 'string', 'Play/Pause',...
                                'pos',[fig.w*0.5 - 30, fig.h*0.1, 60, 30]);
            obj.m_newAnnotaBtn =  uicontrol('parent', obj.m_hFig, 'string', 'New object',...
                                'pos',[fig.w*0.2, fig.h*0.9, 70, 30]);
            obj.m_deleteAnnotaBtn = uicontrol('parent', obj.m_hFig, 'string', 'Delete object',...
                                'pos',[fig.w*0.2 + 75, fig.h*0.9, 70, 30]);
            obj.m_detectAnnotaBtn = uicontrol('parent', obj.m_hFig, 'string', 'Detect object',...
                                'pos',[fig.w*0.2 + 150, fig.h*0.9, 70, 30]);
        end
        %layout init functions
        function menuInit(obj, hFig)
            obj.m_topMenu.hFile = uimenu(hFig, 'Label', 'File');
            obj.m_topMenu.hOpen = uimenu(obj.m_topMenu.hFile, 'Label', 'Open...');
            obj.m_topMenu.hSave = uimenu(obj.m_topMenu.hFile, 'Label', 'Save...');
            obj.m_topMenu.hNew = uimenu(obj.m_topMenu.hFile,  'Label', 'new...');
            
            obj.m_topMenu.hVideo = uimenu(obj.m_topMenu.hOpen, 'Label', 'video');
            obj.m_topMenu.hAnnotation = uimenu(obj.m_topMenu.hOpen,  'Label', 'annotation');
            obj.m_topMenu.hSaveAnnotation = uimenu(obj.m_topMenu.hSave, 'Label', 'annotation file');
            obj.m_topMenu.hNewAnnotationFile = uimenu(obj.m_topMenu.hNew,  'Label', 'annotation file');   
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