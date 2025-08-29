classdef (Abstract) SimRun < handle
    %:class:`SimRun` abstract base for a single simulation run.
    
    properties
        DataPath string
        DataAnalysisPath string
        DataPrefix string = "run"
        DataFormat string = ".mat"
        Output table
        RunIndex uint32 = int32(1)
        IsCompleted logical = false
        WallTime double = 11.5*3600
    end

    properties (Dependent)
        RunPath string
    end
    
    methods
        function obj = SimRun(sim)
            % Construct a :class:`SimRun` using metadata from a :class:`Sim`.
            %
            % :param sim: Parent simulation
            % :type sim: :class:`Sim`, optional
            arguments
                sim = [] 
            end
            if ~isempty(sim)
                if isa(sim,"Sim")
                    obj.DataPath = sim.DataPath;
                    obj.DataAnalysisPath = sim.DataAnalysisPath;
                    obj.DataPrefix = sim.DataPrefix;
                    obj.DataPrefix = sim.DataPrefix;
                    obj.Output = sim.Output;
                    obj.WallTime = sim.WallTime;
                else
                    error("Input must be an object of the Sim class")
                end
            end
        end
        
        function fPath = get.RunPath(obj)
            % Get output path for this run file.
            %
            % :return: Full path to run file
            % :rtype: string
            if ~isempty(obj.DataPath) && ~isempty(obj.DataPrefix)
                fPath = fullfile(obj.DataPath,obj.DataPrefix+num2str(obj.RunIndex)+obj.DataFormat);
            else
                error("Can not find DataPath or DataPrefix. Specify DataPath or DataPrefix for SimRun.")
            end
        end
        
        function data = readRun(obj,varName)
            % Read a variable from this run file.
            %
            % :param varName: Variable name
            % :type varName: string | char
            % :return: Variable value loaded from MAT file
            % :rtype: any
            data = loadVar(obj.RunPath,varName);
        end
    end
end

