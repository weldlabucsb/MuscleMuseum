classdef (Abstract) SpectrumWaveformGenerator < WaveformGenerator
    %:class:`SpectrumWaveformGenerator` Spectrum-specific AWG implementation.
    %
    % Requires the Spectrum MATLAB driver (see vendor site) to be on MATLAB's
    % path. Implements device-specific connection (:meth:`connectSpec`),
    % configuration (:meth:`setSpec`), and upload sequencing (:meth:`upload`).
    %
    % - **Workflow:** :meth:`upload` → :meth:`connectSpec` → :meth:`setSpec` → segment/sequence prep → program card → status check → :meth:`closeSpec`.
    % - **Segment rules:** All enabled channels must have equal segment counts; each
    %   segment must meet board minimum length and be padded to a multiple of 32 samples.
    % - **Scaling:** Samples are mapped to 16-bit DAC range; amplitudes are validated
    %   against :attr:`OutputLimit` considering :attr:`OutputLoad`.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    awg = SpectrumDN2662_02("PCI::SPCM0", name="SpecAWG");
    %    awg.SamplingRate = [1.25e9, 1.25e9];
    %    awg.IsOutput = [true true];
    %    % ... set awg.WaveformList per channel ...
    %    awg.upload();
    %
    
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
            % No persistent session (Spectrum connects per-upload).
            %
            % Spectrum AWG MATLAB driver requires closing/opening the card
            % around uploads; use :meth:`connectSpec` within :meth:`upload`.
            
            % Briefly connects to retrieve some parameters from the device.
            obj.connectSpec;
            obj.closeSpec;
        end
        
        function connectSpec(obj)
            % Initialize Spectrum maps and open the device.
            %
            % Loads :attr:`RegMap` and :attr:`ErrorMap`, frees lingering sessions,
            % and opens the card using :attr:`ResourceName`.
            %
            % :raises error: If Spectrum MATLAB library is missing or card open fails
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

            % Checks that Device has DDS option installed
            try
            dds_featureMask = bitor (obj.RegMap('SPCM_FEAT_EXTFW_DDS20'), obj.RegMap('SPCM_FEAT_EXTFW_DDS50'));
            if ~(bitand (obj.Device.extFeatureMap, dds_featureMask) == 0)
                obj.IsDDSCompatible=1;
            end
            catch
                error("Please update your matlab Spectrum driver to use DDS")
            end
        end


        

        function set(obj)
            % Unused (Spectrum initializes per-upload).
        end
        
        function setSpec(obj)
            % Configure sampling rate, trigger, and enabled outputs for Spectrum device.
            %
            % Sets card PLL to requested :attr:`SamplingRate(1)`, programs trigger
            % source based on :attr:`TriggerSource(1)`, and enables channels per
            % :attr:`IsOutput`.
            %
            % :raises error: On PLL setup failure or subsequent Spectrum errors
            obj.check;

            %% Set sampling rate
            if obj.IsDDSEnabled %% DDS uses max sampling rate for the clock, sequence rate is used differently.
                [success,obj.Device] = spcMSetupClockPLL(obj.Device, obj.SamplingRateLimit, 0);
                if (success == false)
                    obj.closeSpec
                    spcMErrorMessageStdOut(obj.Device, 'Error: spcMSetupClockPLL:\n\t', true);
                    return;
                end
            else


                [success,obj.Device] = spcMSetupClockPLL(obj.Device, obj.SamplingRate(1), 0);
                if (success == false)
                    obj.closeSpec
                    spcMErrorMessageStdOut(obj.Device, 'Error: spcMSetupClockPLL:\n\t', true);
                    return;
                end
                sr = obj.Device.setSamplerate;
                obj.SamplingRate(:) = deal(sr);
            end

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
            % Channels must have identical segment counts; each segment stores
            % samples for all enabled channels. Segments are padded to 32-sample
            % boundaries and meet board minimums; scaling maps to 16-bit DAC.
            %
            % :raises error: On mismatched segment counts, segment size mismatch,
            %   output limit violations, or Spectrum driver errors
            %% Set and connect
            obj.connectSpec;
            obj.setSpec;

            if obj.IsDDSEnabled
                disp("Using DDS for upload")
                state=obj.uploadDDS;
                if state
                    obj.closeSpec;
                    disp(obj.Name + " channel" + num2str(1) + " uploaded [" + obj.WaveformList{1}.Name +"] successfully.")
                    return
                else
                    disp("DDS Upload Failed, using normal AWG operation.")
                end
                
            end

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
                obj.WaveformList{enabledChannel(ii)}.NPeriodPerCycle = 0; % For spectrum AWG, we don't want to split a periodic waveform into parts and upload
                t{ii} = obj.WaveformList{enabledChannel(ii)}.WaveformPrepared; % Load the prepared waveforms
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
                        sample{jj,ii} = [sample{jj,ii},interp1(sample{jj,ii},(numel(sample{jj,ii})+1):segmentSizeMinimum,'linear','extrap')];
                    end
                    remainder=32-mod(numel(sample{jj,ii}), 32);
                    segSize(ii) = ceil(numel(sample{jj,ii})/32)*32;
                    if mod(numel(sample{jj,ii}), 32)
                        sample{jj,ii} = [sample{jj,ii},interp1(sample{jj,ii}(end-9:end),11:(remainder+10),'linear','extrap')];
                    end
                    sample{jj,ii} = sample{jj,ii} * scale / amp(ii);
                end
                if ~all(segSize == segSize(1))
                    obj.closeSpec
                    error("The segment sizes of each channel have to be the same for each uploaded segment.")
                end
                errorCode = spcm_dwSetParam_i32(obj.Device.hDrv, obj.RegMap('SPC_SEQMODE_WRITESEGMENT'),jj-1); % somehow we have to write the output explicitly if we call spcm_dwSetParam_i32
                errorCode = spcm_dwSetParam_i32(obj.Device.hDrv, obj.RegMap('SPC_SEQMODE_SEGMENTSIZE'), segSize(1));
                errorCode = spcm_dwSetData(obj.Device.hDrv, 0, segSize(1), nEnabledChannel, 0, sample{jj,:});
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
                    [~,obj.Device] = spcMSetupSequenceStep(obj.Device,ii-1,0,ii-1,1,1); %loop the zero output until trigger
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

        function state=uploadDDS(obj)
                %Returns state=1 if sequence completes upload. If state=0, defaults
                %to normal upload without DDS
            %% Check that waveforms are indeed compatible
            status=obj.checkDDSUsable;
            if ~status
                state=0;
                return
            end

            %% Load prepared waveforms (only for 1st channel), extract amplitude, frequency and phase modulation.
            % t = cell(1,nEnabledChannel);
            % for ii = 1:nEnabledChannel
            %     obj.WaveformList{enabledChannel(ii)}.SamplingRate = obj.SamplingRate(1);
            %     obj.WaveformList{enabledChannel(ii)}.NPeriodPerCycle = 0; % For spectrum AWG, we don't want to split a periodic waveform into parts and upload
            %     t{ii} = obj.WaveformList{enabledChannel(ii)}.WaveformPrepared; % Load the prepared waveforms
            % end
            TimeStep=1/obj.SamplingRate(1);

            waveformprep=obj.WaveformList{1};
            waveformprep.SamplingRate=obj.SamplingRate(1);
            corecount=length(waveformprep.WaveformOrigin); %Number of cores

            if corecount>20
                state=0;
                disp('Too many frequency components for DDS mode. Can only run 20 frequencies.')
                return
            end
            
            isFreqMod=zeros(1, (corecount));
            isAmpMod=zeros(1,(corecount));
            isPhaseMod=zeros(1, (corecount));
            
            AmpModWaveform=cell(1, corecount);
            FreqModWaveform=cell(1, corecount);
            PhaseModWaveform=cell(1, corecount);
            StartTimes=zeros(1,corecount);
            EndTimes=zeros(1,corecount);
            %%Determine if each one is using phase mod, frequency mod, or
            %%amp mod
            for ii=1:corecount
                worigin=waveformprep.WaveformOrigin{ii};
                if ~isempty(worigin.AmplitudeModulation)
                    isAmpMod(ii)=1;
                end
                if ~isempty(worigin.PhaseModulation)
                    isPhaseMod(ii)=1;
                end
                if ~isempty(worigin.FrequencyModulation)
                    isFreqMod(ii)=1;
                end

                [ampModfunc,freqModfunc,phaseModfunc] = worigin.getModulation();
                t=0 : worigin.TimeStep : worigin.EndTime;
                t0=worigin.StartTime;
                td = worigin.Duration;
                

                AmpModWaveform{ii} = (t>=t0 & t<=(t0+td)) .* (worigin.Amplitude+ampModfunc(t-t0)) ./2;
                FreqModWaveform{ii}= (t>=t0 & t<=(t0+td)) .* (worigin.Frequency+freqModfunc(t-t0));
                PhaseModWaveform{ii}= (t>=t0 & t<=(t0+td)) .* (worigin.Phase+phaseModfunc(t-t0));
                StartTimes(ii)=t0;
                EndTimes(ii)=worigin.EndTime;
                
            end
            
            tvec=0:TimeStep:max(EndTimes);
            
            %Need to figure out when each waveform starts to make sure they
            %are timed with the correct delays.


            %% Calculate the number of steps to upload to ensure sequence can be completed. Currently limited to 4k steps
            steps=0;
            steps=steps+8+6*corecount; %Add number of steps needed for setup and connect core
            if strcmp(obj.TriggerSource(1), "External")
                steps=steps+3;
            end

            if sum(isPhaseMod)>0
                steps=steps+1;
            end
            
            %Add number of steps per each modulated waveform.
            for ii=1:corecount
                if isFreqMod(ii)
                    steps=steps+length(FreqModWaveform{ii});
                end
                if isAmpMod(ii)
                    steps=steps+length(AmpModWaveform{ii});
                end
                if isPhaseMod(ii)
                    steps=steps+length(PhaseModWaveform{ii});
                end
                
            end
            if steps>3950 %Limit is 4000 but giving space for error.
                state =0; 
                disp('Number of steps are larger than DDS can handle currently')
                return
            end

            if length(tvec)>4000
                state=0;
                disp('Sampling Rate is too high')
                return
            end

            %% Check that amplitude of all waveforms is within limits, calculate max amp
            maxamp=zeros(1, corecount);
            coreamp=zeros(1,corecount);
            for ii=1:corecount
                maxamp(ii)=max(AmpModWaveform{ii});
                coreamp(ii)=waveformprep.WaveformOrigin{ii}.Amplitude;
            end

            ampsum=sum(maxamp);
            if obj.OutputLoad(1) == "50"
                if ampsum>2
                    state=0;
                    disp("Cumulative amplitudes are too large")
                    return;
                end
            else
                if ampsum>4
                    state=0;
                    disp("Cumulative amplitudes are too large")
                    return;
                end
                
            end

            %% Rescale Amp to be Normalized against max amp
            
            coreamp=coreamp/ampsum;
            for ii=1:corecount
                AmpModWaveform{ii}=AmpModWaveform{ii}/ampsum;
            end

            
            


            %% Enable DDS

            errorCode = spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_CARDMODE'),    obj.RegMap('SPC_REP_STD_DDS')); % DDS mode
            
                %Need to figure out how to calculate this
            if obj.OutputLoad(1) == "50"
                    [~,obj.Device] = spcMSetupAnalogOutputChannel(obj.Device, 0, ampsum*1e3, 0, 0, obj.RegMap('SPCM_STOPLVL_ZERO'), 0, 0);
                else
                    [~,obj.Device] = spcMSetupAnalogOutputChannel(obj.Device, 0, ampsum/2*1e3, 0, 0, obj.RegMap('SPCM_STOPLVL_ZERO'), 0, 0);
            end
        
            errorCode = spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_M2CMD'), obj.RegMap('M2CMD_CARD_WRITESETUP'));
            if (errorCode ~= 0)
                [success, cardInfo] = spcMCheckSetError (errorCode, cardInfo);
                spcMErrorMessageStdOut (cardInfo, 'Error: spcm_dwSetParam_i64:\n\t', true);
                return;
            end

            %% Reset DDS and setup DMA
            errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_RESET'));
            errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_DATA_TRANSFER_MODE'),obj.RegMap('SPCM_DDS_DTM_DMA')); %Run right after reset
            if sum(isPhaseMod)>0
                errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_PHASE_BEHAVIOUR'),obj.RegMap('SPCM_DDS_PHASE_SHIFT')); %Run right after reset
            end
            errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_WRITE_TO_CARD')); %  write all dds settings to card


            %% Setup Cores, Set Initial Frequency and Triggers
            for ii=1:corecount
                frequency=waveformprep.WaveformOrigin{ii}.Frequency;
                errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORES_ON_CH0'), obj.RegMap('SPCM_DDS_CORE0')+ii-1);
                errorCode= spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP')+ii-1, AmpModWaveform{ii}(1)); %Amps are normalized to 1.
                errorCode= spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_FREQ'), frequency+FreqModWaveform{ii}(1));
            end
            
            switch obj.TriggerSource(1)
                case "External"
                    errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_TRG_SRC'), obj.RegMap('SPCM_DDS_TRG_SRC_CARD'));
                    errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_EXEC_AT_TRG')); % execute at trigger to check that first trigger works
                    errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_WRITE_TO_CARD')); %  write all dds settings to card
                case "Immediate"
                otherwise
            end
            
            %% Setup Timer for Step Advance in sequence
            errorCode= spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_TRG_TIMER'), TimeStep);
            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_TRG_SRC'), obj.RegMap('SPCM_DDS_TRG_SRC_TIMER'));
            errorCode= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_EXEC_AT_TRG')); % execute at trigger to check that first trigger works
            %% Write Each Advance in Frequency, Phase, and Mod for each core
            tracktime=0;
            for ii=1:length(tvec)-1
                tracktime=tracktime+TimeStep;
                for jj=1:corecount
                    if tvec(ii)<StartTimes(jj) && (tvec(ii+1)>=StartTimes(jj))
                        ampslope=(AmpModWaveform{jj}(ii+1)-AmpModWaveform{jj}(ii+1))/TimeStep;
                        errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP_SLOPE')+jj-1, ampslope);

                    end
                    if ii>2
                        if tvec(ii-1)<StartTimes(jj) && (tvec(ii)>=StartTimes(jj)) && ~isAmpMod(jj)
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP_SLOPE')+jj-1, 0);
   
                            %Turn off ampmod if not modulating amp after
                            %starting waveform.
                        end
                    end

                    if tvec(ii)>=StartTimes(jj) && ((tvec(ii+1))<EndTimes(jj))
                        %%Add FrequencyMod if available
                        if isFreqMod(jj)
                            freqslope=(FreqModWaveform{jj}(ii+1)-FreqModWaveform{jj}(ii+1))/TimeStep;
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_FREQ_SLOPE')+jj-1, freqslope);
                        end
                    
                    %%Add AmpMod if available or if delay is late
                        if isAmpMod(jj)
                            ampslope=(AmpModWaveform{jj}(ii+1)-AmpModWaveform{jj}(ii+1))/TimeStep;
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP_SLOPE')+jj-1, ampslope);
                        end
                    %%Add PhaseMod if available if 
                        if isPhaseMod(jj)
                            phaseshift=(PhaseModWaveform{jj}(ii+1)-PhaseModWaveform{jj}(ii+1));
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_PHASE')+jj-1, phaseshift);
                        end
                    end
                    if tvec(ii)<EndTimes(jj) && tvec(ii+1)>=EndTimes(jj)
                       %Turn off amp, amp slope, and frequency at 0.
                        if isAmpMod(jj)
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP_SLOPE')+jj-1, 0);
                        end
                        if isFreqMod(jj)
                            errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_FREQ_SLOPE')+jj-1, 0);
                        end
                        errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP')+jj-1, 0);
                       
                    end
                end
                error=spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_EXEC_AT_TRG'));
            end

            %% Turn off all frequency ramps and set amplitude to 0
            for jj=1:corecount
                %Turn off amp, amp slope, and frequency at 0.
                if isAmpMod(jj)
                    errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP_SLOPE')+jj-1, 0);
                end
                if isFreqMod(jj)
                    errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_FREQ_SLOPE')+jj-1, 0);
                end
                errorCode=spcm_dwSetParam_d64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CORE0_AMP')+jj-1, 0);
            end
            error=spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_EXEC_AT_TRG'));
            error= spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_DDS_CMD'), obj.RegMap('SPCM_DDS_CMD_WRITE_TO_CARD')); %  write all dds settings to card


        

                
            %% Activate Card with a Force Trigger to start the first step and set trigger. Use Try Catch in Case there's an unknown issue with the uploaded sequence.
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

            % Force Trigger
            errorCode = spcm_dwSetParam_i64 (obj.Device.hDrv, obj.RegMap('SPC_M2CMD'), obj.RegMap('M2CMD_CARD_FORCETRIGGER'));
            %First trigger must be a force trigger to set up other trigger types.

            state=1;
            return

            
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

        function value= checkDDSUsable(obj)
            targetoutput=zeros(1,length(obj.IsOutput));
            if ~isequal(size(obj.IsOutput), size(targetoutput))
                targetoutput=targetoutput';
            end
            targetoutput(1)=1;
            matchchannel=(targetoutput==obj.IsOutput);
            waveform=obj.WaveformList{1};
            matchconcatmethod=strcmp(waveform.ConcatMethod, 'Simultaneous');
            matchwaveformtype=1;
            for ii=1:length(waveform.WaveformOrigin)
                if ~isa(waveform.WaveformOrigin{ii},'SineWaveModulated')
                    matchwaveformtype=0;
                end
            end
            usable= matchchannel & matchconcatmethod & matchwaveformtype;
            if usable
                value=1;
            else
                value=0;

            end 
        
        end
    
    end
end

