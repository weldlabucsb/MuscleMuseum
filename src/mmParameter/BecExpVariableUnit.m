classdef BecExpVariableUnit < MmParameter
    %:class:`BecExpVariableUnit` records units for scan variables in BEC experiments.
    %
    % Maps :attr:`ScannedVariable` to its string unit label
    % (:attr:`ScannedVariableUnit`). Intended for joining into
    % :class:`BecExpSetting` and CSV post-processing.
    %
    % **Schema (columns, types, defaults, default entries):**
    %
    % .. list-table::
    %    :widths: 28 18 22 32
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %      - DefaultEntry values
    %    * - ScannedVariable
    %      - string
    %      - dummy
    %      - RunIndex
    %    * - ScannedVariableUnit
    %      - string
    %      - V
    %      - (empty)
    %
    % **Foreign keys:**
    %
    % (none)
    %
    % **Join conditions:**
    %
    % (used by :class:`BecExpSetting`, not defined here)
    %
    % **Flags:**
    %
    % .. list-table::
    %    :widths: 38 14
    %    :header-rows: 1
    %
    %    * - Property
    %      - Value
    %    * - IsIncludeDefaultEntry
    %      - true
    %    * - IsFirstColumnUnique
    %      - true
    %    * - IsTriggerJoinOnRight
    %      - false
    %    * - IsTriggerJoinOnLeft
    %      - false

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

