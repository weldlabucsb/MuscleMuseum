classdef MmSetting < handle
    %:class:`MmSetting` manages persistent toolbox settings using a local SQLite database.
    %
    % Provides schema definition, validation, and automatic migration via a metadata table
    % and a schema hash. Supports default entries, typed columns, and conversion between
    % MATLAB types and SQLite storage formats.
    %
    % Key features:
    % - Metadata table for multi-table schema tracking
    % - Schema hashing for change detection
    % - PRAGMA table_info for schema introspection
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    s = YourSettingSubclass();
    %    s.checkTable(); % ensure schema exists and is current

    properties (SetAccess=protected)
        TableColumn dictionary = dictionary("Name","string") %Stores column name and type. Should be defined in subclass's construtor
        DefaultValue dictionary = dictionary("Name","Name") %Stores column name and default value. Should be defined in subclass's construtor. Using Null is not recommended.
        DefaultEntry table %Default entries for initial setup
    end

    properties (Constant)
        DataBaseName = "mmSeting.db" %Database file name. Saved in MMUser
        DataTypeMapping = dictionary(...
            ["double","logical","string","doubleMatrix","logicalMatrix","stringMatrix"],...
            ["REAL","INTEGER","TEXT","TEXT","TEXT","TEXT"]) %Map matlab types to database types
        MetadataTableName = "SchemaMetadata" %Table to store schema information for all tables
    end

    properties (Dependent)
        TableName (1,1) string %Table name is consistent with the subclass name
        SchemaHash (1,1) string %Hash of current schema definition including default entries
    end

    methods
        function obj = MmSetting()
            % Construct an instance of :class:`MmSetting`.
            %
            % Subclasses should define their schema in the constructor by setting
            % :attr:`TableColumn`, :attr:`DefaultValue`, and optionally :attr:`DefaultEntry`.
        end

        function tableName = get.TableName(obj)
            tableName = string(class(obj));
        end

        function schemaHash = get.SchemaHash(obj)
            % Generate a fast hash of the current schema definition
            % This includes table name, column names, types, default values, and default entries
            schemaStr = "";
            
            % Add table name for uniqueness across multiple tables
            schemaStr = schemaStr + "TABLE:" + obj.TableName + ";";
            
            % Add column definitions (optimized string concatenation)
            columnNames = obj.TableColumn.keys;
            columnTypes = obj.TableColumn.values;
            schemaStr = schemaStr + join(columnNames + ":" + columnTypes, ";") + ";";
            
            % Add default values
            defaultNames = obj.DefaultValue.keys;
            defaultValues = obj.DefaultValue.values;
            schemaStr = schemaStr + "DEFAULTS:" + join(defaultNames + "=" + string(defaultValues), ";") + ";";
            
            % Add default entries hash (if any)
            if ~isempty(obj.DefaultEntry) && height(obj.DefaultEntry) > 0
                % Convert table to string representation for hashing
                entryStr = "";
                for i = 1:height(obj.DefaultEntry)
                    row = obj.DefaultEntry(i, :);
                    rowStr = join(string(table2cell(row)), ",");
                    entryStr = entryStr + rowStr + ";";
                end
                schemaStr = schemaStr + "ENTRIES:" + entryStr;
            end
            
            % Generate hash for change detection
            schemaHash = dataHash(schemaStr);
        end

        function checkDataBase(obj)
            % Ensure the SQLite database file and metadata table exist.
            %
            % Creates the database file in ``MMUser/config`` if missing and initializes
            % the ``SchemaMetadata`` table for schema tracking.
            dbName = fullfile(getHome,"Documents","MMUser","config",obj.DataBaseName);
            if ~isfile(dbName)
                conn = sqlite(dbName,"create");
                % Create the Metadata table
                sqlquery = "CREATE TABLE IF NOT EXISTS " + obj.MetadataTableName + ...
                    "(TableName TEXT PRIMARY KEY, SchemaHash TEXT, LastUpdated TEXT);";
                execute(conn, sqlquery);
                close(conn)
            end
        end

        function checkTable(obj)
            % Ensure this setting's table exists and matches the current schema.
            %
            % If the table does not exist, it is created. If the schema hash differs
            % from the stored one, an automatic schema migration is performed.
            obj.checkDataBase
            
            % Check if our table exists
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlquery = "SELECT name FROM sqlite_master" + ...
                " WHERE type='table' AND name='" + obj.TableName + "';";
            fetchResult = fetch(conn,sqlquery);
            close(conn);
            
            if isempty(fetchResult)
                % Table doesn't exist, create it
                obj.createTable;
            else
                % Table exists, check if schema is current
                if ~obj.isSchemaCurrent
                    % Schema is outdated, update it
                    obj.updateTableSchema;
                end
            end
        end

        function updateSchemaMetadata(obj)
            % Update or insert the current schema hash into the metadata table.
            %
            % Records ``TableName``, ``SchemaHash``, and ``LastUpdated`` for change tracking.
            % Insert or update schema metadata for this table
            % Uses INSERT OR REPLACE to handle both new entries and updates
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlquery = "INSERT OR REPLACE INTO " + obj.MetadataTableName + ...
                " (TableName, SchemaHash, LastUpdated) VALUES " + ...
                "('" + obj.TableName + "', '" + obj.SchemaHash + "', '" + string(datetime) + "');";
            execute(conn, sqlquery);
            close(conn);
        end

        function createTable(obj)
            % Create the SQLite table according to the current schema definition.
            %
            % Uses :attr:`TableColumn` and :attr:`DataTypeMapping` to generate the CREATE TABLE
            % statement, writes default entries if provided, and updates schema metadata.
            % Create the table with current schema
            conn = sqlite(which(obj.DataBaseName),"connect");
            columnName = obj.TableColumn.keys;
            columnTypeMapped = obj.DataTypeMapping(obj.TableColumn.values);
            sqlquery = [(columnName+" "),(columnTypeMapped+", ")].';
            sqlquery = sqlquery(:);
            sqlquery(end) = strrep(sqlquery(end),", ","");
            sqlquery = "CREATE TABLE " + obj.TableName +...
                "(" + join(sqlquery) + ");";
            execute(conn,sqlquery)
            close(conn);
            obj.insertDefaultEntry;
            obj.updateSchemaMetadata;
        end

        function isCurrent = isSchemaCurrent(obj)
            % Check whether the stored schema hash matches the current schema.
            %
            % :return: True if the schema hash in the metadata table equals :attr:`SchemaHash`.
            % :rtype: logical

            % Check if the current schema matches the stored schema
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlquery = "SELECT SchemaHash FROM " + obj.MetadataTableName + ...
                " WHERE TableName = '" + obj.TableName + "';";
            result = fetch(conn, sqlquery);
            
            if isempty(result) || isempty(result.SchemaHash) || ismissing(result.SchemaHash)
                isCurrent = false;
                close(conn);
                return;
            end
            
            % Check hash
            isCurrent = obj.SchemaHash == string(result.SchemaHash);
            close(conn);
        end

        function insertDefaultEntry(obj)
            % Insert default entries into the table if present.
            %
            % Uses :attr:`DefaultEntry` and the first key in :attr:`TableColumn` to write
            % initial rows. No action if :attr:`DefaultEntry` is empty.
            % Insert default entries if provided and not empty
            if ~isempty(obj.DefaultEntry) && height(obj.DefaultEntry) > 0
                % Write default entries directly using the existing connection
                columnName = obj.TableColumn.keys;
                obj.updateEntry(obj.DefaultEntry,columnName(1))
            end
        end

        function updateTableSchema(obj)
            % Migrate the SQLite table to match the current schema.
            %
            % Adds missing columns with default values when provided, and recreates the table
            % if extra columns or type mismatches are detected. Updates metadata afterward.
            % Update table schema to match current definition
            conn = sqlite(which(obj.DataBaseName),"connect");
            
            % Get current table info
            sqlquery = 'SELECT name, type FROM pragma_table_info(''' + obj.TableName +  ''')';
            currentColumns = fetch(conn, sqlquery);
            
            % Get target column names and types
            targetColumnNames = obj.TableColumn.keys;
            targetColumnTypes = obj.DataTypeMapping(obj.TableColumn.values);
            
            % Find missing columns
            missingColumns = setdiff(targetColumnNames, currentColumns.name);
            
            % Add missing columns
            for i = 1:length(missingColumns)
                colName = missingColumns(i);
                colType = targetColumnTypes(strcmp(targetColumnNames, colName));
                defaultValue = obj.DefaultValue(colName);
                
                sqlquery = "ALTER TABLE " + obj.TableName + ...
                    " ADD " + colName + " " + colType + ";";
                execute(conn, sqlquery);
                
                % Set default value for existing rows
                if ~isempty(defaultValue)
                    sqlquery = "UPDATE " + obj.TableName + " SET " + colName + " = '" + string(defaultValue) + "';";
                    execute(conn, sqlquery);
                end
            end
            
            % Check for type mismatches or extra columns
            extraColumns = setdiff(currentColumns.name, targetColumnNames);
            if ~isempty(extraColumns)
                % Recreate table to remove extra columns
                close(conn);
                obj.recreateTable();
            else
                close(conn);
            end
            obj.insertDefaultEntry;
            obj.updateSchemaMetadata;
        end

        function recreateTable(obj)
            % Recreate the table from scratch to remove extra columns or change types.
            %
            % Backs up the current table, creates a new table with the target schema,
            % copies compatible columns, and then drops the backup.
            % Recreate table with current schema (for removing columns or changing types)
            fprintf('Recreating table %s with new schema\n', obj.TableName);
            
            conn = sqlite(which(obj.DataBaseName),"connect");
            
            % Backup existing data
            tempTableName = obj.TableName + "_backup";
            sqlquery = "ALTER TABLE " + obj.TableName + " RENAME TO " + tempTableName + ";";
            execute(conn, sqlquery);
            
            % Create new table
            obj.createTable();
            
            % Copy compatible data
            commonColumns = obj.getCommonColumns(tempTableName);
            if ~isempty(commonColumns)
                columnStr = join(commonColumns, ", ");
                sqlquery = "INSERT INTO " + obj.TableName + " (" + columnStr + ") " + ...
                    "SELECT " + columnStr + " FROM " + tempTableName + ";";
                execute(conn, sqlquery);
            end
            
            % Drop backup table
            sqlquery = "DROP TABLE " + tempTableName + ";";
            execute(conn, sqlquery);
            
            close(conn);
        end

        function commonColumns = getCommonColumns(obj, otherTableName)
            % Get a list of columns common to this table and another table.
            %
            % :param otherTableName: The name of the other table to compare against.
            % :type otherTableName: string
            % :return: Column names that exist in both tables.
            % :rtype: string array
            % Get columns that exist in both tables
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlquery1 = 'SELECT name FROM pragma_table_info(''' + obj.TableName +  ''')';
            sqlquery2 = 'SELECT name FROM pragma_table_info(''' + otherTableName +  ''')';
            
            table1Columns = fetch(conn, sqlquery1);
            table2Columns = fetch(conn, sqlquery2);
            
            commonColumns = intersect(table1Columns.name, table2Columns.name);
            close(conn);
        end

        function writeEntry(obj,t)
            % Append entries to the table.
            %
            % :param t: Rows to write. Struct inputs are converted to table.
            % :type t: table or struct
            if isempty(t)
                return
            end
            t = obj.prepareInput(t);
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlwrite(conn,obj.TableName,t)
            close(conn)
        end

        function updateEntry(obj,t,keyColumnName)
            % Upsert rows based on a key column.
            %
            % For each row in ``t``, update the existing row matching ``keyColumnName``;
            % if not present, insert it.
            %
            % :param t: Input rows to write.
            % :type t: table or struct
            % :param keyColumnName: Column used as the upsert key.
            % :type keyColumnName: string
            arguments
                obj
                t %Input entry table
                keyColumnName (1,1) string %Key column name.
            end
            if ~ismember(keyColumnName,obj.TableColumn.keys)
                return
            end
            conn = sqlite(which(obj.DataBaseName),"connect");

            % rewrite entries if they match the key
            t = prepareInput(obj,t);
            columnValue = t.(keyColumnName);
            rf = rowfilter(keyColumnName);
            rfList = arrayfun(@(x) rf.(keyColumnName) == x,columnValue,UniformOutput=false);
            sqlupdate(conn,obj.TableName,t,rfList)

            % write extra entries if they don't exist
            sqlquery = "SELECT " + keyColumnName + " FROM " + obj.TableName;
            columnValueDb = fetch(conn,sqlquery);
            columnValueDb = columnValueDb.(keyColumnName);
            extraEntry = setdiff(columnValue,columnValueDb);
            close(conn)
            if ~isempty(extraEntry)
                t = t(t.(keyColumnName) == extraEntry,:);
                obj.writeEntry(t);
            end
        end

        function t = prepareInput(obj,t)
            % Validate and normalize input rows against the schema.
            %
            % Ensures column names and MATLAB types match :attr:`TableColumn`. Handles
            % matrix types via cell arrays and converts them to string representations for storage.
            %
            % :param t: Input rows. Struct inputs are converted to table.
            % :type t: table or struct
            % :return: Normalized table ready for SQL write operations.
            % :rtype: table

            %% Check input type, convert to table
            if ~isa(t,"table")
                if isa(t,"struct")
                    t = struct2table(t);
                else
                    error("Database input has to table or struct.")
                end
            end

            %% Check column names
            columnName = obj.TableColumn.keys.';
            columnType = obj.TableColumn.values.';
            tColumnName = string(t.Properties.VariableNames);
            if (numel(tColumnName) ~= numel(columnName)) || ~isempty(setdiff(tColumnName,columnName))
                error("Input table variable names do not match the database table.")
            end

            %% Check column types
            tColumnType = string(arrayfun(@(x) class(t.(x)),columnName,'UniformOutput',false));
            matIdx = contains(columnType,"Matrix");
            if ~any(matIdx)
                if any(tColumnType ~= columnType)
                    error("Input table variable types do not match the database table.")
                end
            else
                % Matrix type has to use cell
                if any(tColumnType(matIdx) ~= "cell")
                    error("Input table variable types do not match the database table." + ...
                        " The matrix elements have to be cell type.")
                end

                % Elements in matrix type columns have to match the type
                matColumnName = columnName(matIdx);
                matColumnType = strrep(columnType(matIdx),"Matrix","");
                if any( ...
                        arrayfun( ...
                        @(x) string(class(t.(matColumnName(x)){1})) ~= matColumnType(x), ...
                        1:numel(matColumnName) ...
                        ) ...
                        )
                    error("Input table variable types do not match the database table.")
                end

                % Check the other colums' types
                if any(tColumnType(~matIdx) ~= columnType(~matIdx))
                    error("Input table variable types do not match the database table.")
                end

                % Convert matrix data into string data
                for ii = find(matIdx)
                    switch columnType(ii)
                        case "stringMatrix"
                            t.(columnName(ii)) = cellfun(@(x) strmat2str(x),t.(columnName(ii)));
                        otherwise
                            t.(columnName(ii)) = cellfun(@(x) string(mat2str(x)),t.(columnName(ii)));
                    end
                end
            end
        end

        function t = readTable(obj)
            % Read the entire table and convert columns to MATLAB types.
            %
            % :return: All rows in this setting's table.
            % :rtype: table
            conn = sqlite(which(obj.DataBaseName),"readonly");
            t = sqlread(conn,obj.TableName);
            t = obj.convertOutput(t);
            close(conn)
        end

        function t = readEntry(obj,keyColumnName,keyColumnValue)
            % Read entries filtered by a key column and specific values.
            %
            % :param keyColumnName: Column to filter on.
            % :type keyColumnName: string
            % :param keyColumnValue: Values to match in the key column.
            % :type keyColumnValue: vector
            % :return: Matching rows with MATLAB-typed columns.
            % :rtype: table
            arguments
                obj
                keyColumnName (1,1) string %Key column name
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column values
            end
            if ~ismember(keyColumnName,obj.TableColumn.keys)
                t = table.empty;
                return
            end
            conn = sqlite(which(obj.DataBaseName),"readonly");
            if obj.TableColumn(keyColumnName) == "string"
                whereStr = obj.TableName + "." + keyColumnName + "=\"\""  + keyColumnValue + ...
                    "\"\"";
            else
                whereStr = obj.TableName + "." + keyColumnName + "="  + keyColumnValue;
            end
            
            sqlquery = "SELECT * FROM " + obj.TableName + " WHERE " + join(whereStr, " OR ") + ";";
            t = fetch(conn,sqlquery);
            t = obj.convertOutput(t);
            close(conn)
        end

        function t = convertOutput(obj,t)
            % Convert SQLite-stored values back to MATLAB types.
            %
            % Converts matrix-encoded strings and logical columns to their corresponding
            % MATLAB representations based on :attr:`TableColumn`.
            %
            % :param t: Table read from the database.
            % :type t: table
            % :return: Table with converted MATLAB types.
            % :rtype: table
            columnName = obj.TableColumn.keys.';
            columnType = obj.TableColumn.values.';

            % Convert matrix data
            matIdx = contains(columnType,"Matrix");
            if any(matIdx)
                for ii = find(matIdx)
                    switch columnType(ii)
                        case "stringMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) str2strmat(x),t.(columnName(ii)),"UniformOutput",false);
                        case "doubleMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) eval(x),t.(columnName(ii)),"UniformOutput",false);
                        case "logicalMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) logical(eval(x)),t.(columnName(ii)),"UniformOutput",false);
                    end
                end
            end

            % Convert logical data
            logIdx = columnType =="logical";
            if any(logIdx)
                for ii = find(logIdx)
                    t.(columnName(ii)) = arrayfun(@(x) logical(x),t.(columnName(ii)));
                end
            end
        end

    end
end

