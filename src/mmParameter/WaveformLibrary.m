classdef WaveformLibrary < MmParameter
    %:class:`VariableList` stores named scalar variables and expressions.
    %
    % Each row defines :attr:`Name`, numeric :attr:`Value`, a reference
    % :attr:`List` name, an :attr:`Equation` string and its evaluated
    % :attr:`EquationValue` for caching.

    properties

    end

    methods
        function obj = WaveformLibrary()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "WaveformListID ", "double", ...
                "Type", "string", ...
                "Property", "struct"...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "WaveformListID ", "0", ...
                "Type", "'ConstantWave'", ...
                "Property", "'None'"...
                );
        end
    end
end

