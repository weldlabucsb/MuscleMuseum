classdef SqrtParabolicFit1D < FitData1D
    %:class:`SqrtParabolicFit1D` fits y = sqrt(A*(x - x0)^2 + C) to 1D data.
    %
    % Fits a square-root parabolic model commonly used where the dependent
    % variable scales with the absolute distance from a center with an offset.
    % Automatically estimates amplitude, center, and offset from the data.
    %
    % - **Formula**: :math:`y = \sqrt{A\,(x-x_0)^2 + C}`
    % - **Coefficients**: :math:`A` (scale), :math:`x_0` (center), :math:`C` (offset)
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit sqrt-parabolic model to data
    %     x = linspace(-5,5,101)';
    %     y = sqrt(0.2*(x-0.7).^2 + 0.05) + 0.01*randn(size(x));
    %     data = [x, y];
    %     fitObj = SqrtParabolicFit1D(data);
    %     fitObj.do();
    %     fitObj.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fitted parameters
    %     A     = fitObj.Coefficient(1);
    %     x0    = fitObj.Coefficient(2);
    %     C     = fitObj.Coefficient(3);

    properties

    end

    methods
        function obj = SqrtParabolicFit1D(rawData)
            % Construct a :class:`SqrtParabolicFit1D`.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the sqrt-parabolic fit formula.
            obj.Func = fittype('sqrt(A*(x-x0).^2 + C)','independent', {'x'},...
                'coefficients', {'A', 'x0', 'C'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit parameters from data.
            %
            % Estimates center from the minimum of :math:`y^2`, offset from end
            % regions, and scale from edge points.
            %
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

