classdef (Abstract) TektronixScope < Scope
    %TEKTRONIXOSCILLOSCOPE Summary of this class goes here
    %   Detailed explanation goes here
    properties (SetAccess = protected,Transient)
        Oscilloscope  % MATLAB Quick-Control Oscilloscope object
    end

    methods
        function obj = TektronixScope(resourceName,name)
            arguments
                resourceName string
                name string = string.empty
            end
            obj@Scope(resourceName,name);
            obj.Manufacturer = "Tektronix";
            obj.SampleUnit = "V";
        end

        function connect(obj)
            obj.Oscilloscope = oscilloscope;
            obj.Oscilloscope.Timeout = 5;
            obj.Oscilloscope.Resource = obj.ResourceName;
            obj.Oscilloscope.connect;
        end

        function set(obj)
            obj.check;
            obj.Oscilloscope.AcquisitionTime = obj.Duration;
            obj.Oscilloscope.WaveformLength = obj.NSample;
            obj.Oscilloscope.TriggerMode = lowerFirst(obj.TriggerMode);
            if obj.TriggerSlope == "Rise"
                obj.Oscilloscope.TriggerSlope = "rising";
            else
                obj.Oscilloscope.TriggerSlope = "falling";
            end
            obj.Oscilloscope.TriggerLevel = obj.TriggerLevel;
            if obj.TriggerSource == "External"
                obj.Oscilloscope.TriggerSource = 'EXT';
            else
                obj.Oscilloscope.TriggerSource = obj.TriggerSource;
            end
            for ii = 1:obj.NChannel
                cName = "CH" + num2str(ii);
                if ~obj.IsEnabled(ii)
                    disableChannel(obj.Oscilloscope,cName)
                else
                    enableChannel(obj.Oscilloscope,cName)
                    configureChannel(obj.Oscilloscope,cName,'VerticalCoupling',obj.VerticalCoupling(ii))
                    configureChannel(obj.Oscilloscope,cName,'VerticalOffset',obj.VerticalOffset(ii))
                    configureChannel(obj.Oscilloscope,cName,'VeticalRange',obj.VerticalRange(ii))
                end
            end
        end

        function read(obj)
            obj.check;
            ChannelName = obj.Oscilloscope.ChannelsEnabled;
            ChannelName = string(ChannelName.');
            SampleData = cell(1,numel(ChannelName));
            [SampleData{:}] = obj.Oscilloscope.readWaveform;
            SampleData = cell2mat(SampleData.');
            obj.Sample = SampleData;
            obj.saveObject;
        end

        function close(obj)
            if isempty(obj.Oscilloscope)
                warning("Scope is not connected.")
                return
            elseif ~isvalid(obj.Oscilloscope)
                warning("Scope was deleted.")
                return
            elseif string(obj.Oscilloscope.Status) == "close"
                warning("Scope was closed.")
                return
            end
            obj.Oscilloscope.disconnect
            delete(obj.Oscilloscope)
        end

        function status = check(obj)
            if isempty(obj.Oscilloscope)
                error("Scope is not connected.")   
            elseif ~isvalid(obj.Oscilloscope)
                error("Scope object was deleted.")
            elseif string(obj.Oscilloscope.Status) == "close"
                error("Scope object was closed.")
            elseif obj.SamplingRateMax < obj.SamplingRate
                error("Scope sampling rate exceeds the limit")
            elseif obj.NSampleMax < obj.NSample
                error("Scope sampling number exceeds the limit")
            else
                status = true;
            end
        end
    end
end

