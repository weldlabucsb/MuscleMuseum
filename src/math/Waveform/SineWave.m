classdef SineWave < PeriodicWaveform
    %:class:`SineWave` generates a sinusoidal waveform.
    %
    % Creates a sine wave with specified amplitude, frequency, phase, and timing
    % parameters. The waveform is zero outside the specified duration.
    % Inherits from :class:`PeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Basic sine wave
    %     sine = SineWave(frequency = 1000, amplitude = 2.0, duration = 0.01);
    %     sine.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Sine wave with phase offset
    %     sine = SineWave(frequency = 500, amplitude = 1.0, phase = pi/4);
    %     sine.plot();
    
    properties
        
    end
    
    methods
        function obj = SineWave(options)
            %Construct a SineWave object.
            %
            % :param samplingRate: Sampling rate in Hz (default: inherited)
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: inherited)
            % :type duration: double, optional
            % :param amplitude: Waveform amplitude (default: inherited)
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param frequency: Frequency in Hz (default: inherited)
            % :type frequency: double, optional
            % :param phase: Phase offset in radians (default: 0)
            % :type phase: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     sine = SineWave(frequency = 1000, amplitude = 1.0, duration = 0.01);
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.frequency double = [];
                options.phase double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the sine wave.
            %
            % Returns a function handle that generates a sine wave with the
            % specified amplitude, frequency, phase, and timing parameters.
            % The waveform is zero outside the specified duration. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns sine wave values
            % :rtype: function_handle
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     sine = SineWave(frequency = 1000, amplitude = 1.0);
            %     func = sine.TimeFunc();
            %     t = 0:0.001:0.01;
            %     y = func(t);
            amp = obj.Amplitude;
            freq = obj.Frequency;
            td = obj.Duration;
            t0 = obj.StartTime;
            phi = obj.Phase;
            offset = obj.Offset;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* ...
                    (amp ./2 .* sin(2 * pi .* freq .* (t-t0) + phi) + offset);
            end
        end
    end
end

