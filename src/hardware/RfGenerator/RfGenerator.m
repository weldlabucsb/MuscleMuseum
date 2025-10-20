classdef (Abstract) RfGenerator < Hardware
    %WAVEFORMGENERATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        SamplingRate double
        TriggerSource string {mustBeMember(TriggerSource,{'External','Software','Immediate'})} = "External"
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise"
        OutputMode string {mustBeMember(OutputMode,{'Gated','Normal'})} = "Normal"
        IsOutput logical
        OutputLoad string {mustBeMember(OutputLoad,{'50','Infinity'})} = "50"
        WaveformList cell
    end
    
    methods
        function obj = RfGenerator(resourceName,name)
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

