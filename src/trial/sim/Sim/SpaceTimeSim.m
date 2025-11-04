classdef (Abstract) SpaceTimeSim < Sim
    %TIMESIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        InitialTime double = 0
        TotalTime (1,1) double
        TimeStep (1,1) double
        SavePeriod = 1
        AveragePeriod = 1
        SpaceOrigin double = [0;0;0] % in meters
        SpaceRange double {mustBePositive} % in meters
        SpaceStep double {mustBePositive}
        Dimension (1,1) double {mustBeInteger,mustBeInRange(Dimension,1,3)} = 1
        BoundaryCondition string {mustBeMember(BoundaryCondition,{'Periodic','Dirichlet','Neumann'})} = "Periodic"
    end
    
    methods
        function obj = SpaceTimeSim(trialName,simName)
            %TIMESIM Construct an instance of this class
            %   Detailed explanation goes here
            obj@Sim(trialName,simName);
        end
        
        function setWaveFunctionSize(obj)
            output = obj.Output;
            if ~isempty(output) && ~isempty(output(output.VariableName == "WaveFunction",:))
                nSpaceStep = getNSpaceStep(obj.SpaceRange,obj.SpaceStep);
                output(output.VariableName == "WaveFunction",:).Size = nSpaceStep;
            end
            obj.Output = output;
        end
    end
end

