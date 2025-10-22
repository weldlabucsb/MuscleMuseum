classdef AtomNumber < BecAnalysis
    %:class:`AtomNumber` compute and plot atom number components vs scan.
    %
    % Integrates AD density over ROI/sub-ROIs to obtain raw counts and, when
    % density fits are available, separates thermal/condensate contributions.
    % Supports normalized sub-ROI fractions and 1D/2D visualizations.
    %
    % **Associated Charts:**
    %   - Chart(1): "Atom number" - Error bar plots of atom number vs parameter

    properties (SetAccess = protected)
        Raw % Integrated atomic column density per run/subROI [m^{-2}]
        Thermal % Thermal cloud component from density fits per run/subROI [m^{-2}]
        Condensate % Condensate component from bimodal fits per run/subROI [m^{-2}]
    end

    properties (Dependent)
        Total % Total atom number as sum of thermal and condensate components [m^{-2}]
    end

    properties (Constant)
        Unit = 10^6; % Display scale factor for atom number plots (millions of atoms)
    end

    properties (SetObservable)
        YLim double = [0,30]; % Y-axis limits for 1D plots in units of :attr:`Unit` [millions]
        IsShowRaw logical = true; % Flag to show/hide raw integrated atom number series
        IsShowThermal logical = true; % Flag to show/hide thermal component series
        IsShowCondensate logical = true; % Flag to show/hide condensate component series
        IsShowTotal logical = true; % Flag to show/hide total atom number series
    end

    properties
        IsShowNormalized logical = true; % Flag to normalize sub-ROI fractions by total atom number
        FitMethod string = "None" % Optional fit model name for atom number vs parameter trends
        FitDataRaw % Fit object results for raw integrated atom number trends
        FitDataThermal % Fit object results for thermal component trends
        FitDataCondensate % Fit object results for condensate component trends
        Colormap = sky
    end

    properties (Hidden,Transient)
        RawLine % Errorbar plot handles for raw atom number series
        ThermalLine % Errorbar plot handles for thermal component series
        CondensateLine % Errorbar plot handles for condensate component series
        TotalLine % Errorbar plot handles for total atom number series
        RawError
        ThermalError
        CondensateError
        TotalError
    end

    methods
        function obj = AtomNumber(becExp)
            % Construct :class:`AtomNumber` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Atom number",...
                num = 29, ...
                fpath = fullfile(becExp.DataAnalysisPath,"AtomNumber"),...
                loc = [0.6936,0.6014],...
                size = [0.3069,0.3995]...
                );
        end

        function initialize(obj)
            % Initialize plots, listeners, and internal data containers.
            %
            % Sets up 1D or 2D plotting layouts, creates data storage arrays,
            % configures plot properties, and establishes property listeners.
            becExp = obj.BecExp;
            fig = obj.Chart(1).initialize;
            nSub = becExp.Roi.NSub;
            nSub(nSub == 0) = 1;
            is2DScan = becExp.Is2DScan;
            xLabel = becExp.XLabel;
            yLabel = becExp.YLabel;

            %% Initialize data
            obj.Raw = zeros(1,1,nSub);
            obj.Thermal = zeros(1,1,nSub);
            obj.Condensate = zeros(1,1,nSub);

            %% Initialize figures
            if ~ishandle(fig)
                return
            end

            % Listener for plotting y limit and toggling lines
            addlistener(obj,'YLim','PostSet',@obj.handlePropEvents);
            addlistener(obj,'IsShowRaw','PostSet',@obj.handlePropEvents);
            addlistener(obj,'IsShowThermal','PostSet',@obj.handlePropEvents);
            addlistener(obj,'IsShowCondensate','PostSet',@obj.handlePropEvents);
            addlistener(obj,'IsShowTotal','PostSet',@obj.handlePropEvents);

            if ~is2DScan
                %% 1D scan initialization
                % Initialize axis
                ax = gca;
                co = ax.ColorOrder;
                conum=size(co, 1);
                mOrder = markerOrder();

                obj.RawLine = matlab.graphics.chart.primitive.ErrorBar.empty;
                obj.ThermalLine = matlab.graphics.chart.primitive.ErrorBar.empty;
                obj.CondensateLine = matlab.graphics.chart.primitive.ErrorBar.empty;
                obj.TotalLine = matlab.graphics.chart.primitive.ErrorBar.empty;

                hold(ax,'on')

                % Initialize raw plots
                for ii = 1:nSub
                    obj.RawLine(ii) = errorbar(ax,1,1,[]);
                    obj.RawLine(ii).Marker = mOrder(ii);
                    obj.RawLine(ii).MarkerFaceColor = co(ii,:);
                    obj.RawLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                    obj.RawLine(ii).MarkerSize = 8;
                    obj.RawLine(ii).LineWidth = 2;
                    obj.RawLine(ii).Color = co(ii,:);
                    obj.RawLine(ii).CapSize = 0;
                end
                legendStrRaw = arrayfun(@(x) "Raw " + x,1:nSub);

                % Initialize thermal and condensate plots
                if ismember("DensityFit",becExp.AnalysisMethod)
                    switch becExp.DensityFit.FitMethod
                        case {"GaussianFit1D","BosonicGaussianFit1D"}
                            for ii = 1:nSub
                                obj.ThermalLine(ii) = errorbar(ax,1,1,[]);
                                obj.ThermalLine(ii).Marker = mOrder(ii);
                                obj.ThermalLine(ii).MarkerFaceColor = co(mod(ii + nSub-1,conum)+1,:);
                                obj.ThermalLine(ii).MarkerEdgeColor = co(mod(ii + nSub-1,conum)+1,:)*.5;
                                obj.ThermalLine(ii).MarkerSize = 8;
                                obj.ThermalLine(ii).LineWidth = 2;
                                obj.ThermalLine(ii).Color = co(ii + nSub,:);
                                obj.ThermalLine(ii).CapSize = 0;
                            end
                            if isempty(becExp.Roi.SubRoi)
                                legendStr = ["Raw","Thermal"];
                            else
                                legendStrThermal = arrayfun(@(x) "Thermal " + x,1:nSub);
                                legendStr = [legendStrRaw,legendStrThermal];
                            end
                            lg = legend(ax,legendStr(:));
                    end
                else
                    if isempty(becExp.Roi.SubRoi)
                        lg = legend(ax,"Raw");
                    else
                        lg = legend(ax,legendStrRaw);
                    end
                end
                hold(ax,'off')

                % Change axis properties
                ax.Box = "on";
                ax.XGrid = "on";
                ax.YGrid = "on";
                ax.XLabel.String = xLabel;
                ax.XLabel.Interpreter = "latex";
                ax.YLim = obj.YLim;
                if nSub > 1 && obj.IsShowNormalized
                    ax.YLabel.String = "${N}_{\mathrm{atom, subroi}}/{N}_{\mathrm{atom, total}}$";
                    ax.YLim = [0,1];
                else
                    ax.YLabel.String = "${N}_{\mathrm{atom}}~[\times 10^{" + string(log(obj.Unit)/log(10)) + "}]$";
                end
                ax.YLabel.Interpreter = "latex";
                ax.FontSize = 12;

                if numel(lg.String) >= 8
                    lg.NumColumns = 2;
                    lg.FontSize = 8;
                    lg.Location = "best";
                end

                % Change visibilities of lines
                if ~isempty(obj.RawLine)
                    if obj.IsShowRaw
                        [obj.RawLine.Visible] = deal("on");
                    else
                        [obj.RawLine.Visible] = deal("off");
                    end
                end
                if ~isempty(obj.ThermalLine)
                    if obj.IsShowThermal
                        [obj.ThermalLine.Visible] = deal("on");
                    else
                        [obj.ThermalLine.Visible] = deal("off");
                    end
                end
                if ~isempty(obj.CondensateLine)
                    if obj.IsShowCondensate
                        [obj.CondensateLine.Visible] = deal("on");
                    else
                        [obj.CondensateLine.Visible] = deal("off");
                    end
                end
                if ~isempty(obj.TotalLine)
                    if obj.IsShowTotal
                        [obj.TotalLine.Visible] = deal("on");
                    else
                        [obj.TotalLine.Visible] = deal("off");
                    end
                end

                % Turn on/off line connections
                if becExp.AveragingMethod == "None"
                    if ~isempty(obj.RawLine)
                        [obj.RawLine.LineStyle] = deal("none");
                    end
                    if ~isempty(obj.ThermalLine)
                        [obj.ThermalLine.LineStyle] = deal("none");
                    end
                    if ~isempty(obj.CondensateLine)
                        [obj.CondensateLine.LineStyle] = deal("none");
                    end
                    if ~isempty(obj.TotalLine)
                        [obj.TotalLine.LineStyle] = deal("none");
                    end
                end
            else
                %% 2D scan initialization
                obj.RawLine = matlab.graphics.primitive.Image.empty;
                obj.ThermalLine = matlab.graphics.primitive.Image.empty;
                obj.CondensateLine = matlab.graphics.primitive.Image.empty;
                obj.TotalLine = matlab.graphics.primitive.Image.empty;
                obj.RawError = matlab.graphics.primitive.Image.empty;
                obj.ThermalError = matlab.graphics.primitive.Image.empty;
                obj.CondensateError = matlab.graphics.primitive.Image.empty;
                obj.TotalError = matlab.graphics.primitive.Image.empty;

                tg = uitabgroup(fig);
                titleStr = "Trial " + becExp.SerialNumber + " Atom Number, " ;

                % Initialize raw plots
                tRaw = uitab(tg, 'Title', 'Raw');
                tgRaw = uitabgroup(tRaw);
                for ii = 1:nSub
                    obj.RawLine(ii) = obj.initializeImage(tgRaw,titleStr,nSub,xLabel,yLabel,ii,"Raw",false);
                    obj.RawError(ii) = obj.initializeImage(tgRaw,titleStr,nSub,xLabel,yLabel,ii,"Raw",true);
                end

                % Initialize thermal plot
                if ismember("DensityFit",becExp.AnalysisMethod)
                    tThermal = uitab(tg, 'Title', 'Thermal');
                    tgThermal = uitabgroup(tThermal);
                    for ii = 1:nSub
                        switch becExp.DensityFit.FitMethod
                            case {"GaussianFit1D","BosonicGaussianFit1D"}
                                obj.ThermalLine(ii) = obj.initializeImage(tgThermal,titleStr,nSub,xLabel,yLabel,ii,"Thermal",false);
                                obj.ThermalError(ii) = obj.initializeImage(tgThermal,titleStr,nSub,xLabel,yLabel,ii,"Thermal",true);
                        end
                    end
                end

            end
        end

        function img = initializeImage(obj,tabGroupObj,titleStr,nSub,xLabel,yLabel,idx,name,isError)
            if isError
                t = uitab(tabGroupObj,'Title',"Error"+idx);
            else
                t = uitab(tabGroupObj,'Title',"Data"+idx);
            end
            ax = axes(t);
            img = imagesc(ax,0);
            ax.XLabel.String = xLabel;
            ax.XLabel.Interpreter = "latex";
            ax.YLabel.String = yLabel;
            ax.YLabel.Interpreter = "latex";
            ax.Colormap = obj.Colormap;
            ax.YDir = "normal";
            if isError
                ax.Title.String = titleStr + name + idx + " Error";
            else
                ax.Title.String = titleStr + name + idx;
            end
            ax.Title.Interpreter = "latex";
            cb = colorbar;
            if nSub > 1 && obj.IsShowNormalized
                ax.CLim = [0,1];
                cb.Label.String = [];
            else
                if ~isError
                    ax.CLim = obj.YLim;
                end
                cb.Label.String = "$\times 10^{" + string(log(obj.Unit)/log(10)) + "}$";
                cb.Label.Interpreter = "latex";
            end
        end

        function updateData(obj,runIdx)
            % Compute atom number components for a given run.
            %
            % Integrates AD density over ROI or sub-ROIs and, if available,
            % computes thermal contribution from :class:`DensityFit`.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
            becExp = obj.BecExp;
            nSub = becExp.Roi.NSub;
            nSub(nSub == 0) = 1;
            px = becExp.Acquisition.PixelSizeReal;

            %% Update Raw data
            if isempty(becExp.Roi.SubRoi)
                obj.Raw(runIdx) = sum(becExp.Ad.AdData(:,:,runIdx),"all") * px^2;
            else
                subData = becExp.Roi.selectSub(becExp.Ad.AdData(:,:,runIdx));
                for ii = 1:nSub
                    obj.Raw(1,runIdx,ii) = sum(subData{ii},"all") * px^2;
                end
            end

            %% Update thermal and condensate data
            if ismember("DensityFit",obj.BecExp.AnalysisMethod)
                for ii = 1:nSub
                    switch obj.BecExp.DensityFit.FitMethod
                        case "GaussianFit1D"
                            obj.Thermal(1,runIdx,ii) = 2 * pi * prod(becExp.DensityFit.ThermalCloudSize(:,runIdx,ii)) * ...
                                becExp.DensityFit.ThermalCloudCentralDensity(1,runIdx,ii);
                        case "BosonicGaussianFit1D"
                            obj.Thermal(1,runIdx,ii) = pi * prod(becExp.DensityFit.ThermalCloudSize(:,runIdx,ii)) * ...
                                becExp.DensityFit.ThermalCloudCentralDensity(1,runIdx,ii) * ...
                                boseFunction(1,3) / boseFunction(1,2);
                    end
                end
            end
        end

        function updateFigure(obj,~)
            % Update figure for 1D or 2D scans based on current data.
            if ishandle(obj.Chart(1).Figure)
                fig = figure(obj.Chart(1).Figure);
            else
                return
            end

            %% Parameters. Use sorted list for plotting
            becExp = obj.BecExp;
            nSub = becExp.Roi.NSub;
            nSub(nSub == 0) = 1;

            if becExp.Is2DScan
                % 2D scan - create density plots
                obj.updateFigure2D(fig, nSub);
            else
                % 1D scan - original line plot logic
                obj.updateFigure1D(fig, nSub);
            end
        end

        function updateFigure1D(obj, fig, nSub)
            % Render 1D scan results with error bars.
            %
            % :param fig: Figure handle
            % :type fig: matlab.ui.Figure
            % :param nSub: Number of sub-ROIs
            % :type nSub: double

            %% Parameters. Use sorted list for plotting
            becExp = obj.BecExp;
            varList = becExp.ScannedVariableList;

            %% Update raw plots
            rawTotal = sum(obj.Raw,3);
            for ii = 1:nSub
                if nSub > 1 && obj.IsShowNormalized
                    [xRaw,yRaw,stdRaw] = computeAveErr(varList,obj.Raw(1,:,ii) ./ rawTotal, becExp.AveragingMethod);
                else
                    [xRaw,yRaw,stdRaw] = computeAveErr(varList,obj.Raw(1,:,ii) / obj.Unit, becExp.AveragingMethod);
                end
                obj.RawLine(ii).XData = xRaw;
                obj.RawLine(ii).YData = yRaw;
                obj.RawLine(ii).YNegativeDelta = stdRaw;
                obj.RawLine(ii).YPositiveDelta = stdRaw;
            end

            %% Update thermal and condensate plots
            if ismember("DensityFit",becExp.AnalysisMethod)
                switch becExp.DensityFit.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D"}
                        thermalTotal = sum(obj.Thermal,3);
                        for ii = 1:nSub
                            if nSub > 1 && obj.IsShowNormalized
                                [xThermal,yThermal,stdThermal] = computeAveErr(varList,obj.Thermal(1,:,ii) ./ thermalTotal, becExp.AveragingMethod);
                            else
                                [xThermal,yThermal,stdThermal] = computeAveErr(varList,obj.Thermal(1,:,ii) / obj.Unit, becExp.AveragingMethod);
                            end
                            obj.ThermalLine(ii).XData = xThermal;
                            obj.ThermalLine(ii).YData = yThermal;
                            obj.ThermalLine(ii).YNegativeDelta = stdThermal;
                            obj.ThermalLine(ii).YPositiveDelta = stdThermal;
                        end
                end
            end

            %% Update lengend position
            lg = findobj(fig,"Type","Legend");
            lg.Location = "best";

            %% Update Line connection
            l = findobj(fig,"Type","Line");
            le = findobj(fig,"Type","ErrorBar");
            if becExp.AveragingMethod == "None"
                if ~isempty(l)
                    [l.LineStyle] = deal("none");
                end
                if ~isempty(le)
                    [le.LineStyle] = deal("none");
                end
            else
                if ~isempty(l)
                    [l.LineStyle] = deal("-");
                end
                if ~isempty(le)
                    [le.LineStyle] = deal("-");
                end
            end
        end

        function updateFigure2D(obj, fig, nSub)
            % Render 2D density plots of selected components.
            %
            % :param fig: Figure handle
            % :type fig: matlab.ui.Figure
            % :param nSub: Number of sub-ROIs
            % :type nSub: double

            %% Parameters. Use sorted list for plotting
            becExp = obj.BecExp;
            varList = becExp.ScannedVariableList;

            %% Update raw plots
            rawTotal = sum(obj.Raw,3);
            for ii = 1:nSub
                if nSub > 1 && obj.IsShowNormalized
                    [xRaw,yRaw,dataRaw,errorRaw] = computeAveErr2D(varList(1,:),varList(2,:),obj.Raw(1,:,ii) ./ rawTotal, becExp.AveragingMethod);
                else
                    [xRaw,yRaw,dataRaw,errorRaw] = computeAveErr2D(varList(1,:),varList(2,:),obj.Raw(1,:,ii) / obj.Unit, becExp.AveragingMethod);
                end
                updateImageData(obj.RawLine(ii),xRaw,yRaw,dataRaw);
                updateImageData(obj.RawError(ii),xRaw,yRaw,errorRaw);
            end

            %% Update thermal and condensate plots
            if ismember("DensityFit",becExp.AnalysisMethod)
                switch becExp.DensityFit.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D"}
                        thermalTotal = sum(obj.Thermal,3);
                        for ii = 1:nSub
                            if nSub > 1 && obj.IsShowNormalized
                                [xThermal,yThermal,dataThermal,errorThermal] = computeAveErr2D(varList(1,:),varList(2,:),obj.Thermal(1,:,ii) ./ thermalTotal, becExp.AveragingMethod);
                            else
                                [xThermal,yThermal,dataThermal,errorThermal] = computeAveErr2D(varList(1,:),varList(2,:),obj.Thermal(1,:,ii) / obj.Unit, becExp.AveragingMethod);
                            end
                            obj.ThermalLine(ii).XData = xThermal;
                            obj.ThermalLine(ii).YData = yThermal;
                            updateImageData(obj.ThermalLine(ii),xThermal,yThermal,dataThermal);
                            updateImageData(obj.ThermalError(ii),xThermal,yThermal,errorThermal);
                        end
                end
            end
        end

        function val = get.Total(obj)
            % Dependent property: total atom number (thermal + condensate).
            %
            % :return: Total atom number array
            % :rtype: double
            val = obj.Thermal + obj.Condensate;
        end
    end

    methods (Static)
        function handlePropEvents(src,evnt)
            % Handle graphics updates when display properties change.
            %
            % :param src: Property metadata
            % :type src: meta.property
            % :param evnt: Event object carrying affected instance
            % :type evnt: event.EventData
            obj = evnt.AffectedObject;

            if isempty(obj.Chart(1).Figure) || ~ishandle(obj.Chart(1).Figure)
                return
            end

            if obj.BecExp.Is2DScan && string(src.Name) ~= "YLim"
                return
            end

            switch src.Name
                case 'YLim'
                    if ~obj.BecExp.Is2DScan
                        fig = obj.Chart(1).Figure;
                        ax = fig.CurrentAxes;
                        ax.YLim = obj.YLim;
                    else
                        fig = obj.Chart(1).Figure;
                        ax = findobj(fig,'Type','Axes');
                        [ax.CLim] = deal(obj.YLim);
                    end
                case 'IsShowRaw'
                    if ~isempty(obj.RawLine)
                        if obj.IsShowRaw
                            [obj.RawLine.Visible] = deal("on");
                        else
                            [obj.RawLine.Visible] = deal("off");
                        end
                    end
                case 'IsShowThermal'
                    if ~isempty(obj.ThermalLine)
                        if obj.IsShowThermal
                            [obj.ThermalLine.Visible] = deal("on");
                        else
                            [obj.ThermalLine.Visible] = deal("off");
                        end
                    end
                case 'IsShowCondensate'
                    if ~isempty(obj.CondensateLine)
                        if obj.IsShowCondensate
                            [obj.CondensateLine.Visible] = deal("on");
                        else
                            [obj.CondensateLine.Visible] = deal("off");
                        end
                    end
                case 'IsShowTotal'
                    if ~isempty(obj.TotalLine)
                        if obj.IsShowTotal
                            [obj.TotalLine.Visible] = deal("on");
                        else
                            [obj.TotalLine.Visible] = deal("off");
                        end
                    end
            end
        end
    end
end

