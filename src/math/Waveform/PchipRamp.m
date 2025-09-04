classdef PchipRamp < PchipPulse
    %:class:`LinearRamp` generates a linear ramp waveform.
    %
    % Creates a waveform that linearly transitions from a start value to a stop
    % value over a specified ramp time. Inherits from :class:`TrapezoidalPulse`
    % with zero fall time to create a pure ramp.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Basic linear ramp
    %     ramp = LinearRamp(startValue = 0, stopValue = 5, rampTime = 0.01);
    %     ramp.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Negative ramp
    %     ramp = LinearRamp(startValue = 10, stopValue = 0, rampTime = 0.005);
    %     ramp.plot();
    
    properties
        StartValue double = 0 % Initial value of the ramp.
        StopValue double = 0 % Final value of the ramp.
        RampTime double = 0 % Duration of the ramp transition in seconds.
    end
    
    methods
        function obj = PchipRamp(options)
            %Construct a LinearRamp object.
            %
            % :param samplingRate: Sampling rate in Hz (default: inherited)
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Total duration in seconds (default: inherited)
            % :type duration: double, optional
            % :param startValue: Initial ramp value (default: 0)
            % :type startValue: double, optional
            % :param stopValue: Final ramp value (default: 0)
            % :type stopValue: double, optional
            % :param rampTime: Ramp duration in seconds (default: 0)
            % :type rampTime: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     ramp = LinearRamp(startValue = 0, stopValue = 10, rampTime = 0.01);
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.startValue double = 0;
                options.stopValue double = 0;
                options.rampTime double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
            obj.FallTime = 0;
        end

        function set.RampTime(obj,val)
            %Set the ramp time and update rise time.
            %
            % :param val: Ramp duration in seconds
            % :type val: double
            obj.RampTime = val;
            obj.RiseTime = val;
        end

        function set.StartValue(obj,val)
            %Set the start value and update offset and amplitude.
            %
            % :param val: Initial ramp value
            % :type val: double
            obj.StartValue = val;
            obj.Offset = val;
            obj.Amplitude = obj.StopValue - val;
        end

        function set.StopValue(obj,val)
            %Set the stop value and update offset and amplitude.
            %
            % :param val: Final ramp value
            % :type val: double
            obj.StopValue = val;
            obj.Offset = obj.StartValue;
            obj.Amplitude = val - obj.StartValue;
        end
        
    end
end

