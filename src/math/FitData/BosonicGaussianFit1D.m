classdef BosonicGaussianFit1D < FitData1D
    % Bosonic Gaussian function fit for one-dimensional data.
    %
    % Fits a bosonic Gaussian function that accounts for Bose-Einstein statistics
    % to experimental data. Uses a Bose function approximation applied to a
    % Gaussian distribution.
    %
    % - **Formula**: :math:`y = A\,\mathrm{Bose}(e^{-(x-x_0)^2/(2\sigma^2)};2.5) + C`
    % - **Coefficients**: :math:`A` (amplitude), :math:`x_0` (center), :math:`\sigma` (width), :math:`C` (offset)
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit bosonic Gaussian to experimental data
    %     x = linspace(-5, 5, 100);
    %     y = 2*boseFunctionApprox(exp(-(x-1).^2/0.5), 2.5) + 0.1*randn(size(x));
    %     data = [x', y'];
    %     bosonicFit = BosonicGaussianFit1D(data);
    %     bosonicFit.do();
    %     bosonicFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     bosonicFit = BosonicGaussianFit1D(data);
    %     bosonicFit.do();
    %     amplitude = bosonicFit.Coefficient(1);
    %     center = bosonicFit.Coefficient(2);
    %     sigma = bosonicFit.Coefficient(3);
    %     offset = bosonicFit.Coefficient(4);
    %
    
    properties
        
    end
    
    methods
        function obj = BosonicGaussianFit1D(rawData)
            % Constructor for BosonicGaussianFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData1D(rawData)
            
        end

        function setFormula(obj)
            % Set the bosonic Gaussian fit formula.
            %
            obj.Func = fittype('A*boseFunctionApprox(exp(-(x-x0)^2/(2*sigma^2)),2.5)+C','independent', {'x'},...
                'coefficients', {'A', 'x0', 'sigma','C'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit parameters from data.
            %
            % Estimates amplitude, center, standard deviation, and offset
            % based on data characteristics, similar to standard Gaussian fit.
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
            
            % Center guess
            guessCenter = median(x(y>0.5*max(y)));

            % Standard deviation guess
            guessStandardDeviation = (max(x) - min(x))/30;

            obj.StartPoint = [guessAmplitude,guessCenter,guessStandardDeviation,guessOffset];
            obj.Lower = [0, min(x), 0, min(y) - 0.05 * guessAmplitude];
            obj.Upper = [1.5 * guessAmplitude, max(x), (max(x) - min(x))*.5, 5*abs(min(y))];
        end
    end
end

