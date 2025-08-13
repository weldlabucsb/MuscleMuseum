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
        TableColumn dictionary =  dictionary("Name","string") %Stores column name and type. Should be defined in subclass's construtor
        DefaultValue dictionary =  dictionary("Name","Name") %Stores column name and default value. Should be defined in subclass's construtor. Using Null is not recommended.
        DefaultEntry table %Default entries for initial setup
        TableName (1,1) string %Table name is consistent with the subclass name
        DefaultKey (1,1) string %The default key string will be the name of the first column after SerialNumber
        ColumnNameAll string %Including the SerialNumber column
        ColumnTypeAll string %Including the SerialNumber column's type
        JoinCondition dictionary = dictionary([],[]) %{[Table,KeyColumn]} ->{[DataColumn1,DataColumn2,...]}
    end

    % Removed IsIndexed: all tables now have a built-in INTEGER PRIMARY KEY 'SerialNumber'

    properties (Constant)
        DataBaseName = "mmSeting.db" %Database file name. Saved in MMUser
        DataTypeMapping = dictionary(...
            ["int64","double","logical","string","doubleMatrix","logicalMatrix","stringMatrix"],...
            ["INT","REAL","INTEGER","TEXT","TEXT","TEXT","TEXT"]) %Map matlab types to database types
        MetadataTableName = "SchemaMetadata" %Table to store schema information for all tables
    end

    properties (Dependent)
        SchemaHash (1,1) string %Hash of current schema definition including default entries
        IsSchemaCurrent (1,1) logical %Check whether the stored schema hash matches the current schema. 
    end

    methods
        function obj = MmSetting()
            % Construct an instance of :class:`MmSetting`.
            %
            % Subclasses should define their schema in the constructor by setting
            % :attr:`TableColumn`, :attr:`DefaultValue`, and optionally :attr:`DefaultEntry`.
            obj.defineSchema
            obj.setProperty
        end
        
        function setProperty(obj)
            obj.TableName = string(class(obj));
            columnName = obj.TableColumn.keys;
            obj.DefaultKey = columnName(1);
            obj.ColumnNameAll = ["SerialNumber",columnName.'];
            obj.ColumnTypeAll = ["int64",obj.TableColumn.values.'];
        end

        function schemaHash = get.SchemaHash(obj)
            % Compute a hash string representing the current schema definition.
            %
            % The hash covers :attr:`TableName`, column names/types, default values, and
            % serialized :attr:`DefaultEntry` rows (if any).
            %
            % :return: Schema hash string
            % :rtype: string
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
            if ~isempty(obj.DefaultEntry)
                % Convert table to string representation for hashing
                entryStr = "";
                t = obj.prepareInputTable(obj.DefaultEntry);
                for ii = 1:size(t,1)
                    row = t(ii, :);
                    rowStr = join(string(table2cell(row)), ",");
                    entryStr = entryStr + rowStr + ";";
                end
                schemaStr = schemaStr + "ENTRIES:" + entryStr;
            end
            
            % Generate hash for change detection
            schemaHash = dataHash(schemaStr);
        end

        function isCurrent = get.IsSchemaCurrent(obj)
            % Check whether the stored schema hash matches the current schema.
            %
            % :return: True if the schema hash in the metadata table equals :attr:`SchemaHash`.
            % :rtype: logical

            % Check if the current schema matches the stored schema
            obj.checkDataBase
            conn = obj.connectDatabaseRead;
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
        
        function conn = connectDatabase(obj)
            % Open a read-write connection to the SQLite database file.
            %
            % :return: SQLite connection handle
            % :rtype: sqlite
            conn = sqlite(which(obj.DataBaseName),"connect");
        end

        function conn = connectDatabaseRead(obj)
            % Open a read-only connection to the SQLite database file.
            %
            % :return: SQLite read-only connection handle
            % :rtype: sqlite
            conn = sqlite(which(obj.DataBaseName),"readonly");
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
            obj.checkConstructor
            
            % Check if our table exists
            conn = obj.connectDatabaseRead;
            sqlquery = "SELECT name FROM sqlite_master" + ...
                " WHERE type='table' AND name='" + obj.TableName + "';";
            fetchResult = fetch(conn,sqlquery);
            close(conn);
            
            if isempty(fetchResult)
                % Table doesn't exist, create it
                obj.createTable;
            else
                % Table exists, check if schema is current
                if ~obj.IsSchemaCurrent
                    % Schema is outdated, update it
                    obj.updateTableSchema;
                else
                    % Update default entries anyway in case they were
                    % modified accidentaly,
                    obj.insertDefaultEntry;
                end
            end
        end

        function checkConstructor(obj)
            % Validate constructor-provided schema and defaults.
            %
            % Ensures :attr:`TableColumn` types follow :attr:`DataTypeMapping`,
            % :attr:`DefaultEntry` rows can be serialized by :meth:`prepareInputTable`,
            % and that :attr:`DefaultValue` includes all columns.
            
            if isempty(obj.TableColumn)
                error("TableColumn can not be empty.")
            elseif(any(~ismember(obj.TableColumn.values,obj.DataTypeMapping.keys)))
                error("Data types (the key values) are not set correctly in TableColumn")
            end
            
            if ~isempty(obj.DefaultEntry)
                try 
                    obj.prepareInputTable(obj.DefaultEntry);
                catch
                    error("Default entries are not set correctly.")
                end
            end

            if isempty(obj.DefaultValue)
                error("Default values must be set.")
            else
                columnName = obj.TableColumn.keys;
                defaulValueColumnName = obj.DefaultValue.keys;
                if ~isempty(setdiff(columnName,defaulValueColumnName))
                    error("Default values must be set for all columnes.")
                end
            end

        end

        function updateSchemaMetadata(obj)
            % Update or insert the current schema hash into the metadata table.
            %
            % Records ``TableName``, ``SchemaHash``, and ``LastUpdated`` for change tracking.
            % Insert or update schema metadata for this table
            % Uses INSERT OR REPLACE to handle both new entries and updates
            conn = obj.connectDatabase;
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
            conn = obj.connectDatabase;
            columnName = obj.TableColumn.keys;
            columnType = obj.DataTypeMapping(obj.TableColumn.values);
            columnDefault = obj.DefaultValue(columnName);
            % Build DDL with SerialNumber first as INTEGER PRIMARY KEY
            colDefs = "SerialNumber INTEGER PRIMARY KEY, " + ...
                      columnName(1) + " " + columnType(1) + " NOT NULL UNIQUE, " + ...
                      join(columnName(2:end) + " " + columnType(2:end) + ...
                      " DEFAULT " + columnDefault(2:end), ", ");
            sqlquery = "CREATE TABLE " + obj.TableName + "(" + colDefs + ");";
            execute(conn,sqlquery)

            close(conn);
            obj.insertDefaultEntry;
            obj.updateSchemaMetadata;
        end

        function createJoin(obj)
            jcName = obj.JoinCondition.keys;
            if isempty(jcName)
                return
            end

            % Get current table info
            conn = obj.connectDatabase;
            sqlquery = 'SELECT name, type FROM pragma_table_info(''' + obj.TableName +  ''')';
            dbColumn = fetch(conn, sqlquery);

            % Create columns in the current table for join
            for ii = 1:numel(jcName)
                jTableName = jcName{ii}(1);
                jKeyName = jcName{ii}(2);
                sqlquery = 'SELECT name, type FROM pragma_table_info(''' + jTableName +  ''')';
                jtdbColumn = fetch(conn, sqlquery);
                if ~isempty(jtdbColumn) && ismember(jKeyName,jtdbColumn.name)
                    jDataColumn = obj.JoinCondition(jcName(ii));
                    [jDataColumn,idx] = intersect(jtdbColumn.name,jDataColumn{1});
                    jDataType = jtdbColumn.type(idx);
                    makeJoin(jTableName,jKeyName,jDataColumn,jDataType)
                end
            end

            function makeJoin(jt,jk,jdc,jdt)
                % Create column if missing
                sql = "ALTER TABLE " + obj.TableName + ...
                    " ADD " + jdc + " " + jdt + ";";
                for ll = 1:numel(sql)
                    if ~ismember(jdc(ll),dbColumn.name)
                        execute(conn,sql(ll))
                    end
                end

                % Join once
                sql = "UPDATE " + obj.TableName + newline + ...
                    "SET " + newline + ...
                    join("  " + jdc + " = (SELECT " + jt + "." + jdc + " FROM " +jt +...
                    " WHERE " + jt + "." + jk + " = " + obj.TableName + "." + jk + ")",","+newline)+ ";";
                execute(conn,sql)

                % Check if update trigger already exists
                triggerNameUpdate = "update_" + obj.TableName + "_on_" + jt + "_" + jk + "_update";
                sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                triggerDb = fetch(conn,sql);
                if isempty(triggerDb)
                    % Create trigger
                    sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                        "AFTER UPDATE OF " + jk + " ON " + jt + newline + ...
                        "FOR EACH ROW" + newline + ...
                        "BEGIN" + newline + ...
                        "   UPDATE " + obj.TableName + newline + ...
                        "   SET " + newline + ...
                        join("      " + jdc + " = NEW." + jdc,","+newline) + newline + ...
                        "WHERE " + obj.TableName + "." + jk + " = OLD." + jk + ";" + newline + ...
                        "END;";
                    execute(conn,sql)
                end

                % Check if insert trigger already exists
                triggerNameUpdate = "update_" + obj.TableName + "_on_" + jt + "_" + jk + "_insert";
                sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                triggerDb = fetch(conn,sql);
                if isempty(triggerDb)
                    % Create trigger
                    sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                        "AFTER INSERT ON " + jt + newline + ...
                        "FOR EACH ROW" + newline + ...
                        "BEGIN" + newline + ...
                        "   UPDATE " + obj.TableName + newline + ...
                        "   SET " + newline + ...
                        join("      " + jdc + " = NEW." + jdc,","+newline) + newline + ...
                        "WHERE " + obj.TableName + "." + jk + " = NEW." + jk + ";" + newline + newline + ...
                        "   INSERT OR IGNORE INTO " + obj.TableName + " (" + join([jk;jdc],", ") + ")" + newline + ...
                        "   VALUES (" + join("NEW."+[jk;jdc],", ") + ");" + newline + ...
                        "END;";
                    execute(conn,sql)
                end

            end
        end

        function insertDefaultEntry(obj)
            % Insert default entries into the table if present.
            %
            % Uses :attr:`DefaultEntry` and the first key in :attr:`TableColumn` to write
            % initial rows. No action if :attr:`DefaultEntry` is empty.
            % Insert default entries if provided and not empty
            if ~isempty(obj.DefaultEntry)
                % Use the first schema column (e.g., Name) as the upsert key
                obj.updateEntry(obj.DefaultEntry, obj.DefaultKey)
            end
        end

        function updateTableSchema(obj)
            % Migrate the SQLite table to match the current schema.
            %
            % Adds missing columns with default values when provided, and recreates the table
            % if extra columns or type mismatches are detected. Updates metadata afterward.
            % Update table schema to match current definition
            conn = obj.connectDatabase;
            
            % Get current table info
            sqlquery = 'SELECT name, type FROM pragma_table_info(''' + obj.TableName +  ''')';
            dbColumns = fetch(conn, sqlquery);
            
            % Get target column names and types
            targetColumnNames = obj.TableColumn.keys;
            
            % Ensure SerialNumber exists; if not, recreate table
            if ~ismember("SerialNumber", dbColumns.name)
                close(conn);
                obj.recreateTable();
                obj.insertDefaultEntry;
                obj.updateSchemaMetadata;
                return
            end

            % Find missing columns (excluding SerialNumber, which is managed by core)
            missingColumns = setdiff(targetColumnNames, dbColumns.name);
            
            % Add missing columns
            for ii = 1:length(missingColumns)
                colName = missingColumns(ii);
                colType = obj.DataTypeMapping(obj.TableColumn(colName));
                colDefault = obj.DefaultValue(colName);
                
                sqlquery = "ALTER TABLE " + obj.TableName + ...
                    " ADD " + colName + " " + colType + " DEFAULT " + colDefault + ";";
                execute(conn, sqlquery);
            end
            close(conn);
            
            % Check for type mismatches or extra columns
            extraColumns = setdiff(dbColumns.name, ["SerialNumber"; targetColumnNames]);
            [existingColumn,dbIdx] = intersect(dbColumns.name,targetColumnNames);
            if ~isempty(existingColumn)
                    existingColumnTypeTarget = obj.DataTypeMapping(obj.TableColumn(existingColumn));
                    existingDbColumnType = dbColumns.type(dbIdx);
                    mismatchedColumnIdx = existingDbColumnType ~= existingColumnTypeTarget;
            else
                    mismatchedColumnIdx = false;
            end
            if ~isempty(extraColumns) || any(mismatchedColumnIdx)
                % Recreate table to remove extra columns
                obj.recreateTable();
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
            
            % Delete default entries
            if ~isempty(obj.DefaultEntry)
                obj.deleteEntry(obj.DefaultEntry.(obj.DefaultKey),obj.DefaultKey)
            end
            
            % Backup existing data
            conn = obj.connectDatabase;
            tempTableName = obj.TableName + "_backup";
            sqlquery = "ALTER TABLE " + obj.TableName + " RENAME TO " + tempTableName + ";";
            execute(conn, sqlquery);
            close(conn)
            
            % Create new table
            obj.createTable();
            
            % Copy compatible data
            conn = obj.connectDatabase;
            sqlquery1 = 'SELECT name FROM pragma_table_info(''' + obj.TableName +  ''')';
            sqlquery2 = 'SELECT name FROM pragma_table_info(''' + tempTableName +  ''')';
            table1Columns = fetch(conn, sqlquery1);
            table2Columns = fetch(conn, sqlquery2);
            newCols = string(table1Columns.name);
            oldCols = string(table2Columns.name);
            % Determine columns to copy; include SerialNumber only if present in old table
            copyCols = intersect(newCols, oldCols, 'stable');
            if ~isempty(copyCols)
                columnStr = join(copyCols, ", ");
                sqlquery = "INSERT INTO " + obj.TableName + " (" + columnStr + ") " + ...
                    "SELECT " + columnStr + " FROM " + tempTableName + ";";
                execute(conn, sqlquery);
            end
            
            % Drop backup table
            sqlquery = "DROP TABLE " + tempTableName + ";";
            execute(conn, sqlquery);
            
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
            t = obj.prepareInputTable(t, false);
            conn = obj.connectDatabase;
            sqlwrite(conn,obj.TableName,t)
            close(conn)
        end

        function updateTable(obj,t)
            % Overwrite the entire database table with validated content.
            %
            % Drops and recreates the table according to the current schema, then
            % upserts rows from ``t`` using :attr:`DefaultKey`, and finally inserts
            % the configured default entries.
            %
            % :param t: New table content that matches :attr:`TableColumn` names and types
            % :type t: table
            %
            % **Raises:**
            %
            %     :class:`error`
            %         If input table names or types do not match the schema.
            %Overwrite the entire database table
            arguments
                obj
                t table % Input table
            end
            if isempty(t)
                return
            end

            % Check if the input table is formated correctly (require all columns)
            obj.prepareInputTable(t, true);

            % Delete the existing entries
            conn = obj.connectDatabase;
            sqlquery = "DELETE FROM " + obj.TableName + ";";
            execute(conn, sqlquery);
            close(conn)

            % Insert default entry
            obj.insertDefaultEntry

            % Insert t into the database table
            obj.updateEntry(t,obj.DefaultKey)

        end
        
        function updateEntry(obj, t, keyColumnName)
            % Upsert rows by delete-then-insert using sqlwrite for robust typing.
            %
            % :param t: Input rows to write (all schema columns, any order)
            % :type t: table or struct
            % :param keyColumnName: Conflict key when ``SerialNumber`` is absent; default "SerialNumber"
            % :type keyColumnName: string, optional
            arguments
                obj
                t
                keyColumnName (1,1) string = "SerialNumber"
            end
            if isempty(t) 
                return
            elseif ~ismember(keyColumnName,obj.ColumnNameAll)
                error("The keyColumnName does not match any database table column name.")
            elseif ~ismember(keyColumnName,t.Properties.VariableNames)
                error("The keyColumnName does not match any input table column name.")
            end

            % rewrite entries if they match the key
            conn = obj.connectDatabase;
            tOrigin = t;
            t = prepareInputTable(obj,t);
            columnValue = t.(keyColumnName);
            rf = rowfilter(keyColumnName);
            rfList = arrayfun(@(x) rf.(keyColumnName) == x,columnValue,UniformOutput=false);
            sqlupdate(conn,obj.TableName,t,rfList)

            % write extra entries if they don't exist
            sqlquery = "SELECT " + keyColumnName + " FROM " + obj.TableName;
            columnValueDb = fetch(conn,sqlquery);
            columnValueDb = columnValueDb.(keyColumnName);
            if ~isempty(columnValueDb)
                extraEntry = setdiff(columnValue,columnValueDb);
            else
                extraEntry = columnValue;
            end
            close(conn)
            if ~isempty(extraEntry)
                t = tOrigin(ismember(tOrigin.(keyColumnName), extraEntry),:);
                obj.writeEntry(t);
            end
        end

        function updateValue(obj,keyColumnValue,updateColumnName,value,keyColumnName)
            % Update values in a specific column for selected key values.
            %
            % :param keyColumnName: Key column to match
            % :type keyColumnName: string
            % :param keyColumnValue: Key values to update (vector)
            % :type keyColumnValue: vector
            % :param updateColumnName: Column to be updated
            % :type updateColumnName: string
            % :param val: New values (vector; for matrix columns use cell array)
            % :type val: vector or cell
            arguments
                obj
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column values
                updateColumnName (1,1) string %Column you want to update
                value {mustBeVector(value)}
                keyColumnName (1,1) string = "SerialNumber" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll) || ...
                    ~ismember(updateColumnName,obj.ColumnNameAll)
                error("The keyColumnName or updateColumnName does not match any database table column name.")
            end
            if numel(keyColumnValue) ~= numel(value)
                error("The size of key column values must match the size of val.")
            end

            % Prepare the input value
            if updateColumnName == "SerialNumber"
                updateColumnType = "int64";
            else
                updateColumnType = obj.TableColumn(updateColumnName);
            end
            if ~contains(updateColumnType,"Matrix")
                if string(class(value)) ~= updateColumnType
                    error("Input value type is not correct.")
                end
            else
                if ~iscell(value)
                    error("For matrix columns, the input value mut be a cell array.")
                elseif string(class(value{1})) ~= strrep(updateColumnType,"Matrix","")
                    error("Input value type is not correct.")
                end
            end
            switch updateColumnType
                case "stringMatrix"
                    value = cellfun(@(x) strmat2str(x),value);
                case "string"

                otherwise
                    value = cellfun(@(x) string(mat2str(x)),value);
            end

            % Update the values
            conn = obj.connectDatabase;
            sqlquery = "UPDATE " + obj.TableName + " SET " + updateColumnName + " = '" + value + "'" + ...
                " WHERE " + keyColumnName + "="""  + keyColumnValue + ...
                    """; ";
            for ii = 1:numel(sqlquery)
                execute(conn, sqlquery(ii));
            end
            close(conn)
        end

        function deleteEntry(obj,keyColumnValue,keyColumnName)
            % Delete entries by key column and value(s).
            %
            % :param keyColumnName: Key column used for deletion
            % :type keyColumnName: string
            % :param keyColumnValue: Key values to delete (vector)
            % :type keyColumnValue: vector
            arguments
                obj
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column value. Can be an array
                keyColumnName (1,1) string = "SerialNumber" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                error("The keyColumnName does not match any database table column name.")
            end

            conn = obj.connectDatabase;
            if keyColumnName == "SerialNumber" || obj.TableColumn(keyColumnName) ~= "string"
                inList = "(" + join(string(keyColumnValue), ",") + ")";
            else
                inList = "('" + join(string(keyColumnValue), "','") + "')";
            end

            sqlquery = "DELETE FROM " + obj.TableName + " WHERE " + obj.TableName + "." + keyColumnName + " IN " + inList + ";";
            execute(conn,sqlquery);
            close(conn)
        end

        function deleteDuplicate(obj)
            if isempty(obj.DefaultEntry)
                return
            end
            conn = obj.connectDatabase;
            keyColumnName = obj.DefaultKey;
            sqlquery = "SELECT " + keyColumnName + " FROM " + obj.TableName;
            columnValueDb = fetch(conn,sqlquery);
            columnValueDb = columnValueDb.(keyColumnName);
            if ~isempty(columnValueDb)
                [~,idx] = unique(columnValueDb,'legacy');
                if ~isempty(idx)
                    warning("Detected duplicated entries. Will delete the older ones.")
                    obj.deleteEntry(setdiff(1:numel(columnValueDb),idx));
                end
            end
            close(conn)
        end
        
        function t = prepareInputTable(obj, t, isAllColumnsRequired)
            % Validate and normalize input rows against the schema.
            %
            % Ensures column names and MATLAB types match :attr:`TableColumn` regardless
            % of the input column order. Handles matrix-typed columns by auto-wrapping
            % non-cell inputs into per-row cells, then serializing to TEXT storage.
            % Supports empty [], missing/NaN/Inf in numeric matrix elements and empty
            % strings in string matrices.
            %
            % :param t: Input rows. Struct inputs are converted to table.
            % :type t: table or struct
            % :return: Normalized table (column order and types aligned to schema) ready for SQL writes.
            % :rtype: table

            arguments
                obj
                t
                isAllColumnsRequired (1,1) logical = false
            end

            %% Coerce to table if needed
            if ~isa(t,"table")
                if isa(t,"struct")
                    t = struct2table(t);
                else
                    error("Database input has to table or struct.")
                end
            end

            %% Get schema and table column names
            sColumnName = obj.TableColumn.keys.';        
            tColumnName = string(t.Properties.VariableNames);           

            %% Check column names    
            if isAllColumnsRequired && ~isempty(setdiff(sColumnName,tColumnName))
                error("If require all columns, the input table has to contain all columns.")
            end

            % Partial inputs allowed.
            % Keep only known columns in schema order.
            sColumnName = intersect(["SerialNumber",sColumnName], tColumnName, 'stable');
            t = t(:, sColumnName);
            if isempty(t)
                return
            end

            %% Check data type for non-matrix columns
            tColumnType = string(arrayfun(@(x) class(t.(x)),sColumnName,'UniformOutput',false));
            if sColumnName(1)=="SerialNumber"
                if ~isnumeric(t.SerialNumber)
                    error("The SerialNumber column of the input table has to be numeric.")
                elseif ~isinteger(t.SerialNumber)
                    t.SerialNumber = int64(t.SerialNumber);
                end
                tColumnType = tColumnType(2:end);
                sColumnName = sColumnName(2:end);
            end
            sColumnType = obj.TableColumn(sColumnName);
            
            matIdx = contains(sColumnType,"Matrix");
            mismatchIndex = tColumnType(~matIdx) ~= sColumnType(~matIdx);
            if any(mismatchIndex)
                nonMatColumnName = sColumnName(~matIdx);
                wrongColumn = join(nonMatColumnName(mismatchIndex),",");
                error("Input table variable types do not match the database table for " + ...
                    wrongColumn + ".")
            end

            %% Check data type for matrix columns, serialize and normalize the output
            if any(matIdx)
                sColumnTypeBare = replace(sColumnType,"Matrix","");
                cellIdx = tColumnType == "cell";
                nonCellIdx = (~cellIdx) & matIdx;
                if any(nonCellIdx)
                    % Do the operation for matrix columns that was not
                    % prepared as cells
                    mismatchIndex = tColumnType(nonCellIdx) ~= sColumnTypeBare(nonCellIdx);
                    if any(mismatchIndex)
                        nonCellColumnName = sColumnName(nonCellIdx);
                        wrongColumn = join(nonCellColumnName(mismatchIndex),",");
                        error("Input table variable types do not match the database table for " + ...
                            wrongColumn + ".")
                    end
                    nonCellStringIdx = (tColumnType == "string") & nonCellIdx;
                    t = updateTableVarfun(@prepareNonCellString,t,sColumnName(nonCellStringIdx));
                    nonCellOtherIdx = (tColumnType ~= "string") & nonCellIdx;
                    t = updateTableVarfun(@prepareNonCellOther,t,sColumnName(nonCellOtherIdx));
                end
                if any(cellIdx)
                    % Do the operation for matrix columns prepared as cells
                    cellColumnName = sColumnName(cellIdx);
                    sColumnTypeBareCell = sColumnTypeBare(cellIdx);
                    tColumnTypeCell = string(arrayfun(@(x) class(t.(x){1}),cellColumnName,'UniformOutput',false));
                    mismatchIndex = tColumnTypeCell ~= sColumnTypeBareCell;
                    if any(mismatchIndex)
                        wrongColumn = join(cellColumnName(mismatchIndex),",");
                        error("Input table variable types do not match the database table for " + ...
                            wrongColumn + ".")
                    end
                    cellStringIdx = tColumnTypeCell == "string";
                    t = updateTableVarfun(@prepareCellString,t,cellColumnName(cellStringIdx));
                    cellOtherIdx = tColumnTypeCell ~= "string";
                    t = updateTableVarfun(@prepareCellOther,t,cellColumnName(cellOtherIdx));
                end
            end
            
            function out = prepareNonCellString(in)
                out = join(normalizeString(in),",");
            end

            function out = prepareNonCellOther(in)
                out = arrayfun(@(x) string(mat2str(in(x,:))),(1:height(in))');
            end

            function out = prepareCellString(in)
                out = string(cellfun(@(x) strmat2str(normalizeString(x)),in, 'UniformOutput', false));
            end 

            function out = prepareCellOther(in)
                out = string(cellfun(@(x) mat2str(x),in, 'UniformOutput', false));
            end 

            function str = normalizeString(str)
                % Replace empty with None
                maskEmpty = ismissing(str) | str == "";
                if any(maskEmpty(:))
                    str(maskEmpty) = "None";
                end

                % Escape single and double quotes
                str = replace(str, "'", "''");
                str = replace(str, '"', '""');
            end
        end

        function t = readTable(obj,IsHideSerial)
            % Read the entire table and convert columns to MATLAB types.
            %
            % :return: All rows in this setting's table.
            % :rtype: table
            arguments
                obj
                IsHideSerial logical = false
            end
            conn = obj.connectDatabaseRead;
            t = sqlread(conn,obj.TableName);
            t = obj.convertOutputTable(t,IsHideSerial);
            close(conn)
        end

        function t = readEntry(obj,keyColumnValue,keyColumnName,IsHideSerial)
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
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column values
                keyColumnName (1,1) string = "SerialNumber" %Key column name (optional)
                IsHideSerial logical = false
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                error("Wrong keyColumnName.")
            end
            conn = obj.connectDatabaseRead;
            if keyColumnName == "SerialNumber" || obj.TableColumn(keyColumnName) ~= "string"
                inList = "(" + join(string(keyColumnValue), ",") + ")";
            else
                vals = string(keyColumnValue);
                vals = replace(vals, "'", "''");
                inList = "('" + join(vals, "','") + "')";
            end
            
            sqlquery = "SELECT * FROM " + obj.TableName + " WHERE " + obj.TableName + "." + keyColumnName + " IN " + inList + ";";
            t = fetch(conn,sqlquery);
            t = obj.convertOutputTable(t,IsHideSerial);
            close(conn)
        end

        function t = readValue(obj,keyColumnValue,readColumnName,keyColumnName)
            % Read one or more columns filtered by a key column and values.
            %
            % :param keyColumnName: Column to filter on
            % :type keyColumnName: string
            % :param keyColumnValue: Key values to match (vector)
            % :type keyColumnValue: vector
            % :param readColumnName: Column name(s) to return
            % :type readColumnName: string or string vector
            % :return: Table of selected columns, or a vector when a single column is requested
            % :rtype: table or vector
            arguments
                obj
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column values
                readColumnName string {mustBeVector(readColumnName)} %Columns you want to read
                keyColumnName (1,1) string = "SerialNumber" %Key column name (optional)
            end
            cols = obj.ColumnNameAll;
            if ~ismember(keyColumnName,cols) || any(~ismember(readColumnName,cols))
                error("Wrong keyColumnName or readColumnName.")
            end
            conn = obj.connectDatabaseRead;
            if keyColumnName == "SerialNumber" || obj.TableColumn(keyColumnName) ~= "string"
                inList = "(" + join(string(keyColumnValue), ",") + ")";
            else
                vals = string(keyColumnValue);
                vals = replace(vals, "'", "''");
                inList = "('" + join(vals, "','") + "')";
            end
            columnStr = join(readColumnName,",");

            sqlquery = "SELECT " + columnStr + " FROM " + obj.TableName + " WHERE " + obj.TableName + "." + keyColumnName + " IN " + inList + ";";
            t = fetch(conn,sqlquery);
            t = obj.convertOutputTable(t);
            if isscalar(readColumnName)
                t = t.(readColumnName);
            end
            close(conn)
        end

        function t = convertOutputTable(obj,t,IsHideSerial)
            % Convert SQLite-stored values back to MATLAB types.
            %
            % Converts matrix-encoded strings and logical columns to their corresponding
            % MATLAB representations based on :attr:`TableColumn`.
            %
            % :param t: Table read from the database.
            % :type t: table
            % :return: Table with converted MATLAB types.
            % :rtype: table
            arguments
                obj
                t table
                IsHideSerial logical = false
            end

            if isempty(t)
                t = table.empty;
                return
            end

            columnName = obj.TableColumn.keys.';
            columnType = obj.TableColumn.values.';
            presentVars = string(t.Properties.VariableNames);

            % Convert matrix data
            matIdx = contains(columnType,"Matrix");
            if any(matIdx)
                for ii = find(matIdx)
                    if ~ismember(columnName(ii), presentVars)
                        continue
                    end
                    switch columnType(ii)
                        case "stringMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) str2strmat(x),t.(columnName(ii)),"UniformOutput",false);
                        case "doubleMatrix"
                            % Use str2num for performance/safety over eval
                            t.(columnName(ii)) = arrayfun(@(x) str2num(x), t.(columnName(ii)), "UniformOutput", false); %#ok<ST2NM>
                        case "logicalMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) logical(str2num(x)), t.(columnName(ii)), "UniformOutput", false); %#ok<ST2NM>
                    end
                end
            end

            % Convert logical data
            logIdx = columnType =="logical";
            if any(logIdx)
                for ii = find(logIdx)
                    if ~ismember(columnName(ii), presentVars)
                        continue
                    end
                    t.(columnName(ii)) = arrayfun(@(x) logical(x),t.(columnName(ii)));
                end
            end

            % Delete SerialNumber if needed
            if IsHideSerial && ismember("SerialNumber",presentVars)
                t.SerialNumber = [];
            end
        end

    end

    methods (Abstract)
        defineSchema(obj)
    end
end

