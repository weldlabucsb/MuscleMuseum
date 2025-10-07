classdef (Abstract) TektronixScope < Scope
    %:class:`TektronixScope` base wrapper for Tektronix oscilloscopes.
    %
    % Provides connection, configuration, readout, and close helpers using
    % MATLAB Quick-Control Oscilloscope. Implements :meth:`connect`, :meth:`set`,
    % :meth:`read`, :meth:`close`, and :meth:`check` in terms of the common
    % :class:`Scope` interface.
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
            % Connect to the instrument using :attr:`ResourceName`.
            obj.Oscilloscope = oscilloscope;
            obj.Oscilloscope.Timeout = 5;
            obj.Oscilloscope.Resource = obj.ResourceName;
            obj.Oscilloscope.connect;
        end

        function set(obj)
            % Apply acquisition and trigger settings and per-channel config.
            %
            % Uses :attr:`Duration`, :attr:`NSample`, :attr:`TriggerMode`,
            % :attr:`TriggerSlope`, :attr:`TriggerLevel`, :attr:`TriggerSource`,
            % and channel arrays (:attr:`IsEnabled`, :attr:`VerticalCoupling`,
            % :attr:`VerticalOffset`, :attr:`VerticalRange`).
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
            % Read waveforms from enabled channels and update :attr:`Sample`.
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
            % Gracefully close the instrument session.
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
            % Validate instrument state and configuration limits.
            %
            % :return: True when the instrument is connected, open, and within limits
            % :rtype: logical
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

