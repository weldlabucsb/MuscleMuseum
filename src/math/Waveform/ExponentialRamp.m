classdef ExponentialRamp < Waveform
    %EXPONENTIALRAMP 
    %   T
    
    properties
        Tau double = 0;       % tau is the exponential decay time for amp to drop a factor of 1/e.
        StartValue double = 0;
        Offset double = 0;
    end
    
    methods
        function obj = ExponentialRamp(options)
            %GAUSSIANPULSE Construct an instance of this class
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = 1e-6;
                options.amplitude double = [];
                options.offset double = 0;

                % options.sigma double = [];
                options.startValue double = 1;
                options.tau double = -1;
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
            startval = obj.StartValue;
            t0 = obj.StartTime;
            % te = obj.EndTime;
            offset = obj.Offset;

            tau=obj.Tau;

            

            % Envelope parameters with sensible defaults
            % tc = obj.CenterTime;
            % if isempty(tc)
            %     tc = (t0 + te) / 2;                % default: center of window
            % end
            % sg = obj.Sigma;
            % if isempty(sg)
            %     sg = max((te - t0) / 6, eps);      % default: ~3σ fits in window
            % end

            func = @tFunc;
            function waveOut = tFunc(t)
                % gate = (t >= t0 & t <= te);
                % env  = exp(-0.5 * ((t - tc) ./ sg).^2);
                waveOut = offset+(startval-offset).*exp((t-t0)/tau);
            end
        end
    end
end
