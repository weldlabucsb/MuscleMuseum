classdef SiglentSDS2104XPlus < SiglentScope
    % SiglentSDS2104XPlus: Model configuration for SDS2104X+
    %
    % Fully compatible with Scope base class constraints.

    properties
    end

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
            obj.TriggerMode = "Normal";   % ✅ valid
            obj.TriggerSource = "CH1";    % keep this format
            obj.TriggerSlope = "Rise";    % ✅ valid
            obj.TriggerLevel = 0;
            obj.DisabledProperty = ["NSampleMax"];
        end

        function set(obj)
            % =========================
            % Clamp memory depth to valid Siglent values
            % % =========================
            if sum(obj.IsEnabled) == 1 
                validDepths = [2e4, 2e5, 2e6, 20e6, 200e6];
            else
                validDepths = [1e4, 1e5, 1e6, 10e6, 100e6];
            end
            [~, idx] = min(abs(validDepths - obj.NSample));
            obj.NSample = validDepths(idx);
            
            % =========================
            % Call base SCPI implementation
            % =========================
            set@SiglentScope(obj);
        end
    end
end