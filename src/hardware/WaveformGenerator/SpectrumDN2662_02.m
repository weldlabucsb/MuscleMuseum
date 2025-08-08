classdef SpectrumDN2662_02 < SpectrumWaveformGenerator
    %:class:`SpectrumDN2662_02` model configuration for a 2-ch Spectrum AWG.
    
    properties
        
    end
    
    methods
        function obj = SpectrumDN2662_02(resourceName,name)
            % Construct a :class:`SpectrumDN2662_02`.
            %
            % :param resourceName: Resource string for Spectrum card
            % :type resourceName: string
            % :param name: Device nickname
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@SpectrumWaveformGenerator(resourceName,name);
            obj.Model = "DN2662_02";
            obj.NChannel = 2;
            obj.IsOutput = [true,true];
            obj.Memory = 2e9;
            obj.SamplingRate = [1.25e9,1.25e9];
            obj.WaveformList = cell(1,obj.NChannel);
            obj.DisabledProperty = ["TriggerSlope","OutputMode"];
            obj.OutputLimit = [0.08,2];
        end
            
    end
end

