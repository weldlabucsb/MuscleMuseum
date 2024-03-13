classdef TriangleFit1D < FitData1D
    %GAUSSIANFIT1D Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function obj = TriangleFit1D(rawData)
            %GAUSSIANFIT1D Construct an instance of this class
            %   Detailed explanation goes here
            obj@FitData1D(rawData)
            obj.Func = fittype(['(mod((x + phi), T) < Tr) .* (Amin + (Amax - Amin) .* mod((x + phi), T) / Tr) +' ...
                '(mod((x + phi), T) >= Tr) .* (Amax -  (Amax - Amin) .* (mod((x + phi), T) - Tr) / (T - Tr))'],'independent', {'x'},...
        'coefficients', {'Amin','Amax','phi', 'T','Tr'});
            x = rawData(:,1);
            y = rawData(:,2);

            % Period guess
            n = numel(x);
            xUnit = max(x)/n;
            yFT = nufft(y,x/xUnit);
            yFT(1) = 0;
            yFT = yFT(1:floor(n/2));
            fList = (0:floor(n/2)-1)/n / xUnit;
            [~,idx] = max(abs(yFT));
            guessPeriod = 1 / fList(idx(1));

            % Rise time guess
            guessRise = 0.5 *  guessPeriod;

            % Phase guess
            guessPhase = -mean(mod(x(y==min(y)),guessPeriod));

            amp = max(y) - min(y);

            obj.StartPoint = [max(y),min(y),guessPhase,guessPeriod,guessRise];
            obj.Lower = [max(y) - 0.5 * amp, min(y) - 0.5 * amp,-guessPeriod,guessPeriod*0.8,0];
            obj.Upper = [max(y) + 0.5 * amp, min(y) + 0.5 * amp,guessPeriod,guessPeriod*1.2,guessPeriod];
        end
        
    end
end

