classdef VescentSlice < VescentPhaseLock
    %:class:`VescentSlice` concrete Vescent module with model and frequency limits.
    
    properties
        
    end
    
    methods
        function obj = VescentSlice(resourceName,name)
            arguments
                resourceName string
                name string = string.empty
            end
            obj@VescentPhaseLock(resourceName,name);
            obj.Model = "Slice";
            obj.FrequencyLimit = [10,9500] * 1e6;
        end
    end
end

