classdef SqrtParabolicFit1D < FitData1D
    %GAUSSIANFIT1D Summary of this class goes here
    %   Detailed explanation goes here

    properties

    end

    methods
        function obj = SqrtParabolicFit1D(rawData)
            %GAUSSIANFIT1D Construct an instance of this class
            %   Detailed explanation goes here
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            obj.Func = fittype('sqrt(A*(x-x0).^2 + C)','independent', {'x'},...
                'coefficients', {'A', 'x0', 'C'});

        end

        function guessCoefficient(obj)
            if isempty(obj.DataSize) || obj.DataSize < obj.MinimumDataSize
                return
            end
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);
            y2 = y.^2;

            % Offset guess
            if length(y)>21
                guessOffset=mean([y2(1:20) y2(end-20:20)]);
            else
                guessOffset=min(y2);
            end

            % Center guess
            [~,idx] = min(abs(y2 - guessOffset));
            guessCenter = x(idx);

            % Amplitude guess
            y2Ends = [y2(1),y2(end)];
            xEnds = [x(1),x(end)];
            guessAmplitude = max((y2Ends - guessOffset) ./ (xEnds - guessCenter).^2);

            obj.StartPoint = [guessAmplitude,guessCenter,guessOffset];
            obj.Lower = [0, -max(x), 0];
            obj.Upper = [10 * guessAmplitude, max(x), 5*min(y2)];

        end

    end
end

