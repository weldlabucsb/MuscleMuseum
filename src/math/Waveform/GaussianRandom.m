classdef GaussianRandom < RandomWaveform
    %:class:`GaussianRandom` generates Gaussian random waveform signals.
    %
    % Creates random signals with values following a normal (Gaussian)
    % distribution with specified mean and standard deviation. Uses MATLAB's
    % normrnd() function for pseudo-random number generation. Inherits from :class:`RandomWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create Gaussian random with mean 0, std 1
    %     gaussian = GaussianRandom(duration = 0.01);
    %     gaussian.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create Gaussian random with mean 2, std 0.5
    %     gaussian = GaussianRandom(mean = 2, standardDeviation = 0.5, duration = 0.01);
    %     gaussian.plot();
    
    properties
        Mean double = 0 % Mean of the Gaussian distribution.
        StandardDeviation double = 1 % Standard deviation of the Gaussian distribution.
    end
    
    methods
        function obj = GaussianRandom(options)
            %Construct a GaussianRandom object.
            %
            % :param samplingRate: Sampling rate in Hz (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: [])
            % :type duration: double, optional
            % :param mean: Mean of Gaussian distribution (default: 0)
            % :type mean: double, optional
            % :param standardDeviation: Standard deviation of Gaussian distribution (default: 1)
            % :type standardDeviation: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.mean double = [];
                options.standardDeviation double = 1;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the Gaussian random waveform.
            %
            % Creates a function handle that generates Gaussian random values
            % with the configured mean and standard deviation. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns Gaussian random values
            % :rtype: function_handle
            mu = obj.Mean;
            sigma = obj.StandardDeviation;
            td = obj.Duration;
            t0 = obj.StartTime;
            func = @tFunc;
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(t0+td)) .* ...
                    normrnd(mu,sigma,1,numel(t));
            end
        end
    end
end

