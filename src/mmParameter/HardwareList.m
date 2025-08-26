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

        function hwId = saveEntry(obj,hw)
            % Save a hardware object into the database

            % Save general parameter
            t = hw.convert2Table;
            obj.updateEntry(t,"Name")
            hwId = obj.readValue(t.Name,"ID","Name");

            % Save other parameters into HardwareParameter
            p = HardwareParameter;
            p.deleteEntry(hwId,"HardwareID") % Delete the existing parameters first
            para = t.Parameter;
            para.HardwareID = hwId;
            p.writeEntry(para)
        end
    end
end

