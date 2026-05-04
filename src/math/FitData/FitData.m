classdef (Abstract) FitData < handle
    %:class:`FitData` abstract base for data fitting operations.
    %
    % Provides a framework for fitting mathematical functions to experimental data
    % using MATLAB's curve fitting toolbox. Supports customizable fit parameters,
    % bounds, and optimization settings.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a Gaussian fit object
    %     data = [x, y]; % n x 2 array of x,y coordinates
    %     gaussianFit = GaussianFit1D(data);
    %     gaussianFit.do();
    %     gaussianFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Customize fit parameters
    %     fitObj = LinearFit1D(data);
    %     fitObj.IsOverride = true;
    %     fitObj.StartPointOverride = [1.0, 0.5];
    %     fitObj.do();

    properties
        RawData double % Input data for fitting
        IsOverride logical = false % Whether to use override parameters
        StartPointOverride (1,:) double % Fit coefficient start point override
        LowerOverride (1,:) double % Fit coefficient lower bound override
        UpperOverride (1,:) double % Fit coefficient upper bound override
        TolFun (1,1) double = 1E-16 % Function tolerance for optimization
        MaxFunEvals (1,1) double = 2000 % Maximum function evaluations
        MaxIter (1,1) double = 2000 % Maximum iterations for optimization
        NPlot (1,1) double = 1000 % Number of points for plotting
    end

    properties (Dependent,Hidden,Transient)
        Option % MATLAB fitoptions object
    end

    properties (SetAccess = protected)
        StartPoint (1,:) double % Fit coefficient start point
        Lower (1,:) double % Fit coefficient lower bound
        Upper (1,:) double % Fit coefficient upper bound
        Func % MATLAB fittype object
        Result % MATLAB fitobject
        Gof % Goodness of fit
        Coefficient double % Coefficient resulted from fit
    end

    properties (Dependent)
        CoefficientName string % Names of fit coefficients
        FitFormula string % Mathematical formula for the fit function
        MinimumDataSize double % Minimum number of data points required
    end

    methods
        function obj = FitData(rawData)
            % Construct a :class:`FitData`.
            %
            % :param rawData: Input data for fitting
            % :type rawData: double array
            %
            obj.setFormula
            obj.RawData = rawData;
        end

        function option = get.Option(obj)
            % Build MATLAB fitoptions object with current settings.
            %
            % :return: Configured fitoptions object
            % :rtype: fitoptions
            %
            coffSize = size(obj.CoefficientName);
            if ~isempty(obj.Func)
                option = fitoptions(obj.Func);
                if isa(option,'curvefit.llsqoptions')
                    return
                end

                if obj.IsOverride && ~isempty(obj.StartPointOverride)...
                        && all(size(obj.StartPointOverride) == coffSize)
                    option.StartPoint = obj.StartPointOverride;
                elseif ~isempty(obj.StartPoint)
                    option.StartPoint = obj.StartPoint;
                end

                if obj.IsOverride && ~isempty(obj.LowerOverride)...
                        && all(size(obj.LowerOverride) == coffSize)
                    option.Lower = obj.LowerOverride;
                elseif ~isempty(obj.Lower)
                    option.Lower = obj.Lower;
                end

                if obj.IsOverride && ~isempty(obj.UpperOverride)...
                        && all(size(obj.UpperOverride) == coffSize)
                    option.Upper = obj.UpperOverride;
                elseif ~isempty(obj.Upper)
                    option.Upper = obj.Upper;
                end

                if option.Method ~= "LinearLeastSquares"
                    option.TolFun = obj.TolFun;
                    option.MaxFunEvals = obj.MaxFunEvals;
                    option.MaxIter = obj.MaxIter;
                end

                % validate options
                if any(option.Upper < option.Lower)
                    idx = option.Upper < option.Lower;
                    temp = option.Upper(idx);
                    option.Upper(idx) = option.Lower(idx);
                    option.Lower(idx) = temp;
                end
                if any((option.StartPoint < option.Lower) | (option.StartPoint > option.Upper))
                    idx = (option.StartPoint < option.Lower) | (option.StartPoint > option.Upper);
                    option.StartPoint(idx) = (option.Lower(idx) + option.Upper(idx)) / 2;
                end
            end
        end

        function cName = get.CoefficientName(obj)
            % Get names of fit coefficients.
            %
            % :return: Coefficient names
            % :rtype: string array
            %
            if isempty(obj.Func)
                cName = string.empty;
            else
                cName = string(coeffnames(obj.Func)).';
            end
        end

        function minSize = get.MinimumDataSize(obj)
            % Get minimum number of data points required for fitting.
            %
            % :return: Minimum data size
            % :rtype: double
            %
            cName = obj.CoefficientName;
            if isempty(cName)
                minSize = 1;
            else
                minSize = numel(cName);
            end
        end

        function formulaString = get.FitFormula(obj)
            % Get mathematical formula for the fit function.
            %
            % :return: Formula string
            % :rtype: string
            %
            if isempty(obj.Func)
                formulaString = string.empty;
            else
                formulaString = string(formula(obj.Func));
            end
        end
    
        function set.RawData(obj,val)
            % Set raw data and automatically guess coefficients.
            %
            % :param val: Input data
            % :type val: double array
            %
            obj.RawData = obj.checkData(val);
            obj.guessCoefficient;
        end
        
        function setDefaultOverride(obj)
            % Set override parameters to default values.
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     fitObj.setDefaultOverride();
            %
            obj.guessCoefficient
            nameList = ["StartPoint","Lower","Upper"];
            for ii = 1:numel(nameList)
                if isempty(obj.(nameList(ii)+"Override"))
                    obj.(nameList(ii)+"Override") = obj.(nameList(ii));
                end
            end
        end

        function clearOverride(obj)
            % Clear all override parameters.
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     fitObj.clearOverride();
            %
            nameList = ["StartPoint","Lower","Upper"];
            for ii = 1:numel(nameList)
                obj.(nameList(ii)+"Override") = [];
            end
        end
    end

    methods (Abstract)
        setFormula(obj)
        output = checkData(obj,RawData)
        guessCoefficient(obj)
        obj = do(obj)
        plot(obj)
    end
end

