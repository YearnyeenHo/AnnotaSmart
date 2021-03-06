classdef DrawRectHelper < handle
    %helper 只要一个就可以了，可以重复工作;先耗点空间吧。
    properties
        m_hFig
        m_curAxes %绘图的坐标系是hParent？
        m_hLines
        m_hPatch
        m_rectPos
        m_posChangeCallback
        m_posSetCallback
        m_selectedCallback
    end
    methods
        %加入读入文件，已有pos的话应该即刻设置并调用setPos，直接画出来即可
        function obj = DrawRectHelper(hFig, curAxes, id, rectPos, setPosFunc, selectedFunc)
            drawhelperNew = 'drawHelper construct!' 
            if isempty(curAxes) || isempty(hFig)
                error('handle empty');
            end
            
            obj.m_hFig = hFig;
            obj.m_curAxes = curAxes;
            
            if nargin >= 3
                obj.m_rectPos = rectPos;
            end
            
            obj.setInstanceCallbackFcn(setPosFunc, selectedFunc);
            
            %if get(obj.m_hFig, 'CurrentAxes') ~= curAxes
                set( obj.m_hFig, 'CurrentAxes', curAxes );
            %end
            
            obj.drawInit(id);%初始化绘图对象
            
            if ~isempty(obj.m_rectPos)
                obj.updateRectPosAppearance();%从文件或已有数据读入，可以即刻画了
            else
                obj.initPosition();%产生一像素点可见
            end
            
            obj.setCallBackFcn();
        end
        
        function drawInit(obj, id)
            color = DrawRectHelper.rectColor(id);
            lwidth = 2;
            lstyle = '-';
            properties = {'color', color, 'LineWidth', lwidth, 'LineStyle', lstyle};
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
%             color = DrawRectHelper.randColor();
            obj.m_hPatch=patch('FaceColor', color, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        end
        
        function setInstanceCallbackFcn(obj, setPosFunc, selectedFunc)
            obj.setPosSetCallback(setPosFunc);
            obj.setSelectedCallback(selectedFunc);
        end
        
        function setCallBackFcn(obj)
            % set callbacks on all objects
            set(obj.m_hPatch, 'ButtonDownFcn', @obj.btnDown, 'DeleteFcn', @obj.deleteFcn);
            set(obj.m_hLines, 'ButtonDownFcn', @obj.btnDown, 'DeleteFcn', @obj.deleteFcn);
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
                anchor = [1, 1];
                op = 'resize';
             else %以后每次进来都先设置cursor
                curPt = obj.getCurrentPt();
                [anchor, cursor, op] = obj.getCursorDirection(curPt);
             end
            if ~isempty(obj.m_selectedCallback)
                obj.m_selectedCallback();
            end
            set( obj.m_hFig, 'Pointer', cursor );
            set( obj.m_hFig, 'WindowButtonMotionFcn',{@obj.drag, anchor, op});%立即给当前矩形绑定变形函数
            set( obj.m_hFig, 'WindowButtonUpFcn', @obj.stopDrag );
            %第一次调用返回后，Initialize那边会有个wait等待第二次点击，一击为常见像素点大小的矩形，等待二击，drag 
        end
        function createRectBox(obj)
            if(isempty(obj.m_rectPos))
                anchor=ginput(1);%axes origin is top left
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
        %%%%%%%%%%%%%%%%%%%% getSide %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %判断鼠标在Rect的位置，靠近中心点，就平移？四条边各不同
        %得到鼠标的样式cursor
        %改变flag，  % flag: -1: none, 0=resize; 1=drag;
        function [anchor,cursor,op] = getCursorDirection(obj, curPt)
            [centerPt, radius] = DrawRectHelper.getCenterPtAndRads(obj.m_rectPos);
            k = radius/3;
            dirFlag = zeros(1,2);
            for i = 1:2
                if curPt(i) < (centerPt(i) - radius(i) + k(i))%lf/tp
                    dirFlag(i) = -1;
                elseif curPt(i) > (centerPt(i) + radius(i) - k(i))%/rt/bt
                    dirFlag(i) = 1;
                end
            end
            opVec = {'resize', 'translation'};
            cursorMatrix = {'topl','left','botl';'bottom','fleur','top';'topr','right','botr'};
            index = dirFlag + 2;
            cursor = cursorMatrix{index(1),index(2)};
            if strcmp(cursor,'fleur')
                op = opVec{2};
                anchor = curPt;
            else
                anchor = dirFlag;
                op = opVec{1};
            end
        end
        function curPt = getCurrentPt(obj)
            %从当前坐标系，获取最近一次点击的位置
            %the axes origin is on top left!!!
            curPt=get(obj.m_curAxes,'CurrentPoint');
            %返回的结构是
            %x1 y1 1
            %x1 y1 0
            %所以取[1 3]，就是取了x1和y1
            curPt = curPt([1 3]);
        end
        %%%%%%%%%%%%%%%%%%%%%  drag  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %可能是平移或变形，处理后得到pos，它们最后都要调用setPos(pos)，
        %如果注册了posChangeCallback，还要手工调用!
        %最后drawnow %来update display
        function drag(obj, src, event, anchor, op)
            curPt = obj.getCurrentPt();
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
        end
        
        function DragToTranslation(obj, curPt)
            
            [centerPt,~] = DrawRectHelper.getCenterPtAndRads(obj.m_rectPos);
            obj.m_rectPos = [obj.m_rectPos(1:2)+(curPt - centerPt) obj.m_rectPos(3:4)];
        end
        
        function DragToResize(obj, anchor, curPt)
            [centerPt, radius] = DrawRectHelper.getCenterPtAndRads(obj.m_rectPos);
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
            obj.rPtToRectPos(rPtMin, rPtMax);
        end
    
        function stopDrag(obj, src, event)
            set( obj.m_hFig, 'Pointer', 'arrow' );
            set( obj.m_hFig, 'WindowButtonMotionFcn','');
            set( obj.m_hFig, 'WindowButtonUpFcn','');
            set( obj.m_hFig, 'WindowButtonDownFcn','');
            if ~isempty(obj.m_posSetCallback)
                obj.m_posSetCallback(obj.m_rectPos); 
            end;
        end
        %%%%%%%%%%%%%%%%%%%%% cornerToRect %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function rPtToRectPos(obj,rPta, rPtb)
            [centerPt, ~] = DrawRectHelper.getCenterPtAndRads(obj.m_rectPos);
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
            obj.setPatch(obj.m_rectPos);
            obj.setBoundaries();
            drawnow;
        end
        
        function setPatch(obj, rectPos)
        % create invisible patch to captures key presses
            [xVector, yVector] = DrawRectHelper.rectPosToVerticesVec(rectPos);
            vert = [xVector yVector ones(4,1)]; 
            face=1:4;
            set(obj.m_hPatch, 'Faces', face, 'Vertices', vert);%是在建立patch？
        end
        
        function setBoundaries(obj)
            % draw rectangle boundaries and control circles
            for i=1:length(obj.m_hLines)
                indicesPair = mod([i-1 i],4)+1;%hBnd是一个句柄数组，放的是矩形4条line的句柄
                %Xdata是取值范围？想表示边长？获得xs(ids)可以表示一个区间
                [xVector, yVector] = DrawRectHelper.rectPosToVerticesVec(obj.m_rectPos);
                set(obj.m_hLines(i), 'Xdata', xVector(indicesPair), 'Ydata', yVector(indicesPair));%xs(ids),默认取矩阵的第一列（不过xs也就只有一列）的某几个下标的元素，ids=[2 3]时就取第2、3个
                %构成第i条边的边上的点的x与y的区间
             end
        end
        
        function setPosAndUpdateAppearance(obj, pos)
            obj.m_rectPos = pos;
            obj.updateRectPosAppearance();
        end
        
        function deleteFcn(obj, src, event)
            hdls = {obj.m_hLines, obj.m_hPatch, obj.m_posChangeCallback, obj.m_posSetCallback};
            for i = 1:length(hdls)
                if ishandle(hdls{i})
                    delete(hdls{i});
                end
            end
             hdls = deal([]);
             obj.m_hFig = [];
             obj.m_curAxes = [];
             obj.m_rectPos = [];
        end
        function delete(obj)
            obj.deleteFcn()
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        function setPosChangeCallback(obj, func)
            obj.m_posChangeCallback = func; 
        end

        function setPosSetCallback(obj, func)
            obj.m_posSetCallback = func; 
        end
        
        function setSelectedCallback(obj, func)
            obj.m_selectedCallback = func;
        end
    end
    
    methods(Static)
        function color = rectColor(id)
            colorVec = ['y', 'b', 'g','r', 'c', 'm'];
%             index = 0;
%             while index < 1
%                index = round((rand()*10)/2);
%             end
            index = mod(id, length(colorVec)) + 1;
            color = colorVec(index);
        end
        function [xVector, yVector] = rectPosToVerticesVec(rectPos)
           xVector = [rectPos(1) rectPos(1)+rectPos(3) rectPos(1)+rectPos(3) rectPos(1)]';
           yVector = [rectPos(2) rectPos(2) rectPos(2)+rectPos(4) rectPos(2)+rectPos(4)]'; 
        end
        function [centerPt,radius] = getCenterPtAndRads(rectPos)
            radius = rectPos(3:4)/2;
            cx = rectPos(1) + radius(1);
            cy = rectPos(2) + radius(2);
            centerPt = [cx cy];
        end
    end
end