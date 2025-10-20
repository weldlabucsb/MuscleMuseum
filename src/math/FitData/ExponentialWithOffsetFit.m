classdef ExponentialWithOffsetFit < FitData1D
    %GAUSSIANFIT1D Summary of this class goes here
    %   Detailed explanation goes here
    % fit function: a*exp(-t/tau)+c
    properties

    end

    methods
        function obj = ExponentialWithOffsetFit(rawData)
            %GAUSSIANFIT1D Construct an instance of this class
            %   Detailed explanation goes here
            obj@FitData1D(rawData)
            obj.Func = fittype('A * exp(-x/tau) + B', 'independent', {'x'}, ...
                'coefficients', {'A', 'tau', 'B'});
            x = rawData(:,1);
            y = rawData(:,2);

            % Offset guess.
            guessOffset = min(y);
            % Amplitude guess
            guessAmplitude = max(y);

            % lifetime guess
            P = polyfit(log10(x), log10(y-min(y), 1));
            guessLifetime = -1/P(1);

            obj.StartPoint = [guessAmplitude,guessLifetime,guessOffset];
            obj.Lower = [0.5 * guessAmplitude, guessLifetime / 5, guessOffset - 0.3 * guessAmplitude];
            obj.Upper = [2 * guessAmplitude, 5 * guessLifetime, guessOffset + 0.3 * guessAmplitude];

        end

    end
end

