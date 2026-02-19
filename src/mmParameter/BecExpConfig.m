classdef BecExpConfig < MmParameter
    %:class:`BecExpConfig` stores machine/global configuration for :class:`BecExp`.
    %
    % These entries represent deployment-level configuration such as file paths,
    % database targets, color maps, and control app name, which are mirrored into
    % :class:`BecExpSetting` via a join on :attr:`IsLocalTest`.
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
    %    * - IsLocalTest
    %      - logical
    %      - 0
    %    * - CiceroLogOrigin
    %      - string
    %      - XXX
    %    * - ParentPath
    %      - string
    %      - XXX
    %    * - DataPrefix
    %      - string
    %      - run
    %    * - DataFormat
    %      - string
    %      - .tif
    %    * - IsAutoDelete
    %      - logical
    %      - 0
    %    * - DatabaseName
    %      - string
    %      - experiment
    %    * - DatabaseTableName
    %      - string
    %      - main
    %    * - DataGroupSize
    %      - double
    %      - 3
    %    * - IsAutoAcquire
    %      - logical
    %      - 1
    %    * - OdColormap
    %      - doubleMatrix
    %      - [0,0,0]
    %    * - AtomName
    %      - string
    %      - Lithium7
    %    * - ImagingStageList
    %      - stringMatrix
    %      - [LF,HF,NI]
    %    * - ControlAppName
    %      - string
    %      - BecControl
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
        function obj = BecExpConfig()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "IsLocalTest","logical",...
                "CiceroLogOrigin", "string", ...
                "ParentPath", "string", ...
                "DataPrefix", "string", ...
                "DataFormat", "string", ...
                "IsAutoDelete", "logical", ...
                "DatabaseName", "string", ...
                "DatabaseTableName", "string", ...
                "DataGroupSize", "double", ...
                "IsAutoAcquire", "logical", ...
                "OdColormap", "doubleMatrix", ...
                "AtomName", "string", ...
                "ImagingStageList", "stringMatrix", ...
                "ControlAppName", "string", ...
                "VariableMapping", "stringMatrix"...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "IsLocalTest","0",...
                "CiceroLogOrigin", "'XXX'", ...
                "ParentPath", "'XXX'", ...
                "DataPrefix", "'run'", ...
                "DataFormat", "'.tif'", ...
                "IsAutoDelete", "0", ...
                "DatabaseName", "'experiment'", ...
                "DatabaseTableName", "'main'", ...
                "DataGroupSize", "3", ...
                "IsAutoAcquire", "1", ...
                "OdColormap", "'[0,0,0]'", ...
                "AtomName", "'Lithium7'", ...
                "ImagingStageList", "'LF,HF,NI'", ...
                "ControlAppName", "'BecControl'", ...
                "VariableMapping", "'None'"...
                );
        end
    end
end

