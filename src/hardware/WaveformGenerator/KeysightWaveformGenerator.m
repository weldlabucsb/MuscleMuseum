classdef (Abstract) KeysightWaveformGenerator < WaveformGenerator
    %:class:`KeysightWaveformGenerator` base for Keysight AWGs with VISA control.
    %
    % Provides setup, upload, triggering, and connection management for Keysight
    % arbitrary waveform generators using :meth:`connect`, :meth:`set`, :meth:`upload`,
    % :meth:`trigger`, :meth:`close`, and :meth:`check`.
    
    properties (SetAccess = protected,Transient)
        VisaDevice
    end
    
    methods
        function obj = KeysightWaveformGenerator(resourceName,name)
            % Construct a :class:`KeysightWaveformGenerator`.
            %
            % :param resourceName: VISA resource name, e.g., "TCPIP0::...::inst0::INSTR"
            % :type resourceName: string
            % :param name: Device nickname
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@WaveformGenerator(resourceName,name);
            obj.Manufacturer = "Keysight";
        end
        
        function connect(obj)
            % Open VISA connection using :attr:`ResourceName`.
            obj.VisaDevice = visadev(obj.ResourceName);
        end

        function set(obj)
            % Configure channels (sample rate, voltage levels, trigger, mode, load).
            %
            % Applies settings per channel: :attr:`SamplingRate`, trigger
            % source/slope, output mode/load, and voltage limits. Clears volatile
            % memory before upload and ensures LSB byte order for binary blocks.
            obj.check;
            v = obj.VisaDevice;
            v.ByteOrder = "little-endian";
            configureTerminator(v,"LF")
            writeline(v,"*CLS") % Clear status
            for ii = 1:obj.NChannel
                sourceStr = "SOURce" + string(ii);
                outputStr = "OUTPut" + string(ii);
                triggerStr = "TRIGger" + string(ii);
                writeline(v,outputStr + " 0") % Stop output
                writeline(v,sourceStr + ":DATA:VOLatile:CLEar") % Clear volatile memory
                writeline(v,"FORM:BORD SWAP") % Swaps byte order to LSB
                writeline(v, sprintf(sourceStr + ':FUNCtion:ARBitrary:SRATe %g MHZ', obj.SamplingRate(ii) * 1e-6)); % Sampling rate
                writeline(v, sprintf(sourceStr + ':VOLTage:HIGH %g', 2.0)); % Voltage high
                writeline(v, sprintf(sourceStr + ':VOLTage:LOW %g', -2.0)); % Voltage low
                writeline(v, sprintf(sourceStr + ':VOLTage:OFFset %g', 0)); % Voltage offset
                writeline(v, sprintf(sourceStr + ':FUNCtion:ARBitrary:PTPeak %g', 1)); % Set arbitray waveform p2p
                
                % Trigger source
                switch obj.TriggerSource(ii)
                    case "External"
                        writeline(v, triggerStr + ":SOURce EXT");
                    case "Software"
                        writeline(v, triggerStr + ":SOURce BUS");
                    case "Immediate"
                        writeline(v, triggerStr + ":SOURce IMM");
                end

                % Trigger slope
                switch obj.TriggerSlope(ii)
                    case "Rise"
                        writeline(v, triggerStr + ":SLOPe POS");
                    case "Fall"
                        writeline(v, triggerStr + ":SLOPe NEG");
                end

                % Output mode
                if obj.IsOutput(ii)
                    switch obj.OutputMode(ii)
                        case "Normal"
                            writeline(v, outputStr + ':MODE NORMal');
                        case "Gated"
                            writeline(v, outputStr + ':MODE GATed'); % Gating the output
                    end
                end

                % Output load
                switch obj.OutputLoad(ii)
                    case "50"
                        writeline(v, outputStr + ':LOAD 50')
                    case "Infinity"
                        writeline(v, outputStr + ':LOAD INFinity')
                end
            end
        end

        function upload(obj)
            % Upload prepared waveforms to the device and start output if enabled.
            %
            % Sequences each channel's :attr:`WaveformList` by inserting leading
            % and trailing zeros for clean triggering, scales to peak-to-peak, and
            % writes segments + sequence tables via SCPI binary block transfers.
            %% Check connection to the device
            obj.check;
            v = obj.VisaDevice;

            %% Upload to channels
            for ii = 1:obj.NChannel
                %% Check waveform and output
                if isempty(obj.WaveformList{ii})
                    outputStr = "OUTPut" + string(ii);
                    writeline(v,outputStr + " 0") % Stop output if no waveform
                    continue
                elseif obj.IsOutput(ii) == false
                    continue
                end

                %% Add begining and ending zero waveforms for triggering
                obj.WaveformList{ii}.SamplingRate = obj.SamplingRate(ii);
                t = obj.WaveformList{ii}.WaveformPrepared;
                Sample = {zeros(1,35)};
                PlayMode = "OnceWaitTrigger";
                NRepeat = 0;
                t0 = table(Sample,PlayMode,NRepeat);
                PlayMode = "Repeat";
                te = table(Sample,PlayMode,NRepeat);
                t = [t0;t;te];

                %% Initialize parameters
                nWave = size(t,1);
                arbSegName = "MMARB_ch" + string(ii) + "_" + string(1:nWave)';
                arbFileName = "MMARB_ch" + string(ii);
                arbToSeq = cell(1,nWave);
                markerModeList=repmat({'lowAtStart'}, 1, nWave);
                markerLocList=linspace(10,10,nWave);
                sourceStr = "SOURce" + string(ii);
                outputStr = "OUTPut" + string(ii);

                %% Set PTP value
                scaleFactor = max(cellfun(@(x) max(abs(x)),t.Sample));
                ptp = 2 * scaleFactor;
                writeline(v, sprintf(sourceStr + ':FUNCtion:ARBitrary:PTPeak %g', ptp)); % Set arbitray waveform p2p

                %% Upload
                for jj = 1:nWave
                    dataBlock = t.Sample{jj} ./ scaleFactor;
                    dataBlock = dataBlock(:).'; % data block has to be a row vector
                    dataBlock = single(dataBlock); % reduce memory use

                    %% Map play mode string
                    switch t.PlayMode(jj)
                        case "Once"
                            playMode = "once";
                        case "OnceWaitTrigger"
                            playMode = "onceWaitTrig";
                        case "Repeat"
                            playMode = "repeat";
                        case "RepeatInf"
                            playMode = "repeatInf";
                        case "RepeatTilTrigger"
                            playMode = "repeatTilTrig";
                    end

                    %% Write arb segment data into the device
                    header = char(sprintf(sourceStr+":DATA:ARBitrary" + " %s,",arbSegName(jj)));
                    writebinblock2(v,dataBlock,obj.DataType,header) % Write data into arb segment
                    arbToSeq{jj}=sprintf('%s,%d,%s,%s,%d',arbSegName(jj),t.NRepeat(jj),playMode,markerModeList{jj},markerLocList(jj));
                end

                %% Concatenate arb segments into an arb sequence
                allArbsToSeq=sprintf(strcat(arbFileName,',%s'),sprintf('%s,',arbToSeq{1:end}));
                allArbsToSeq=allArbsToSeq{1}(1:end-1); %remove final comma
                header2 = char(sourceStr + pad(":DATA:SEQuence "));
                writebinblock2(v,allArbsToSeq,obj.DataType,header2)

                %% Tell the device to output the arb sequence
                writeline(v,sprintf(sourceStr + ':FUNCtion:ARBitrary "%s"', arbFileName)) % Change ARB source file
                writeline(v,sourceStr + ":FUNCtion ARB") % Change output mode to ARB
                writeline(v,outputStr + " 1") % Start to output

                %% Check if upload is successful
                s = obj.check;
                if s
                    disp(obj.Name + " channel" + num2str(ii) + " uploaded [" + obj.WaveformList{ii}.Name +"] successfully.")
                    obj.saveObject;
                else
                    obj.set
                end
            end
        end

        function trigger(obj)
            % Issue a software trigger on channels configured for BUS trigger.
            %% Check connection to the device
            obj.check;
            v = obj.VisaDevice;

            %% Software trigger
            for ii = 1:obj.NChannel
                if obj.TriggerSource(ii) == "Software"
                    triggerStr = "TRIGger" + string(ii);
                    writeline(v, triggerStr);
                end
            end

        end

        function close(obj)
            % Close the VISA session, ensuring device is idle.
            if isempty(obj.VisaDevice)
                warning("VISA device is not connected.")
                return
            elseif ~isvalid(obj.VisaDevice)
                warning("VISA device was deleted.")
                return
            else
                em = query(obj.VisaDevice, ':SYSTem:ERRor?');
                if em(1:2)~="+0"
                    disp("Hardware error. Message: "+ newline + em)
                    obj.set
                end
            end
            v = obj.VisaDevice;
            write(v, '*WAI');
            write(v, ':ABORt');
            delete(v);
            clear v;
            clear instrument
        end
    
        function status = check(obj)
            % Query device error status.
            %
            % :return: True when the device reports no error via :code:`SYST:ERR?`
            % :rtype: logical
            status = false;
            if isempty(obj.VisaDevice)
                error("VISA device is not connected.")
            elseif ~isvalid(obj.VisaDevice)
                error("VISA device was deleted.")
            else
                em = query(obj.VisaDevice, ':SYSTem:ERRor?');
                if em(1:2)~="+0"
                    disp("Hardware error. Message: "+ newline + em)
                else
                    status = true;
                end
            end
        end
    
    end
end

