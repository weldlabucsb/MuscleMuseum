classdef HardwareSetting < MmParameter
    %:class:`HardwareSetting` stores per-hardware per-channel settings and bindings.
    %
    % Each row identifies a hardware device (:attr:`HardwareID`), a channel
    % (:attr:`ChannelNumber`), a setting :attr:`Name`, and its value. Values can
    % be provided either as a literal :attr:`DefaultValue` (stored as TEXT) or by
    % referencing a :class:`VariableList` entry via :attr:`VariableID`, in which
    % case the effective value will be resolved dynamically.
    %
    % **Schema (columns, types, defaults):**
    %
    % .. list-table::
    %    :widths: 28 18 28
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %    * - HardwareID
    %      - int64
    %      - 1
    %    * - ChannelNumber
    %      - int64
    %      - 1
    %    * - Name
    %      - string
    %      - Memory
    %    * - Type
    %      - string
    %      - double
    %    * - DefaultValue
    %      - string
    %      - 1000
    %    * - VariableID
    %      - int64
    %      - 0
    %
    % **Foreign keys:**
    %
    % - ``HardwareID`` → :class:`HardwareList` (``ID``)
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
    %      - false
    %    * - IsTriggerJoinOnRight
    %      - false
    %    * - IsTriggerJoinOnLeft
    %      - false

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
            obj.UniqueConstraint = ["HardwareID","ChannelNumber","Name"];
        end

        function updateSettingValue(obj,hwId,settingName,value,channelNumber)
            % Update a literal default value for a hardware setting.
            %
            % :param hwId: Hardware ID
            % :type hwId: double
            % :param settingName: Setting name (e.g., ``"SamplingRate"``)
            % :type settingName: string
            % :param value: New literal value (stored as TEXT)
            % :type value: string or numeric
            % :param channelNumber: Channel index (1-based)
            % :type channelNumber: double, optional
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
            % Bind a hardware setting to a variable.
            %
            % :param hwId: Hardware ID
            % :type hwId: double
            % :param settingName: Setting name
            % :type settingName: string
            % :param varNameOrId: Variable :attr:`ID` or variable :attr:`Name`
            % :type varNameOrId: double or string
            % :param channelNumber: Channel index (1-based)
            % :type channelNumber: double, optional
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
            % Read the bound variable ID for a hardware setting.
            %
            % :return: Variable ID (0 if not bound)
            % :rtype: double
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
        
        function value = readSettingValue(obj,hwId,settingName,channelNumber)
            % Read the literal default value for a hardware setting.
            %
            % :return: DefaultValue (TEXT); caller may cast based on type
            % :rtype: string
            arguments
                obj
                hwId (1,1)
                settingName string
                channelNumber = 1
            end

            % Read the value
            conn = obj.connectDatabase;
            sqlquery = "SELECT DefaultValue FROM " + obj.TableName + ...
                " WHERE HardwareID ="  + hwId + ...
                " AND ChannelNumber = " + channelNumber + ...
                " AND Name = '" + settingName + "'; ";
             value = fetch(conn, sqlquery);
             if ~isempty(value)
                 value = value.DefaultValue;
             else
                 value = 0;
             end
             close(conn)
        end

        
        function id = readSettingID(obj,hwId,settingName,channelNumber)
            % Read the row ID for a specific hardware setting and channel.
            %
            % :return: Row ID (0 if not found)
            % :rtype: double
            arguments
                obj
                hwId (1,1)
                settingName string
                channelNumber = 1
            end
            % Read the ID
            conn = obj.connectDatabase;
            sqlquery = "SELECT ID FROM " + obj.TableName + ...
                " WHERE HardwareID ="  + hwId + ...
                " AND ChannelNumber = " + channelNumber + ...
                " AND Name = '" + settingName + "'; ";
             id = fetch(conn, sqlquery);
             if ~isempty(id)
                 id = id.ID;
             else
                 id = 0;
             end
             close(conn)
        end

        function t = readSetting(obj,hwId)
            % Read effective values for all settings of a hardware device.
            %
            % Returns a table with columns ``Name``, ``ChannelNumber``,
            % ``VariableID``, ``Value`` where ``Value`` is resolved from
            % :class:`VariableList` when ``VariableID`` != 0, otherwise equals
            % ``DefaultValue`` cast to its declared type.
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

