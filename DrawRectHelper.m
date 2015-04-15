classdef DrawRectHelper < handle
    %helper 只要一个就可以了，可以重复工作;先耗点空间吧。
    properties
%         m_hpatch
%         m_hLine      %hBnd
        m_hFig
        m_curAxes %绘图的坐标系是hParent？
        m_hLines
        m_hPatch
        m_rectPos
        m_posChangeCallback
        m_posSetCallback
    end
    methods
        %加入读入文件，已有pos的话应该即刻设置并调用setPos，直接画出来即可
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
            
            obj.drawInit();%初始化绘图对象
            
            if ~isempty(obj.m_rectPos)
                updateRectPosAppearance();%从文件或已有数据读入，可以即刻画了
            else
                obj.initPosition();%产生一像素点可见
            end
            
            obj.setCallBackFcn();
        end
        
        function drawInit(obj)
            properties = {'color',color,'LineWidth',lwidth,'LineStyle',lstyle};
            if isempty(obj.m_rectPos)%假设是从文件中读入的
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
            obj.btnDown(); %类外，点击调用drawhelper，首次点击生成物体，还未绑定btnDown，先手工调用
            waitfor(obj.m_hFig,'WindowButtonUpFcn','');%等待第二次点击，点击后，没有点击相应但是会触发motion事件，将rect拉开
        end
        %%%%%%%%%%%%%%%%%%% btnDwn %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function btnDown(obj, src, event)
            if(isempty(obj.m_hLines) || isempty(obj.m_hPatch))
                return; 
            end
             if isempty(obj.m_rectPos)
                obj.createRectBox();%一个像素点可见
                cursor = 'botr';
             else %以后每次进来都先设置cursor
                 curPt = obj.getCurrentPt();
                 [~,cursor,~] = obj.getCursorDirection(curPt);
             end
            
            set( obj.m_hFig, 'Pointer', cursor );
            set( obj.m_hFig, 'WindowButtonMotionFcn',@drag);%立即给当前矩形绑定变形函数
            set( obj.m_hFig, 'WindowButtonUpFcn', @stopDrag );
            %第一次调用返回后，Initialize那边会有个wait等待第二次点击，一击为常见像素点大小的矩形，等待二击，drag 
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
            %对于一个像素点pos，设置patch，设置hLines中各个线段大小
            obj.updateRectPosAppearance()
            
            set(obj.m_hLines, 'Visible', 'on');%经过setPos（）的设置后，设置为visible on可见，此时，出现了一个像素点

        end
        
%         function resizeRect(obj)
%             curPt = obj.getCurrentPt(); 
%             [anchor,cursor,flag]=obj.getCursorDirection( curPt );%%getSide
%         end
        %%%%%%%%%%%%%%%%%%%% getSide %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %判断鼠标在Rect的位置，靠近中心点，就平移？四条边各不同
        %得到鼠标的样式cursor
        %改变flag，  % flag: -1: none, 0=resize; 1=drag;
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
            %从当前坐标系，获取最近一次点击的位置
            curPt=get(hAx,'CurrentPoint');%返回的结构是
            %x1 y1 1
            %x1 y1 0
            %所以取[1 3]，就是取了x1和y1
            curPt = curPt([1 3]);
        end
        
        %%%%%%%%%%%%%%%%%%%%%  drag  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %可能是平移或变形，处理后得到pos，它们最后都要调用setPos(pos)，
        %如果注册了posChangeCallback，还要手工调用!
        %最后drawnow %来update display
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
        %多次调用 set(obj.m_hPatch, 'Faces', face, 'Vertices',
        %vert);或那个line的，反正用的是同一个句柄，只是重新设值，就是这要刷新屏幕，还是原来的对象只是样子变了
        %就相当于重新画了
        function updateRectPosAppearance(obj)
            obj.setPatch(obj.m_rectPos)
            obj.setBoundaries()
        end
        function setPatch(obj, rectPos)
        % create invisible patch to captures key presses
            [xVector, yVector] = obj.rectPosToVerticesVec(rectPos);
            vert = [xVector yVector ones(4,1)]; 
            face=1:4;
            set(obj.m_hPatch, 'Faces', face, 'Vertices', vert);%是在建立patch？
        end
        
        function setBoundaries(obj)
            % draw rectangle boundaries and control circles
            for i=1:length(hBnds)
                indicesPair = mod([i-1 i],4)+1;%hBnd是一个句柄数组，放的是矩形4条line的句柄
                %Xdata是取值范围？想表示边长？获得xs(ids)可以表示一个区间
                set(obj.m_hLines(i), 'Xdata', xs(indicesPair), 'Ydata', ys(indicesPair));%xs(ids),默认取矩阵的第一列（不过xs也就只有一列）的某几个下标的元素，ids=[2 3]时就取第2、3个
                %构成第i条边的边上的点的x与y的区间
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