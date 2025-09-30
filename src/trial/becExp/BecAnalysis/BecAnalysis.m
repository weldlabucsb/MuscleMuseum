classdef (Abstract) BecAnalysis < handle & matlab.mixin.SetGetExactNames
    %:class:`BecAnalysis` abstract base for BEC experiment analysis modules.
    %
    % Provides a common lifecycle API (:meth:`initialize`, :meth:`update`,
    % :meth:`finalize`, :meth:`save`, :meth:`show`, :meth:`refresh`, :meth:`close`)
    % and helpers for 2D scans (reshape, validation, axis data). Subclasses
    % implement :meth:`updateData` and :meth:`updateFigure`.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    bx = BecExp("Test");
    %    an = Od(bx);  % :class:`Od` is a :class:`BecAnalysis`
    %    an.initialize();
    %    an.update(1);
    %    an.finalize();

    properties 
        Chart Chart % One or more :class:`Chart` figure instances managed by this analysis module
        Gui Gui % One or more :class:`Gui` panel or app instances managed by this analysis module
    end
    
    properties (SetAccess = protected)
        BecExp BecExp % Owning :class:`BecExp` trial instance that contains this analysis module
    end
    
    methods 
        function obj = BecAnalysis(becExp)
            % Construct :class:`BecAnalysis` base analyzer.
            %
            % :param becExp: Owning experiment trial
            % :type becExp: :class:`BecExp`
            obj.BecExp = becExp;
        end
    end
    
    methods
        
        function initialize(obj)
            % Initialize charts and GUI panels.
            %
            % Calls :meth:`Chart.initialize` and :meth:`Gui.initialize` for all
            % registered objects.
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).initialize;
            end
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).initialize(obj.BecExp);
            end
        end

        function update(obj,runIdx)
            % Process and render data for a specific run.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
            obj.updateData(runIdx);
            obj.updateFigure(runIdx);
        end

        function updateData(obj,runIdx)
            % Override in subclasses for specific data processing.
            %
            % Implement analysis-specific data computation and storage in subclasses.
            % This method is called for each new run to process raw data.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
        end

        function updateFigure(obj,runIdx)
            % Override in subclasses for specific plotting and visualization.
            %
            % Implement analysis-specific figure updates in subclasses. This method
            % is called after data processing to refresh visual displays.
            %
            % :param runIdx: Run index to render
            % :type runIdx: double
        end

        function finalize(obj)
            % Override in subclasses for final processing after all runs.
            %
            % Implement any post-processing steps that require all run data
            % to be available, such as final plots or summary calculations.
        end

        function save(obj)
            % Save all charts associated with this analysis module.
            %
            % Calls the save method on each :class:`Chart` instance to persist
            % figures to disk in the trial's analysis directory.
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).save;
            end
        end

        function show(obj)
            % Display GUI panels and chart windows.
            %
            % Initializes and shows all GUI panels and chart figures associated
            % with this analysis module on the current monitor.
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).initialize(obj.BecExp);
            end
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).show;
            end
        end
        
        function browserShow(obj)
            % Display charts and GUIs in browser-style layout across monitors.
            %
            % Arranges analysis windows on secondary monitor (if available) in
            % browser-like tiled layout for multi-monitor workflows. Falls back
            % to primary monitor if control panel is not running on secondary.
            mp = sortMonitor;
            monitorIndex = 1;
            if size(mp,1) > 1
                appHandle = get(findall(0, 'Tag', obj.BecExp.ControlAppName), 'RunningAppInstance');
                if ~isempty(appHandle)
                    if isvalid(appHandle)
                        monitorIndex = 2;
                    end
                end
            end
            for jj = 1:numel(obj.Gui)
                obj.Gui(jj).Monitor = monitorIndex;
            end
            for jj = 1:numel(obj.Chart)
                obj.Chart(jj).IsBrowser = true;
                obj.Chart(jj).Monitor = monitorIndex;
            end
            obj.show
        end

        function refresh(obj)
            % Recompute data for all runs and refresh visualization.
            %
            % Reinitializes the analysis, reprocesses all completed runs,
            % updates figures with the latest run, and performs finalization.
            obj.initialize
            for runIdx = 1:obj.BecExp.NCompletedRun
                obj.updateData(runIdx)
            end
            obj.updateFigure(runIdx)
            obj.finalize
        end

        function refreshData(obj)
            if ~isempty(obj.Chart)
                tempChartIsEnabled = num2cell([obj.Chart.IsEnabled]);
                [obj.Chart.IsEnabled] = deal(false);
            end
            if ~isempty(obj.Gui)
                tempGuiIsEnabled = num2cell([obj.Gui.IsEnabled]);
                [obj.Gui.IsEnabled] = deal(false);
            end
            obj.refresh;
            if ~isempty(obj.Chart)
                [obj.Chart.IsEnabled] = tempChartIsEnabled{:};
            end
            if ~isempty(obj.Gui)
                [obj.Gui.IsEnabled] = tempGuiIsEnabled{:};
            end
        end

        function toggle(obj,isEnabled)
            % Enable or disable all GUIs and charts in this analysis module.
            %
            % Controls the enabled state of all associated GUI panels and chart
            % figures, affecting their visibility and interaction capabilities.
            %
            % :param isEnabled: Flag to enable (true) or disable (false) components
            % :type isEnabled: logical
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).IsEnabled = isEnabled;
            end
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).IsEnabled = isEnabled;
            end
        end

        function close(obj)
            % Close all GUI panels and chart windows.
            %
            % Properly closes and cleans up all GUI panels and chart figures
            % associated with this analysis module.
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).close;
            end
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).close;
            end
        end
    end

    % New methods for 2D support
    methods (Access = protected)
        
        function data2D = reshapeDataTo2D(obj, data1D)
            % Reshape 1D series to 2D grid using scanned parameters.
            %
            % Converts run-indexed data to a 2D parameter grid for 2D scans.
            % Multiple measurements at the same parameter point are averaged.
            %
            % :param data1D: Vector of measurement values per run
            % :type data1D: double
            % :return: 2D matrix indexed by [secondary, primary] variables
            % :rtype: double
            if ~obj.BecExp.Is2DScan
                data2D = data1D;
                return
            end
            
            paraList = obj.BecExp.ScannedVariableList;
            if isempty(paraList) || size(paraList, 1) ~= 2
                data2D = data1D;
                return
            end
            
            paraList1 = paraList(1, :);
            paraList2 = paraList(2, :);
            
            % Ensure data1D has the same length as parameters
            if length(data1D) ~= length(paraList1)
                data1D = data1D(1:min(length(data1D), length(paraList1)));
                paraList1 = paraList1(1:length(data1D));
                paraList2 = paraList2(1:length(data1D));
            end
            
            % Get unique values for each parameter
            [unique1, ~, idx1] = unique(paraList1);
            [unique2, ~, idx2] = unique(paraList2);
            
            % Create 2D data array
            data2D = zeros(length(unique2), length(unique1));
            
            % Use accumarray for efficient grouping and averaging
            % Create linear indices for the 2D grid
            linearIndices = sub2ind([length(unique2), length(unique1)], idx2, idx1);
            
            % Use accumarray to group data by linear index and compute mean
            % This automatically handles repeats by averaging
            averagedData = accumarray(linearIndices, data1D, [length(unique2) * length(unique1), 1], @mean, NaN);
            
            % Reshape back to 2D
            data2D = reshape(averagedData, [length(unique2), length(unique1)]);
        end
        
        function [xData, yData] = get2DPlotData(obj)
            % Get unique axis values for 2D parameter plots.
            %
            % Extracts sorted unique values for both scanned parameters
            % to create axis arrays for 2D visualization.
            %
            % :return: Unique primary (x) and secondary (y) parameter values
            % :rtype: double, double
            if ~obj.BecExp.Is2DScan
                xData = obj.BecExp.ScannedVariableList;
                yData = [];
                return
            end
            
            paraList = obj.BecExp.ScannedVariableList;
            if isempty(paraList) || size(paraList, 1) ~= 2
                xData = [];
                yData = [];
                return
            end
            
            paraList1 = paraList(1, :);
            paraList2 = paraList(2, :);
            
            xData = unique(paraList1);
            yData = unique(paraList2);
        end
        
        function isValid2D = validate2DData(obj, data1D)
            % Validate grid completeness for 2D parameter scans.
            %
            % Checks if the data covers a complete rectangular grid in
            % parameter space, which is required for proper 2D visualization.
            %
            % :param data1D: Vector of measurement values per run
            % :type data1D: double
            % :return: True if data covers a complete rectangular parameter grid
            % :rtype: logical
            if ~obj.BecExp.Is2DScan
                isValid2D = true;
                return
            end
            
            paraList = obj.BecExp.ScannedVariableList;
            if isempty(paraList) || size(paraList, 1) ~= 2
                isValid2D = false;
                return
            end
            
            paraList1 = paraList(1, :);
            paraList2 = paraList(2, :);
            
            if length(data1D) ~= length(paraList1) || length(data1D) ~= length(paraList2)
                isValid2D = false;
                return
            end
            
            % Check if we have a complete grid
            unique1 = unique(paraList1);
            unique2 = unique(paraList2);
            expectedRuns = length(unique1) * length(unique2);
            
            isValid2D = length(data1D) == expectedRuns;
        end
        
        function [data2D, std2D] = reshapeDataTo2DWithStd(obj, data1D)
            % Reshape 1D series to 2D grid with per-cell standard deviation.
            %
            % Converts run-indexed data to 2D parameter grid and computes
            % standard deviation for repeated measurements at each grid point.
            %
            % :param data1D: Vector of measurement values per run
            % :type data1D: double
            % :return: Averaged 2D data matrix and corresponding standard deviation matrix
            % :rtype: double, double
            if ~obj.BecExp.Is2DScan
                data2D = data1D;
                std2D = zeros(size(data1D));
                return
            end
            
            paraList = obj.BecExp.ScannedVariableList;
            if isempty(paraList) || size(paraList, 1) ~= 2
                data2D = data1D;
                std2D = zeros(size(data1D));
                return
            end
            
            paraList1 = paraList(1, :);
            paraList2 = paraList(2, :);
            
            % Ensure data1D has the same length as parameters
            if length(data1D) ~= length(paraList1)
                data1D = data1D(1:min(length(data1D), length(paraList1)));
                paraList1 = paraList1(1:length(data1D));
                paraList2 = paraList2(1:length(data1D));
            end
            
            % Get unique values for each parameter
            [unique1, ~, idx1] = unique(paraList1);
            [unique2, ~, idx2] = unique(paraList2);
            
            % Create 2D data arrays
            data2D = zeros(length(unique2), length(unique1));
            std2D = zeros(length(unique2), length(unique1));
            
            % Use accumarray for efficient grouping and statistics
            % Create linear indices for the 2D grid
            linearIndices = sub2ind([length(unique2), length(unique1)], idx2, idx1);
            
            % Use accumarray to group data by linear index and compute mean
            averagedData = accumarray(linearIndices, data1D, [length(unique2) * length(unique1), 1], @mean, NaN);
            
            % Use accumarray to compute standard deviation
            % We need to handle the case where there's only one data point per group
            stdData = accumarray(linearIndices, data1D, [length(unique2) * length(unique1), 1], @(x) std(x, 0), 0);
            
            % Reshape back to 2D
            data2D = reshape(averagedData, [length(unique2), length(unique1)]);
            std2D = reshape(stdData, [length(unique2), length(unique1)]);
            
            % Set standard deviation to 0 for single data points (where std would be NaN)
            std2D(isnan(std2D)) = 0;
        end
    end

end

