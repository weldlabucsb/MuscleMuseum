classdef KapitzaDirac < BecAnalysis
    %:class:`KapitzaDirac` analyze Kapitza-Dirac diffraction patterns.
    %
    % Placeholder for future analysis of momentum-space diffraction from a
    % pulsed lattice. Intended to extract diffraction order populations and
    % compare with simple Raman-Nath predictions.
    %
    % **Associated Charts:**
    %   - Chart(1): "Kapitza Dirac" - Diffraction order population analysis (future implementation)
    
    properties
        Wavelength (1,1) double = 1064e-9
        LatticeAxis string = "Y"
        OrderMax (1,1) double = 2
        OrderMaxFinal (1,1) double
        RoiSize (1,1) double = 50
        RoiMethod string = "Auto"
        KdFitMethod string = "TDSE"
        ParameterMethod string = "ReadVariable"
        ScanType string = "Power"
        ScopeChannel string = "LatticeScope_ch1"
    end

    properties (Constant)
        % Reserved for future physical constants and calibration factors
    end

    properties (SetObservable)
        % Reserved for future plot display settings and toggles
    end

    properties (Hidden,Transient)
        RawLine
        RawFitLine
    end

    properties (Dependent)
        OpticalLattice OpticalLattice
    end
    
    methods
        function obj = KapitzaDirac(becExp)
            % Construct :class:`KapitzaDirac` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Kapitza Dirac",...
                num = 32, ...
                fpath = fullfile(becExp.DataAnalysisPath,"KapitzaDirac"),...
                loc = [0.6936,0.032],...
                size = [0.3069,0.57]...
                );
        end

        function ol = get.OpticalLattice(obj)
            switch obj.LatticeAxis
                case "X"
                    dir = [1,0,0];
                case "Y"
                    dir = [0,1,0];
            end
            ol = OpticalLattice(obj.BecExp.Atom,laser(wavelength=obj.Wavelength,direction=dir));
        end
        
        function initialize(obj)
            % Initialize figure for Kapitza-Dirac diffraction analysis.
            %
            % Sets up the analysis chart window. Currently a placeholder for
            % future diffraction pattern visualization.
            fig = obj.Chart(1).initialize;

            if ~ishandle(fig)
                return
            end

            becExp = obj.BecExp;
            if obj.RoiMethod == "Manual"
                nRoi = obj.BecExp.Roi.NSub;
                if mod(nRoi,2) == 0
                    error("The number of subrois must be odd for Kd fit.")
                else
                    obj.OrderMaxFinal = floor(nRoi/2);
                end
            else
                obj.OrderMaxFinal = obj.OrderMax;
            end

            % Initialize lines
            ax = gca;
            co = ax.ColorOrder;
            mOrder = markerOrder();
            obj.RawLine = matlab.graphics.chart.primitive.ErrorBar.empty;
            obj.RawFitLine = matlab.graphics.chart.primitive.Line.empty;
            for ii = 1:(1+obj.OrderMaxFinal)
                obj.RawLine(ii) = errorbar(ax,1,1,[]);
                obj.RawLine(ii).Marker = mOrder(ii);
                obj.RawLine(ii).MarkerFaceColor = co(ii,:);
                obj.RawLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                obj.RawLine(ii).MarkerSize = 8;
                obj.RawLine(ii).LineWidth = 2;
                obj.RawLine(ii).Color = co(ii,:);
                obj.RawLine(ii).CapSize = 0;
                obj.RawFitLine(ii) = line(ax,1,1);
                obj.RawFitLine(ii).LineWidth = 2;
                obj.RawFitLine(ii).Color = co(ii,:);
            end
            % legendStrRaw = arrayfun(@(x) "Raw " + x,1:nSub);
        end

        function updateData(obj,runIdx)
            % Extract diffraction order populations from momentum distribution.
            %
            % **TODO:** Implement analysis of momentum-space diffraction patterns
            % from pulsed optical lattice interactions to extract diffraction
            % order populations and compare with Raman-Nath theory.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
        end

        function updateFigure(obj,~)
            % Update diffraction order population plots.
            %
            % **TODO:** Implement visualization of diffraction order populations
            % versus scanned parameter, with comparison to theoretical predictions.
            %
            % :param ~: Unused run index placeholder
            % :type ~: double
            % TODO: plot diffraction order populations vs parameter
        end

        function generateRoi(obj)
            becExp = obj.BecExp;
            if obj.RoiMethod == "Auto" && becExp.NCompletedRun >= 1
                try
                    TofTimeVariable = becExp.VariableMapping("TofTime");
                catch
                    error("TofTime Variable was not properly set in MmConfig. Can not generate Roi for Kd analyis.")
                end
                unit = becExp.VariableUnitSetting.readValue(TofTimeVariable,"ScannedVariableUnit","ScannedVariable");
                Tof = becExp.CiceroData.(TofTimeVariable);
                Tof = Tof(1) * unit2SI(unit);
                if Tof == 0
                    error("Can not do Kd analyis when Tof = 0.")
                end
                hbar = Constants.SI("hbar");
                seperation = 2 * hbar * 2 * pi / obj.Wavelength / becExp.Atom.mass * Tof;
                seperation = round(seperation / becExp.Acquisition.PixelSizeReal);
                if becExp.CenterReferenceID ~= 0
                    ref = becExp.BecExpData.readValue(becExp.CenterReferenceID,"CloudCenter","TrialID");
                    ref = becExp.Roi.noRotationFull2Full(ref);
                else
                    error("Center reference was not defined. Can not generate Roi for Kd analyis.")
                end
                switch obj.LatticeAxis
                    case "X"
                        subNRowColumn = [1,obj.OrderMax * 2 + 1];
                    case "Y"
                        subNRowColumn = [obj.OrderMax * 2 + 1,1];
                end
                subCenterSize = [ref,obj.RoiSize,obj.RoiSize];
                becExp.Roi.SubRoiSeparation = seperation;
                becExp.Roi.SubRoiNRowColumn = subNRowColumn;
                becExp.Roi.SubRoiCenterSize = subCenterSize;
                becExp.Ad.Gui(1).App.Roi.SubRoiSeparation = seperation;
                becExp.Ad.Gui(1).App.Roi.SubRoiNRowColumn = subNRowColumn;
                becExp.Ad.Gui(1).App.Roi.SubRoiCenterSize = subCenterSize;
                becExp.refresh
            end
        end

    end
end

