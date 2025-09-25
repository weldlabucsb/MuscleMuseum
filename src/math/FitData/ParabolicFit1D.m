classdef ParabolicFit1D < FitData1D
    % Parabolic function fit for one-dimensional data.
    %
    % Fits a parabolic function of the form :math:`y = a\,x^2 + b\,x + c` to experimental data.
    % Uses MATLAB's built-in poly2 fit type for efficient quadratic regression.
    %
    % - **Formula**: :math:`y = a\,x^2 + b\,x + c`
    % - **Coefficients**: :math:`a` (quadratic), :math:`b` (linear), :math:`c` (constant)
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit parabolic function to experimental data
    %     x = linspace(-5, 5, 100);
    %     y = 0.5*x.^2 + 2*x + 1 + 0.1*randn(size(x));
    %     data = [x', y'];
    %     parabolicFit = ParabolicFit1D(data);
    %     parabolicFit.do();
    %     parabolicFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     parabolicFit = ParabolicFit1D(data);
    %     parabolicFit.do();
    %     a = parabolicFit.Coefficient(1); % quadratic coefficient
    %     b = parabolicFit.Coefficient(2); % linear coefficient
    %     c = parabolicFit.Coefficient(3); % constant term
    %
    
    properties
        
    end
    
    methods
        function obj = ParabolicFit1D(rawData)
            % Constructor for ParabolicFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the parabolic fit formula.
            %
            obj.Func = fittype('poly2');
        end

        function guessCoefficient(obj)
            % Parabolic fit uses MATLAB's automatic parameter estimation.
            %
            % For parabolic fits, MATLAB automatically estimates the quadratic,
            % linear, and constant coefficients, so no manual guessing is required.
            %
        end
    end
end

