classdef TrapezoidalSinePulse < PartialPeriodicWaveform
    %:class:`TrapezoidalSinePulse` generates sine wave pulses with trapezoidal rise and fall transitions.
    %
    % Creates sine wave pulses with linear rise and fall transitions and a constant
    % amplitude plateau during the periodic portion. Similar to :class:`TrapezoidalPulse`
    % but with sine wave modulation. Inherits from :class:`PartialPeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a trapezoidal sine pulse with rise and fall times
    %     pulse = TrapezoidalSinePulse(amplitude = 2.0, frequency = 1000, ...
    %                                  riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with only rise time
    %     pulse = TrapezoidalSinePulse(amplitude = 1.0, frequency = 500, riseTime = 0.002);
    %     pulse.plot();
    
    properties

    end
    
    methods
        function obj = TrapezoidalSinePulse(options)
            %Construct a TrapezoidalSinePulse object.
            %
            % :param samplingRate: Sampling rate in Hz (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: [])
            % :type duration: double, optional
            % :param amplitude: Peak-to-peak amplitude (default: [])
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param frequency: Frequency in Hz (default: [])
            % :type frequency: double, optional
            % :param phase: Initial phase in radians (default: 0)
            % :type phase: double, optional
            % :param riseTime: Rise transition time in seconds (default: 0)
            % :type riseTime: double, optional
            % :param fallTime: Fall transition time in seconds (default: 0)
            % :type fallTime: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.frequency double = [];
                options.phase double = 0;

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
            %Get the time function for the trapezoidal sine pulse.
            %
            % Creates a function handle that generates sine wave pulse values
            % with linear rise and fall transitions. Implements the abstract
            % :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns trapezoidal sine pulse values
            % :rtype: function_handle
            amp = obj.Amplitude;
            freq = obj.Frequency;
            % td = obj.Duration;
            t0 = obj.StartTime;
            te = obj.EndTime;
            phi = obj.Phase;
            offset = obj.Offset;
            tr = obj.RiseTime;
            tf = obj.FallTime;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((((t-t0)./(tr)-1) .* (t<=(t0+tr)) - (t-(te-tf))./(tf) .* (t>=(te-tf)) + 1) .*...
                    (amp ./2 .* sin(2 * pi .* freq .* (t-t0) + phi)) + offset);
            end
        end
    end
end

