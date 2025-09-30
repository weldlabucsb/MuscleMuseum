classdef Keysight33500B < KeysightWaveformGenerator
    %:class:`Keysight33500B` model configuration for a 2-ch AWG.
    
    properties
        
    end
    
    methods
        function obj = Keysight33500B(resourceName,name)
            % Construct a :class:`Keysight33500B`.
            %
            % :param resourceName: VISA resource name
            % :type resourceName: string
            % :param name: Device nickname
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@KeysightWaveformGenerator(resourceName,name);
            obj.Model = "33500B";
            obj.NChannel = 2;
            obj.IsOutput = [true,true];
            obj.OutputLoad = ["50","50"];
            obj.OutputMode = ["Normal","Normal"];
            obj.TriggerSource = ["External","External"];
            obj.TriggerSlope = ["Rise","Rise"];
            obj.Memory = 16e6;
            obj.SamplingRate = [250e6,250e6];
            obj.SamplingRateLimit = 250e6;
            obj.WaveformList = cell(1,obj.NChannel);
            obj.OutputLimit = [10,10];
        end
            
    end
end

