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
                "DataPath", "string" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'DefaultWg'", ...
                "Type", "'Keysight33600A'", ...
                "DataPath", "'XXX'" ...
                );
        end
    end
end

