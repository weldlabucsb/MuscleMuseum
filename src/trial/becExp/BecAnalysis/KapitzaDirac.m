classdef KapitzaDirac < BecAnalysis
    %OD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)

    end

    properties (Constant)

    end

    properties (SetObservable)
        
    end

    properties (Hidden,Transient)

    end
    
    methods
        function obj = KapitzaDirac(becExp)
            %OD Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Kapitza Dirac",...
                num = 32, ...
                fpath = fullfile(becExp.DataAnalysisPath,"KapitzaDirac"),...
                loc = [0.3919,0.032],...
                size = [0.6081,0.57]...
                );
        end
        
        function initialize(obj)
            fig = obj.Chart(1).initialize;

            if ~ishandle(fig)
                return
            end
        end

        function updateData(obj,runIdx)
            becExp = obj.BecExp;
        end

        function updateFigure(obj,~)
            if ishandle(obj.Chart(1).Figure)
                fig = figure(obj.Chart(1).Figure);
            else
                return
            end
        end

    end

    methods (Static)
        function handlePropEvents(src,evnt)
            switch src.Name
                case 'YLim'
                    obj = evnt.AffectedObject;
                    for ii = 1:numel(obj.Chart)
                        if ishandle(obj.Chart(ii).Figure)
                            fig = obj.Chart(ii).Figure;
                            ax = fig.CurrentAxes;
                            ax.YLim = obj.YLim;
                        end
                    end
            end
        end
    end
end

