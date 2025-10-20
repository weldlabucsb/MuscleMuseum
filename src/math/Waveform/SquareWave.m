classdef SquareWave < PeriodicWaveform
    %:class:`SquareWave` generates square wave signals with configurable duty cycle.
    %
    % Creates periodic square wave signals with adjustable amplitude, frequency,
    % phase, and duty cycle. The waveform alternates between high and low levels
    % based on the duty cycle percentage. Inherits from :class:`PeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a 50% duty cycle square wave
    %     square = SquareWave(frequency = 1000, amplitude = 2.0, duration = 0.01);
    %     square.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a 25% duty cycle square wave
    %     square = SquareWave(frequency = 500, amplitude = 1.0, dutyCycle = 0.25);
    %     square.plotOneCycle();
    
    properties
        DutyCycle double { ...
            mustBeGreaterThanOrEqual(DutyCycle,0), ...
            mustBeLessThanOrEqual(DutyCycle,1) } = 0.5 % Fraction of each period the waveform stays at its high level.
    end

    methods
        function obj = SquareWave(options)
            %Construct a SquareWave object.
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
            % :param phase: Phase in radians (default: 0)
            % :type phase: double, optional
            % :param dutyCycle: Duty cycle fraction [0,1] (default: 0.5)
            % :type dutyCycle: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     square = SquareWave(frequency = 1000, amplitude = 2.0, dutyCycle = 0.3);
            arguments
                options.samplingRate double = []
                options.startTime     double = 0
                options.duration      double = []
                options.amplitude     double = []
                options.offset        double = 0
                options.frequency     double = []
                options.phase         double = 0
                options.dutyCycle     double = 0.5
            end

            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end

        function func = TimeFunc(obj)
            %Get the time function for the square wave.
            %
            % Creates a function handle that generates square wave values
            % based on the configured amplitude, frequency, phase, and duty cycle.
            % Implements the abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns square wave values
            % :rtype: function_handle
            amp   = obj.Amplitude;
            off   = obj.Offset;
            freq  = obj.Frequency;
            phi   = obj.Phase;
            duty  = obj.DutyCycle;
            t0    = obj.StartTime;
            td    = obj.Duration;

            func = @tFunc;
            function waveOut = tFunc(t)
                % only valid between t0 and t0+td
                inWindow = (t >= t0) & (t <= t0 + td);

                % normalized phase in [0,1)
                normPh = mod(freq .* (t - t0) + phi/(2*pi), 1);

                % build ±half‐amplitude square
                sq = zeros(size(t));
                sq(normPh < duty)  =  amp/2;
                sq(normPh >= duty) = -amp/2;

                % add offset and mask outside [t0, t0+td]
                waveOut = inWindow .* (sq + off);
            end
        end
    end
end
