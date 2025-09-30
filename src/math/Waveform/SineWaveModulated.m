classdef SineWaveModulated < ModulatedWaveform
    %:class:`SineWaveModulated` generates amplitude, frequency, and phase modulated sine waves.
    %
    % Creates sine wave signals with time-varying amplitude, frequency, and phase
    % modulation. Supports complex modulation patterns for advanced signal generation
    % and communication applications. Inherits from :class:`ModulatedWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create amplitude modulated sine wave
    %     ampMod = SineWave(frequency = 10, amplitude = 0.5);
    %     sine = SineWaveModulated(frequency = 1000, amplitude = 1.0, ...
    %                              amplitudeModulation = ampMod);
    %     sine.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create frequency modulated sine wave
    %     freqMod = SineWave(frequency = 5, amplitude = 100);
    %     sine = SineWaveModulated(frequency = 1000, amplitude = 1.0, ...
    %                              frequencyModulation = freqMod);
    
    properties
        
    end
    
    methods
        function obj = SineWaveModulated(options)
            %Construct a SineWaveModulated object.
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
            % :param frequency: Carrier frequency in Hz (default: [])
            % :type frequency: double, optional
            % :param phase: Initial phase in radians (default: 0)
            % :type phase: double, optional
            % :param amplitudeModulation: Amplitude modulation waveform (default: [])
            % :type amplitudeModulation: :class:`WaveformList`, optional
            % :param frequencyModulation: Frequency modulation waveform (default: [])
            % :type frequencyModulation: :class:`WaveformList`, optional
            % :param phaseModulation: Phase modulation waveform (default: [])
            % :type phaseModulation: :class:`WaveformList`, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;
                options.frequency double = [];
                options.phase double = 0;

                options.amplitudeModulation = []; 
                options.frequencyModulation = [];
                options.phaseModulation = [];
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the modulated sine wave.
            %
            % Creates a function handle that generates modulated sine wave values
            % with time-varying amplitude, frequency, and phase based on the
            % configured modulation waveforms. Implements the abstract :meth:`TimeFunc`
            % method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns modulated sine wave values
            % :rtype: function_handle
            amp = obj.Amplitude;
            freq = obj.Frequency;
            td = obj.Duration;
            t0 = obj.StartTime;
            phi = obj.Phase;
            offset = obj.Offset;
            [ampMod,freqMod,phaseMod] = obj.getModulation;

            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* ((amp+ampMod(t-t0)) ./2 .* ...
                    sin(2 * pi .* (freq .* (t-t0) + cumtrapz(t-t0,freqMod(t-t0))) + (phi+phaseMod(t-t0))) + offset);
            end
        end
    end
end

