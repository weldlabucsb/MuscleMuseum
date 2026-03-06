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
        ScopeChannel string
    end

    properties (SetAccess = protected)
        RawOrderFraction
        PulseTime
        PulseAmplitude
        KdDataPrecompute
        DepthOverAmplitude
        PulseOffset
    end

    properties (SetAccess = protected, Hidden)
        PulseTimeVariable
        PulseAmplitudeVariable
        IsRoiValid logical = false
        TimeUnit
        AmplitudeUnit
    end

    properties (Hidden,Transient)
        RawLine
        RawFitLine
    end

    properties (Dependent)
        OpticalLattice OpticalLattice
    end

    properties (Constant)
        DepthMaxEr = 200
        DepthStepEr = 0.01
        OrderMaxTDSE = 20
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
            ol = OpticalLattice(obj.BecExp.Atom,Laser(wavelength=obj.Wavelength,direction=dir));
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
            %% Error handling
            if ~isprop(becExp,"AtomNumber")
                becExp.addAnalysis("AtomNumber")
                becExp.refresh("AtomNumber")
            end

            switch obj.ParameterMethod
                case "ReadVariable"
                    try
                        obj.PulseTimeVariable = becExp.VariableMapping("KdPulseTime");
                        obj.TimeUnit = unit2SI(becExp.VariableUnitSetting.readValue(obj.PulseTimeVariable,"ScannedVariableUnit","ScannedVariable"));
                    catch
                        becExp.displayLog("KdPulseTime Variable was not properly set in MmConfig. Can not do Kd analyis when ParameterMethod is set to ReadVariable.","error")
                    end
                    try
                        obj.PulseAmplitudeVariable = becExp.VariableMapping("KdPulseAmplitude");
                        obj.AmplitudeUnit = unit2SI(becExp.VariableUnitSetting.readValue(obj.PulseAmplitudeVariable,"ScannedVariableUnit","ScannedVariable"));
                    catch
                        becExp.displayLog("KdPulseAmplitude Variable was not properly set in MmConfig. Can not do Kd analyis when ParameterMethod is set to ReadVariable.","error")
                    end
                case "FitScope"
                    if isempty(obj.ScopeChannel) || count(obj.ScopeChannel,"_") ~= 1
                        becExp.displayLog("ScopeChannel is not set properly. It has to be ScopeName_ChannelNumber. Can not do Kd analyis when ParameterMethod is set to FitScope","error")
                    end
                    svStr = obj.ScopeChannel + "_" + ["TrapezoidalAmplitude","TrapezoidalDuration","TrapezoidalOffset"];
                    if ~isprop(becExp,"ScopeValue")
                        becExp.addAnalysis("ScopeValue")
                    end
                    oldFVN = becExp.ScopeValue.FullValueName;
                    if ~isempty(oldFVN) && oldFVN(1) ~="" && oldFVN(1) ~= "None"
                        becExp.ScopeValue.FullValueName = unique([oldFVN,svStr]);
                    else
                        becExp.ScopeValue.FullValueName = svStr;
                    end
                    if ~isempty(setdiff(oldFVN,becExp.ScopeValue.FullValueName)) || ~isempty(setdiff(becExp.ScopeValue.FullValueName,oldFVN))
                        becExp.refresh("ScopeValue")
                    end
            end

            if obj.RoiMethod == "Manual"
                nRoi = obj.BecExp.Roi.NSub;
                if mod(nRoi,2) == 0
                    becExp.displayLog("The number of subrois must be odd for Kd fit.","error")
                else
                    obj.OrderMaxFinal = floor(nRoi/2);
                    obj.IsRoiValid = true;
                end
            else
                obj.OrderMaxFinal = obj.OrderMax;
            end

            %% Initialize lines
            ax = gca;
            hold(ax,"on")
            co = ax.ColorOrder;
            mOrder = markerOrder();
            obj.RawLine = matlab.graphics.chart.primitive.Line.empty;
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
                obj.RawLine(ii).LineStyle = 'none';
                obj.RawFitLine(ii) = line(ax,1,1);
                obj.RawFitLine(ii).LineWidth = 2;
                obj.RawFitLine(ii).Color = co(ii,:);
            end
            hold(ax,"off")

            %% Render
            ax.Box = "on";
            ax.XGrid = "on";
            ax.YGrid = "on";
            ax.FontSize = 12;
            ax.YLabel.Interpreter = "latex";
            ax.YLabel.String = "$P_n$";
            ax.XLabel.Interpreter = "latex";
            switch obj.ScanType
                case "Time"
                    ax.XLabel.String = "$t_{\mathrm{pulse}}~[\mu\mathrm{s}]$";
                case "Power"
                    ax.XLabel.String = "Optical Power $[\mathrm{V}]$";
            end
            ax.YLim = [0,1];
            ax.Title.Interpreter = "latex";
            ax.Title.String = "Fit Result";
            legendStrRaw = arrayfun(@(x) "$n = " + x + "$",0:obj.OrderMaxFinal);
            legend(obj.RawLine,legendStrRaw(:),'Interpreter','latex')         
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
            if obj.BecExp.NCompletedRun == 1 && runIdx == 1 && ~obj.IsRoiValid
                obj.generateRoi
            end
            if ~obj.IsRoiValid
                return
            end
            becExp = obj.BecExp;
            switch obj.ParameterMethod
                case "ReadVariable"
                    obj.PulseTime = becExp.CiceroData.(obj.PulseTimeVariable) * obj.TimeUnit;
                    obj.PulseAmplitude = becExp.CiceroData.(obj.PulseAmplitudeVariable) * obj.AmplitudeUnit;
                    obj.PulseOffset = 0;
                case "FitScope"
                    obj.PulseTime = becExp.ScopeData.(obj.ScopeChannel + "_TrapezoidalDuration");
                    obj.PulseAmplitude = becExp.ScopeData.(obj.ScopeChannel + "_TrapezoidalAmplitude");
                    obj.PulseOffset = becExp.ScopeData.(obj.ScopeChannel + "_TrapezoidalOffset");
            end
            temp = becExp.AtomNumber.Raw;
            omf = obj.OrderMaxFinal;
            leftWing = temp(:,:,1:omf);
            rightWing = temp(:,:,(omf+2):end);
            obj.RawOrderFraction = zeros([size(temp,[1,2]),omf+1]);
            obj.RawOrderFraction(:,:,1) = temp(:,:,omf+1);
            obj.RawOrderFraction(:,:,2:end) = flip(leftWing,3) + rightWing;
            obj.RawOrderFraction = obj.RawOrderFraction ./ sum(obj.RawOrderFraction,3);
        end

        function updateFigure(obj,runIdx)
            % Update diffraction order population plots.
            %
            % **TODO:** Implement visualization of diffraction order populations
            % versus scanned parameter, with comparison to theoretical predictions.
            %
            % :param ~: Unused run index placeholder
            % :type ~: double
            % TODO: plot diffraction order populations vs parameter
        end

        function fit(obj)
            becExp = obj.BecExp;

            % update raw data plot
            for ii = 1:numel(obj.RawLine)
                obj.RawLine(ii).YData = obj.RawOrderFraction(:,:,ii);
                switch obj.ScanType
                    case "Time"
                        obj.RawLine(ii).XData = obj.PulseTime;
                    case "Power"
                        obj.RawLine(ii).XData = obj.PulseAmplitude;
                end
            end

            % Precompute Kd Data
            Er = obj.OpticalLattice.RecoilEnergy;
            depthList = (0:obj.DepthStepEr:obj.DepthMaxEr) * Er;
            if obj.KdFitMethod == "TDSE" && isempty(obj.KdDataPrecompute)
                becExp.displayLog("Pre-computing KD data...")
                obj.KdDataPrecompute = computeKd(...
                    obj.OpticalLattice,...
                    depthList,...
                    mean(obj.PulseTime(:)),...
                    obj.OrderMaxTDSE);
                becExp.displayLog("Done...")
            end

            % Interpolate
            KdInterp = cell(1,obj.OrderMaxFinal + 1);
            for nn = 1:(obj.OrderMaxFinal+1)
                nthOrder = obj.KdDataPrecompute(:,obj.OrderMaxTDSE + nn);
                KdInterp{nn} = @(q) interp1(depthList / Er, nthOrder, q, 'pchip', 'extrap');
            end

            % Error function
            p = obj.PulseAmplitude(:);
            rawFrac = squeeze(obj.RawOrderFraction);
            errFun = @(k) sum(arrayfun(@(jj) sum(abs(KdInterp{jj}(k * p) - rawFrac(:,jj)).^2),1:obj.OrderMax+1));

            % Optimization
            kMax = obj.DepthMaxEr / (max(p) + eps);
            kCandidates = linspace(0, kMax, 100);
            vals = arrayfun(@(k) errFun(k), kCandidates);
            [~,idx] = min(vals);
            k0 = max(kCandidates(idx), 1e-9);
            obj.DepthOverAmplitude = fminsearch(errFun,k0);
            ax = findobj(obj.Chart(1).Figure,'Type','Axes');

            % Display
            ax.Title.String = "$t_{\mathrm{pulse}} = " + mean(obj.PulseTime(:)) * 1e6 + "~\mu\mathrm{s}$, " + ...
                "$V_0 ~\mathrm{in} ~ E_{\mathrm{R}} = " + num2str(obj.DepthOverAmplitude) + "\times (\mathrm{Power} - " + mean(obj.PulseOffset(:)) + ")$";
            for ii = 1:obj.OrderMaxFinal + 1
               obj.RawFitLine(ii).XData = linspace(min(p),max(p),1000) + mean(obj.PulseOffset(:));
               obj.RawFitLine(ii).YData = KdInterp{ii}(obj.DepthOverAmplitude * obj.RawFitLine(ii).XData);
            end
        end

        function generateRoi(obj)
            becExp = obj.BecExp;
            if obj.RoiMethod == "Auto"
                if becExp.NCompletedRun == 0
                    becExp.displayLog("Can not generate KD ROIs without knowing thet TofTime. Please run the experiment once.","error")
                end
                try
                    TofTimeVariable = becExp.VariableMapping("TofTime");
                catch
                    becExp.displayLog("TofTime Variable was not properly set in MmConfig. Can not generate Roi for Kd analyis.","error")
                end
                unit = becExp.VariableUnitSetting.readValue(TofTimeVariable,"ScannedVariableUnit","ScannedVariable");
                Tof = becExp.CiceroData.(TofTimeVariable);
                Tof = Tof(1) * unit2SI(unit);
                if Tof == 0
                    becExp.displayLog("Can not do Kd analyis when Tof = 0.","error")
                end
                hbar = Constants.SI("hbar");
                seperation = 2 * hbar * 2 * pi / obj.Wavelength / becExp.Atom.mass * Tof;
                seperation = round(seperation / becExp.Acquisition.PixelSizeReal);
                if becExp.CenterReferenceID ~= 0
                    ref = becExp.BecExpData.readValue(becExp.CenterReferenceID,"CloudCenter","TrialID");
                else
                    becExp.displayLog("Center reference was not defined. Can not generate Roi for Kd analyis.","error")
                end
                switch obj.LatticeAxis
                    case "X"
                        subNRowColumn = [1,obj.OrderMax * 2 + 1];
                    case "Y"
                        subNRowColumn = [obj.OrderMax * 2 + 1,1];
                end
                obj.IsRoiValid = true;
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

