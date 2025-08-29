classdef (Abstract) TimeSim < Sim
    %:class:`TimeSim` abstract base for time-domain simulations.
    
    properties
        InitialTime double = 0
        TotalTime (1,1) double
        TimeStep (1,1) double
        SavePeriod = 1
        AveragePeriod = 1
    end
    
    methods
        function obj = TimeSim(trialName,config)
            % Construct a :class:`TimeSim`.
            %
            % :param trialName: Simulation name
            % :type trialName: string
            % :param config: Config table/struct or name
            % :type config: string | table | struct
            obj@Sim(trialName,config);
        end
        
    end
end

