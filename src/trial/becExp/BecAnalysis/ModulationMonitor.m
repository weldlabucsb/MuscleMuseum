classdef ModulationMonitor < BecAnalysis
    %:class:`ModulationMonitor` real-time scope diagnostics for AC modulation.
    %
    % ------------------------------------------------------------------
    % WHERE THE ANALYSIS LIVES
    % ------------------------------------------------------------------
    % Everything that touches the data is in the "Analysis" methods block:
    %
    %   loadTrace         read a run's scope trace (RAM if live, else disk)
    %   correctTimebase   undo the scope's s/div coercion, fix Fs
    %   detectModulation  find the modulation window (two-pass envelope)
    %   fitChannel        measure f, amplitude, phase, DC, distortion
    %   refineFrequency   IEEE-1057 four-parameter sine fit
    %
    % Every other method only draws. If a number looks wrong, the bug is in
    % one of the five functions above.
    %
    % ------------------------------------------------------------------
    % MEASUREMENT CHAIN, AND WHY
    % ------------------------------------------------------------------
    % 1. TIMEBASE. MuscleMuseum lets the user request an arbitrary capture
    %    duration, but the scope only offers a 1-2-5 sequence of s/div. The
    %    saved TimeList therefore reports a duration the hardware never used,
    %    and Fs is wrong by up to 25%. Since every measured frequency scales
    %    with Fs, this is corrected first and both durations are recorded so
    %    a correction is always auditable.
    %
    % 2. MASK. One window per run, shared by all channels: the beams are
    %    gated together, so a per-channel mask would invent a phase offset
    %    that does not physically exist. Detection is two-pass because a
    %    single moving mean wide enough to be robust also smears the edge by
    %    a couple of periods. Pass 1 (wide) locates the region; pass 2
    %    (quarter period) sharpens the edges inside that region.
    %
    % 3. FREQUENCY. Measured from the spectrum, NOT seeded from the command.
    %    Seeding from the command means the monitor can only ever confirm
    %    what was asked for; a real mismatch would show up as zero amplitude
    %    instead of a frequency error. The search is floored at 3 cycles per
    %    mask so the envelope's own low-frequency lobe can never win.
    %
    % 4. AMPLITUDE / PHASE / DC. Three-parameter linear fit at the measured
    %    frequency, then a four-parameter refinement. Both channels are fit
    %    against a common time origin so the relative phase is exact.
    %
    % ------------------------------------------------------------------
    % TABS
    %   Transfer   metric vs scan variable, one curve per value of the other
    %   Scan map   the same metrics as heatmaps over the 2D scan grid
    %   Timeline   per-run view, for drift and outliers
    %   Basic      plain readout of one run, one column per channel
    %   Inspector  raw trace, mask, fit and spectrum for one run
    % Clicking a point or cell in the first three opens that run in the
    % Inspector.

    properties
        ExpectedFrequencyVar string = "hw_KPModFreq" % Hardware variable holding the commanded mod frequency
        DepthVar string = "" % Hardware variable for mod depth. "" = auto-detect from the scan variables
        IsChirp logical = false % Modulation is a linear frequency sweep, not a fixed tone (AM spectroscopy)
        ChirpEndFreqVar string = "" % Hardware variable for the chirp END frequency; ExpectedFrequencyVar is then the START
        DepthTargetVar string = "hw_KPDepthEr" % Hardware variable holding the target combined depth V0
        AlphaVar string = "hw_KPModDepthAlpha" % Hardware variable holding the drive parameter alpha
        CalculatePhase logical = true % Compute the relative phase of the first two channels
        PhaseTarget double = 180 % Expected relative phase in degrees
        ScopeName string = "LatticeScope" % Name of the scope hardware for offline loading
        MaxChannel double = 4 % Highest scope channel to look for
        ShowDistortion logical = true % Include the harmonic-distortion metric
        ShowDriveMetrics logical = false % Offer alpha*beta and AC balance in the metric menus
        IsKapitzaAxes logical = true % Scan map in phase-diagram orientation: alpha on x, frequency on y with the lowest at the top

        % --- timebase -------------------------------------------------
        TimebaseSnap string = "up" % "up" (round up to the next valid s/div) | "off" (no correction)
        TimebaseWarnFraction double = 0.02 % Flag a correction larger than this fraction of the duration
        DepthSnapTolerance double = 5e-4 % Snap the sample count to a 1-2-5 memory depth within this relative tolerance

        % --- modulation-window detection ------------------------------
        MaskCoarseCycles double = 4 % Pass 1 envelope smoothing width, in commanded periods
        MaskEdgeGuardCycles double = 4 % Pass 2 slew search half-width around each coarse edge, in periods
        MaskFraction double = 0.5 % Half-maximum crossing used by the coarse pass
        MaskEdgeFraction double = 0.5 % Slew threshold, as a fraction of the local peak slew
        MaskTrimCycles double = 0.25 % Periods trimmed inward from each edge after detection

        % --- manual mask nudge (Inspector top bar) --------------------
        % Per-run, so a nudge applied to one run never silently follows you to
        % the next. Row 1 = start offset, row 2 = end offset, both in
        % microseconds (+ = later). Zero means no nudge, which is why there is
        % no separate on/off toggle to get out of step with the values.
        MaskNudge double = zeros(2,0)

        % --- frequency estimation -------------------------------------
        MinCyclesInMask double = 3 % Lower bound of the spectral search, in cycles per mask
        SubharmonicRatio double = 0.10 % Peak fraction above which a sub-harmonic is taken as the true fundamental
        FreqTolerance double = 0.25 % Reject a four-parameter refinement straying further than this
        LockTolerance double = 0.02 % |f_meas/f_set - 1| below this counts as locked
        ZeroPadFactor double = 10 % Zero-padding multiple for the spectrum
        ChirpSmoothCycles double = 20 % Smoothing width for the displayed instantaneous frequency, in periods
        NHarmonics double = 5 % Harmonics included in the distortion figure and spectrum span
        MaxFitIter double = 12 % Gauss-Newton iterations for the frequency refinement

        % --- unit conversion (volts -> physical units) -----------------
        % Applied at DISPLAY time only; everything is stored in volts, so
        % toggling this needs no re-analysis and a wrong calibration is one
        % click from being undone.
        %   level      quantity:  x_out = Multiplier * (V + Offset)
        %   difference quantity:  x_out = Multiplier *  V
        % The offset must NOT be applied to differences (Vpp, Vrms, dVdc):
        % it cancels in a subtraction.
        IsConvertVolts logical = false % Master switch for the conversion below
        VoltMultiplier double = [1 1 1 1] % Physical units per volt, one per channel
        VoltOffset double = [0 0 0 0] % Volts added before scaling, one per channel
        VoltUnit string = "Er" % Label for the converted unit

        CacheTraces logical = false % Keep raw traces in RAM (off: reload from disk on demand)
        DefaultTab string = "Transfer" % Tab shown on startup
        FollowLatestOnBasic logical = true % While Basic is visible, show the newest completed run
    end

    properties (SetAccess = protected)
        % Per-channel metrics, sized nChannel x nRun
        Vpp double      % AC peak-to-peak (V)
        Vrms double     % AC rms (V), mean removed
        Dc double       % Mean voltage over the modulation window (V)
        Freq double     % Measured modulation frequency (Hz). In chirp mode this is the START frequency
        FreqEnd double  % Measured chirp END frequency (Hz), chirp mode only
        ChirpRate double% Measured sweep rate (Hz/s), chirp mode only
        Thd double      % Total harmonic distortion, harmonics 2..N vs fundamental (dBc)
        DcStep double   % Mean level during modulation minus the static level just before it (V)
        DcPre double    % Static (pre-modulation) level (V)
        DcDark double   % Dark level with the beam off (V)
        % Per-run metrics, sized 1 x nRun
        PhaseErr double
        FreqExpected double
        FreqExpectedEnd double % Commanded chirp end frequency (Hz)
        DepthSet double
        V0Expected double   % Commanded combined depth V0 (Er), from DepthTargetVar
        AlphaSet double     % Commanded alpha, from AlphaVar
        ModTime double      % Measured modulation duration (s)
        SampleRate double   % Corrected sample rate (Hz)
        MaskClipped logical % True when modulation runs past either record edge
        ClipStart logical   % True when the turn-on edge was not captured
        ClipEnd logical     % True when the turn-off edge was not captured
        RawDuration double  % Capture duration as stored in the file (s)
        TrueDuration double % Capture duration after 1-2-5 snapping (s)
        NChannel double = 0
    end

    properties (Hidden, Transient)
        H struct = struct()
        Grid struct = struct('Valid',false)
        InspectorRun double = 1
        TraceCache cell = {}
        DirtyTabs logical
        TransferXAxis double = 1 % 1 = vs frequency, 2 = vs depth setting
        InspectorBottom double = 1 % Bottom Inspector panel: 1 = spectrum, 2 = combined lattice
        % Custom tab: one entry per panel (1..6)
        CustomMetric double = [1 1 2 2 4 7]   % metric ids, see metricRegistry
        CustomChannel double = [1 2 1 2 1 1]  % channel for the per-channel metrics
        CustomStyle double = [1 1 1 1 1 1]    % 1 = scan map, 2 = curve family, 3 = vs run
        CustomXAxis double = 1 % Curve-style x axis: 1 = frequency, 2 = depth
        FreqPanelChannel double = 1 % Which channel the selectable panel shows
        FreqPanelMetric double = 4 % Selectable top-right panel: a metric id, see metricRegistry
        ShowErrorBars logical = false % Draw repeat scatter as error bars
    end

    properties (Constant, Hidden)
        % Channel line colours. Ch1 blue / Ch2 orange is the convention used
        % everywhere; the gradient colormaps below are keyed to match.
        ChColor = [0.000 0.447 0.741;   % Ch 1  blue
                   0.851 0.325 0.098;   % Ch 2  orange
                   0.180 0.545 0.341;   % Ch 3  green
                   0.494 0.318 0.635]   % Ch 4  purple
        CMask   = [0.839 0.153 0.157]
        CInk    = [0.130 0.140 0.160]
        CMuted  = [0.480 0.500 0.530]
        CGrid   = [0.886 0.894 0.906]
        CPanelBg = [0.976 0.980 0.988]
        TabNames = ["Transfer","Scan map","Timeline","Custom","Basic","Inspector"]
    end

    methods
        function obj = ModulationMonitor(becExp)
            obj@BecAnalysis(becExp)
            % ---------------------------------------------------------
            % WINDOW SIZE / POSITION: change the two lines below.
            %   loc  = [left, bottom] as fractions of the screen
            %   size = [width, height] as fractions of the screen
            % Nothing else in this class touches the window geometry.
            % ---------------------------------------------------------
            obj.Chart(1) = Chart(...
                name = "Modulation Monitor",...
                num = 46, ...
                fpath = fullfile(becExp.DataAnalysisPath, "ModulationMonitor"),...
                loc = [0.02, 0.05],...
                size = [0.68, 0.62]...
            );
        end

        %% ===============================================================
        %  Lifecycle
        %  ===============================================================
        function initialize(obj)
            fig = obj.Chart(1).initialize;
            if ~isgraphics(fig)
                return
            end

            obj.Vpp = []; obj.Vrms = []; obj.Dc = []; obj.Freq = []; obj.Thd = [];
            obj.FreqEnd = []; obj.ChirpRate = []; obj.FreqExpectedEnd = [];
            obj.DcStep = []; obj.DcPre = []; obj.DcDark = [];
            obj.PhaseErr = []; obj.FreqExpected = []; obj.DepthSet = [];
            obj.V0Expected = []; obj.AlphaSet = [];
            obj.ModTime = []; obj.SampleRate = [];
            obj.RawDuration = []; obj.TrueDuration = [];
            obj.MaskClipped = false(1,0);
            obj.ClipStart = false(1,0); obj.ClipEnd = false(1,0);
            obj.NChannel = 0;
            obj.TraceCache = {};
            obj.Grid = ModulationMonitor.emptyGrid();
            obj.InspectorRun = 1;
            obj.DirtyTabs = true(1, numel(obj.TabNames));

            clf(fig);
            set(fig,'Color','w');

            obj.H = struct();
            obj.H.Figure = fig;
            obj.H.LastRun = 0;
            obj.H.TabGroup = uitabgroup(fig,'Units','normalized','Position',[0 0 1 1]);
            for ii = 1:numel(obj.TabNames)
                obj.H.Tab(ii) = uitab(obj.H.TabGroup,'Title',char(obj.TabNames(ii)),...
                    'BackgroundColor','w');
            end
            obj.H.TabGroup.SelectionChangedFcn = @(~,~) obj.drawSelectedTab();

            obj.buildBasicTab();
            obj.buildInspectorTab();

            k = find(obj.TabNames == obj.DefaultTab, 1);
            if isempty(k), k = 1; end
            obj.H.TabGroup.SelectedTab = obj.H.Tab(k);
        end

        function refresh(obj)
            obj.initialize;
            n = obj.BecExp.NCompletedRun;
            for runIdx = 1:max(n,0)
                obj.updateData(runIdx);
            end
            obj.updateFigure(n);
        end

        %% ===============================================================
        %  Data
        %  ===============================================================
        function updateData(obj, runIdx)
            if runIdx < 1
                return
            end
            obj.resetRun(runIdx);

            obj.FreqExpected(runIdx) = obj.readVar(obj.ExpectedFrequencyVar, runIdx);
            obj.DepthSet(runIdx)     = obj.readVar(obj.depthVarName(), runIdx);
            obj.V0Expected(runIdx)   = obj.readVar(obj.DepthTargetVar, runIdx);
            obj.FreqExpectedEnd(runIdx) = obj.readVar(obj.ChirpEndFreqVar, runIdx);
            obj.AlphaSet(runIdx)     = obj.readVar(obj.AlphaVar, runIdx);

            res = obj.analyzeRun(runIdx);
            if ~res.Ok
                return
            end

            nCh = numel(res.Ch);
            obj.growChannels(nCh, runIdx);
            for k = 1:nCh
                obj.Vpp(k,runIdx)  = 2*res.Ch(k).A;   % fit returns peak amplitude
                obj.Vrms(k,runIdx) = res.Ch(k).Rms;
                obj.Dc(k,runIdx)   = res.Ch(k).Dc;
                obj.Freq(k,runIdx) = res.Ch(k).F;
                obj.Thd(k,runIdx)  = res.Ch(k).Thd;
                obj.DcStep(k,runIdx) = res.Ch(k).DcStep;
                obj.DcPre(k,runIdx)  = res.Ch(k).DcPre;
                obj.DcDark(k,runIdx) = res.Ch(k).DcDark;
                obj.FreqEnd(k,runIdx)   = res.Ch(k).FEnd;
                obj.ChirpRate(k,runIdx) = res.Ch(k).ChirpRate;
            end
            obj.ModTime(runIdx)     = res.ModTime;
            obj.SampleRate(runIdx)  = res.Fs;
            obj.RawDuration(runIdx) = res.RawDuration;
            obj.TrueDuration(runIdx)= res.TrueDuration;
            obj.MaskClipped(runIdx) = res.MaskClipped;
            obj.ClipStart(runIdx)   = res.ClipStart;
            obj.ClipEnd(runIdx)     = res.ClipEnd;

            % Relative phase of the first two channels. Both were fit against
            % the same time origin, so the difference is directly meaningful.
            if obj.CalculatePhase && nCh >= 2 && ...
                    isfinite(res.Ch(1).Phi) && isfinite(res.Ch(2).Phi)
                measured = rad2deg(res.Ch(1).Phi - res.Ch(2).Phi);
                obj.PhaseErr(runIdx) = ModulationMonitor.wrap180(measured - obj.PhaseTarget);
            end

            obj.DirtyTabs(:) = true;
        end

        %% ===============================================================
        %  Figure
        %  ===============================================================
        function updateFigure(obj, runIdx)
            if ~isfield(obj.H,'Figure') || ~isgraphics(obj.H.Figure) || obj.NChannel == 0
                return
            end
            obj.buildGrid(runIdx);
            obj.H.LastRun = runIdx;
            if obj.InspectorRun > runIdx || obj.InspectorRun < 1
                obj.InspectorRun = max(runIdx,1);
            end
            % The Basic tab is a per-shot monitor: while it is the visible
            % tab it follows the newest completed run, so a live experiment
            % shows the numbers for the shot that just finished. Other tabs
            % leave the run selection alone, so stepping through runs in the
            % Inspector is never yanked forward underneath you.
            if obj.FollowLatestOnBasic && obj.isTabVisible(obj.tabIndex("Basic"))
                obj.InspectorRun = max(runIdx,1);
            end
            obj.drawSelectedTab();
        end

        function idx = tabIndex(obj, name)
            % Index of a tab by name, so the switch in drawSelectedTab and
            % these lookups cannot drift apart when tabs are reordered.
            idx = find(obj.TabNames == name, 1);
            if isempty(idx), idx = 0; end
        end

        function tf = isTabVisible(obj, idx)
            % True when tab 'idx' is the one currently on screen.
            tf = false;
            if ~isfield(obj.H,'TabGroup') || ~isgraphics(obj.H.TabGroup)
                return
            end
            if idx < 1 || idx > numel(obj.H.Tab)
                return
            end
            tf = isgraphics(obj.H.Tab(idx)) && ...
                obj.H.TabGroup.SelectedTab == obj.H.Tab(idx);
        end

        function drawSelectedTab(obj)
            % Always redraw the tab being shown.
            %
            % This used to skip the redraw when a dirty flag was clear, which
            % saved a little time but meant any bookkeeping slip in those
            % flags left a tab permanently blank - a silent failure with no
            % error to chase. Redrawing on every selection is a fraction of a
            % second and cannot fail that way. The flags are still maintained
            % so a future change can reinstate the optimisation safely.
            if ~isfield(obj.H,'TabGroup') || ~isgraphics(obj.H.TabGroup)
                return
            end
            idx = find(obj.H.Tab == obj.H.TabGroup.SelectedTab, 1);
            if isempty(idx)
                return
            end
            runIdx = obj.lastRun();
            try
                switch idx
                    case 1, obj.drawTransferTab(runIdx);
                    case 2, obj.drawMapTab(runIdx);
                    case 3, obj.drawTimelineTab(runIdx);
                    case 4, obj.drawCustomTab(runIdx);
                    case 5, obj.drawBasicTab();
                    case 6, obj.drawInspector();
                end
                obj.DirtyTabs(idx) = false;
            catch ME
                % Show the failure in the tab rather than leaving it empty.
                obj.showTabError(obj.H.Tab(idx), ME);
            end
            drawnow limitrate
        end

        function showTabError(obj, tab, ME)
            delete(allchild(tab));
            msg = sprintf('This tab failed to draw.\n\n%s\n', ME.message);
            for k = 1:min(numel(ME.stack),4)
                msg = sprintf('%s\n  %s  (line %d)', msg, ...
                    ME.stack(k).name, ME.stack(k).line);
            end
            uicontrol(tab,'Style','text','Units','normalized',...
                'Position',[0.05 0.30 0.90 0.40],'String',msg,...
                'BackgroundColor','w','ForegroundColor',obj.CMask,...
                'HorizontalAlignment','left','FontSize',10);
        end
    end

    %% ===================================================================
    %  Panel definitions shared by the Transfer and Scan map tabs
    %  ===================================================================
    methods (Access = protected)
        function ids = visibleMetricIds(obj)
            % Metric ids offered in the dropdowns, in display order.
            % Hidden ones still work if set programmatically; they are only
            % kept out of the menus.
            ids = [1 2 3 4 5 6 7 8 9 12 13 14];
            if obj.ShowDriveMetrics
                ids = [1 2 3 4 5 6 7 8 9 10 11 12 13 14];
            end
        end

        function tf = metricNeedsConvert(~, id)
            % Combined-lattice metrics subtract or ratio the two channels, so
            % they are only meaningful once each channel is in physical units
            % (the two have different Er/V).
            tf = ismember(id, [8 9 10 11]);
        end

        function [names, needsCh] = metricRegistry(~)
            % Single source of truth for every plottable quantity. panelSet
            % (fixed layouts) and the Custom tab both build panels from this,
            % so a metric is defined once. needsCh marks the per-channel ones.
            names = {'AC pk-pk', 'Mean level', 'AC Vrms', 'Freq error', ...
                     'THD', [char(916) 'Vdc at mod start'], 'Phase error', ...
                     'V0 combined', 'Vi static', 'alpha*beta', 'AC balance', ...
                     'Chirp end error', 'Chirp span', 'Measured mod time'};
            needsCh = [true true true true true true false false false false ...
                       false true true false];
        end

        function p = buildMetricPanel(obj, id, ch, runs)
            % One panel definition for metric 'id' on channel 'ch'.
            u = obj.unitStr();
            needConv = obj.metricNeedsConvert(id) && ~obj.IsConvertVolts;
            ch = min(max(round(ch),1), max(obj.NChannel,1));
            switch id
                case 1
                    p = struct('data', obj.convert(obj.row(obj.Vpp,ch,runs), ch, 'delta'), ...
                        'name', sprintf('AC pk-pk, Ch %d', ch), 'unit', obj.unitLong('pp'), ...
                        'short','AC pk-pk', 'ushort',u, 'mode','seq','cmap',ch,'ref',NaN);
                case 2
                    p = struct('data', obj.convert(obj.row(obj.Dc,ch,runs), ch, 'level'), ...
                        'name', sprintf('Mean level, Ch %d', ch), 'unit', obj.unitLong('level'), ...
                        'short','Mean level', 'ushort',u, 'mode','seq','cmap',ch,'ref',NaN);
                case 3
                    p = struct('data', obj.convert(obj.row(obj.Vrms,ch,runs), ch, 'delta'), ...
                        'name', sprintf('AC Vrms, Ch %d', ch), 'unit', obj.unitLong('level'), ...
                        'short','AC Vrms', 'ushort',u, 'mode','seq','cmap',ch,'ref',NaN);
                case 5
                    p = struct('data', obj.row(obj.Thd,ch,runs), ...
                        'name', sprintf('THD, Ch %d', ch), 'unit','dBc', ...
                        'short','THD', 'ushort','dBc', 'mode','seq','cmap',ch,'ref',NaN);
                case 6
                    p = struct('data', obj.convert(obj.row(obj.DcStep,ch,runs), ch, 'delta'), ...
                        'name', sprintf('%sV_dc at mod start, Ch %d', char(916), ch), ...
                        'unit', obj.unitLong('step'), ...
                        'short', sprintf('%sV_dc', char(916)), 'ushort',u, ...
                        'mode','div','cmap',ch,'ref',0);
                case 7
                    p = struct('data', obj.padTo(obj.PhaseErr,runs), ...
                        'name','Relative phase error', 'unit','Degrees from target', ...
                        'short','Phase error', 'ushort','deg', 'mode','cyc','cmap',1,'ref',0);
                case 8
                    tgt = median(obj.padTo(obj.V0Expected,runs), 'omitnan');
                    if isfinite(tgt), md = 'divref'; else, md = 'seq'; tgt = NaN; end
                    p = struct('data', obj.combinedV0(runs), ...
                        'name','V_0 combined depth (Ch2 - Ch1)', 'unit', u, ...
                        'short','V_0', 'ushort',u, 'mode',md,'cmap',1,'ref',tgt);
                case 9
                    p = struct('data', obj.combinedVi(runs), ...
                        'name','V_i static combined depth (sign = inversion)', 'unit', u, ...
                        'short','V_i', 'ushort',u, 'mode','div','cmap',1,'ref',0);
                case 10
                    p = struct('data', obj.combinedAlphaBeta(runs), ...
                        'name','Delivered drive strength  (A_1+A_2)/V_0', ...
                        'unit','alpha*beta', 'short','alpha*beta', 'ushort','', ...
                        'mode','seq','cmap',1,'ref',NaN);
                case 11
                    p = struct('data', obj.combinedBalance(runs), ...
                        'name','AC balance (A_2-A_1)/mean, theory = 0', ...
                        'unit','percent', 'short','AC balance', 'ushort','%', ...
                        'mode','div','cmap',1,'ref',0);
                case 12
                    p = struct('data', obj.row(obj.FreqEnd,ch,runs) - obj.padTo(obj.FreqExpectedEnd,runs), ...
                        'name', sprintf('Chirp END: measured minus commanded, Ch %d', ch), ...
                        'unit','Hertz', 'short','Chirp end error', 'ushort','Hz', ...
                        'mode','div','cmap',ch,'ref',0);
                case 13
                    p = struct('data', obj.row(obj.FreqEnd,ch,runs) - obj.row(obj.Freq,ch,runs), ...
                        'name', sprintf('Chirp span (f_end - f_start), Ch %d', ch), ...
                        'unit','Hertz', 'short','Chirp span', 'ushort','Hz', ...
                        'mode','seq','cmap',ch,'ref',NaN);
                case 14
                    p = struct('data', obj.padTo(obj.ModTime,runs)*1e3, ...
                        'name','Measured modulation time', 'unit','ms', ...
                        'short','Mod time', 'ushort','ms', 'mode','seq','cmap',1,'ref',NaN);
                otherwise   % 4 = frequency error
                    nm = 'Measured minus commanded frequency';
                    if obj.IsChirp, nm = 'Chirp START: measured minus commanded'; end
                    p = struct('data', obj.row(obj.Freq,ch,runs) - obj.padTo(obj.FreqExpected,runs), ...
                        'name', sprintf('%s, Ch %d', nm, ch), 'unit','Hertz', ...
                        'short','Freq error', 'ushort','Hz', 'mode','div','cmap',ch,'ref',0);
            end
            p.NeedsConvert = needConv;
        end

        function p = panelSet(obj, runs)
            % Six panels laid out column-wise:
            %   col 1  AC pk-pk     Ch1 / Ch2
            %   col 2  Mean level   Ch1 / Ch2
            %   col 3  selectable metric / phase error
            % Voltage quantities are converted here (display time only), with
            % 'delta' vs 'level' chosen per quantity: an offset must not be
            % applied to a difference.
            nCh = min(max(obj.NChannel,1), 2);
            p = {};
            for k = 1:nCh
                p{end+1} = struct('data', obj.convert(obj.row(obj.Vpp,k,runs), k, 'delta'), ...
                    'name', sprintf('AC pk-pk, Ch %d', k), 'unit', obj.unitLong('pp'), ...
                    'short','AC pk-pk', 'ushort', obj.unitStr(), ...
                    'mode','seq','cmap',k,'ref',NaN); %#ok<AGROW>
            end
            for k = 1:nCh
                p{end+1} = struct('data', obj.convert(obj.row(obj.Dc,k,runs), k, 'level'), ...
                    'name', sprintf('Mean level, Ch %d', k), 'unit', obj.unitLong('level'), ...
                    'short','Mean level', 'ushort', obj.unitStr(), ...
                    'mode','seq','cmap',k,'ref',NaN); %#ok<AGROW>
            end

            % Third column, top: user-selectable via the tab's top bar, since
            % only one channel/metric fits (a heatmap cannot overlay two).
            % metricList() order maps onto registry ids here.
            kf = min(max(round(obj.FreqPanelChannel),1), max(obj.NChannel,1));
            p{end+1} = obj.buildMetricPanel(obj.FreqPanelMetric, kf, runs);

            if obj.CalculatePhase && obj.NChannel >= 2
                p{end+1} = struct('data', obj.padTo(obj.PhaseErr,runs), ...
                    'name','Relative phase error', 'unit','Degrees from target', ...
                    'short','Phase error', 'ushort','deg', ...
                    'mode','cyc','cmap',1,'ref',0);
            elseif obj.ShowDistortion
                p{end+1} = struct('data', obj.row(obj.Thd,1,runs), ...
                    'name','THD, Ch 1', 'unit','dBc', ...
                    'short','THD', 'ushort','dBc', ...
                    'mode','seq','cmap',1,'ref',NaN);
            end
        end

        function order = panelTileOrder(~)
            % nexttile fills row-major (1 2 3 / 4 5 6); this remaps the
            % panelSet order onto column-major tiles.
            order = [1 4 2 5 3 6];
        end
    end

    %% ===================================================================
    %  Transfer tab
    %  ===================================================================
    methods (Access = protected)
        function drawTransferTab(obj, runIdx)
            tab = obj.H.Tab(1);
            delete(allchild(tab));
            runs = 1:max(runIdx,1);

            % Two rows, so the hint text is never squeezed out by the
            % selectors. Row 1: x axis + hint. Row 2: panel selectors.
            ctl = uipanel(tab,'Units','normalized','Position',[0 0.915 1 0.085],...
                'BorderType','none','BackgroundColor','w');
            rowTop = 0.52; rowBot = 0.06; rowH = 0.40;

            uicontrol(ctl,'Style','text','Units','normalized',...
                'Position',[0.006 rowTop 0.04 rowH],...
                'String','Plot vs','BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',9);
            obj.H.TransferPopup = uicontrol(ctl,'Style','popupmenu','Units','normalized',...
                'Position',[0.05 rowTop 0.17 rowH],'FontSize',9,...
                'String',{obj.varLabel(obj.ExpectedFrequencyVar), obj.varLabel(obj.depthVarName())},...
                'Value',obj.TransferXAxis,...
                'Callback',@(s,~) obj.onTransferAxis(s));
            uicontrol(ctl,'Style','text','Units','normalized',...
                'Position',[0.235 rowTop 0.755 rowH],...
                'String','Line shade runs dark (low) to light (high) on the other scan variable. Hover for values, click to open a run in the Inspector.',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','left','FontSize',8.5);

            xE = obj.addPanelControls(ctl, 0.006, rowBot, rowH);
            obj.addErrorBarToggle(ctl, xE, rowBot, rowH);

            tl = tiledlayout(tab, 2, 3, 'TileSpacing','loose','Padding','compact');
            tl.Units = 'normalized';
            tl.OuterPosition = [0 0 1 0.915];
            title(tl, sprintf('%sModulation response  |  %d run(s) analysed', obj.trialTag(), runIdx), ...
                'FontWeight','bold','Color',obj.CInk);

            p = obj.panelSet(runs);
            order = obj.panelTileOrder();
            for ii = 1:min(numel(p),6)
                ax = nexttile(tl, order(ii));
                obj.drawCurvePanel(ax, p{ii}, runs);
            end
        end

        function drawCurvePanel(obj, ax, p, runs, xAxisSel)
            obj.styleAxes(ax);
            if isfield(p,'NeedsConvert') && p.NeedsConvert
                obj.panelTitle(ax, p.name);
                obj.placeholder(ax, sprintf(['Needs "Convert volts?"\n\n' ...
                    'This metric combines Ch1 and Ch2, which have different\n' ...
                    'Er/V calibrations, so their raw voltage difference is\n' ...
                    'not meaningful.']));
                return
            end
            title(ax, p.name, 'FontWeight','bold','Color',obj.CInk,'FontSize',10,...
                'Interpreter','none');
            g = obj.Grid;
            if ~g.Valid
                obj.placeholder(ax,'Waiting for scan variables');
                return
            end
            hold(ax,'on');

            if nargin < 5, xAxisSel = obj.TransferXAxis; end
            [~, xName, famVals, famName, nFam] = obj.familyLayout(xAxisSel);
            alongX = (xAxisSel == 1) || ~g.Is2D;
            cmap = obj.familyMap(p);

            for k = 1:nFam
                [xs, ys, rIdx, nRep, repStd, rList] = obj.seriesAlong(p.data, k, alongX);
                if ~any(isfinite(ys))
                    continue
                end
                col = cmap(ModulationMonitor.colIndex(k,nFam),:);
                if obj.ShowErrorBars && any(isfinite(repStd))
                    % Bars are the shot-to-shot scatter of the repeats that
                    % were averaged into each point. Points without repeats
                    % carry NaN and simply draw no bar.
                    h = errorbar(ax, xs, ys, repStd, '-o', 'Color', col, ...
                        'MarkerFaceColor', col, 'MarkerSize', 4.5, 'LineWidth', 1.2, ...
                        'CapSize', 4, 'ButtonDownFcn', @(s,e) obj.onPick(s,e));
                else
                    h = plot(ax, xs, ys, '-o', 'Color', col, 'MarkerFaceColor', col, ...
                        'MarkerSize', 4.5, 'LineWidth', 1.2, ...
                        'ButtonDownFcn', @(s,e) obj.onPick(s,e));
                end
                h.UserData = rIdx;   % run index behind each x position, for click-through
                try
                    st = obj.lineStats(ys);
                    sig = char(963);
                    % One prefix for the whole tooltip, chosen from sigma.
                    ref = st.Std;
                    if ~(ref > 0), ref = abs(st.Mean); end
                    [sc, uStr] = obj.tipScale(p.ushort, ref);
                    rows = [ ...
                        dataTipTextRow('Run', rIdx); ...
                        dataTipTextRow(obj.varLabel(xName), xs); ...
                        dataTipTextRow(obj.varLabel(famName), repmat(famVals(k),size(xs))); ...
                        dataTipTextRow(sprintf('%s (%s)', p.short, uStr), ys*sc, '%.4g'); ...
                        dataTipTextRow(sprintf('Line mean (%s)', uStr), repmat(st.Mean*sc,size(xs)), '%.4g'); ...
                        dataTipTextRow(sprintf('Line %s (%s)', sig, uStr), repmat(st.Std*sc,size(xs)), '%.4g'); ...
                        dataTipTextRow(sprintf('Pt offset from mean (%s)', sig), st.Z, '%+.2f')];
                    % Repeat rows only when the scan actually has repeats.
                    if any(nRep > 1)
                        % List the run numbers, not just the count: clicking
                        % only opens the first one, so the others are
                        % otherwise impossible to find in the Inspector.
                        % cellstr, not a string array: data tips render a
                        % string array as a blank value on some releases.
                        rows = [rows; ...
                            dataTipTextRow('Runs at this pt', cellstr(rList)); ...
                            dataTipTextRow(sprintf('Repeat %s (%s)', sig, uStr), repStd*sc, '%.4g')]; %#ok<AGROW>
                    end
                    h.DataTipTemplate.DataTipRows = rows;
                catch
                end
            end
            if isfinite(p.ref)
                yline(ax, p.ref, '--', 'Color', obj.CMuted, 'HandleVisibility','off');
            end
            if strcmp(p.mode,'cyc')
                % Symmetric about zero so a wrap is visible, but scaled to the
                % data so small errors are still readable.
                lim = obj.phaseLimit(p.data);
                ylim(ax,[-lim lim]);
            end
            xlabel(ax, obj.varLabel(xName), 'Interpreter','none');
            ylabel(ax, p.unit);
            ax.UserData = struct('Kind','curve');
            hold(ax,'off');
        end

        function cm = familyMap(obj, p)
            % Ch1 curves take the blue-green family, Ch2 the red-orange one,
            % matching the solid line colours used on the Inspector.
            if isfield(p,'cmap') && p.cmap == 2
                cm = ModulationMonitor.ch2Map();
            else
                cm = ModulationMonitor.ch1Map();
            end
        end

        function [xv, xName, famVals, famName, nFam] = familyLayout(obj, xAxisSel)
            if nargin < 2, xAxisSel = obj.TransferXAxis; end
            g = obj.Grid;
            if xAxisSel == 1 || ~g.Is2D
                xv = g.XValues; xName = g.XName;
                famVals = g.YValues; famName = g.YName; nFam = g.Ny;
            else
                xv = g.YValues; xName = g.YName;
                famVals = g.XValues; famName = g.XName; nFam = g.Nx;
            end
        end

        function [xs, ys, rIdx, nRep, repStd, rList] = seriesAlong(obj, data, k, alongX)
            % One curve: hold the family index k fixed, sweep the other axis.
            g = obj.Grid;
            if alongX
                n = g.Nx; xs = g.XValues;
                cells = cell(1,n);
                for ix = 1:n
                    if g.Is2D, cells{ix} = g.CellRuns{k,ix}; else, cells{ix} = g.CellRuns{ix}; end
                end
            else
                n = g.Ny; xs = g.YValues;
                cells = cell(1,n);
                for iy = 1:n
                    if g.Is2D, cells{iy} = g.CellRuns{iy,k}; else, cells{iy} = g.CellRuns{k}; end
                end
            end
            ys = NaN(1,n); rIdx = NaN(1,n);
            nRep = zeros(1,n); repStd = NaN(1,n);
            rList = repmat("", 1, n);   % run numbers behind each point
            for ii = 1:n
                r = cells{ii};
                if isempty(r), continue; end
                r = r(r >= 1 & r <= numel(data));
                if isempty(r), continue; end
                v = data(r); v = v(isfinite(v));
                if ~isempty(v)
                    ys(ii) = mean(v);           % repeats at one scan point are averaged
                    nRep(ii) = numel(v);
                    if numel(v) > 1
                        repStd(ii) = std(v);    % shot-to-shot scatter at this point
                    end
                end
                rIdx(ii) = r(1);
                rList(ii) = strjoin(string(r), ', ');
            end
        end

        function [sc, uStr] = tipScale(~, ushort, ref)
            % Pick a metric prefix from the SMALLEST quantity on the tooltip
            % (the standard deviation), and use it for every value on that
            % line so mean and sigma stay directly comparable. Without this a
            % sigma of 8.48e-04 V is unreadable next to a mean of 0.456 V.
            sc = 1; uStr = ushort;
            if ~isfinite(ref) || ref <= 0
                return
            end
            % Metric prefixes only make sense for SI units. A user-supplied
            % unit (Er, and so on) is left exactly as given.
            switch ushort
                case 'V'
                    if ref < 1e-3
                        sc = 1e6; uStr = 'uV';
                    elseif ref < 1
                        sc = 1e3; uStr = 'mV';
                    end
                case 'Hz'
                    if ref >= 1e6
                        sc = 1e-6; uStr = 'MHz';
                    elseif ref >= 1e3
                        sc = 1e-3; uStr = 'kHz';
                    end
                otherwise
                    % deg, dBc and friends are already in sensible units.
            end
        end

        function stats = lineStats(~, ys)
            % Variation of one curve across the swept variable.
            %
            % Reported as a relative standard deviation (1 sigma as a percent
            % of the curve mean) because the question being asked is "does
            % this quantity hold constant as the other variable is swept",
            % which is a scale-free question: 5 mV of wobble means something
            % different on a 0.1 V curve than on a 1 V one. Peak-to-peak is
            % Sigma is reported in the panel's own units so it can be read
            % against the line mean directly; the per-point z-score then says
            % whether the point under the cursor is the one responsible for
            % the spread.
            v = ys(isfinite(ys));
            stats = struct('Mean',NaN,'Std',NaN,'RelStd',NaN,'Span',NaN,'RelSpan',NaN,'Z',NaN(size(ys)));
            if isempty(v)
                return
            end
            stats.Mean = mean(v);
            stats.Span = max(v) - min(v);
            if numel(v) > 1
                stats.Std = std(v);
            else
                stats.Std = 0;
            end
            den = abs(stats.Mean);
            if den > 0
                stats.RelStd  = 100 * stats.Std  / den;
                stats.RelSpan = 100 * stats.Span / den;
            end
            if stats.Std > 0
                stats.Z = (ys - stats.Mean) / stats.Std;
            else
                stats.Z = zeros(size(ys));
            end
        end

        function [items, ids] = metricList(obj)
            % Menu entries for the selectable panel, with their metric ids.
            % Storing the id (not the menu position) means hiding or adding a
            % metric never silently repoints an existing selection.
            ids = obj.visibleMetricIds();
            ids = ids(ids ~= 7);            % phase already has its own panel
            [names, ~] = obj.metricRegistry();
            items = names(ids);
        end

        function xEnd = addPanelControls(obj, parent, xPos, yPos, hgt)
            if nargin < 4, yPos = 0.18; end
            if nargin < 5, hgt = 0.6; end
            % Channel + metric selectors for the third-column panel, and the
            % error-bar toggle. Shared by the Transfer and Scan map tabs.
            nCh = max(obj.NChannel,1);
            uicontrol(parent,'Style','text','Units','normalized',...
                'Position',[xPos yPos 0.065 hgt],'String','Top-right',...
                'BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',9);
            items = arrayfun(@(k) sprintf('Ch %d',k), 1:nCh, 'UniformOutput', false);
            uicontrol(parent,'Style','popupmenu','Units','normalized',...
                'Position',[xPos+0.065 yPos 0.052 hgt],'FontSize',9,...
                'String',items,'Value',min(max(round(obj.FreqPanelChannel),1),nCh),...
                'Enable', ModulationMonitor.onOff(nCh > 1), ...
                'Callback',@(s,~) obj.onFreqChannel(s));
            [items, ids] = obj.metricList();
            sel = find(ids == obj.FreqPanelMetric, 1);
            if isempty(sel), sel = 1; end
            obj.H.FreqMetricIds = ids;
            uicontrol(parent,'Style','popupmenu','Units','normalized',...
                'Position',[xPos+0.122 yPos 0.135 hgt],'FontSize',9,...
                'String',items,'Value',sel,...
                'Callback',@(s,~) obj.onFreqMetric(s));
            xEnd = xPos + 0.265;
        end

        function xEnd = addErrorBarToggle(obj, parent, xPos, yPos, hgt)
            if nargin < 4, yPos = 0.15; end
            if nargin < 5, hgt = 0.7; end
            uicontrol(parent,'Style','checkbox','Units','normalized',...
                'Position',[xPos yPos 0.105 hgt],'String','Show error bars',...
                'Value',obj.ShowErrorBars,'BackgroundColor','w',...
                'ForegroundColor',obj.CInk,'FontSize',9,...
                'Callback',@(s,~) obj.onErrorBars(s));
            xEnd = xPos + 0.11;
        end

        function onFreqChannel(obj, src)
            obj.FreqPanelChannel = src.Value;
            obj.DirtyTabs(1) = true;   % Transfer
            obj.DirtyTabs(2) = true;   % Scan map
            obj.DirtyTabs(4) = true;   % Custom
            obj.drawSelectedTab();
        end

        function onFreqMetric(obj, src)
            ids = obj.H.FreqMetricIds;
            obj.FreqPanelMetric = ids(min(max(src.Value,1),numel(ids)));
            obj.DirtyTabs(1) = true;
            obj.DirtyTabs(2) = true;
            obj.drawSelectedTab();
        end

        function onErrorBars(obj, src)
            obj.ShowErrorBars = logical(src.Value);
            obj.DirtyTabs(1) = true;   % Transfer
            obj.DirtyTabs(3) = true;   % Timeline
            obj.DirtyTabs(4) = true;   % Custom
            obj.drawSelectedTab();
        end

        function onTransferAxis(obj, src)
            obj.TransferXAxis = src.Value;
            obj.DirtyTabs(1) = true;
            obj.drawSelectedTab();
        end
    end

    %% ===================================================================
    %  Scan map tab
    %  ===================================================================
    methods (Access = protected)
        %% ---- Custom tab -------------------------------------------------
        function drawCustomTab(obj, runIdx)
            % Six panels, each independently configurable: metric, plot style
            % and channel. Reuses the same panel definitions and the same
            % three renderers as the fixed tabs, so nothing here is a second
            % implementation of anything.
            tab = obj.H.Tab(4);
            delete(allchild(tab));
            runs = 1:max(runIdx,1);

            ctl = uipanel(tab,'Units','normalized','Position',[0 0.86 1 0.14],...
                'BorderType','none','BackgroundColor','w');
            [allNames, ~] = obj.metricRegistry();
            mIds = obj.visibleMetricIds();
            names = allNames(mIds);
            obj.H.CustomMetricIds = mIds;
            styles = {'Scan map','Curve','vs Run'};
            nCh = max(obj.NChannel,1);
            chItems = arrayfun(@(k) sprintf('Ch %d',k), 1:nCh, 'UniformOutput', false);

            uicontrol(ctl,'Style','text','Units','normalized',...
                'Position',[0.004 0.70 0.06 0.24],'String','Curve x axis',...
                'BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',9);
            uicontrol(ctl,'Style','popupmenu','Units','normalized',...
                'Position',[0.065 0.70 0.15 0.26],'FontSize',9,...
                'String',{obj.varLabel(obj.ExpectedFrequencyVar), obj.varLabel(obj.depthVarName())},...
                'Value',min(max(round(obj.CustomXAxis),1),2),...
                'Callback',@(s,~) obj.onCustomXAxis(s));
            uicontrol(ctl,'Style','text','Units','normalized',...
                'Position',[0.225 0.70 0.60 0.24],...
                'String','Each column below configures the matching panel: metric, plot style, channel.',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','left','FontSize',8.5);

            % One column of controls per panel, in the same tile order.
            w = 0.158;
            for q = 1:6
                x = 0.006 + (q-1)*w;
                uicontrol(ctl,'Style','popupmenu','Units','normalized',...
                    'Position',[x 0.36 w*0.95 0.26],'FontSize',8.5,...
                    'String',names,'Value',ModulationMonitor.idPos(mIds, obj.CustomMetric(q)),...
                    'Callback',@(s,~) obj.onCustomMetric(s,q));
                uicontrol(ctl,'Style','popupmenu','Units','normalized',...
                    'Position',[x 0.04 w*0.55 0.26],'FontSize',8.5,...
                    'String',styles,'Value',min(max(round(obj.CustomStyle(q)),1),3),...
                    'Callback',@(s,~) obj.onCustomStyle(s,q));
                uicontrol(ctl,'Style','popupmenu','Units','normalized',...
                    'Position',[x+w*0.58 0.04 w*0.37 0.26],'FontSize',8.5,...
                    'String',chItems,'Value',min(max(round(obj.CustomChannel(q)),1),nCh),...
                    'Enable', ModulationMonitor.onOff(nCh > 1), ...
                    'Callback',@(s,~) obj.onCustomChannel(s,q));
            end

            tl = tiledlayout(tab, 2, 3, 'TileSpacing','loose','Padding','compact');
            tl.Units = 'normalized';
            tl.OuterPosition = [0 0.02 1 0.84];
            title(tl, sprintf('%sCustom  |  %d run(s) analysed', obj.trialTag(), runIdx), ...
                'FontWeight','bold','Color',obj.CInk);

            order = obj.panelTileOrder();
            for q = 1:6
                ax = nexttile(tl, order(q));
                pn = obj.buildMetricPanel(obj.CustomMetric(q), obj.CustomChannel(q), runs);
                switch obj.CustomStyle(q)
                    case 2, obj.drawCurvePanel(ax, pn, runs, obj.CustomXAxis);
                    case 3, obj.drawRunPanel(ax, pn, runs);
                    otherwise, obj.drawScanPanel(ax, pn, runs);
                end
            end

            uicontrol(tab,'Style','text','Units','normalized',...
                'Position',[0.01 0.002 0.98 0.018],'BackgroundColor','w',...
                'ForegroundColor',obj.CMuted,'HorizontalAlignment','left','FontSize',8.5,...
                'String','Click any point or cell to open that run in the Inspector.');
        end

        function drawRunPanel(obj, ax, p, runs)
            % Timeline-style: one metric against run index.
            obj.styleAxes(ax);
            if isfield(p,'NeedsConvert') && p.NeedsConvert
                obj.panelTitle(ax, p.name);
                obj.placeholder(ax, sprintf(['Needs "Convert volts?"\n\n' ...
                    'This metric combines Ch1 and Ch2, which have different\n' ...
                    'Er/V calibrations, so their raw voltage difference is\n' ...
                    'not meaningful.']));
                return
            end
            hold(ax,'on');
            y = p.data;
            col = obj.ChColor(min(max(p.cmap,1),4),:);
            if any(isfinite(y))
                h = plot(ax, runs, y, 'o', 'Color', col, 'MarkerFaceColor', col, ...
                    'MarkerSize', 5, 'LineStyle','none', ...
                    'ButtonDownFcn', @(s,e) obj.onPick(s,e));
                ax.UserData = struct('Kind','run');
                try
                    h.DataTipTemplate.DataTipRows = [ ...
                        dataTipTextRow('Run', runs); ...
                        dataTipTextRow(sprintf('%s (%s)', p.short, p.ushort), y)];
                catch
                end
            else
                obj.placeholder(ax,'No data for this metric');
            end
            if isfinite(p.ref)
                yline(ax, p.ref, '--', 'Color', obj.CMuted, 'HandleVisibility','off');
            end
            obj.panelTitle(ax, p.name);
            ylabel(ax, p.unit); xlabel(ax,'Run');
            hold(ax,'off');
        end

        function onCustomMetric(obj, src, q)
            ids = obj.H.CustomMetricIds;
            obj.CustomMetric(q) = ids(min(max(src.Value,1),numel(ids)));
            obj.DirtyTabs(4) = true; obj.drawSelectedTab();
        end

        function onCustomStyle(obj, src, q)
            obj.CustomStyle(q) = src.Value;
            obj.DirtyTabs(4) = true; obj.drawSelectedTab();
        end

        function onCustomChannel(obj, src, q)
            obj.CustomChannel(q) = src.Value;
            obj.DirtyTabs(4) = true; obj.drawSelectedTab();
        end

        function onCustomXAxis(obj, src)
            obj.CustomXAxis = src.Value;
            obj.DirtyTabs(4) = true; obj.drawSelectedTab();
        end

        function drawMapTab(obj, runIdx)
            tab = obj.H.Tab(2);
            delete(allchild(tab));
            runs = 1:max(runIdx,1);

            ctl = uipanel(tab,'Units','normalized','Position',[0 0.955 1 0.045],...
                'BorderType','none','BackgroundColor','w');
            obj.addPanelControls(ctl, 0.006);

            tl = tiledlayout(tab, 2, 3, 'TileSpacing','loose','Padding','loose');
            tl.Units = 'normalized';
            tl.OuterPosition = [0 0.03 1 0.915];
            title(tl, sprintf('%sScan map  |  %d run(s) analysed', obj.trialTag(), runIdx), ...
                'FontWeight','bold','Color',obj.CInk);

            p = obj.panelSet(runs);
            order = obj.panelTileOrder();
            for ii = 1:min(numel(p),6)
                ax = nexttile(tl, order(ii));
                obj.drawScanPanel(ax, p{ii}, runs);
            end

            uicontrol(tab,'Style','text','Units','normalized',...
                'Position',[0.01 0.002 0.98 0.026],'BackgroundColor','w',...
                'ForegroundColor',obj.CMuted,'HorizontalAlignment','left','FontSize',9,...
                'String','Click any cell to open that run in the Inspector. Blank cells have no data yet.');
        end

        function drawScanPanel(obj, ax, p, runs)
            g = obj.Grid;
            obj.styleAxes(ax);
            if isfield(p,'NeedsConvert') && p.NeedsConvert
                obj.panelTitle(ax, p.name);
                obj.placeholder(ax, sprintf(['Needs "Convert volts?"\n\n' ...
                    'This metric combines Ch1 and Ch2, which have different\n' ...
                    'Er/V calibrations, so their raw voltage difference is\n' ...
                    'not meaningful.']));
                return
            end
            if ~g.Valid
                obj.panelTitle(ax, p.name);
                obj.placeholder(ax,'Waiting for scan variables');
                return
            end
            M = obj.gridify(p.data, runs);

            if g.Is2D
                % Kapitza orientation: drive amplitude on x, modulation
                % frequency on y with the LOWEST frequency at the top, to
                % match how the phase diagrams are plotted. The stored grid
                % is always (alpha rows x frequency columns), so this only
                % transposes the display; CellRuns is untouched and onPick
                % swaps the indices back.
                tr = obj.IsKapitzaAxes;
                if tr
                    D = M.';                       % rows = frequency
                    nX = g.Ny; nY = g.Nx;
                    xLab = g.YLabels; yLab = g.XLabels;
                    xName = g.YName;  yName = g.XName;
                    yDir = 'reverse';              % lowest frequency at top
                else
                    D = M;
                    nX = g.Nx; nY = g.Ny;
                    xLab = g.XLabels; yLab = g.YLabels;
                    xName = g.XName;  yName = g.YName;
                    yDir = 'normal';
                end
                im = imagesc(ax, 1:nX, 1:nY, D);
                set(im,'AlphaData',~isnan(D));
                ax.YDir = yDir;
                obj.thinTicks(ax, 'x', 1:nX, xLab, 14);
                obj.thinTicks(ax, 'y', 1:nY, yLab, 14);
                ax.XTickLabelRotation = 45;
                ax.TickLabelInterpreter = 'none';
                xlabel(ax, obj.varLabel(xName), 'Interpreter','none');
                ylabel(ax, obj.varLabel(yName), 'Interpreter','none');
                obj.applyMapColors(ax, D, p);
                cb = colorbar(ax);
                cb.Label.String = p.unit;
                cb.Label.FontSize = 9.5;
                cb.FontSize = 9;
                cb.Color = obj.CInk;
                cb.Box = 'off';
                ax.XGrid = 'off'; ax.YGrid = 'off';
                ax.Color = [0.898 0.906 0.918];
                set(im,'HitTest','on','PickableParts','all',...
                    'ButtonDownFcn',@(s,e) obj.onPick(s,e));
                ax.UserData = struct('Kind','map','Transposed',tr);
                obj.addMapDataTip(ax, D, p, tr);
            else
                % 1D scan: a 1xN strip is unreadable, so draw a line instead.
                v = M(:).'; x = 1:numel(v);
                plot(ax, x, v, '-', 'Color', obj.CGrid, 'LineWidth', 1, 'HandleVisibility','off');
                hold(ax,'on');
                h = plot(ax, x, v, 'o', 'MarkerFaceColor', obj.ChColor(min(p.cmap,4),:), ...
                    'MarkerEdgeColor','none','MarkerSize',6,'LineStyle','none',...
                    'ButtonDownFcn', @(s,e) obj.onPick(s,e));
                h.UserData = obj.firstRunPerCell();
                % Same tip content as the 2D map: scan value, metric, runs.
                rs1 = g.CellRunStr;
                if numel(rs1) ~= numel(v)
                    rs1 = repmat("", 1, numel(v));
                end
                h.DataTipTemplate.DataTipRows = [ ...
                    dataTipTextRow(obj.varLabel(g.XName), g.XValues); ...
                    dataTipTextRow(sprintf('%s (%s)', p.short, p.ushort), v); ...
                    dataTipTextRow('Runs', cellstr(rs1))];
                if isfinite(p.ref)
                    yline(ax, p.ref, '--', 'Color', obj.CMuted, 'HandleVisibility','off');
                end
                if strcmp(p.mode,'cyc')
                    lim = obj.phaseLimit(v);
                    ylim(ax,[-lim lim]);
                end
                obj.thinTicks(ax, 'x', x, g.XLabels, 12);
                ax.XTickLabelRotation = 45;
                ax.TickLabelInterpreter = 'none';
                xlabel(ax, obj.varLabel(g.XName), 'Interpreter','none');
                ylabel(ax, p.unit);
                xlim(ax,[0.5 numel(v)+0.5]);
                ax.UserData = struct('Kind','curve');
                hold(ax,'off');
            end
            % Set last: imagesc/plot call newplot, which resets the axes and
            % would delete a title created beforehand.
            obj.panelTitle(ax, p.name);
        end

        function addMapDataTip(obj, ax, D, p, tr)
            % Image objects do NOT support custom DataTipTemplate rows - the
            % built-in [X,Y] / Index / [R,G,B] tip is all you get, and
            % assigning DataTipRows to an Image errors. So the tips are hung
            % off an invisible scatter placed at the cell centres instead,
            % which does support them (and makes the cells pickable too).
            g = obj.Grid;
            [ny, nx] = size(D);
            [C, R] = meshgrid(1:nx, 1:ny);
            if tr
                % displayed x = depth index, y = frequency index
                xv = repmat(g.YValues(:).', ny, 1);
                yv = repmat(g.XValues(:), 1, nx);
                rs = g.CellRunStr.';
            else
                xv = repmat(g.XValues(:).', ny, 1);
                yv = repmat(g.YValues(:), 1, nx);
                rs = g.CellRunStr;
            end
            if ~isequal(size(rs), [ny nx])
                rs = repmat("", ny, nx);
            end
            if tr
                xName = g.YName; yName = g.XName;
            else
                xName = g.XName; yName = g.YName;
            end

            % Only place markers on cells that actually contain runs. A scan
            % where both variables step together fills a diagonal, so the
            % grid can be ~99% empty: one marker per cell would be thousands
            % of invisible points per panel for a hundred measurements. This
            % also means a tip never appears over a cell with no data.
            keep = rs ~= "" & rs ~= "none";
            if ~any(keep(:))
                return
            end

            % Do NOT use hold/ishold here: ishold errors with
            % "Using hold with image is not supported" on an axes that
            % contains an image. Setting NextPlot directly adds the overlay
            % without going near that code path.
            np = get(ax,'NextPlot');
            set(ax,'NextPlot','add');
            h = scatter(ax, C(keep), R(keep), 60, 'filled', ...
                'MarkerFaceAlpha', 0, 'MarkerEdgeAlpha', 0, ...
                'HitTest','on', 'PickableParts','all', ...
                'HandleVisibility','off', ...
                'ButtonDownFcn', @(s,e) obj.onPick(s,e));
            set(ax,'NextPlot',np);

            h.DataTipTemplate.DataTipRows = [ ...
                dataTipTextRow(obj.varLabel(xName), xv(keep)); ...
                dataTipTextRow(obj.varLabel(yName), yv(keep)); ...
                dataTipTextRow(sprintf('%s (%s)', p.short, p.ushort), D(keep)); ...
                dataTipTextRow('Runs', cellstr(rs(keep)))];
        end

        function applyMapColors(obj, ax, M, p)
            v = M(isfinite(M));
            if isempty(v), return; end
            switch p.mode
                case 'div'
                    % Symmetric about zero so sign reads off the colour.
                    lim = max(abs(v));
                    if lim <= 0, lim = 1; end
                    caxis(ax,[-lim lim]);
                    colormap(ax, ModulationMonitor.divergingMap());
                case 'divref'
                    % Diverging, but centred on a reference value (the
                    % commanded V0) rather than on zero.
                    c0 = p.ref;
                    lim = max(abs(v - c0));
                    if ~isfinite(lim) || lim <= 0, lim = 1; end
                    caxis(ax,[c0-lim c0+lim]);
                    colormap(ax, ModulationMonitor.divergingMap());
                case 'cyc'
                    % Phase is cyclic, but a cyclic map wastes all its
                    % contrast when the data sit near zero. Use the full
                    % cyclic range only when the errors are actually large
                    % enough to wrap; otherwise a symmetric diverging map
                    % resolves the structure that matters.
                    lim = max(abs(v));
                    if lim > 90
                        caxis(ax,[-180 180]);
                        colormap(ax, ModulationMonitor.cyclicMap());
                    else
                        caxis(ax,[-max(lim,1) max(lim,1)]);
                        colormap(ax, ModulationMonitor.divergingMap());
                    end
                otherwise
                    lo = min(v); hi = max(v);
                    if hi <= lo, hi = lo + 1e-12; end
                    caxis(ax,[lo hi]);
                    if isfield(p,'cmap') && p.cmap == 2
                        colormap(ax, ModulationMonitor.ch2Map());
                    else
                        colormap(ax, ModulationMonitor.ch1Map());
                    end
            end
        end
    end

    %% ===================================================================
    %  Timeline tab
    %  ===================================================================
    methods (Access = protected)
        function drawTimelineTab(obj, runIdx)
            tab = obj.H.Tab(3);
            delete(allchild(tab));
            runs = 1:max(runIdx,1);

            ctl = uipanel(tab,'Units','normalized','Position',[0 0.955 1 0.045],...
                'BorderType','none','BackgroundColor','w');
            xE = obj.addErrorBarToggle(ctl, 0.006);
            uicontrol(ctl,'Style','text','Units','normalized',...
                'Position',[xE 0.15 max(0.99-xE,0.05) 0.65],...
                'String','Error bars show the scatter across repeats of that run''s scan point.',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','left','FontSize',8.5);

            tl = tiledlayout(tab, 2, 2, 'TileSpacing','loose','Padding','compact');
            tl.Units = 'normalized';
            tl.OuterPosition = [0 0.03 1 0.915];
            title(tl, sprintf('%sPer-run timeline  |  drift and outliers', obj.trialTag()), ...
                'FontWeight','bold','Color',obj.CInk);

            ax = nexttile(tl); obj.styleAxes(ax); hold(ax,'on');
            for k = 1:obj.NChannel
                obj.scatterRuns(ax, runs, obj.convert(obj.row(obj.Vpp,k,runs),k,'delta'), k);
            end
            obj.panelTitle(ax,'AC pk-pk'); ylabel(ax,obj.unitLong('pp')); xlabel(ax,'Run');
            obj.tidyLegend(ax); hold(ax,'off');

            ax = nexttile(tl); obj.styleAxes(ax); hold(ax,'on');
            for k = 1:obj.NChannel
                obj.scatterRuns(ax, runs, obj.convert(obj.row(obj.Dc,k,runs),k,'level'), k);
            end
            obj.panelTitle(ax,'Mean level'); ylabel(ax,obj.unitLong('level')); xlabel(ax,'Run');
            obj.tidyLegend(ax); hold(ax,'off');

            ax = nexttile(tl); obj.styleAxes(ax); hold(ax,'on');
            obj.scatterRuns(ax, runs, obj.padTo(obj.PhaseErr,runs), 0, 'Phase error');
            yline(ax,0,'--','Color',obj.CMuted,'Label','Target','HandleVisibility','off');
            lim = obj.phaseLimit(obj.padTo(obj.PhaseErr,runs));
            ylim(ax,[-lim lim]);   % symmetric about zero, scaled to the data
            obj.panelTitle(ax,'Relative phase error');
            ylabel(ax,'Degrees from target'); xlabel(ax,'Run'); hold(ax,'off');

            ax = nexttile(tl); obj.styleAxes(ax); hold(ax,'on');
            for k = 1:obj.NChannel
                obj.scatterRuns(ax, runs, ...
                    obj.row(obj.Freq,k,runs) - obj.padTo(obj.FreqExpected,runs), k);
            end
            yline(ax,0,'--','Color',obj.CMuted,'HandleVisibility','off');
            obj.panelTitle(ax,'Measured minus commanded frequency');
            ylabel(ax,'Hertz'); xlabel(ax,'Run'); obj.tidyLegend(ax); hold(ax,'off');

            uicontrol(tab,'Style','text','Units','normalized',...
                'Position',[0.01 0.002 0.98 0.026],'BackgroundColor','w',...
                'ForegroundColor',obj.CMuted,'HorizontalAlignment','left','FontSize',9,...
                'String','Click any point to open that run in the Inspector. Use the data-tip tool to read values without leaving this tab.');
        end

        function scatterRuns(obj, ax, runs, y, k, nameOverride)
            y = obj.padTo(y, runs);
            if ~any(isfinite(y)), return; end
            err = [];
            if obj.ShowErrorBars
                err = obj.repeatErrPerRun(y, runs);
            end
            if k >= 1
                col = obj.ChColor(min(k,size(obj.ChColor,1)),:);
                mkList = {'o','s','^','d'};
                mk = mkList{min(k,4)};
                nm = sprintf('Ch %d', k);
            else
                col = obj.ChColor(4,:); mk = 'o'; nm = 'Value';
            end
            if nargin >= 6, nm = nameOverride; end
            if ~isempty(err) && any(isfinite(err))
                h = errorbar(ax, runs, y, err, mk, 'Color', col, ...
                    'MarkerFaceColor', col, 'MarkerSize', 5.5, 'LineStyle','none', ...
                    'CapSize', 3, 'DisplayName', nm, ...
                    'ButtonDownFcn', @(s,e) obj.onPick(s,e));
            else
                h = plot(ax, runs, y, mk, 'Color', col, 'MarkerFaceColor', col, ...
                    'MarkerSize', 5.5, 'LineStyle','none', 'DisplayName', nm, ...
                    'ButtonDownFcn', @(s,e) obj.onPick(s,e));
            end
            ax.UserData = struct('Kind','run');
            try
                h.DataTipTemplate.DataTipRows = [ ...
                    dataTipTextRow('Run', runs); ...
                    dataTipTextRow('Value', y); ...
                    dataTipTextRow(obj.varLabel(obj.ExpectedFrequencyVar), obj.padTo(obj.FreqExpected,runs)); ...
                    dataTipTextRow(obj.varLabel(obj.depthVarName()), obj.padTo(obj.DepthSet,runs))];
            catch
            end
        end
    end

    %% ===================================================================
    %  Basic tab
    %  ===================================================================
    methods (Access = protected)
        function buildBasicTab(obj)
            tab = obj.H.Tab(5);
            delete(allchild(tab));
            obj.H.BasicNav = obj.buildRunNav(tab, false);
            obj.H.BasicBody = uipanel(tab,'Units','normalized','Position',[0 0 1 0.92],...
                'BorderType','none','BackgroundColor','w');
        end

        function drawBasicTab(obj)
            if ~isfield(obj.H,'BasicBody') || ~isgraphics(obj.H.BasicBody)
                obj.buildBasicTab();
            end
            runIdx = obj.InspectorRun;
            obj.H.BasicNav.Edit.String = num2str(runIdx);
            body = obj.H.BasicBody;
            delete(allchild(body));

            nCh = max(obj.NChannel,1);

            % Notices are optional, so everything below the header is laid out
            % from a running cursor rather than at fixed heights. With fixed
            % positions a second notice overlapped the channel panels.
            yCur = 0.955;
            hHdr = 0.050;
            hNote = 0.042;

            % --- header, pipe-delimited -------------------------------
            yCur = yCur - hHdr;
            hdr = obj.pipeLine({ ...
                sprintf('%sRun %d', obj.trialTag(), runIdx), ...
                sprintf('%s = %s', obj.varLabel(obj.ExpectedFrequencyVar), ...
                    ModulationMonitor.fmtEng(obj.at(obj.FreqExpected,runIdx),'Hz')), ...
                sprintf('%s = %s', obj.varLabel(obj.depthVarName()), ...
                    ModulationMonitor.fmtVal(obj.at(obj.DepthSet,runIdx))), ...
                sprintf('sample rate = %s', ModulationMonitor.fmtEng(obj.at(obj.SampleRate,runIdx),'Sa/s')), ...
                sprintf('measured mod time = %s', ModulationMonitor.fmtEng(obj.at(obj.ModTime,runIdx),'s'))});
            uicontrol(body,'Style','text','Units','normalized',...
                'Position',[0.02 yCur 0.96 hHdr],'String',hdr,'BackgroundColor','w',...
                'ForegroundColor',obj.CInk,'HorizontalAlignment','left',...
                'FontSize',11,'FontWeight','bold');

            % --- clipped-mask notice -----------------------------------
            if runIdx <= numel(obj.MaskClipped) && obj.MaskClipped(runIdx)
                yCur = yCur - hNote;
                cs = runIdx <= numel(obj.ClipStart) && obj.ClipStart(runIdx);
                ce = runIdx <= numel(obj.ClipEnd)   && obj.ClipEnd(runIdx);
                if cs && ce
                    which = 'both turn-on and turn-off were';
                elseif cs
                    which = 'turn-on was';
                else
                    which = 'turn-off was';
                end
                extra = '';
                if cs
                    extra = ' No static region in front of the burst, so dVdc is unavailable.';
                end
                uicontrol(body,'Style','text','Units','normalized',...
                    'Position',[0.02 yCur 0.96 hNote],...
                    'String',sprintf(['Modulation reaches a record edge: %s not captured, so mod time is a lower bound. ' ...
                        'Frequency, amplitude and phase are unaffected.%s'], which, extra),...
                    'BackgroundColor','w','ForegroundColor',obj.CMask,...
                    'HorizontalAlignment','left','FontSize',9.5);
            end

            % --- timebase correction notice ----------------------------
            raw = obj.at(obj.RawDuration, runIdx);
            tru = obj.at(obj.TrueDuration, runIdx);
            if isfinite(raw) && isfinite(tru) && abs(tru-raw) > obj.TimebaseWarnFraction*max(tru,eps)
                yCur = yCur - hNote;
                msg = sprintf('Timebase corrected: file reports a %s capture, not achievable on a 1-2-5 timebase. Rounded up to %s (%s/div); all frequencies use the corrected rate.', ...
                    ModulationMonitor.fmtEng(raw,'s'), ModulationMonitor.fmtEng(tru,'s'), ...
                    ModulationMonitor.fmtEng(tru/10,'s'));
                uicontrol(body,'Style','text','Units','normalized',...
                    'Position',[0.02 yCur 0.96 hNote],'String',msg,'BackgroundColor','w',...
                    'ForegroundColor',obj.CMask,'HorizontalAlignment','left','FontSize',9.5);
            end

            % --- combined-lattice summary, anchored above the phase line
            yComb = 0.085;
            hComb = 0.05;
            if obj.NChannel >= 2
                v0 = obj.combinedV0(1:runIdx);
                vi = obj.combinedVi(1:runIdx);
                abv = obj.combinedAlphaBeta(1:runIdx);
                bal = obj.combinedBalance(1:runIdx);
                u = obj.unitStr();
                tgt = obj.at(obj.V0Expected, runIdx);
                if isfinite(tgt)
                    v0Str = sprintf('V0 = %s %s (target %s)', ...
                        ModulationMonitor.fmtNum(obj.at(v0,runIdx),'%.2f'), u, ...
                        ModulationMonitor.fmtNum(tgt,'%.2f'));
                else
                    v0Str = sprintf('V0 = %s %s', ModulationMonitor.fmtNum(obj.at(v0,runIdx),'%.2f'), u);
                end
                [stateStr, ~] = obj.inversionState(runIdx);
                items = {'Combined lattice, Ch2 - Ch1', v0Str, ...
                    sprintf('Vi = %s %s', ModulationMonitor.fmtNum(obj.at(vi,runIdx),'%.2f'), u), ...
                    sprintf('state = %s', stateStr)};
                % alpha*beta and AC balance are hidden with the same switch
                % that removes them from the metric menus, so the readout and
                % the plot options cannot disagree.
                if obj.ShowDriveMetrics
                    items{end+1} = sprintf('%s%s = %s', char(945), char(946), ...
                        ModulationMonitor.fmtNum(obj.at(abv,runIdx),'%.2f'));
                    items{end+1} = sprintf('AC balance = %s %%', ...
                        ModulationMonitor.fmtNum(obj.at(bal,runIdx),'%+.2f'));
                end
                uicontrol(body,'Style','text','Units','normalized',...
                    'Position',[0.02 yComb 0.96 hComb],'String',obj.pipeLine(items),...
                    'BackgroundColor','w','ForegroundColor',obj.CInk,...
                    'HorizontalAlignment','left','FontSize',11,'FontWeight','bold');
            end

            % --- relative phase line, anchored to the bottom -----------
            yPhase = 0.03;
            hPhase = 0.05;
            hasPhase = obj.CalculatePhase && obj.NChannel >= 2;
            if hasPhase
                pe = obj.at(obj.PhaseErr,runIdx);
                if isfinite(pe)
                    ph = obj.pipeLine({ ...
                        'Relative phase, Ch 1 minus Ch 2', ...
                        sprintf('measured = %+.2f deg', ModulationMonitor.wrap180(pe + obj.PhaseTarget)), ...
                        sprintf('target = %.1f deg', obj.PhaseTarget), ...
                        sprintf('error = %+.2f deg', pe)});
                else
                    ph = 'Relative phase, Ch 1 minus Ch 2  |  not available  |';
                end
                uicontrol(body,'Style','text','Units','normalized',...
                    'Position',[0.02 yPhase 0.96 hPhase],'String',ph,'BackgroundColor','w',...
                    'ForegroundColor',obj.CInk,'HorizontalAlignment','left','FontSize',11);
            end

            % --- channel panels fill whatever is left ------------------
            panelTop = yCur - 0.012;
            panelBot = yComb + hComb + 0.015;
            panelH = max(panelTop - panelBot, 0.25);
            w = 0.96/nCh;
            for k = 1:nCh
                pnl = uipanel(body,'Units','normalized',...
                    'Position',[0.02 + (k-1)*w, panelBot, w*0.965, panelH],...
                    'Title',sprintf('  Channel %d  ', k),'FontSize',11,'FontWeight','bold',...
                    'ForegroundColor',obj.ChColor(min(k,4),:),...
                    'BackgroundColor',obj.CPanelBg,'HighlightColor',obj.CGrid);
                obj.fillChannelPanel(pnl, k, runIdx);
            end
        end

        function fillChannelPanel(obj, pnl, k, runIdx)
            % Label / value rows drawn as separate controls so the value can
            % be emphasised without resorting to a monospaced block.
            fSet = obj.at(obj.FreqExpected, runIdx);
            fM   = obj.cell2(obj.Freq, k, runIdx);
            vppRaw  = obj.cell2(obj.Vpp, k, runIdx);
            vrmsRaw = obj.cell2(obj.Vrms, k, runIdx);
            vdcRaw  = obj.cell2(obj.Dc, k, runIdx);
            stepRaw = obj.cell2(obj.DcStep, k, runIdx);
            preRaw  = obj.cell2(obj.DcPre, k, runIdx);
            darkRaw = obj.cell2(obj.DcDark, k, runIdx);
            th   = obj.cell2(obj.Thd, k, runIdx);
            % Differences take the multiplier only; levels take the offset too.
            vpp  = obj.convert(vppRaw,  k, 'delta');
            vrms = obj.convert(vrmsRaw, k, 'delta');
            vdc  = obj.convert(vdcRaw,  k, 'level');
            step = obj.convert(stepRaw, k, 'delta');
            u    = obj.unitStr();

            if isfinite(fM) && isfinite(fSet)
                devStr = sprintf('%+.2f Hz', fM - fSet);
            else
                devStr = '-';
            end
            % Modulation depth = peak swing / mean level. Computed in the
            % displayed units, so a calibration offset changes it, as it
            % physically should.
            if isfinite(vpp) && isfinite(vdc) && vdc ~= 0
                depthStr = sprintf('%.4f', (0.5*vpp)/abs(vdc));
            else
                depthStr = '-';
            end
            % Step in the mean level when modulation starts, plus the same
            % thing as a percentage of the static level above dark.
            if isfinite(stepRaw) && isfinite(preRaw) && isfinite(darkRaw) && ...
                    abs(preRaw - darkRaw) > 0
                stepStr = sprintf('%+.4f %s  (%+.2f %% of static)', step, u, ...
                    100*stepRaw/(preRaw - darkRaw));
            elseif isfinite(step)
                stepStr = sprintf('%+.4f %s', step, u);
            else
                stepStr = '-';
            end
            [lockStr, lockCol] = obj.lockStatus(fM, fSet);

            rows = { ...
                'Set frequency',      ModulationMonitor.fmtEng(fSet,'Hz'),        obj.CInk; ...
                'Measured frequency', ModulationMonitor.fmtEng(fM,'Hz'),          obj.CInk; ...
                'Frequency error',    devStr,                                     obj.CInk; ...
                'Frequency lock',     lockStr,                                    lockCol; ...
                '', '', obj.CInk; ...
                sprintf('Vpp (AC) [%s]', u),  ModulationMonitor.fmtNum(vpp,'%.4f'),  obj.CInk; ...
                sprintf('Vrms (AC) [%s]', u), ModulationMonitor.fmtNum(vrms,'%.4f'), obj.CInk; ...
                sprintf('Vdc (mean) [%s]', u),ModulationMonitor.fmtNum(vdc,'%.4f'),  obj.CInk; ...
                'Mod depth (0.5*Vpp / Vdc)', depthStr,                             obj.CInk; ...
                sprintf('%sV_dc at mod start', char(916)), stepStr,                 obj.CInk; ...
                '', '', obj.CInk; ...
                'Measured mod time',  ModulationMonitor.fmtEng(obj.at(obj.ModTime,runIdx),'s'), obj.CInk; ...
                'THD',                ModulationMonitor.fmtNum(th,'%.1f dBc'),                  obj.CInk};

            n = size(rows,1);
            top = 0.94; rowH = 0.075;
            for ii = 1:n
                if isempty(rows{ii,1}), continue; end
                y = top - ii*rowH;
                uicontrol(pnl,'Style','text','Units','normalized',...
                    'Position',[0.05 y 0.45 rowH*0.92],'String',rows{ii,1},...
                    'BackgroundColor',obj.CPanelBg,'ForegroundColor',obj.CMuted,...
                    'HorizontalAlignment','left','FontSize',10.5);
                uicontrol(pnl,'Style','text','Units','normalized',...
                    'Position',[0.50 y 0.46 rowH*0.92],'String',rows{ii,2},...
                    'BackgroundColor',obj.CPanelBg,'ForegroundColor',rows{ii,3},...
                    'HorizontalAlignment','left','FontSize',10.5,'FontWeight','bold');
            end
        end

        function [s, col] = lockStatus(obj, fMeas, fSet)
            % Cheap sanity flag: is the measured fundamental actually the one
            % that was asked for? A near-integer ratio is reported explicitly
            % because harmonic or sub-harmonic lock is the usual failure.
            col = obj.CInk;
            if ~isfinite(fMeas) || ~isfinite(fSet) || fSet <= 0
                s = '-';
                return
            end
            ratio = fMeas / fSet;
            if abs(ratio - 1) <= obj.LockTolerance
                s = 'locked';
                col = [0.180 0.545 0.341];
            else
                col = obj.CMask;
                nearest = round(ratio);
                if nearest >= 2 && abs(ratio - nearest) < 0.05
                    s = sprintf('MISMATCH (%dx commanded)', nearest);
                elseif ratio < 0.9 && abs(1/ratio - round(1/ratio)) < 0.05
                    s = sprintf('MISMATCH (1/%d of commanded)', round(1/ratio));
                else
                    s = sprintf('MISMATCH (%.3fx commanded)', ratio);
                end
            end
        end
    end

    %% ===================================================================
    %  Inspector tab
    %  ===================================================================
    methods (Access = protected)
        function buildInspectorTab(obj)
            tab = obj.H.Tab(6);
            delete(allchild(tab));
            obj.H.InspNav = obj.buildRunNav(tab, true);

            obj.H.InspInfo = uicontrol(tab,'Style','text','Units','normalized',...
                'Position',[0.006 0.845 0.988 0.085],'String','','BackgroundColor','w',...
                'ForegroundColor',obj.CInk,'HorizontalAlignment','left','FontSize',10);

            % Four rows so the spectra can span two of them: they carry the
            % most detail and need the vertical room.
            obj.H.InspLayout = tiledlayout(tab, 4, 1, 'TileSpacing','compact','Padding','compact');
            obj.H.InspLayout.Units = 'normalized';
            obj.H.InspLayout.OuterPosition = [0 0 1 0.845];
            obj.H.AxTrace = nexttile(obj.H.InspLayout, 1);
            obj.H.AxCycle = nexttile(obj.H.InspLayout, 2);
            obj.H.SpecTile = 3;
            obj.H.SpecSpan = [2 1];
        end

        function drawInspector(obj)
            if ~isfield(obj.H,'AxTrace') || ~isgraphics(obj.H.AxTrace)
                obj.buildInspectorTab();
            end
            runIdx = obj.InspectorRun;
            obj.H.InspNav.Edit.String = num2str(runIdx);
            obj.syncNudgeControls();

            axT = obj.H.AxTrace; axC = obj.H.AxCycle;
            cla(axT,'reset'); cla(axC,'reset');
            obj.styleAxes(axT); obj.styleAxes(axC);
            % Whichever object occupied the bottom tile last time.
            if isfield(obj.H,'SpecLayout') && isgraphics(obj.H.SpecLayout)
                delete(obj.H.SpecLayout);
            end
            if isfield(obj.H,'CombAxes') && isgraphics(obj.H.CombAxes)
                delete(obj.H.CombAxes);
            end

            res = obj.analyzeRun(runIdx, true);
            if ~res.Ok || isempty(res.Y)
                obj.placeholder(axT, sprintf('No scope trace available for run %d', runIdx));
                obj.H.InspInfo.String = '';
                return
            end
            nCh = size(res.Y,2);
            t = res.T * 1e3;   % ms

            %% --- full trace with the detected modulation window --------
            hold(axT,'on');
            for k = 1:nCh
                plot(axT, t, obj.convert(res.Y(:,k), k, 'level'), ...
                    'Color', obj.ChColor(min(k,4),:), ...
                    'LineWidth', 0.5, 'DisplayName', sprintf('Ch %d', k));
            end
            if isfinite(res.S)
                % Labels sit outside the window so they never cover the data.
                xline(axT, t(res.S), '-', 'Color', obj.CMask, 'LineWidth', 2, ...
                    'Label','mask','LabelHorizontalAlignment','left',...
                    'LabelVerticalAlignment','top','LabelOrientation','horizontal',...
                    'Color',obj.CMask,'FontSize',9,'HandleVisibility','off');
                xline(axT, t(res.E), '-', 'Color', obj.CMask, 'LineWidth', 2, ...
                    'Label','mask','LabelHorizontalAlignment','right',...
                    'LabelVerticalAlignment','top','LabelOrientation','horizontal',...
                    'Color',obj.CMask,'FontSize',9,'HandleVisibility','off');
            end
            obj.panelTitle(axT, sprintf('%sRun %d  |  raw traces and detected modulation', ...
                obj.trialTag(), runIdx));
            ylabel(axT,obj.unitLong('level')); xlabel(axT,'Time (ms)');
            obj.tidyLegend(axT); hold(axT,'off');

            %% --- cycle detail with the fitted model --------------------
            hold(axC,'on');
            f0 = obj.referenceFreq(res);
            if isfinite(f0) && f0 > 0 && isfinite(res.S)
                span = max(round(4 * res.Fs / f0), 32);
                i0 = res.S + round(0.10*(res.E - res.S));   % start inside the window
                i1 = min(i0 + span, res.E);
                idx = i0:i1;
                tau = res.T(idx) - res.T(1);   % same origin used by the fit
                for k = 1:nCh
                    col = obj.ChColor(min(k,4),:);
                    plot(axC, res.T(idx)*1e3, obj.convert(res.Y(idx,k), k, 'level'), ...
                        '.', 'Color', col, 'MarkerSize', 7, 'HandleVisibility','off');
                    c = res.Ch(k);
                    if isfinite(c.F) && isfinite(c.A)
                        model = c.A*cos(2*pi*c.F*tau + c.Phi) + c.Dc;
                        plot(axC, res.T(idx)*1e3, obj.convert(model, k, 'level'), ...
                            '-', 'Color', col*0.45, 'LineWidth', 2, ...
                            'DisplayName', sprintf('Ch %d fit', k));
                    end
                end
            end
            obj.panelTitle(axC,'Mod cycle detailed view, with fit');
            ylabel(axC,obj.unitLong('level')); xlabel(axC,'Time (ms)');
            obj.tidyLegend(axC); hold(axC,'off');

            %% --- bottom tile: spectra, or the combined lattice ---------
            switch obj.InspectorBottom
                case 2, obj.drawCombined(res, nCh, runIdx);
                case 3, obj.drawChirp(res, nCh, runIdx);
                otherwise, obj.drawSpectra(res, nCh, f0);
            end

            obj.H.InspInfo.String = obj.inspectorHeader(res, runIdx, nCh);
        end

        function drawCombined(obj, res, nCh, runIdx)
            % The atoms see the DIFFERENCE of the two beams:
            %   V_KP(t) = U2(t) - U1(t) = V0 [1 + a*b*sin(wt+phi)]
            % so this is the only trace that shows the actual lattice. Both
            % the measured difference and the difference of the two fitted
            % sinusoids are drawn: where they part company is where the
            % waveform is not the steady-state sinusoid, which is exactly the
            % onset transient the raw per-channel traces make hard to judge.
            ax = axes(obj.H.InspLayout); %#ok<LAXES>
            ax.Layout.Tile = obj.H.SpecTile;
            ax.Layout.TileSpan = obj.H.SpecSpan;
            obj.H.CombAxes = ax;
            obj.styleAxes(ax);

            if nCh < 2 || isempty(res.Y)
                obj.placeholder(ax,'Combined lattice needs two channels');
                return
            end
            if ~obj.IsConvertVolts
                obj.placeholder(ax, ...
                    'Enable "Convert volts?" - the two channels have different Er/V, so their raw difference is meaningless');
                return
            end

            t = res.T * 1e3;   % ms
            V = obj.convert(res.Y(:,2), 2, 'level') - obj.convert(res.Y(:,1), 1, 'level');
            hold(ax,'on');
            plot(ax, t, V, 'Color', [0.35 0.35 0.40], 'LineWidth', 0.5, ...
                'DisplayName','V_{KP} measured');

            % Difference of the two fitted sinusoids, over the mask only.
            if isfinite(res.S) && isfinite(res.Ch(1).F) && isfinite(res.Ch(2).F)
                idx = res.S:res.E;
                tau = res.T(idx) - res.T(1);
                m1 = res.Ch(1).A*cos(2*pi*res.Ch(1).F*tau + res.Ch(1).Phi) + res.Ch(1).Dc;
                m2 = res.Ch(2).A*cos(2*pi*res.Ch(2).F*tau + res.Ch(2).Phi) + res.Ch(2).Dc;
                Vfit = obj.convert(m2,2,'level') - obj.convert(m1,1,'level');
                plot(ax, t(idx), Vfit, '--', 'Color', [0.839 0.153 0.157], ...
                    'LineWidth', 1, 'DisplayName','steady-state fit');
            end

            % Reference levels: the static loading depth and the drive mean.
            vi = obj.at(obj.combinedVi(1:max(runIdx,1)), runIdx);
            v0 = obj.at(obj.combinedV0(1:max(runIdx,1)), runIdx);
            if isfinite(vi)
                yline(ax, vi, ':', 'Color', [0.494 0.318 0.635], 'LineWidth', 1.4, ...
                    'Label', sprintf('V_i = %.1f', vi), 'LabelHorizontalAlignment','left', ...
                    'FontSize', 8.5, 'HandleVisibility','off');
            end
            if isfinite(v0)
                yline(ax, v0, ':', 'Color', [0.180 0.545 0.341], 'LineWidth', 1.4, ...
                    'Label', sprintf('V_0 = %.1f', v0), 'LabelHorizontalAlignment','right', ...
                    'FontSize', 8.5, 'HandleVisibility','off');
            end
            yline(ax, 0, '-', 'Color', obj.CGrid, 'HandleVisibility','off');
            if isfinite(res.S)
                xline(ax, t(res.S), '-', 'Color', obj.CMask, 'LineWidth', 1.6, 'HandleVisibility','off');
                xline(ax, t(res.E), '-', 'Color', obj.CMask, 'LineWidth', 1.6, 'HandleVisibility','off');
            end

            obj.panelTitle(ax, sprintf('Combined lattice  V_KP = Ch2 - Ch1   (sign at V_i gives %s loading)', ...
                obj.inversionState(runIdx)));
            ylabel(ax, obj.unitStr()); xlabel(ax,'Time (ms)');
            obj.tidyLegend(ax); hold(ax,'off');
        end

        function drawChirp(obj, res, nCh, runIdx)
            % Instantaneous frequency against time. For a linear sweep this
            % should be a straight line from the commanded start to the
            % commanded end; curvature or a wrong slope is immediately
            % visible here in a way no scalar metric shows.
            ax = axes(obj.H.InspLayout); %#ok<LAXES>
            ax.Layout.Tile = obj.H.SpecTile;
            ax.Layout.TileSpan = obj.H.SpecSpan;
            obj.H.CombAxes = ax;
            obj.styleAxes(ax);
            hold(ax,'on');

            drew = false;
            for k = 1:nCh
                c = res.Ch(k);
                if isempty(c.FInst), continue; end
                tt = (c.FInstT + res.T(res.S) - res.T(1)) * 1e3;
                nn = min(numel(tt), numel(c.FInst));
                plot(ax, tt(1:nn), c.FInst(1:nn)/1e3, '.', ...
                    'Color', obj.ChColor(min(k,4),:), 'MarkerSize', 3, ...
                    'DisplayName', sprintf('Ch %d measured', k));
                if isfinite(c.F) && isfinite(c.ChirpRate)
                    fline = (c.F + c.ChirpRate*c.FInstT(1:nn))/1e3;
                    plot(ax, tt(1:nn), fline, '-', 'Color', obj.ChColor(min(k,4),:)*0.45, ...
                        'LineWidth', 1.8, 'DisplayName', sprintf('Ch %d fit', k));
                end
                drew = true;
            end
            if ~drew
                if ~obj.IsChirp
                    msg = 'Chirp mode is off - tick "Chirp signal?" so the sweep estimator runs';
                elseif ~isfinite(res.S)
                    msg = 'No modulation window was found in this run';
                else
                    msg = 'Sweep fit failed: too few valid samples (check the trigger captured the whole burst)';
                end
                obj.placeholder(ax, msg);
                return
            end

            f1 = obj.at(obj.FreqExpected, runIdx);
            f2 = obj.at(obj.FreqExpectedEnd, runIdx);
            for v = [f1 f2]
                if isfinite(v)
                    yline(ax, v/1e3, '--', 'Color', obj.CMask, 'LineWidth', 1.2, ...
                        'Label', sprintf('%.3f kHz', v/1e3), 'FontSize', 8.5, ...
                        'HandleVisibility','off');
                end
            end
            obj.panelTitle(ax,'Chirp instantaneous frequency (dashed red = commanded start / end)');
            ylabel(ax,'Frequency (kHz)'); xlabel(ax,'Time (ms)');
            obj.tidyLegend(ax); hold(ax,'off');
        end

        function drawSpectra(obj, res, nCh, f0)
            % Channels get their own row: overlaying them hides Ch1 whenever
            % Ch2 is larger. X limits and ticks are shared, and the ticks are
            % placed on harmonics of the fundamental so the grid lines
            % themselves mark where peaks are expected.
            % The spectrum is only meaningful below Nyquist (Fs/2); anything
            % above it is an alias of something below. The span shown is
            % whichever is smaller: enough room for NHarmonics harmonics of the
            % fundamental, or the Nyquist limit itself.
            fNyq = res.Fs/2;
            if isfinite(f0) && f0 > 0
                fTop = min(fNyq, (obj.NHarmonics + 1) * f0);
            else
                fTop = fNyq;
            end
            [scale, unitStr] = ModulationMonitor.freqAxisUnit(fTop);

            obj.H.SpecLayout = tiledlayout(obj.H.InspLayout, nCh, 1, ...
                'TileSpacing','none','Padding','none');
            obj.H.SpecLayout.Layout.Tile = obj.H.SpecTile;
            obj.H.SpecLayout.Layout.TileSpan = obj.H.SpecSpan;

            axList = gobjects(1,nCh);
            for k = 1:nCh
                ax = nexttile(obj.H.SpecLayout);
                obj.styleAxes(ax);
                axList(k) = ax;
                c = res.Ch(k);
                if ~isempty(c.SpecDb)
                    sel = c.SpecF <= fTop;
                    if any(sel)
                        plot(ax, c.SpecF(sel)/scale, c.SpecDb(sel), ...
                            'Color', obj.ChColor(min(k,4),:), 'LineWidth', 0.6);
                    end
                end
                xlim(ax,[0 fTop/scale]);   % round tick values, chosen automatically
                ylim(ax,[-120 5]);
                ax.YTick = [-100 -50 0];
                ax.XGrid = 'on'; ax.YGrid = 'on';
                ax.GridColor = obj.CMuted; ax.GridAlpha = 0.35;
                ylabel(ax, sprintf('Ch %d (dB)', k));
                if k < nCh
                    ax.XTickLabel = [];
                else
                    xlabel(ax, sprintf('Frequency (%s)', unitStr));
                end
                if k == 1
                    obj.panelTitle(ax,'Spectrum of masked scope trace, dB below fundamental');
                end
            end
            if nCh > 1
                linkaxes(axList,'x');
            end
        end

        function f = referenceFreq(~, res)
            % Frequency used to set up the cycle view and the spectrum span.
            f = NaN;
            for k = 1:numel(res.Ch)
                if isfinite(res.Ch(k).F) && res.Ch(k).F > 0
                    f = res.Ch(k).F;
                    return
                end
            end
        end

        function s = inspectorHeader(obj, res, runIdx, nCh)
            % Line 1: run conditions. The run number itself is omitted, since
            % the selector directly above already shows it.
            lines = {obj.pipeLine({ ...
                sprintf('%s = %s', obj.varLabel(obj.ExpectedFrequencyVar), ...
                    ModulationMonitor.fmtEng(obj.at(obj.FreqExpected,runIdx),'Hz')), ...
                sprintf('%s = %s', obj.varLabel(obj.depthVarName()), ...
                    ModulationMonitor.fmtVal(obj.at(obj.DepthSet,runIdx))), ...
                sprintf('sample rate = %s', ModulationMonitor.fmtEng(res.Fs,'Sa/s')), ...
                sprintf('measured mod time = %s', ModulationMonitor.fmtEng(res.ModTime,'s'))})};

            % One line per channel, so the channel name is written once.
            u = obj.unitStr();
            for k = 1:nCh
                c = res.Ch(k);
                items = { ...
                    sprintf('Vpp = %s %s', ModulationMonitor.fmtNum(obj.convert(2*c.A,k,'delta'),'%.4f'), u), ...
                    sprintf('Vdc = %s %s', ModulationMonitor.fmtNum(obj.convert(c.Dc,k,'level'),'%.4f'), u), ...
                    sprintf('f = %s', ModulationMonitor.fmtEng(c.F,'Hz')), ...
                    sprintf('THD = %s', ModulationMonitor.fmtNum(c.Thd,'%.1f dBc'))};
                if isfinite(c.DcStep)
                    items{end+1} = sprintf('%sVdc = %s %s', char(916), ...
                        ModulationMonitor.fmtNum(obj.convert(c.DcStep,k,'delta'),'%+.4f'), u); %#ok<AGROW>
                end
                lines{end+1} = sprintf('Ch%d:  %s', k, obj.pipeLine(items)); %#ok<AGROW>
            end

            pe = obj.at(obj.PhaseErr, runIdx);
            if isfinite(pe)
                lines{end+1} = obj.pipeLine({sprintf('phase error = %+.2f deg', pe)});
            end
            s = strjoin(lines, char(10));
        end

        function nav = buildRunNav(obj, tab, withMaskControls)
            % Run selector, plus (Inspector only) the manual mask nudge.
            if nargin < 3, withMaskControls = false; end
            pnl = uipanel(tab,'Units','normalized','Position',[0 0.93 1 0.07],...
                'BorderType','none','BackgroundColor','w');
            uicontrol(pnl,'Style','text','Units','normalized','Position',[0.008 0.18 0.03 0.6],...
                'String','Run','BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',10);
            nav.Edit = uicontrol(pnl,'Style','edit','Units','normalized',...
                'Position',[0.04 0.15 0.05 0.65],'String','1','FontSize',10,...
                'Callback',@(s,~) obj.setInspectorRun(str2double(s.String)));
            uicontrol(pnl,'Style','pushbutton','Units','normalized',...
                'Position',[0.095 0.15 0.03 0.65],'String','<','FontSize',10,...
                'Callback',@(~,~) obj.setInspectorRun(obj.InspectorRun - 1));
            uicontrol(pnl,'Style','pushbutton','Units','normalized',...
                'Position',[0.128 0.15 0.03 0.65],'String','>','FontSize',10,...
                'Callback',@(~,~) obj.setInspectorRun(obj.InspectorRun + 1));
            nav.Panel = pnl;
            if ~withMaskControls
                return
            end

            uicontrol(pnl,'Style','text','Units','normalized',...
                'Position',[0.175 0.22 0.085 0.52],'String','Nudge mask (us)',...
                'BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',9);
            uicontrol(pnl,'Style','text','Units','normalized',...
                'Position',[0.262 0.22 0.028 0.52],'String','start',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','right','FontSize',9);
            nav.StartEdit = uicontrol(pnl,'Style','edit','Units','normalized',...
                'Position',[0.293 0.22 0.032 0.55],'String','0',...
                'FontSize',9,'Callback',@(s,~) obj.onMaskOffset(s,'start'));
            uicontrol(pnl,'Style','text','Units','normalized',...
                'Position',[0.330 0.22 0.024 0.52],'String','end',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','right','FontSize',9);
            nav.EndEdit = uicontrol(pnl,'Style','edit','Units','normalized',...
                'Position',[0.357 0.22 0.032 0.55],'String','0',...
                'FontSize',9,'Callback',@(s,~) obj.onMaskOffset(s,'end'));
            uicontrol(pnl,'Style','pushbutton','Units','normalized',...
                'Position',[0.396 0.22 0.075 0.55],'String','Copy to all',...
                'FontSize',9,'Callback',@(~,~) obj.copyNudgeToAll());
            uicontrol(pnl,'Style','pushbutton','Units','normalized',...
                'Position',[0.475 0.22 0.055 0.55],'String','Clear all',...
                'FontSize',9,'Callback',@(~,~) obj.clearNudges());
            uicontrol(pnl,'Style','text','Units','normalized',...
                'Position',[0.540 0.22 0.055 0.52],'String','Bottom',...
                'BackgroundColor','w','ForegroundColor',obj.CInk,...
                'HorizontalAlignment','left','FontSize',9);
            uicontrol(pnl,'Style','popupmenu','Units','normalized',...
                'Position',[0.592 0.22 0.115 0.55],'FontSize',9,...
                'String',{'Spectrum','Combined lattice','Chirp f(t)'},...
                'Value',min(max(round(obj.InspectorBottom),1),3),...
                'Callback',@(s,~) obj.onInspectorBottom(s));
            uicontrol(pnl,'Style','text','Units','normalized',...
                'Position',[0.715 0.22 0.28 0.52],...
                'String','Mask offsets apply to this run only (+ = later).',...
                'BackgroundColor','w','ForegroundColor',obj.CMuted,...
                'HorizontalAlignment','left','FontSize',8.5);
        end

        function onMaskOffset(obj, src, which)
            % Offsets belong to the run currently in the Inspector.
            v = str2double(src.String);
            if ~isfinite(v)
                v = 0;
                src.String = '0';
            end
            off = obj.nudgeFor(obj.InspectorRun);
            if strcmp(which,'start')
                off(1) = v;
            else
                off(2) = v;
            end
            obj.setNudge(obj.InspectorRun, off(1), off(2));
            obj.DirtyTabs(5) = true;
            obj.DirtyTabs(6) = true;
            obj.drawSelectedTab();
        end

        function syncNudgeControls(obj)
            % Called whenever the Inspector run changes, so the boxes always
            % show the offsets belonging to the run on screen.
            if ~isfield(obj.H,'InspNav') || ~isfield(obj.H.InspNav,'StartEdit')
                return
            end
            if ~isgraphics(obj.H.InspNav.StartEdit)
                return
            end
            off = obj.nudgeFor(obj.InspectorRun);
            obj.H.InspNav.StartEdit.String = num2str(off(1));
            obj.H.InspNav.EndEdit.String   = num2str(off(2));
        end

        function copyNudgeToAll(obj)
            % Give every run the offsets of the run on screen, then re-measure.
            n = obj.lastRun();
            if n < 1, return; end
            off = obj.nudgeFor(obj.InspectorRun);
            obj.MaskNudge = repmat(off(:), 1, n);
            obj.reanalyseAll();
        end

        function clearNudges(obj)
            obj.MaskNudge = zeros(2,0);
            obj.syncNudgeControls();
            obj.reanalyseAll();
        end

        function reanalyseAll(obj)
            % The other tabs read metrics stored by updateData, so a changed
            % mask only reaches them after every run is measured again. Done
            % on demand because it reloads each trace from disk.
            n = obj.lastRun();
            if n < 1, return; end
            fig = obj.H.Figure;
            oldPtr = get(fig,'Pointer');
            set(fig,'Pointer','watch'); drawnow;
            for r = 1:n
                obj.updateData(r);
            end
            set(fig,'Pointer',oldPtr);
            obj.buildGrid(n);
            obj.DirtyTabs(:) = true;
            obj.drawSelectedTab();
        end

        function onInspectorBottom(obj, src)
            obj.InspectorBottom = src.Value;
            obj.DirtyTabs(6) = true;
            obj.drawSelectedTab();
        end

        function setInspectorRun(obj, runIdx)
            if ~isfinite(runIdx)
                runIdx = obj.InspectorRun;
            end
            runIdx = max(1, min(round(runIdx), max(obj.lastRun(),1)));
            obj.InspectorRun = runIdx;
            obj.syncNudgeControls();   % boxes follow the run, never the reverse
            obj.DirtyTabs(5) = true;   % Basic and Inspector share the run index
            obj.DirtyTabs(6) = true;
            obj.drawSelectedTab();
        end

        function onPick(obj, src, evt)
            % Resolve a click on a map cell / curve point / run marker back to
            % a run index, then jump to the Inspector.
            try
                cp = evt.IntersectionPoint;
            catch
                axTmp = ancestor(src,'axes');
                cp = axTmp.CurrentPoint(1,:);
            end
            ax = ancestor(src,'axes');
            kind = '';
            if isstruct(ax.UserData) && isfield(ax.UserData,'Kind')
                kind = ax.UserData.Kind;
            end
            runIdx = [];
            g = obj.Grid;
            switch kind
                case 'map'
                    ix = round(cp(1)); iy = round(cp(2));
                    tr = isfield(ax.UserData,'Transposed') && ax.UserData.Transposed;
                    if tr
                        % Displayed x is the alpha index, y the frequency
                        % index; CellRuns is stored {alpha, frequency}.
                        if ix >= 1 && ix <= g.Ny && iy >= 1 && iy <= g.Nx
                            runIdx = g.CellRuns{ix,iy};
                        end
                    else
                        if ix >= 1 && ix <= g.Nx && iy >= 1 && iy <= g.Ny
                            runIdx = g.CellRuns{iy,ix};
                        end
                    end
                case 'curve'
                    ud = src.UserData;   % run index per x position
                    if isnumeric(ud) && ~isempty(ud) && isprop(src,'XData')
                        [~, ii] = min(abs(src.XData - cp(1)));
                        if ii >= 1 && ii <= numel(ud)
                            runIdx = ud(ii);
                        end
                    end
                case 'run'
                    runIdx = round(cp(1));
            end
            runIdx = runIdx(isfinite(runIdx));
            if isempty(runIdx)
                return
            end
            obj.InspectorRun = max(1, min(round(runIdx(1)), max(obj.lastRun(),1)));
            obj.syncNudgeControls();
            obj.DirtyTabs(5) = true;
            obj.DirtyTabs(6) = true;
            obj.H.TabGroup.SelectedTab = obj.H.Tab(6);
            obj.drawSelectedTab();
        end
    end

    %% ===================================================================
    %  ANALYSIS
    %  ===================================================================
    methods (Access = protected)
        function res = analyzeRun(obj, runIdx, wantTraces)
            % Full measurement chain for one run. Set wantTraces to keep the
            % raw samples in the result (the Inspector needs them; the metric
            % update does not).
            if nargin < 3, wantTraces = false; end
            res = struct('Ok',false,'T',[],'Y',[],'S',NaN,'E',NaN,...
                'Fs',NaN,'ModTime',NaN,'RawDuration',NaN,'TrueDuration',NaN,...
                'MaskClipped',false,'ClipStart',false,'ClipEnd',false,...
                'Ch',ModulationMonitor.emptyChan());

            [t, Y, ok] = obj.loadTrace(runIdx);
            if ~ok
                return
            end

            % Step 1: timebase. Must happen before anything spectral, since
            % every measured frequency scales directly with Fs.
            [t, Fs, rawDur, trueDur] = obj.correctTimebase(t);
            res.T = t; res.Fs = Fs;
            res.RawDuration = rawDur; res.TrueDuration = trueDur;

            % Step 2: modulation window, shared across channels.
            fSet = obj.readVar(obj.ExpectedFrequencyVar, runIdx);
            fEndSet = obj.readVar(obj.ChirpEndFreqVar, runIdx);
            [s, e, mok, clipped] = obj.detectModulation(Y, Fs, fSet, runIdx);
            if ~mok
                return
            end
            res.S = s; res.E = e;
            res.MaskClipped = any(clipped);
            res.ClipStart = clipped(1);
            res.ClipEnd   = clipped(2);

            res.ModTime = t(e) - t(s);

            % Step 3: per-channel fits, all referred to the record origin so
            % relative phase is meaningful.
            tau = t(s:e) - t(1);
            nCh = size(Y,2);
            % Static level just before modulation, and the dark level after
            % it. The difference between the in-burst mean and the static
            % level is the quantity the atoms actually care about: a
            % nonlinear AOM rectifies the drive and shifts the mean lattice
            % depth away from its statically calibrated value.
            [vPre, vDark] = obj.baselineLevels(Y, s, e, Fs, fSet, clipped(1));
            chans = ModulationMonitor.emptyChan();
            for k = 1:nCh
                chans(k) = obj.fitChannel(tau, Y(s:e,k), Fs, fSet, fEndSet, wantTraces);
                chans(k).DcPre  = vPre(k);
                chans(k).DcDark = vDark(k);
                chans(k).DcStep = chans(k).Dc - vPre(k);
            end
            res.Ch = chans;

            if wantTraces
                res.Y = Y;
            else
                res.Y = zeros(0, nCh);
            end
            res.Ok = true;
        end

        function [t, Fs, rawTotal, trueTotal] = correctTimebase(obj, t)
            % Rebuild the time axis from what the hardware can actually do.
            %
            % Two independent corrections, both of which scale every measured
            % frequency directly:
            %
            % (a) TIME WINDOW. The scope's horizontal scale is a 1-2-5 ladder,
            %     but MuscleMuseum will accept any requested duration, so the
            %     stored TimeList can describe a capture that never happened.
            %     The window is snapped UP: the scope cannot capture less than
            %     was asked for.
            %
            % (b) MEMORY DEPTH. Fs = nSample / window, so the sample count has
            %     to be the true depth. Records occasionally come back one
            %     sample short (99999 instead of 100000), which is a 10 ppm
            %     error in Fs and therefore a 10 ppm error in every frequency
            %     -- about 20 Hz at 2 MHz, which is far larger than the fit
            %     precision and looks exactly like a real deviation. Depths sit
            %     on a 1-2-5 ladder, so n is snapped to a ladder value when it
            %     is within a tight tolerance, and left alone otherwise.
            t = double(t(:));
            n = numel(t);
            Fs = 1 / (t(2) - t(1));
            % The stored TimeList spans the capture window, so this is the
            % duration to snap. (Do NOT use n*dt here: on a record that is a
            % sample short it overshoots the window by one sample, which is
            % enough to push an exactly-valid setting onto the next rung of
            % the ladder and halve Fs.)
            rawTotal = t(end) - t(1);
            trueTotal = rawTotal;
            if strcmpi(obj.TimebaseSnap,'off') || n < 2
                return
            end

            % (a) snap the window up onto the 1-2-5 ladder
            perDiv = rawTotal / 10;
            dec = 10.^(-9:2);
            valid = sort([dec, 2*dec, 5*dec]);
            % Tolerance is loose enough that floating-point dust on an
            % exactly-valid setting cannot promote it to the next rung; a real
            % request is never within 0.01% of a valid step by accident.
            cand = valid(valid >= perDiv*(1 - 1e-4));
            if isempty(cand)
                return
            end
            trueTotal = cand(1) * 10;

            % (b) snap the sample count to a plausible memory depth
            nTrue = ModulationMonitor.snapMemoryDepth(n, obj.DepthSnapTolerance);

            Fs = nTrue / trueTotal;
            t = (0:n-1).' / Fs;
        end

        function off = nudgeFor(obj, runIdx)
            % [startOffset, endOffset] in microseconds for one run; zeros if
            % that run has never been nudged.
            off = [0 0];
            if runIdx >= 1 && runIdx <= size(obj.MaskNudge,2)
                off = obj.MaskNudge(:,runIdx).';
            end
        end

        function setNudge(obj, runIdx, startUs, endUs)
            % Store a per-run nudge, growing the array as needed.
            if runIdx < 1, return; end
            if size(obj.MaskNudge,2) < runIdx
                obj.MaskNudge(:, end+1:runIdx) = 0;
            end
            obj.MaskNudge(:,runIdx) = [startUs; endUs];
        end

        function [s, e, ok, clipped] = detectModulation(obj, Y, Fs, fSet, runIdx)
            % Envelope + slew detector, returning one window for all channels.
            %
            % Pass 1 uses a wide (several period) moving mean to find WHICH
            % REGION is modulated. That is robust against glitches and slow
            % baseline drift, but smoothing wide enough to be robust also
            % smears the turn-on and turn-off edges by a couple of periods,
            % so its half-maximum crossing lands microseconds outside the
            % true edge.
            %
            % Pass 2 finds WHICH SAMPLE the edge is on, from the derivative,
            % searching only near the coarse edge. The derivative alone is
            % fragile (any glitch sets its threshold); the envelope alone is
            % imprecise. Together they are both robust and sample-accurate.
            % clipped(1) = leading edge missing, clipped(2) = trailing edge
            % missing. They must stay separate: the pre-modulation baseline
            % only needs the LEADING edge, so a burst running off the end of
            % the record does not invalidate it.
            s = NaN; e = NaN; ok = false; clipped = [false false];
            n = size(Y,1);
            if n < 128
                return
            end

            % Window widths from the commanded period when it is available.
            if isfinite(fSet) && fSet > 0
                period = Fs / fSet;
            else
                period = n / 200;
            end
            wCoarse = max(min(round(obj.MaskCoarseCycles*period), floor(n/20)), 16);

            % ---- pass 1: envelope, tells us WHICH REGION ----------------
            envC = ModulationMonitor.acEnvelope(Y, wCoarse);
            % Percentiles, NOT min/max, to set the envelope scale.
            %
            % A turn-on or turn-off ramp is a large step, so it produces a
            % narrow but very tall spike in the AC envelope. With hi=max(env)
            % that spike sets the scale, and when the modulation is shallow
            % (AM spectroscopy runs ~1% depth against a full-amplitude ramp)
            % the half-maximum threshold lands far above the actual burst.
            % The detector then locks onto the ramp instead. A ramp occupies
            % well under 5% of the record, so the 95th percentile ignores it
            % while still tracking the modulated plateau.
            lo = ModulationMonitor.pctile(envC, 5);
            hi = ModulationMonitor.pctile(envC, 95);
            if ~isfinite(hi) || hi <= 0
                return
            end
            if (hi - lo) < 0.2 * hi
                % Modulation fills the record; there is nothing to cut away.
                s = 1; e = n; ok = true; clipped = [true true];
                return
            end
            [sc, ec] = ModulationMonitor.longestRun(envC > lo + obj.MaskFraction*(hi - lo));
            if isnan(sc) || (ec - sc) < 8
                return
            end
            s = sc; e = ec;
            % No baseline before/after means the burst runs past the record.
            % Harmless for the fits (fewer cycles, slightly larger sigma, no
            % bias) but worth reporting, since it usually means a mistrigger.
            clipped = [sc <= 2, ec >= n-1];

            % ---- pass 2: slew rate, tells us WHICH SAMPLE ---------------
            % Turn-on and turn-off are genuine steps and are by far the
            % largest single-sample changes in the record, so the derivative
            % locates them exactly. On its own the derivative is fragile (a
            % glitch anywhere sets the threshold, which is how the original
            % implementation failed); restricting the search to a
            % neighbourhood of the coarse edge removes that failure mode
            % while keeping sample precision. The envelope alone cannot do
            % this: smoothing wide enough to be robust also smears the edge
            % by a couple of periods.
            d = sum(abs(diff(Y,1,1)),2);            % combined step size, all channels
            guard = max(round(obj.MaskEdgeGuardCycles*period), 16);
            interior = max(sc+1,1):min(ec,numel(d));
            if isempty(interior)
                return
            end
            % Modulation slew sets the floor an edge must clearly beat.
            floorLevel = 3 * median(d(interior));

            % Use the FIRST/LAST threshold crossing, not the largest step.
            % Turn-off is a hard gate and its maximum sits exactly on the
            % edge, but turn-on ramps over a few cycles, so its steepest
            % sample is partway up the ramp and argmax lands late. A
            % threshold crossing catches the foot of the ramp instead, and
            % treats both edges the same way.
            iLo = max(sc - guard, 1);
            iHi = min(sc + guard, numel(d));
            if iHi > iLo
                seg = d(iLo:iHi);
                vMax = max(seg);
                if vMax > floorLevel
                    rel = find(seg > obj.MaskEdgeFraction*vMax, 1, 'first');
                    if ~isempty(rel)
                        s = iLo + rel;      % first sample after modulation starts
                    end
                end
            end

            iLo = max(ec - guard, 1);
            iHi = min(ec + guard, numel(d));
            if iHi > iLo
                seg = d(iLo:iHi);
                vMax = max(seg);
                if vMax > floorLevel
                    rel = find(seg > obj.MaskEdgeFraction*vMax, 1, 'last');
                    if ~isempty(rel)
                        e = iLo + rel - 1;  % last sample before modulation stops
                    end
                end
            end
            if e <= s
                s = sc; e = ec;
            end

            % Trim inward so turn-on/turn-off transients never enter the fit.
            trim = round(obj.MaskTrimCycles * period);
            s = s + trim; e = e - trim;

            % Manual nudge for THIS run, in microseconds. Only ModTime
            % depends on the edges at this precision: the fits span hundreds of
            % cycles, so a sub-microsecond shift moves amplitude and phase in
            % the fifth decimal at most.
            off = obj.nudgeFor(runIdx);
            if any(off ~= 0)
                s = s + round(off(1) * 1e-6 * Fs);
                e = e + round(off(2) * 1e-6 * Fs);
                s = max(1, min(s, n-1));
                e = max(2, min(e, n));
            end

            if (e - s) < max(32, 2*period)
                s = NaN; e = NaN;
                return
            end
            ok = true;
        end

        function [vPre, vDark] = baselineLevels(obj, Y, s, e, Fs, fSet, clipStart)
            % Median level in a quiet window before the modulation (beam on,
            % unmodulated) and after it (beam off). Medians rather than means
            % so a stray transient cannot drag the reference.
            n = size(Y,1); nCh = size(Y,2);
            vPre = NaN(1,nCh); vDark = NaN(1,nCh);
            if isfinite(fSet) && fSet > 0
                period = Fs / fSet;
            else
                period = n / 200;
            end
            guard = max(round(2*period), 8);   % keep clear of the edge ramp

            % Pre-modulation window. Only the LEADING edge matters here: a
            % burst that runs off the end of the record still has a perfectly
            % good static region in front of it.
            if ~clipStart
                hi = s - guard;
                lo = max(1, s - guard - round(12*period));
                % At high modulation frequency 'guard' is only a few hundred
                % samples, but at low frequency it can be large; if the burst
                % starts early there may be nothing left in front of it. Fall
                % back to a smaller guard rather than giving up, since even a
                % short pre-modulation window gives a usable median.
                if hi - lo < 20
                    hi = s - max(round(0.5*period), 4);
                    lo = max(1, hi - round(4*period));
                end
                if hi > lo && hi - lo >= 10 && hi >= 1
                    for k = 1:nCh
                        vPre(k) = median(Y(lo:hi,k));
                    end
                end
            end

            % Dark window, taken from the tail of the record.
            lo = min(e + guard, n);
            if n - lo >= 20
                for k = 1:nCh
                    vDark(k) = median(Y(lo:n,k));
                end
            end
        end

        function c = fitChannel(obj, tau, y, Fs, fSet, fEndSet, wantSpec)
            % Measure one channel over the masked segment.
            %
            % The frequency is measured from the data, not assumed from the
            % command. Seeding at the commanded value would make a genuine
            % mismatch invisible: the fit would return ~zero amplitude at a
            % frequency where there is no signal, rather than reporting where
            % the signal actually is.
            % wantSpec: only the Inspector displays the spectrum, and it is a
            % 20*log10 over ~500k points per channel per run. Skipping it for
            % metric updates removes pure waste; no metric depends on it.
            if nargin < 7, wantSpec = false; end
            c = ModulationMonitor.emptyChan();
            y = double(y(:));
            n = numel(y);
            if n < 64
                return
            end
            dc0 = mean(y);
            yac = y - dc0;
            c.Rms = std(yac);

            % --- spectrum ------------------------------------------------
            nPad = 2^nextpow2(n * max(2, obj.ZeroPadFactor));
            w = ModulationMonitor.hannWin(n);
            Yf = fft(yac .* w, nPad);
            half = floor(nPad/2);
            mag = abs(Yf(1:half));
            binHz = Fs / nPad;
            if wantSpec
                c.SpecF = (0:half-1).' * binHz;
            end

            % --- chirp: a swept tone needs a different estimator ---------
            % Must come before the fixed-tone peak logic below: for a sweep
            % the spectrum is a broad band, so a single peak is meaningless.
            if obj.IsChirp
                c = obj.fitChirp(c, tau, y, Fs, fSet, fEndSet, wantSpec);
                return
            end

            % --- peak search, floored at MinCyclesInMask -----------------
            % A rectangular-ish burst inside a longer record has a large
            % low-frequency lobe from its own envelope. Requiring at least a
            % few cycles inside the mask puts that lobe below the search
            % floor, so it can never be mistaken for the carrier.
            fMin = obj.MinCyclesInMask * Fs / n;
            iLo = max(2, floor(fMin/binHz) + 1);
            iHi = min(half, floor(0.45*Fs/binHz));
            if iHi <= iLo
                return
            end
            [pkMag, rel] = max(mag(iLo:iHi));
            pk = iLo + rel - 1;
            f0 = obj.parabolicRefine(mag, pk, Fs, nPad);

            % --- sub-harmonic check --------------------------------------
            % With strong distortion the tallest line can be a harmonic. If
            % there is appreciable power at f0/2 or f0/3 (and it is still
            % above the search floor), that is the real fundamental.
            halfW = max(4, ceil(4*nPad/n));
            for d = [2 3]
                fs = f0 / d;
                if fs < fMin, continue; end
                pSub = ModulationMonitor.bandPower(mag, fs/binHz + 1, halfW);
                pPk  = ModulationMonitor.bandPower(mag, f0/binHz + 1, halfW);
                if pPk > 0 && pSub / pPk > obj.SubharmonicRatio^2
                    f0 = fs;
                    break
                end
            end
            if ~isfinite(f0) || f0 <= 0
                return
            end
            c.FSeed = f0;

            % --- stage A: three-parameter fit at the measured frequency ---
            % Linear in (a, b, c) and therefore always well posed. This is
            % what guarantees amplitude and phase survive even if the
            % frequency refinement below fails.
            [A, phi, dc, okA] = ModulationMonitor.linearSineFit(tau, y, f0);
            if ~okA
                return
            end
            c.A = A; c.Phi = phi; c.Dc = dc; c.F = f0;

            % --- stage B: four-parameter refinement ----------------------
            [fB, AB, phiB, dcB, okB] = obj.refineFrequency(tau, y, f0);
            if okB && abs(fB - f0) <= obj.FreqTolerance * f0
                c.F = fB; c.A = AB; c.Phi = phiB; c.Dc = dcB;
            end

            if wantSpec
                c.SpecDb = 20*log10(max(mag,eps) / max(pkMag,eps));
            end
            c.Thd = obj.harmonicPower(mag, Fs, nPad, n, c.F);
        end

        function c = fitChirp(obj, c, tau, y, Fs, fSet, fEndSet, wantSpec)
            % Linear chirp:  psi(t) = 2*pi*(f0*tau + k/2*tau^2)
            %
            % SEEDING. The commanded start and end frequencies are used when
            % available, NOT the measured instantaneous frequency.
            % Instantaneous frequency is d(phase)/dt, and differentiating
            % phase amplifies noise: at the ~1% modulation depth typical of
            % AM spectroscopy the per-sample phase error is a good fraction
            % of a radian, which turns into megahertz of scatter. A straight
            % line through that is meaningless, and the amplitude then
            % collapses to zero because the fit is evaluated where there is
            % no signal. The command is exact by construction and costs
            % nothing, so it is the right seed; the measured instantaneous
            % frequency is kept only as a fallback and for display.
            n = numel(y);
            dc0 = mean(y); yac = y - dc0;
            T = tau(end) - tau(1);
            if T <= 0
                return
            end

            % Instantaneous frequency, smoothed. Kept for the Chirp f(t)
            % panel; raw d(phase)/dt is unreadable at low SNR.
            if nargin < 8, wantSpec = false; end
            needInst = wantSpec || ~(isfinite(fSet) && fSet > 0);
            if needInst
                fi = ModulationMonitor.instFreq(yac, Fs);
            else
                fi = [];
            end
            fRef = fSet;
            if ~isfinite(fRef) || fRef <= 0, fRef = Fs/50; end
            wSm = max(round(Fs/fRef * obj.ChirpSmoothCycles), 8);
            if needInst
                wSm = min(wSm, max(floor(numel(fi)/8),8));
                c.FInst = movmean(fi, wSm);
                c.FInstT = tau(1:numel(c.FInst));
            end

            % --- seed ---------------------------------------------------
            if isfinite(fSet) && fSet > 0 && isfinite(fEndSet) && fEndSet > 0
                f0 = fSet;
                k0 = (fEndSet - fSet) / T;          % exact, from the command
            elseif isfinite(fSet) && fSet > 0
                f0 = fSet; k0 = 0;                  % start known, sweep unknown
            else
                % Last resort: fit the smoothed instantaneous frequency.
                m = numel(c.FInst);
                lo = max(round(0.1*m),2); hi = min(round(0.9*m),m);
                tt = tau(lo:hi); ff = c.FInst(lo:hi);
                good = isfinite(ff) & ff > 0 & ff < 0.45*Fs;
                if nnz(good) >= 32
                    med = median(ff(good));
                    sd = 1.4826 * median(abs(ff(good) - med));
                    if isfinite(sd) && sd > 0
                        good = good & abs(ff - med) < 6*sd;
                    end
                end
                if nnz(good) < 32
                    return
                end
                pl = polyfit(tt(good), ff(good), 1);
                k0 = pl(1); f0 = polyval(pl, 0);
            end
            if ~isfinite(f0) || f0 <= 0 || f0 >= 0.45*Fs
                return
            end
            c.FSeed = f0;

            % --- Gauss-Newton on (f0, k) --------------------------------
            f = f0; k = k0; one = ones(n,1);
            for it = 1:obj.MaxFitIter %#ok<NASGU>
                psi = 2*pi*(f*tau + 0.5*k*tau.^2);
                cs = cos(psi); sn = sin(psi);
                p = [cs, sn, one] \ y;
                if any(~isfinite(p)), break; end
                a = p(1); b = p(2);
                g = -a*sn + b*cs;
                D = [cs, sn, one, 2*pi*tau.*g, pi*(tau.^2).*g];
                q = D \ y;
                if ~all(isfinite(q)), break; end
                df = max(min(q(4), 0.02*max(f,1)), -0.02*max(f,1));
                f = f + df;
                dk = q(5);
                lim = max(abs(k0), abs(f)/T) * 0.2;
                if lim > 0, dk = max(min(dk, lim), -lim); end
                k = k + dk;
                if ~isfinite(f) || f <= 0, break; end
                if abs(df) < 1e-8*max(f,1), break; end
            end

            % Reject a refinement that wandered far from the command.
            if isfinite(fSet) && fSet > 0 && abs(f - fSet) > obj.FreqTolerance*fSet
                f = f0; k = k0;
            end

            psi = 2*pi*(f*tau + 0.5*k*tau.^2);
            p = [cos(psi), sin(psi), one] \ y;
            if any(~isfinite(p)), return; end
            c.A = hypot(p(1), p(2));
            c.Phi = atan2(-p(2), p(1));
            c.Dc = p(3);
            c.F = f;
            c.ChirpRate = k;
            c.FEnd = f + k*T;
            % THD is meaningless for a swept tone: the harmonics sweep too.
        end

        function [f, A, phi, dc, ok] = refineFrequency(obj, tau, y, f0)
            % IEEE-1057 four-parameter sine fit: Gauss-Newton on frequency
            % with the linear parameters re-solved at every step. The step is
            % clamped so a poor seed cannot throw the frequency away.
            f = f0;
            n = numel(y); one = ones(n,1);
            for it = 1:obj.MaxFitIter %#ok<NASGU>
                w = 2*pi*f;
                cs = cos(w*tau); sn = sin(w*tau);
                p = [cs, sn, one] \ y;
                if any(~isfinite(p))
                    A = NaN; phi = NaN; dc = NaN; ok = false;
                    return
                end
                a = p(1); b = p(2);
                % Fourth column is d(model)/df, giving the frequency update.
                q = [cs, sn, one, 2*pi*tau.*(-a*sn + b*cs)] \ y;
                if ~isfinite(q(4)), break; end
                step = q(4);
                lim = 0.05 * max(f,1);
                step = max(min(step, lim), -lim);
                fNew = f + step;
                if ~isfinite(fNew) || fNew <= 0, break; end
                f = fNew;
                if abs(step) < 1e-10 * max(f,1), break; end
            end
            [A, phi, dc, ok] = ModulationMonitor.linearSineFit(tau, y, f);
            ok = ok && isfinite(f) && f > 0;
        end

        function val = harmonicPower(obj, mag, Fs, nPad, n, f0)
            % Power in harmonics 2..N relative to the fundamental, in dB.
            % A positive result is physically impossible for a real signal and
            % therefore flags that the "fundamental" is misidentified.
            val = NaN;
            if ~isfinite(f0) || f0 <= 0
                return
            end
            binHz = Fs / nPad;
            halfW = max(4, ceil(4 * nPad / n));   % Hann main lobe, in bins
            pFund = ModulationMonitor.bandPower(mag, f0/binHz + 1, halfW);
            if ~(pFund > 0)
                return
            end
            pHarm = 0;
            for k = 2:obj.NHarmonics
                fk = k*f0;
                if fk >= 0.49*Fs, break; end
                pHarm = pHarm + ModulationMonitor.bandPower(mag, fk/binHz + 1, halfW);
            end
            if pHarm <= 0
                val = -Inf;
            else
                val = 10*log10(pHarm / pFund);
            end
        end

        function [t, Y, ok] = loadTrace(obj, runIdx)
            % Y is nSample x nChannel. Live data comes from becExp.ScopeData;
            % otherwise the run's .mat is reloaded from the hardware log.
            t = []; Y = []; ok = false;
            becExp = obj.BecExp;

            if obj.CacheTraces && numel(obj.TraceCache) >= runIdx && ~isempty(obj.TraceCache{runIdx})
                c = obj.TraceCache{runIdx};
                t = c.T; Y = c.Y; ok = true;
                return
            end

            try
                if isprop(becExp,'ScopeData') && numel(becExp.ScopeData) >= runIdx
                    sd = becExp.ScopeData(runIdx);
                    if isfield(sd,'Time') && ~isempty(sd.Time)
                        t = double(sd.Time(:));
                        cols = {};
                        for k = 1:obj.MaxChannel
                            fn = sprintf('Volt%d', k);
                            if isfield(sd, fn) && ~isempty(sd.(fn)) && numel(sd.(fn)) == numel(t)
                                cols{end+1} = double(sd.(fn)(:)); %#ok<AGROW>
                            end
                        end
                        if ~isempty(cols)
                            Y = cat(2, cols{:});
                            ok = numel(t) > 128;
                        end
                    end
                end
            catch
                ok = false;
            end

            if ~ok
                try
                    filePath = fullfile(becExp.HardwareLogPath, ...
                        becExp.DataPrefix + "_" + num2str(runIdx) + "_" + obj.ScopeName + ".mat");
                    if isfile(filePath)
                        tmp = load(filePath);
                        fn = fieldnames(tmp);
                        sObj = tmp.(fn{1});
                        t = double(sObj.TimeList(:));
                        nAvail = min(size(sObj.Sample,1), obj.MaxChannel);
                        if nAvail >= 1 && size(sObj.Sample,2) == numel(t)
                            Y = double(sObj.Sample(1:nAvail,:)).';
                            ok = numel(t) > 128;
                        end
                    end
                catch
                    ok = false;
                end
            end

            % Drop disabled / dead channels so they do not appear as columns
            % of zeros in the plots.
            if ok
                keep = false(1, size(Y,2));
                for k = 1:size(Y,2)
                    col = Y(:,k);
                    col = col(isfinite(col));
                    keep(k) = ~isempty(col) && std(col) > 0;
                end
                if ~any(keep)
                    ok = false;
                else
                    Y = Y(:, keep);
                end
            end
            if ok && obj.CacheTraces
                obj.TraceCache{runIdx} = struct('T',t,'Y',Y);
            end
        end
    end

    %% ===================================================================
    %  Scan grid and bookkeeping
    %  ===================================================================
    methods (Access = protected)
        function buildGrid(obj, runIdx)
            % Map runs onto (frequency x depth) cells. Grows live as new scan
            % values appear, and degrades to 1D when only one variable moves.
            runs = 1:max(runIdx,1);
            g = ModulationMonitor.emptyGrid();
            fName = obj.ExpectedFrequencyVar;
            dName = obj.depthVarName();

            fv = obj.padTo(obj.FreqExpected, runs);
            dv = obj.padTo(obj.DepthSet, runs);
            xVals = unique(fv(isfinite(fv)));
            yVals = unique(dv(isfinite(dv)));

            if isempty(xVals) && isempty(yVals)
                obj.Grid = g;
                return
            end

            if numel(xVals) > 1 && numel(yVals) > 1
                g.Is2D = true;
                g.XValues = xVals(:).'; g.YValues = yVals(:).';
                g.XName = char(fName); g.YName = char(dName);
                g.Nx = numel(xVals); g.Ny = numel(yVals);
                g.CellRuns = cell(g.Ny, g.Nx);
                for r = runs
                    ix = find(g.XValues == fv(r), 1);
                    iy = find(g.YValues == dv(r), 1);
                    if ~isempty(ix) && ~isempty(iy)
                        g.CellRuns{iy,ix}(end+1) = r;   % repeats accumulate
                    end
                end
            else
                if numel(xVals) >= numel(yVals)
                    vals = xVals; vec = fv; nameStr = char(fName);
                else
                    vals = yVals; vec = dv; nameStr = char(dName);
                end
                g.Is2D = false;
                g.XValues = vals(:).'; g.YValues = 1;
                g.XName = nameStr; g.YName = '';
                g.Nx = numel(vals); g.Ny = 1;
                g.CellRuns = cell(1, g.Nx);
                for r = runs
                    ix = find(g.XValues == vec(r), 1);
                    if ~isempty(ix)
                        g.CellRuns{ix}(end+1) = r;
                    end
                end
            end
            % Run-number strings for the data tips. Built once here rather
            % than inside every panel: six panels x a large grid would mean
            % thousands of redundant strjoin calls per redraw.
            if g.Is2D
                g.CellRunStr = repmat("", g.Ny, g.Nx);
                for iy = 1:g.Ny
                    for ix = 1:g.Nx
                        rr = g.CellRuns{iy,ix};
                        if isempty(rr)
                            g.CellRunStr(iy,ix) = "none";
                        else
                            g.CellRunStr(iy,ix) = strjoin(string(rr), ', ');
                        end
                    end
                end
            else
                g.CellRunStr = repmat("", 1, g.Nx);
                for ix = 1:g.Nx
                    rr = g.CellRuns{ix};
                    if isempty(rr)
                        g.CellRunStr(ix) = "none";
                    else
                        g.CellRunStr(ix) = strjoin(string(rr), ', ');
                    end
                end
            end
            g.XLabels = arrayfun(@(v) ModulationMonitor.fmtVal(v), g.XValues, 'UniformOutput', false);
            g.YLabels = arrayfun(@(v) ModulationMonitor.fmtVal(v), g.YValues, 'UniformOutput', false);
            g.Valid = g.Nx >= 1;
            obj.Grid = g;
        end

        function M = gridify(obj, metric, runs)
            g = obj.Grid;
            metric = obj.padTo(metric, runs);
            if g.Is2D
                M = NaN(g.Ny, g.Nx);
                for iy = 1:g.Ny
                    for ix = 1:g.Nx
                        M(iy,ix) = ModulationMonitor.cellMean(metric, g.CellRuns{iy,ix});
                    end
                end
            else
                M = NaN(1, g.Nx);
                for ix = 1:g.Nx
                    M(ix) = ModulationMonitor.cellMean(metric, g.CellRuns{ix});
                end
            end
        end

        function err = repeatErrPerRun(obj, data, runs)
            % Timeline plots individual runs, so a run has no error bar of its
            % own. What is meaningful is the scatter among the repeats of the
            % scan point that run belongs to, assigned back to every run in
            % that cell. Points with no repeats stay NaN and draw no bar.
            err = NaN(1, numel(runs));
            g = obj.Grid;
            if ~g.Valid || isempty(g.CellRuns)
                return
            end
            for ii = 1:numel(g.CellRuns)
                r = g.CellRuns{ii};
                if numel(r) < 2, continue; end
                r = r(r >= 1 & r <= numel(data));
                v = data(r); v = v(isfinite(v));
                if numel(v) < 2, continue; end
                sd = std(v);
                idx = r(r <= numel(err));
                err(idx) = sd;
            end
        end

        function r = firstRunPerCell(obj)
            g = obj.Grid;
            r = NaN(1, g.Nx);
            for ix = 1:g.Nx
                c = g.CellRuns{ix};
                if ~isempty(c), r(ix) = c(1); end
            end
        end

        function resetRun(obj, runIdx)
            obj.PhaseErr(runIdx) = NaN;
            obj.FreqExpected(runIdx) = NaN;
            obj.DepthSet(runIdx) = NaN;
            obj.V0Expected(runIdx) = NaN;
            obj.FreqExpectedEnd(runIdx) = NaN;
            obj.AlphaSet(runIdx) = NaN;
            obj.ModTime(runIdx) = NaN;
            obj.SampleRate(runIdx) = NaN;
            obj.RawDuration(runIdx) = NaN;
            obj.TrueDuration(runIdx) = NaN;
            obj.MaskClipped(runIdx) = false;
            obj.ClipStart(runIdx) = false;
            obj.ClipEnd(runIdx) = false;
            if obj.NChannel > 0
                obj.growChannels(obj.NChannel, runIdx);
                obj.Vpp(:,runIdx) = NaN; obj.Vrms(:,runIdx) = NaN;
                obj.Dc(:,runIdx) = NaN;  obj.Freq(:,runIdx) = NaN;
                obj.Thd(:,runIdx) = NaN; obj.DcStep(:,runIdx) = NaN;
                obj.FreqEnd(:,runIdx) = NaN; obj.ChirpRate(:,runIdx) = NaN;
                obj.DcPre(:,runIdx) = NaN; obj.DcDark(:,runIdx) = NaN;
            end
        end

        function growChannels(obj, nCh, runIdx)
            % Grow in chunks. Reallocating on every run turns a refresh over
            % N runs into O(N^2) copying; doubling makes it amortised O(N).
            nChNew = max(nCh, obj.NChannel);
            have = size(obj.Vpp,2);
            if runIdx <= have && nChNew == size(obj.Vpp,1)
                obj.NChannel = nChNew;
                return
            end
            nRun = max(runIdx, max(2*have, 64));
            if nChNew ~= size(obj.Vpp,1) || nRun ~= size(obj.Vpp,2)
                obj.Vpp  = ModulationMonitor.growMat(obj.Vpp,  nChNew, nRun);
                obj.Vrms = ModulationMonitor.growMat(obj.Vrms, nChNew, nRun);
                obj.Dc   = ModulationMonitor.growMat(obj.Dc,   nChNew, nRun);
                obj.Freq = ModulationMonitor.growMat(obj.Freq, nChNew, nRun);
                obj.Thd  = ModulationMonitor.growMat(obj.Thd,  nChNew, nRun);
                obj.DcStep = ModulationMonitor.growMat(obj.DcStep, nChNew, nRun);
                obj.DcPre  = ModulationMonitor.growMat(obj.DcPre,  nChNew, nRun);
                obj.DcDark = ModulationMonitor.growMat(obj.DcDark, nChNew, nRun);
                obj.FreqEnd  = ModulationMonitor.growMat(obj.FreqEnd,  nChNew, nRun);
                obj.ChirpRate= ModulationMonitor.growMat(obj.ChirpRate,nChNew, nRun);
            end
            obj.NChannel = nChNew;
        end

        function name = depthVarName(obj)
            % Whichever scan variable is not the frequency variable.
            if strlength(obj.DepthVar) > 0
                name = obj.DepthVar;
                return
            end
            name = "";
            cand = string.empty;
            for f = ["ScannedVariable","ScannedVariable2"]
                try
                    if isprop(obj.BecExp, f) && strlength(obj.BecExp.(f)) > 0
                        cand(end+1) = obj.BecExp.(f); %#ok<AGROW>
                    end
                catch
                end
            end
            cand = cand(cand ~= obj.ExpectedFrequencyVar);
            if ~isempty(cand)
                name = cand(1);
            end
        end

        function v = readVar(obj, varName, runIdx)
            v = NaN;
            if strlength(varName) == 0, return; end
            try
                d = obj.BecExp.HardwareData.(varName);
                if numel(d) >= runIdx
                    v = double(d(runIdx));
                end
            catch
            end
        end

        %% ---- Combined lattice ------------------------------------------
        % The two beams form a single Kapitza-Pendulum lattice. Writing
        % s = sin(wt+phi), the roadmap's two lattices are
        %   U1(t) = (a/2)V0 (1 - b s)                     [KP1, Ch 1]
        %   U2(t) = (1+a/2)V0 (1 + a/(2+a) b s)           [KP2, Ch 2]
        % and the coefficient of cos^2(kx) in their sum is
        %   V_KP(t) = U2 - U1 = V0 [1 + a b s].
        % So the physically meaningful lattice is the DIFFERENCE of the two
        % channels, not either one alone. Three consequences, all used below:
        %   V0 = mean(Ch2) - mean(Ch1)
        %   A1 = A2 exactly  (the (2+a) factors cancel) -> a balance check
        %   a*b = (A1 + A2) / V0
        % NOTE: V0 is a ~5% difference of two ~175 Er levels, so it amplifies
        % any per-channel calibration error by roughly 20x. Treat the
        % absolute value with more caution than the run-to-run variation.

        function v = combinedV0(obj, runs)
            % Mean combined depth during modulation.
            v = obj.convert(obj.row(obj.Dc,2,runs), 2, 'level') ...
              - obj.convert(obj.row(obj.Dc,1,runs), 1, 'level');
        end

        function v = combinedVi(obj, runs)
            % Static combined depth before modulation starts. Its SIGN is the
            % inverted / non-inverted loading flag.
            v = obj.convert(obj.row(obj.DcPre,2,runs), 2, 'level') ...
              - obj.convert(obj.row(obj.DcPre,1,runs), 1, 'level');
        end

        function [v, aSum] = combinedAlphaBeta(obj, runs)
            % Drive strength actually delivered, a*b = (A1+A2)/V0.
            a1 = obj.convert(obj.row(obj.Vpp,1,runs)/2, 1, 'delta');
            a2 = obj.convert(obj.row(obj.Vpp,2,runs)/2, 2, 'delta');
            aSum = a1 + a2;
            v0 = obj.combinedV0(runs);
            v = aSum ./ v0;
            v(~isfinite(v)) = NaN;
        end

        function v = combinedBalance(obj, runs)
            % (A2-A1) as a percentage of their mean. Theory says exactly 0;
            % any offset is a real imbalance in the delivered drive.
            a1 = obj.convert(obj.row(obj.Vpp,1,runs)/2, 1, 'delta');
            a2 = obj.convert(obj.row(obj.Vpp,2,runs)/2, 2, 'delta');
            v = 100*(a2 - a1) ./ (0.5*(a1 + a2));
            v(~isfinite(v)) = NaN;
        end

        function [state, col] = inversionState(obj, runIdx)
            % Sign of the static combined depth. Measured over thousands of
            % samples in a quiet region, so it is a far more robust indicator
            % than the waveform value at the first modulated sample, which
            % the snap-on transient can dominate.
            vi = obj.combinedVi(1:max(runIdx,1));
            if runIdx < 1 || runIdx > numel(vi) || ~isfinite(vi(runIdx))
                state = '-'; col = obj.CMuted; return
            end
            if vi(runIdx) < 0
                state = 'INVERTED'; col = [0.494 0.318 0.635];
            else
                state = 'non-inverted'; col = [0.180 0.545 0.341];
            end
        end

        function y = convert(obj, x, ch, kind)
            % Volts -> physical units, applied at display time.
            %   kind 'level' : absolute level, takes multiplier AND offset
            %   kind 'delta' : a difference (Vpp, Vrms, dVdc), multiplier ONLY
            % Getting this distinction wrong would silently bias every
            % amplitude, so the kind is always explicit at the call site.
            y = x;
            if ~obj.IsConvertVolts
                return
            end
            m = obj.multiplierFor(ch);
            if strcmp(kind,'level')
                y = m * (x + obj.offsetFor(ch));
            else
                y = m * x;
            end
        end

        function m = multiplierFor(obj, ch)
            m = 1;
            if ch >= 1 && ch <= numel(obj.VoltMultiplier)
                v = obj.VoltMultiplier(ch);
                if isfinite(v) && v ~= 0, m = v; end
            end
        end

        function o = offsetFor(obj, ch)
            o = 0;
            if ch >= 1 && ch <= numel(obj.VoltOffset)
                v = obj.VoltOffset(ch);
                if isfinite(v), o = v; end
            end
        end

        function u = unitStr(obj, isDelta)
            % Short unit token used in axis labels, tooltips and readouts.
            if obj.IsConvertVolts && strlength(obj.VoltUnit) > 0
                u = char(obj.VoltUnit);
            elseif nargin > 1 && isDelta
                u = 'V';
            else
                u = 'V';
            end
        end

        function u = unitLong(obj, what)
            % Axis label: "Volts pk-pk" reads naturally, "Er pk-pk" does not.
            u0 = obj.unitStr();
            if obj.IsConvertVolts
                switch what
                    case 'pp',    u = sprintf('%s (pk-pk)', u0);
                    case 'level', u = u0;
                    case 'step',  u = sprintf('%s%s', char(916), u0);
                    otherwise,    u = u0;
                end
            else
                switch what
                    case 'pp',    u = 'Volts pk-pk';
                    case 'level', u = 'Volts';
                    case 'step',  u = sprintf('%sVolts', char(916));
                    otherwise,    u = 'Volts';
                end
            end
        end

        function s = trialTag(obj)
            % "(#10366) " prefix for every tab title, so exported PNGs are
            % self-identifying once they are separated from the trial.
            s = '';
            try
                n = obj.BecExp.SerialNumber;
                if isscalar(n) && isfinite(n)
                    s = sprintf('(#%d) ', n);
                end
            catch
            end
        end

        function s = varLabel(~, name)
            % MuscleMuseum hardware variables are hw_xxx. Every label built
            % from this is drawn with Interpreter 'none', so the underscore is
            % never rendered as a TeX subscript.
            s = char(name);
            if isempty(s)
                s = '(not scanned)';
            end
        end

        function s = pipeLine(~, parts)
            % "| a | b | c |" so stacked information stays visually separated.
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                s = '';
                return
            end
            s = ['|  ', strjoin(parts, '  |  '), '  |'];
        end

        function n = lastRun(obj)
            n = 0;
            if isfield(obj.H,'LastRun'), n = obj.H.LastRun; end
            if n < 1, n = numel(obj.FreqExpected); end
        end

        function v = row(~, M, k, runs)
            v = NaN(1, numel(runs));
            if isempty(M) || k > size(M,1), return; end
            n = min(size(M,2), numel(runs));
            v(1:n) = M(k, 1:n);
        end

        function v = cell2(~, M, k, idx)
            v = NaN;
            if ~isempty(M) && k <= size(M,1) && idx >= 1 && idx <= size(M,2)
                v = M(k, idx);
            end
        end

        function v = padTo(~, arr, runs)
            v = NaN(1, numel(runs));
            if isempty(arr), return; end
            n = min(numel(arr), numel(runs));
            v(1:n) = arr(1:n);
        end

        function v = at(~, arr, idx)
            if numel(arr) >= idx && idx >= 1
                v = arr(idx);
            else
                v = NaN;
            end
        end

        function styleAxes(obj, ax)
            ax.Color = 'w';
            ax.Box = 'off';
            ax.XColor = obj.CMuted;
            ax.YColor = obj.CMuted;
            ax.XGrid = 'on'; ax.YGrid = 'on';
            ax.GridColor = obj.CGrid;
            ax.GridAlpha = 0.9;
            ax.LineWidth = 0.7;
            ax.FontSize = 9;
            ax.TickDir = 'out';
        end

        function panelTitle(obj, ax, str)
            t = title(ax, str, 'FontWeight','bold','Color',obj.CInk,'FontSize',10);
            ax.TitleHorizontalAlignment = 'center';
            t.Interpreter = 'none';
        end

        function lim = phaseLimit(~, data)
            % Symmetric phase axis, never narrower than a few degrees and
            % never wider than the full cyclic range.
            v = data(isfinite(data));
            if isempty(v)
                lim = 180;
                return
            end
            lim = max(5, min(180, 1.25*max(abs(v))));
        end

        function thinTicks(~, ax, which, positions, labels, maxTicks)
            % Fine 1D scans can have dozens of points; showing every label
            % makes the axis unreadable. Keep at most maxTicks, evenly spaced,
            % always including the first and last.
            n = numel(positions);
            if n <= maxTicks
                keep = 1:n;
            else
                keep = unique(round(linspace(1, n, maxTicks)));
            end
            if strcmp(which,'x')
                ax.XTick = positions(keep);
                ax.XTickLabel = labels(keep);
            else
                ax.YTick = positions(keep);
                ax.YTickLabel = labels(keep);
            end
        end

        function placeholder(obj, ax, msg)
            text(ax, 0.5, 0.5, msg, 'Units','normalized', ...
                'HorizontalAlignment','center','Color',obj.CMuted,'FontSize',10);
            ax.XTick = []; ax.YTick = [];
        end

        function tidyLegend(obj, ax)
            h = findobj(ax,'-property','DisplayName');
            if isempty(h), return; end
            nm = get(h,'DisplayName');
            if ischar(nm), nm = {nm}; end
            if all(cellfun(@isempty, nm)), return; end
            lg = legend(ax,'Location','northeast');
            lg.Box = 'off'; lg.TextColor = obj.CInk; lg.FontSize = 8.5;
        end

        function f = parabolicRefine(~, mag, pk, Fs, N)
            % Sub-bin peak location by parabolic interpolation on the three
            % bins around the maximum.
            p = 0;
            if pk > 1 && pk < numel(mag)
                a = mag(pk-1); b = mag(pk); c = mag(pk+1);
                den = a - 2*b + c;
                if den ~= 0
                    p = 0.5*(a - c)/den;
                    if abs(p) > 1, p = 0; end
                end
            end
            f = (pk - 1 + p) * (Fs / N);
        end
    end

    %% ===================================================================
    %  Static helpers (no toolbox dependencies)
    %  ===================================================================
    methods (Static, Hidden)
        function g = emptyGrid()
            g = struct('Valid',false,'Is2D',false,'Nx',0,'Ny',0, ...
                'XValues',[],'YValues',[],'XLabels',{{}},'YLabels',{{}}, ...
                'XName','','YName','','CellRuns',{{}},'CellRunStr',string.empty);
        end

        function c = emptyChan()
            c = struct('A',NaN,'Phi',NaN,'Dc',NaN,'Rms',NaN,'F',NaN,'FSeed',NaN, ...
                'Thd',NaN,'DcStep',NaN,'DcPre',NaN,'DcDark',NaN, ...
                'FEnd',NaN,'ChirpRate',NaN,'FInstT',[],'FInst',[],'FInstGood',[], ...
                'SpecF',[],'SpecDb',[]);
        end

        function env = acEnvelope(Y, wLen)
            % Sum over channels of the smoothed magnitude of the high-passed
            % signal. Summing is deliberate: the beams are gated together, so
            % combining channels improves the edge estimate.
            n = size(Y,1);
            env = zeros(n,1);
            for k = 1:size(Y,2)
                y = double(Y(:,k));
                ac = y - movmean(y, wLen);
                env = env + movmean(abs(ac), wLen);
            end
        end

        function [A, phi, dc, ok] = linearSineFit(tau, y, f)
            % Three-parameter fit at fixed frequency:
            %   y = a*cos(2*pi*f*tau) + b*sin(2*pi*f*tau) + c
            % Returns y = A*cos(2*pi*f*tau + phi) + dc.
            A = NaN; phi = NaN; dc = NaN; ok = false;
            w = 2*pi*f;
            p = [cos(w*tau), sin(w*tau), ones(numel(y),1)] \ y;
            if any(~isfinite(p)), return; end
            A = hypot(p(1), p(2));
            phi = atan2(-p(2), p(1));
            dc = p(3);
            ok = isfinite(A) && isfinite(dc);
        end

        function [s, e] = longestRun(mask)
            s = NaN; e = NaN;
            mask = logical(mask(:).');
            d = diff([false, mask, false]);
            starts = find(d == 1);
            stops  = find(d == -1) - 1;
            if isempty(starts), return; end
            [~, k] = max(stops - starts);
            s = starts(k); e = stops(k);
        end

        function M = growMat(M, nRow, nCol)
            old = M;
            M = NaN(nRow, nCol);
            if ~isempty(old)
                r = 1:min(size(old,1),nRow);
                c = 1:min(size(old,2),nCol);
                M(r,c) = old(r,c);
            end
        end

        function v = cellMean(metric, r)
            v = NaN;
            if isempty(r), return; end
            r = r(r >= 1 & r <= numel(metric));
            if isempty(r), return; end
            x = metric(r); x = x(isfinite(x));
            if ~isempty(x), v = mean(x); end
        end

        function nTrue = snapMemoryDepth(n, tol)
            % Scope memory depths are 1-2-5 numbers (10k, 20k, 50k, 100k...).
            % A record that is a handful of samples off one of those is almost
            % certainly that depth with samples dropped in transfer, and the
            % discrepancy corrupts Fs. Anything not close to a ladder value is
            % left untouched, so a genuinely odd depth is never "corrected".
            nTrue = n;
            if ~isfinite(n) || n < 100
                return
            end
            dec = 10.^(2:9);
            ladder = sort([dec, 2*dec, 5*dec]);
            [~, k] = min(abs(ladder - n));
            if abs(ladder(k) - n) / n <= tol
                nTrue = ladder(k);
            end
        end

        function k = idPos(ids, id)
            k = find(ids == id, 1);
            if isempty(k), k = 1; end
        end

        function s = onOff(tf)
            if tf, s = 'on'; else, s = 'off'; end
        end

        function v = pctile(x, p)
            % Percentile without the Statistics Toolbox. Used instead of
            % min/max wherever a narrow outlier (a switching edge) would
            % otherwise set the scale.
            x = sort(x(isfinite(x)));
            if isempty(x)
                v = NaN;
                return
            end
            idx = max(1, min(numel(x), round(p/100 * numel(x))));
            v = x(idx);
        end

        function fi = instFreq(y, Fs)
            % Instantaneous frequency from the analytic signal. The Hilbert
            % transform is built directly from the FFT so no Signal
            % Processing Toolbox licence is needed.
            y = y(:); n = numel(y);
            Y = fft(y);
            h = zeros(n,1);
            if mod(n,2) == 0
                h(1) = 1; h(n/2+1) = 1; h(2:n/2) = 2;
            else
                h(1) = 1; h(2:(n+1)/2) = 2;
            end
            z = ifft(Y .* h);
            ph = unwrap(angle(z));
            fi = diff(ph) * Fs / (2*pi);
        end

        function y = wrap180(x)
            y = mod(x + 180, 360) - 180;
        end

        function w = hannWin(n)
            if n < 2
                w = ones(n,1);
                return
            end
            w = 0.5*(1 - cos(2*pi*(0:n-1).'/(n-1)));
        end

        function p = bandPower(mag, centreBin, halfWidth)
            lo = max(1, floor(centreBin - halfWidth));
            hi = min(numel(mag), ceil(centreBin + halfWidth));
            if hi < lo
                p = 0;
                return
            end
            p = sum(mag(lo:hi).^2);
        end

        function k = colIndex(i, n)
            % Spread family index i over the usable part of a colormap,
            % avoiding the extreme ends where contrast against white is poor.
            if n < 2
                k = 170;
                return
            end
            k = round(30 + (i-1)/(n-1) * (232-30));
            k = max(1, min(256, k));
        end

        function [scale, unitStr] = freqAxisUnit(fTop)
            if fTop >= 1e6
                scale = 1e6; unitStr = 'MHz';
            elseif fTop >= 1e3
                scale = 1e3; unitStr = 'kHz';
            else
                scale = 1; unitStr = 'Hz';
            end
        end

        function s = fmtVal(v)
            % Compact value for tick labels and scan-variable readouts.
            if ~isfinite(v)
                s = '-';
            elseif abs(v) >= 1e6
                s = sprintf('%.4g M', v/1e6);
            elseif abs(v) >= 1e3
                s = sprintf('%.4g k', v/1e3);
            elseif v == round(v)
                s = sprintf('%d', v);
            else
                s = sprintf('%.4g', v);
            end
        end

        function s = fmtNum(v, fmt)
            if isfinite(v)
                s = sprintf(fmt, v);
            else
                s = '-';
            end
        end

        function s = fmtEng(v, unit)
            % Engineering notation with the prefix bound to the unit, so this
            % reads "355.938 kHz" and never "355.938 k Hz". %g drops trailing
            % zeros, so a round sample rate prints as "100 MSa/s".
            if ~isfinite(v)
                s = '-';
                return
            end
            a = abs(v);
            if a == 0
                s = sprintf('0 %s', unit);
            elseif a >= 1e6
                s = sprintf('%.6g M%s', v/1e6, unit);
            elseif a >= 1e3
                s = sprintf('%.6g k%s', v/1e3, unit);
            elseif a >= 1e-3
                s = sprintf('%.6g m%s', v*1e3, unit);
            elseif a >= 1e-6
                s = sprintf('%.6g u%s', v*1e6, unit);
            else
                s = sprintf('%.3g %s', v, unit);
            end
        end

        % --- colormaps ---------------------------------------------------
        function cm = ch1Map()
            % Blue-green (viridis-like), paired with the blue Ch1 line colour.
            anchors = [0.031 0.113 0.216; 0.106 0.310 0.443; 0.180 0.529 0.549; ...
                       0.427 0.686 0.463; 0.816 0.808 0.361; 0.976 0.906 0.612];
            cm = ModulationMonitor.interpMap(anchors, 256);
        end

        function cm = ch2Map()
            % Red-orange (magma-like), paired with the orange Ch2 line colour.
            anchors = [0.055 0.035 0.145; 0.263 0.098 0.400; 0.518 0.169 0.451; ...
                       0.780 0.267 0.373; 0.937 0.475 0.290; 0.988 0.706 0.408; ...
                       0.988 0.886 0.667];
            cm = ModulationMonitor.interpMap(anchors, 256);
        end

        function cm = divergingMap()
            anchors = [0.125 0.290 0.529; 0.400 0.600 0.769; 0.859 0.898 0.933; ...
                       0.969 0.969 0.965; 0.949 0.784 0.686; 0.839 0.451 0.310; ...
                       0.647 0.176 0.145];
            cm = ModulationMonitor.interpMap(anchors, 256);
        end

        function cm = cyclicMap()
            % Runs dark -> blue -> white -> red -> dark, so 0 is neutral and
            % the two ends (+180 and -180) are the same colour: a wrap is not
            % rendered as a discontinuity.
            anchors = [0.180 0.184 0.278; 0.180 0.365 0.588; 0.478 0.663 0.816; ...
                       0.831 0.882 0.929; 0.973 0.973 0.969; 0.949 0.804 0.729; ...
                       0.827 0.475 0.353; 0.639 0.216 0.196; 0.180 0.184 0.278];
            cm = ModulationMonitor.interpMap(anchors, 256);
        end

        function cm = interpMap(anchors, n)
            x = (1:size(anchors,1)).';
            xi = linspace(1, size(anchors,1), n).';
            cm = [interp1(x, anchors(:,1), xi), ...
                  interp1(x, anchors(:,2), xi), ...
                  interp1(x, anchors(:,3), xi)];
            cm = min(max(cm,0),1);
        end
    end
end