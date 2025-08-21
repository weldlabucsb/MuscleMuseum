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
                "NCycle", "double",...
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
                "NCycle", "10",...
                "WaveformOrigin","'[]'"...
                );
        end

        function wfl = loadEntry(obj,nameOrID)
            if isnumeric(nameOrID)
                wflPara = obj.readEntry(nameOrID);
            else
                wflPara = obj.readEntry(nameOrID,"Name");
            end
            if isempty(wflPara)
                wfl = WaveformList.empty;
                return
            end
            p = WaveformLibrary;
            wfo = arrayfun(@(x) p.loadEntry(x),wflPara.WaveformOrigin,'UniformOutput',false);
            wfl = WaveformList(wflPara.Name,waveformOrigin=wfo);
            paraList = obj.TableColumn.keys;
            paraList(ismember(paraList,["WaveformOrigin","Name"])) = [];
            for ii = 1:numel(paraList)
                wfl.(paraList(ii)) = wflPara.(paraList(ii));
            end
        end
    end
end

