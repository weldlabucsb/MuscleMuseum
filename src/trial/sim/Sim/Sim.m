classdef (Abstract) Sim < Trial
    %:class:`Sim` abstract base for simulation trials.
    %
    % Holds output, wall-time budget, and a vector of :class:`SimRun` objects.

    properties
        Output
        WallTime double = 86400 % in [s]
        SimRun
    end

    properties(Dependent,Hidden)
        UncompletedRunIndex
    end

    methods
        function obj = Sim(trialName,config)
            % Construct a :class:`Sim`.
            %
            % :param trialName: Simulation name
            % :type trialName: string
            % :param config: Config table/struct or name
            % :type config: string | table | struct
            obj@Trial(trialName,config);
        end

        function uRunIdx = get.UncompletedRunIndex(obj)
            % Indices of runs not yet completed.
            uRunIdx = find(~[obj.SimRun.IsCompleted]);
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

            %% Create data folders
            obj.DataPath = fullfile(obj.TrialPath,...
                yyyy+mm+dd+trialDelimiter+num2str(obj.TrialIndex));
            obj.DataAnalysisPath = fullfile(obj.DataPath,'dataAnalysis');
            obj.ObjectPath = fullfile(obj.DataAnalysisPath, ...
                obj.Name+yyyy+mm+dd+trialDelimiter+num2str(obj.TrialIndex)+'.mat');

            createFolder(obj.DataPath);
            createFolder(obj.DataAnalysisPath);

        end

        % setConfigProperty(obj,struct)
    end
end

