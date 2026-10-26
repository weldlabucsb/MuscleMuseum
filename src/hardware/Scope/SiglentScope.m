classdef (Abstract) SiglentScope < Scope
    % SiglentScope: VISA implementation for Siglent SDS2000X Plus / SDS2000X HD series
    %
    % Key features:
    % -- visadev communication
    % -- raw 16-bit (WORD) waveform transfer, split into chunks of :WAVeform:MAXPoint?
    % -- scaling taken from the binary :WAVeform:PREamble? (V/div, offset,
    %    codes/div, probe factor), so it is correct for 8-, 10- and 12-bit ADCs
    %
    % Model subclasses configure:
    %   AcqResolution        ":ACQuire:RESolution" argument, or "" to not send it
    %   SetMemoryManagement  send ":ACQuire:MMANagement FMDepth" before ACQ:MDEP
    %   isInterleaved()      which channel combinations run interleaved
    %   validMemoryDepths()  allowed ACQ:MDEP values for the current mode
    %   currentSamplingRateMax()  max sample rate for the current channel mode

    properties (Access = public, Transient)
        VisaObj % visadev object
    end

    properties (SetAccess = protected)
        AcqResolution string = ""           % e.g. "10Bits" (SDS2000X+); "" = don't send
        SetMemoryManagement logical = true % force fixed-memory-depth mode in set()
    end

    properties (Access = public)
        AcqType string = "Normal"           % "Normal" or "ERES"
        AcqEresBits double = 3.0            % ERES bit depth (0.5 to 3.0; max 3 bits)
    end

    properties (SetAccess = protected, Transient)
        LastPreamble = struct.empty % preamble of each channel from the last read()
    end

    properties (Access = private, Transient)
        MaxPointsCache double = []  % cached :WAVeform:MAXPoint? answer
    end

    methods
        function obj = SiglentScope(resourceName, name)
            obj@Scope(resourceName, name);
            obj.Manufacturer = "Siglent";
        end

        function connect(obj)
            try
                obj.VisaObj = visadev(obj.ResourceName);
                configureTerminator(obj.VisaObj, "LF");
                obj.VisaObj.ByteOrder = "little-endian"; % Siglent default
                obj.VisaObj.Timeout = 10;
                obj.MaxPointsCache = [];

                writeline(obj.VisaObj, "*CLS");
                idn = writeread(obj.VisaObj, "*IDN?"); %#ok<NASGU>
                % fprintf("Connected to: %s\n", idn);
            catch ME
                error("Failed to connect to scope at %s: %s", obj.ResourceName, ME.message);
            end
        end

        function set(obj)
            v = obj.VisaObj;

            % =========================
            % Acquisition / Type Settings
            % =========================
            if strcmpi(obj.AcqType, "ERES")
                writeline(v, sprintf(":ACQuire:TYPE ERES,%g", obj.AcqEresBits));
                obj.SetMemoryManagement = false;
            else
                writeline(v, ":ACQuire:TYPE NORMal");
            end

            if strlength(obj.AcqResolution) > 0
                writeline(v, ":ACQuire:RESolution " + obj.AcqResolution);
            end
            writeline(v, ":WAVeform:WIDTh WORD"); % required for >8-bit data

            % =========================
            % Channel settings (configure before timebase/memory depth)
            % =========================
            for ii = 1:obj.NChannel
                ch = "CHAN" + ii;
                if obj.IsEnabled(ii)
                    writeline(v, sprintf("%s:SWIT ON", ch));
                    writeline(v, sprintf("%s:COUP %s", ch, upper(obj.VerticalCoupling(ii))));
                    writeline(v, sprintf("%s:SCAL %g", ch, obj.VerticalRange(ii) / 8));
                    writeline(v, sprintf("%s:OFFS %g", ch, obj.VerticalOffset(ii)));
                else
                    writeline(v, sprintf("%s:SWIT OFF", ch));
                end
            end

            % =========================
            % Horizontal settings
            % =========================
            obj.Duration = obj.snapDuration(obj.Duration);
            writeline(v, sprintf("TIM:SCAL %g", obj.Duration / 10));
            obj.Duration = 10 * obj.queryNumber("TIM:SCAL?");   % trust what the scope actually set
            
            writeline(v, sprintf(':TIMebase:DELay %e', -obj.HorizontalOffset));

            % =========================
            % Memory depth (after channels and timebase are established)
            % =========================
            obj.applyMemoryDepth();

            % =========================
            % Trigger settings
            % =========================
            switch obj.TriggerMode
                case "Normal"
                    writeline(v, "TRIG:MODE NORM");
                case "Auto"
                    writeline(v, "TRIG:MODE AUTO");
                case "Software"
                    writeline(v, "TRIG:MODE SING");
            end
            switch obj.TriggerSource
                case "External"
                    writeline(v, "TRIG:EDGE:SOUR EX");
                otherwise
                    writeline(v, sprintf("TRIG:EDGE:SOUR C%s", extractAfter(obj.TriggerSource, "CH")));
            end
            switch obj.TriggerSlope
                case "Rise"
                    writeline(v, "TRIG:EDGE:SLOP RIS");
                case "Fall"
                    writeline(v, "TRIG:EDGE:SLOP FALL");
            end
            writeline(v, sprintf("TRIG:EDGE:LEV %g", obj.TriggerLevel));
        end

        function read(obj)
            if ~obj.check()
                error("Scope check failed. Aborting read.");
            end

            v = obj.VisaObj;
            enabledChans = find(obj.IsEnabled);
            numEnabled = numel(enabledChans);

            writeline(v, ':TRIGger:STOP');
            restartOnExit = onCleanup(@() writeline(v, ':TRIGger:RUN')); %#ok<NASGU>

            chanData = cell(1, numEnabled);
            pre = struct.empty;
            for ii = 1:numEnabled
                idx = enabledChans(ii);
                writeline(v, sprintf(':WAVeform:SOURce C%d', idx));
                try
                    p = obj.readPreamble();
                    p.Channel = idx;
                    obj.crossCheckScale(p);

                    codes = obj.readWaveformCodes(p.NPoints);
                    chanData{ii} = double(codes) .* (p.VDiv / p.CodePerDiv) - p.Offset;
                    pre = [pre, p]; %#ok<AGROW>
                catch ME
                    warning("SiglentScope:noWaveform", ...
                        "CH%d: could not read waveform (%s). Row filled with NaN.", idx, ME.message);
                end
            end
            obj.LastPreamble = pre;

            % Size the record from what the scope actually returned
            lens = cellfun(@numel, chanData);
            if any(lens > 0)
                nPts = max(lens);
                if nPts ~= obj.NSample
                    warning("SiglentScope:pointMismatch", ...
                        "Scope returned %d points but NSample was %d. NSample updated to match.", ...
                        nPts, obj.NSample);
                    obj.NSample = nPts;
                end
                if ~isempty(pre)
                    actualDuration = pre(1).Interval * nPts;
                    if abs(actualDuration - obj.Duration) / obj.Duration > 0.01
                        warning("SiglentScope:durationMismatch", ...
                            "Scope record length is %.6g s but Duration is %.6g s; TimeList will be off.", ...
                            actualDuration, obj.Duration);
                    end
                end
            else
                nPts = obj.NSample;
            end

            obj.Sample = NaN(numEnabled, nPts);
            for ii = 1:numEnabled
                n = numel(chanData{ii});
                obj.Sample(ii, 1:n) = chanData{ii};
            end
            obj.SampleUnit = "V";

            obj.saveObject;
        end

        function startFromEdge(obj)
            tdiv = obj.queryNumber('TIM:SCAL?');
            writeline(obj.VisaObj, sprintf(':TIMebase:DELay %e', 5 * tdiv));
        end
       
        function d = snapDuration(obj, d) %#ok<INUSL>
            % Round a requested Duration up to the next 1-2-5 time/div step
            % (10 divisions), so the full requested window is captured.
            % Range from the datasheet: 1 ns/div to 1000 s/div.
            steps = [1 2 5]' * 10.^(-9:3);
            grid  = sort(steps(:)');
            grid  = grid(grid >= 1e-9 & grid <= 1000);
            k = find(grid >= (d / 10) * (1 - 1e-9), 1);
            if isempty(k)
                k = numel(grid);
            end
            d = 10 * grid(k);
        end
        
        function trigger(obj)
            writeline(obj.VisaObj, ":TRIGger:MODE FTRIG")
        end

        function status = check(obj)
            % Drains the whole error queue (SYST:ERR? returns one entry per call).
            status = false;
            if isempty(obj.VisaObj)
                return;
            end
            errs = strings(0);
            for k = 1:20
                e = strtrim(string(writeread(obj.VisaObj, "SYST:ERR?")));
                if strlength(e) == 0 || startsWith(e, "0") || startsWith(e, "+0")
                    break;
                end
                errs(end+1) = e; %#ok<AGROW>
            end
            if isempty(errs)
                status = true;
            else
                warning("Scope Error(s): %s", strjoin(errs, " | "));
            end
        end

        function [out, state] = isScopeTriggered(obj)
            state = writeread(obj.VisaObj, 'TRIG:STAT?');
            out = contains(state, "Trig'd");
            pause(0.01)
        end

        function close(obj)
            if ~isempty(obj.VisaObj)
                try
                    delete(obj.VisaObj);
                catch
                end
            end
            obj.VisaObj = [];
        end
    end

    methods (Access = protected)
        function tf = isInterleaved(obj)
            % Interleaved = at most one of C1/C2 and at most one of C3/C4 on.
            en = obj.IsEnabled;
            tf = ~(en(1) && en(2)) && ~(numel(en) >= 4 && en(3) && en(4));
        end

        function d = validMemoryDepths(obj)
            if obj.isInterleaved()
                d = [2e4, 2e5, 2e6, 2e7, 2e8];
            else
                d = [1e4, 1e5, 1e6, 1e7, 1e8];
            end
        end

        function sr = currentSamplingRateMax(obj)
            sr = obj.SamplingRateMax;
        end

        function applyMemoryDepth(obj)
            % Snap NSample to a valid depth that does not exceed the max sample
            % rate for this Duration, then send it to the scope.
            d = obj.validMemoryDepths();
            ok = d(d ./ obj.Duration <= obj.currentSamplingRateMax() * (1 + 1e-9));
            if isempty(ok)
                ok = d(1);
            end
            [~, k] = min(abs(ok - obj.NSample));
            obj.NSample = ok(k);

            if strcmpi(obj.AcqType, "ERES")
                % In ERES mode, use AUTO management and set ceiling to max depth (200M/100M)
                writeline(obj.VisaObj, ":ACQuire:MMANagement AUTO");
                maxDepth = ok(end); % Maximum available depth for current channel config (e.g., 200M or 100M)
                writeline(obj.VisaObj, "ACQ:MDEP " + SiglentScope.depthString(maxDepth));
            else
                if obj.SetMemoryManagement
                    writeline(obj.VisaObj, ":ACQuire:MMANagement FMDepth");
                else
                    writeline(obj.VisaObj, ":ACQuire:MMANagement AUTO");
                end
                writeline(obj.VisaObj, "ACQ:MDEP " + SiglentScope.depthString(ok(k)));
            end
        end

        function p = readPreamble(obj)
            % Parse the 346-byte binary WAVeform:PREamble? block (Siglent new format).
            v = obj.VisaObj;
            writeline(v, ":WAVeform:PREamble?");
            raw = uint8(readbinblock(v, "uint8"));
            flush(v, "input");
            raw = raw(:).';
            if numel(raw) < 332
                error("Preamble too short (%d bytes).", numel(raw));
            end

            f32 = @(off) double(typecast(raw(off+1:off+4), 'single'));
            i32 = @(off) double(typecast(raw(off+1:off+4), 'int32'));
            i16 = @(off) double(typecast(raw(off+1:off+2), 'int16'));
            f64 = @(off) double(typecast(raw(off+1:off+8), 'double'));

            p.NPoints    = i32(hex2dec('74'));
            probe        = f32(hex2dec('148'));
            if ~(isfinite(probe) && probe > 0), probe = 1; end
            p.Probe      = probe;
            p.VDiv       = f32(hex2dec('9C')) * probe;
            p.Offset     = f32(hex2dec('A0')) * probe;
            p.CodePerDiv = f32(hex2dec('A4'));
            p.AdcBit     = i16(hex2dec('AC'));
            p.Interval   = f32(hex2dec('B0'));
            p.Delay      = f64(hex2dec('B4'));

            if ~(p.NPoints > 0)
                error("Preamble reports %d points (no acquisition?).", p.NPoints);
            end
            if ~(isfinite(p.CodePerDiv) && p.CodePerDiv > 0)
                error("Invalid codes/div in preamble (%g).", p.CodePerDiv);
            end
        end

        function crossCheckScale(obj, p)
            % Sanity check: preamble V/div should equal the channel's V/div.
            try
                vdivScope = obj.queryNumber(sprintf(":CHANnel%d:SCALe?", p.Channel));
                if abs(vdivScope - p.VDiv) / vdivScope > 0.01
                    warning("SiglentScope:scaleMismatch", ...
                        "CH%d: preamble V/div = %g but channel V/div = %g (probe factor %g). Check scaling.", ...
                        p.Channel, p.VDiv, vdivScope, p.Probe);
                end
            catch
            end
        end

        function codes = readWaveformCodes(obj, nPts)
            % Read nPts int16 codes in chunks no larger than :WAVeform:MAXPoint?.
            v = obj.VisaObj;
            chunk = min(nPts, obj.maxPoints());

            oldTimeout = v.Timeout;
            v.Timeout = max(oldTimeout, 5 + 2 * chunk / 2e6); % assume >= ~2 MB/s link

            codes = zeros(1, nPts, 'int16');
            pos = 0;
            try
                while pos < nPts
                    n = min(chunk, nPts - pos);
                    writeline(v, sprintf(":WAVeform:STARt %d", pos));
                    writeline(v, sprintf(":WAVeform:POINt %d", n));
                    writeline(v, ":WAVeform:DATA?");
                    blk = readbinblock(v, "int16");
                    flush(v, "input");
                    if isempty(blk)
                        error("Empty data block at point %d.", pos);
                    end
                    m = min(numel(blk), n);
                    codes(pos+1:pos+m) = int16(blk(1:m));
                    pos = pos + m;
                    if m < n % scope returned fewer points than asked
                        codes = codes(1:pos);
                        break;
                    end
                end
                writeline(v, ":WAVeform:STARt 0");
            catch ME
                v.Timeout = oldTimeout;
                rethrow(ME);
            end
            v.Timeout = oldTimeout;
        end

        function n = maxPoints(obj)
            if isempty(obj.MaxPointsCache)
                n = inf;
                try
                    q = obj.queryNumber(":WAVeform:MAXPoint?");
                    if isfinite(q) && q > 0
                        n = q;
                    end
                catch
                end
                obj.MaxPointsCache = n;
            end
            n = obj.MaxPointsCache;
        end

        function val = queryNumber(obj, cmd)
            % Query and return the last number in the reply (ignores e.g. the '1' in 'C1').
            s = writeread(obj.VisaObj, cmd);
            m = regexp(s, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
            if isempty(m)
                error("No number in reply to '%s': %s", cmd, s);
            end
            val = str2double(m{end});
        end
    end

    methods (Static, Access = protected)
        function s = depthString(n)
            % 2e7 -> "20M", 2e4 -> "20k"
            if n >= 1e6 && mod(n, 1e6) == 0
                s = sprintf("%dM", n / 1e6);
            elseif n >= 1e3 && mod(n, 1e3) == 0
                s = sprintf("%dk", n / 1e3);
            else
                s = sprintf("%d", n);
            end
        end
    end
end