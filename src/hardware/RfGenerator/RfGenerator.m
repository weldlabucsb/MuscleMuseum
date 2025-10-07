classdef (Abstract) RfGenerator < Hardware
    %:class:`RfGenerator` abstract base for RF signal generators.
    %
    % Provides common timing/trigger/output configuration for RF sources and
    % a minimal control API. Subclasses implement vendor-specific behavior.
    %
    % - **Typical workflow:** :meth:`connect` → :meth:`set` → :meth:`upload` → :meth:`check` → :meth:`close`
    
    properties
        SamplingRate double % Sampling rate [Hz] for generated signal
        TriggerSource string {mustBeMember(TriggerSource,{'External','Software','Immediate'})} = "External" % Trigger source selection
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise" % Trigger edge selection
        OutputMode string {mustBeMember(OutputMode,{'Gated','Normal'})} = "Normal" % Output mode ('Gated' or 'Normal')
        IsOutput logical % Per-channel output enable flags
        OutputLoad string {mustBeMember(OutputLoad,{'50','Infinity'})} = "50" % Output load setting ('50' or 'Infinity')
        WaveformList cell % Cell array of per-channel waveforms to output
    end
    
    methods
        function obj = RfGenerator(resourceName,name)
            % Construct a :class:`RfGenerator`.
            %
            % :param resourceName: Connection resource identifier (e.g., VISA)
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
        % Establish a connection to the RF generator.
        set(obj)
        % Configure sample rate, trigger, load, and output mode.
        upload(obj)
        % Upload or arm waveforms for output.
        close(obj)
        % Close the instrument connection.
        status = check(obj)
        % Query instrument state; returns true if status is OK.
    end
end

