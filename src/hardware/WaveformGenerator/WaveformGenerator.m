classdef (Abstract) WaveformGenerator < Hardware
    %:class:`WaveformGenerator` abstract base for arbitrary waveform generators (AWGs).
    %
    % Provides common configuration for sampling, triggering, output mode/load,
    % and per-channel waveform lists. Subclasses (e.g., :class:`KeysightWaveformGenerator`,
    % :class:`SpectrumWaveformGenerator`) implement vendor-specific SCPI/driver logic.
    %
    % - **Typical workflow**: :meth:`connect` → :meth:`set` → :meth:`upload` → :meth:`check` → :meth:`close`
    properties
        SamplingRate double % Sampling rate per channel [Hz]
        TriggerSource string {mustBeMember(TriggerSource,{'External','Software','Immediate'})} = "External" % Trigger source
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise" % Trigger edge
        OutputMode string {mustBeMember(OutputMode,{'Gated','Normal'})} = "Normal" % Output mode
        IsOutput logical % Per-channel output enables
        OutputLoad string {mustBeMember(OutputLoad,{'50','Infinity'})} = "50" % Output load selection
        WaveformList cell % Per-channel waveform list objects
        IsDDSCompatible logical = 0 % Determines whether the given AWG is also compatible with DDS operation.
        IsDDSEnabled logical = 0 %Determines whether to use DDS mode or not in the AWG.
    end

    properties (SetAccess=protected)
        SamplingRateLimit (1,1) double % Maximum supported sampling rate [Hz]
        OutputLimit (1,2) double % [lower, upper] output amplitude at 50 Ω
    end
    
    methods
        function obj = WaveformGenerator(resourceName,name)
            % Construct a :class:`WaveformGenerator`.
            %
            % :param resourceName: Connection resource for the device
            % :type resourceName: string
            % :param name: Device nickname (default: [])
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@Hardware(resourceName,name)
        end
        
    end

    methods (Abstract)
        connect(obj)
        % Establish a connection/session to the AWG.
        set(obj)
        % Apply sampling/trigger/output configurations.
        upload(obj)
        % Upload waveforms/sequences for playback.
        close(obj)
        % Close the session.
        status = check(obj)
        % Return true if instrument reports no error.
    end
end

