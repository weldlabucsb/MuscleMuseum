classdef TwoColorSineSquaredPulse < Waveform
    %TWOCOLORSINESQUAREDPULSE Two sine carriers under sin^2 envelopes (summed)
    %   Both envelopes share the same [startTime, endTime] and are sin^2-shaped:
    %       env(t) = sin^2(pi * (t - t0) / duration), gated to [t0, te].
    %   Each color has its own envelope amplitude and carrier frequency/phase.
    %   Total output: gate .* (env .* (A1/2 * sin(2*pi*f1*(t - t0) + phi1) ...
    %                                  + A2/2 * sin(2*pi*f2*(t - t0) + phi2)) + offset)

    properties
        Amplitude1 double = [];  % Envelope amplitude for color 1
        Amplitude2 double = [];  % Envelope amplitude for color 2
        Frequency1 double = [];  % Carrier frequency for color 1
        Frequency2 double = [];  % Carrier frequency for color 2
        Phase1 double = 0;       % Carrier phase for color 1
        Phase2 double = 0;       % Carrier phase for color 2
    end

    methods
        function obj = TwoColorSineSquaredPulse(options)
            %TWOCOLORSINESQUAREDPULSE Construct an instance of this class
            %   Keeps the same options style and assignment loop.
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.offset double = 0;

                options.amplitude1 double = [];
                options.amplitude2 double = [];
                options.frequency1 double = [];
                options.frequency2 double = [];
                options.phase1 double = 0;
                options.phase2 double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end

        function func = TimeFunc(obj)
            % Build time-domain function handle (sum of two sin^2-envelope carriers + offset)
            A1  = obj.Amplitude1;
            A2  = obj.Amplitude2;
            f1  = obj.Frequency1;
            f2  = obj.Frequency2;
            phi1 = obj.Phase1;
            phi2 = obj.Phase2;

            t0  = obj.StartTime;
            te  = obj.EndTime;
            td  = obj.Duration;
            offset = obj.Offset;

            func = @tFunc;
            function waveOut = tFunc(t)
                gate = (t >= t0 & t <= te);
                % sin^2 envelope within gate; zero outside
                x = (t - t0) ./ td;
                env = zeros(size(t));
                env(gate) = sin(pi .* x(gate)).^2;

                % Two carriers with MM-style 1/2 scaling
                c1 = (A1 ./ 2) .* sin(2*pi .* f1 .* (t - t0) + phi1);
                c2 = (A2 ./ 2) .* sin(2*pi .* f2 .* (t - t0) + phi2);

                waveOut = gate .* (env .* (c1 + c2) + offset);
            end
        end
    end
end
