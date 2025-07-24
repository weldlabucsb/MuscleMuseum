classdef radset < MmSetting
    %RAD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function obj = radset()
            %RAD Construct an instance of this class
            %   Detailed explanation goes here
            obj@MmSetting
            columnName = ["a","b","d","f","rd"];
            columnType = ["doubleMatrix","double","string","stringMatrix","logical"];
            defaultValue = ["[1,2]","1","""asdf""","""asdf,dddd""","1"];
            obj.TableColumn = dictionary(columnName,columnType);
            obj.DefaultValue = dictionary(columnName,defaultValue);
        end
    end
end

