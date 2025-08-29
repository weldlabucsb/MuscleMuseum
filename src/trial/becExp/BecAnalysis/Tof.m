classdef Tof < BecAnalysis
    %OD Summary of this class goes here
    %   Detailed explanation goes here

    properties
        FitDataThermal
        FitDataCondensate
    end

    properties (SetAccess = protected)
        TofTime double
        Temperature double
        TrappingFrequency double %[omega_x;omega_y]
        ThermalCloudSizeInSitu double
        ThermalCloudCentralDensityInSitu double
        PhaseSpaceDensity double
    end

    properties (Hidden,Transient)
        ThermalXLine
        ThermalXFitLine
        ThermalYLine
        ThermalYFitLine
        CondensateXLine
        CondensateXFitLine
        CondensateYLine
        CondensateYFitLine
        ParaTable
        kBoverM
        lambdaDBPrefator
    end

    methods
        function obj = Tof(becExp)
            %OD Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Time of flight",...
                num = 31, ...
                fpath = fullfile(becExp.DataAnalysisPath,"Tof"),...
                loc = [0.6936,0.032],...
                size = [0.3069,0.57]...
                );
        end

        function initialize(obj)
            %% Check if we can do TOF analysis
            if obj.BecExp.ScannedVariable ~= "TOF"
                warning("Scanned Variable is not TOF. Can not do TOF analysis")
                return
            elseif ~ismember("DensityFit",obj.BecExp.AnalysisMethod)
                warning("No DensityFit. Can not do TOF analysis")
                return
            elseif ~isempty(obj.BecExp.Roi.SubRoi)
                warning("Can not do TOF analysis for sub-ROIs.")
                return
            end

            %% Turn off density fit cloud size plots
            obj.BecExp.DensityFit.Chart(1).IsEnabled = false;
            if ishandle(obj.BecExp.DensityFit.Chart(1).Figure)
                close(obj.BecExp.DensityFit.Chart(1).Figure);
            end

            %% Initialize parameters
            obj.FitDataThermal = LinearFit1D([1,1]);
            obj.FitDataThermal = repmat(obj.FitDataThermal,2,1);
            obj.TofTime = 0;
            m = obj.BecExp.Atom.mass;
            kB = Constants.SI("kB");
            obj.kBoverM = kB/m;
            obj.lambdaDBPrefator = Constants.SI("hbar") * sqrt(2 * pi / m / kB);

            %% Initialize plots
            fig = obj.Chart(1).initialize;
            if ~ishandle(fig)
                return
            end

            % Initialize the figure
            p1 = uipanel(fig,"Position",[0,0.3,1,0.7]);
            ax = axes(p1);
            ax.XLabel.String = "$t^{2}_{\mathrm{TOF}}$ [$\mu\mathrm{s}^2$]";
            ax.XLabel.Interpreter = "latex";
            ax.YLabel.String = "$R^{2}$ [$\mu\mathrm{m}^2$]";
            ax.YLabel.Interpreter = "latex";
            ax.FontSize = 12;
            ax.Box = "on";
            ax.XGrid = "on";
            ax.YGrid = "on";
            co = ax.ColorOrder;
            
            % Initialize the table
            p2 = uipanel(fig,"Position",[0,0,1,0.3]);
            obj.ParaTable = uitable(p2,'Data', [1 2 3],Unit='normalized',Position=[0,0,1,1]);
            obj.ParaTable.ColumnName = {'Parameter','Value','Unit'};
            data{1,1} = 'Temperature';
            data{1,2} = '';
            data{1,3} = 'μK';
            data{2,1} = 'Thermal Cloud Radius in x';
            data{2,2} = '';
            data{2,3} = 'μm';
            data{3,1} = 'Thermal Cloud Radius in y';
            data{3,2} = '';
            data{3,3} = 'μm';
            data{4,1} = 'Thermal Cloud Central Column Density';
            data{4,2} = '';
            data{4,3} = 'm^-2';
            data{5,1} = 'Trapping frequency in x';
            data{5,2} = '';
            data{5,3} = 'Hz';
            data{6,1} = 'Trapping frequency in y';
            data{6,2} = '';
            data{6,3} = 'Hz';
            data{7,1} = 'Maximum Phase Space Density';
            data{7,2} = '';
            data{7,3} = '';

            obj.ParaTable.Data = data;
            obj.ParaTable.FontSize = 12;
            obj.ParaTable.Units = 'pixel';
            tWidth = obj.ParaTable.Position(3);
            obj.ParaTable.ColumnWidth={tWidth/2.01 tWidth/4.01 tWidth/4.01};
            obj.ParaTable.ColumnEditable=[false false];
            obj.ParaTable.RowName=[];
            obj.ParaTable.Units = 'normalized';

            switch obj.BecExp.DensityFit.FitMethod
                case {"GaussianFit1D","BosonicGaussianFit1D"}
                    obj.ThermalXLine = line(ax,1,1);
                    obj.ThermalXLine.Marker = "o";
                    obj.ThermalXLine.MarkerFaceColor = co(1,:);
                    obj.ThermalXLine.MarkerEdgeColor = co(1,:)*.5;
                    obj.ThermalXLine.MarkerSize = 8;
                    obj.ThermalXLine.LineWidth = 2;
                    obj.ThermalXLine.LineStyle = "none";

                    obj.ThermalXFitLine = line(ax,1,1);
                    obj.ThermalXFitLine.LineWidth = 2;
                    obj.ThermalXFitLine.Color = co(1,:);

                    obj.ThermalYLine = line(ax,1,1);
                    obj.ThermalYLine.Marker = "o";
                    obj.ThermalYLine.MarkerFaceColor = co(2,:);
                    obj.ThermalYLine.MarkerEdgeColor = co(2,:)*.5;
                    obj.ThermalYLine.MarkerSize = 8;
                    obj.ThermalYLine.LineWidth = 2;
                    obj.ThermalYLine.LineStyle = "none";

                    obj.ThermalYFitLine = line(ax,1,1);
                    obj.ThermalYFitLine.LineWidth = 2;
                    obj.ThermalYFitLine.Color = co(2,:);

                    lg = legend(ax,"$R^{2}_{\mathrm{thermal},x}$ Data","$R^{2}_{\mathrm{thermal},x}$ Fit", ...
                        "$R^{2}_{\mathrm{thermal},y}$ Data","$R^{2}_{\mathrm{thermal},y}$ Fit");
                    lg.Interpreter = "latex";
                    lg.Location = "best";
            end

        end

        function updateData(obj,~)
            becExp = obj.BecExp;
            if becExp.ScannedVariable ~= "TOF" || becExp.NCompletedRun < 2 ||...
                    ~ismember("DensityFit",obj.BecExp.AnalysisMethod) ||...
                    ~isempty(obj.BecExp.Roi.SubRoi)
                return
            end
            obj.TofTime = becExp.ScannedVariableList * unit2SI(becExp.ScannedVariableUnit);
            wt = obj.BecExp.DensityFit.ThermalCloudSize;
            obj.FitDataThermal = [LinearFit1D([(obj.TofTime.^2).',(wt(1,:).^2).']);...
                LinearFit1D([(obj.TofTime.^2).',(wt(2,:).^2).'])];
            obj.FitDataThermal(1).do;
            obj.FitDataThermal(2).do;

            obj.Temperature = mean([obj.FitDataThermal(1).Coefficient(1),obj.FitDataThermal(2).Coefficient(1)]) / ...
                2 / obj.kBoverM;
            obj.TrappingFrequency = sqrt(1 ./ ([obj.FitDataThermal(1).Coefficient(2);obj.FitDataThermal(2).Coefficient(2)] / ...
                2 / obj.kBoverM / obj.Temperature));
            obj.ThermalCloudSizeInSitu = sqrt([obj.FitDataThermal(1).Coefficient(2);obj.FitDataThermal(2).Coefficient(2)]);
            obj.ThermalCloudCentralDensityInSitu = max(becExp.AtomNumber.Thermal) / ...
                pi / prod(obj.ThermalCloudSizeInSitu) / boseFunction(1,3) * boseFunction(1,2);
            lambdaDB = obj.lambdaDBPrefator * sqrt(1./obj.Temperature);
            sigma = sqrt(prod(obj.ThermalCloudSizeInSitu));
            n3D = obj.ThermalCloudCentralDensityInSitu / sigma / sqrt(2 * pi) / boseFunction(1,2);
            obj.PhaseSpaceDensity = n3D * lambdaDB^3;
        end

        function updateFigure(obj,~)
            becExp = obj.BecExp;
            fig = obj.Chart(1).Figure;
            if becExp.ScannedVariable ~= "TOF" || becExp.NCompletedRun < 2 ...
                    || (isempty(fig) || ~ishandle(fig)) || ~ismember("DensityFit",obj.BecExp.AnalysisMethod) ||...
                    ~isempty(obj.BecExp.Roi.SubRoi)
                return
            end
            
            switch obj.BecExp.DensityFit.FitMethod
                case {"GaussianFit1D","BosonicGaussianFit1D"}
                    rawXT = obj.FitDataThermal(1).RawData;
                    fitXT = obj.FitDataThermal(1).FitPlotData;
                    rawYT = obj.FitDataThermal(2).RawData;
                    fitYT = obj.FitDataThermal(2).FitPlotData;
                    obj.ThermalXLine.XData = rawXT(:,1) * 1e12;
                    obj.ThermalXLine.YData = rawXT(:,2) * 1e12;
                    obj.ThermalXFitLine.XData = fitXT(:,1) * 1e12;
                    obj.ThermalXFitLine.YData = fitXT(:,2) * 1e12;
                    obj.ThermalYLine.XData = rawYT(:,1) * 1e12;
                    obj.ThermalYLine.YData = rawYT(:,2) * 1e12;
                    obj.ThermalYFitLine.XData = fitYT(:,1) * 1e12;
                    obj.ThermalYFitLine.YData = fitYT(:,2) * 1e12;

                    obj.ParaTable.Data{1,2} = obj.Temperature * 1e6;
                    obj.ParaTable.Data{2,2} = obj.ThermalCloudSizeInSitu(1) * 1e6;
                    obj.ParaTable.Data{3,2} = obj.ThermalCloudSizeInSitu(2) * 1e6;
                    obj.ParaTable.Data{4,2} = obj.ThermalCloudCentralDensityInSitu;
                    obj.ParaTable.Data{5,2} = obj.TrappingFrequency(1);
                    obj.ParaTable.Data{6,2} = obj.TrappingFrequency(2);
                    obj.ParaTable.Data{7,2} = obj.PhaseSpaceDensity;
            end
            lg = findobj(fig,"Type","Legend");
            lg.Location = "best";
        end

        function refresh(obj)
            obj.initialize;
            obj.updateData(obj.BecExp.NCompletedRun)
            obj.updateFigure(obj.BecExp.NCompletedRun)
        end

    end
end

