classdef ScopeValue < BecAnalysis
    %OD Summary of this class goes here
    %   Detailed explanation goes here

    properties
        FullValueName
    end

    properties (SetAccess = protected)

    end

    properties (Hidden,Transient)
        ScopeLine
    end

    methods
        function obj = ScopeValue(becExp)
            %OD Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Scope Value",...
                num = 34, ...
                fpath = fullfile(becExp.DataAnalysisPath,"ScopeValue"),...
                loc = [0.6936,0.032],...
                size = [0.3069,0.57]...
                );
        end

        function initialize(obj)
            %% Check if we can plot scope values
            if isempty(obj.FullValueName)
                warning("No FullValueName given. Can not plot scope values.")
                return
            elseif ismissing(obj.FullValueName)
                warning("No FullValueName given. Can not plot scope values.")
                return
            end

            %% Initialize plots
            fig = obj.Chart(1).initialize;
            if ~ishandle(fig)
                return
            end

            % Initialize axis
            ax = gca;
            co = ax.ColorOrder;
            conum=size(co, 1);
            mOrder = markerOrder();

            obj.ScopeLine = matlab.graphics.chart.primitive.ErrorBar.empty;

            hold(ax,'on')

            % Initialize raw plots
            for ii = 1:numel(obj.FullValueName)
                obj.ScopeLine(ii) = errorbar(ax,1,1,[]);
                obj.ScopeLine(ii).Marker = mOrder(ii);
                obj.ScopeLine(ii).MarkerFaceColor = co(ii,:);
                obj.ScopeLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                obj.ScopeLine(ii).MarkerSize = 8;
                obj.ScopeLine(ii).LineWidth = 2;
                obj.ScopeLine(ii).Color = co(ii,:);
                obj.ScopeLine(ii).CapSize = 0;
            end

            lg = legend(ax,obj.FullValueName(:));
            lg.Location = "best";
            lg.Interpreter = 'none';
            if numel(lg.String) >= 8
                lg.NumColumns = 2;
                lg.FontSize = 8;
                lg.Location = "best";
            end

            ax.Box = "on";
            ax.XGrid = "on";
            ax.YGrid = "on";
            ax.XLabel.String = obj.BecExp.XLabel;
            ax.XLabel.Interpreter = "latex";
            ax.YLabel.String = "Scope Data";
            ax.YLabel.Interpreter = "latex";
            ax.FontSize = 12;

        end

        function updateData(obj,~)
            % becExp = obj.BecExp;
            
        end

        function updateFigure(obj,~)
            becExp = obj.BecExp;
            paraList = becExp.ScannedParameterList;
            fig = obj.Chart(1).Figure;
            if becExp.NCompletedRun < 1 ...
                    || (isempty(fig) || ~ishandle(fig))
                return
            end
            
            for ii = 1:numel(obj.FullValueName)
                [x,y,std] = computeStd(paraList, becExp.ScopeData.(obj.FullValueName(ii)), becExp.AveragingMethod);
                obj.ScopeLine(ii).XData = x;
                obj.ScopeLine(ii).YData = y;
                obj.ScopeLine(ii).YNegativeDelta = std;
                obj.ScopeLine(ii).YPositiveDelta = std;
            end
            lg = findobj(fig,"Type","Legend");
            lg.Location = "best";
        end

        function refresh(obj)
            obj.initialize;
            obj.updateData(obj.BecExp.NCompletedRun)
            obj.updateFigure(obj.BecExp.NCompletedRun)
        end

    end
end

