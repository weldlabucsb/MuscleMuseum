classdef Od < BecAnalysis
    %:class:`Od` compute optical depth (OD) and related plots per run.
    %
    % Reads ROI images (atom/light/dark), computes absorption and OD, applies
    % optional fringe removal, and renders OD mix and GIF animations. Also
    % stores background-subtracted light for downstream imaging analysis.
    %
    % **Associated Charts:**
    %   - Chart(1): "OdMix" - Horizontal mosaic or 2D density plot of OD
    %   - Chart(2): "OdAnimation" - Animated GIF showing OD evolution
    %
    % **Associated GUIs:**
    %   - Gui(1): "FringeRemoval" - Interface for fringe removal configuration

    properties (Transient)
        RoiData double % Raw ROI image stack with shape (:math:`N_y`, :math:`N_x`, :math:`N_\mathrm{run}`, [atom, light, dark])
        CameraLightData double % Background-subtracted light images after fringe removal processing
        OdData double % Optical depth maps :math:`\mathrm{OD} = -\ln(I_\mathrm{atom}/I_\mathrm{light})` per run
        ImageRatio double % Atom-to-light intensity ratio :math:`I_\mathrm{atom}/I_\mathrm{light}` for phase contrast imaging
    end

    properties
        FringeRemovalMethod string = "LSR" % Fringe removal algorithm: "LSR" (least squares regression) or "None"
        FringeRemovalMask double % Background region coordinates as 2×N matrix [:math:`y`; :math:`x`] in pixels
        Colormap = jet % Colormap function handle for optical depth visualization
    end

    properties (SetObservable)
        CLim double = [0,4] % Color axis limits for optical depth plots [OD_min, OD_max]
    end

    methods
        function obj = Od(becExp)
            % Construct :class:`Od` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
            obj@BecAnalysis(becExp)
            obj.Gui(1) = Gui(...
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
            % Initialize internal data arrays and property change listeners.
            %
            % Sets up storage arrays for ROI data, optical depth maps, image ratios,
            % and processed light images. Establishes listener for color limit changes.
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            obj.RoiData = zeros([roiSize,1,3]);
            obj.OdData = zeros([roiSize,1]);
            obj.ImageRatio = zeros([roiSize,1]);
            obj.CameraLightData = zeros([roiSize,1]);

            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
        end

        function update(obj,runIdx)
            % Read run data and compute optical depth without fringe removal.
            %
            % Loads raw images for the specified run, computes optical depth using
            % the absorption-to-OD conversion, and updates camera light data for
            % downstream analysis modules.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
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

            % Update camera light data
            obj.CameraLightData(:,:,runIdx) = obj.RoiData(:,:,runIdx,2) - obj.RoiData(:,:,runIdx,3);
        end

        function finalize(obj)
            % Apply fringe removal and generate final OD visualizations.
            %
            % Performs fringe removal processing (if configured), then creates
            % the OD mosaic plot and animated GIF showing temporal evolution.
            obj.doFringeRemoval
            obj.plotOdMix
            obj.plotOdAnimation
        end

        function show(obj)
            % Display OD mosaic and animation charts with property listeners.
            %
            % Makes the OD visualization charts visible and establishes property
            % change listeners for real-time color limit updates.
            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
            obj.Chart(1).show
            obj.Chart(2).show
        end

        function refresh(obj)
            % Reload all ROI data from disk and regenerate OD analysis.
            %
            % Clears temporary data, reloads all run images from disk, and
            % recomputes the complete OD analysis including fringe removal
            % and visualization.
            becExp = obj.BecExp;
            becExp.TempData = [];
            roi = becExp.Roi;
            roiSize = roi.CenterSize(3:4);
            nRun = becExp.NCompletedRun;

            obj.RoiData = becExp.readRunRoi(1:nRun);

            % Redo plotting
            obj.finalize;
        end

        function doFringeRemoval(obj)
            % Perform optional fringe removal and update processed data.
            %
            % Applies fringe removal algorithm (if configured) to reduce systematic
            % intensity variations. Updates optical depth, image ratio, and camera
            % light data with the corrected values.

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
                        obj.Gui(1).initialize(OdBefore,OdAfter,Rtest,obj.FringeRemovalMethod)
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
            % Generate OD mosaic plot for 1D scans or 2D parameter map.
            %
            % Creates either a horizontal mosaic of OD images (for 1D parameter
            % scans) or a 2D density map (for 2D parameter scans) showing the
            % spatial distribution of optical depth.

            %% Initialize figure
            fig = obj.Chart(1).initialize;
            if ishandle(fig)
                figure(fig)
            else
                return
            end

            %% Check if 2D scan and call appropriate plotting method
            if obj.BecExp.Is2DScan
                obj.plotOdMix2D(fig);
            else
                obj.plotOdMix1D(fig);
            end
        end

        function plotOdMix1D(obj, fig)
            % Create horizontal mosaic of OD images for 1D parameter scans.
            %
            % Concatenates OD images from all runs side-by-side, sorted by
            % parameter value, with proper axis labeling and colorbar.
            %
            % :param fig: Target figure handle
            % :type fig: matlab.ui.Figure
            ax = gca;

            %% Plot OD Data
            odData = obj.OdData;
            if ~obj.BecExp.IsDensityAverage
                xTick = obj.BecExp.ScannedVariableListSorted;
                odData = odData(:,:,obj.BecExp.RunListSorted);
            else
                [xTick,odData] = computeAveErr(obj.BecExp.ScannedVariableList,odData);
            end

            nRun = numel(xTick);
            cData = cell(1,nRun);

            for ii = 1:numel(xTick)
                cData{ii} = odData(:,:,ii);
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
            targetHeight = figPos(4)*0.8;
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
            ax.XTickLabel = string(xTick);
            set(ax,'box','off')
            ax.Units = "pixels";
            outerpos = ax.OuterPosition;
            fig.Position(4) = fig.Position(3) * outerpos(4)/outerpos(3)*1.05;
            ax.OuterPosition(2) = 0;
        end

        function plotOdMix2D(obj, fig)
            % Create 2D parameter density map from OD data.
            %
            % Generates a 2D density plot showing OD variation across the
            % two-dimensional parameter space, using a representative slice
            % through the ROI.
            %
            % :param fig: Target figure handle
            % :type fig: matlab.ui.Figure
            becExp = obj.BecExp;
            roi = becExp.Roi;
            roiSize = roi.CenterSize(3:4);

            % Get 2D plot data
            [xData, yData] = obj.get2DPlotData();

            if isempty(xData) || isempty(yData)
                % Fallback to 1D plotting if 2D data is not available
                obj.plotOdMix1D(fig);
                return;
            end

            % Clear figure and create new axes
            clf(fig);
            ax = axes(fig);

            % Create 2D density plot for a representative slice (middle of ROI)
            midSlice = round(roiSize(1)/2);
            odSlice = squeeze(obj.OdData(midSlice, :, :));

            % Reshape to 2D grid
            od2D = obj.reshapeDataTo2D(odSlice);

            % Create density plot
            imagesc(ax, xData, yData, od2D);
            ax.Colormap = obj.Colormap;
            ax.CLim = obj.CLim;

            % Add labels and title
            ax.XLabel.String = becExp.XLabel;
            ax.XLabel.Interpreter = "latex";
            ax.XLabel.FontSize = 12;
            ax.YLabel.String = becExp.YLabel;
            ax.YLabel.Interpreter = "latex";
            ax.YLabel.FontSize = 12;
            ax.Title.String = "TrialName: " + obj.BecExp.Name + ...
                ", Trial \#" + num2str(obj.BecExp.SerialNumber) + ...
                " (OD at y=" + num2str(midSlice) + ")";
            ax.Title.Interpreter = "latex";
            ax.Title.FontSize = 12;

            % Add colorbar
            colorbar(ax);
        end

        function plotOdAnimation(obj)
            % Generate animated GIF showing OD evolution across parameter values.
            %
            % Creates an animated visualization with the main OD image and
            % cross-sectional profiles, stepping through parameter values
            % to show temporal or parametric evolution.
            
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
            varName = becExp.ScannedVariable;
            varListSorted = becExp.ScannedVariableListSorted;
            varUnit = becExp.ScannedVariableUnit;

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
                    if varUnit == "None" || ismissing(varUnit)
                        varLabel = "$\mathrm{" + varName + "} = ~$" + ...
                            string(varListSorted(ii));
                    else
                        varLabel = "$\mathrm{" + varName + "} = ~$" + ...
                            string(varListSorted(ii)) + "$~\mathrm{" + ...
                            varUnit + "}$";
                    end
                    imgAxes.Title.String = ...
                        "TrialName: " + becExp.Name + ...
                        ", Trial \#" + num2str(becExp.SerialNumber) + ...
                        ", Run \#" + num2str(ii) + ", " + ...
                        varLabel;

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
            % Listener callback to propagate CLim changes.
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
                    odApp = obj.BecExp.Ad.Gui(1).App;
                    if ~isempty(odApp)
                        if isvalid(odApp)
                            if odApp.IsOd
                                odApp.OdAxes.CLim = obj.CLim;
                                odApp.OdYAxes.XLim = obj.CLim;
                                odApp.OdXAxes.YLim = obj.CLim;
                                odApp.ODMinEditField.Value = obj.CLim(1);
                                odApp.ODMaxEditField.Value = obj.CLim(2);
                            end
                        end
                    end
            end
        end
    end
end

