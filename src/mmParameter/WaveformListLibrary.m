classdef WaveformListLibrary < MmParameter
    %:class:`VariableList` stores named scalar variables and expressions.
    %
    % Each row defines :attr:`Name`, numeric :attr:`Value`, a reference
    % :attr:`List` name, an :attr:`Equation` string and its evaluated
    % :attr:`EquationValue` for caching.

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
                "WaveformOrigin","'[]'"...
                );
        end

        function wfl = loadEntry(obj,nameOrID)
            % Load a WaveformList object from the database
            if isnumeric(nameOrID)
                wflPara = obj.readEntry(nameOrID);
            else
                wflPara = obj.readEntry(nameOrID,"Name");
            end
            if isempty(wflPara)
                wfl = WaveformList.empty;
                return
            end
            % Read and load WavformOrigin fomr WaveformLibrary
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
            % Save a WaveformList object into the database
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

            % Update WaveformLibrary
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
            arguments
                obj
                keyColumnValue (1,1) %Key column value. Can be an array
                name string
                keyColumnName (1,1) string = "ID" %Key column name (optional)
            end
            if ~ismember(keyColumnName,obj.ColumnNameAll)
                obj.throwError("The keyColumnName does not match any database table column name.")
            end

            % Duplicate the entry in WaveformListLibrary
            s = obj.readEntry(keyColumnValue,keyColumnName,true);
            if ~isempty(name)
                s.(obj.FirstColumn) = name;
            end
            obj.writeEntry(s)

            % Check WaveformOrigin
            wflID = obj.getLastID;
            wfo = s.WaveformOrigin;

            % Write WaveformOrigin into WaveformLibrary
            p = WaveformLibrary;
            wfID = zeros(1,numel(wfo));
            for ii = 1:numel(wfo)
                wfID(ii) = p.duplicateEntry(wfo(ii),wflID);
            end
            obj.updateValue(wflID,"WaveformOrigin",{wfID});
        end
    end
end

