classdef WaveformListLibrary < MmParameter
    %:class:`WaveformListLibrary` stores named :class:`WaveformList` presets.
    %
    % Each row defines a waveform list preset with sampling rate and list-level
    % behaviors such as concatenation and patching methods, and holds
    % :attr:`WaveformOrigin` IDs pointing into :class:`WaveformLibrary`.
    %
    % **Schema (columns, types, defaults):**
    %
    % .. list-table::
    %    :widths: 30 18 28
    %    :header-rows: 1
    %
    %    * - Column
    %      - Type
    %      - Default
    %    * - Name
    %      - string
    %      - DefaultWaveformList
    %    * - SamplingRate
    %      - double
    %      - 1000
    %    * - ConcatMethod
    %      - string
    %      - Sequential
    %    * - PatchMethod
    %      - string
    %      - Continue
    %    * - PatchConstant
    %      - double
    %      - 0
    %    * - IsTriggerAdvance
    %      - logical
    %      - 0
    %    * - NPeriodPerCycle
    %      - double
    %      - 10
    %    * - WaveformOrigin
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
        function obj = WaveformListLibrary()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "Name", "string", ...
                "SamplingRate", "double", ...
                "ConcatMethod", "string",...
                "PatchMethod", "string",...
                "PatchConstant", "double",...
                "IsTriggerAdvance", "logical",...
                "NPeriodPerCycle", "double",...
                "TransformFunction","string",...
                "WaveformOrigin","doubleMatrix"...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "Name", "'DefaultWaveformList'", ...
                "SamplingRate", "1000", ...
                "ConcatMethod", "'Sequential'",...
                "PatchMethod", "'Continue'",...
                "PatchConstant", "0",...
                "IsTriggerAdvance", "0",...
                "NPeriodPerCycle", "10",...
                "TransformFunction","'None'",...
                "WaveformOrigin","'[]'"...
                );
        end

        function wfl = loadEntry(obj,nameOrID)
            % Load a :class:`WaveformList` object from the database.
            %
            % Resolves by numeric ``ID`` or string ``Name`` and constructs a
            % :class:`WaveformList` with its :attr:`WaveformOrigin` items
            % instantiated from :class:`WaveformLibrary`. Remaining properties
            % are copied from the row.
            %
            % :param nameOrID: Row ID or logical name
            % :type nameOrID: double or string
            % :return: Loaded waveform list (empty if not found)
            % :rtype: :class:`WaveformList`
            if isnumeric(nameOrID)
                wflPara = obj.readEntry(nameOrID);
            else
                wflPara = obj.readEntry(nameOrID,"Name");
            end
            if isempty(wflPara)
                wfl = WaveformList.empty;
                return
            end
            % Read and load :attr:`WaveformOrigin` from :class:`WaveformLibrary`
            p = WaveformLibrary;
            wfo = arrayfun(@(x) p.loadEntry(x),wflPara.WaveformOrigin,'UniformOutput',false);
            wfl = WaveformList(wflPara.Name,waveformOrigin=wfo);
            
            % Read and load other WaveformList parameters
            paraList = obj.TableColumn.keys;
            paraList(ismember(paraList,["WaveformOrigin","Name"])) = [];
            for ii = 1:numel(paraList)
                wfl.(paraList(ii)) = wflPara.(paraList(ii));
            end
        end

        function wflID = saveEntry(obj,wfl)
            % Save a :class:`WaveformList` object into the database.
            %
            % Upserts the list row by ``Name`` and synchronizes
            % :attr:`WaveformOrigin` children in :class:`WaveformLibrary`.
            %
            % :param wfl: Waveform list to persist
            % :type wfl: :class:`WaveformList`
            % :return: Row ID of the waveform list
            % :rtype: double
            arguments
                obj
                wfl WaveformList
            end
            % Save parameter
            t = wfl.convert2Table;
            obj.updateEntry(t,"Name")
            wflID = obj.readValue(t.Name,"ID","Name");

            % Check WaveformOrigin
            wfo = obj.readValue(wflID,"WaveformOrigin");
            nwf = numel(wfl.WaveformOrigin);
            if nwf == 0
                obj.updateValue(wflID,"WaveformOrigin",{[]})
                return
            end

            % Update :class:`WaveformLibrary`
            p = WaveformLibrary;
            if ~isempty(wfo)
                p.deleteEntry(wfo)
            end
            id = zeros(1,nwf);
            for ii = 1:numel(wfl.WaveformOrigin)
                id(ii) = p.saveEntry(wfl.WaveformOrigin{ii},wflID);
            end
            obj.updateValue(wflID,"WaveformOrigin",{id});
        end

        function wflID = duplicateEntry(obj,keyColumnValue,name,keyColumnName)
            % Duplicate a row and its :attr:`WaveformOrigin` subtree.
            %
            % :param keyColumnValue: Source row key value
            % :type keyColumnValue: double
            % :param name: New ``Name`` for the duplicated list
            % :type name: string
            % :param keyColumnName: Key column name (default ``ID``)
            % :type keyColumnName: string, optional
            % :return: New row ID of the duplicated list
            % :rtype: double
            arguments
                obj
                keyColumnValue (1,1) %Key column value. Can be an array
                name string
                keyColumnName (1,1) string = "ID" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("The keyColumnName does not match any database table column name.")
            end

            % Duplicate the entry in :class:`WaveformListLibrary`
            s = obj.readEntry(keyColumnValue,keyColumnName,true);
            if ~isempty(name)
                s.(obj.FirstColumn) = name;
            end
            obj.writeEntry(s)

            % Check WaveformOrigin
            wflID = obj.getLastID;
            wfo = s.WaveformOrigin;

            % Write :attr:`WaveformOrigin` into :class:`WaveformLibrary`
            p = WaveformLibrary;
            wfID = zeros(1,numel(wfo));
            for ii = 1:numel(wfo)
                wfID(ii) = p.duplicateEntry(wfo(ii),wflID);
            end
            obj.updateValue(wflID,"WaveformOrigin",{wfID});
        end
    end
end

