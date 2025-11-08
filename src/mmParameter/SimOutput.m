classdef SimOutput < MmParameter

    properties

    end

    methods
        function obj = SimOutput()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "SimName", "string", ...
                "VariableName", "string", ...
                "RuntimeName", "string", ...
                "Size", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "SimName", "'SeSim1D'", ...
                "VariableName", "'Time'", ...
                "RuntimeName", "'t'", ...
                "Size", "1" ...
                );

            obj.IsFirstColumnUnique = false;
            obj.UniqueConstraint = ["SimName","VariableName"];
        end
        
    end
end

