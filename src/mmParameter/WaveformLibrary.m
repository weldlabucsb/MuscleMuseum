classdef WaveformLibrary < MmParameter
    %:class:`WaveformLibrary` stores serialized :class:`Waveform` objects and their parameters.
    %
    % Each row represents a waveform template associated with a
    % :attr:`WaveformListID`, the waveform :attr:`Type` (class name),
    % :attr:`SamplingRate`, JSON-encoded :attr:`Parameter` table describing
    % named parameters, and optional modulation links referencing entries in
    % :class:`WaveformListLibrary`.
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
    %    * - WaveformListID
    %      - int64
    %      - 1
    %    * - Type
    %      - string
    %      - ConstantWave
    %    * - SamplingRate
    %      - double
    %      - 1000
    %    * - Parameter
    %      - table
    %      - None
    %    * - AmplitudeModulation
    %      - double
    %      - 0
    %    * - FrequencyModulation
    %      - double
    %      - 0
    %    * - PhaseModulation
    %      - double
    %      - 0
    %
    % **Foreign keys:**
    %
    % - ``WaveformListID`` → :class:`WaveformListLibrary` (``ID``)
    %
    % **Join conditions:**
    %
    % (none; view ``WaveformParameters`` is created for JSON expansion)
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
        function obj = WaveformLibrary()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "WaveformListID", "int64", ...
                "Type", "string", ...
                "SamplingRate", "double", ...
                "Parameter", "table",...
                "AmplitudeModulation", "double", ...
                "FrequencyModulation", "double", ...
                "PhaseModulation", "double" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "WaveformListID", "1", ...
                "Type", "'ConstantWave'", ...
                "SamplingRate", "1000", ...
                "Parameter", "'None'",...
                "AmplitudeModulation", "0", ...
                "FrequencyModulation", "0", ...
                "PhaseModulation", "0" ...
                );

            % Define foreign key
            obj.ForeignKey = cell2table( ...
                {"WaveformListLibrary","WaveformListID","ID"},...
                "VariableNames",["ParentTable","KeyChild","KeyParent"]);
            obj.IsFirstColumnUnique = false;
        end

        function createView(obj)
            % Create the SQLite view used to expand JSON parameters per row.
            %
            % Creates/ensures the ``WaveformParameters`` view which flattens the
            % JSON-encoded :attr:`Parameter` column into a rowset with columns
            % ``ID`` (pointing to this table), ``Name``, ``VariableID``, and
            % ``DefaultValue``. Idempotent: only creates the view if it does not
            % already exist. Used by :meth:`readParameter` to join with
            % :class:`VariableList` and resolve current values.
            conn = obj.connectDatabase;
            viewName = "WaveformParameters";
            sql = "SELECT name FROM sqlite_master WHERE type='view' AND name='" + viewName + "';";
            viewDb = fetch(conn,sql);
            if isempty(viewDb)
                sqlquery = "CREATE VIEW " + viewName + " AS" + newline + ...
                    "SELECT" + newline + ...
                    "   lib.ID," + newline + ...
                    "   json.value ->> 'Name' AS Name," + newline + ...
                    "   json.value ->> 'VariableID' AS VariableID," + newline + ...
                    "   CAST(json.value ->> 'DefaultValue' AS REAL) AS DefaultValue" + newline + ...
                    "FROM WaveformLibrary AS lib," + newline + ...
                    "   json_each(lib.Parameter) AS json;";
                execute(conn,sqlquery)
                close(conn)
            end
        end

        function s = readParameter(obj,id)
            % Read waveform parameters with variable resolution.
            %
            % Returns a struct combining base waveform fields with a parameter
            % table where variable links are resolved against :class:`VariableList`.
            %
            % :param id: Row ID
            % :type id: double
            % :return: Struct with fields ``Type``, ``SamplingRate``, modulation
            %          IDs, and a ``Parameter`` table containing columns
            %          ``Name``, ``DefaultValue``, ``VariableID``, ``Value``.
            % :rtype: struct
            conn = obj.connectDatabaseRead;
            %% Read general waveform properties
            sqlquery = "SELECT" + ...
                " ID," + ...
                " Type," + ...
                " SamplingRate," + ...
                " AmplitudeModulation," + ...
                " FrequencyModulation," + ...
                " PhaseModulation" + ...
                " FROM " + obj.TableName  + ...
                " WHERE " + obj.TableName + ".ID = " + id + ";";
            s = table2struct(fetch(conn,sqlquery));

            %% Read waveform parameters and perform join
            sqlquery = "SELECT" + newline + ...
                "   wp.Name," + newline + ...
                "   wp.DefaultValue," + newline + ...
                "   wp.VariableID," + newline + ...
                "    COALESCE(vl.CurrentValue, wp.DefaultValue) AS Value" + newline + ...
                "FROM WaveformParameters AS wp" + newline + ...
                "LEFT JOIN VariableList AS vl" + newline + ...
                "   ON wp.VariableID = vl.ID" + newline + ...
                "WHERE wp.ID = " + id + ";";
            s.Parameter = fetch(conn,sqlquery);

            %% Build the scan dictionary
            name = s.Parameter.Name;
            varID = s.Parameter.VariableID;
            scannedParameter = varID ~= 0;
            if any(scannedParameter)
                s.Scan = dictionary(name(scannedParameter),varID(scannedParameter));
            else
                s.Scan = dictionary([],[]);
            end
            close(conn)
        end

        function wf = loadEntry(obj,id)
            % Instantiate a :class:`Waveform` object from a database row.
            %
            % Calls :meth:`readParameter` and constructs the waveform class with
            % parameter assignment, resolving optional modulation lists from
            % :class:`WaveformListLibrary`.
            %
            % :param id: Row ID to load
            % :type id: double
            % :return: Waveform instance populated from the database
            % :rtype: :class:`Waveform`
            s = obj.readParameter(id);
            wf = eval(s.Type);
            wf.SamplingRate = s.SamplingRate;
            wf.Scan = s.Scan;
            for ii = 1:height(s.Parameter)
                wf.(s.Parameter.Name(ii)) = s.Parameter.Value(ii);
            end
            if isa(wf,"ModulatedWaveform")
                modList = ["AmplitudeModulation","FrequencyModulation","PhaseModulation"];
                p = WaveformListLibrary;
                for ii = 1:numel(modList)
                    if s.(modList(ii)) ~= 0
                        wf.(modList(ii)) = p.loadEntry(s.(modList(ii)));
                    end
                end
            end
        end

        function wfID = saveEntry(obj,wf,wflID,wfID)
            % Save a :class:`Waveform` object into the database.
            arguments
                obj
                wf
                wflID
                wfID = []
            end
            t = wf.convert2Table;
            t.WaveformListID = wflID;
            if isempty(wfID)
                obj.writeEntry(t)
                wfID = obj.getLastID;
            else
                t.ID = wfID;
                obj.updateEntry(t)
            end
        end

        function wflID = checkVariableBound(obj,varID)
            % Return dependent waveform lists for a given variable ID.
            %
            % Scans ``Parameter`` JSON for occurrences of ``VariableID`` and
            % returns unique :attr:`WaveformListID` values that reference it.
            %
            % :param varID: Target variable ID
            % :type varID: double
            % :return: Dependent ``WaveformListID`` values
            % :rtype: double or []
            conn = obj.connectDatabaseRead;
            sqlquery = "SELECT" + newline + ...
                "   wl.WaveformListID"  + newline + ...
                "FROM WaveformLibrary AS wl, " + newline + ...
                "   json_each(wl.Parameter) AS json" + newline + ...
                "WHERE json.value ->> 'VariableID' = " + varID + newline + ...
                "GROUP BY wl.WaveformListID;";
            t = fetch(conn,sqlquery);
            if isempty(t)
                wflID = [];
            else
                wflID = unique(t.WaveformListID);
            end
            close(conn)
        end
    end
end

