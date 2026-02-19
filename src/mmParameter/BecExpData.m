classdef BecExpData < MmParameter

    properties
        
    end

    methods
        function obj = BecExpData()
            obj@MmParameter()
        end

        function defineSchema(obj)
            obj.TableColumn = dictionary(...
                "TrialID", "int64", ...
                "CloudCenter", "doubleMatrix" ...
                );

            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "TrialID", "1", ...
                "CloudCenter", "'[1,1]'" ...
                );

            % Define foreign key
            obj.ForeignKey = cell2table( ...
                { ...
                "BecExpSetting","TrialID","ID";...
                },...
                "VariableNames",["ParentTable","KeyChild","KeyParent"]);
        end

    end
end

