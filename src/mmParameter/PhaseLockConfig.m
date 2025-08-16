classdef PhaseLockConfig < MmParameter
    %:class:`WaveformGeneratorConfig` stores device-level configuration for
    % waveform generators, such as model name and VISA resource.
    %
    % Typically joined into :class:`WaveformGeneratorSetting` to mirror
    % :attr:`DeviceModel` and :attr:`ResourceName` by device :attr:`Name`.
    
    properties

    end
    
    methods
        function obj = PhaseLockConfig()
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
                "Name", "'DefaultPhaseLock'", ...      
                "DeviceModel", "'VescentSlice'", ...     
                "ResourceName", "'XXX'" ...    
            );
            
            % Define default entries for initial table setup in :attr:`DefaultEntry`
        end
        
    end
end

