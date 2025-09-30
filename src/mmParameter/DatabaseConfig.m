classdef DatabaseConfig < MmParameter
    %:class:`DatabaseConfig` lists logical databases and their table lists.
    %
    % Used by higher-level code to determine which parameter tables belong to a
    % given logical database (e.g., ``experiment`` or ``simulation``). The
    % :attr:`TableList` is stored as a string matrix and converted back to a
    % MATLAB string array by :meth:`MmParameter.convertOutputTable`.
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
    %    * - Name
    %      - string
    %      - defaultDatabase
    %      - experiment; simulation
    %    * - TableList
    %      - stringMatrix
    %      - defaultTable
    %      - [main]; [main]
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
    %      - false
    %    * - IsFirstColumnUnique
    %      - true
    %    * - IsTriggerJoinOnRight
    %      - false
    %    * - IsTriggerJoinOnLeft
    %      - false

    properties

    end

    methods
        function obj = DatabaseConfig()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "TableList", "stringMatrix" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'defaultDatabase'", ...
                "TableList", "'defaultTable'" ...
                );

            % Define default entries for initial table setup in :attr:`DefaultEntry`
            obj.DefaultEntry = table(...
                ["experiment";"simulation"], ...
                {["main"];["main"]}, ...
                'VariableNames', [...
                "Name", ...
                "TableList", ...
                ] ...
                );
            obj.IsIncludeDefaultEntry = false;
        end
    end
end

