classdef UniformRandom < RandomWaveform
    %:class:`UniformRandom` generates uniform random waveform signals.
    %
    % Creates random signals with values uniformly distributed between
    % specified lower and upper bounds. Uses MATLAB's rand() function
    % for pseudo-random number generation. Inherits from :class:`RandomWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create uniform random between 0 and 1
    %     uniform = UniformRandom(duration = 0.01);
    %     uniform.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create uniform random between -2 and 2
    %     uniform = UniformRandom(lowerBound = -2, upperBound = 2, duration = 0.01);
    %     uniform.plot();
    
    properties
        LowerBound double = 0 % Lower bound of the uniform distribution.
        UpperBound double = 1 % Upper bound of the uniform distribution.
    end
    
    methods
        function obj = UniformRandom(options)
            %Construct a UniformRandom object.
            %
            % :param samplingRate: Sampling rate in Hz (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: [])
            % :type duration: double, optional
            % :param lowerBound: Lower bound of uniform distribution (default: 0)
            % :type lowerBound: double, optional
            % :param upperBound: Upper bound of uniform distribution (default: 1)
            % :type upperBound: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.lowerBound double = [];
                options.upperBound double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the uniform random waveform.
            %
            % Creates a function handle that generates uniform random values
            % between the configured lower and upper bounds. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns uniform random values
            % :rtype: function_handle
            lb = obj.LowerBound;
            ub = obj.UpperBound;
            td = obj.Duration;
            t0 = obj.StartTime;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* ...
                    (rand(1,numel(t)).*(ub-lb) + lb);
            end
        end
    end
end

