classdef TanhSinePulse < PartialPeriodicWaveform
    %:class:`TanhSinePulse` generates sine wave pulses with hyperbolic tangent rise and fall transitions.
    %
    % Creates sine wave pulses with smooth rise and fall transitions using
    % hyperbolic tangent (tanh) functions. Provides smooth, sigmoid-like
    % transitions for pulse shaping. Inherits from :class:`PartialPeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a tanh sine pulse with rise and fall times
    %     pulse = TanhSinePulse(amplitude = 2.0, frequency = 1000, ...
    %                           riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with only rise time
    %     pulse = TanhSinePulse(amplitude = 1.0, frequency = 500, riseTime = 0.002);
    %     pulse.plot();
    
    properties

    end
    
    methods
        function obj = TanhSinePulse(options)
            %Construct a TanhSinePulse object.
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
            % :param frequency: Frequency in Hz (default: inherited)
            % :type frequency: double, optional
            % :param phase: Initial phase in radians (default: 0)
            % :type phase: double, optional
            % :param riseTime: Rise transition time in seconds (default: 0)
            % :type riseTime: double, optional
            % :param fallTime: Fall transition time in seconds (default: 0)
            % :type fallTime: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     pulse = TanhSinePulse(amplitude = 2.0, frequency = 1000, ...
            %                           riseTime = 0.001, fallTime = 0.001);
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
            %Get the time function for the tanh sine pulse.
            %
            % Creates a function handle that generates sine wave pulse values
            % with hyperbolic tangent rise and fall transitions. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns tanh sine pulse values
            % :rtype: function_handle
            amp = obj.Amplitude;
            freq = obj.Frequency;
            t0 = obj.StartTime;
            te = obj.EndTime;
            phi = obj.Phase;
            offset = obj.Offset;
            tr = obj.RiseTime;
            tf = obj.FallTime;
            trCenter = t0 + tr / 2;
            tfCenter = te - tf / 2;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((tanh((t-trCenter)./(tr).* 2 * pi) - 1)./2 .* (t<=(t0+tr))...
                    - (tanh((t-tfCenter)./(tf).* 2 * pi) + 1)./2 .* (t>=(te-tf)) + 1) .*...
                    (amp ./2 .* sin(2 * pi .* freq .* (t-t0) + phi) + offset);
            end
        end
    end
end

