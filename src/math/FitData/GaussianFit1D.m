classdef GaussianFit1D < FitData1D
    % Gaussian function fit for one-dimensional data.
    %
    % Fits a Gaussian function of the form A*exp(-(x-x0)^2/(2*sigma^2))+C to
    % experimental data. Automatically estimates initial parameters from the data.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit Gaussian to experimental data
    %     x = linspace(-5, 5, 100);
    %     y = 2*exp(-(x-1).^2/0.5) + 0.1*randn(size(x));
    %     data = [x', y'];
    %     gaussianFit = GaussianFit1D(data);
    %     gaussianFit.do();
    %     gaussianFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     gaussianFit = GaussianFit1D(data);
    %     gaussianFit.do();
    %     amplitude = gaussianFit.Coefficient(1);
    %     center = gaussianFit.Coefficient(2);
    %     sigma = gaussianFit.Coefficient(3);
    %     offset = gaussianFit.Coefficient(4);
    %

    properties

    end

    methods
        function obj = GaussianFit1D(rawData)
            % Constructor for GaussianFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     data = [1:10; randn(1,10)].';
            %     gaussianFit = GaussianFit1D(data);
            %
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the Gaussian fit formula.
            %
            % Formula: A*exp(-(x-x0)^2/(2*sigma^2))+C
            % Parameters: A (amplitude), x0 (center), sigma (width), C (offset)
            %
            obj.Func = fittype('A*exp(-(x-x0)^2/(2*sigma^2))+C','independent', {'x'},...
                'coefficients', {'A', 'x0', 'sigma','C'});
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

            % Center guess
            guessCenter = median(x(y>0.5*max(y)));

            % Standard deviation guess
            guessStandardDeviation = (max(x) - min(x))/30;

            obj.StartPoint = [guessAmplitude,guessCenter,guessStandardDeviation,guessOffset];
            obj.Lower = [0, min(x), 0, min(y) - 0.05 * guessAmplitude];
            obj.Upper = [1.5 * guessAmplitude, max(x), (max(x) - min(x))*.25, 5*abs(min(y))];

        end

    end
end

