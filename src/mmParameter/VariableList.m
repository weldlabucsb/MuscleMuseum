classdef VariableList < MmParameter
    %:class:`VariableList` stores named scalar variables and expressions.
    %
    % Each row defines :attr:`Name`, numeric :attr:`DefaultValue`, a logical
    % grouping :attr:`List`, an :attr:`Equation` string, and the current
    % evaluated :attr:`CurrentValue` (cache). When referenced by other tables
    % (e.g., :class:`HardwareSetting`, :class:`WaveformLibrary`), the effective
    % value is the ``CurrentValue`` if present, otherwise ``DefaultValue``.
    %
    % **Schema (columns, types, defaults):**
    %
    % .. list-table::
    %    :widths: 30 18 28
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %    * - Name
    %      - string
    %      - hw_default
    %    * - DefaultValue
    %      - double
    %      - 0
    %    * - List
    %      - string
    %      - None
    %    * - Equation
    %      - string
    %      - None
    %    * - CurrentValue
    %      - double
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
        function obj = VariableList()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "DefaultValue", "double", ...
                "List", "string", ...
                "Equation", "string", ...
                "CurrentValue", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'hw_default'", ...
                "DefaultValue", "0", ...
                "List", "'None'", ...
                "Equation", "'None'", ...
                "CurrentValue", "0" ...
                );
        end
    end
end

