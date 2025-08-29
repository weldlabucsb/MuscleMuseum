classdef SineFit1D < FitData1D
    % Sine function fit for one-dimensional data.
    %
    % Fits a sine function of the form A*sin(2*pi*f*x + phi) + C to experimental data.
    % Automatically estimates amplitude, frequency, phase, and offset from the data
    % using Fourier transform analysis.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit sine function to experimental data
    %     x = linspace(0, 10, 200);
    %     y = 2*sin(2*pi*0.5*x + pi/4) + 1 + 0.1*randn(size(x));
    %     data = [x', y'];
    %     sineFit = SineFit1D(data);
    %     sineFit.do();
    %     sineFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     sineFit = SineFit1D(data);
    %     sineFit.do();
    %     amplitude = sineFit.Coefficient(1);
    %     frequency = sineFit.Coefficient(2);
    %     phase = sineFit.Coefficient(3);
    %     offset = sineFit.Coefficient(4);
    %

    properties

    end

    methods
        function obj = SineFit1D(rawData)
            % Constructor for SineFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     data = [1:10; randn(1,10)].';
            %     sineFit = SineFit1D(data);
            %
            obj@FitData1D(rawData)
        end
        
        function setFormula(obj)
            % Set the sine fit formula.
            %
            % Formula: A*sin(2*pi*f*x + phi) + C
            % Parameters: A (amplitude), f (frequency), phi (phase), C (offset)
            %
            obj.Func = fittype('A * sin(2 * pi * f * x + phi) + C','independent', {'x'},...
                'coefficients', {'A', 'f', 'phi','C'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit parameters from data.
            %
            % Estimates amplitude, frequency, phase, and offset using Fourier
            % transform analysis and data characteristics.
            %
            if isempty(obj.DataSize) || obj.DataSize < obj.MinimumDataSize
                return
            end
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);

            % Offset guess
            guessOffset=(max(y) + min(y))/2;

            % Amplitude guess
            guessAmplitude = (max(y) - min(y))/2;

            % Frequency guess
            n = numel(x);
            xUnit = max(x)/n;
            yFT = nufft(y,x/xUnit);
            yFT(1) = 0;
            yFT = yFT(1:floor(n/2));
            fList = (0:floor(n/2)-1)/n / xUnit;
            [~,idx] = max(abs(yFT));
            guessFrequency = fList(idx(1));

            % Phase guess
            guessPhase = mean(mod(pi/2 - 2 * pi * guessFrequency * x(y==max(y)),2 * pi));

            obj.StartPoint = [guessAmplitude,guessFrequency,guessPhase,guessOffset];
            obj.Lower = [0.5 * guessAmplitude, guessFrequency / 5, 0, guessOffset - 0.3 * guessAmplitude];
            obj.Upper = [2 * guessAmplitude, 5 * guessFrequency, 2 * pi, guessOffset + 0.3 * guessAmplitude];
        end
    end
end

