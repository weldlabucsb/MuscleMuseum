classdef Keysight33600A < KeysightWaveformGenerator
    %:class:`Keysight33600A` model configuration for a 2-ch high-speed AWG.
    
    properties
        
    end
    
    methods
        function obj = Keysight33600A(resourceName,name)
            % Construct a :class:`Keysight33600A`.
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
            obj.Model = "33600A";
            obj.NChannel = 2;
            obj.IsOutput = [true,true];
            obj.Memory = 4e6;
            obj.SamplingRate = [1e9,1e9];
            obj.WaveformList = cell(1,obj.NChannel);
        end
    
    end
end

