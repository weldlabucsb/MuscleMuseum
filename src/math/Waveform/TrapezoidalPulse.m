classdef TrapezoidalPulse < PartialPeriodicWaveform & ConstantTop
    %:class:`TrapezoidalPulse` generates trapezoidal pulse signals with rise and fall transitions.
    %
    % Creates pulse signals with linear rise and fall transitions and a constant
    % amplitude plateau. Useful for smooth pulse generation with controlled
    % transition times. Inherits from :class:`PartialPeriodicWaveform` and :class:`ConstantTop`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a trapezoidal pulse with rise and fall times
    %     pulse = TrapezoidalPulse(amplitude = 2.0, duration = 0.01, ...
    %                              riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with only rise time
    %     pulse = TrapezoidalPulse(amplitude = 1.0, duration = 0.01, riseTime = 0.002);
    %     pulse.plot();
    
    properties

    end
    
    methods
        function obj = TrapezoidalPulse(options)
            %Construct a TrapezoidalPulse object.
            %
            % :param samplingRate: Sampling rate in Hz (default: inherited)
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: inherited)
            % :type duration: double, optional
            % :param amplitude: Peak-to-peak amplitude (default: inherited)
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param riseTime: Rise transition time in seconds (default: 0)
            % :type riseTime: double, optional
            % :param fallTime: Fall transition time in seconds (default: 0)
            % :type fallTime: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     pulse = TrapezoidalPulse(amplitude = 2.0, duration = 0.01, ...
            %                              riseTime = 0.001, fallTime = 0.001);
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.riseTime double = 0;
                options.fallTime double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the trapezoidal pulse.
            %
            % Creates a function handle that generates trapezoidal pulse values
            % with linear rise and fall transitions. Implements the abstract
            % :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns trapezoidal pulse values
            % :rtype: function_handle
            amp = obj.Amplitude;
            t0 = obj.StartTime;
            te = obj.EndTime;
            offset = obj.Offset;
            tr = obj.RiseTime;
            tf = obj.FallTime;
            if tf == 0
                func = @trFunc;
            elseif tr == 0
                func = @tfFunc;
            else
                func = @tFunc;
            end
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((((t-t0)./(tr)-1) .* (t<=(t0+tr)) - (t-(te-tf))./(tf) .* (t>=(te-tf)) + 1) .*...
                    amp  + offset);
            end
            function waveOut = trFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((((t-t0)./(tr)-1) .* (t<=(t0+tr)) + 1) .*...
                    amp  + offset);
            end
            function waveOut = tfFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((- (t-(te-tf))./(tf) .* (t>=(te-tf)) + 1) .*...
                    amp  + offset);
            end
        end
    end
end

