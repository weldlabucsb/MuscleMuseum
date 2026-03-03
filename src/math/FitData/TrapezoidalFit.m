classdef TrapezoidalFit < FitData1D

    properties

    end

    methods
        function obj = TrapezoidalFit(rawData)
            % Constructor for GaussianFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the Gaussian fit formula.
            %
            obj.Func = fittype('(x>=t0 & x<=(te)) .* ((((x-t0)./(tr)-1) .* (x<=(t0+tr)) - (x-(te-tf))./(tf) .* (x>=(te-tf)) + 1) .* amp) + offset',...
                'independent', {'x'},...
                'coefficients', {'t0', 'te', 'tr','tf','amp','offset'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit parameters from data.
            %
            % Estimates amplitude, center, standard deviation, and offset
            % based on data characteristics.
            %
            if isempty(obj.DataSize) || obj.DataSize < obj.MinimumDataSize
                return
            end
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);

            % Offset guess
            if length(y)>50
                guessOffset=mean([y(1:20);y(end-19:end)]);
            else
                guessOffset=min(y);
            end

            % Amplitude guess
            guessAmplitude = max(y) - guessOffset;

            % Find time guess
            tStart = min(x);
            tStop = max(x);
            tTotal = tStop - tStart;
            guessT0 = tStart + tTotal/10;
            guessTE = tStop - tTotal/10;
            guessTR = tTotal/10;
            guessTF = tTotal/10;

            obj.StartPoint = [guessT0,guessTE,guessTR,guessTF,guessAmplitude,guessOffset];
            obj.Lower = [tStart, tStart, 0, 0, 0, guessOffset - guessAmplitude/2];
            obj.Upper = [tStop, tStop, tTotal/2, tTotal/2, 2 * guessAmplitude, guessOffset + guessAmplitude/2];

        end

    end
end

