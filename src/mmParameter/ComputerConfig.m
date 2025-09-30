classdef ComputerConfig < MmParameter
    %:class:`ComputerConfig` stores machine-specific paths and labels used by the toolbox.
    %
    % Includes paths for experiment data/logs, repository, config and temp
    % directories, as well as hostnames for control/logging computers. Used by
    % :func:`setParameter` to set up a new environment.
    %
    % **Schema (columns, types, defaults, default entries):**
    %
    % .. list-table::
    %    :widths: 30 18 20 32
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %      - DefaultEntry values
    %    * - BecExpControlComputerName
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - BecExpParentPath
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - BecExpDatabaseName
    %      - string
    %      - experiment
    %      - (no DefaultEntry)
    %    * - BecExpDatabaseTableName
    %      - string
    %      - main
    %      - (no DefaultEntry)
    %    * - CiceroComputerName
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - CiceroLogOrigin
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - HardwareLogOrigin
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - RepoPath
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - ConfigPath
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
    %    * - TempPath
    %      - string
    %      - XXX
    %      - (no DefaultEntry)
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
        function obj = ComputerConfig()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "BecExpControlComputerName", "string", ...
                "BecExpParentPath", "string", ...
                "BecExpDatabaseName", "string", ...
                "BecExpDatabaseTableName", "string", ...
                "CiceroComputerName", "string", ...
                "CiceroLogOrigin", "string", ...
                "HardwareLogOrigin", "string", ...
                "RepoPath", "string", ...
                "ConfigPath", "string", ...
                "TempPath", "string" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
               "BecExpControlComputerName", "'XXX'", ...
                "BecExpParentPath", "'XXX'", ...
                "BecExpDatabaseName", "'experiment'", ...
                "BecExpDatabaseTableName", "'main'", ...
                "CiceroComputerName", "'XXX'", ...
                "CiceroLogOrigin", "'XXX'", ...
                "HardwareLogOrigin", "'XXX'", ...
                "RepoPath", "'XXX'", ...
                "ConfigPath", "'XXX'", ...
                "TempPath", "'XXX'" ...
                );
            obj.IsIncludeDefaultEntry = false;
        end
    end
end

