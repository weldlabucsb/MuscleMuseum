classdef BecExpVariableUnit < MmParameter
    %:class:`BecExpParameterUnit` records units for scan variables in BEC experiments.
    %
    % Maps :attr:`ScannedParameter` to its string unit label
    % (:attr:`ScannedParameterUnit`). Intended for joining into
    % :class:`BecExpConfig`.

    properties

    end

    methods
        function obj = BecExpVariableUnit()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "ScannedVariable", "string", ...
                "ScannedVariableUnit", "string" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "ScannedVariable", "'dummy'", ...
                "ScannedVariableUnit", "'V'" ...
                );
            obj.DefaultEntry = cell2table({ ...
                "RunIndex","";...
                },"VariableNames",["ScannedVariable","ScannedVariableUnit"]);
            obj.IsIncludeDefaultEntry = true;
        end
    end
end

