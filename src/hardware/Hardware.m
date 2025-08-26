classdef (Abstract) Hardware < handle & matlab.mixin.SetGetExactNames
    %:class:`Hardware` provides a common abstraction for controllable instruments.
    %
    % Encapsulates identity, resource naming, data type for uploads, and logging
    % of instrument objects via :meth:`saveObject`. Concrete subclasses implement model-specific control
    % (e.g., AWGs, scopes, cameras, phase locks).
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    awg = KeysightWaveformGenerator("TCPIP0::192.168.0.2::inst0::INSTR", name="AWG1");
    %    % use awg-specific APIs here
    %
    % **Notes:**
    %
    %     The default logging location is derived from ``Config.mat`` → ``ComputerConfig.HardwareLogOrigin``.
    %     Set ``isSaving=false`` to disable object logging.
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
        DisabledProperty string % Properties that are not implemented for specific models
    end

    properties(Hidden)
        DataPath string % Folder to save the object
    end

    methods
        function obj = Hardware(resourceName,name)
            % Construct a :class:`Hardware` object.
            %
            % :param resourceName: VISA/ethernet/COM resource identifier for the device.
            % :type resourceName: string
            % :param name: Short device nickname used for logging folder names.
            % :type name: string, optional
            % :param isSaving: Whether to save device snapshots to disk (default true).
            % :type isSaving: logical, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj.ResourceName = resourceName;
            obj.Name = name;
        end

        function t = convert2Table(obj)
            %% Get setable properties from the hw object
            mc = metaclass(obj);
            NameList = mc.PropertyList;
            NameList = NameList(~([NameList.Dependent] |...
                [NameList.Constant] |...
                [NameList.Hidden] |...
                [NameList.Transient] |...
                string({NameList.SetAccess}) == "protected" | ...
                string({NameList.SetAccess}) == "private"));
            NameList = string({NameList.Name});
            nProp = numel(NameList);
            DefaultValue = "";
            Type = "";
            ChannelNumber = 1;
            paraIdx = 1;
            Name = "";
            className = string(mc.SuperclassList(1).SuperclassList(1).Name);
            for ii = 1:nProp
                temp = obj.(NameList(ii));
                type = string(class(temp));
                for jj = 1:numel(temp)
                    ChannelNumber(paraIdx) = jj;
                    Name(paraIdx) = NameList(ii);
                    if type ~= "cell"
                        DefaultValue(paraIdx) = string(temp(jj));
                        Type(paraIdx) = type;
                    else
                        if className == "WaveformGenerator" && NameList(ii) == "WaveformList"
                            p = WaveformListLibrary;
                            Type(paraIdx) = "int64";
                            Name(paraIdx) = "WaveformListID";
                            if ~isempty(temp{jj})
                                name = temp{jj}.Name;
                                id = p.readValue(name,"ID","Name");
                                if ~isempty(id)
                                    DefaultValue(paraIdx) = string(id);
                                else
                                    DefaultValue(paraIdx) = "0";
                                end
                            else
                                DefaultValue(paraIdx) = "0";
                            end
                        else
                            if ~isempty(temp{jj})
                                DefaultValue(paraIdx) = temp{jj};
                            else
                                DefaultValue(paraIdx) = "None";
                            end
                            Type(paraIdx) = string(class(temp{jj}));
                        end
                    end
                    paraIdx = paraIdx + 1;
                end
            end
            ChannelNumber = ChannelNumber(:);
            Name = Name(:);
            Type = Type(:);
            DefaultValue = DefaultValue(:);
            Setting = {table(ChannelNumber,Name,Type,DefaultValue)};

            %% Get other parameters
            Type = className;
            DeviceModel = obj.Manufacturer + obj.Model;
            if ~isempty(obj.ResourceName)
                ResourceName = obj.ResourceName;
            else
                ResourceName = "None";
            end
            Name = obj.Name;
            t = table(Name,Type,DeviceModel,ResourceName,Setting);

        end
    end

    methods (Access = protected)
        function saveObject(obj)
            % Save a timestamped snapshot of the hardware object to :attr:`DataPath`.
            if isfolder(obj.DataPath)
                t = string(datetime('now','Format','yyyyMMddHHmmss'));
                save(fullfile(obj.DataPath,obj.Name + "_" + t),'obj')
            end
        end
    end
end

