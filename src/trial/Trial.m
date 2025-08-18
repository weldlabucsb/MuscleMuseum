classdef (Abstract) Trial < handle & matlab.mixin.SetGetExactNames & dynamicprops
    %:class:`Trial` is an abstract base class for orchestrating experiments/simulations.
    %
    % Provides lifecycle management for a single run series: configuration loading,
    % data folder setup, database logging (writer/reader), serial numbering, optional
    % GUI integration, and file system watching to trigger analysis.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    % Constructing a concrete trial
    %    t = MyConcreteTrial("Test", "MyConfigName");
    %    t.update();  % persist object and DB
    %
    % **Events:**
    %
    %     NewRunFinished : event
    %         Emitted when a new data file group has been detected and completed.
    %
    % **Notes:**
    %
    %     Subclasses must implement :meth:`writeDatabase`, :meth:`updateDatabase`,
    %     :meth:`setFolder`, and :meth:`setConfigProperty`.
    properties
        Description string = "This is a test trial."
        NCompletedRun int32 = 0
        NRun int32 = 1
        ScannedParameter string = "dummy"  
        ScannedParameterUnit string = "V"  
        ScannedParameter2 string = "None"  
        ScannedParameterUnit2 string = "None"  
        Is2dScan logical = false
    end

    properties (SetAccess = private)
        DateTime datetime % The date and time when the experiment/simulation is done.
    end

    properties (SetAccess = protected)
        Name string
        DataPath string = "."
        ObjectPath string
        SerialNumber int32
    end

    properties (Dependent)
        IsCompeted logical
        Is2DScan logical  % Computed property based on ScannedParameter dimensions
    end

    properties (SetAccess = protected, Hidden)
        ParentPath {mustBeFolder} = "."
        IsAutoDelete logical = false
        DatabaseName string
        DatabaseTableName string
        DataPrefix string = "run"
        DataFormat string = ".mat"
        DatePath string
        TrialPath string
        DataAnalysisPath string
        DataGroupSize uint32 = 1
        TrialIndex uint32 = 1
        ControlAppName string
    end

    properties (SetAccess = protected, Hidden, Transient)
        Reader database.postgre.connection
        Writer database.postgre.connection
        FileSystemWatcher
        Watcher event.listener
        Analyzer event.listener
        ControlApp
    end

    properties (Hidden,Transient)
        TempData = []
        TempDataPath string
    end

    properties (Hidden)
        ConfigParameter struct
    end

    methods
        function obj = Trial(trialName,config)
            % Construct a :class:`Trial` object.
            %
            % :param trialName: Alphanumeric name for the trial type.
            % :type trialName: string
            % :param config: Configuration identifier or data. If string, loads from ``Config.mat``.
            % :type config: string | table | struct
            %
            % **Raises:**
            %
            %     :class:`error`
            %         If ``trialName`` is not alphanumeric or configuration cannot be found.
            arguments
                trialName string
                config
            end

            %% Check if the input trialName is alphanum
            if isAlphaNum(trialName)
                obj.Name = trialName;
            else
                error('Trial name must only have numbers and alphabetic characters.')
            end

            %% Check the class of [config] and assign configuration properties
            if isstruct(config)
                obj.ConfigParameter = config;
            elseif istable(config)
                obj.ConfigParameter = table2struct(config);
            elseif isstring(config)
                % Load the configuration from file
                try
                    p = eval(config);
                    configTable = p.readTable;
                catch
                    error("Can not find the configuration table in [mmParameter.db]. Try running the [setConfig.m] and [checkSetting].")
                end

                % Set the configuration parameters
                if ismember(trialName,configTable.TrialName)
                    obj.ConfigParameter = table2struct(configTable(configTable.TrialName==trialName,:));      
                elseif find(configTable.TrialName=="Test")
                    warning("Can not find the configuration for TrialName: " + trialName +...
                        ". Loaded the [Test] trial configuration instead.")
                    obj.ConfigParameter = table2struct(configTable(configTable.TrialName=="Test",:));
                else
                    error("Can not find the configuration for TrialName: " + trialName +...
                        ". No [Test] trial type defined either. Check your configuration file.")
                end
            else
                error("Input type for [config] has to be a string, a table, or a structure.")
            end
            obj.setConfigProperty(obj.ConfigParameter);

            %% Set the control app
            if ~isempty(obj.ControlAppName)
                obj.ControlApp = get(findall(0, 'Tag', obj.ControlAppName), 'RunningAppInstance');
            end
            obj.displayLog("Constructing the object.")

            %% Set the folders
            obj.displayLog("Setting up folders.")
            obj.Writer = createWriter(obj.DatabaseName); %Create writer type database connection
            obj.DateTime = datetime;
            obj.setFolder %Create folders for data storage

            %% Write initial information into the database, then get the serial number generated by the database
            obj.displayLog("Creating a database entry.")
            obj.writeDatabase;
            sqlQuery = "SELECT last_value FROM " + "public."""+obj.DatabaseTableName+"_SerialNumber_seq"";";
            data = pgFetch(obj.Writer,sqlQuery);
            obj.SerialNumber = data.last_value;

        end

        function updateObject(obj)
            % Save the current object to :attr:`ObjectPath`.
            obj.displayLog("Updating the object file.")
            save(obj.ObjectPath,'obj')
        end

        function update(obj)
            % Persist object changes and synchronize the database record.
            %
            % Calls :meth:`updateObject` and :meth:`updateDatabase`, and writes a
            % short description file into :attr:`DataPath`.
            obj.updateObject
            obj.updateDatabase

            fid = fopen(fullfile(obj.DataPath, "description.txt"), 'wt' );
            fprintf(fid,'\n%s',obj.Description, strcat('Trial #', num2str(obj.SerialNumber)));
            fclose(fid);
        end

        function displayLog(obj,str,logType)
            % Display a log message, routed to GUI if available.
            %
            % :param str: Message text.
            % :type str: string
            % :param logType: One of "normal", "warning", or "error".
            % :type logType: string, optional
            arguments
                obj 
                str string
                logType string = "normal"
            end
            if isempty(obj.ControlApp) || ~isvalid(obj.ControlApp)
                switch logType
                    case "warning"
                        warning(str)
                    case "error"
                        error(str)
                    otherwise
                        disp(str)
                end         
            else
                obj.ControlApp.displayLog(str,logType)
            end
        end

    end

    methods (Abstract)
        writeDatabase(obj)
        % Write the initial database entry for the trial.
        %
        % Implemented by subclasses. Should create the DB row used to derive
        % :attr:`SerialNumber`.
        updateDatabase(obj)
        % Update the database entry to reflect current object state.
        setFolder(obj)
        % Create and assign data/object/analysis folder paths.
        setConfigProperty(obj,struct)
        % Assign configuration-dependent properties from structure/table.
    end

    methods
        function s = struct(obj)
            % Create a plain struct snapshot of public properties for logging/DB.
            %
            % :return: Public, serializable properties with heavy objects mapped to names.
            % :rtype: struct
            publicProperties = properties(obj);
            s = struct();
            for fi = 1:numel(publicProperties)
                prop = obj.(publicProperties{fi});
                if isa(prop,"numeric") || isa(prop,"char") ||...
                        isa(prop,"string") || isa(prop,"logical") || isa(prop,"datetime")
                    s.(publicProperties{fi}) = obj.(publicProperties{fi});
                else
                    try
                        s.(publicProperties{fi}) = obj.(publicProperties{fi}).Name;
                    catch
                    end
                end
            end
            s = rmfield(s,"SerialNumber");
        end

        function isCompeted = get.IsCompeted(obj)
            % Whether all runs have completed.
            %
            % :return: True if :attr:`NRun` equals :attr:`NCompletedRun`.
            % :rtype: logical
            isCompeted = obj.NRun == obj.NCompletedRun;
        end

        function is2DScan = get.Is2DScan(obj)
            % Whether this trial configures a 2D parameter scan.
            %
            % :return: True if :attr:`ScannedParameter` is a 1x2 string array.
            % :rtype: logical
            % Determine if this is a 2D scan based on ScannedParameter dimensions
            is2DScan =  obj.ScannedParameter2 ~= "None";
        end

        function createWatcher(obj)
            % Create a file system watcher that emits :event:`NewRunFinished` per group.
            %
            % Watches :attr:`DataPath` for created files matching :attr:`DataFormat` and
            % accumulates until :attr:`DataGroupSize` files are seen, then notifies.
            obj.FileSystemWatcher = System.IO.FileSystemWatcher(obj.DataPath);
            obj.FileSystemWatcher.Filter = "*"+obj.DataFormat;
            obj.FileSystemWatcher.EnableRaisingEvents = true;
            obj.Watcher = addlistener(obj.FileSystemWatcher,'Created', @(src,event) onChanged(src,event,obj));
            obj.Watcher.Enabled = false;
            function onChanged(~,evt,obj)
                obj.TempDataPath = [obj.TempDataPath string(evt.FullPath.ToString())];
                if numel(obj.TempDataPath) == obj.DataGroupSize
                    notify(obj,'NewRunFinished');
                    obj.TempDataPath = [];
                end
            end
        end

    end

    methods (Static)
        function obj = loadobj(obj)
            % Reconnect DB writer and GUI handle when the object is loaded.
            %
            % :return: Loaded object with transient handles restored when possible.
            % :rtype: :class:`Trial`
            try
                obj.Writer = createWriter(obj.DatabaseName); %Create writer type database connection
            catch
            end
            if ~isempty(obj.ControlAppName)
                obj.ControlApp = get(findall(0, 'Tag', obj.ControlAppName), 'RunningAppInstance');
            end
        end
    end

    events
        NewRunFinished %Triggered when a new run is detected.
    end
end

