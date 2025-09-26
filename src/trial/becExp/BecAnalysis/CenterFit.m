classdef CenterFit < BecAnalysis
    %:class:`CenterFit` fit thermal cloud centers vs scanned variable.
    %
    % Uses center positions from :class:`DensityFit` to estimate trends versus
    % the scanned variable with user-selected 1D fit models (linear, parabolic,
    % sine, triangle). Produces x/y center plots with fits and a parameter
    % table summarizing slope, acceleration, or slosh parameters. Not intended
    % for sub-ROIs.
    %
    % **Associated Charts:**
    %   - Chart(1): "Center fit" - Cloud center position vs parameter with fit curves

    properties
        FitMethod = "LinearFit1D" % 1D fit model: \"LinearFit1D\"|\"ParabolicFit1D\"|\"SineFit1D\"|\"TriangleFit1D\"
        FitDataThermal % Two fit objects (x,y) applied to thermal cloud center trajectories
        FitDataCondensate % Reserved for future condensate center trajectory fits
        IsSaveCenter logical = false % Flag to save mean center position to CloudCenterData.mat for reuse
        MinimumFitNumber = 1 % Minimum number of runs required to perform the selected fit model
    end

    properties (SetAccess = protected)
        ThermalCloudCenterMean % Mean thermal cloud center position [:math:`x`; :math:`y`] [pixels]
        ThermalCloudCenterRange % Thermal cloud center position range [:math:`x`; :math:`y`] [pixels]
        ThermalCloudCenterSlope % Linear fit slope for center vs parameter [pixels/VarUnit]
        ThermalCloudCenterAcceleration % Parabolic fit acceleration [pixels/VarUnit^2 or m/s^2 for time scans]
        ThermalCloudCenterSloshAmplitude % Sine/Triangle fit oscillation amplitude [pixels]
        ThermalCloudCenterSloshOffset % Sine/Triangle fit center offset [pixels]
        ThermalCloudCenterSloshFrequency % Sine/Triangle fit frequency [Hz for time scans, 1/VarUnit otherwise]
        CondensateCenterMean % Reserved: Mean condensate center position [:math:`x`; :math:`y`] [pixels]
        CondensateCenterRange % Reserved: Condensate center position range [:math:`x`; :math:`y`] [pixels]
        CondensateCenterSlope % Reserved: Linear slope for condensate center [pixels/VarUnit]
        CondensateCenterAcceleration % Reserved: Parabolic acceleration for condensate center [pixels/VarUnit^2]
        CondensateCenterSloshAmplitude % Reserved: Oscillation amplitude for condensate center [pixels]
        CondensateCenterSloshOffset % Reserved: Center offset for condensate center [pixels]
        CondensateCenterSloshFrequency % Reserved: Oscillation frequency for condensate center [Hz or 1/VarUnit]
    end

    properties (Hidden,Transient)
        ThermalXLine % Plot handle for thermal x-center data points
        ThermalXFitLine % Plot handle for thermal x-center fit line
        ThermalYLine % Plot handle for thermal y-center data points
        ThermalYFitLine % Plot handle for thermal y-center fit line
        ParaTable % UI table handle for displaying fit parameters and results
    end

    methods
        function obj = CenterFit(becExp)
            % Construct :class:`CenterFit` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Center fit",...
                num = 30, ...
                fpath = fullfile(becExp.DataAnalysisPath,"CenterFit"),...
                loc = [0.3919,0.032],...
                size = [0.3069,0.57]...
                );
        end

        function initialize(obj)
            % Initialize plots, fit objects, and parameter table.
            %
            % Sets up dual-axis plots for x/y center trajectories, initializes
            % fit objects based on :attr:`FitMethod`, and creates parameter table.
            % Requires :class:`DensityFit` in analysis pipeline.
            becExp = obj.BecExp;
            %% Check if we have DensityFit and Sub-ROIs
            if ~ismember("DensityFit",obj.BecExp.AnalysisMethod)
                warning("No DensityFit. Can not do CenterFit analysis")
                return
            elseif ~isempty(obj.BecExp.Roi.SubRoi)
                warning("Can not do CenterFit analysis for sub-ROIs.")
                return
            end

            %% Initialize data
            obj.ThermalCloudCenterMean = [0;0];
            obj.ThermalCloudCenterRange = [0;0];
            obj.ThermalCloudCenterSlope = [0;0];
            obj.ThermalCloudCenterAcceleration = [0;0];
            obj.ThermalCloudCenterSloshAmplitude = [0;0];
            obj.ThermalCloudCenterSloshOffset = [0;0];
            obj.ThermalCloudCenterSloshFrequency = [0;0];
            obj.CondensateCenterMean = [0;0];
            obj.CondensateCenterRange = [0;0];
            obj.CondensateCenterSlope = [0;0];
            obj.CondensateCenterAcceleration = [0;0];
            obj.CondensateCenterSloshAmplitude = [0;0];
            obj.CondensateCenterSloshOffset = [0;0];
            obj.CondensateCenterSloshFrequency = [0;0];

            %% Initialize fit
            thermalTemp = obj.FitDataThermal;
            condensateTemp = obj.FitDataCondensate;
            obj.FitDataThermal = eval(obj.FitMethod + "([0,0])");
            obj.FitDataCondensate = eval(obj.FitMethod + "([0,0])");
            obj.FitDataThermal(2) = eval(obj.FitMethod + "([0,0])");
            obj.FitDataCondensate(2) = eval(obj.FitMethod + "([0,0])");
            nameList = ["StartPoint","Lower","Upper"] + "Override";
            nameList = [nameList,"IsOverride"];
            if ~isempty(thermalTemp)
                for xx = 1:2
                    for nn = 1:numel(nameList)
                        obj.FitDataThermal(xx).(nameList(nn)) = thermalTemp(xx).(nameList(nn));
                    end
                end
            end
            if ~isempty(condensateTemp)
                for xx = 1:2
                    for nn = 1:numel(nameList)
                        obj.FitDataCondensate(xx).(nameList(nn)) = condensateTemp(xx).(nameList(nn));
                    end
                end
            end

            %% Initialize plots
            fig = obj.Chart(1).initialize;
            if ishandle(fig)
                %% Initialize plots, general

                % Plot curves into panel1
                p1 = uipanel(fig,"Position",[0,0.3,1,0.7]);
                t = tiledlayout(p1,2,1);
                t.TileSpacing = 'compact';
                t.Padding = 'compact';

                % X axes (x center)
                ax1 = nexttile(t);
                ax1.XLabel.Interpreter = "latex";
                ax1.YLabel.String = "$x_0$ [Pixels]";
                ax1.YLabel.Interpreter = "latex";
                ax1.FontSize = 12;
                ax1.Box = "on";
                ax1.XGrid = "on";
                ax1.YGrid = "on";
                ax1.XTickLabel = [];

                % Y axes (y center)
                ax2 = nexttile(t);
                ax2.XLabel.String = becExp.XLabel;
                ax2.XLabel.Interpreter = "latex";
                ax2.YLabel.String = "$y_0$ [Pixels]";
                ax2.YLabel.Interpreter = "latex";
                ax2.FontSize = 12;
                ax2.Box = "on";
                ax2.XGrid = "on";
                ax2.YGrid = "on";

                %% Initialize plots, based on DensityFit method
                hold(ax1,'on')
                hold(ax2,'on')
                switch becExp.DensityFit.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D", "WeightedMean"}
                        % X data lines
                        co = ax1.ColorOrder;
                        obj.ThermalXLine = errorbar(ax1,1,1,[]);
                        obj.ThermalXLine.Marker = "o";
                        obj.ThermalXLine.MarkerFaceColor = co(1,:);
                        obj.ThermalXLine.MarkerEdgeColor = co(1,:)*.5;
                        obj.ThermalXLine.MarkerSize = 8;
                        obj.ThermalXLine.LineWidth = 2;
                        obj.ThermalXLine.LineStyle = "none";
                        obj.ThermalXLine.CapSize = 0;

                        obj.ThermalXFitLine = line(ax1,1,1);
                        obj.ThermalXFitLine.LineWidth = 2;
                        obj.ThermalXFitLine.Color = co(1,:);
                        legend(ax1,"Thermal Data","Thermal Fit");

                        % Y data lines
                        co = ax2.ColorOrder;
                        obj.ThermalYLine = errorbar(ax2,1,1,[]);
                        obj.ThermalYLine.Marker = "o";
                        obj.ThermalYLine.MarkerFaceColor = co(1,:);
                        obj.ThermalYLine.MarkerEdgeColor = co(1,:)*.5;
                        obj.ThermalYLine.MarkerSize = 8;
                        obj.ThermalYLine.LineWidth = 2;
                        obj.ThermalYLine.LineStyle = "none";
                        obj.ThermalYLine.CapSize = 0;

                        obj.ThermalYFitLine = line(ax2,1,1);
                        obj.ThermalYFitLine.LineWidth = 2;
                        obj.ThermalYFitLine.Color = co(1,:);
                        legend(ax2,"Thermal Data","Thermal Fit");
                end
                hold(ax1,'off')
                hold(ax2,'off')
            end

            %% Initialize table
            if ishandle(fig)
                %% Initialize table data
                switch becExp.DensityFit.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D", "WeightedMean"}
                        %% Thermal fit only
                        data{1,1} = 'Thermal Cloud Center Mean in x';
                        data{1,2} = '';
                        data{1,3} = 'Pixels';
                        data{2,1} = 'Thermal Cloud Center Mean in y';
                        data{2,2} = '';
                        data{2,3} = 'Pixels';
                        data{3,1} = 'Thermal Cloud Center Range in x';
                        data{3,2} = '';
                        data{3,3} = 'Pixels';
                        data{4,1} = 'Thermal Cloud Center Range in y';
                        data{4,2} = '';
                        data{4,3} = 'Pixels';
                        switch obj.FitMethod
                            case "LinearFit1D"
                                obj.MinimumFitNumber = 2;
                                data{5,1} = 'Thermal Cloud Center Slope in x';
                                data{5,2} = '';
                                data{5,3} = 'Pixels/VarUnit';
                                data{6,1} = 'Thermal Cloud Center Slope in y';
                                data{6,2} = '';
                                data{6,3} = 'Pixels/VarUnit';
                            case "ParabolicFit1D"
                                obj.MinimumFitNumber = 3;
                                data{5,1} = 'Thermal Cloud Center Acceleration in x';
                                data{5,2} = '';
                                data{6,1} = 'Thermal Cloud Center Acceleration in y';
                                data{6,2} = '';
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    data{5,3} = 'm/s^2';
                                    data{6,3} = 'm/s^2';
                                else
                                    data{5,3} = 'Pixels/VarUnit^2';
                                    data{6,3} = 'Pixels/VarUnit^2';
                                end
                            case "SineFit1D"
                                obj.MinimumFitNumber = 4;
                                data{5,1} = 'Thermal Cloud Center Slosh Amplitude in x';
                                data{5,2} = '';
                                data{5,3} = 'Pixels';
                                data{6,1} = 'Thermal Cloud Center Slosh Amplitude in y';
                                data{6,2} = '';
                                data{6,3} = 'Pixels';
                                data{7,1} = 'Thermal Cloud Center Slosh Offset in x';
                                data{7,2} = '';
                                data{7,3} = 'Pixels';
                                data{8,1} = 'Thermal Cloud Center Slosh Offset in y';
                                data{8,2} = '';
                                data{8,3} = 'Pixels';
                                data{9,1} = 'Thermal Cloud Center Slosh Frequency in x';
                                data{9,2} = '';
                                data{10,1} = 'Thermal Cloud Center Slosh Frequency in y';
                                data{10,2} = '';
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    data{9,3} = 'Hz';
                                    data{10,3} = 'Hz';
                                else
                                    data{9,3} = '1/VarUnit';
                                    data{10,3} = '1/VarUnit';
                                end
                            case {"TriangleFit1D","IsoscelesTriangleFit1D"}
                                obj.MinimumFitNumber = 5;
                                data{5,1} = 'Thermal Cloud Center Slosh Amplitude in x';
                                data{5,2} = '';
                                data{5,3} = 'Pixels';
                                data{6,1} = 'Thermal Cloud Center Slosh Amplitude in y';
                                data{6,2} = '';
                                data{6,3} = 'Pixels';
                                data{7,1} = 'Thermal Cloud Center Slosh Offset in x';
                                data{7,2} = '';
                                data{7,3} = 'Pixels';
                                data{8,1} = 'Thermal Cloud Center Slosh Offset in y';
                                data{8,2} = '';
                                data{8,3} = 'Pixels';
                                data{9,1} = 'Thermal Cloud Center Slosh Frequency in x';
                                data{9,2} = '';
                                data{10,1} = 'Thermal Cloud Center Slosh Frequency in y';
                                data{10,2} = '';
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    data{9,3} = 'Hz';
                                    data{10,3} = 'Hz';
                                else
                                    data{9,3} = '1/VarUnit';
                                    data{10,3} = '1/VarUnit';
                                end
                        end

                    case "BimodalFit1D"
                        %% Thermal and condensate fit
                end

                %% Initialize table plot
                p2 = uipanel(fig,"Position",[0,0,1,0.3]);
                obj.ParaTable = uitable(p2,'Data', [1 2 3],Unit='normalized',Position=[0,0,1,1]);
                obj.ParaTable.ColumnName = {'Parameter','Value','Unit'};
                obj.ParaTable.Data = data;
                obj.ParaTable.FontSize = 12;
                obj.ParaTable.Units = 'pixel';
                tWidth = obj.ParaTable.Position(3);
                obj.ParaTable.ColumnWidth={tWidth*0.6 tWidth*0.2 tWidth*0.2};
                obj.ParaTable.ColumnEditable=[false false];
                obj.ParaTable.RowName=[];
                obj.ParaTable.Units = 'normalized';

            end
        end

        function updateData(obj,~)
            % Compute fit parameters for cloud centers vs scanned variable.
            %
            % For each axis (x,y), prepares :attr:`FitDataThermal` and
            % extracts slope/acceleration/slosh parameters depending on
            % :attr:`FitMethod` when sufficient runs exist.
            %
            % :param ~: Unused run index placeholder (processes all runs)
            % :type ~: double
            becExp = obj.BecExp;
            if ~ismember("DensityFit",becExp.AnalysisMethod) ||...
                    ~isempty(becExp.Roi.SubRoi)
                return
            end
            varList = becExp.ScannedVariableList.';
            if isTimeUnit(becExp.ScannedVariableUnit)
                tUnit = unit2SI(becExp.ScannedVariableUnit);
            end

            %% Update data
            switch becExp.DensityFit.FitMethod
                case {"GaussianFit1D","BosonicGaussianFit1D", "WeightedMean"}
                    %% Thermal fit only
                    obj.ThermalCloudCenterMean = mean(becExp.DensityFit.ThermalCloudCenter,2);
                    obj.ThermalCloudCenterRange = max(becExp.DensityFit.ThermalCloudCenter,[],2) - ...
                        min(becExp.DensityFit.ThermalCloudCenter,[],2);
                    if becExp.NCompletedRun >= obj.MinimumFitNumber
                        switch obj.FitMethod
                            case "LinearFit1D"
                                %% Linear Fit
                                for xx = 1:2
                                    obj.FitDataThermal(xx).RawData = [varList,becExp.DensityFit.ThermalCloudCenter(xx,:).'];
                                    obj.FitDataThermal(xx).do;
                                end
                                obj.ThermalCloudCenterSlope = ...
                                    [obj.FitDataThermal(1).Coefficient(1);obj.FitDataThermal(2).Coefficient(1)];
                            case "ParabolicFit1D"
                                %% Parabolic Fit
                                for xx = 1:2
                                    obj.FitDataThermal(xx).RawData = [varList,becExp.DensityFit.ThermalCloudCenter(xx,:).'];
                                    obj.FitDataThermal(xx).do;
                                end
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    obj.ThermalCloudCenterAcceleration = ...
                                        1 / (tUnit^2) * 2 * [obj.FitDataThermal(1).Coefficient(1);obj.FitDataThermal(2).Coefficient(1)];
                                else
                                    obj.ThermalCloudCenterAcceleration = ...
                                        2 * [obj.FitDataThermal(1).Coefficient(1);obj.FitDataThermal(2).Coefficient(1)];
                                end
                            case "SineFit1D"
                                %% Sine Fit
                                for xx = 1:2
                                    obj.FitDataThermal(xx).RawData = [varList,becExp.DensityFit.ThermalCloudCenter(xx,:).'];
                                    obj.FitDataThermal(xx).do;
                                end
                                obj.ThermalCloudCenterSloshAmplitude = ...
                                    [obj.FitDataThermal(1).Coefficient(1);obj.FitDataThermal(2).Coefficient(1)];
                                obj.ThermalCloudCenterSloshOffset = ...
                                    [obj.FitDataThermal(1).Coefficient(4);obj.FitDataThermal(2).Coefficient(4)];
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    obj.ThermalCloudCenterSloshFrequency = ...
                                        1 / tUnit * [obj.FitDataThermal(1).Coefficient(2);obj.FitDataThermal(2).Coefficient(2)];
                                else
                                    obj.ThermalCloudCenterSloshFrequency = ...
                                        [obj.FitDataThermal(1).Coefficient(2);obj.FitDataThermal(2).Coefficient(2)];
                                end
                            case {"TriangleFit1D","IsoscelesTriangleFit1D"}
                                %% Sine Fit
                                for xx = 1:2
                                    obj.FitDataThermal(xx).RawData = [varList,becExp.DensityFit.ThermalCloudCenter(xx,:).'];
                                    obj.FitDataThermal(xx).do;
                                end
                                obj.ThermalCloudCenterSloshAmplitude = ...
                                    [(obj.FitDataThermal(1).Coefficient(1) - obj.FitDataThermal(1).Coefficient(2))/2;...
                                    (obj.FitDataThermal(2).Coefficient(1) - obj.FitDataThermal(2).Coefficient(2))/2];
                                obj.ThermalCloudCenterSloshOffset = ...
                                    [(obj.FitDataThermal(1).Coefficient(1) + obj.FitDataThermal(1).Coefficient(2))/2;...
                                    (obj.FitDataThermal(2).Coefficient(1) + obj.FitDataThermal(2).Coefficient(2))/2];
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    obj.ThermalCloudCenterSloshFrequency = ...
                                        1 ./ tUnit ./ [obj.FitDataThermal(1).Coefficient(4);obj.FitDataThermal(2).Coefficient(4)];
                                else
                                    obj.ThermalCloudCenterSloshFrequency = ...
                                        1 ./ [obj.FitDataThermal(1).Coefficient(4);obj.FitDataThermal(2).Coefficient(4)];
                                end
                        end
                    end
                case "BimodalFit1D"
                    %% Thermal and condensate fit

            end
        end

        function updateFigure(obj,~)
            % Update center vs scan plots and parameter table.
            %
            % :param ~: Unused run index placeholder
            % :type ~: double
            fig = obj.Chart(1).Figure;
            becExp = obj.BecExp;
            if ~ismember("DensityFit",obj.BecExp.AnalysisMethod) || (isempty(fig) || ~ishandle(fig)) ||...
                    ~isempty(obj.BecExp.Roi.SubRoi)
                return
            end
            px = becExp.Acquisition.PixelSizeReal;

            switch becExp.DensityFit.FitMethod
                case {"GaussianFit1D","BosonicGaussianFit1D", "WeightedMean"}
                    %% Thermal fit only
                    obj.ParaTable.Data{1,2} = num2str(obj.ThermalCloudCenterMean(1)/px,'%.2f');
                    obj.ParaTable.Data{2,2} = num2str(obj.ThermalCloudCenterMean(2)/px,'%.2f');
                    obj.ParaTable.Data{3,2} = num2str(obj.ThermalCloudCenterRange(1)/px,'%.2f');
                    obj.ParaTable.Data{4,2} = num2str(obj.ThermalCloudCenterRange(2)/px,'%.2f');
                    if becExp.NCompletedRun >= 1 && becExp.NCompletedRun < obj.MinimumFitNumber
                        obj.ThermalXLine.XData = obj.BecExp.ScannedVariableList;
                        obj.ThermalXLine.YData = obj.BecExp.DensityFit.ThermalCloudCenter(1,:) / px;
                        obj.ThermalYLine.XData = obj.BecExp.ScannedVariableList;
                        obj.ThermalYLine.YData = obj.BecExp.DensityFit.ThermalCloudCenter(2,:) / px;
                    elseif becExp.NCompletedRun >= obj.MinimumFitNumber
                        rawXT = obj.FitDataThermal(1).RawData;
                        rawYT = obj.FitDataThermal(2).RawData;
                        [xRawXT,yRawXT,stdRawXT] = computeAveErr(rawXT(:,1),rawXT(:,2) / px, becExp.AveragingMethod);
                        [xRawYT,yRawYT,stdRawYT] = computeAveErr(rawYT(:,1),rawYT(:,2) / px, becExp.AveragingMethod);

                        obj.ThermalXLine.XData = xRawXT;
                        obj.ThermalXLine.YData = yRawXT;
                        obj.ThermalXLine.YNegativeDelta = stdRawXT;
                        obj.ThermalXLine.YPositiveDelta = stdRawXT;

                        obj.ThermalYLine.XData = xRawYT;
                        obj.ThermalYLine.YData = yRawYT;
                        obj.ThermalYLine.YNegativeDelta = stdRawYT;
                        obj.ThermalYLine.YPositiveDelta = stdRawYT;

                        fitXT = obj.FitDataThermal(1).FitPlotData;
                        fitYT = obj.FitDataThermal(2).FitPlotData;
                        obj.ThermalXFitLine.XData = fitXT(:,1);
                        obj.ThermalXFitLine.YData = fitXT(:,2) / px;
                        obj.ThermalYFitLine.XData = fitYT(:,1);
                        obj.ThermalYFitLine.YData = fitYT(:,2) / px;

                        switch obj.FitMethod
                            case "LinearFit1D"
                                obj.ParaTable.Data{5,2} = num2str(obj.ThermalCloudCenterSlope(1)/px);
                                obj.ParaTable.Data{6,2} = num2str(obj.ThermalCloudCenterSlope(2)/px);
                            case "ParabolicFit1D"
                                if isTimeUnit(becExp.ScannedVariableUnit)
                                    obj.ParaTable.Data{5,2} = num2str(obj.ThermalCloudCenterAcceleration(1));
                                    obj.ParaTable.Data{6,2} = num2str(obj.ThermalCloudCenterAcceleration(2));
                                else
                                    obj.ParaTable.Data{5,2} = num2str(obj.ThermalCloudCenterAcceleration(1)/px);
                                    obj.ParaTable.Data{6,2} = num2str(obj.ThermalCloudCenterAcceleration(2)/px);
                                end
                            case {"SineFit1D","TriangleFit1D","IsoscelesTriangleFit1D"}
                                obj.ParaTable.Data{5,2} = num2str(obj.ThermalCloudCenterSloshAmplitude(1)/px);
                                obj.ParaTable.Data{6,2} = num2str(obj.ThermalCloudCenterSloshAmplitude(2)/px);
                                obj.ParaTable.Data{7,2} = num2str(obj.ThermalCloudCenterSloshOffset(1)/px);
                                obj.ParaTable.Data{8,2} = num2str(obj.ThermalCloudCenterSloshOffset(2)/px);
                                obj.ParaTable.Data{9,2} = num2str(obj.ThermalCloudCenterSloshFrequency(1));
                                obj.ParaTable.Data{10,2} = num2str(obj.ThermalCloudCenterSloshFrequency(2));
                        end
                    end
                case "BimodalFit1D"
                    %% Thermal and condensate fit
            end

            lg = findobj(fig,'Type','Legend');
            lg(1).Location = 'best';
            lg(2).Location = 'best';
        end

        function refresh(obj)
            % Recompute and redraw all center-fit outputs.
            obj.initialize;
            obj.updateData(obj.BecExp.NCompletedRun)
            obj.updateFigure(obj.BecExp.NCompletedRun)
        end

        function save(obj)
            % Save figure and optionally persist center reference for reuse.
            %
            % When :attr:`IsSaveCenter` is true, writes/updates
            % ``CloudCenterData.mat`` with mean center for this trial.
            becExp = obj.BecExp;
            if ~ismember("DensityFit",becExp.AnalysisMethod) ||...
                    ~isempty(becExp.Roi.SubRoi)
                return
            end
            obj.Chart(1).save

            % save center data
            if obj.IsSaveCenter
                load("CloudCenterData.mat","CloudCenter")
                TrialNameList = CloudCenter.TrialName;
                TrialName = becExp.Name;
                px = becExp.Acquisition.PixelSizeReal;
                switch becExp.DensityFit.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D", "WeightedMean"}
                        Center = obj.ThermalCloudCenterMean;
                end
                Center = reshape(flip(Center),1,2) / px; % Use ROI coordinates convention.
                Center = becExp.Roi.full2NoRotationFull(Center); % Convert to no-rotation full coordinates
                t = table(TrialName,Center);
                if ~ismember(TrialName,TrialNameList)
                    CloudCenter = [CloudCenter;t];
                else
                    CloudCenter(TrialNameList == TrialName,:) = t;
                end
                save(which("CloudCenterData.mat"),"CloudCenter")
            end
        end

    end
end

