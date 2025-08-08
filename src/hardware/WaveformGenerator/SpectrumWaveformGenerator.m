classdef (Abstract) SpectrumWaveformGenerator < WaveformGenerator
    %:class:`SpectrumWaveformGenerator` Spectrum-specific AWG implementation.
    %   
    % Please download the Spectrum AWG MATLAB driver (see vendor site) and ensure it
    % is on MATLAB's path. Provides :meth:`connectSpec`, :meth:`setSpec`, and an
    % :meth:`upload` implementation that prepares segments and sequences per-channel.
    %
    % Properties:
    %   - :attr:`Device`: Spectrum device handle and metadata
    %   - :attr:`RegMap`: Register map (from Spectrum library)
    %   - :attr:`ErrorMap`: Error codes (from Spectrum library)
    
    properties (SetAccess = protected,Transient)
        Device
        RegMap
        ErrorMap
    end
    
    methods
        function obj = SpectrumWaveformGenerator(resourceName,name)
            % Construct a :class:`SpectrumWaveformGenerator`.
            %
            % :param resourceName: Vendor-specific resource string
            % :type resourceName: string
            % :param name: Device nickname
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@WaveformGenerator(resourceName,name);
            obj.Manufacturer = "Spectrum";
        end

        function connect(obj)
            % Spectrum requires a fresh connection per upload; no persistent connect.
        end
        
        function connectSpec(obj)
            % Initialize Spectrum maps and open the device.
            try
                obj.RegMap = spcMCreateRegMap;
                obj.ErrorMap = spcMCreateErrorMap;
            catch
                error("The Spectrum MATLAB library is not found. Please download it from Spectrum AWG websites and install it." + ...
                " Make sure the library is in MATLAB's search path.")
            end
            spcMFree;
            [isOpened,obj.Device] = spcMInitDevice(char(obj.ResourceName));
            if ~isOpened
                spcMErrorMessageStdOut(obj.Device, 'Error: Could not open card\n', true)
            end
        end

        function set(obj)
            % Unused (Spectrum initializes per-upload).
        end
        
        function setSpec(obj)
            % Configure sampling rate, trigger, and enabled outputs for Spectrum device.
            obj.check;

            %% Set sampling rate
            [success,obj.Device] = spcMSetupClockPLL(obj.Device, obj.SamplingRate(1), 0);
            if (success == false)
                obj.closeSpec
                spcMErrorMessageStdOut(obj.Device, 'Error: spcMSetupClockPLL:\n\t', true);
                return;
            end
            sr = obj.Device.setSamplerate;
            obj.SamplingRate(:) = deal(sr);

            %% Set triggering
            switch obj.TriggerSource(1)
                case "External"
                    [~,obj.Device] = spcMSetupTrigExternal(obj.Device, obj.RegMap('SPC_TM_POS'), 0, 0, 1, 0); 
                case "Immediate"
                    [~,obj.Device] = spcMSetupTrigSoftware(obj.Device, 0);
                otherwise
                    [~,obj.Device] = spcMSetupTrigSoftware(obj.Device, 0);
            end

            %% Set output
            for ii = 1:obj.NChannel
                if obj.IsOutput(ii)
                    [~,obj.Device] = spcMSetupAnalogOutputChannel(obj.Device, ii-1, 2000, 0, 0, obj.RegMap('SPCM_STOPLVL_ZERO'), 0, 0);     
                end
            end
        end

        function upload(obj)
            % Upload waveforms as same-sized segments and sequence them (Spectrum requirement).
            %
            % Channels must have the same number of segments and behavior. Samples are
            % uploaded segment-by-segment, and each segment stores samples of all channels.
            %% Set and connect
            obj.connectSpec;
            obj.setSpec;

            %% Get the minimum segment size
            enabledChannel = [];
            for ii = 1:obj.NChannel
                if isempty(obj.WaveformList{ii})
                    continue
                elseif obj.IsOutput(ii) == false
                    continue
                else
                    enabledChannel = [enabledChannel,ii];
                end
            end

            if isempty(enabledChannel)
                return
            else
                nEnabledChannel = numel(enabledChannel);
            end

            switch nEnabledChannel
                case 1
                    segmentSizeMinimum = 384;
                case 2
                    segmentSizeMinimum = 192;
                case 3
                    segmentSizeMinimum = 192;
                otherwise
                    segmentSizeMinimum = 96;
            end
            
            %% Load prepared waveforms
            t = cell(1,nEnabledChannel);
            for ii = 1:nEnabledChannel
                obj.WaveformList{enabledChannel(ii)}.SamplingRate = obj.SamplingRate(1);
                obj.WaveformList{enabledChannel(ii)}.NCycle = NaN; % avoid periodic splitting
                t{ii} = obj.WaveformList{enabledChannel(ii)}.WaveformPrepared; % prepared waveforms
            end

            %% Check numbers of waveforms of each channel
            nWaveList = zeros(1,nEnabledChannel);
            for ii = 1:nEnabledChannel
                nWaveList(ii) = size(t{ii},1);
            end
            if all(nWaveList == nWaveList(1))
                nWave = nWaveList(1) + 1;
            else
                obj.closeSpec
                error("The numbers of waveforms of each channel have to be the same.")
            end

            %% Set the peak-to-peak values
            amp = zeros(1,nEnabledChannel);
            for ii = 1:nEnabledChannel
                for jj = 1:(nWave-1)
                    amp(ii) = max(amp(ii),max(abs(t{ii}.Sample{jj})));
                end
                if obj.OutputLoad(ii) == "50"
                    oLim = obj.OutputLimit;
                else
                    oLim = obj.OutputLimit * 2;
                end
                if amp(ii) > oLim(2)
                    obj.closeSpec
                    error("The amplitude of the waveform exceeds the output limit.")
                elseif amp(ii) < oLim(1)
                    amp(ii) = oLim(1);
                end
                if obj.OutputLoad(ii) == "50"
                    [~,obj.Device] = spcMSetupAnalogOutputChannel(obj.Device, enabledChannel(ii)-1, amp(ii)*1e3, 0, 0, obj.RegMap('SPCM_STOPLVL_ZERO'), 0, 0);
                else
                    [~,obj.Device] = spcMSetupAnalogOutputChannel(obj.Device, enabledChannel(ii)-1, amp(ii)/2*1e3, 0, 0, obj.RegMap('SPCM_STOPLVL_ZERO'), 0, 0);
                end
            end

            %% Set channel selection (bit masks)
            bitAll = int64(2.^(enabledChannel-1));
            bitMask = bitAll(1);
            for ii = 1:(numel(bitAll)-1)
                bitMask = bitor(bitMask,bitAll(ii+1));
            end
            bitMaskH = int32(0);
            bitList = find(bitget(bitMask,33:64));
            for ii = 1:numel(bitList)
                bitMaskH = bitset(bitMaskH,bitList(ii));
            end
            bitMaskL = uint32(0);
            bitList = find(bitget(bitMask,1:32));
            for ii = 1:numel(bitList)
                bitMaskL = bitset(bitMaskL,bitList(ii));
            end
            [~,obj.Device] = spcMSetupModeRepSequence(obj.Device, bitMaskH, bitMaskL, nWave, 0); 

            %% Tailor the waveforms (segment sizes and scaling)
            sample = cell(nWave,nEnabledChannel);
            scale=32767;            

            for jj = 1:nWave
                segSize = zeros(1,nEnabledChannel);
                for ii = 1:nEnabledChannel
                    if jj == nWave
                        sample{jj,ii} = zeros(1,segmentSizeMinimum);
                    else
                        sample{jj,ii} = t{ii}.Sample{jj};
                    end
                    if numel(sample{jj,ii}) < segmentSizeMinimum
                        % Pad to minimum segment size by linear extrapolation of the tail
                        nPad = segmentSizeMinimum - numel(sample{jj,ii});
                        padIdx = (numel(sample{jj,ii})+1):(numel(sample{jj,ii})+nPad);
                        % Note: keep original behavior; this is a syntax-only correction to avoid linter parse error
                        sample{jj,ii} = [sample{jj,ii}, interp1(1:numel(sample{jj,ii}), sample{jj,ii}, padIdx, 'linear', 'extrap')]; %#ok<AGROW>
                    end
                    remainder=32-mod(numel(sample{jj,ii}), 32);
                    segSize(ii) = ceil(numel(sample{jj,ii})/32)*32;
                    if mod(numel(sample{jj,ii}), 32)
                        padIdx2 = 11:(remainder+10);
                        tail = sample{jj,ii}(max(end-9,1):end);
                        sample{jj,ii} = [sample{jj,ii}, interp1(1:numel(tail), tail, padIdx2, 'linear', 'extrap')]; %#ok<AGROW>
                    end
                    sample{jj,ii} = sample{jj,ii} * scale / amp(ii);
                end
                if ~all(segSize == segSize(1))
                    obj.closeSpec
                    error("The segment sizes of each channel have to be the same for each uploaded segment.")
                end
                errorCode = spcm_dwSetParam_i32(obj.Device.hDrv, obj.RegMap('SPC_SEQMODE_WRITESEGMENT'),jj-1); % explicit write
                errorCode = spcm_dwSetParam_i32(obj.Device.hDrv, obj.RegMap('SPC_SEQMODE_SEGMENTSIZE'), segSize(1));
                errorCode = spcm_dwSetData(obj.Device.hDrv, 0, segSize(1), nEnabledChannel, 0, sample{jj,:}); %#ok<NASGU>
            end

            %% Determine the order (sequence)
            for ii = 1:nWave
                if ii ~= nWave
                    switch t{1}.PlayMode(ii)
                        case "Repeat"
                            [~,obj.Device] = spcMSetupSequenceStep(obj.Device,ii-1,ii,ii-1,t{1}.NRepeat(ii),0);
                        case "RepeatTilTrigger"
                            [~,obj.Device] = spcMSetupSequenceStep(obj.Device,ii-1,ii,ii-1,1,1);
                    end
                else
                    [~,obj.Device] = spcMSetupSequenceStep(obj.Device,ii-1,0,ii-1,1,1); % loop zero output until trigger
                end
            end

            %% Activate Card
            commandMask = bitor(obj.RegMap('M2CMD_CARD_START'), obj.RegMap('M2CMD_CARD_ENABLETRIGGER'));
            errorCode = spcm_dwSetParam_i32(obj.Device.hDrv, obj.RegMap('SPC_M2CMD'), commandMask);

            if (errorCode ~= 0)
                [~, obj.Device] = spcMCheckSetError (errorCode, obj.Device);
                if errorCode == obj.ErrorMap('ERR_TIMEOUT')
                    errorCode = spcm_dwSetParam_i32 (obj.Device.hDrv, obj.RegMap('SPC_M2CMD'), obj.RegMap('M2CMD_CARD_STOP'));
                    fprintf (' OK\n ................... replay stopped\n');
                else
                    spcMErrorMessageStdOut (obj.Device, 'Error: spcm_dwSetParam_i32:\n\t', true);
                    obj.closeSpec
                    return;
                end
            end

            %% Check if upload is successful
            s = obj.check;
            if s
                for ii = enabledChannel
                    disp(obj.Name + " channel" + num2str(ii) + " uploaded [" + obj.WaveformList{ii}.Name +"] successfully.")
                end
                obj.saveObject;
            end
            obj.closeSpec;
        end

        function close(obj)
            % Placeholder (Spectrum cards close in :meth:`closeSpec`).
        end
        
        function closeSpec(obj)
            % Close the Spectrum device if connected.
            if isempty(obj.Device)
                warning("Device is not connected.")
                return
            else
                spcMCloseCard(obj.Device);
            end
        end
    
        function status = check(obj)
            % Check Spectrum device status and sequence option presence.
            status = false;
            if isempty(obj.Device)
                error("Device is not connected.")
            elseif obj.Device.cardFunction ~= obj.RegMap('SPCM_TYPE_AO')
                spcMErrorMessageStdOut(obj.Device, 'Error: Card function not supported by this example\n', false);
            elseif bitand(obj.Device.featureMap, obj.RegMap('SPCM_FEAT_SEQUENCE')) == 0
                spcMErrorMessageStdOut(obj.Device, 'Error: Sequence Mode Option not installed. Example was done especially for this option!\n', false);
            elseif string(obj.Device.errorText) ~= "No Error"
                obj.closeSpec
                error(obj.Device.errorText)
            else
                status = true;
            end
        end
    
    end
end

