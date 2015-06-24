classdef MainView < handle
    properties
        m_viewSize
        m_hFig
        m_topMenu
        m_playerPanel
       
        m_playOrPauseBtn
        m_fpsTitle
        m_fpsEdit
        m_frames
        m_totalFrames
        
        m_newAnnotaBtn
        m_deleteAnnotaBtn
        
        m_detAnnotaBtn
        
        m_trackAnnotaBtn 
        m_trackCheckBox
        m_trackFrmNumTitle
        m_trackFrmNumEdit
        
%         m_seqObj
        m_ctrlObj
        m_keyStatus = false(1,4)
        m_keyNames = {'rightarrow','leftarrow','d','v'}
        m_KEY
    end
    
    methods
        function obj = MainView()
            obj.m_viewSize = [100, 100, 640, 480];
%             obj.m_seqObj = seqObj;  
            obj.buildUI();
            obj.hotkeyInit();
            obj.m_ctrlObj = obj.makeController();                          %view class is response to generate controller
%             obj.m_seqObj.setCurFigAndAxes(obj.m_hFig, obj.m_playerPanel.hAx);
            obj.attachToController(obj.m_ctrlObj);                         %register the conponent's callback function
            
        end
       
        function buildUI(obj)
            obj.m_hFig = figure( 'Name','AnnotaSmart', 'NumberTitle','off', ...
      'Toolbar','auto', 'MenuBar','none',...
      'Color','w', 'Visible','on', 'Position',obj.m_viewSize);
           
           obj.layoutInit();
        end
        %layout init functions
        function layoutInit(obj)
            %bottom left,the origin is on the bottom left corner of the screen
            fig.x = obj.m_viewSize(1);
            fig.y = obj.m_viewSize(2);
            fig.w = obj.m_viewSize(3);
            fig.h = obj.m_viewSize(4);
            
            btn.w = 70;
            btn.h = 30;
            btn.starty = fig.h*0.93;
            btn.startx = fig.w*0.01;
            
            %top menu
            obj.m_topMenu.hFile = uimenu(obj.m_hFig, 'Label', 'File');
            obj.m_topMenu.hOpen = uimenu(obj.m_topMenu.hFile, 'Label', 'Open...');
            obj.m_topMenu.hSave = uimenu(obj.m_topMenu.hFile, 'Label', 'Save...');
            obj.m_topMenu.hNew = uimenu(obj.m_topMenu.hFile,  'Label', 'new...');
            
            obj.m_topMenu.hOpenVideo = uimenu(obj.m_topMenu.hOpen, 'Label', 'video');
            obj.m_topMenu.hOpenAnnotation = uimenu(obj.m_topMenu.hOpen,  'Label', 'annotation');
            obj.m_topMenu.hSaveAnnotation = uimenu(obj.m_topMenu.hSave, 'Label', 'annotation file');
            obj.m_topMenu.hNewAnnotationFile = uimenu(obj.m_topMenu.hNew,  'Label', 'annotation file'); 
            %the component coordinate is within the figure
            obj.m_newAnnotaBtn =  uicontrol('parent', obj.m_hFig, 'string', 'New object',...
                                'pos',[btn.startx, btn.starty,  btn.w,  btn.h]);
            obj.m_deleteAnnotaBtn = uicontrol('parent', obj.m_hFig, 'string', 'Delete object',...
                                'pos',[btn.startx + 75, btn.starty,  btn.w,  btn.h]);
            obj.m_detAnnotaBtn = uicontrol('parent', obj.m_hFig, 'string', 'detect',...
                                'pos',[btn.startx + 150, btn.starty,  btn.w - 35,  btn.h]);
            obj.m_trackAnnotaBtn = uicontrol('parent', obj.m_hFig, 'string', 'track',...
                                'pos',[btn.startx + 190, btn.starty,  btn.w - 35,  btn.h]);                
            obj.m_trackCheckBox = uicontrol('parent', obj.m_hFig, 'string', 'multiple target',...
                                'Style','checkbox','pos',[btn.startx + 230, btn.starty,  btn.w + 30,  btn.h]); 
            obj.m_trackFrmNumTitle = uicontrol('parent', obj.m_hFig, 'string', 'frames to track :',...
                                'Style','text','pos',[btn.startx + 330, btn.starty,  btn.w + 30,  btn.h]); 
            obj.m_trackFrmNumEdit = uicontrol('parent', obj.m_hFig, 'string', '20',...
                                'Style','edit','pos',[btn.startx + 365, btn.starty,  btn.w - 50,  btn.h - 15]);        
            obj.m_playOrPauseBtn = uicontrol('parent', obj.m_hFig, 'string', 'Play/Pause',...
                                'pos',[btn.startx + 435, btn.starty,  btn.w,  btn.h]);
            obj.m_fpsTitle = uicontrol('parent', obj.m_hFig, 'string', 'fps : ',...
                                'Style','text','pos',[btn.startx + 510, btn.starty,  btn.w - 20,  btn.h]); 
            obj.m_fpsEdit = uicontrol('parent', obj.m_hFig, 'string', '100',...
                                'Style','edit','pos',[btn.startx + 520, btn.starty,  btn.w - 40,  btn.h - 15]);                
            obj.m_frames = uicontrol('parent', obj.m_hFig, 'string', '',...
                                'Style','edit','pos',[btn.startx + 560, btn.starty,  btn.w - 50,  btn.h - 15], 'HorizontalAlignment','Left'); 
            obj.m_totalFrames = uicontrol('parent', obj.m_hFig, 'string', '',...
                                'Style','text','pos',[btn.startx + 580, btn.starty,  btn.w - 30,  btn.h - 15], 'HorizontalAlignment', 'Left'); 
            %panel
            % obj.m_playerPanel.h = uipanel('parent',obj.m_hFig,'BackgroundColor','black','Position', [.25 .1 .67 .67]);
             obj.m_playerPanel.hAx = axes('parent', obj.m_hFig, 'Position', [.10 .1 .80 .80]);

      
        end
        
        function enableBtn(obj, op)
            hs = [obj.m_playOrPauseBtn, obj.m_newAnnotaBtn,...
                obj.m_deleteAnnotaBtn,obj.m_trackAnnotaBtn, obj.m_detAnnotaBtn];
            set(hs,'Enable', op);     
        end
        function hotkeyInit(obj)
            obj.m_KEY.RIGHT = 1;
            obj.m_KEY.LEFT = 2;
            obj.m_KEY.DEL = 3;
            obj.m_KEY.V = 4;
        end
        
        %View is responsable for generating its controller
        function ctrlObj = makeController(obj)
            ctrlObj = AnnotaSmartController(obj);
        end
        
        function resizeFigFcn(obj, src, even)
            figSz = get(obj.m_hFig, 'position');
            ui = [obj.m_playOrPauseBtn,...
            obj.m_newAnnotaBtn, obj.m_deleteAnnotaBtn,...
            obj.m_trackAnnotaBtn, obj.m_trackCheckBox,...
            obj.m_trackFrmNumTitle, obj.m_trackFrmNumEdit,...
            obj.m_fpsTitle, obj.m_fpsEdit, obj.m_detAnnotaBtn];
            for i = 1:length(ui)
                posOld = get(ui(i),'pos');
                set(ui(i), 'position',[posOld(1), figSz(4)*0.93,...
                    posOld(3),posOld(4)]);
            end
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
            

            funcH = @controller.callback_trackAnnotaBtn;
            set(obj.m_trackAnnotaBtn, 'callback', funcH);
            
            funcH = @controller.callback_setTrackFrmNum;
            set(obj.m_trackFrmNumEdit, 'callback', funcH);
            
            funcH = @controller.callback_setCheckBox;
            set(obj.m_trackCheckBox, 'callback',funcH);
            
            funcH = @controller.keyPressFcn_hotkeyDown;
            set(obj.m_hFig, 'KeyPressFcn', funcH);
            
            funcH = @controller.keyReleaseFcn_hotkeyUp;
            set(obj.m_hFig, 'KeyReleaseFcn', funcH);
            %top menu call back
            funcH = @controller.callback_openVideo;
            set(obj.m_topMenu.hOpenVideo, 'callback', funcH);

            funcH = @controller.callback_openAnnotation;
            set(obj.m_topMenu.hOpenAnnotation, 'callback', funcH);

            funcH = @controller.callback_saveAnnotation;
            set(obj.m_topMenu.hSaveAnnotation, 'callback', funcH);
            
            funcH = @controller.callback_detectAnnotaBtn;
            set(obj.m_detAnnotaBtn, 'callback', funcH);
            
            funcH = @obj.resizeFigFcn;
            set(obj.m_hFig,'ResizeFcn', funcH);
%             funcH = @controller.callback_detectAnnotaBtn;
%             set(obj.m_topMenu.hNewAnnotationFile, 'callback', funcH);          
        end
        function delete()
            
        end
    end
end