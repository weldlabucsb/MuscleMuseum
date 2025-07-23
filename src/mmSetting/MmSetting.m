classdef MmSetting < handle
    %MMSETTING This class handles MuscleMuseum settings.
    %   Detailed explanation goes here
    
    properties (SetAccess=protected)
        TableName (1,1) string
        TableField dictionary
    end

    properties (Constant)
        DataBaseName = "mmSeting"
    end
    
    methods
        function obj = MmSetting()
            %MMSETTING Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end

        function checkDataBase(obj)
            dbPath = fullfile(getHome,"Documents","MMUser","config","mmSeting.db");
            if ~isfile(dbPath)
                
            end
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

