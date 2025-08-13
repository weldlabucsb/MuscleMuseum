classdef WaveformGeneratorConfig < MmSetting
    %WAVEFORMGENERATORSETTING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties

    end
    
    methods
        function obj = WaveformGeneratorConfig()
            obj@MmSetting()
        end
        
        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...      
                "DeviceModel", "string", ...      
                "ResourceName", "string" ...         
            );
            
            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "DefaultWg", ...      
                "DeviceModel", "Keysight33600A", ...     
                "ResourceName", "XXX" ...    
            );
            
            % Define default entries for initial table setup in :attr:`DefaultEntry`
        end
        
    end
end

