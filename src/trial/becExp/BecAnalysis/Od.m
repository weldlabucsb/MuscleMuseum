classdef Od < BecAnalysis
    %OD Calculate and plot optical depth
    %   Detailed explanation goes here

    properties (Transient)
        RoiData double % Raw RoiData, including atom/light/dark.
        CameraLightData double % For calculating cross section. Background subtracted. Fringe removed.
        OdData double % Calculated OdData
        ImageRatio double % Calculated Ratio of post-subtracted Atom and Light Imaging for PCI
    end

    properties
        FringeRemovalMethod string = "LSR" % Least square regression
        FringeRemovalMask double % 2*N array. First column is y coordinate. Second column is x coordinate.
        Colormap = jet
    end

    properties (SetObservable)
        CLim double = [0,4]
    end

    methods
        function obj = Od(becExp)
            %OD Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Gui(1) = Gui(...
                name = "OdPreviewer",...
                fpath = fullfile(becExp.DataAnalysisPath,"Od"),...
                loc = [0.003125,0.387037037],...
                size = [0.38984375,0.587037], ...
                isEnabled = false...
                );
            obj.Gui(2) = Gui(...
                name = "FringeRemoval",...
                fpath = fullfile(becExp.DataAnalysisPath,"FringeRemoval"),...
                loc = "center",...
                size = "large",...
                isEnabled = false...
                );
            obj.Chart(1) = Chart(...
                name = "OdMix",...
                num = 22, ...
                fpath = fullfile(becExp.DataAnalysisPath,"OdMix"),...
                loc = "center",...
                size = "full",...
                isEnabled = false...
                );
            obj.Chart(2) = Chart(...
                name = "OdAnimation",...
                num = 23, ...
                fpath = fullfile(becExp.DataAnalysisPath,"OdAnimation"),...
                loc = "center",...
                size = "large",...
                isGif = true,...
                isEnabled = false...
                );
        end
    end

    methods

        function initialize(obj)
            % Initialize matrices
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            obj.RoiData = zeros([roiSize,1,3]);
            obj.OdData = zeros([roiSize,1]);
            obj.ImageRatio = zeros([roiSize,1]);
            obj.CameraLightData = zeros([roiSize,1]);

            obj.Gui(1).initialize(obj.BecExp) % invoke OdPreviewer
            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
        end

        function update(obj,runIdx)
            becExp = obj.BecExp;
            if ~isempty(becExp.TempData)
                % Read RoiData from camera
                obj.RoiData(:,:,runIdx,:) = becExp.Roi.select(becExp.TempData);
            else
                % Read Roidata from file
                obj.RoiData(:,:,runIdx,:) = becExp.Roi.select(becExp.readRun(runIdx));
            end

            % Update OD without fringe removal
            obj.OdData(:,:,runIdx) = absorption2Od(computeAbsorption(obj.RoiData(:,:,runIdx,:)));
            obj.ImageRatio(:,:, runIdx) = computeAbsorption(obj.RoiData(:,:,runIdx,:));

            % Update OdPreviewer
            obj.Gui(1).update;

            % Update camera light data
            obj.CameraLightData(:,:,runIdx) = obj.RoiData(:,:,runIdx,2) - obj.RoiData(:,:,runIdx,3);
        end

        function finalize(obj)
            obj.doFringeRemoval
            obj.plotOdMix
            obj.plotOdAnimation
        end

        function show(obj)
            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
            obj.Gui(1).initialize(obj.BecExp)
            obj.Chart(1).show
            obj.Chart(2).show
        end

        function refresh(obj)
            becExp = obj.BecExp;
            becExp.TempData = [];
            roi = becExp.Roi;
            roiSize = roi.CenterSize(3:4);
            nRun = becExp.NCompletedRun;

            if isempty(obj.Gui(1).App) || ~isvalid(obj.Gui(1).App)
                obj.Gui(1).initialize(obj.BecExp)
            else
                obj.Gui(1).update
            end

            obj.RoiData = becExp.readRunRoi(1:nRun);

            % Redo ploting
            obj.finalize;
        end

        function doFringeRemoval(obj)
            %% First calculate atom and light with background subtraction
            atom = obj.RoiData(:,:,:,1) - obj.RoiData(:,:,:,3);
            light = obj.RoiData(:,:,:,2) - obj.RoiData(:,:,:,3);
            OdBefore = absorption2Od(computeAbsorption(cat(4,atom,light))); % OdBefore fringe removal
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            ImageRatioBefore= computeAbsorption(cat(4,atom,light)); % Computes Atom/Light

            %% Do fringe romoval if the mask and the method are given
            if (~isempty(obj.FringeRemovalMask)) && obj.FringeRemovalMethod ~= "None"
                mask = obj.BecExp.Roi.createMask(obj.FringeRemovalMask);
                switch obj.FringeRemovalMethod
                    case "LSR"
                        % Least square regression
                        atom = reshape(atom,[],size(atom,3));
                        light = reshape(light,[],size(light,3));
                        mask = mask(:);

                        c = lsqminnorm(light(mask,:)'*light(mask,:),light(mask,:)'*atom(mask,:));
                        light = light * c;
                        [~, Rtest, ~]=qr(light(mask,:)'*light(mask,:), 0);

                        atom = reshape(atom,roiSize(1),roiSize(2),size(atom,2),1);
                        light = reshape(light,roiSize(1),roiSize(2),size(light,2),1);
                        OdAfter = absorption2Od(computeAbsorption(cat(4,atom,light)));
                        ImageRatioAfter = computeAbsorption(cat(4,atom,light));
                        obj.Gui(2).initialize(OdBefore,OdAfter,Rtest,obj.FringeRemovalMethod)
                    otherwise
                        OdAfter = OdBefore;
                        ImageRatioAfter = ImageRatioBefore;
                end
            else
                OdAfter = OdBefore;
                ImageRatioAfter = ImageRatioBefore;
            end

            %% Update light and Od data after fringe removal
            obj.CameraLightData = light;
            obj.OdData = OdAfter;
            obj.ImageRatio = ImageRatioAfter;
        end

        function plotOdMix(obj)
            %% Initialize
            fig = obj.Chart(1).initialize;
            if ishandle(fig)
                figure(fig)
            else
                return
            end
            ax = gca;

            %% Plot OD Data
            nRun = obj.BecExp.NCompletedRun;
            cData = cell(1,nRun);
            runList = obj.BecExp.RunListSorted;
            for ii = 1:nRun
                cData{ii} = obj.OdData(:,:,runList(ii));
            end
            mData = horzcat(cData{:});
            img = imagesc(ax,mData);

            %% Render
            fz = 20;
            cb = colorbar(ax);
            clim(obj.CLim)
            colormap(ax,obj.Colormap)
            
            cb.Label.Interpreter = "Latex";
            cb.Label.String = "OD";
            cb.Label.FontSize = fz;
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            yxBoundary = obj.BecExp.Roi.YXBoundary;
            aspect = double(nRun)*roiSize(2)/roiSize(1);
            figPos = fig.InnerPosition;
            targetWidth = figPos(3)*0.85;
            targetHeight = figPos(4)*0.85;
            ax.Units = "pixels";
            if targetWidth > targetHeight * aspect
                ax.Position(4) = targetHeight;
                ax.Position(3) = targetHeight * aspect;
            else
                ax.Position(3) = targetWidth;
                ax.Position(4) = targetWidth / aspect;
            end
            ax.Position(1:2) = [figPos(3)/2 - ax.Position(3)/2,...
                figPos(4)/2 - ax.Position(4)/2];
            pbaspect(ax,[aspect,1,1])

            ax.Units = "normalized";
            ax.XLabel.String = obj.BecExp.XLabel;
            ax.XLabel.Interpreter = "latex";
            ax.XLabel.FontSize = fz;
            ax.YLabel.String = "$y$ position [pixels]";
            ax.YLabel.Interpreter = "latex";
            ax.YLabel.FontSize = fz;
            ax.Title.String = "TrialName: " + obj.BecExp.Name + ...
                ", Trial \#" + num2str(obj.BecExp.SerialNumber);
            ax.Title.Interpreter = "latex";
            ax.Title.FontSize = fz;
            ax.FontSize = fz;
            
            renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
            ax.TickDir = "out";
            tickSpace = roiSize(2);
            ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nRun)-tickSpace/2);
            ax.XTickLabel = string(obj.BecExp.ScannedParameterListSorted);
            set(ax,'box','off')
            ax.Units = "pixels";
            outerpos = ax.OuterPosition;
            fig.Position(4) = fig.Position(3) * outerpos(4)/outerpos(3)*1.05;
            ax.OuterPosition(2) = 0;
            
        end

        function plotOdAnimation(obj)
            %% Initialize figure
            fig = obj.Chart(2).initialize;
            if ishandle(fig)
                figure(fig)
            else
                return
            end

            %% Gif parameters
            startDelay=.5;
            midDelay=.1;
            endDelay=.5;
            filename = obj.Chart(2).Path + ".gif";

            %% BecExp parameters
            becExp = obj.BecExp;
            roi = becExp.Roi;
            yxBoundary = roi.YXBoundary;
            roiSize = roi.CenterSize(3:4);
            nRun = becExp.NCompletedRun;
            runList = obj.BecExp.RunListSorted;
            paraName = becExp.ScannedParameter;
            paraListSorted = becExp.ScannedParameterListSorted;
            paraUnit = becExp.ScannedParameterUnit;

            %% Initialize plots
            roiAspect = roiSize(2)/roiSize(1);
            figPos = fig.InnerPosition;
            gap = 15;
            yxLabelSize = 50;
            yxWidth = 60;
            capSize = 30;
            cbSize = 70;
            targetWidth = figPos(3) - gap - yxLabelSize - yxWidth - cbSize;
            targetHeight = figPos(4) - gap - yxLabelSize - yxWidth - capSize;
            if targetWidth >= targetHeight * roiAspect
                imgHeight = targetHeight;
                imgWidth = targetHeight * roiAspect;
                imgLeft = max(figPos(3)/2 - imgWidth/2,gap + yxLabelSize + yxWidth);
                imgBottom = gap + yxLabelSize + yxWidth;
            else
                imgWidth = targetWidth;
                imgHeight = imgWidth / roiAspect;
                imgLeft = gap + yxLabelSize + yxWidth;
                imgBottom = max(figPos(4)/2 - imgHeight/2,gap + yxLabelSize + yxWidth);
            end

            % OD image
            imgAxes = axes(fig);
            imgAxes.Units = "pixels";
            img = imagesc(imgAxes,zeros(roiSize));
            imgAxes.Colormap = obj.Colormap;
            cb = colorbar(imgAxes,"eastoutside");
            cb.Label.Interpreter = "Latex";
            cb.Label.String = "OD";
            cb.Label.FontSize = 14;
            imgAxes.Position = [imgLeft,imgBottom,imgWidth,imgHeight];
            imgAxes.CLim = obj.CLim;
            imgAxes.XTickLabel = '';
            imgAxes.YTickLabel = '';
            imgAxes.Title.Interpreter = "Latex";
            imgAxes.Title.FontSize = 14;
            imgAxes.Toolbar.Visible = "off";
            
            
            % X plot
            xAxes = axes(fig);
            xAxes.Units = "pixels";
            xAxes.Position = [imgLeft,imgBottom - (gap + yxWidth),imgWidth,yxWidth];
            xLine = plot(xAxes,yxBoundary(3):yxBoundary(4),zeros(1,roiSize(2)),'k','LineWidth',0.5);
            xAxes.XLabel.String = "$x$ position [Pixels]";
            xAxes.XLabel.Interpreter = "Latex";
            xAxes.XLabel.FontSize = 14;
            xAxes.YLim = obj.CLim;
            xAxes.XLim = [yxBoundary(3),yxBoundary(4)];
            xAxes.Toolbar.Visible = "off";
            
            % Y plot
            yAxes = axes(fig);
            yAxes.Units = "pixels";
            yAxes.Position = [imgLeft - (gap + yxWidth),imgBottom,yxWidth,imgHeight];
            yLine = plot(yAxes,zeros(1,roiSize(1)),yxBoundary(1):yxBoundary(2),'k','LineWidth',0.5);
            yAxes.YLabel.String = "$y$ position [Pixels]";
            yAxes.YLabel.Interpreter = "Latex";
            yAxes.YLabel.FontSize = 14;
            yAxes.YDir = "reverse";
            yAxes.XLim = obj.CLim;
            yAxes.YLim = [yxBoundary(1),yxBoundary(2)];
            yAxes.Toolbar.Visible = "off";

            %% Animation
            if ~isempty(obj.OdData)
                for ii = 1:nRun

                    % Update plots
                    img.CData = obj.OdData(:,:,runList(ii));
                    xLine.YData = squeeze(obj.OdData(round(roiSize(1)/2),:,runList(ii)));
                    yLine.XData = squeeze(obj.OdData(:,round(roiSize(2)/2),runList(ii)));

                    % Update title
                    if ismissing(paraUnit)
                        paraLabel = "$\mathrm{" + paraName + "} = ~$" + ...
                            string(paraListSorted(ii));
                    else
                        paraLabel = "$\mathrm{" + paraName + "} = ~$" + ...
                            string(paraListSorted(ii)) + "$~\mathrm{" + ...
                            paraUnit + "}$";
                    end
                    imgAxes.Title.String = ...
                        "TrialName: " + becExp.Name + ...
                        ", Trial \#" + num2str(becExp.SerialNumber) + ...
                        ", Run \#" + num2str(ii) + ", " + ... 
                        paraLabel;

                    % Save as gif
                    frame = getframe(fig);
                    im = frame2im(frame);
                    [A,map] = rgb2ind(im,256);
                    if ii == 1
                        imwrite(A,map,filename,'gif','LoopCount',Inf,'DelayTime',startDelay);
                    else
                        if ii==nRun
                            imwrite(A,map,filename,'gif','WriteMode','append','DelayTime',endDelay);
                        else
                            imwrite(A,map,filename,'gif','WriteMode','append','DelayTime',midDelay);
                        end
                    end
                end
            end
            close(fig)
        end
    end

    methods (Static)
        function handlePropEvents(src,evnt)
            switch src.Name
                case 'CLim'
                    obj = evnt.AffectedObject;
                    for ii = 1:numel(obj.Chart)
                        if ishandle(obj.Chart(ii).Figure)
                            fig = obj.Chart(ii).Figure;
                            ax = fig.CurrentAxes;
                            ax.CLim = obj.CLim;
                        end
                    end
                    if ~isempty(obj.Gui(1).App)
                        if isvalid(obj.Gui(1).App)
                            obj.Gui(1).App.OdAxes.CLim = obj.CLim;
                            obj.Gui(1).App.OdYAxes.XLim = obj.CLim;
                            obj.Gui(1).App.OdXAxes.YLim = obj.CLim;
                            obj.Gui(1).App.ODMinEditField.Value = obj.CLim(1);
                            obj.Gui(1).App.ODMaxEditField.Value = obj.CLim(2);
                        end
                    end
            end
        end
    end
end

