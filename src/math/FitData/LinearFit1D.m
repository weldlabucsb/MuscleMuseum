classdef LinearFit1D < FitData1D
    % Linear function fit for one-dimensional data.
    %
    % Fits a linear function of the form y = ax + b to experimental data.
    % Uses MATLAB's built-in poly1 fit type for efficient linear regression.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit linear function to experimental data
    %     x = linspace(0, 10, 50);
    %     y = 2*x + 1 + 0.1*randn(size(x));
    %     data = [x', y'];
    %     linearFit = LinearFit1D(data);
    %     linearFit.do();
    %     linearFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     linearFit = LinearFit1D(data);
    %     linearFit.do();
    %     slope = linearFit.Coefficient(1);
    %     intercept = linearFit.Coefficient(2);
    %
    
    properties
        
    end
    
    methods
        function obj = LinearFit1D(rawData)
            % Constructor for LinearFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     data = [1:10; randn(1,10)].';
            %     linearFit = LinearFit1D(data);
            %
            obj@FitData1D(rawData)
        end
        
        function setFormula(obj)
            % Set the linear fit formula.
            %
            % Formula: y = ax + b (poly1)
            % Parameters: a (slope), b (intercept)
            %
            obj.Func = fittype('poly1');
        end

        function guessCoefficient(obj)
            % Linear fit uses MATLAB's automatic parameter estimation.
            %
            % For linear fits, MATLAB automatically estimates the slope and
            % intercept parameters, so no manual guessing is required.
            %
        end
    end
end

