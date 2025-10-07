classdef AcquisitionSetting < MmParameter
    %:class:`AcquisitionSetting` stores per-camera acquisition configuration.
    %
    % Defines camera identity and acquisition-related parameters such as
    % :attr:`DeviceModel`, :attr:`DeviceID`, :attr:`SerialNumber`,
    % :attr:`ExposureTime` [s], bad pixel rows (:attr:`BadRow`), optical
    % :attr:`Magnification`, and system :attr:`Transmission` (unitless).
    %
    % The schema is declared in :meth:`defineSchema` using
    % :attr:`TableColumn` and :attr:`DefaultValue`. Use
    % :meth:`MmParameter.checkTable` to create/migrate the table and
    % :meth:`MmParameter.readTable`/:meth:`MmParameter.updateTable` to load/save.
    %
    % **Schema (columns, types, defaults, default entries):**
    %
    % .. list-table::
    %    :widths: 24 18 24 34
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %      - DefaultEntry values
    %    * - Name
    %      - string
    %      - DefaultPcoEdge5p5
    %      - DefaultPcoEdge5p5; DefaultBaslerAcA1920_25um
    %    * - DeviceModel
    %      - string
    %      - PcoEdge5p5
    %      - PcoEdge5p5; BaslerAcA1920_25um
    %    * - DeviceID
    %      - double
    %      - 0
    %      - 0; 1
    %    * - SerialNumber
    %      - double
    %      - 0
    %      - 0; 0
    %    * - ExposureTime
    %      - double
    %      - 3e-5
    %      - 3e-5; 3e-5
    %    * - BadRow
    %      - doubleMatrix
    %      - []
    %      - []; []
    %    * - Magnification
    %      - double
    %      - 1
    %      - 1; 1
    %    * - Transmission
    %      - double
    %      - 1
    %      - 1; 1
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

    end

    methods
        function obj = AcquisitionSetting()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "DeviceModel", "string", ...
                "DeviceID", "double", ...
                "SerialNumber", "double", ...
                "ExposureTime", "double", ...
                "BadRow", "doubleMatrix", ...
                "Magnification", "double", ...
                "Transmission", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'DefaultPcoEdge5p5'", ...
                "DeviceModel", "'PcoEdge5p5'", ...
                "DeviceID", "0", ...
                "SerialNumber", "0", ...
                "ExposureTime", "0.00003", ...
                "BadRow", "'[]'", ...
                "Magnification", "1", ...
                "Transmission", "1" ...
                );

            % Define default entries for initial table setup in :attr:`DefaultEntry`
            obj.DefaultEntry = table(...
                ["DefaultPcoEdge5p5";"DefaultBaslerAcA1920_25um"], ...
                ["PcoEdge5p5";"BaslerAcA1920_25um"], ...
                [0;1], ...
                [0;0], ...
                [3e-5;3e-5], ...
                {[];[]}, ...
                [1;1], ...
                [1;1], ...
                'VariableNames', [...
                "Name", ...
                "DeviceModel", ...
                "DeviceID", ...
                "SerialNumber", ...
                "ExposureTime", ...
                "BadRow", ...
                "Magnification", ...
                "Transmission" ...
                ] ...
                );
        end

        function acqObj = loadEntry(obj,nameOrID)
            % Instantiate a camera object from a stored entry.
            %
            % Resolves an entry by numeric ``ID`` or by ``Name`` and constructs
            % the device object using its :attr:`DeviceModel` with
            % ``feval(DeviceModel, Name)``.
            %
            % :param nameOrID: Entry identifier (numeric ``ID`` or string ``Name``)
            % :type nameOrID: double or string
            % :return: Constructed camera device object
            % :rtype: :class:`Acquisition`
            if isnumeric(nameOrID)
                acqConfig = obj.readEntry(nameOrID);
            else
                acqConfig = obj.readEntry(nameOrID,"Name");
            end
            acqObj = feval(acqConfig.DeviceModel,acqConfig.Name);
        end
        
    end
end

