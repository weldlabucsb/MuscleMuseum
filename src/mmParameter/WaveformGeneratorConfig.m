classdef WaveformGeneratorConfig < MmParameter
    %:class:`WaveformGeneratorConfig` stores device-level configuration for
    % waveform generators, such as model name and VISA resource.
    
    properties

    end
    
    methods
        function obj = WaveformGeneratorConfig()
            obj@MmParameter()
        end
        
        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...      
                "DeviceModel", "string", ...      
                "ResourceName", "string" ...         
            );
            
            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'DefaultWg'", ...      
                "DeviceModel", "'Keysight33600A'", ...     
                "ResourceName", "'XXX'" ...    
            );
            
            % Define default entries for initial table setup in :attr:`DefaultEntry`
        end
        
    end
end

