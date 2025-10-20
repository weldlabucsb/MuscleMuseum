classdef LinearFrequencyRamp < Waveform
    %:class:`LinearFrequencyRamp` generates sine waves with linearly varying frequency.
    %
    % Creates sine wave signals where the frequency changes linearly from a start
    % frequency to a stop frequency over the duration. Useful for frequency sweep
    % applications and chirp signals. Inherits from :class:`Waveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a frequency sweep from 100 Hz to 1000 Hz
    %     ramp = LinearFrequencyRamp(startFrequency = 100, stopFrequency = 1000, ...
    %                                amplitude = 1.0, duration = 0.01);
    %     ramp.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a downward frequency sweep
    %     ramp = LinearFrequencyRamp(startFrequency = 1000, stopFrequency = 100, ...
    %                                amplitude = 2.0, duration = 0.01);
    %     ramp.plot();
    
    properties
        Amplitude double = 0 % Peak-to-peak amplitude, usually in Volts.
        Offset double = 0 % Offest, usually in Volts.
        StartFrequency double {mustBePositive} = 10 % Linear frequency in Hz - Starting frequency.
        StopFrequency double {mustBePositive} = 100 % Linear frequency in Hz - Ending frequency.
        Phase double = 0 % Initial phase in radians.
    end
    
    methods
        function obj = LinearFrequencyRamp(options)
            %Construct a LinearFrequencyRamp object.
            %
            % :param samplingRate: Sampling rate in Hz (default: inherited)
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: inherited)
            % :type duration: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param amplitude: Peak-to-peak amplitude (default: 0)
            % :type amplitude: double, optional
            % :param phase: Initial phase in radians (default: 0)
            % :type phase: double, optional
            % :param startFrequency: Starting frequency in Hz (default: 1)
            % :type startFrequency: double, optional
            % :param stopFrequency: Ending frequency in Hz (default: 2)
            % :type stopFrequency: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     ramp = LinearFrequencyRamp(startFrequency = 100, stopFrequency = 1000, ...
            %                                amplitude = 1.0, duration = 0.01);
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.offset double = 0;
                options.amplitude double = 0;

                options.phase double = 0;
                options.startFrequency double = 1;
                options.stopFrequency double = 2;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the linear frequency ramp.
            %
            % Creates a function handle that generates sine wave values with
            % linearly varying frequency from :attr:`StartFrequency` to :attr:`StopFrequency`.
            % Implements the abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns frequency ramp values
            % :rtype: function_handle
            amp = obj.Amplitude;
            freqi = obj.StartFrequency;
            freqf = obj.StopFrequency;
            td = obj.Duration;
            t0 = obj.StartTime;
            phi = obj.Phase;
            offset = obj.Offset;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* ...
                    (amp ./2 .* sin(2 * pi .* (freqi.*(t-t0) + cumtrapz(t-t0,((freqf-freqi) ./ td .* (t-t0))))  + phi) + offset);
            end
        end
    end
end

