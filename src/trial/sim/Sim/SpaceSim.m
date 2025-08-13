classdef (Abstract) SpaceSim < Sim
    %:class:`SpaceSim` abstract base for spatial simulations.
    %
    % Defines origin, range, step, dimension, and boundary condition.
    
    properties
        SpaceOrigin double = [0;0;0] % in meters
        SpaceRange double {mustBePositive} % in meters
        SpaceStep double {mustBePositive}
        Dimension (1,1) double {mustBeInteger,mustBeInRange(Dimension,1,3)} = 1
        BoundaryCondition string {mustBeMember(BoundaryCondition,{'Periodic','Dirichlet','Neumann'})} = "Periodic"
    end
    
    methods
        function obj = SpaceSim(trialName,config)
            % Construct a :class:`SpaceSim`.
            %
            % :param trialName: Simulation name
            % :type trialName: string
            % :param config: Config table/struct or name
            % :type config: string | table | struct
            obj@Sim(trialName,config);
        end
        
    end
end

