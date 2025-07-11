classdef (Abstract) WaveformGenerator < Hardware
    %WAVEFORMGENERATOR Subclass of Hardware, includes additional parameters
    %involved for operating an AWG
    %   Generalized class for AWGs, with some additional parameters and
    %   generic functions defined.
    %   Properties:
    %       SamplingRate: sample rate of waveform to be uploaded
    %       TriggerSource: String that describes the trigger used for the
    %       waveform, can be 'External', 'Software', or 'Immediate'.
    %       Default is 'External'
    %       TriggerSlope: Whether trigger happens on rise or fall of pulse,
    %       options are 'Rise' and 'Fall', default 'Rise'
    %       OutputMode: Tells whether the AWG outputs the full waveform or
    %       turns off when the trigger is off, option is 'Normal' and
    %       'Gated', default 'Normal
    %       IsOutput: A logical array that tells which of the NChannels are
    %       enabled or not.
    %       OutputLoad: Tells whether the output load is infinite or 50ohm.
    %       Options are '50' and 'Infinity', default '50'.
    %       WaveformList: Cell that stores the waveformlist object for each
    %       channel
    %       OutputLimit: (1,2) array telling the lower and upper limit
    %       values of the waveform being inputed
    %   Abstract Methods:
    %       connect(obj):
    %           Initializes connection to specific device
    %       set(obj):
    %           Setup device settings?
    %       upload(obj):
    %           Upload waveform to device
    %       close(obj):
    %           Terminate connection to device
    %       status=check(obj):
    %           Pings device for status and returns a given string or other
    %           method of notification.
    %
    
    properties
        SamplingRate double
        TriggerSource string {mustBeMember(TriggerSource,{'External','Software','Immediate'})} = "External"
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise"
        OutputMode string {mustBeMember(OutputMode,{'Gated','Normal'})} = "Normal"
        IsOutput logical
        OutputLoad string {mustBeMember(OutputLoad,{'50','Infinity'})} = "50"
        WaveformList cell
        OutputLimit (1,2) double % [lower,upper], At 50 Ohm
    end
    
    methods
        function obj = WaveformGenerator(resourceName,name)
            arguments
                resourceName string
                name string = string.empty
            end
            obj@Hardware(resourceName,name)
        end
        
    end

    methods (Abstract)
        connect(obj)
        set(obj)
        upload(obj)
        close(obj)
        status = check(obj)
    end
end

