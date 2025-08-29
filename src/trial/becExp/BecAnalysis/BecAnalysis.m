classdef (Abstract) BecAnalysis < handle & matlab.mixin.SetGetExactNames
    %BECANALYSIS Summary of this class goes here
    %   Detailed explanation goes here

    properties 
        Chart Chart
        Gui Gui
    end
    
    properties (SetAccess = protected)
        BecExp BecExp
    end
    
    methods 
        function obj = BecAnalysis(becExp)
            obj.BecExp = becExp;
        end
    end
    
    methods
        
        function initialize(obj)
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).initialize;
            end
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).initialize(obj.BecExp);
            end
        end

        function update(obj,runIdx)
            obj.updateData(runIdx);
            obj.updateFigure(runIdx);
        end

        function updateData(obj,runIdx)
            % Override in subclasses for specific data processing
        end

        function updateFigure(obj,runIdx)
            % Override in subclasses for specific plotting
        end

        function finalize(obj)
            % Override in subclasses for final processing
        end

        function save(obj)
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).save;
            end
        end

        function show(obj)
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).initialize(obj.BecExp);
            end
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).show;
            end
        end
        
        function browserShow(obj)
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
            obj.initialize
            for runIdx = 1:obj.BecExp.NCompletedRun
                obj.updateData(runIdx)
            end
            obj.updateFigure(runIdx)
            obj.finalize
        end

        function toggle(obj,isEnabled)
            for ii = 1:numel(obj.Gui)
                obj.Gui(ii).IsEnabled = isEnabled;
            end
            for ii = 1:numel(obj.Chart)
                obj.Chart(ii).IsEnabled = isEnabled;
            end
        end

        function close(obj)
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
            % Reshape 1D data to 2D grid based on parameter values
            % Handles repeats by averaging data points with the same parameter combination
            % Optimized version using vectorized operations
            if ~obj.BecExp.Is2DScan
                data2D = data1D;
                return
            end
            
            paraList = obj.BecExp.ScannedParameterList;
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
            % Get x and y data for 2D plots
            if ~obj.BecExp.Is2DScan
                xData = obj.BecExp.ScannedParameterList;
                yData = [];
                return
            end
            
            paraList = obj.BecExp.ScannedParameterList;
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
            % Validate that 2D data can be properly reshaped
            if ~obj.BecExp.Is2DScan
                isValid2D = true;
                return
            end
            
            paraList = obj.BecExp.ScannedParameterList;
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
            % Reshape 1D data to 2D grid with standard deviation for repeats
            % Returns both the averaged data and the standard deviation
            % Optimized version using vectorized operations
            if ~obj.BecExp.Is2DScan
                data2D = data1D;
                std2D = zeros(size(data1D));
                return
            end
            
            paraList = obj.BecExp.ScannedParameterList;
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

