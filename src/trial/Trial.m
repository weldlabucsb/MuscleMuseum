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
        Description string = "This is a test trial." % Human-readable description of the trial purpose and setup
        NCompletedRun int32 = 0 % Number of experimental runs completed successfully
        NRun int32 = 1 % Total number of runs planned for this trial
    end

    properties (Abstract)
        ScannedVariable string % Primary scanned parameter name (must be implemented by subclasses)
        ScannedVariableUnit string % Primary scanned parameter unit string (must be implemented by subclasses)
        ScannedVariable2 string % Secondary scanned parameter name for 2D scans (must be implemented by subclasses)
        ScannedVariableUnit2 string % Secondary scanned parameter unit string for 2D scans (must be implemented by subclasses)
    end

    properties (SetAccess = protected)
        DateTime datetime % Date and time when the experiment or simulation was initiated
    end

    properties (SetAccess = protected)
        Name string % Trial name identifier matching the configuration entry
        DataPath string = "." % Full path to the trial's data storage directory
        ObjectPath string % Full path to the saved trial object .mat file
        SerialNumber int32 % Unique database-generated identifier for this trial instance
    end

    properties (Dependent)
        IsCompleted logical % True when all planned runs have been completed successfully
        Is2DScan logical % True for two-dimensional parameter scans (computed from :attr:`ScannedVariable2`)
    end

    properties (SetAccess = protected, Hidden)
        ParentPath {mustBeFolder} = "." % Root directory for all trial data storage
        IsAutoDelete logical = false % Flag to automatically delete empty trials with no completed runs
        DatabaseName string % PostgreSQL database name for trial persistence
        DatabaseTableName string % Database table name for this trial type
        DataPrefix string = "run" % Filename prefix for data files (e.g., "run_1_atom.tif")
        DataFormat string = ".mat" % File extension for data files
        DatePath string % Date-organized folder path (year/year.month/month.day)
        TrialPath string % Full path to this trial's root directory
        DataAnalysisPath string % Full path to analysis results subdirectory
        DataGroupSize uint32 = 1 % Number of files per run group for file watcher triggering
        TrialIndex uint32 = 1 % Index of this trial among trials with same name on same day
        ControlAppName string % Tag name of associated GUI control panel application
    end

    properties (SetAccess = protected, Hidden, Transient)
        Reader database.postgre.connection % Database connection for reading trial data
        Writer database.postgre.connection % Database connection for writing trial data
        FileSystemWatcher % .NET file system watcher for monitoring data directory
        Watcher event.listener % Event listener for file system changes
        Analyzer event.listener % Event listener for triggering analysis pipeline
        ControlApp % Handle to associated GUI control panel application
    end

    properties (Hidden,Transient)
        TempData = [] % Temporary storage for current run data during acquisition
        TempDataPath string % Temporary file paths for data being processed
    end

    properties (Hidden)
        ConfigParameter struct % Configuration parameters loaded from database or file
    end

    methods
        function obj = Trial(trialName,config,isLoad)
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
                isLoad logical = false %Whether it's loading an old instance or creating a new one
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
            if ~isLoad
                obj.displayLog("Constructing the object.")
            end
           
            %% Set parameter table
            obj.setParameterTable

            %% Set the folders
            if ~isLoad
                obj.displayLog("Setting up folders.")
                obj.Writer = createWriter(obj.DatabaseName); %Create writer type database connection
                obj.DateTime = datetime;
                obj.setFolder %Create folders for data storage
            end

            %% Write initial information into the database, then get the serial number generated by the database
            if ~isLoad
                obj.displayLog("Creating a database entry.")
                obj.writeDatabase;
                sqlQuery = "SELECT last_value FROM " + "public."""+obj.DatabaseTableName+"_SerialNumber_seq"";";
                data = pgFetch(obj.Writer,sqlQuery);
                obj.SerialNumber = data.last_value;
            end

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
        setParameterTable(obj)
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

        function isCompeted = get.IsCompleted(obj)
            % Whether all runs have completed.
            %
            % :return: True if :attr:`NRun` equals :attr:`NCompletedRun`.
            % :rtype: logical
            isCompeted = obj.NRun == obj.NCompletedRun;
        end

        function is2DScan = get.Is2DScan(obj)
            % Whether this trial configures a 2D variable scan.
            %
            % :return: True if :attr:`ScannedParameter` is a 1x2 string array.
            % :rtype: logical
            % Determine if this is a 2D scan based on ScannedVariable dimensions
            is2DScan =  obj.ScannedVariable2 ~= "None";
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
        NewRunFinished % Event triggered when a new experimental run is detected and ready for analysis
    end
end

