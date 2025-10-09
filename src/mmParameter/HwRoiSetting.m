classdef HwRoiSetting < MmParameter
    %:class:`RoiSetting` stores rectangular ROIs and optional sub-ROI
    %grids. This one is used for HardwareROIs
    %
    % Columns define a ROI by bounds (:attr:`Y1`..:attr:`X2`), image size,
    % rotation :attr:`Angle`, and sub-ROI center/size/grid definitions.
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
    %      - defaultRoi
    %    * - Y1
    %      - double
    %      - 1
    %    * - Y2
    %      - double
    %      - 100
    %    * - X1
    %      - double
    %      - 1
    %    * - X2
    %      - double
    %      - 100
    %    * - ImageSizeY
    %      - double
    %      - 1080
    %    * - ImageSizeX
    %      - double
    %      - 1920
    %    * - Angle
    %      - double
    %      - 0
    %    * - SubRoiCenterSize
    %      - doubleMatrix
    %      - []
    %    * - SubRoiNRowColumn
    %      - doubleMatrix
    %      - []
    %    * - SubRoiSeparation
    %      - doubleMatrix
    %      - []
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
        function obj = HwRoiSetting()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "Y1", "double", ...
                "Y2", "double", ...
                "X1", "double", ...
                "X2", "double", ...
                "ImageSizeY", "double", ...
                "ImageSizeX", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'defaultRoi'", ...
                "Y1", "1", ...
                "Y2", "100", ...
                "X1", "1", ...
                "X2", "100", ...
                "ImageSizeY", "1080", ...
                "ImageSizeX", "1920" ...
                );
        end
    end
end

