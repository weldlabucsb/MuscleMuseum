classdef HardwareList < MmParameter
    %:class:`HardwareList` catalogs available hardware objects and their data folders.
    %
    % Maps a logical :attr:`Name` to :attr:`Type` and :attr:`DeviceModel`, plus a
    % device-specific :attr:`DataPath` and :attr:`ResourceName`. Use
    % :meth:`saveEntry` to persist a hardware object's parameters and per-channel
    % settings, and :meth:`loadEntry` to reconstruct the device from stored
    % entries. Per-channel settings are stored in :class:`HardwareSetting`.
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
    %    * - Name
    %      - string
    %      - DefaultWg
    %    * - Type
    %      - string
    %      - WaveformGenerator
    %    * - DataPath
    %      - string
    %      - XXX
    %    * - DeviceModel
    %      - string
    %      - Keysight33600A
    %    * - ResourceName
    %      - string
    %      - XXX
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
        HardwareSetting % :class:`HardwareSetting` accessor used to read/write per-device settings
        WaveformListLibrary % :class:`WaveformListLibrary` accessor used to load/save waveform lists
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
            % Save a hardware object into the database.
            %
            % Persists general hardware properties in this table, and upserts
            % per-channel settings into :class:`HardwareSetting`.
            %
            % :param hw: Hardware object to save (e.g., a scope, WG, phase lock)
            % :type hw: :class:`Hardware`
            % :param isSaveSettingOnly: If true, only upsert settings; skip general props
            % :type isSaveSettingOnly: logical, optional
            % :return: Row ID of the saved hardware entry
            % :rtype: double
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
            % Load a hardware object from the database.
            %
            % Resolves by numeric ``ID`` or string ``Name``, then constructs the
            % device using its :attr:`DeviceModel` and populates properties from
            % :class:`HardwareSetting` (including :attr:`WaveformList` if present).
            %
            % :param nameOrID: Hardware row ID or logical Name
            % :type nameOrID: double or string
            % :return: Instantiated hardware object populated from settings
            % :rtype: :class:`Hardware`
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
            % Update a hardware object in-memory from stored settings.
            %
            % Reads :class:`HardwareSetting` rows and applies them to the
            % provided object. Useful when settings were changed externally.
            %
            % :param nameOrID: Hardware row ID or logical Name
            % :type nameOrID: double or string
            % :param hw: Existing hardware object to update
            % :type hw: :class:`Hardware`
            % :return: Updated hardware object
            % :rtype: :class:`Hardware`
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

