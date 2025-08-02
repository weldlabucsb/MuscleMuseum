classdef (Abstract) Hardware < handle & matlab.mixin.SetGetExactNames
    %This class provides generalized parameter and functions for
    %hardware components that may be interfaced with MM. Most of these
    %properties are specific to AWG controls.
    %Properties:
    %
    %   Name: Nickname of device
    %   Manufacturer: Manufacturer of device
    %   Model: Model number
    %   Memory: Number of sample points that can be stored
    %   NChannel: Number of channels in devices
    %   ResourceName: Interfaces (like VISA) require a resource name to
    %   identify device (such as IP address or COM channel)
    %   DataType: classification of type of data used to upload
    %   waveform. Defaults to uint8.
    %   ParentPath: Folder retrieved from Config.mat
    %   DataPath: Folder to save all log object for this device, subfolder of ParentPath
    %   DisabledProperty: Properties not implemented for specific
    %   models
    %
    %Methods:
    %
    %   Hardware(resourceName, name, isSaving):
    %       creation method that saves the resourcename for ID, name,
    %       and logic for isSaving to determine whether and where to save log files. Also gathers parameters from
    %       Config.mat under ComputerConfig to determine where to save
    %       logs for 
    %   saveObject(obj)
    %       saves the object as a log file with name of device and time of
    %       generation.

    properties(SetAccess = protected)
        Name string % Nickname of the device
        Manufacturer string % Manufacturer of the device
        Model string % Model number
        Memory double % How many sample points the device can store
        NChannel double % How many channels the device has
        ResourceName string % Interfaces (like VISA) require a resource name to identify the device
        DataType string {mustBeMember(DataType,{'uint8','double'})}= "uint8"
        ParentPath string
        DataPath string % Folder to save the object
        DisabledProperty string % Properties that are not implemented for specific models
    end

    methods
        function obj = Hardware(resourceName,name,isSaving)
            arguments
                resourceName string
                name string = string.empty
                isSaving logical = true
            end
            obj.ResourceName = resourceName;
            obj.Name = name;

            % Set logging folder
            if isSaving
                load("Config.mat","ComputerConfig")
                obj.ParentPath = ComputerConfig.HardwareLogOrigin;
                if isfolder(obj.ParentPath)
                    obj.DataPath = fullfile(obj.ParentPath,name);
                    createFolder(obj.DataPath);
                else
                    warning("Can not find the hardware log folder. Check your setConfig")
                end
            end
        end
    end

    methods (Access = protected)
        function saveObject(obj)
            if isfolder(obj.DataPath)
                t = string(datetime('now','Format','yyyyMMddHHmmss'));
                save(fullfile(obj.DataPath,obj.Name + "_" + t),'obj')
            end
        end
    end
end

