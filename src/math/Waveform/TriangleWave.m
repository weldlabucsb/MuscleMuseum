classdef TriangleWave < PeriodicWaveform
    %:class:`TriangleWave` generates a periodic triangle waveform.
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
       Balance double = 0.5 
    end
    
    methods
        function obj = TriangleWave(options)
            % Construct a :class:`TriangleWave`.
            %
            % :param samplingRate: Sampling rate [Hz] (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time :math:`t_0` [s] (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration :math:`T` [s] (default: [])
            % :type duration: double, optional
            % :param amplitude: Waveform amplitude (default: [])
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param frequency: Frequency :math:`f` [Hz] (default: [])
            % :type frequency: double, optional
            % :param phase: Phase :math:`\phi` [rad] (default: 0)
            % :type phase: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.frequency double = [];
                options.phase double = 0;
                options.balance double = 0.5;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            % Get the time function for the sine wave.
            %
            % Implements the abstract :meth:`TimeFunc` from :class:`Waveform` by
            % returning :math:`f(t) = \mathbb{1}_{[t_0,t_0+T]}(t)\,(A/2\,\sin(2\pi f (t-t_0)+\phi)+\mathrm{offset})`.
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
            balance=obj.Balance;
            func = @tFunc;

                %Copied from TriangleFit1D
            T=1/freq;
            Amin=offset-amp/2;
            Amax=offset+amp/2;
            Tr=T*balance;
            function waveOut = tFunc(t)
                waveOut = (mod((t + phi/(2*pi)*T), T) < Tr) .* (Amin + (Amax - Amin) .* mod((t + phi/(2*pi)*T), T) / Tr) + ...
                (mod((t + phi/(2*pi)*T), T) >= Tr) .* (Amax -  (Amax - Amin) .* (mod((t + phi/(2*pi)*T), T) - Tr) / (T - Tr));
            end
        end
    end
end

