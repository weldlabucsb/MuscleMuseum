classdef MmSetting < handle
    %MMSETTING This class handles MuscleMuseum settings.
    %   Detailed explanation goes here

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
    end

    properties (Dependent)
        TableName (1,1) string %Table name is consistent with the subclass name
    end

    methods
        function obj = MmSetting()
            %MMSETTING Construct an instance of this class
            %   Detailed explanation goes here
        end

        function tableName = get.TableName(obj)
            tableName = string(class(obj));
        end

        function checkDataBase(obj)
            % Check if database exists. If not, create it.
            dbName = fullfile(getHome,"Documents","MMUser","config",obj.DataBaseName);
            if ~isfile(dbName)
                conn = sqlite(dbName,"create");
                close(conn)
            end
        end

        function checkTable(obj)
            obj.checkDataBase
            conn = sqlite(which(obj.DataBaseName),"connect");
            columnName = obj.TableColumn.keys;
            columnTypeMapped = obj.DataTypeMapping(obj.TableColumn.values);
            sqlquery = "SELECT name FROM sqlite_master" + ...
                " WHERE type='table' AND name='" + obj.TableName + "';";

            %% Check if database table exists.
            if isempty(fetch(conn,sqlquery))
                %% If not, create it.
                sqlquery2 = [(columnName+" "),(columnTypeMapped+", ")].';
                sqlquery2 = sqlquery2(:);
                sqlquery2(end) = strrep(sqlquery2(end),", ","");
                sqlquery2 = "CREATE TABLE " + obj.TableName +...
                    "(" + join(sqlquery2) + ");";
                execute(conn,sqlquery2)
            else
                %% If the table exists, add missing columns
                sqlquery3 = 'SELECT name, type FROM pragma_table_info(''' + obj.TableName +  ''')';
                out = fetch(conn,sqlquery3);
                dbColumnName = out.name;
                dbColumnType = out.type;
                missingColumn = setdiff(columnName,dbColumnName);
                if ~isempty(missingColumn)
                    % Add missing columns
                    missingColumnType = obj.DataTypeMapping(obj.TableColumn(missingColumn));
                    for ii = 1:numel(missingColumn)
                        sqlquery4 = "ALTER TABLE " + obj.TableName +...
                            " ADD " + missingColumn(ii) + " " + missingColumnType(ii) + ";";
                        execute(conn,sqlquery4)
                        execute(conn,"UPDATE " + obj.TableName + " SET " + missingColumn(ii) + " = " + obj.DefaultValue(missingColumn(ii)))
                    end
                end

                %% Check mismatched column types or extra columns
                extraColumn = setdiff(dbColumnName,columnName);
                [existingColumn,dbIdx] = intersect(dbColumnName,columnName);
                if ~isempty(existingColumn)
                    existingColumnTypeTarget = obj.DataTypeMapping(obj.TableColumn(existingColumn));
                    existingDbColumnType = dbColumnType(dbIdx);
                    mismatchedColumnIdx = existingDbColumnType ~= existingColumnTypeTarget;
                else
                    mismatchedColumnIdx = false;
                end
                if ~isempty(extraColumn) || any(mismatchedColumnIdx)
                    % Recreate the table and copy data
                    execute(conn, 'PRAGMA foreign_keys = OFF;')
                    execute(conn, 'ALTER TABLE ' +  obj.TableName + ' RENAME TO TempTable;')
                    sqlquery2 = [(columnName+" "),(columnTypeMapped+", ")].';
                    sqlquery2 = sqlquery2(:);
                    sqlquery2(end) = strrep(sqlquery2(end),", ","");
                    sqlquery2 = "CREATE TABLE " + obj.TableName +...
                        "(" + join(sqlquery2) + ");";
                    execute(conn,sqlquery2)
                    columnStr = join(columnName,", ");
                    sqlquery5 = "INSERT INTO " + obj.TableName + " (" + columnStr + ") " + ...
                        "SELECT " + columnStr + " FROM TempTable;";
                    execute(conn,sqlquery5)
                    execute(conn, 'DROP TABLE TempTable;')
                    execute(conn, 'PRAGMA foreign_keys = ON;')
                end
            end
            close(conn)
        end

        function writeRow(obj,t)
            if isempty(t)
                return
            end
            t = obj.prepareInput(t);
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlwrite(conn,obj.TableName,t)
            close(conn)
        end

        function t = prepareInput(obj,t)
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
            conn = sqlite(which(obj.DataBaseName),"readonly");
            t = sqlread(conn,obj.TableName);
            t = obj.convertOutput(t);
            close(conn)
        end

        function t = readRow(obj,cond)

            t = convertOutput(obj,t);
        end

        function t = convertOutput(obj,t)
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

