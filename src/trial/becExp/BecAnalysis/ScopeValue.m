classdef ScopeValue < BecAnalysis
    %:class:`ScopeValue` plot scope-derived values vs scanned variable.
    %
    % Reads values captured from hardware logs (via :attr:`BecExp.ScopeData`)
    % and displays them as errorbar plots, one series per entry in
    % :attr:`FullValueName`.
    %
    % **Associated Charts:**
    %   - Chart(1): "Scope Value" - Error bar plots of scope measurements vs parameter

    properties
        FullValueName % Scope measurement identifiers (e.g., "ScopeX_Ch1_Rms", "ScopeY_Ch2_Peak")
    end

    properties (SetAccess = protected)

    end

    properties (Hidden,Transient)
        ScopeLine % Errorbar plot handles for scope measurement series
    end

    methods
        function obj = ScopeValue(becExp)
            % Construct :class:`ScopeValue` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
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
            % Initialize chart and series for scope values.
            
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
            % Reserved for future precomputation of scope data.
            %
            % Currently unused as scope values are read directly from
            % :attr:`BecExp.ScopeData` during plotting.
            %
            % :param ~: Unused run index placeholder
            % :type ~: double
        end

        function updateFigure(obj,~)
            % Update errorbar series for each selected scope value.
            becExp = obj.BecExp;
            paraList = becExp.ScannedParameterList;
            fig = obj.Chart(1).Figure;
            if becExp.NCompletedRun < 1 ...
                    || (isempty(fig) || ~ishandle(fig))
                return
            end
            
            for ii = 1:numel(obj.FullValueName)
                [x,y,std] = computeAveErr(paraList, becExp.ScopeData.(obj.FullValueName(ii)), becExp.AveragingMethod);
                obj.ScopeLine(ii).XData = x;
                obj.ScopeLine(ii).YData = y;
                obj.ScopeLine(ii).YNegativeDelta = std;
                obj.ScopeLine(ii).YPositiveDelta = std;
            end
            lg = findobj(fig,"Type","Legend");
            lg.Location = "best";
        end

        function refresh(obj)
            % Rebuild and redraw chart from current scope data.
            obj.initialize;
            obj.updateData(obj.BecExp.NCompletedRun)
            obj.updateFigure(obj.BecExp.NCompletedRun)
        end

    end
end

