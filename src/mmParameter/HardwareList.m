classdef HardwareList < MmParameter
    %:class:`HardwareList` catalogs available hardware objects and their data folders.
    %
    % Maps a logical :attr:`Name` to a hardware :attr:`Type` and a device-specific
    % :attr:`DataPath` for storing logs/objects.

    properties
        
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
            p = HardwareSetting;
            p.deleteEntry(hwId,"HardwareID") % Delete the existing entries first
            s = t.Setting{1};
            s.HardwareID = repmat(hwId,height(s),1);
            p.writeEntry(s)
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
            p = HardwareSetting;
            p2 = WaveformListLibrary;
            setting = p.readSetting(id);
            hw = eval(hwPara.DeviceModel + "(hwPara.ResourceName,hwPara.Name)");
            hw.DataPath = hwPara.DataPath;
            for ii = 1:height(setting)
                if setting.Name(ii) == "WaveformListID"
                    hw.WaveformList{setting.ChannelNumber(ii)} = p2.loadEntry(setting.Value{ii});
                else
                    hw.(setting.Name(ii))(setting.ChannelNumber(ii)) = setting.Value{ii};
                end
            end
        end
    end
end

