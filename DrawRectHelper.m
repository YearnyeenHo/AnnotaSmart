classdef DrawRectHelper < handle
    %helper ֻҪһ���Ϳ����ˣ������ظ�����;�Ⱥĵ�ռ�ɡ�
    properties
%         m_hpatch
%         m_hLine      %hBnd
        m_hFig
        m_curAxes %��ͼ������ϵ��hParent��
        m_hLines
        m_hPatch
        m_rectPos
        m_posChangeCallback
        m_posSetCallback
    end
    methods
        %��������ļ�������pos�Ļ�Ӧ�ü������ò�����setPos��ֱ�ӻ���������
        function obj = DrawRectHelper(hFig, curAxes, rectPos)
            if isempty(curAxes) || isempty(hFig)
                error('handle empty');
            end
            
            obj.m_hFig = hFig;
            obj.m_curAxes = curAxes;
            
            if nargin == 3
                obj.m_rectPos = rectPos;
            end
            
            if get(obj.m_hFig, 'CurrentAxes') ~= hAx
                set( obj.m_hFig, 'CurrentAxes', hAx );
            end
            
            obj.drawInit();%��ʼ����ͼ����
            
            if ~isempty(obj.m_rectPos)
                updateRectPosAppearance();%���ļ����������ݶ��룬���Լ��̻���
            else
                obj.initPosition();%����һ���ص�ɼ�
            end
            
            obj.setCallBackFcn();
        end
        
        function drawInit(obj)
            properties = {'color',color,'LineWidth',lwidth,'LineStyle',lstyle};
            if isempty(obj.m_rectPos)%�����Ǵ��ļ��ж����
             visible='off'; 
            else
             visible='on'; 
            end
            %create lines
            for i=1:4
                obj.m_hLines(i)=line(properties{:},'Visible',visible); 
            end
            %create patch    
            obj.m_hPatch=patch('FaceColor','g','FaceAlpha',0.1,'EdgeColor','none');
        end
        
        function setCallBackFcn(obj)
            % set callbacks on all objects
            set(obj.m_hPatch, 'ButtonDownFcn', @btnDown, 'DeleteFcn', @deleteFcn);
            set(obj.m_hLines, 'ButtonDownFcn', @btnDown, 'DeleteFcn', @deleteFcn);
        end
        
        function initPosition(obj)
            % set or query initial position
            obj.btnDown(); %���⣬�������drawhelper���״ε���������壬��δ��btnDown�����ֹ�����
            waitfor(obj.m_hFig,'WindowButtonUpFcn','');%�ȴ��ڶ��ε���������û�е����Ӧ���ǻᴥ��motion�¼�����rect����
        end
        %%%%%%%%%%%%%%%%%%% btnDwn %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function btnDown(obj, src, event)
            if(isempty(obj.m_hLines) || isempty(obj.m_hPatch))
                return; 
            end
             if isempty(obj.m_rectPos)
                obj.createRectBox();%һ�����ص�ɼ�
                cursor = 'botr';
             else %�Ժ�ÿ�ν�����������cursor
                 curPt = obj.getCurrentPt();
                 [~,cursor,~] = obj.getCursorDirection(curPt);
             end
            
            set( obj.m_hFig, 'Pointer', cursor );
            set( obj.m_hFig, 'WindowButtonMotionFcn',@drag);%��������ǰ���ΰ󶨱��κ���
            set( obj.m_hFig, 'WindowButtonUpFcn', @stopDrag );
            %��һ�ε��÷��غ�Initialize�Ǳ߻��и�wait�ȴ��ڶ��ε����һ��Ϊ�������ص��С�ľ��Σ��ȴ�������drag 
        end
        function createRectBox(obj)
            if(isempty(obj.m_rectPos))
                anchor=ginput(1);
            else
                anchor=obj.m_rectPos(1:2);
            end
            obj.m_rectPos=[anchor 1 1];
            if ~isempty(obj.m_posSetCallback)
                obj.m_posSetCallback(obj.m_rectPos);
            end
            %����һ�����ص�pos������patch������hLines�и����߶δ�С
            obj.updateRectPosAppearance()
            
            set(obj.m_hLines, 'Visible', 'on');%����setPos���������ú�����Ϊvisible on�ɼ�����ʱ��������һ�����ص�

        end
        
%         function resizeRect(obj)
%             curPt = obj.getCurrentPt(); 
%             [anchor,cursor,flag]=obj.getCursorDirection( curPt );%%getSide
%         end
        %%%%%%%%%%%%%%%%%%%% getSide %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %�ж������Rect��λ�ã��������ĵ㣬��ƽ�ƣ������߸���ͬ
        %�õ�������ʽcursor
        %�ı�flag��  % flag: -1: none, 0=resize; 1=drag;
        function [anchor,cursor,op] = getCursorDirection(obj, curPt)
            [centerPt, radius] = obj.getCenterPtAndRads(obj.m_rectPos);
            k = radius/3;
            dirFlag = zeros(1,2);
            for i = 1:2
                if curPt(i) < (centerPt(i) - radius(i) + k)%lf/bt
                    dirFlag(i) = -1;
                elseif curPt(i) > (centerPt(i) + radius(i) - k)%/rt/tp
                    dirFlag(i) = +1;
                end
            end
            opVec = ['resize', 'translation'];
            cursorMatrix = {'topl','top','topr';'left','fleur','right';'botl','bottom','botr'};
            index = dirFlag+2;
            cursor = cursorMatrix(index(1),index(2));
            if strcmp(cursor,'fleur')
                op = opVec(2);
                anchor = curPt;
            else
                op = opVec(1);
            end
        end
        
        function [centerPt,radius] = getCenterPtAndRads(obj, rectPos)
            radius = rectPos(3:4)/2;
            cx = rectPos(1) + radius(1);
            cy = rectPos(2) + radius(2);
            centerPt = [cx cy];
        end
        function curPt = getCurrentPt(obj)
            %�ӵ�ǰ����ϵ����ȡ���һ�ε����λ��
            curPt=get(hAx,'CurrentPoint');%���صĽṹ��
            %x1 y1 1
            %x1 y1 0
            %����ȡ[1 3]������ȡ��x1��y1
            curPt = curPt([1 3]);
        end
        
        %%%%%%%%%%%%%%%%%%%%%  drag  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %������ƽ�ƻ���Σ������õ�pos���������Ҫ����setPos(pos)��
        %���ע����posChangeCallback����Ҫ�ֹ�����!
        %���drawnow %��update display
        function drag(obj)
            curPt = obj.getCurrentPt();
            [anchor,~,op] = obj.getCursorDirection(curPt);
            if strcmp(op,'translation')
                obj.DragToTranslation(curPt);
            else
                obj.DragToResize(anchor, curPt);
            end
            %callback
            if ~isempty(obj.m_posChangeCallback)
                obj.m_posChangeCallback(obj.m_rectPos);
            end
            
            obj.updateRectPosAppearance();%setPos
            drawnow;
        end
        
        function DragToTranslation(obj, lastPt)
            
            latestPt = obj.getCurrentPt();
            obj.m_rectPos = [obj.m_rectPos(1:2)+(latestPt - lastPt) obj.m_rectPos(3:4)];
        end
        
        function DragToResize(obj, anchor, curPt)
            [centerPt, radius] = obj.getCenterPtAndRads(obj.m_rectPos);
            distance = curPt - centerPt;
            rPtMin = -radius;
            rPtMax = radius;
            for i = 1:2
                if anchor(i) > 0      
                    rPtMax(i) = distance(i);
                elseif anchor(i) < 0
                    rPtMin(i) = distance(i);
                end
            end
            obj.rPtToRectPos(obj, rPtMin, rPtMax);
        end
        
        function stopDrag(obj)
            set( hFig, 'Pointer', 'arrow' );
            set( hFig, 'WindowButtonMotionFcn','');
            set( hFig, 'WindowButtonUpFcn','');
            if ~isempty(obj.m_posSetCallback)
                obj.m_posSetCallback(obj.m_rectPos); 
            end;
        end
        %%%%%%%%%%%%%%%%%%%%% cornerToRect %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function rPtToRectPos(obj,rPta, rPtb)
            [centerPt, ~] = obj.getCenterPtAndRads(obj.m_rectPos);
            tempPt = min(rPta, rPtb);
            rPtb = max(rPta, rPtb);
            rPta = tempPt;
            rPta = centerPt + rPta;
            rPtb = centerPt + rPtb;
            centerPt = (rPta + rPtb)/2;
            radius = (rPtb - rPta)/2;
            bottomLeftPt = centerPt - radius;
            obj.m_rectPos = [bottomLeftPt 2*radius];     
        end

        %%%%%%%%%%%%%%%%%%%%% setPos %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %��ε��� set(obj.m_hPatch, 'Faces', face, 'Vertices',
        %vert);���Ǹ�line�ģ������õ���ͬһ�������ֻ��������ֵ��������Ҫˢ����Ļ������ԭ���Ķ���ֻ�����ӱ���
        %���൱�����»���
        function updateRectPosAppearance(obj)
            obj.setPatch(obj.m_rectPos)
            obj.setBoundaries()
        end
        function setPatch(obj, rectPos)
        % create invisible patch to captures key presses
            [xVector, yVector] = obj.rectPosToVerticesVec(rectPos);
            vert = [xVector yVector ones(4,1)]; 
            face=1:4;
            set(obj.m_hPatch, 'Faces', face, 'Vertices', vert);%���ڽ���patch��
        end
        
        function setBoundaries(obj)
            % draw rectangle boundaries and control circles
            for i=1:length(hBnds)
                indicesPair = mod([i-1 i],4)+1;%hBnd��һ��������飬�ŵ��Ǿ���4��line�ľ��
                %Xdata��ȡֵ��Χ�����ʾ�߳������xs(ids)���Ա�ʾһ������
                set(obj.m_hLines(i), 'Xdata', xs(indicesPair), 'Ydata', ys(indicesPair));%xs(ids),Ĭ��ȡ����ĵ�һ�У�����xsҲ��ֻ��һ�У���ĳ�����±��Ԫ�أ�ids=[2 3]ʱ��ȡ��2��3��
                %���ɵ�i���ߵı��ϵĵ��x��y������
             end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [xVector, yVector] = rectPosToVerticesVec(obj, rectPos)
           xVector = [rectPos(1) rectPos(1)+rectPos(3) rectPos(1)+rectPos(3) rectPos(1)];
           yVector = [rectPos(2) rectPos(2) rectPos(1)+rectPos(4) rectPos(1)+rectPos(4)]; 
        end
        
        function setPosChangeCallback(obj, func)
            obj.m_posChangeCallback = func; 
        end

        function setPosSetCallback(obj, func)
            obj.m_posSetCallback = func; 
        end
    end
end