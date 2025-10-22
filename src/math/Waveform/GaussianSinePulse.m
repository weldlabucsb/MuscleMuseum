classdef GaussianSinePulse < Waveform
    %GAUSSIANSINEPULSE Gaussian envelope with a sine carrier
    %   The envelope is exp(-0.5 * ((t - tc)/sigma)^2), gated to [t0, te].
    %   Carrier is sin(2*pi*freq*(t - t0) + phi).
    
    properties
        Sigma double = [];       % Standard deviation of Gaussian envelope
        CenterTime double = [];  % Center time of the Gaussian envelope
        Offset double = [];
        Phase double = [];
    end
    
    methods
        function obj = GaussianSinePulse(options)
            %GAUSSIANSINEPULSE Construct an instance of this class
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.frequency double = [];
                options.phase double = 0;

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
            % Build time-domain function handle (gated Gaussian*sine + offset)
            amp = obj.Amplitude;
            freq = obj.Frequency;
            t0 = obj.StartTime;
            te = obj.EndTime;
            phi = obj.Phase;
            offset = obj.Offset;

            % Envelope parameters
            tc = obj.CenterTime;
            if isempty(tc)
                tc = (t0 + te) / 2;                % default: centered in the window
            end
            sg = obj.Sigma;
            if isempty(sg)
                sg = max((te - t0) / 6, eps);      % default: ~3σ spans the window
            end

            func = @tFunc;
            function waveOut = tFunc(t)
                gate = (t >= t0 & t <= te);
                env  = exp(-0.5 * ((t - tc) ./ sg).^2);
                carr = (amp ./ 2) .* sin(2 * pi .* freq .* (t - t0) + phi);
                waveOut = gate .* (env .* carr + offset);
            end
        end
    end
end
