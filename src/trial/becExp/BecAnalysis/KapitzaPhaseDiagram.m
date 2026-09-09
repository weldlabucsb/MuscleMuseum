% filepath: c:\Users\Nicole\Documents\MuscleMuseum\src\trial\becExp\BecAnalysis\KapitzaPhaseDiagram.m
classdef KapitzaPhaseDiagram < BecAnalysis
    %:class:`KapitzaPhaseDiagram` live 1D/2D parameter scan analysis for Kapitza pendulum.
    
    properties
        MetricName string = "StdDev2" % "IPR", "CentralAtomFraction", "StdDev", "StdDev2"
        InvertOmegaAxis logical = true % Low frequencies at top of image
        NoiseFloor double = 0 % For StdDev2 background correction cutoff
        UseDimensionlessAxes logical = true % Toggle between alpha/Omega or raw variables
        ModDepthVariable string = "hw_KPModDepthAlpha" % HardwareData field storing dimensionless alpha (fixed value display in 1D freq scans)
        ModFreqVariable string = "hw_KPModFreq" % HardwareData field storing modulation frequency in Hz (fixed value display in 1D depth scans)
    end

    properties (SetAccess = protected)
        MetricValue double % 1D array of computed metric per run
    end

    properties (Hidden, Transient)
        PhaseImage % Handle to imagesc object
        DimensionlessScaleCache = struct('beta', [], 'f0', [], 'ok', false) % Cache to avoid rebuilding OpticalLattice every call
    end

    methods
        function obj = KapitzaPhaseDiagram(becExp)
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Kapitza Phase Diagram",...
                num = 45, ...
                fpath = fullfile(becExp.DataAnalysisPath, "KapitzaPhaseDiagram"),...
                loc = [0.6936, 0.05],...
                size = [0.3069, 0.45]...
            );
        end

        function initialize(obj)
            fig = obj.Chart(1).initialize;
            if ~ishandle(fig)
                return
            end
            
            becExp = obj.BecExp;
            
            % Ensure Ad analysis is present -- KapitzaPhaseDiagram depends on
            % becExp.Ad.AdData (live atomic density), mirroring how AtomNumber
            % and KapitzaDirac declare their dependencies.
            if ~isprop(becExp, "Ad")
                becExp.addAnalysis("Ad")
            end
            
            obj.MetricValue = [];
            obj.DimensionlessScaleCache = struct('beta', [], 'f0', [], 'ok', false); % Reset cache for new trial

            ax = gca(fig);
            obj.PhaseImage = imagesc(ax, []);
            ax.Colormap = parula;
            cb = colorbar(ax);
            cb.Label.Interpreter = "latex";
            
            if obj.InvertOmegaAxis
                ax.YDir = "reverse";
            else
                ax.YDir = "normal";
            end
            
            ax.FontSize = 12;
        end

        function updateData(obj, runIdx)
            becExp = obj.BecExp;
            
            % Use live atomic column density (matches AtomNumber.updateData).
            % becExp.Ad.AdData is populated per-run during live acquisition
            % (Ad.update) and reconstructed for offline-reloaded trials via
            % Ad.refresh -- do NOT use Od.RoiData (raw optical depth) or a
            % nonexistent Ad.RoiData property.
            if size(becExp.Ad.AdData, 3) < runIdx
                return % Not yet computed for this run
            end
            adData = becExp.Ad.AdData(:,:,runIdx);
            
            pixelSize = becExp.Acquisition.PixelSizeReal;
            
            % Compute Metric
            switch obj.MetricName
                case "IPR"
                    val = obj.computeIPR(adData);
                case "IPR22"
                    val = obj.computeIPR2(adData);
                case "CentralAtomFraction"
                    val = obj.computeCentralAtomFraction(adData);
                case "StdDev"
                    val = obj.computeStDev(adData, pixelSize);
                case "StdDev2"
                    val = obj.computeStDevWithBgSub(adData, pixelSize, obj.NoiseFloor);
                case "ExcessKurtosis"
                    val = obj.computeKurtosis(adData, pixelSize, obj.NoiseFloor);
                case "FringeVisibility"
                    val = obj.computeVisibility(adData);
                case "FourierPower"
                    val = obj.computeFFTPower(adData);
                otherwise
                    val = obj.computeStDevWithBgSub(adData, pixelSize, obj.NoiseFloor);
            end
            
            obj.MetricValue(runIdx) = val;
        end

        function updateFigure(obj, ~)
            if ~ishandle(obj.Chart(1).Figure) || isempty(obj.MetricValue)
                return
            end
            fig = obj.Chart(1).Figure;
            ax = gca(fig);
            
            if obj.isScan2D()
                obj.updateFigure2D(ax);
            else
                obj.updateFigure1D(ax);
            end
        end

        function updateFigure2D(obj, ax)
            % Use BecAnalysis 2D utilities
            [xRaw, yRaw] = obj.get2DPlotData();
            if isempty(xRaw) || isempty(yRaw)
                return; % Not a 2D scan yet
            end
            
            xPlot = xRaw;
            yPlot = yRaw;
            
            % Convert to dimensionless if selected
            if obj.UseDimensionlessAxes
                [beta, f0, ok] = obj.computeDimensionlessScales();
                if ok
                    xPlot = xRaw * beta;
                    yPlot = yRaw / f0;
                    
                    ax.XLabel.String = "$\alpha$";
                    ax.XLabel.Interpreter = "latex";
                    ax.YLabel.String = "$\Omega$";
                    ax.YLabel.Interpreter = "latex";
                    ax.XLabel.FontSize = 14;
                    ax.YLabel.FontSize = 14;
                end
            else
                % Use properties directly from the Trial class
                try
                    xName = obj.BecExp.ScannedVariable;
                    xUnit = obj.BecExp.ScannedVariableUnit;
                    yName = obj.BecExp.ScannedVariable2;
                    yUnit = obj.BecExp.ScannedVariableUnit2;
                    
                    % Add parenthesis around units if they exist and are not "None"
                    if xUnit ~= "" && xUnit ~= "None", xName = xName + " (" + xUnit + ")"; end
                    if yUnit ~= "" && yUnit ~= "None", yName = yName + " (" + yUnit + ")"; end
                    
                    ax.XLabel.String = localLatexEscape(xName);
                    ax.YLabel.String = localLatexEscape(yName);
                catch
                    ax.XLabel.String = "Scan Variable 1";
                    ax.YLabel.String = "Scan Variable 2";
                end
                ax.XLabel.Interpreter = "latex";
                ax.YLabel.Interpreter = "latex";
                ax.XLabel.FontSize = 14;
                ax.YLabel.FontSize = 14;
            end
            
            metric2D = obj.reshapeDataTo2D(obj.MetricValue);

            % Update heatmap
            obj.PhaseImage.XData = xPlot;
            obj.PhaseImage.YData = yPlot;
            obj.PhaseImage.CData = metric2D;
            
            % Smart Axis Ticks and Padding
            uX = unique(xPlot);
            uY = unique(yPlot);
            
            % Calculate half-pixel spacing to perfectly border the tiles
            if length(uX) > 1, dx = uX(2)-uX(1); else, dx = 1; end
            if length(uY) > 1, dy = abs(uY(2)-uY(1)); else, dy = 1; end
            
            ax.XLim = [min(xPlot) - dx/2, max(xPlot) + dx/2];
            ax.YLim = [min(yPlot) - dy/2, max(yPlot) + dy/2];
            
            if length(uX) <= 6
                ax.XTick = uX;
                ax.XTickLabel = string(num2str(uX(:), '%.4g')); % Clean format (e.g. 27.11)
            else
                ax.XTickMode = 'auto'; % Let MATLAB pick nice spacing
                ax.XTickLabelMode = 'auto';
            end
            
            if length(uY) <= 6
                ax.YTick = uY;
                ax.YTickLabel = string(num2str(uY(:), '%.4g'));
            else
                ax.YTickMode = 'auto';
                ax.YTickLabelMode = 'auto';
            end
            
            obj.applyColorLimitsAndColorbar(ax, metric2D);
            obj.buildTitle(ax);
        end

        function updateFigure1D(obj, ax)
                   becExp = obj.BecExp;
            freqScanned = obj.isFreqScanned();
            
            % Pull raw scanned variable across runs
            try
                scanRaw = becExp.HardwareData.(char(becExp.ScannedVariable));
            catch
                return
            end
            scanRaw = scanRaw(:)';
            nRuns = min(length(scanRaw), length(obj.MetricValue));
            scanRaw = scanRaw(1:nRuns);
            metric1D = obj.MetricValue(1:nRuns);
            
            % Group and average repeated shots at the same scanned value
            % (mirrors computeAveErr in the external analysis scripts -- without
            % this, repeated shots at identical alpha/Omega values get plotted as
            % separate noisy columns instead of one averaged, smooth value).
            [uniqueScan, ~, groupIdx] = unique(scanRaw);
            avgMetric = accumarray(groupIdx(:), metric1D(:), [], @mean)';
            
            scanRaw = uniqueScan;
            metric1D = avgMetric;
            
            [beta, f0, dimensionlessOk] = obj.computeDimensionlessScales();
            
            % Fixed (non-scanned) value, pulled directly from HardwareData (constant across the scan)
            try
                if freqScanned
                    fixedVal = becExp.HardwareData.(char(obj.ModDepthVariable))(1); % raw alpha
                    if obj.UseDimensionlessAxes && dimensionlessOk
                        fixedVal = fixedVal * beta; % scale to dimensionless alpha
                    end
                else
                    fixedVal = becExp.HardwareData.(char(obj.ModFreqVariable))(1); % raw Hz
                end
            catch
                fixedVal = NaN;
            end
            
            if freqScanned
                % Scanned variable = frequency -> vertical single-column heatmap (y = Omega)
                yRaw = scanRaw; % already unique + sorted from grouping step above
                metricSorted = metric1D;
                
                if obj.UseDimensionlessAxes && dimensionlessOk
                    yPlot = yRaw / f0;
                    fixedLabelStr = "$\alpha = " + num2str(fixedVal, '%.4g') + "$";
                    yLabelStr = "$\Omega$";
                else
                    yPlot = yRaw;
                    yUnit = becExp.ScannedVariableUnit;
                    yName = becExp.ScannedVariable;
                    if yUnit ~= "" && yUnit ~= "None", yName = yName + " (" + yUnit + ")"; end
                    yLabelStr = localLatexEscape(yName);
                    fixedLabelStr = localLatexEscape(obj.ModDepthVariable) + " = " + num2str(fixedVal, '%.4g');
                end
                
                obj.PhaseImage.XData = [1 2];
                obj.PhaseImage.YData = yPlot;
                obj.PhaseImage.CData = metricSorted(:); % Nx1 column strip
                
                ax.YLabel.String = yLabelStr;
                ax.XLabel.String = fixedLabelStr;
                ax.XTick = [];
                
                if length(yPlot) > 1, dy = abs(yPlot(2)-yPlot(1)); else, dy = 1; end
                ax.YLim = [min(yPlot)-dy/2, max(yPlot)+dy/2];
                ax.XLim = [0.5 2.5];
            else
                % Scanned variable = depth -> horizontal single-row heatmap (x = alpha)
                xRaw = scanRaw; % already unique + sorted from grouping step above
                metricSorted = metric1D;
                
                if obj.UseDimensionlessAxes && dimensionlessOk
                    xPlot = xRaw * beta;
                    fixedLabelStr = "$\Omega = " + num2str(fixedVal / f0, '%.4g') + "$";
                    xLabelStr = "$\alpha$";
                else
                    xPlot = xRaw;
                    xUnit = becExp.ScannedVariableUnit;
                    xName = becExp.ScannedVariable;
                    if xUnit ~= "" && xUnit ~= "None", xName = xName + " (" + xUnit + ")"; end
                    xLabelStr = localLatexEscape(xName);
                    fixedLabelStr = localLatexEscape(obj.ModFreqVariable) + " = " + num2str(fixedVal, '%.4g');
                end
                
                obj.PhaseImage.XData = xPlot;
                obj.PhaseImage.YData = [1 2];
                obj.PhaseImage.CData = metricSorted; % 1xN row strip
                
                ax.XLabel.String = xLabelStr;
                ax.YLabel.String = fixedLabelStr;
                ax.YTick = [];
                
                if length(xPlot) > 1, dx = xPlot(2)-xPlot(1); else, dx = 1; end
                ax.XLim = [min(xPlot)-dx/2, max(xPlot)+dx/2];
                ax.YLim = [0.5 2.5];
            end
            
            ax.XLabel.Interpreter = "latex";
            ax.YLabel.Interpreter = "latex";
            ax.XLabel.FontSize = 14;
            ax.YLabel.FontSize = 14;
            
            obj.applyColorLimitsAndColorbar(ax, metricSorted);
            obj.buildTitle(ax);
        end

        function drawTheoryCurves(obj)
            % Function called by user via AppDesigner button to overlay theory boundaries
            if ~ishandle(obj.Chart(1).Figure)
                return;
            end
            
            fig = obj.Chart(1).Figure;
            ax = gca(fig);
            hold(ax, 'on');
            
            % Clean up any old theory lines first
            oldLines = findobj(ax, 'Tag', 'TheoryLine');
            delete(oldLines);
            
            if obj.isScan2D()
                obj.drawTheoryCurves2D(ax);
            else
                obj.drawTheoryCurves1D(ax);
            end
            
            hold(ax, 'off');
        end

        function drawTheoryCurves2D(obj, ax)
            [xRaw, ~] = obj.get2DPlotData();
            if isempty(xRaw)
                return;
            end
            
            % Axis definitions
            try
                beta = obj.BecExp.HardwareData.hw_KPModDepthBeta(1);
                isInverted = obj.BecExp.HardwareData.hw_KPIsInverted(1);
            catch
                beta = 1; % Fallback
                isInverted = true;
            end
            
            xPlotScale = 1;
            if obj.UseDimensionlessAxes
                xPlotScale = beta;
            end
            
            alphaTheory = linspace(min(xRaw)*beta, max(xRaw)*beta, 1000);
            boundalphaTheory = linspace(max(min(xRaw)*beta, 250/139 + 1e-9), max(xRaw)*beta, 1000);
            
            b1 = obj.kpClassicalBoundary(alphaTheory, 1);
            b2 = obj.kpClassicalBoundary(boundalphaTheory, 2);
            b3 = obj.kpClassicalBoundary(alphaTheory, 3);
            
            % We will plot against configured X-scale, and use raw Omega (since Y is Omega theory bound)
            if isInverted
                plot(ax, alphaTheory / beta * xPlotScale, b1, '--w', 'LineWidth', 1.5, 'Tag', 'TheoryLine');
                plot(ax, boundalphaTheory / beta * xPlotScale, b2, '--w', 'LineWidth', 1.5, 'Tag', 'TheoryLine');
            else
                plot(ax, alphaTheory / beta * xPlotScale, b3, '--w', 'LineWidth', 1.5, 'Tag', 'TheoryLine');
            end
        end

        function drawTheoryCurves1D(obj, ax)
            becExp = obj.BecExp;
            
            try
                isInverted = becExp.HardwareData.hw_KPIsInverted(1);
            catch
                isInverted = true;
            end
            
            freqScanned = obj.isFreqScanned();
            [beta, f0, dimensionlessOk] = obj.computeDimensionlessScales();
            
            if freqScanned
                % X is the fixed alpha "column"; boundary crossings are horizontal lines in Omega
                try
                    alphaFixed = becExp.HardwareData.(char(obj.ModDepthVariable))(1); % raw alpha
                    if obj.UseDimensionlessAxes && dimensionlessOk
                        alphaFixed = alphaFixed * beta;
                    end
                catch
                    return
                end
                
                if isInverted
                    omega1 = obj.kpClassicalBoundary(alphaFixed, 1);
                    omega2 = obj.kpClassicalBoundary(alphaFixed, 2);
                    yline(ax, omega1, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                    yline(ax, omega2, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                else
                    omega3 = obj.kpClassicalBoundary(alphaFixed, 3);
                    yline(ax, omega3, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                end
            else
                % Y is the fixed Omega "row"; boundary crossings are vertical lines in alpha
                try
                    omegaFixedRaw = becExp.HardwareData.(char(obj.ModFreqVariable))(1); % raw Hz
                catch
                    return
                end
                if ~dimensionlessOk
                    return % Cannot solve boundary without f0
                end
                omegaFixed = omegaFixedRaw / f0;
                
                if isInverted
                    alpha1 = obj.kpClassicalBoundaryInverse(omegaFixed, 1);
                    alpha2 = obj.kpClassicalBoundaryInverse(omegaFixed, 2);
                    xline(ax, alpha1, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                    xline(ax, alpha2, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                else
                    alpha3 = obj.kpClassicalBoundaryInverse(omegaFixed, 3);
                    xline(ax, alpha3, '--w', 'LineWidth', 1.75, 'Tag', 'TheoryLine');
                end
            end
        end

        %% Scan-type helpers
        function tf = isScan2D(obj)
            tf = true; % Preserve old (2D) behavior if check fails
            try
                tf = obj.BecExp.ScannedVariable2 ~= "None";
            catch
            end
        end

        function tf = isFreqScanned(obj)
            tf = false;
            try
                tf = obj.BecExp.ScannedVariableUnit == "Hz";
            catch
            end
        end

        function [beta, f0, ok] = computeDimensionlessScales(obj)
            % Cache result -- constructing OpticalLattice/Laser/Atom is expensive,
            % and beta/f0 are constant for the whole trial (depend only on fixed
            % HardwareData values), so recomputing per-run is wasteful.
            if obj.DimensionlessScaleCache.ok
                beta = obj.DimensionlessScaleCache.beta;
                f0 = obj.DimensionlessScaleCache.f0;
                ok = true;
                return
            end
            
            beta = 1; f0 = 1; ok = false;
            try
                becExp = obj.BecExp;
                beta = becExp.HardwareData.hw_KPModDepthBeta(1);
                V0 = becExp.HardwareData.hw_KPDepthEr(1);
                
                atom = getAtom("Lithium7");
                laser = Laser(wavelength = 1064e-9, power = 1);
                ol = OpticalLattice(atom, laser);
                ol.DepthSpec = V0 * ol.RecoilEnergy;
                f0 = ol.HarmonicFrequency;
                ok = true;
                
                obj.DimensionlessScaleCache = struct('beta', beta, 'f0', f0, 'ok', true);
            catch
                obj.BecExp.displayLog("Failed to compute Dimensionless axes. Check HardwareData variables.", "warning");
            end
        end

        function applyColorLimitsAndColorbar(obj, ax, metricData)
            % Center color limits around exactly 0 for Excess Kurtosis
            if obj.MetricName == "ExcessKurtosis"
                maxAbs = 0.75*max(abs(metricData(:)));
                if isempty(maxAbs) || maxAbs == 0, maxAbs = 0.75; end % Fallback for empty/zero grids
                clim(ax, [-maxAbs, maxAbs]);
            else
                clim(ax, 'auto'); % Auto scale for all other metrics
            end
            
            % Update Colorbar Label
            cb = colorbar(ax);
            if (obj.MetricName == "StdDev2" || obj.MetricName == "ExcessKurtosis") && obj.NoiseFloor > 0
                cb.Label.String = obj.MetricName + " (" + num2str(obj.NoiseFloor * 100) + "\% Cutoff)";
            else
                cb.Label.String = obj.MetricName;
            end
            cb.Label.Interpreter = "latex";
            cb.Label.FontSize = 14;
        end

        function buildTitle(obj, ax)
            % Build Title String (shared between 1D and 2D)
            V0 = NaN;
            try V0 = obj.BecExp.HardwareData.hw_KPDepthEr(1); catch, end
            
            isInverted = obj.InvertOmegaAxis;
            try isInverted = obj.BecExp.HardwareData.hw_KPIsInverted(1); catch, end
            
            invStr = "Non-Inverted";
            if isInverted, invStr = "Inverted"; end
            
            % Determine whether to display t_mod or N_cycles
            timeOrCyclesStr = "t_{\mathrm{mod}} = \mathrm{NaN~ms}";
            try
                timeArray = obj.BecExp.HardwareData.hw_KPModTimeScan;
                modTimeRaw = timeArray(1);
                
                isTimeVarying = length(unique(timeArray)) > 1;
                
                if isTimeVarying
                    nCycles = obj.BecExp.HardwareData.hw_KPModNCycle(1);
                    timeOrCyclesStr = "N_{\mathrm{cycles}} = " + num2str(nCycles);
                else
                    tMod = modTimeRaw * 1000; % Convert to ms
                    timeOrCyclesStr = "t_{\mathrm{mod}} = " + num2str(tMod) + "~\mathrm{ms}";
                end
            catch
                % Fallback if hardware arrays are missing
            end
            
            ax.Title.String = "$(\#" + obj.BecExp.SerialNumber + ")\ V_0 = " + num2str(V0) + ...
                "~E_{\mathrm{R}},\ \mathrm{" + invStr + "},~" + timeOrCyclesStr + "$";
            ax.Title.Interpreter = "latex";
            ax.Title.FontSize = 16;
        end

        %% Calculation Helpers
        function ipr = computeIPR(~, adData)
            % 1. Sum over X to get 1D Y-axis column density
            onedData = squeeze(sum(adData, 2)); 
            nY = size(onedData, 1);
            
            % 2. Dynamically find the peak density position
            [~, peakIdx] = max(onedData);
            
            % 3. Apply a tight window (+/- 25 pixels) to mimic the old script's crop.
            % (51 pixels total width gives a baseline IPR of ~0.02)
            wd = max(1, peakIdx - 25) : min(nY, peakIdx + 25);
            croppedData = onedData(wd);
            
            % 4. Compute IPR strictly on the localized cloud
            % (No background subtraction needed, as empty space is removed)
            mass = sum(croppedData, 1);
            if mass == 0
                ipr = 0;
            else
                croppedData = croppedData ./ mass;
                ipr = squeeze(sum(croppedData.^2, 1));
            end
        end
        
        function ipr = computeIPR2(~, adData)
            onedData = squeeze(sum(adData, 2)); 
            onedData = onedData ./ sum(onedData, 1);
            ipr = squeeze(sum(onedData.^2, 1));
        end

        function frac = computeCentralAtomFraction(~, adData)
            onedData = squeeze(sum(adData, 2));
            nY = size(onedData, 1);
            
            % Dynamically find the peak density position instead of geometric center
            [~, peakIdx] = max(onedData);
            
            % Create window around peak (safely bounded by image edges)
            wd = max(1, peakIdx - 10) : min(nY, peakIdx + 10);
            
            % Compute fraction
            N_central = sum(onedData(wd), 1);
            N_total = sum(onedData, 1);
            
            frac = N_central / N_total; 
            if N_total == 0, frac = 0; end
        end

        function width = computeStDev(~, adData, pxsize)
            onedData = squeeze(sum(adData, 2));
            onedData = onedData ./ sum(onedData, 1);
            pos = pxsize * (1:size(onedData, 1))';
            meanpos = sum(pos .* onedData, 1) ./ sum(onedData, 1);
            var = sum(((pos - meanpos).^2) .* onedData, 1) ./ sum(onedData, 1);
            width = sqrt(squeeze(abs(var)));
        end
        %updated to handle negatives when normalizing
        function width = computeStDevWithBgSub(~, adData, px, noiseFloorPct)
            onedData = squeeze(sum(adData, 2));
            nPos = size(onedData, 1);
            
            edgeIdx = max(1, round(nPos * 0.10));
            edgeMask = false(nPos, 1);
            edgeMask([1:edgeIdx, nPos-edgeIdx+1:nPos]) = true;
            
            bgOffset = sum(onedData .* edgeMask, 1) / sum(edgeMask);
            onedData = onedData - bgOffset;
            
            % This step safely deletes both negative regions AND noise below the cutoff
            peakDensities = max(onedData, [], 1);
            onedData(onedData < noiseFloorPct .* peakDensities) = 0;
            
            mass = sum(onedData, 1);
            
            % Protect against completely blank/noisy images dividing by zero
            if mass == 0
                width = 0;
            else
                pos = px * (1:nPos)';
                meanpos = sum(pos .* onedData, 1) ./ mass;
                variance = sum(((pos - meanpos).^2) .* onedData, 1) ./ mass;
                width = sqrt(squeeze(abs(variance)));
            end
        end
        % new metrics to try: 
        function k = computeKurtosis(~, adData, px, noiseFloorPct)
            onedData = squeeze(sum(adData, 2));
            nPos = size(onedData, 1);
            
            % 1. Smooth slightly to kill single salt-and-pepper hot pixels
            onedData = smoothdata(onedData, 'gaussian', 3);
            
            % 2. Characterize background noise
            edgeIdx = max(1, round(nPos * 0.10));
            edgeMask = false(nPos, 1); 
            edgeMask([1:edgeIdx, nPos-edgeIdx+1:nPos]) = true;
            
            bgMean = sum(onedData .* edgeMask, 1) / sum(edgeMask);
            bgStd = std(onedData(edgeMask));
            
            % Subtract background
            onedData = onedData - bgMean;
            
            % 3. Strict Thresholding (Max of 3-sigma OR User % Cutoff)
            peakDensities = max(onedData, [], 1);
            threshold = max(3 * bgStd, noiseFloorPct .* peakDensities);
            onedData(onedData < threshold) = 0;
            
            mass = sum(onedData, 1);
            if mass == 0
                k = 0; 
                return; 
            end
            
            pos = px * (1:nPos)';
            meanpos = sum(pos .* onedData, 1) ./ mass;
            variance = sum(((pos - meanpos).^2) .* onedData, 1) ./ mass;
            if variance == 0
                k = 0; 
                return; 
            end
            
            % Calculate 4th moment
            moment4 = sum(((pos - meanpos).^4) .* onedData, 1) ./ mass;
            k = (moment4 / (variance^2)) - 3; % Excess kurtosis
        end
        function vis = computeVisibility(~, adData)
            onedData = squeeze(sum(adData, 2));
            
            % Smooth slightly to prevent camera salt/pepper noise from creating false peaks
            onedData = smoothdata(onedData, 'gaussian', 5);
            
            nPos = length(onedData);
            bgOffset = mean(onedData([1:max(1, round(nPos*0.1)), min(nPos, round(nPos*0.9)):nPos]));
            onedData = onedData - bgOffset;
            onedData(onedData < 0) = 0;
            
            % Find peaks with minimum spacing (e.g., 20 pixels) and a threshold
            [pks, locs] = findpeaks(onedData, 'MinPeakProminence', max(onedData)*0.1, 'MinPeakDistance', 20);
            
            if length(pks) < 2
                vis = 0; % No side fringes detected, it's just a blob
            else
                % Sort by peak height
                [~, sortIdx] = sort(pks, 'descend');
                loc1 = locs(sortIdx(1));
                loc2 = locs(sortIdx(2));
                
                % Limit search to the lowest valley specifically between the two highest peaks
                idxMin = min(loc1, loc2);
                idxMax = max(loc1, loc2);
                
                valley = min(onedData(idxMin:idxMax));
                I_max = (onedData(loc1) + onedData(loc2)) / 2;
                I_min = valley;
                
                vis = (I_max - I_min) / (I_max + I_min);
            end
        end

        function fPower = computeFFTPower(~, adData)
            onedData = squeeze(sum(adData, 2));
            nPos = size(onedData, 1);
            
            bgOffset = mean(onedData([1:max(1, round(nPos*0.1)), min(nPos, round(nPos*0.9)):nPos]));
            onedData = onedData - bgOffset;
            onedData(onedData < 0) = 0;
            
            mass = sum(onedData);
            if mass == 0, fPower = 0; return; end
            
            % Normalize so mass fluctuations don't skew the FFT amplitude
            onedData = onedData / mass;
            
            % Compute Power Spectrum
            fftData = fft(onedData);
            powerSpec = abs(fftData).^2;
            
            % Discard DC component offset and the very low frequencies (the broad Gaussian envelope)
            % Bins 1-5 represent the 'macro' cloud shape. Real diffraction orders will be higher frequency.
            powerSpec(1:5) = 0; 
            
            % Focus on the single-sided band up to Nyquist limit
            halfSpec = powerSpec(1:floor(nPos/2));
            fPower = max(halfSpec);
        end

        function Omega = kpClassicalBoundary(~, alpha, idx)
            switch idx
                case 1
                    Omega = alpha / sqrt(2);
                case 2
                    Omega = 0.126491 * sqrt(-250. + 139. * alpha);
                case 3
                    Omega = 0.126491 * sqrt(250. + 139. * alpha);
                otherwise
                    Omega = zeros(size(alpha));
            end
        end

        function alpha = kpClassicalBoundaryInverse(~, Omega, idx)
            % Inverse of kpClassicalBoundary, used for 1D scans where Omega is fixed
            % and we need to solve for the alpha crossing point(s).
            switch idx
                case 1
                    alpha = Omega * sqrt(2);
                case 2
                    alpha = ((Omega / 0.126491).^2 + 250) / 139;
                case 3
                    alpha = ((Omega / 0.126491).^2 - 250) / 139;
                otherwise
                    alpha = NaN(size(Omega));
            end
        end

        function refresh(obj)
            obj.initialize;
            for runIdx = 1:obj.BecExp.NCompletedRun
                obj.updateData(runIdx);
            end
            obj.updateFigure(obj.BecExp.NCompletedRun);
        end
    end
end

function s = localLatexEscape(s)
    % Escape characters LaTeX treats specially so raw variable/unit names
    % (e.g. "hw_KPModFreq") render literally instead of triggering math-mode
    % syntax such as subscripting on "_".
    s = string(s);
    if strlength(s) == 0
        return
    end
    s = strrep(s,"\","\textbackslash ");
    s = strrep(s,"_","\_");
    s = strrep(s,"%","\%");
    s = strrep(s,"&","\&");
    s = strrep(s,"#","\#");
    s = strrep(s,"$","\$");
end