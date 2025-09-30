classdef ListList < MmParameter
    %:class:`ListList` stores named numeric lists for parameter sweeps or setups.
    %
    % Each row defines a list identifier and its :attr:`ListValue` (encoded
    % numeric array), plus optional convenience fields :attr:`Start`,
    % :attr:`Stop`, :attr:`Step` useful for generation scripts.
    %
    % **Schema (columns, types, defaults, default entries):**
    %
    % .. list-table::
    %    :widths: 22 18 22 38
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %      - DefaultEntry values
    %    * - List
    %      - string
    %      - None
    %      - None
    %    * - ListValue
    %      - doubleMatrix
    %      - []
    %      - []
    %    * - Start
    %      - double
    %      - 0
    %      - 0
    %    * - Stop
    %      - double
    %      - 0
    %      - 0
    %    * - Step
    %      - double
    %      - 0
    %      - 0
    %
    % **Foreign keys:**
    %
    % (none)
    %
    % **Join conditions:**
    %
    % (none)
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
        function obj = ListList()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "List", "string", ...
                "ListValue", "doubleMatrix", ...
                "Start", "double", ...
                "Stop", "double", ...
                "Step", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "List", "'None'", ...
                "ListValue", "'[]'", ...
                "Start", "0", ...
                "Stop", "0", ...
                "Step", "0" ...
                );

            % Define default entries for initial table setup in :attr:`DefaultEntry`
            obj.DefaultEntry = table(...
                ["None";], ...
                {[];}, ...
                [0;], ...
                [0;], ...
                [0;], ...
                'VariableNames', [...
                "List", ...
                "ListValue" ...
                "Start", ...
                "Stop", ...
                "Step", ...
                ] ...
                );

            obj.IsIncludeDefaultEntry = true;
        end
    end
end

