classdef HardwareAssociation < MmParameter
    %:class:`HardwareAssociation` binds trial presets to hardware setting rows.
    %
    % Each row links a :attr:`TrialID` (from :class:`BecExpSetting`) to a
    % :attr:`SettingID` (from :class:`HardwareSetting`), and optionally provides
    % a literal :attr:`DefaultValue` and/or a :attr:`VariableID` override. This
    % enables per-trial overrides of hardware settings.
    %
    % **Schema (columns, types, defaults):**
    %
    % .. list-table::
    %    :widths: 30 20 30
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %    * - TrialID
    %      - int64
    %      - 1
    %    * - SettingID
    %      - int64
    %      - 1
    %    * - DefaultValue
    %      - string
    %      - None
    %    * - VariableID
    %      - int64
    %      - 0
    %
    % **Foreign keys:**
    %
    % - ``SettingID`` → :class:`HardwareSetting` (``ID``)
    % - ``TrialID`` → :class:`BecExpSetting` (``ID``)
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
        function obj = HardwareAssociation()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "TrialID", "int64", ...
                "SettingID", "int64", ...
                "DefaultValue", "string", ... 
                "VariableID", "int64"...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "TrialID", "1", ...
                "SettingID", "1", ...
                "DefaultValue", "'None'", ... 
                "VariableID", "0"...
                );

            obj.IsFirstColumnUnique = false;
            % Define foreign key
            obj.ForeignKey = cell2table( ...
                { ...
                "HardwareSetting","SettingID","ID"; ...
                "BecExpSetting","TrialID","ID";...
                },...
                "VariableNames",["ParentTable","KeyChild","KeyParent"]);

            obj.UniqueConstraint = ["TrialID","SettingID"];
        end

    end
end

