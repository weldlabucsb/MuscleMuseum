classdef SiglentSDS2204XHD < SiglentScope
    % SiglentSDS2204XHD: Model configuration for SDS2204X HD (12-bit, 200 MHz, 4 ch)
    %
    % Datasheet (EN02B):
    %   2 GSa/s / 200 Mpts/ch interleaved   (only one of C1/C2 and only one of C3/C4 on)
    %   1 GSa/s / 100 Mpts/ch non-interleaved
    %   Average / ERES modes limit depth to 20 Mpts (interleaved) / 10 Mpts.
    %   12-bit is native: there is no ":ACQuire:RESolution" setting to send.

    methods
        function obj = SiglentSDS2204XHD(resourceName, name)
            arguments
                resourceName string
                name string = string.empty
            end

            obj@SiglentScope(resourceName, name);
            obj.Model = "SDS2204X HD";
            obj.SamplingRateMax = 2e9;
            obj.NSampleMax = 200e6;
            obj.NChannel = 4;
            obj.NSample = 2e5;
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

            obj.AcqResolution = "";          % native 12-bit
            obj.SetMemoryManagement = true;  % make sure ACQ:MDEP is honoured
        end
    end

    methods (Access = protected)
        function sr = currentSamplingRateMax(obj)
            if obj.isInterleaved()
                sr = 2e9;
            else
                sr = 1e9;
            end
        end
    end
end
