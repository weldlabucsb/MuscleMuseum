classdef GaussianPulse < Waveform
    %GAUSSIANPULSE Pure Gaussian envelope (no carrier)
    %   The envelope is exp(-0.5 * ((t - tc)/sigma)^2), gated to [t0, te].
    
    properties
        Sigma double = 0;       % Standard deviation of Gaussian envelope
        CenterTime double = 0;  % Center time of the Gaussian envelope
        Amplitude double = 0;
        Offset double = 0;
    end
    
    methods
        function obj = GaussianPulse(options)
            %GAUSSIANPULSE Construct an instance of this class
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.sigma double = [];
                options.centerTime double = [];
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            % Build time-domain function handle (gated Gaussian + offset)
            amp = obj.Amplitude;
            t0 = obj.StartTime;
            te = obj.EndTime;
            offset = obj.Offset;

            % Envelope parameters with sensible defaults
            tc = obj.CenterTime;
            if isempty(tc)
                tc = (t0 + te) / 2;                % default: center of window
            end
            sg = obj.Sigma;
            if isempty(sg)
                sg = max((te - t0) / 6, eps);      % default: ~3σ fits in window
            end

            func = @tFunc;
            function waveOut = tFunc(t)
                gate = (t >= t0 & t <= te);
                env  = exp(-0.5 * ((t - tc) ./ sg).^2);
                waveOut = gate .* (amp .* env + offset);
            end
        end
    end
end
