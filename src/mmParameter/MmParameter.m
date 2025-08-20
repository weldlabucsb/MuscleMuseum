classdef MmParameter < handle
    %:class:`MmParameter` manages persistent toolbox parameters/settings using a local SQLite database.
    %
    % Provides schema definition, validation, and automatic migration via a metadata
    % table and a schema hash. Supports default entries, typed columns, and
    % conversion between MATLAB types and SQLite storage formats.
    %
    % **Key features:**
    %
    % - Metadata table for multi-table schema tracking
    % - Schema hashing for change detection
    % - ``PRAGMA table_info`` for schema introspection
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    s = YourParameterSubclass();
    %    s.checkTable(); % ensure schema exists and is current
    %    t = s.readTable();
    %
    % **Notes:**
    %
    % - The database file is placed under ``getHome()/Documents/MMUser/config`` and is
    %   named according to :attr:`DataBaseName`.
    % - String and matrix-typed columns are serialized to TEXT and converted back on read.

    properties (SetAccess=protected)
        TableColumn dictionary =  dictionary("Name","string") %Stores column name and type. Should be defined in subclass's construtor
        DefaultValue dictionary =  dictionary("Name","Name") %Stores column name and default value. Should be defined in subclass's construtor. Using Null is not recommended.
        DefaultEntry table %Default entries for initial setup
        TableName (1,1) string %Table name is consistent with the subclass name
        DefaultKey (1,1) string %The default key string will be the name of the first column after ID
        ColumnNameAll string %Including the ID column
        ColumnTypeAll string %Including the ID column's type
        ExtraColumnFromJoin string
        JoinCondition table %TableRight,KeyLeft,KeyRight,ColumnLeft,ColumnRight
        IsTriggerJoinOnRight (1,1) logical = false %Determine if we want to trigger the join automatically when the join table is updated or inserted
        IsTriggerJoinOnLeft (1,1) logical = false %Determine if we want to trigger the join automatically when this table is updated or inserted
        IsIncludeDefaultEntry (1,1) logical = false %Determine if we want to automatically include the default entries into the table
    end

    % Removed IsIndexed: all tables now have a built-in INTEGER PRIMARY KEY 'ID'

    properties (Constant)
        DataBaseName = "mmParameter.db" %Database file name. Saved under MMUser/config
        DataTypeMapping = dictionary(...
            ["int64","double","logical","string","doubleMatrix","logicalMatrix","stringMatrix","struct","table"],...
            ["INTEGER","REAL","INTEGER","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT"]) %Map MATLAB types to database types
        MetadataTableName = "SchemaMetadata" %Table to store schema information for all tables
    end

    properties (Dependent)
        SchemaHash (1,1) string %Hash of current schema definition including default entries
        IsSchemaCurrent (1,1) logical %Check whether the stored schema hash matches the current schema.
    end

    methods
        function obj = MmParameter()
            % Construct an instance of :class:`MmParameter`.
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
            obj.ColumnNameAll = ["ID",columnName.'];
            obj.ColumnTypeAll = ["int64",obj.TableColumn.values.'];
            if ~isempty(obj.JoinCondition)
                joinTableColumns = obj.JoinCondition.ColumnLeft.';
                joinTableColumns = cat(2,joinTableColumns{:});
                obj.ExtraColumnFromJoin = setdiff(joinTableColumns,obj.ColumnNameAll);
            end
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

            % Add join information
            if ~isempty(obj.JoinCondition)
                schemaStr = schemaStr + ...
                    join(...
                    "TableRight:" + obj.JoinCondition.TableRight +...
                    ",KeyLeft:" + obj.JoinCondition.KeyLeft +...
                    ",KeyRight:" + obj.JoinCondition.KeyRight +...
                    ",ColumnLeft:" + cellfun(@(x) join(x,","), obj.JoinCondition.ColumnLeft) + ...
                    ",ColumnRight:" + cellfun(@(x) join(x,","), obj.JoinCondition.ColumnRight),...
                    ",") + ";";
            end
            schemaStr = schemaStr + "IsTriggerJoinOnJoinTable:" + obj.IsTriggerJoinOnRight + ";";
            schemaStr = schemaStr + "IsTriggerJoinOnSelf:" + obj.IsTriggerJoinOnLeft + ";";
            schemaStr = schemaStr + "IsIncludeDefaultEntry:" + obj.IsIncludeDefaultEntry + ";";

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
            % Ensure this parameter table exists and matches the current schema.
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
                    % modified accidentally,
                    obj.updateDefaultEntry;
                end
            end

            obj.createJoin
        end

        function checkConstructor(obj)
            % Validate constructor-provided schema and defaults.
            %
            % Ensures :attr:`TableColumn` types follow :attr:`DataTypeMapping`,
            % :attr:`DefaultEntry` rows can be serialized by :meth:`prepareInputTable`,
            % and that :attr:`DefaultValue` includes all columns.

            if isempty(obj.TableColumn)
                obj.throwError("TableColumn can not be empty.")
            elseif(any(~ismember(obj.TableColumn.values,obj.DataTypeMapping.keys)))
                obj.throwError("Data types (the key values) are not set correctly in TableColumn")
            end

            if ~isempty(obj.DefaultEntry)
                try
                    obj.prepareInputTable(obj.DefaultEntry);
                catch
                    obj.throwError("Default entries are not set correctly.")
                end
            end

            if isempty(obj.DefaultValue)
                obj.throwError("Default values must be set.")
            else
                columnName = obj.TableColumn.keys;
                defaulValueColumnName = obj.DefaultValue.keys;
                if ~isempty(setdiff(columnName,defaulValueColumnName))
                    obj.throwError("Default values must be set for all columnes.")
                end
            end

            if ~isempty(obj.JoinCondition)
                columns = string(obj.JoinCondition.Properties.VariableNames);
                if ~isempty(setdiff(["TableRight","KeyLeft","KeyRight","ColumnLeft","ColumnRight"],columns))
                    obj.throwError("JoinCondition must include TableRight,KeyLeft,KeyRight,ColumnLeft,ColumnRight.")
                elseif ~isstring(obj.JoinCondition.TableRight)
                    obj.throwError("TableRight of JoinCondition must be astring")
                elseif ~isstring(obj.JoinCondition.KeyLeft)
                    obj.throwError("KeyLeft of JoinCondition must be astring")
                elseif ~isstring(obj.JoinCondition.KeyRight)
                    obj.throwError("KeyRight of JoinCondition must be astring")
                elseif ~iscell(obj.JoinCondition.ColumnLeft) || ~isstring(obj.JoinCondition.ColumnLeft{1})
                    obj.throwError("ColumnLeft of JoinCondition must be is a cell of string.")
                elseif ~iscell(obj.JoinCondition.ColumnRight) || ~isstring(obj.JoinCondition.ColumnRight{1})
                    obj.throwError("ColumnRight of JoinCondition must be is a cell of string.")
                elseif any(cellfun(@numel,obj.JoinCondition.ColumnLeft) ~= cellfun(@numel,obj.JoinCondition.ColumnRight))
                    obj.throwError("In JoinCondition, ColumnLeft element number must be equal to ColumnRight.")
                elseif any(~ismember(obj.JoinCondition.KeyLeft,obj.ColumnNameAll))
                    obj.throwError("KeyLeft of JoinCondition must be a memeber of this table's columns.")
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
            % Build DDL with ID first as INTEGER PRIMARY KEY
            colDefs = "ID INTEGER PRIMARY KEY, " + ...
                columnName(1) + " " + columnType(1) + " NOT NULL UNIQUE, " + ...
                join(columnName(2:end) + " " + columnType(2:end) + ...
                " DEFAULT " + columnDefault(2:end), ", ");
            sqlquery = "CREATE TABLE " + obj.TableName + "(" + colDefs + ");";
            execute(conn,sqlquery)

            close(conn);
            obj.updateDefaultEntry;
            obj.updateSchemaMetadata;
        end

        function createJoin(obj)
            % Create join-backed shadow columns and triggers based on :attr:`JoinCondition`.
            %
            % For each entry in :attr:`JoinCondition` with key ``[JoinTable, JoinKey]`` and
            % value of data columns to mirror, this will:
            %
            % - Add missing columns to this table
            % - Populate them once from the join table
            % - Create triggers to keep them updated on INSERT/UPDATE of either table,
            %   according to :attr:`IsTriggerJoinOnJoinTable` and :attr:`IsTriggerJoinOnSelf`.
            %
            % Called from :meth:`checkTable` after ensuring the base table exists.
            
            if isempty(obj.JoinCondition)
                return
            end

            % Get current table info
            conn = obj.connectDatabase;
            sqlquery = 'SELECT name, type FROM pragma_table_info(''' + obj.TableName +  ''')';
            dbColumn = fetch(conn, sqlquery);

            % Make join
            for ii = 1:height(obj.JoinCondition)
                tableRight = obj.JoinCondition.TableRight(ii);
                keyLeft = obj.JoinCondition.KeyLeft(ii);
                keyRight = obj.JoinCondition.KeyRight(ii);
                sqlquery = 'SELECT name, type FROM pragma_table_info(''' + tableRight +  ''')';
                rdbColumn = fetch(conn, sqlquery);
                if ~isempty(rdbColumn) &&...
                        ismember(keyRight,rdbColumn.name) &&...
                        ismember(keyLeft,dbColumn.name)
                    columnRight = obj.JoinCondition.ColumnRight{ii};
                    columnLeft = obj.JoinCondition.ColumnLeft{ii};
                    [columnRight,idx,idx2] = intersect(rdbColumn.name,columnRight);
                    columnType = rdbColumn.type(idx);
                    columnLeft = columnLeft(idx2);
                    if ~isempty(columnRight)
                        makeJoin(tableRight,keyLeft,keyRight,columnLeft.',columnRight,columnType)
                    end
                end
            end

            function makeJoin(tr,kl,kr,cl,cr,ct)
                %% Create column if missing
                sql = "ALTER TABLE " + obj.TableName + ...
                    " ADD " + cl + " " + ct + ";";
                for ll = 1:numel(sql)
                    if ~ismember(cl(ll),dbColumn.name)
                        execute(conn,sql(ll))
                    end
                end

                %% Join once
                sql = "UPDATE " + obj.TableName + newline + ...
                    "SET " + newline + ...
                    join("  " + cl + " = (SELECT " + tr + "." + cr + " FROM " +tr +...
                    " WHERE " + tr + "." + kr + " = " + obj.TableName + "." + kl + ")",","+newline) + newline + ...
                "WHERE " + kl + " IN (SELECT " + tr + "."+ kr + " FROM " + tr + ");";
                execute(conn,sql)

                %% Add trigger

                if obj.IsTriggerJoinOnRight
                    %% Check if update trigger already exists
                    triggerNameUpdate = "update_" + obj.TableName + "_key_" + kl + "_on_" + tr + "_" + kr + "_update";
                    sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                    triggerDb = fetch(conn,sql);
                    if isempty(triggerDb)
                        % Create trigger
                        sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                            "AFTER UPDATE OF " + kr + " ON " + tr + newline + ...
                            "FOR EACH ROW" + newline + ...
                            "BEGIN" + newline + ...
                            "   UPDATE " + obj.TableName + newline + ...
                            "   SET " + newline + ...
                            join("      " + cl + " = NEW." + cr,","+newline) + newline + ...
                            "   WHERE " + obj.TableName + "." + kl + " = OLD." + kr + ";" + newline + ...
                            "END;";
                        execute(conn,sql)
                    end

                    %% Check if insert trigger already exists
                    triggerNameUpdate = "update_" + obj.TableName + "_key_" + kl + "_on_" + tr + "_" + kr + "_insert";
                    sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                    triggerDb = fetch(conn,sql);
                    if isempty(triggerDb)
                        % Create trigger
                        sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                            "AFTER INSERT ON " + tr + newline + ...
                            "FOR EACH ROW" + newline + ...
                            "BEGIN" + newline + ...
                            "   UPDATE " + obj.TableName + newline + ...
                            "   SET " + newline + ...
                            join("      " + cl + " = NEW." + cr,","+newline) + newline + ...
                            "   WHERE " + obj.TableName + "." + kl + " = NEW." + kr + ";" + newline + newline + ...
                            "END;";
                        execute(conn,sql)
                    end
                end

                if obj.IsTriggerJoinOnLeft
                    %% Check if update trigger already exists
                    selectFromTableRight = "(SELECT " + tr + "." + cr + " FROM " + tr + " WHERE " + tr + "." + kr +" = NEW." + kl + ")";
                    triggerNameUpdate = "update_" + obj.TableName + "_key_" + kl + "_on_" + obj.TableName + "_" + kl + "_update";
                    sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                    triggerDb = fetch(conn,sql);
                    if isempty(triggerDb)
                        % Create trigger
                        
                        sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                            "AFTER UPDATE OF " + kl + " ON " + obj.TableName + newline + ...
                            "FOR EACH ROW" + newline + ...
                            "WHEN EXISTS (SELECT 1 FROM " + tr + " WHERE " + tr + "." + kr + " = NEW."+ kl +")" + newline + ...
                            "BEGIN" + newline + ...
                            "   UPDATE " + obj.TableName + newline + ...
                            "   SET " + newline + ...
                            join("      " + cl + " = " + selectFromTableRight,","+newline) + newline + ...
                            "   WHERE " + obj.TableName + "." + kl + " = NEW." + kl + ";" + newline + ...
                            "END;";
                        execute(conn,sql)
                    end

                    %% Check if insert trigger already exists
                    triggerNameUpdate = "update_" + obj.TableName + "_key_" + kl + "_on_" + obj.TableName + "_" + kl + "_insert";
                    sql = "SELECT name FROM sqlite_master WHERE type='trigger' AND name='" + triggerNameUpdate + "';";
                    triggerDb = fetch(conn,sql);
                    if isempty(triggerDb)
                        % Create trigger
                        sql = "CREATE TRIGGER " + triggerNameUpdate + newline +...
                            "AFTER INSERT ON " + obj.TableName + newline + ...
                            "FOR EACH ROW" + newline + ...
                            "WHEN EXISTS (SELECT 1 FROM " + tr + " WHERE " + tr + "." + kr + " = NEW."+ kl +")" + newline + ...
                            "BEGIN" + newline + ...
                            "   UPDATE " + obj.TableName + newline + ...
                            "   SET " + newline + ...
                            join("      " + cl + " = "+ selectFromTableRight,","+newline) + newline + ...
                            "   WHERE " + obj.TableName + "." + kl + " = NEW." + kl + ";" + newline + ...
                            "END;";
                        execute(conn,sql)
                    end
                end

            end
        end

        function updateDefaultEntry(obj)
            % Insert default entries into the table if present.
            %
            % Uses :attr:`DefaultEntry` and the first key in :attr:`TableColumn` to write
            % initial rows. No action if :attr:`DefaultEntry` is empty.
            % Insert default entries if provided and not empty
            if ~isempty(obj.DefaultEntry)
                if obj.IsIncludeDefaultEntry
                    % Use the first schema column (e.g., Name) as the upsert key
                    obj.updateEntry(obj.DefaultEntry, obj.DefaultKey)
                else
                    obj.deleteEntry(obj.DefaultEntry.(obj.DefaultKey),obj.DefaultKey)
                end
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

            % Ensure ID exists; if not, recreate table
            if ~ismember("ID", dbColumns.name)
                close(conn);
                obj.recreateTable();
                obj.updateDefaultEntry;
                obj.updateSchemaMetadata;
                return
            end

            % Find missing columns (excluding ID, which is managed by core)
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
            extraColumns = setdiff(dbColumns.name, ["ID"; targetColumnNames]);
            extraColumns = setdiff(extraColumns,obj.ExtraColumnFromJoin);
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
            obj.updateDefaultEntry;
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
            % Determine columns to copy; include ID only if present in old table
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
            t = obj.prepareInputTable(t, false, true);
            conn = obj.connectDatabase;
            sqlwrite(conn,obj.TableName,t)
            close(conn)
        end

        function updateTable(obj,t,isRequireAll)
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
                t % Input table or structure
                isRequireAll logical = false
            end
            if isempty(t)
                return
            end

            % Check if the input table is formatted correctly (require all columns)
            obj.prepareInputTable(t, isRequireAll);

            % Delete the existing entries
            conn = obj.connectDatabase;
            sqlquery = "DELETE FROM " + obj.TableName + ";";
            execute(conn, sqlquery);
            close(conn)

            % Insert default entry
            obj.updateDefaultEntry

            % Insert t into the database table
            obj.updateEntry(t,obj.DefaultKey)

        end

        function updateEntry(obj, t, keyColumnName)
            % Upsert rows using ``sqlupdate`` for matching keys and ``sqlwrite`` for new rows.
            %
            % :param t: Input rows to write (all schema columns, any order)
            % :type t: table or struct
            % :param keyColumnName: Conflict key when ``ID`` is absent; default "ID"
            % :type keyColumnName: string, optional
            arguments
                obj
                t
                keyColumnName (1,1) string = "ID"
            end
            if isempty(t)
                return
            elseif ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("The keyColumnName does not match any database table column name.")
            else
                tOrigin = t;
                t = prepareInputTable(obj,t);
                if ~ismember(keyColumnName,t.Properties.VariableNames)
                    obj.throwError("The keyColumnName does not match any input table column name.")
                end
            end

            % rewrite entries if they match the key
            conn = obj.connectDatabase;
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
            % :param value: New values (vector; for matrix columns use cell array)
            % :type value: vector or cell
            arguments
                obj
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column values
                updateColumnName (1,1) string %Column you want to update
                value
                keyColumnName (1,1) string = "ID" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("The keyColumnName does not match any database table column name.")
            end
            if ~(numel(keyColumnValue) == 1 || numel(keyColumnValue) == numel(value))
                obj.throwError("The size of key column values must match the size of val.")
            end
            if ~isempty(value) && ~isvector(value)
                obj.throwError("Input value mut be a vector.")
            end

            value = obj.prepareInputValue(updateColumnName,value,numel(keyColumnValue) == 1);

            % Update the values
            conn = obj.connectDatabase;
            if keyColumnName ~= "ID" && contains(obj.TableColumn(keyColumnName), "string")
                keyColumnValue = "'" + keyColumnValue + "'";
            end
            sqlquery = "UPDATE " + obj.TableName + " SET " + updateColumnName + " = '" + value + "'" + ...
                " WHERE " + keyColumnName + "="  + keyColumnValue + "; ";
            for ii = 1:numel(sqlquery)
                execute(conn, sqlquery(ii));
            end
            close(conn)
        end

        function updateColumn(obj,updateColumnName,value)
            arguments
                obj
                updateColumnName (1,1) string
                value   
            end
            if ~isempty(value) && ~isvector(value)
                obj.throwError("Input value mut be a vector.")
            end

            value = obj.prepareInputValue(updateColumnName,value);
            conn = obj.connectDatabase;
            sqlquery = "UPDATE " + obj.TableName + " SET " + updateColumnName + ...
                " = " + value + ";";
            execute(conn,sqlquery)
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
                keyColumnName (1,1) string = "ID" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("The keyColumnName does not match any database table column name.")
            end

            conn = obj.connectDatabase;
            if keyColumnName == "ID" || ~contains(obj.TableColumn(keyColumnName), "string")
                inList = "(" + join(string(keyColumnValue), ",") + ")";
            else
                inList = "('" + join(string(keyColumnValue), "','") + "')";
            end

            sqlquery = "DELETE FROM " + obj.TableName + " WHERE " + obj.TableName + "." + keyColumnName + " IN " + inList + ";";
            execute(conn,sqlquery);
            close(conn)
        end

        function t = prepareInputTable(obj, t, isAllColumnsRequired,isIgnoreId)
            % Validate and normalize input rows against the schema.
            %
            % Ensures column names and MATLAB types match :attr:`TableColumn` regardless
            % of the input column order. Partial inputs are allowed unless
            % ``isAllColumnsRequired`` is true. Matrix-typed columns are serialized to
            % TEXT: non-cell inputs are wrapped per row; cell inputs are validated and
            % serialized. Supports empty [], missing/NaN/Inf in numeric matrices and
            % empty strings in string matrices.
            %
            % :param t: Input rows. Struct inputs are converted to table.
            % :type t: table or struct
            % :return: Normalized table (column order and types aligned to schema) ready for SQL writes.
            % :rtype: table

            arguments
                obj
                t
                isAllColumnsRequired (1,1) logical = false
                isIgnoreId (1,1) logical = false
            end

            %% Coerce to table if needed
            if ~isa(t,"table")
                if isa(t,"struct")
                    t = struct2table(t,'AsArray',true);
                else
                    obj.throwError("Database input has to table or struct.")
                end
            end

            %% Get schema and table column names
            sColumnName = obj.TableColumn.keys.';
            tColumnName = string(t.Properties.VariableNames);

            %% Check column names
            if isAllColumnsRequired && ~isempty(setdiff(sColumnName,tColumnName))
                obj.throwError("If require all columns, the input table has to contain all columns.")
            end

            % Partial inputs allowed.
            % Keep only known columns in schema order.
            sColumnName = intersect(["ID",sColumnName], tColumnName, 'stable');
            t = t(:, sColumnName);
            if isempty(t)
                return
            end

            %% Check data type for non-matrix and non-json columns
            tColumnType = string(arrayfun(@(x) class(t.(x)),sColumnName,'UniformOutput',false));
            if sColumnName(1)=="ID"
                if isIgnoreId
                    t.ID = [];
                elseif ~isnumeric(t.ID)
                    obj.throwError("The ID column of the input table has to be numeric.")
                elseif ~isinteger(t.ID)
                    t.ID = int64(t.ID);
                end
                tColumnType = tColumnType(2:end);
                sColumnName = sColumnName(2:end);
            end
            sColumnType = obj.TableColumn(sColumnName);

            jsonIdx = (sColumnType == "table") | (sColumnType == "struct");
            
            matIdx = contains(sColumnType,"Matrix");
            numIdx = contains(sColumnType,["double","logical"]);
            nonMatnonJsonIdx = (~matIdx) & (~jsonIdx);
            mismatchIndex = tColumnType(nonMatnonJsonIdx) ~= sColumnType(nonMatnonJsonIdx);
            if any(mismatchIndex)
                nonMatColumnName = sColumnName(nonMatnonJsonIdx);
                mismatchName = nonMatColumnName(mismatchIndex);
                mismatchNumIdx = mismatchIndex & numIdx(nonMatnonJsonIdx);
                mismatchNumPass = arrayfun(@(x) isnumeric(t.(x))||islogical(t.(x)),nonMatColumnName(mismatchNumIdx));
                passColumnName = nonMatColumnName(mismatchNumIdx);
                passColumnName = passColumnName(mismatchNumPass);
                mismatchName(ismember(mismatchName,passColumnName)) = [];
                if ~isempty(mismatchName)
                    obj.throwError("Input table variable types do not match the database table for " + ...
                        join(mismatchName,",") + ".")
                end
            end
            strScalarIdx = sColumnType == "string";
            t = updateTableVarfun(@normalizeString,t,sColumnName(strScalarIdx));

            %% Check data type for json columns
            if any(jsonIdx)
                cellIdx = (tColumnType == "cell") & jsonIdx;
                nonCellIdx = (tColumnType ~= "cell") & jsonIdx;
                if any(cellIdx)
                    cellColumnName = sColumnName(cellIdx);
                    tColumnTypeCell = string(arrayfun(@(x) class(t.(x){1}),cellColumnName,'UniformOutput',false));
                    mismatchIndex = tColumnTypeCell ~= sColumnType(cellIdx);
                    if any(mismatchIndex)
                        mismatchName = cellColumnName(mismatchIndex);
                        obj.throwError("Input table variable types do not match the database table for " + ...
                        join(mismatchName,",") + ".")
                    end
                    for ii = find(cellIdx)
                        t.(sColumnName(ii)) = cellfun(@normalizeJson, t.(sColumnName(ii)));
                    end
                end
                if any(nonCellIdx)
                    nonCellColumnName = sColumnName(nonCellIdx);
                    mismatchIndex = tColumnType(nonCellIdx) ~= sColumnType(nonCellIdx);
                    if any(mismatchIndex)
                        mismatchName = nonCellColumnName(mismatchIndex);
                        obj.throwError("Input table variable types do not match the database table for " + ...
                        join(mismatchName,",") + ".")
                    end
                    for ii = find(nonCellIdx)
                        t.(sColumnName(ii)) = arrayfun(@normalizeJson, t.(sColumnName(ii)));
                    end
                end
            end

            %% Check data type for matrix columns, serialize and normalize the output
            if any(matIdx)
                cellIdx = (tColumnType == "cell") & matIdx;
                nonCellIdx = (tColumnType ~= "cell") & matIdx;
                sColumnTypeBare = replace(sColumnType,"Matrix","");
                if any(nonCellIdx)
                    % Do the operation for matrix columns that was not
                    % prepared as cells
                    mismatchIndex = tColumnType(nonCellIdx) ~= sColumnTypeBare(nonCellIdx);
                    if any(mismatchIndex)
                        nonCellColumnName = sColumnName(nonCellIdx);
                        mismatchName = nonCellColumnName(mismatchIndex);
                        mismatchNumIdx = mismatchIndex & numIdx(nonCellIdx);
                        mismatchNumPass = arrayfun(@(x) isnumeric(t.(x))||islogical(t.(x)),nonCellColumnName(mismatchNumIdx));
                        passColumnName = nonCellColumnName(mismatchNumIdx);
                        passColumnName = passColumnName(mismatchNumPass);
                        mismatchName(ismember(mismatchName,passColumnName)) = [];
                        if ~isempty(mismatchName)
                            obj.throwError("Input table variable types do not match the database table for " + ...
                                join(mismatchName,",") + ".")
                        end
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
                        mismatchName = cellColumnName(mismatchIndex);
                        mismatchNumIdx = mismatchIndex & numIdx(cellIdx);
                        mismatchNumPass = arrayfun(@(x) isnumeric(t.(x))||islogical(t.(x){1}),cellColumnName(mismatchNumIdx));
                        passColumnName = cellColumnName(mismatchNumIdx);
                        passColumnName = passColumnName(mismatchNumPass);
                        mismatchName(ismember(mismatchName,passColumnName)) = [];
                        if ~isempty(mismatchName)
                            obj.throwError("Input table variable types do not match the database table for " + ...
                                join(mismatchName,",") + ".")
                        end
                    end
                    cellStringIdx = tColumnTypeCell == "string";
                    t = updateTableVarfun(@prepareCellString,t,cellColumnName(cellStringIdx));
                    cellOtherIdx = tColumnTypeCell ~= "string";
                    t = updateTableVarfun(@prepareCellOther,t,cellColumnName(cellOtherIdx));
                end
            end
        end

        function value = prepareInputValue(obj,updateColumnName,value,isScalar)
            arguments
                obj
                updateColumnName (1,1) string
                value
                isScalar logical = false
            end
            if ~ismember(updateColumnName,obj.ColumnNameAll)
                obj.throwError("The updateColumnName does not match any database table column name.")
            end

            % Prepare the input value
            if updateColumnName == "ID"
                updateColumnType = "int64";
            else
                updateColumnType = obj.TableColumn(updateColumnName);
            end
            isNum = contains(updateColumnType,["double","logical","int64"]);
            isJson = contains(updateColumnType,["table","struct"]);
            if ~contains(updateColumnType,"Matrix")
                if string(class(value)) ~= updateColumnType
                    if isNum
                        if ~(isnumeric(value) || islogical(value))
                            obj.throwError("Input value type is not correct.")
                        end
                    elseif isJson
                        if string(class(value{1})) ~= updateColumnType
                            obj.throwError("Input value type is not correct.")
                        end
                    else
                        obj.throwError("Input value type is not correct.")
                    end
                end
            else
                if ~iscell(value)
                    if isScalar
                        value = {value};
                    else
                        obj.throwError("For matrix columns, the input value mut be a cell array.")
                    end
                end
                if string(class(value{1})) ~= strrep(updateColumnType,"Matrix","")
                    if isNum
                        if ~(isnumeric(value{1}) || islogical(value{1}))
                            obj.throwError("Input value type is not correct.")
                        end
                    else
                        obj.throwError("Input value type is not correct.")
                    end
                end
            end
            switch updateColumnType
                case "stringMatrix"
                    value = cellfun(@(x) strmat2str(normalizeString(x)),value);
                case "string"
                    value = normalizeString(value);
                case {"doubleMatrix","logicalMatrix"}
                    value = cellfun(@(x) string(mat2str(x)),value);
                case {"table","struct"}
                    if iscell(value)
                        value = cellfun(@normalizeJson, value);
                    else
                        value = arrayfun(@normalizeJson, value);
                    end
            end
        end
        
        function t = readTable(obj,IsHideSerial)
            % Read the entire table and convert columns to MATLAB types.
            %
            % :return: All rows in this parameter table.
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
            % Filtering is supported for base table columns.
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
                keyColumnName (1,1) string = "ID" %Key column name (optional)
                IsHideSerial logical = false
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("Wrong keyColumnName.")
            end

            if keyColumnName == "ID" && islogical(keyColumnValue)
                keyColumnValue = find(keyColumnValue);
                if isempty(keyColumnValue)
                    t = [];
                    return
                end
            end

            conn = obj.connectDatabaseRead;
            if keyColumnName == "ID" || ~contains(obj.TableColumn(keyColumnName), "string")
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

        function value = readColumn(obj,readColumnName)
            arguments
                obj
                readColumnName string {mustBeVector(readColumnName)} 
            end
            if any(~ismember(readColumnName,[obj.ColumnNameAll,obj.ExtraColumnFromJoin]))
                obj.throwError("readColumnName is not a valid column name.")
            end
            sqlquery = "SELECT " + join(readColumnName,", ") + " FROM " + obj.TableName + ";";
            conn = obj.connectDatabaseRead;
            value = fetch(conn,sqlquery);
            value = obj.convertOutputTable(value);
            if isscalar(readColumnName)
                value = value.(readColumnName);
            end
        end

        function t = readValue(obj,keyColumnValue,readColumnName,keyColumnName)
            % Read one or more columns filtered by a key column and values.
            %
            % When a single column is requested, a vector is returned instead of a table.
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
                keyColumnName (1,1) string = "ID" %Key column name (optional)
            end
            cols = obj.ColumnNameAll;
            if ~ismember(keyColumnName,cols) || any(~ismember(readColumnName,[cols,obj.ExtraColumnFromJoin]))
                obj.throwError("Wrong keyColumnName or readColumnName.")
            end
            conn = obj.connectDatabaseRead;
            if keyColumnName == "ID" || ~contains(obj.TableColumn(keyColumnName), "string")
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

        function t = readValueTwoKey(obj,keyColumnValue,keyColumnValue2,readColumnName,keyColumnName,keyColumnName2)
            % Read one or more columns filtered by a key column and values.
            %
            % When a single column is requested, a vector is returned instead of a table.
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
                keyColumnValue {mustBeVector(keyColumnValue)} %Key column1 values
                keyColumnValue2 {mustBeVector(keyColumnValue2)} %Key column2 values
                readColumnName string {mustBeVector(readColumnName)} %Columns you want to read
                keyColumnName (1,1) string  %Key column1 name
                keyColumnName2 (1,1) string = "ID" %Key column2 name (optional)
            end
            cols = obj.ColumnNameAll;
            if any(~ismember([keyColumnName,keyColumnName2],cols)) || any(~ismember(readColumnName,[cols,obj.ExtraColumnFromJoin]))
                obj.throwError("Wrong keyColumnName or readColumnName.")
            end
            conn = obj.connectDatabaseRead;
            if keyColumnName == "ID" || ~contains(obj.TableColumn(keyColumnName), "string")
                inList = "(" + join(string(keyColumnValue), ",") + ")";
            else
                vals = string(keyColumnValue);
                vals = replace(vals, "'", "''");
                inList = "('" + join(vals, "','") + "')";
            end

            if keyColumnName2 == "ID" || ~contains(obj.TableColumn(keyColumnName2), "string")
                inList2 = "(" + join(string(keyColumnValue2), ",") + ")";
            else
                vals = string(keyColumnValue2);
                vals = replace(vals, "'", "''");
                inList2 = "('" + join(vals, "','") + "')";
            end
            columnStr = join(readColumnName,",");

            sqlquery = "SELECT " + columnStr + " FROM " + obj.TableName +...
                " WHERE " + obj.TableName + "." + keyColumnName + " IN " + inList + ...
                " AND " + obj.TableName + "." + keyColumnName2 + " IN " + inList2 + ";";
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
                            % Parse numeric matrix strings to numeric arrays
                            t.(columnName(ii)) = arrayfun(@(x) str2num(x), t.(columnName(ii)), "UniformOutput", false);
                        case "logicalMatrix"
                            t.(columnName(ii)) = arrayfun(@(x) logical(str2num(x)), t.(columnName(ii)), "UniformOutput", false);
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

            % Convert json data
            jsonIdx = contains(columnType,["table","struct"]);
            if any(jsonIdx)
                for ii = find(jsonIdx)
                    if ~ismember(columnName(ii), presentVars)
                        continue
                    end
                    switch columnType(ii)
                        case "table"
                            t.(columnName(ii)) = arrayfun(@jsondecodeTable, t.(columnName(ii)), "UniformOutput", false);
                        case "struct"
                            t.(columnName(ii)) = arrayfun(@jsondecodeStruct, t.(columnName(ii)), "UniformOutput", false);
                    end
                end
            end

            % Delete ID if needed
            if IsHideSerial && ismember("ID",presentVars)
                t.ID = [];
            end

            % Remove cell and convert to struct if input is one-row
            if height(t) == 1
                t = table2struct(t);
            end
        end

        function throwError(obj,me)
            str = newline + "Error in " + obj.TableName + ":" + newline + ...
                me;
            error(str)
        end
    end

    methods (Abstract)
        defineSchema(obj)
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
if isempty(str)
    sz = size(str);
    sz(sz==0) = 1;
    str = repmat("None",sz);
    return
end
maskEmpty = ismissing(str) | str == "";
if any(maskEmpty(:))
    str(maskEmpty) = "None";
end

% Escape single and double quotes
str = replace(str, "'", "''");
str = replace(str, '"', '""');
end

function str = normalizeJson(s)
if isempty(s)
    str = "None";
else
    str = string(jsonencode(s));
end
end

function s = jsondecodeStruct(str)
if str == "None"
    s = struct.empty(0,1);
else
    s = jsondecode(str);
end
end

function s = jsondecodeTable(str)
if str == "None"
    s = table.empty(0,1);
else
    s = struct2table(jsondecode(str));
end
end
