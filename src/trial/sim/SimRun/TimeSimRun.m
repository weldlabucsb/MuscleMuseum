classdef (Abstract) TimeSimRun < SimRun
    %:class:`TimeSimRun` abstract base for a time-discretized simulation run.
    
    properties
        InitialTime double = 0
        TotalTime (1,1) double
        TimeStep (1,1) double
        SavePeriod = 1e3
        AveragePeriod = 200
        InitialCondition InitialCondition
    end

    properties(Dependent)
        NTimeStep
        TimeList
        TimeListAvg
        NDataRow
        NDataRowMemory
    end
    
    methods
        function obj = TimeSimRun(timeSim)
            % Construct a :class:`TimeSimRun` from a :class:`TimeSim`.
            %
            % :param timeSim: Parent :class:`TimeSim` or :class:`SpaceTimeSim`
            % :type timeSim: any, optional
            arguments
                timeSim = []
            end
            obj@SimRun(timeSim)
            if ~isempty(timeSim)
                if isa(timeSim,"TimeSim") || isa(timeSim,"SpaceTimeSim")
                    obj.InitialTime = timeSim.InitialTime;
                    obj.TotalTime = timeSim.TotalTime;
                    obj.TimeStep = timeSim.TimeStep;
                    obj.SavePeriod = timeSim.SavePeriod;
                    obj.AveragePeriod = timeSim.AveragePeriod;
                else
                    error("Input must be an object of the TimeSim class")
                end
            end
        end

        function nTimeStep = get.NTimeStep(obj)
            % Number of time steps.
            nTimeStep = numel(obj.TimeList);
        end

        function tList = get.TimeList(obj)
            % Time grid from :attr:`InitialTime` to :attr:`TotalTime`.
            tList = obj.InitialTime : obj.TimeStep : obj.TotalTime;
        end
        
        function tListAvg = get.TimeListAvg(obj)
            % Subsampled time grid for averages with period :attr:`AveragePeriod`.
            aP = obj.AveragePeriod;
            tList = obj.TimeList;
            nt = obj.NTimeStep;
            tListAvg = tList(aP:aP:nt);
        end

        function nDataRow = get.NDataRow(obj)
            % Expected number of averaged rows.
            nDataRow = floor(obj.NTimeStep / obj.AveragePeriod);
        end

        function nDataRowMemory = get.NDataRowMemory(obj)
            % Number of rows per save period.
            nDataRowMemory = floor(obj.SavePeriod / obj.AveragePeriod);
        end

        function check(obj,isWarning)
            % Check whether the run is completed by inspecting saved rows.
            arguments
                obj TimeSimRun
                isWarning logical = true
            end
            try
                matObj = matfile(obj.RunPath,'Writable',true);
                [nRow,~] = size(matObj,'Time');
                if nRow == obj.NDataRow
                    obj.IsCompleted = true;
                elseif isWarning
                    warning("Run" + num2str(obj.RunIndex) + " was not completed")
                end
            catch
                if isWarning
                    warning("Run" + num2str(obj.RunIndex) + " was not completed")
                end
            end
        end
        
    end
end

