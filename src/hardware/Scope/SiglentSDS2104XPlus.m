classdef SiglentSDS2104XPlus < SiglentScope
    % SiglentSDS2104XPlus: Model configuration for SDS2104X+
    %
    % Memory-depth clamping now lives in SiglentScope.set(); this class only
    % supplies the model-specific settings.

    methods
        function obj = SiglentSDS2104XPlus(resourceName, name)
            arguments
                resourceName string
                name string = string.empty
            end

            obj@SiglentScope(resourceName, name);
            obj.Model = "SDS2104X+";
            obj.SamplingRateMax = 2e9;
            obj.NSampleMax = 100e6;
            obj.NChannel = 4;
            obj.NSample = 1e5;
            obj.IsEnabled = false(1, obj.NChannel);
            obj.IsEnabled(1) = true;
            obj.VerticalOffset = zeros(1, obj.NChannel);
            obj.VerticalCoupling = repmat("DC", 1, obj.NChannel);
            obj.VerticalRange = repmat(2, 1, obj.NChannel);
            obj.TriggerMode = "Normal";
            obj.TriggerSource = "CH1";
            obj.TriggerSlope = "Rise";
            obj.TriggerLevel = 0;
            obj.DisabledProperty = ["NSampleMax"];

            obj.AcqResolution = "10Bits";
        end
    end

    methods (Access = protected)
        function tf = isInterleaved(obj)
            % Original behaviour kept: only a single enabled channel counts as interleaved.
            tf = sum(obj.IsEnabled) == 1;
        end
    end
end
