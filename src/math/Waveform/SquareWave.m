classdef SquareWave < PeriodicWaveform
    %SQUAREWAVE   A square‐wave generator (peak‐to‐peak amplitude)
    
    properties
        % Fraction of each period the waveform stays at its high level
        DutyCycle double { ...
            mustBeGreaterThanOrEqual(DutyCycle,0), ...
            mustBeLessThanOrEqual(DutyCycle,1) } = 0.5
    end

    methods
        function obj = SquareWave(options)
            arguments
                options.samplingRate double = []
                options.startTime     double = 0
                options.duration      double = []
                options.amplitude     double = []
                options.offset        double = 0
                options.frequency     double = []
                options.phase         double = 0
                options.dutyCycle     double = 0.5
            end

            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end

        function func = TimeFunc(obj)
            %TIMEFUNC    Return a handle that generates the square wave.
            amp   = obj.Amplitude;
            off   = obj.Offset;
            freq  = obj.Frequency;
            phi   = obj.Phase;
            duty  = obj.DutyCycle;
            t0    = obj.StartTime;
            td    = obj.Duration;

            func = @tFunc;
            function waveOut = tFunc(t)
                % only valid between t0 and t0+td
                inWindow = (t >= t0) & (t <= t0 + td);

                % normalized phase in [0,1)
                normPh = mod(freq .* (t - t0) + phi/(2*pi), 1);

                % build ±half‐amplitude square
                sq = zeros(size(t));
                sq(normPh < duty)  =  amp/2;
                sq(normPh >= duty) = -amp/2;

                % add offset and mask outside [t0, t0+td]
                waveOut = inWindow .* (sq + off);
            end
        end
    end
end
