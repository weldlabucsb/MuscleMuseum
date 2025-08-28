classdef HardwareList < MmParameter
    %:class:`HardwareList` catalogs available hardware objects and their data folders.
    %
    % Maps a logical :attr:`Name` to a hardware :attr:`Type` and a device-specific
    % :attr:`DataPath` for storing logs/objects.

    properties
        HardwareSetting
        WaveformListLibrary
    end

    methods
        function obj = HardwareList()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "Type", "string", ...
                "DataPath", "string", ...
                "DeviceModel", "string", ...
                "ResourceName", "string" ...     
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'DefaultWg'", ...
                "Type", "'WaveformGenerator'", ...
                "DataPath", "'XXX'", ...
                "DeviceModel", "'Keysight33600A'", ...
                "ResourceName", "'XXX'" ...     
                );
            obj.HardwareSetting = HardwareSetting;
            obj.WaveformListLibrary = WaveformListLibrary;
        end

        function hwId = saveEntry(obj,hw,isSaveSettingOnly)
            % Save a hardware object into the database
            arguments
                obj
                hw
                isSaveSettingOnly logical = false
            end

            % Save general parameter
            t = hw.convert2Table;
            if ~isSaveSettingOnly
                obj.updateEntry(t,"Name")
            end
            hwId = obj.readValue(t.Name,"ID","Name");

            % Save settings into HardwareSetting
            p = obj.HardwareSetting;
            s = t.Setting{1};
            if isempty(s)
                return
            end
            s.HardwareID = repmat(hwId,height(s),1);

            % Perform upsert
            conn = obj.connectDatabase;
            sqlquery = "INSERT INTO " + p.TableName + ...
                " (HardwareID, ChannelNumber, Name, Type, DefaultValue)" + newline + ...
                "VALUES (" + ...
                s.HardwareID + "," + ...
                s.ChannelNumber + "," + ...
                "'" + s.Name + "'," + ...
                "'" + s.Type + "'," + ...
                "'" + s.DefaultValue + "'" + ...
                ")" + newline + ...
                "ON CONFLICT (HardwareID, ChannelNumber, Name)" + newline + ...
                "DO UPDATE SET DefaultValue = excluded.DefaultValue;";
            for ii = 1:numel(sqlquery)
                execute(conn,sqlquery(ii))
            end
            close(conn)
        end
    
        function hw = loadEntry(obj,nameOrID)
            % Load a Hardware object from the database
            if isnumeric(nameOrID)
                hwPara = obj.readEntry(nameOrID);
                id = nameOrID;
            else
                hwPara = obj.readEntry(nameOrID,"Name");
                id = obj.readValue(nameOrID,"ID","Name");
            end
            if isempty(hwPara)
                hw = [];
                return
            end
            p = obj.HardwareSetting;
            p2 = obj.WaveformListLibrary;
            setting = p.readSetting(id);
            hw = eval(hwPara.DeviceModel + "(hwPara.ResourceName,hwPara.Name)");
            hw.DataPath = hwPara.DataPath;
            for ii = 1:height(setting)
                if setting.Name(ii) == "WaveformList"
                    hw.WaveformList{setting.ChannelNumber(ii)} = p2.loadEntry(setting.Value{ii});
                else
                    hw.(setting.Name(ii))(setting.ChannelNumber(ii)) = setting.Value{ii};
                end
            end
        end
        
        function hw = updateHardware(obj,nameOrID,hw)
            % Update a Hardware object
            if isnumeric(nameOrID)
                id = nameOrID;
            else
                id = obj.readValue(nameOrID,"ID","Name");
            end
            p = obj.HardwareSetting;
            p2 = obj.WaveformListLibrary;
            setting = p.readSetting(id);
            for ii = 1:height(setting)
                if setting.Name(ii) == "WaveformList"
                    hw.WaveformList{setting.ChannelNumber(ii)} = p2.loadEntry(setting.Value{ii});
                else
                    hw.(setting.Name(ii))(setting.ChannelNumber(ii)) = setting.Value{ii};
                end
            end
        end
    end
end

