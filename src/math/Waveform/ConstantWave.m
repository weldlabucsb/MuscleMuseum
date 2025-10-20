classdef ConstantWave < PeriodicWaveform & ConstantTop
    %:class:`ConstantWave` generates a constant (DC) waveform.
    %
    % Creates a waveform with a constant amplitude value over the specified duration.
    % Inherits from :class:`PeriodicWaveform` and :class:`ConstantTop` for periodic
    % behavior and constant amplitude properties.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Basic constant waveform
    %     const = ConstantWave(amplitude = 5.0, duration = 0.01);
    %     const.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Constant waveform with offset
    %     const = ConstantWave(amplitude = 2.0, offset = 1.0, duration = 0.005);
    %     const.plot();
    
    properties
        
    end
    
    methods
        function obj = ConstantWave(options)
            %Construct a ConstantWave object.
            %
            % :param samplingRate: Sampling rate in Hz (default: inherited)
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: inherited)
            % :type duration: double, optional
            % :param offset: DC offset value (default: 0)
            % :type offset: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     const = ConstantWave(amplitude = 3.0, duration = 0.01, offset = 1.0);
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.offset double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
            if ~isempty(obj.SamplingRate)
                obj.Frequency = obj.SamplingRate;
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the constant waveform.
            %
            % Returns a function handle that generates a constant value over
            % the specified duration, zero outside the duration. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns constant values
            % :rtype: function_handle
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     const = ConstantWave(amplitude = 2.0, duration = 0.01);
            %     func = const.TimeFunc();
            %     t = 0:0.001:0.02;
            %     y = func(t);
            td = obj.Duration;
            t0 = obj.StartTime;
            offset = obj.Offset;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* offset;
            end
        end
    end
end

