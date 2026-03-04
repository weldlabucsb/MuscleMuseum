classdef DatabaseServerConfig < MmParameter
    %:class:`DatabaseServerConfig` stores credentials for external database servers.
    %
    % Records :attr:`Name` (host label), :attr:`Port`, :attr:`Username`, and
    % :attr:`Password`. Used by functions that connect to Postgres. Credentials
    % are stored in the local SQLite file and should be handled carefully.
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
    %      - localhost
    %      - localhost
    %    * - Port
    %      - double
    %      - 5432
    %      - 5432
    %    * - Username
    %      - string
    %      - postgres
    %      - postgres
    %    * - Password
    %      - string
    %      - SupermassiveBlackHole
    %      - SupermassiveBlackHole
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
        function obj = DatabaseServerConfig()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "Port", "double", ...
                "Username", "string", ...
                "Password", "string" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'localhost'", ...
                "Port", "5432", ...
                "Username", "'postgres'", ...
                "Password", "'SupermassiveBlackHole'" ...
                );

            % Define default entries for initial table setup in :attr:`DefaultEntry`
            obj.DefaultEntry = table(...
                ["localhost";], ...
                [5432;], ...
                ["postgres";], ...
                ["SupermassiveBlackHole";], ...
                'VariableNames', [...
                "Name", ...
                "Port", ...
                "Username", ...
                "Password", ...
                ] ...
                );
            obj.IsIncludeDefaultEntry = false;
            obj.IsFirstColumnUnique = false;
        end
    end
end

