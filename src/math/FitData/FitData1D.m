classdef (Abstract) FitData1D < FitData
    %:class:`FitData1D` abstract base for one-dimensional data fitting.
    %
    % Extends :class:`FitData` to provide specialized functionality for fitting
    % functions to 1D data (x,y coordinate pairs). Includes plotting capabilities
    % and fit evaluation methods (:meth:`evaluateFit`).
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create and perform a 1D fit
    %     x = linspace(0, 10, 100);
    %     y = 2*exp(-(x-5).^2/2) + 0.1*randn(size(x));
    %     data = [x', y'];
    %     fitObj = GaussianFit1D(data);
    %     fitObj.do();
    %     fitObj.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Evaluate fit at specific points
    %     fitObj = LinearFit1D(data);
    %     fitObj.do();
    %     xEval = [1, 2, 3, 4, 5];
    %     yEval = fitObj.evaluateFit(xEval);
    %

    properties (Dependent)
        FitPlotData (:,2) double % n * 2 array for plotting fit curve
        DataSize (1,1) double % Number of data points
    end
    
    methods
        function obj = FitData1D(rawData)
            % Construct a :class:`FitData1D`.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData(rawData)
        end

        function output = checkData(obj,rawData)
            % Validate input data format for 1D fitting.
            %
            % :param rawData: Input data to validate
            % :type rawData: double array
            % :return: Validated data or empty array
            % :rtype: double array
            %
            if isempty(rawData)
                output = [];
            elseif ~ismatrix(rawData)
                error("Fit raw data must be a n * 2 matrix.")
            elseif size(rawData,2) ~= 2
                error("Fit raw data must be a n * 2 matrix.")
            else
                output = rawData;
            end
        end

        function fpData = get.FitPlotData(obj)
            % Get data for plotting the fit curve.
            %
            % :return: x,y coordinates for fit curve plotting
            % :rtype: double array
            %
            if isempty(obj.Result)
                fpData = [];
                return
            end
            xFit = linspace(min(obj.RawData(:,1)),max(obj.RawData(:,1)),1000).';
            yFit = obj.evaluateFit(xFit);
            fpData = [xFit,yFit];
        end

        function dataSize = get.DataSize(obj)
            % Get number of data points.
            %
            % :return: Number of data points
            % :rtype: double
            %
            dataSize = size(obj.RawData,1);
        end

        function obj = do(obj)
            % Perform the fitting operation.
            %
            % :return: Self-reference for method chaining
            % :rtype: FitData1D
            %
            [fitResult,gof] = fit(obj.RawData(:,1),obj.RawData(:,2),obj.Func,obj.Option);
            obj.Result = fitResult;
            obj.Gof = gof;
            obj.Coefficient = coeffvalues(fitResult);
        end

        function y = evaluateFit(obj,x)
            % Evaluate the fitted function at specified x values.
            %
            % :param x: x-coordinates for evaluation
            % :type x: double array
            % :return: y-values from fitted function
            % :rtype: double array
            %
            if isempty(obj.Result)
                y = [];
            else
                y = feval(obj.Result,x);
            end
        end
        
        function plot(obj,targetAxes,isRender)
            % Plot raw data and fit curve.
            %
            % :param targetAxes: Target axes for plotting (optional)
            % :type targetAxes: axes handle
            % :param isRender: Whether to render axis labels and formatting
            % :type isRender: logical
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     fitObj.plot();
            %     fitObj.plot(gca, false);
            %
            arguments
                obj FitData1D
                targetAxes = []
                isRender logical = true
            end

            if isempty(targetAxes)
                figure
                ax = gca;
            else
                ax = targetAxes;
            end
            x = obj.RawData(:,1);
            [x,idx] = sort(x);
            y = obj.RawData(:,2);
            y = y(idx);
            l = plot(ax,x,y,obj.FitPlotData(:,1),obj.FitPlotData(:,2));
            l(1).LineWidth = 1.5;
            l(2).LineWidth = 1.5;
            legend(ax,"Raw Data","Fit Data")

            if isRender
                box on
                xlabel("$x$",'Interpreter','latex')
                ylabel("$y$",'Interpreter','latex')
            end
        end
        
    end
end

