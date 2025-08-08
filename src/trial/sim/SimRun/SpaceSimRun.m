classdef (Abstract) SpaceSimRun < SimRun
    %:class:`SpaceSimRun` abstract base for a space-discretized simulation run.
    
    properties
        SpaceOrigin double = [0;0;0] % in meters
        SpaceRange double {mustBePositive} % in meters
        SpaceStep double {mustBePositive} % in meters
        BoundaryCondition string {mustBeMember(BoundaryCondition,{"Periodic","Dirichlet","Neumann"})} = "Periodic"
    end

    properties (SetAccess = protected)
        Dimension (1,1) double {mustBeInteger,mustBeInRange(Dimension,1,3)} = 1
    end

    properties (Dependent)
        NSpaceStep
        SpaceList
        SpaceAngularFrequencyStep % for fft
        SpaceAngularFrequencyList % for fft
    end
    
    methods
        function obj = SpaceSimRun(spaceSim)
            % Construct a :class:`SpaceSimRun` using :class:`SpaceSim` metadata.
            %
            % :param spaceSim: Parent :class:`SpaceSim` or :class:`SpaceTimeSim`
            % :type spaceSim: any, optional
            arguments
                spaceSim = []
            end
            obj@SimRun(spaceSim)
            if ~isempty(spaceSim)
                if isa(spaceSim,"SpaceSim") || isa(spaceSim,"SpaceTimeSim")
                    obj.SpaceOrigin = spaceSim.SpaceOrigin;
                    obj.SpaceRange = spaceSim.SpaceRange;
                    obj.SpaceStep = spaceSim.SpaceStep;
                    obj.Dimension = spaceSim.Dimension;
                else
                    error("Input must be an object of the SpaceSim class")
                end
            end
        end

        function obj = set.SpaceStep(obj,val)
            % Ensure number of steps is a power of 2.
            sRange = obj.SpaceRange;
            if isempty(sRange)
                return
            elseif isempty(obj.SpaceStep)
                nSpaceStep = getNSpaceStep(sRange,val);
                obj.SpaceStep = sRange ./ (nSpaceStep - 1);
            elseif any(abs(val - obj.SpaceStep)>eps)
                nSpaceStep = getNSpaceStep(sRange,val);
                obj.SpaceStep = sRange ./ (nSpaceStep - 1);
            end
        end

        function obj = set.SpaceRange(obj,val)
            % Update space step when range changes.
            obj.SpaceRange = val;
            step = obj.SpaceStep;
            if isempty(step)
                return
            else
                nSpaceStep = val ./ step;
                nSpaceStep = 2.^(ceil(log2(nSpaceStep)));
                obj.SpaceStep = val ./ (nSpaceStep - 1);
            end
        end

        function NN = get.NSpaceStep(obj)
            % Number of space grid points per dimension.
            switch obj.Dimension
                case 1
                    NN = numel(obj.SpaceList);
                case 2
                    NN = cellfun(@numel,(obj.SpaceList));
                case 3
                    NN = cellfun(@numel,(obj.SpaceList));
            end
        end

        function sList = get.SpaceList(obj)
            % Space grid (1D) or cell of vectors (2D/3D).
            origin = obj.SpaceOrigin;
            sRange = obj.SpaceRange;
            step = obj.SpaceStep;
            switch obj.Dimension
                case 1
                    sList = origin(1) + (-sRange(1)/2 : step : sRange(1)/2);
                case 2
                    sListX = origin(1) + (-sRange(1)/2 : step : sRange(1)/2);
                    sListY = origin(2) + (-sRange(2)/2 : step : sRange(2)/2);
                    sList = {sListX;sListY};
                case 3
                    sListX = origin(1) + (-sRange(1)/2 : step : sRange(1)/2);
                    sListY = origin(2) + (-sRange(2)/2 : step : sRange(2)/2);
                    sListZ = origin(3) + (-sRange(3)/2 : step : sRange(3)/2);
                    sList = {sListX;sListY;sListZ};
            end
        end

        function kList = get.SpaceAngularFrequencyList(obj)
            % FFT angular frequency grid(s) corresponding to :attr:`SpaceList`.
            NN = obj.NSpaceStep;
            step = obj.SpaceStep;
            switch obj.Dimension
                case 1
                    kList = 2 * pi * [0:NN(1)/2-1 -NN(1)/2:-1]/NN(1)/step(1);
                case 2
                    kListx = 2 * pi * [0:NN(1)/2-1 -NN(1)/2:-1]/NN(1)/step(1);
                    kListy = 2 * pi * [0:NN(2)/2-1 -NN(2)/2:-1]/NN(2)/step(2);
                    kList = {kListx;kListy};
                case 3
                    kListx = 2 * pi * [0:NN(1)/2-1 -NN(1)/2:-1]/NN(1)/step(1);
                    kListy = 2 * pi * [0:NN(2)/2-1 -NN(2)/2:-1]/NN(2)/step(2);
                    kListz = 2 * pi * [0:NN(3)/2-1 -NN(3)/2:-1]/NN(3)/step(3);
                    kList = {kListx;kListy;kListz};
            end
        end

        function kStep = get.SpaceAngularFrequencyStep(obj)
            % Angular frequency steps per dimension.
            switch obj.Dimension
                case 1
                    kStep = obj.SpaceAngularFrequencyList(2) - obj.SpaceAngularFrequencyList(1);
                case 2
                    kStep = cellfun(@(x) x(2) - x(1),obj.SpaceAngularFrequencyList);
                case 3
                    kStep = cellfun(@(x) x(2) - x(1),obj.SpaceAngularFrequencyList);
            end
        end
        
    end
end

