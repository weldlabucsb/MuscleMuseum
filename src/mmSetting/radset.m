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
            obj.TableColumn = dictionary(["a","b","c"],["doubleMatrix","stringMatrix","logical"]);
        end
    end
end

