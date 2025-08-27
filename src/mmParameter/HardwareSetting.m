classdef HardwareSetting < MmParameter
    %:class:`HardwareList` catalogs available hardware objects and their data folders.
    %
    % Maps a logical :attr:`Name` to a hardware :attr:`Type` and a device-specific
    % :attr:`DataPath` for storing logs/objects.

    properties

    end

    methods
        function obj = HardwareSetting()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "HardwareID", "int64", ...
                "ChannelNumber", "int64", ...
                "Name", "string", ...
                "Type", "string", ...
                "DefaultValue", "string", ... 
                "VariableID", "int64"...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "HardwareID", "1", ...
                "ChannelNumber", "1", ...
                "Name", "'Memory'", ...
                "Type", "double", ...
                "DefaultValue", "'1000'", ... 
                "VariableID", "0"...
                );

            obj.IsFirstColumnUnique = false;
            % Define foreign key
            obj.ForeignKey = cell2table( ...
                {"HardwareList","HardwareID","ID"},...
                "VariableNames",["ParentTable","KeyChild","KeyParent"]);
        end

        function updateSettingValue(obj,hwId,settingName,value,channelNumber)
            arguments
                obj
                hwId (1,1)
                settingName string
                value
                channelNumber = 1
            end

            % Update the values
            conn = obj.connectDatabase;
            sqlquery = "UPDATE " + obj.TableName + " SET DefaultValue = '" + value + "'" + ...
                " WHERE HardwareID ="  + hwId + ...
                " AND ChannelNumber = " + channelNumber + ...
                " AND Name = '" + settingName + "'; ";
            for ii = 1:numel(sqlquery)
                execute(conn, sqlquery(ii));
            end
            close(conn)
        end

        function updateSettingVariable(obj,hwId,settingName,varNameOrId,channelNumber)
            arguments
                obj
                hwId (1,1)
                settingName string
                varNameOrId
                channelNumber = 1
            end

            if isnumeric(varNameOrId)
                varID = string(varNameOrId);
            else
                p2 = VariableList;
                varID = p2.readValue(varNameOrId,"ID","Name");
                if isempty(varID)
                    varID = 0;
                end
            end

            % Update the values
            conn = obj.connectDatabase;
            sqlquery = "UPDATE " + obj.TableName + " SET VariableID = '" + varID + "'" + ...
                " WHERE HardwareID ="  + hwId + ...
                " AND ChannelNumber = " + channelNumber + ...
                " AND Name = '" + settingName + "'; ";
            for ii = 1:numel(sqlquery)
                execute(conn, sqlquery(ii));
            end
            close(conn)
        end
    
        function varId = readSettingVariable(obj,hwId,settingName,channelNumber)
            arguments
                obj
                hwId (1,1)
                settingName string
                channelNumber = 1
            end

            % Read the variable
            conn = obj.connectDatabase;
            sqlquery = "SELECT VariableID FROM " + obj.TableName + ...
                " WHERE HardwareID ="  + hwId + ...
                " AND ChannelNumber = " + channelNumber + ...
                " AND Name = '" + settingName + "'; ";
             varId = fetch(conn, sqlquery);
             if ~isempty(varId)
                 varId = varId.VariableID;
             else
                 varId = 0;
             end
             close(conn)
        end

        function t = readSetting(obj,hwId)
            sqlquery = "SELECT" + newline + ...
                "dp.Name," + newline + ...
                "dp.Type," + newline + ...
                "dp.ChannelNumber," + newline + ...
                "dp.VariableID," + newline + ...
                "CASE" + newline + ...
                "    WHEN dp.VariableID = 0 THEN dp.DefaultValue" + newline + ...
                "    ELSE vl.CurrentValue" + newline + ...
                "END AS Value" + newline + ...
                "FROM " + obj.TableName + " AS dp" + newline + ...
                "LEFT JOIN VariableList AS vl" + newline + ...
                "  ON dp.VariableID = vl.ID" + newline + ...
                "WHERE dp.HardwareID = " + hwId + ";";
            conn = obj.connectDatabaseRead;
            t = fetch(conn,sqlquery);
            type = t.Type;
            value = t.Value;
            value = arrayfun(@typeCast,type,value,"UniformOutput",false);
            t.Value = value;
            t.Type = [];
            close(conn)
            function val = typeCast(ty,val)
                switch ty
                    case "double"
                        val = double(val);
                    case "logical"
                        val = str2num(val);
                    case "int64"
                        val = int64(double(val));
                end
            end
        end
   
    end
end

