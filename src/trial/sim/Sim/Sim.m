classdef (Abstract) Sim < Trial
    %:class:`Sim` abstract base for simulation trials.
    %
    % Holds output, wall-time budget, and a vector of :class:`SimRun` objects.

    properties
        Output
        WallTime double = 86400 % in [s]
        SimRun
        ScannedVariable string = "None" % Primary scanned parameter name (must be implemented by subclasses)
        ScannedVariableUnit string = "None" % Primary scanned parameter unit string (must be implemented by subclasses)
        ScannedVariable2 string = "None" % Secondary scanned parameter name for 2D scans (must be implemented by subclasses)
        ScannedVariableUnit2 string = "None" % Secondary scanned parameter unit string for 2D scans (must be implemented by subclasses)
    end

    properties (SetAccess = private, Hidden)
        SimOutput SimOutput
        SimSetting SimSetting
    end

    properties(Dependent,Hidden)
        UncompletedRunIndex
    end

    methods
        function obj = Sim(trialName,simName)
            % Construct a :class:`Sim`.
            %
            % :param trialName: Simulation name
            % :type trialName: string
            % :param simName: Config table/struct or name
            % :type simName: string | table | struct
            p = SimSetting;
            s = p.readEntryTwoKey(simName,trialName,"SimName","TrialName");
            if isempty(s)
                s = p.readEntryTwoKey(simName,"Test","SimName","TrialName");
            end
            obj@Trial(trialName,s);
        end

        function uRunIdx = get.UncompletedRunIndex(obj)
            % Indices of runs not yet completed.
            uRunIdx = find(~[obj.SimRun.IsCompleted]);
        end

        function setParameterTable(obj)
            obj.SimOutput = SimOutput;
            obj.SimSetting = SimSetting;
        end

        function setOutput(obj)
            if ~isempty(obj.Output) && isstring(obj.Output)
                output = obj.Output;
            else
                output = obj.ConfigParameter.OutputVariableName;
            end

            if isempty(output) || any(output == "None")
                error("No output variable specified")
            end

            if isa(obj,"TimeSim") || isa(obj,"SpaceTimeSim")
                output = ["Time";output];
            end
            output = unique(output);

            t = obj.SimOutput.readEntry(string(class(obj)),"SimName");
            output = t(ismember(t.VariableName,output),:);
            obj.Output = output;
        end

        function check(obj,isWarning)
            % Check all runs, update :attr:`NCompletedRun`, and persist.
            arguments
                obj Sim
                isWarning logical = true
            end
            for ii = 1:obj.NRun
                obj.SimRun(ii).check(isWarning);
            end
            obj.NCompletedRun = sum([obj.SimRun.IsCompleted]);
            obj.update
        end

        function start(obj)
            % Launch incomplete runs in parallel where possible, then re-check.
            obj.check(false)
            uRunIdx = obj.UncompletedRunIndex;
            if numel(uRunIdx)>1
                parfevalOnAll(@warning,0,'off','all');
                parfor ii = 1:numel(uRunIdx)
                    try
                        obj.SimRun(uRunIdx(ii)).start;
                    catch
                    end
                end
            elseif numel(uRunIdx) == 1
                obj.SimRun(uRunIdx).start
            elseif numel(uRunIdx) == 0
                disp("All runs are completed.")
            end
            obj.check
            if numel(uRunIdx)>0
                obj.start
            end
        end
    end

    methods (Hidden)
        function setFolder(obj)
            % Create data storage folders and set analysis paths for the trial.
            %   The data are stored under :attr:`TrialPath` with a date-index naming scheme.

            %% Look at the watch
            t = obj.DateTime;
            mm = string(num2str(t.Month,'%02u'));
            dd = string(num2str(t.Day,'%02u'));
            yyyy = string(num2str(t.Year));

            %% Delimiters
            trialDelimiter = '_';

            %% Create trial folder
            obj.TrialPath = string(fullfile(obj.ParentPath,obj.Name));
            createFolder(obj.TrialPath); %Create the Date folder if it doesn't exist.

            %% Find trial index
            if obj.IsAutoDelete == true %Delete trials with no data collected
                query = "SELECT ""SerialNumber"" FROM " + obj.DatabaseTableName + " WHERE ""NCompletedRun"" = 0;";
                emptyData = pgFetch(obj.Writer,query);
                deleteTrial(obj.Writer,obj.DatabaseTableName,emptyData.SerialNumber,true) %Delete folders with no data.
            end

            query = "SELECT ""SerialNumber"" FROM " + obj.DatabaseTableName + " WHERE ""Name"" = '" + obj.Name + "'";
            todayData = pgFetch(obj.Writer,query);
            obj.TrialIndex = size(todayData,1) + 1;

            %% Find trial number
            sqlQuery = "SELECT last_value FROM " + "public."""+obj.DatabaseTableName+"_SerialNumber_seq"";";
            data = pgFetch(obj.Writer,sqlQuery);
            trialNumber = data.last_value + 1;

            %% Create data folders
            obj.DataPath = fullfile(obj.TrialPath,...
                yyyy+mm+dd+trialDelimiter+num2str(obj.TrialIndex) + trialDelimiter + "Trial" + trialDelimiter + trialNumber);
            obj.DataAnalysisPath = fullfile(obj.DataPath,'dataAnalysis');
            obj.ObjectPath = fullfile(obj.DataAnalysisPath, ...
                obj.Name+yyyy+mm+dd+trialDelimiter+num2str(obj.TrialIndex)+'.mat');

            createFolder(obj.DataPath);
            createFolder(obj.DataAnalysisPath);

        end

        % setConfigProperty(obj,struct)
    end
end

