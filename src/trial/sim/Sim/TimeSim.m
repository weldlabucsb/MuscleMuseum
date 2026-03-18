classdef (Abstract) TimeSim < Sim
    %:class:`TimeSim` abstract base for time-domain simulations.

    properties (SetObservable = true)
        InitialTime double = 0
        TotalTime (1,1) double
        TimeStep (1,1) double
        SavePeriod = 1e3
        AveragePeriod = 200
    end

    methods
        function obj = TimeSim(trialName,simName)
            % Construct a :class:`TimeSim`.
            %
            % :param trialName: Simulation name
            % :type trialName: string
            % :param config: Config table/struct or name
            % :type config: string | table | struct
            obj@Sim(trialName,simName);
            addlistener(obj,'InitialTime','PostSet',@obj.handlePropEvents);
            addlistener(obj,'TotalTime','PostSet',@obj.handlePropEvents);
            addlistener(obj,'TimeStep','PostSet',@obj.handlePropEvents);
            addlistener(obj,'SavePeriod','PostSet',@obj.handlePropEvents);
            addlistener(obj,'AveragePeriod','PostSet',@obj.handlePropEvents);
        end

    end

    methods (Static)
        function handlePropEvents(src,evnt)
            obj = evnt.AffectedObject;
            if isempty(obj.SimRun)
                return
            end

            switch src.Name
                case 'InitialTime'
                    [obj.SimRun.InitialTime] = deal(obj.InitialTime);
                case 'TotalTime'
                    [obj.SimRun.TotalTime] = deal(obj.TotalTime);
                case 'TimeStep'
                    [obj.SimRun.TimeStep] = deal(obj.TimeStep);
                case 'SavePeriod'
                    [obj.SimRun.SavePeriod] = deal(obj.SavePeriod);
                case 'AveragePeriod'
                    [obj.SimRun.AveragePeriod] = deal(obj.AveragePeriod);
            end
        end
    end
end

