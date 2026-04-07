classdef (Abstract) SiglentScope < Scope
    % SiglentScope: Fast VISA implementation for Siglent SDS2000X+ series
    %
    % Key features:
    % -- Uses visadev for fast communication
    % -- Pulls raw 16-bit waveform data
    % -- Uses WAV:PRE? for scaling (Siglent format)

    properties (Access = public,Transient)
        VisaObj % visadev object
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
                
                % Try little-endian first (Siglent default)
                obj.VisaObj.ByteOrder = "little-endian";
                obj.VisaObj.Timeout = 10;

                writeline(obj.VisaObj, "*CLS");

                idn = writeread(obj.VisaObj, "*IDN?");
                % fprintf("Connected to: %s\n", idn);

            catch ME
                error("Failed to connect to scope at %s: %s", obj.ResourceName, ME.message);
            end
        end

        function set(obj)
            v = obj.VisaObj;

            % =========================
            % Waveform transfer setup
            % =========================
            % writeline(v, "WAV:MODE RAW");       % Full memory
            % writeline(v, "WAV:FORMAT BYTE");      % 16-bit
            % writeline(v, "WAV:BYTEORDER LSB");  % Little endian

            % =========================
            % Horizontal settings
            % =========================
            writeline(v, sprintf("TIM:SCAL %g", obj.Duration / 10));

            % =========================
            % Channel settings
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

            if sum(obj.IsEnabled) == 1
                switch obj.NSample
                    case 2e4
                        writeline(v, sprintf("ACQ:MDEP 20k"));
                    case 2e5
                        writeline(v, sprintf("ACQ:MDEP 200k"));
                    case 2e6
                        writeline(v, sprintf("ACQ:MDEP 2M"));
                    case 2e7
                        writeline(v, sprintf("ACQ:MDEP 20M"));
                    case 2e8
                        writeline(v, sprintf("ACQ:MDEP 200M"));
                    otherwise
                        writeline(v, sprintf("ACQ:MDEP 20M"));
                end
            else
                switch obj.NSample
                    case 1e4
                        writeline(v, sprintf("ACQ:MDEP 10k"));
                    case 1e5
                        writeline(v, sprintf("ACQ:MDEP 100k"));
                    case 1e6
                        writeline(v, sprintf("ACQ:MDEP 1M"));
                    case 1e7
                        writeline(v, sprintf("ACQ:MDEP 10M"));
                    case 1e8
                        writeline(v, sprintf("ACQ:MDEP 100M"));
                    otherwise
                        writeline(v, sprintf("ACQ:MDEP 10M"));
                end
            end
            % writeline(v, sprintf("ACQ:MDEP 10M"))

            % =========================
            % Trigger settings
            % =========================
            switch obj.TriggerMode
                case "Normal"
                    writeline(v, sprintf("TRIG:MODE NORM"));
                case "Auto" 
                    writeline(v, sprintf("TRIG:MODE AUTO"));
                case "Software"
                    writeline(v, sprintf("TRIG:MODE SING"));
            end
            switch obj.TriggerSource
                case "External"
                    writeline(v, sprintf("TRIG:EDGE:SOUR EX"));
                otherwise
                    writeline(v, sprintf("TRIG:EDGE:SOUR C%s", extractAfter(obj.TriggerSource, "CH")));
            end
            switch obj.TriggerSlope
                case "Rise"
                    writeline(v, sprintf("TRIG:EDGE:SLOP RIS"));
                case "Fall"
                    writeline(v, sprintf("TRIG:EDGE:SLOP FALL"));
            end
            writeline(v, sprintf("TRIG:EDGE:LEV %g", obj.TriggerLevel));
        end

        function read(obj)
            if ~obj.check()
                error("Scope check failed. Aborting read.");
            end

            v = obj.VisaObj;
            % tInternal = tic;

            enabledChans = find(obj.IsEnabled);
            numEnabled = numel(enabledChans);

            obj.Sample = zeros(numEnabled, obj.NSample);

            writeline(v,':TRIGger:STOP')
            for ii = 1:numEnabled
                idx = enabledChans(ii);

                % Select channel
                % writeline(v, 'WFSU TYPE,WORD');
                % writeline(v, 'CFMT DEF9,WORD,BIN');

                % flush(v, "input");

                % Get Vertical Gain (Volts/Div) and Offset
                % 1. Read the raw string responses from the scope
                vdiv_str = writeread(v, sprintf('C%d:VDIV?', idx));
                voffset_str = writeread(v, sprintf('C%d:OFST?', idx));

                % 2. Find ALL numbers in the strings (this will output a cell array of matches)
                vdiv_matches = regexp(vdiv_str, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
                voffset_matches = regexp(voffset_str, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');

                % 3. Extract the LAST number found (ignoring the '1' in 'C1') and convert to double
                vdiv = str2double(vdiv_matches{end});
                voffset = str2double(voffset_matches{end});
                
                % Request waveform
                writeline(v, sprintf(':WAVeform:SOURce C%g', idx));
                writeline(v, sprintf(':WAVeform:DATA?'));
                % writeline(v, sprintf('C%g:WF? DAT2', idx));

                % charRead = '';
                % while charRead ~= ','
                %     charRead = read(v, 1, 'char');
                % end
                try
                    rawData = readbinblock(v,'int8');
                    % writeline(v,":WAVeform:PRE?");
                    % pre = readbinblock(v,'uint8');

                    obj.Sample(ii, :) = (double(rawData) .* (vdiv / 30)) - voffset;
                catch
                    obj.Sample(ii, :) = zeros(1,obj.NSample);
                    warning("no waveform on the scope")
                end
                % read(v,1,"char")
                % writeline(v,"*OPC?")
                % readline(v)

                % flush(v, "input");
                % pause(0.1)

            end
            writeline(v,':TRIGger:RUN')
            % obj.set
            obj.SampleUnit = "V";

            % if ismethod(obj, 'saveObject')
                obj.saveObject;
            % end

            % fprintf('(internal timer on read()) -- Transfer Speed %.4f s\n', toc(tInternal));
        end

        function startFromEdge(obj)
            v = obj.VisaObj;
            tdiv_str = writeread(v, 'TIM:SCAL?');
            tdiv = str2double(regexp(tdiv_str, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match', 'once'));
            delayValue = 5 * tdiv; 
            writeline(v, sprintf(':TIMebase:DELay %e', delayValue));
        end

        function trigger(obj)
            v = obj.VisaObj;
            writeline(v,":TRIGger:MODE FTRIG")
        end

        function status = check(obj)
            if isempty(obj.VisaObj)
                status = false;
                return;
            end

            errStr = writeread(obj.VisaObj, "SYST:ERR?");

            if startsWith(errStr, "0")
                status = true;
            else
                warning("Scope Error: %s", errStr);
                status = false;
            end
        end

        function close(obj)
            if ~isempty(obj.VisaObj)
                clear obj.VisaObj;
            end
        end
    end
end