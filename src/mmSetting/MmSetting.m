classdef MmSetting < handle
    %MMSETTING This class handles MuscleMuseum settings.
    %   Detailed explanation goes here
    
    properties (SetAccess=protected)
        TableColumn dictionary = dictionary("Name","string")
        DefaultEntry table
    end

    properties (Constant)
        DataBaseName = "mmSeting.db"
        DataTypeMapping = dictionary(...
            ["double","logical","string","doubleMatrix","logicalMatrix","stringMatrix"],...
            ["REAL","INTEGER","TEXT","TEXT","TEXT","TEXT"])
    end

    properties (Dependent)
        TableName (1,1) string
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
            dbName = fullfile(getHome,"Documents","MMUser","config",obj.DataBaseName);
            if ~isfile(dbName)
                conn = sqlite(dbName,"create");
                close(conn)
            end
        end

        function checkTable(obj)
            obj.checkDataBase
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlquery = "SELECT name FROM sqlite_master" + ...
                " WHERE type='table' AND name='" + obj.TableName + "';";
            if isempty(fetch(conn,sqlquery))
                columnName = obj.TableColumn.keys;
                columnTypeMapped = obj.DataTypeMapping(obj.TableColumn.values);
                sqlquery2 = [(columnName+" "),(columnTypeMapped+", ")].';
                sqlquery2 = sqlquery2(:);
                sqlquery2(end) = strrep(sqlquery2(end),", ","");
                sqlquery2 = "CREATE TABLE " + obj.TableName +...
                    "(" + join(sqlquery2) + ");";
                execute(conn,sqlquery2)
            end
            close(conn)
        end
        
        function writeRow(obj,t)
            if isempty(t)
                return
            end
            t = obj.validateInput(t);
            conn = sqlite(which(obj.DataBaseName),"connect");
            sqlwrite(conn,obj.TableName,t)
            close(conn)
        end

        function t = validateInput(obj,t)
            if ~isa(t,"table")
                if isa(t,"struct")
                    t = struct2table(t);
                else
                    error("Database input has to table or struct.")
                end
            end
            columnName = obj.TableColumn.keys.';
            columnType = obj.TableColumn.values.';
            tColumnName = string(t.Properties.VariableNames);
            if (numel(tColumnName) ~= numel(columnName)) || any(tColumnName ~= columnName)
                error("Input table variable names do not match the database table.")
            end
            tColumnType = string(arrayfun(@(x) class(t.(x)),tColumnName,'UniformOutput',false));
            matIdx = contains(columnType,"Matrix");
            if ~any(matIdx)
                if any(tColumnType ~= columnType)
                    error("Input table variable types do not match the database table.")
                end
            else
                if any(tColumnType(matIdx) ~= "cell")
                    error("Input table variable types do not match the database table." + ...
                        " The matrix elements have to be cell type.")
                end
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
                if any(tColumnType(~matIdx) ~= columnType(~matIdx))
                    error("Input table variable types do not match the database table.")
                end
            end
        end
    end
end

