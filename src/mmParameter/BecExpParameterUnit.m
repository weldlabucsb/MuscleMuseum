classdef BecExpParameterUnit < MmParameter
    %:class:`BecExpParameterUnit` records units for scan variables in BEC experiments.
    %
    % Maps :attr:`ScannedParameter` to its string unit label
    % (:attr:`ScannedParameterUnit`). Intended for joining into
    % :class:`BecExpConfig`.

    properties

    end

    methods
        function obj = BecExpParameterUnit()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "ScannedParameter", "string", ...
                "ScannedParameterUnit", "string" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "ScannedParameter", "'dummy'", ...
                "ScannedParameterUnit", "'V'" ...
                );
            obj.DefaultEntry = cell2table({ ...
                "RunIndex","";...
                },"VariableNames",["ScannedParameter","ScannedParameterUnit"]);
            obj.IsIncludeDefaultEntry = true;
        end
    end
end

