classdef (Abstract) ModulatedWaveform < Waveform
    %:class:`ModulatedWaveform` abstract base class for modulated waveform generation.
    %
    % Provides common functionality for waveforms with amplitude, frequency,
    % and phase modulation. Subclasses implement specific modulation schemes
    % for advanced signal generation applications. Inherits from :class:`Waveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create amplitude modulation
    %     ampMod = SineWave(frequency = 10, amplitude = 0.5);
    %     modulated = SineWaveModulated(frequency = 1000, amplitude = 1.0, ...
    %                                   amplitudeModulation = ampMod);
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create frequency modulation
    %     freqMod = SineWave(frequency = 5, amplitude = 100);
    %     modulated = SineWaveModulated(frequency = 1000, amplitude = 1.0, ...
    %                                   frequencyModulation = freqMod);
    
    properties
        Amplitude double = 0 % Peak-to-peak amplitude, usually in Volts.
        Offset double = 0 % Offset, usually in Volts.
        Frequency double {mustBePositive} = 100 % In Hz
        Phase double = 0 % In radians
        AmplitudeModulation WaveformList % Waveform for amplitude modulation.
        FrequencyModulation WaveformList % Waveform for frequency modulation.
        PhaseModulation WaveformList % Waveform for phase modulation.
    end
    
    methods
        function obj = ModulatedWaveform()
            %Construct a ModulatedWaveform object.
            %
            % Abstract base class constructor. Subclasses should implement
            % their own constructors with appropriate parameters.
        end

        function [ampMod,freqMod,phaseMod] = getModulation(obj)
            %Get the modulation function handles.
            %
            % Returns function handles for amplitude, frequency, and phase
            % modulation. Returns zero functions if no modulation is configured.
            % Uses the :attr:`AmplitudeModulation`, :attr:`FrequencyModulation`,
            % and :attr:`PhaseModulation` properties.
            %
            % :return: Amplitude modulation function handle
            % :rtype: function_handle
            % :return: Frequency modulation function handle
            % :rtype: function_handle
            % :return: Phase modulation function handle
            % :rtype: function_handle
            if ~isempty(obj.AmplitudeModulation)
                obj.AmplitudeModulation.SamplingRate = obj.SamplingRate;
                ampMod = obj.AmplitudeModulation.TimeFunc;
            else
                ampMod = @(t) zeros(size(t));
            end
            if ~isempty(obj.FrequencyModulation)
                obj.FrequencyModulation.SamplingRate = obj.SamplingRate;
                freqMod = obj.FrequencyModulation.TimeFunc;
            else
                freqMod = @(t) zeros(size(t));
            end
            if ~isempty(obj.PhaseModulation)
                obj.PhaseModulation.SamplingRate = obj.SamplingRate;
                phaseMod = obj.PhaseModulation.TimeFunc;
            else
                phaseMod = @(t) zeros(size(t));
            end
        end
    end
end

