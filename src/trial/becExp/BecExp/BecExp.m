classdef BecExp < Trial
    %:class:`BecExp` run orchestration for BEC experiments with real-time analysis.
    %
    % Wires together acquisition, ROI selection, analysis modules, logging,
    % and database updates. Supports automatic or file-watcher acquisition,
    % 1D/2D parameter scans, figure/GUI management, and error handling for
    % Cicero and hardware logs.
    %
    % **Workflow:**
    %
    % - :meth:`start`: set hardware, start acquisition or watcher, enable analyzer, initialize figures
    % - On each run (listener): fetch/move Cicero log, update hardware/scope data, update figures
    % - :meth:`stop`/:meth:`fastStop`: stop acquisition, unlock, refresh/save/close analysis figures
    % - :meth:`refresh`: recompute and redraw analysis
    % - :meth:`show`/:meth:`browserShow`: display figures/GUI on chosen monitor(s)
    properties
        Roi Roi % :class:`Roi` defining main region of interest for image analysis
        SubRoi Roi % Optional collection of sub-ROIs for multi-region analysis
        Acquisition Acquisition % :class:`Acquisition` settings and hardware interface helpers
        AnalysisMethod string % Ordered list of active analysis module names
        CloudCenter double % Cloud center coordinates [:math:`y_0`, :math:`x_0`] from previous measurement [pixels]
        AveragingMethod string = "StdErr" % Data averaging method: "None"|"StdErr"|"Std"
        IsDensityAverage logical = false % Flag to control averaging when saving Od and Ad data and figures
        IsUseWeightedPosition logical = 0 % Logical value to control use of weighted or fitted center positions for CenterFit
    end

    properties(Dependent)
        ScannedVariable string % Primary scanned variable name from :attr:`VariableUnitSetting`
        ScannedVariableUnit string % Primary scanned variable unit string
        ScannedVariable2 string % Secondary scanned variable name for 2D parameter scans
        ScannedVariableUnit2 string % Secondary scanned variable unit string for 2D scans
    end

    properties(Hidden)
        ScannedVariableID (1,1) double = 1 % Primary variable ID in :class:`BecExpVariableUnit` lookup table
        ScannedVariableID2 (1,1) double = 0 % Secondary variable ID for 2D parameter scans (0 = none)
        IsAutoAcquire logical = false % Flag to automatically control camera acquisition from MATLAB
        IsHoldRefresh logical = false % Flag to temporarily disable figure refresh during operations
        IsAcquiring logical = false % Flag indicating whether images are currently being acquired
        IsOdPreview logical = false % Flag to toggle optical depth preview mode in analysis GUIs
    end

    properties (Hidden,Transient)
        ExistedCiceroLogNumber % Count of Cicero log files already present in origin directory
        ExistedHardwareLogNumber % Count of hardware log files already present in origin directories
    end

    properties (SetAccess = private, Hidden)
        CiceroLogOrigin = "." % Origin directory path watched for new Cicero log files
        CiceroLogPath string % Destination log folder path within trial directory
        CiceroLogTime datetime % Timestamps of moved Cicero log files per run
        DeletedRunVariableList % Cached scanned parameter values for runs that have been deleted
        VariableUnitSetting % Lookup table mapping variable IDs to parameter names and units
        HardwareList % Configuration table for hardware devices and their settings
        VariableList % Live table of current hardware variable values
        HardwareAssociation % Mapping table linking trial configurations to hardware settings
        HardwareLogPath string % Destination hardware log folder path within trial directory
    end

    properties (SetAccess = private)
        CiceroData struct % Aggregated Cicero sequence variables per run from log files
        HardwareData struct % Aggregated hardware measurement values per run from device logs
        ScopeData struct % Aggregated oscilloscope-derived measurement values per run
        Atom Atom % :class:`Atom` object containing atomic species properties for the experiment
    end

    properties (Dependent,Hidden)
        ScannedVariableList % 1D array or 2×N matrix of scanned variable values across runs
        RunListSorted % Run indices sorted by ascending scanned variable value(s)
        ScannedVariableListSorted % Scanned variable values sorted in ascending order
        XLabel % LaTeX-formatted axis label with units for primary scanned variable
        YLabel % LaTeX-formatted y-axis label with units for secondary variable (2D scans only)
        VariableGrid % Meshgrid structure containing X, Y grids for 2D variable scans
    end

    properties (Constant,Hidden)
        AnalysisOrder = {"Od";"Imaging";"Ad";...
            "DensityFit";["AtomNumber";"Tof";"CenterFit";"KapitzaDirac"];"ScopeValue"} % Analysis execution order groups defining dependencies
    end

    methods
        function obj = BecExp(trialName,config,isLoad)
            % Construct :class:`BecExp` trial orchestrator.
            %
            % Initializes atom and acquisition settings, ROI, analysis
            % modules, log paths, and optional auto-load. When not loading,
            % performs an initial update to set up figures and internal state.
            %
            % :param trialName: Human-readable trial name
            % :type trialName: string
            % :param config: Configuration entry name (default: "BecExpSetting")
            % :type config: string, optional
            % :param isLoad: If true, construct from a saved object struct
            % :type isLoad: logical, optional
            arguments
                trialName string
                config = "BecExpSetting"
                isLoad logical = false
            end
            obj@Trial(trialName,config,isLoad);


            % Atom setting
            obj.Atom = getAtom(obj.ConfigParameter.AtomName);

            % Acquisition settings
            p = AcquisitionSetting;
            obj.Acquisition = p.loadEntry(obj.ConfigParameter.AcquisitionName);
            obj.Acquisition.ImagePath = obj.DataPath;
            obj.Acquisition.ImageFormat = obj.DataFormat;
            obj.Acquisition.ImagePrefix = obj.DataPrefix;
            obj.Roi = Roi(obj.ConfigParameter.RoiName,imageSize = obj.Acquisition.ImageSize);

            % Cloud center
            if ~ismissing(obj.ConfigParameter.CloudCenterReference)
                load("CloudCenterData.mat","CloudCenter")
                if ismember(obj.ConfigParameter.CloudCenterReference,CloudCenter.TrialName)
                    obj.CloudCenter = ...
                        CloudCenter(CloudCenter.TrialName == obj.ConfigParameter.CloudCenterReference,:).Center;
                end
            end

            % Analysis settings
            if ~isLoad
                obj.AnalysisMethod = rmmissing(["Od";"Imaging";"Ad";...
                    obj.AnalysisMethod(:)]);
                obj.AnalysisMethod(obj.AnalysisMethod == "None") = [];
                obj.addAnalysis(obj.AnalysisMethod);
            end
            obj.setAnalyzer;

            % Finalize construction
            if ~isLoad
                obj.update;
                obj.displayLog("Object construction done.")
            end
        end

        function setParameterTable(obj)
            % Load static parameter lookup tables used by the trial.
            %
            % Initializes configuration tables for variable mappings, hardware
            % settings, current values, and trial associations from the database.
            obj.VariableUnitSetting = BecExpVariableUnit;
            obj.HardwareList = HardwareList;
            obj.VariableList = VariableList;
            obj.HardwareAssociation = HardwareAssociation;
        end
        
        function var1 = get.ScannedVariable(obj)
            % Get primary scanned variable name from lookup table.
            %
            % :return: Primary scanned parameter name
            % :rtype: string
            id = obj.ScannedVariableID;
            var1 = obj.VariableUnitSetting.readValue(id,"ScannedVariable");
        end

        function var2 = get.ScannedVariable2(obj)
            % Get secondary scanned variable name for 2D parameter scans.
            %
            % :return: Secondary scanned parameter name, or "None" if not a 2D scan
            % :rtype: string
            id = obj.ScannedVariableID2;
            if id == 0
                var2 = "None";
            else
                var2 = obj.VariableUnitSetting.readValue(id,"ScannedVariable");
            end
        end

        function unit1 = get.ScannedVariableUnit(obj)
            % Get unit string for primary scanned variable.
            %
            % :return: Primary scanned parameter unit string
            % :rtype: string
            id = obj.ScannedVariableID;
            unit1 = obj.VariableUnitSetting.readValue(id,"ScannedVariableUnit");
        end

        function unit2 = get.ScannedVariableUnit2(obj)
            % Get unit string for secondary scanned variable in 2D scans.
            %
            % :return: Secondary scanned parameter unit string, or "None" if not a 2D scan
            % :rtype: string
            id = obj.ScannedVariableID2;
            if id == 0
                unit2 = "None";
            else
                unit2 = obj.VariableUnitSetting.readValue(id,"ScannedVariableUnit");
            end
        end
        
        function varList = get.ScannedVariableList(obj)
            % Get scanned parameter values for all completed runs.
            %
            % Returns either a 1D array (for 1D scans) or a 2×N matrix (for 2D scans)
            % containing the parameter values for each run. Handles special cases like
            % run index and Cicero log time.
            %
            % :return: Parameter values per run - 1D array or 2×N matrix
            % :rtype: double
            if obj.Is2DScan
                % For 2D scans, return a 2xN matrix with both parameters             
                varList1 = obj.getVariableList(obj.ScannedVariable);
                varList2 = obj.getVariableList(obj.ScannedVariable2);
                if ~isempty(varList1) && ~isempty(varList2)
                    varList = [varList1; varList2];
                else
                    varList = [];
                end
            else
                % 1D scan - original logic
                varList = obj.getVariableList(obj.ScannedVariable);
            end
        end

        function varList = getVariableList(obj,varName)
            switch varName
                case "None"
                    varList = [];
                case "RunIndex"
                    varList = double(1:obj.NCompletedRun);
                case "CiceroLogTime"
                    if ~isempty(obj.CiceroLogTime)
                        varList = obj.CiceroLogTime;
                        varList = varList - varList(1);
                        varList = seconds(varList);
                    else
                        varList = [];
                    end
                otherwise
                    if isfield(obj.CiceroData,varName)
                        varList = obj.CiceroData.(varName);
                    elseif isfield(obj.HardwareData,varName)
                        varList = obj.HardwareData.(varName);
                    else
                        obj.updateScopeData
                        if isfield(obj.ScopeData,varName)
                            varList = obj.ScopeData.(varName);
                        else
                            varList = [];
                        end
                    end
            end
        end

        function runListSorted = get.RunListSorted(obj)
            % Get run indices sorted by scanned value(s).
            %
            % :return: Sorted run indices
            % :rtype: double
            varList = obj.ScannedVariableList;
            [~,runListSorted] =  sort(varList,2);
        end

        function varListSorted = get.ScannedVariableListSorted(obj)
            % Get sorted list of scanned values.
            %
            % :return: Sorted scanned values
            % :rtype: double
            varList = obj.ScannedVariableList;
            [varListSorted,~] =  sort(varList,2);
        end

        function xLabel = get.XLabel(obj)
            % Build LaTeX-formatted x-axis label for primary variable.
            %
            % :return: Axis label string
            % :rtype: string
            sP = obj.ScannedVariable;
            sP = strrep(sP,'_','\_');
            if obj.ScannedVariableUnit == "None"
                xLabel = sP;
            else
                xLabel = sP + "~[$\mathrm{" + obj.ScannedVariableUnit + "}$]";
            end
        end

        function yLabel = get.YLabel(obj)
            % Build LaTeX-formatted y-axis label for secondary variable.
            %
            % :return: Axis label string or empty
            % :rtype: string
            if ~obj.Is2DScan
                yLabel = "";
                return
            end
            
            sP = obj.ScannedVariable2;
            sP = strrep(sP,'_','\_');
            if obj.ScannedVariableUnit2 == "None"
                yLabel = sP;
            else
                yLabel = sP + "~[$\mathrm{" + obj.ScannedVariableUnit2 + "}$]";
            end
        end

        function l = ScannedVariableLabel(obj,runNumber)
            % Build label strings for scanned variable names and values.
            %
            % :param runNumber: Run index
            % :type runNumber: double
            % :return: [names, values] joined for display
            % :rtype: string
            if ~obj.Is2DScan
                sv = obj.ScannedVariable;
            else
                sv = obj.ScannedVariable + ", " + obj.ScannedVariable2;           
            end
            sv = strrep(sv,'_','\_');

            if isempty(obj.ScannedVariableList)  
                l = sv;
            else
                sl = string(obj.ScannedVariableList(:,runNumber));
                su = [obj.ScannedVariableUnit;obj.ScannedVariableUnit2];
                su = " $\mathrm{" + replace(su,"None","") + "}$";
                if ~obj.Is2DScan
                    l = [sv,sl + su(1)]; 
                else
                    l = [sv,join(sl + su,",")]; 
                end
            end
        end

        function varGrid = get.VariableGrid(obj)
            % Create 2D parameter grid structure for 2D scans.
            %
            % Generates meshgrid arrays and unique parameter lists for 2D parameter
            % scans. Returns empty for 1D scans.
            %
            % :return: Structure with X, Y meshgrids and unique parameter lists
            % :rtype: struct
            if ~obj.Is2DScan
                varGrid = [];
                return
            end
            
            varList = obj.ScannedVariableList;
            if isempty(varList) || size(varList, 1) ~= 2
                varGrid = [];
                return
            end
            
            varList1 = varList(1, :);
            varList2 = varList(2, :);
            
            % Get unique values for each parameter
            unique1 = unique(varList1);
            unique2 = unique(varList2);
            
            % Create meshgrid
            [X, Y] = meshgrid(unique1, unique2);
            varGrid = struct('X', X, 'Y', Y, 'unique1', unique1, 'unique2', unique2);
        end

        function drp = get.DeletedRunVariableList(obj)
            % Get cached parameter values for deleted runs.
            %
            % Returns parameter values from runs that have been deleted but are
            % not present in the current run list. Used for tracking deleted data.
            %
            % :return: Parameter values of deleted runs that are not in current list
            % :rtype: double
            if isempty(obj.DeletedRunVariableList)
                drp = eval(class(obj.ScannedVariableList)+".empty(0,0)");
                return
            end
            if all(~ismember(obj.DeletedRunVariableList,obj.ScannedVariableList))
                drp = obj.DeletedRunVariableList;
            else
                drp = obj.DeletedRunVariableList(~ismember(obj.DeletedRunVariableList,obj.ScannedVariableList));
            end
        end

        function setAnalyzer(obj)
            % Set up event listener for automated analysis upon run completion.
            %
            % Creates a listener that triggers analysis pipeline when new run data
            % becomes available. The analyzer handles image renaming, log fetching,
            % hardware updates, and figure refreshing.
            obj.Analyzer = addlistener(obj,'NewRunFinished',@(src,event) onChanged(src,event,obj));
            obj.Analyzer.Enabled = false;
            function onChanged(~,~,obj)
                obj.IsAcquiring = true;
                obj.NCompletedRun = obj.NCompletedRun + 1;
                if obj.NCompletedRun > obj.NRun
                    obj.NRun = obj.NCompletedRun;
                end
                currentRunNumber = obj.NCompletedRun;
                obj.displayLog("Run #" + string(currentRunNumber) + " is acquired.")

                %% Rename images and write TempData if not Auto acquire
                if ~obj.IsAutoAcquire
                    pause(0.1)
                    [~,dataPath,ext] = fileparts(obj.TempDataPath);
                    [~,idx] = sort(str2double(string((regexp(dataPath,'[^\_]*$','match')))));
                    ext = ext(idx);
                    obj.TempDataPath = obj.TempDataPath(idx);
                    nn = num2str(currentRunNumber);
                    dataPrefix = fullfile(obj.DataPath,obj.DataPrefix) + "_" + nn;
                    newDataPath = [dataPrefix + "_atom" + ext(1);...
                        dataPrefix + "_light" + ext(2);...
                        dataPrefix + "_dark" + ext(3)];
                    arrayfun(@(ii) renameFile(obj.TempDataPath(ii),newDataPath(ii)),[1 2 3]);
                    obj.TempData = obj.readRun(currentRunNumber);
                end

                %% Fetch Cicero log data and write into CiceroData
                isFetched = obj.fetchCiceroLog(currentRunNumber);
                if ~isFetched %Error handling when Cicero crashes
                    obj.displayLog("Failed fetching the Cicero data. Deleting the latest images","warning")
                    fList = dir(fullfile(obj.DataPath,"*"+obj.DataFormat));
                    imageList = string({fList.name});
                    if ~isempty(imageList)
                        imageNumberList = arrayfun(@(x) str2double(regexp(x,'\d*','match')),imageList);
                        deleteList = imageList(ismember(imageNumberList,currentRunNumber));
                        for ii = 1:numel(deleteList)
                            deleteFile(fullfile(obj.DataPath,deleteList(ii)))
                        end
                    end
                    obj.countExistedLog
                    obj.IsAcquiring = false;
                    obj.NCompletedRun = obj.NCompletedRun - 1;
                    if obj.NCompletedRun > 0
                        obj.NRun = obj.NCompletedRun;
                    else
                        obj.NRun = 1;
                    end
                    return
                end

                % Update cicero data
                [ciceroData, readsuccess] = obj.readCiceroLog(currentRunNumber);

                % Error handling if file cannot be read (should be
                % double checked before properly using. Deletes latest
                % images. Need to check step to delete extraneous Cicero Log
                % File.
                if ~readsuccess %Error handling when Cicero log file gets corrupted.
                    obj.displayLog("Failed reading the Cicero data. Deleting the latest images","warning")
                    dataPrefix = obj.DataPrefix;
                    badfile= fullfile(obj.CiceroLogPath,dataPrefix) + "_" + num2str(currentRunNumber)+".clg";
                    disp(badfile);
                    delete(badfile)
                    fList = dir(fullfile(obj.DataPath,"*"+obj.DataFormat));
                    imageList = string({fList.name});
                    if ~isempty(imageList)
                        imageNumberList = arrayfun(@(x) str2double(regexp(x,'\d*','match')),imageList);
                        deleteList = imageList(ismember(imageNumberList,currentRunNumber));
                        for ii = 1:numel(deleteList)
                            deleteFile(fullfile(obj.DataPath,deleteList(ii)))
                        end
                    end
                    obj.countExistedLog
                    obj.IsAcquiring = false;
                    obj.NCompletedRun = obj.NCompletedRun - 1;
                    if obj.NCompletedRun > 0
                        obj.NRun = obj.NCompletedRun;
                    else
                        obj.NRun = 1;
                    end
                    
                    return
                    
                end
                
                if isempty(obj.CiceroData)
                    obj.CiceroData = ciceroData;
                else
                    f = fields(obj.CiceroData);
                    for ii = 1:numel(f)
                        obj.CiceroData.(f{ii}) = [obj.CiceroData.(f{ii}),ciceroData.(f{ii})];
                    end
                end

                %% Fetch Hardware log data
                obj.fetchHardwareLog(currentRunNumber);
                
                %% Update Hardware
                obj.updateHardware

                %% Update ScopeData
                obj.updateScopeData

                %% Check if the scanned parameter is correct
                if isempty(obj.ScannedVariableList)
                    if ~obj.Is2DScan
                        obj.displayLog("Can not find [" + obj.ScannedVariable + "]" + ...
                            " in Cicero or Hardware Variable List or scope data list. Please correct and restart.","error")
                    else
                        obj.displayLog("Can not find [" + obj.ScannedVariable + "] or [" + obj.ScannedVariable2 + "]" + ...
                            " in Cicero or Hardware Variable List or scope data list. Please correct and restart.","error")
                    end
                end

                %% Show Images
                obj.displayLog("Updating the figures.")
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).update(currentRunNumber)
                end

                obj.IsAcquiring = false;
            end
        end

        function addAnalysis(obj,newAnalysisList)
            % Add new analysis modules to the experiment pipeline.
            %
            % Instantiates analysis objects, applies configuration settings,
            % and sorts them according to :attr:`AnalysisOrder` dependencies.
            %
            % :param newAnalysisList: Names of analysis modules to add
            % :type newAnalysisList: string
            if ~isstring(newAnalysisList)
                error('Input must be a string.')
            end
            if ~all(ismember(newAnalysisList,vertcat(obj.AnalysisOrder{:})))
                warning('Input are not all listed in AnalysisOrder.')
            end
            newAnalysisList = rmmissing(newAnalysisList);
            newAnalysisList(newAnalysisList == "None") = [];
            if isempty(newAnalysisList)
                return
            end

            for ii = 1:numel(newAnalysisList)
                if ~isprop(obj,newAnalysisList(ii))
                    addprop(obj,newAnalysisList(ii));
                    obj.(newAnalysisList(ii)) = eval(newAnalysisList(ii) + "(obj)");
                    switch newAnalysisList(ii)
                        case "Od"
                            obj.Od.CLim = [0,obj.ConfigParameter.OdCLim];
                            obj.Od.Colormap = obj.ConfigParameter.OdColormap;
                            obj.Od.FringeRemovalMask = obj.ConfigParameter.FringeRemovalMask;
                            obj.Od.FringeRemovalMethod = obj.ConfigParameter.FringeRemovalMethod;
                        case "Imaging"
                            obj.Imaging.ImagingStage = obj.ConfigParameter.ImagingStage;
                            obj.Imaging.ImagingMethod = obj.ConfigParameter.ImagingMethod;
                        case "Ad"
                            obj.Ad.AdMethod = obj.ConfigParameter.AdMethod;
                            obj.Ad.CLim = [0,obj.ConfigParameter.AdCLim];
                        case "ScopeValue"
                            obj.ScopeValue.FullValueName = strsplit(string(obj.ConfigParameter.ScopeValueName),";");
                        case "DensityFit"
                            obj.DensityFit.FitMethod = obj.ConfigParameter.DensityFitMethod;
                        case "AtomNumber"
                            obj.AtomNumber.YLim = [0,obj.ConfigParameter.AtomNumberYLim];
                            obj.AtomNumber.FitMethod = obj.ConfigParameter.AtomNumberFitMethod;
                        case "CenterFit"
                            obj.CenterFit.FitMethod = obj.ConfigParameter.CenterFitMethod;
                    end
                end

                obj.AnalysisMethod = [obj.AnalysisMethod(:);newAnalysisList(:)];
                obj.sortAnalysis;
            end
        end

        function removeAnalysis(obj,removeAnalysisList)
            % Remove analysis modules from the experiment pipeline.
            %
            % Closes associated figures and removes modules from the active
            % analysis list, then re-sorts the remaining modules.
            %
            % :param removeAnalysisList: Names of analysis modules to remove
            % :type removeAnalysisList: string
            if ~isstring(removeAnalysisList)
                error('Input must be a string.')
            end
            removeAnalysisList = rmmissing(removeAnalysisList);
            if isempty(removeAnalysisList)
                return
            end

            removeAnalysisList = removeAnalysisList(ismember(removeAnalysisList,obj.AnalysisMethod));
            for ii = 1:numel(removeAnalysisList)
                obj.(removeAnalysisList(ii)).close;
            end

            obj.AnalysisMethod(obj.AnalysisMethod == removeAnalysisList) = [];
            obj.sortAnalysis;

        end

        function analysisListSorted = sortAnalysis(obj)
            % Sort analysis modules according to execution dependencies.
            %
            % Arranges active analysis modules in the order specified by
            % :attr:`AnalysisOrder` to ensure proper data flow (e.g., Od before Ad).
            %
            % :return: Sorted list of analysis module names
            % :rtype: string
            analysisList = obj.AnalysisMethod;
            analysisListSorted = rmmissing(unique(analysisList(:)));
            analysisOrder = obj.AnalysisOrder;
            analysisOrder = vertcat(analysisOrder{:});
            extraAnalysis = analysisListSorted(~ismember(analysisListSorted,analysisOrder));
            analysisListSorted = [analysisOrder(ismember(analysisOrder,analysisListSorted));...
                extraAnalysis];
            obj.AnalysisMethod = analysisListSorted(:).';
        end

        function start(obj)
            % Initialize hardware and begin data acquisition or file watching.
            %
            % Sets up hardware associations, starts camera acquisition (if auto mode)
            % or file watcher, enables the analysis pipeline, and initializes all
            % analysis figure windows.
            obj.displayLog(" ")
            obj.displayLog("Trial #" + string(obj.SerialNumber) + ": Starting data acquisition and real-time analysis.")
            obj.countExistedLog

            obj.setHardware
            if obj.IsAutoAcquire
                obj.Acquisition.connectCamera;
                switch obj.Imaging.ImagingMethod
                    case  "Absorption"
                        obj.Acquisition.setCameraParameterAbsorption;
                        obj.Acquisition.setCallback(@(src,evt) saveBecImageAbsorption(src,evt,obj));
                    case "Dispersive"

                    case "Fluorescence"

                end
                obj.Acquisition.startCamera;
            else
                obj.createWatcher;
                obj.Watcher.Enabled = true;
            end

            obj.Analyzer.Enabled = true;
            analysisMethod = obj.AnalysisMethod;

            obj.displayLog("Initializing the figures.")
            for ii = 1:numel(analysisMethod)
                obj.(analysisMethod(ii)).initialize;
            end

        end

        function pause(obj)
            % Pause data acquisition and disable real-time analysis.
            %
            % Temporarily stops camera acquisition or file watcher and disables
            % the analysis pipeline without closing figures or losing state.
            obj.displayLog("Pausing data acquisition and real-time analysis.")
            if obj.IsAutoAcquire
                obj.Acquisition.pauseCamera;
            else
                obj.Watcher.Enabled = false;
            end
            obj.Analyzer.Enabled = false;
        end

        function resume(obj)
            % Resume data acquisition and re-enable real-time analysis.
            %
            % Restarts camera acquisition or file watcher, updates log file counts,
            % and re-enables the analysis pipeline from the paused state.
            obj.displayLog("Resuming data acquisition and real-time analysis.")

            obj.ExistedCiceroLogNumber = countFileNumber(obj.CiceroLogOrigin,".clg");

            if obj.IsAutoAcquire
                obj.Acquisition.startCamera;
            else
                obj.Watcher.Enabled = true;
            end
            obj.Analyzer.Enabled = true;
        end

        function save(obj)
            if obj.NCompletedRun == 0
                return
            end
            warning off
            for ii = 1:numel(obj.AnalysisMethod)
                obj.(obj.AnalysisMethod(ii)).save;
                obj.(obj.AnalysisMethod(ii)).close;
            end
            warning on
            obj.update
        end

        function stop(obj)
            % Stop acquisition, finalize analysis, and clean up resources.
            %
            % Stops camera or file watcher, unlocks phase locks, performs final
            % analysis refresh (with fringe removal if enabled), saves all figures,
            % and updates the trial database. Deletes empty trials with no runs.
            obj.displayLog(" ")
            obj.displayLog("Trial #" + string(obj.SerialNumber) + ": Stopping data acquisition and real-time analysis.")

            if obj.IsAutoAcquire
                obj.Acquisition.stopCamera;
            else
                obj.Watcher.Enabled = false;
            end
            obj.Analyzer.Enabled = false;

            obj.displayLog("Unlocking the phase locks.")
            obj.unlock

            if obj.NCompletedRun == 0
                obj.displayLog("No run has been acquired. Deleting this trial.")
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).close;
                end
                deleteBecExp(obj.SerialNumber,true)
                obj.delete
                return
            end

            if obj.Od.FringeRemovalMethod == "None" || isempty(obj.Od.FringeRemovalMask)
                obj.displayLog("Saving the figures.")
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).finalize;
                    obj.(obj.AnalysisMethod(ii)).save;
                    obj.(obj.AnalysisMethod(ii)).close;
                end
            else
                obj.displayLog("Refreshing and Saving the figures.")
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).refresh;
                    obj.(obj.AnalysisMethod(ii)).save;
                    obj.(obj.AnalysisMethod(ii)).close;
                end
            end

            obj.update;

        end

        function fastStop(obj)
            % Fast stop without forced refresh; save and close analysis figures.
            %
            % Similar to :meth:`stop` but skips the final analysis refresh step
            % to save time. Still performs cleanup, saves figures, and updates
            % the database. Useful when immediate shutdown is needed.
            obj.displayLog(" ")
            obj.displayLog("Trial #" + string(obj.SerialNumber) + ": Stopping data acquisition and real-time analysis. Will not force refresh.")

            if obj.IsAutoAcquire
                obj.Acquisition.stopCamera;
            else
                obj.Watcher.Enabled = false;
            end
            obj.Analyzer.Enabled = false;

            obj.displayLog("Unlocking the phase locks.")
            obj.unlock

            if obj.NCompletedRun == 0
                obj.displayLog("No run has been acquired. Deleting this trial.")
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).close;
                end
                deleteBecExp(obj.SerialNumber,true)
                obj.delete
                return
            end

            obj.displayLog("Saving the figures.")
            for ii = 1:numel(obj.AnalysisMethod)
                obj.(obj.AnalysisMethod(ii)).finalize;
                obj.(obj.AnalysisMethod(ii)).save;
                obj.(obj.AnalysisMethod(ii)).close;
            end

            obj.update;

        end

        function show(obj)
            % Display all analysis windows on the current monitor.
            %
            % Makes all analysis figure windows and GUIs visible using their
            % default positioning and sizing settings.
            for ii = 1:numel(obj.AnalysisMethod)
                obj.(obj.AnalysisMethod(ii)).show;
            end
        end

        function browserShow(obj)
            % Display analysis windows in browser-style layout on secondary monitor.
            %
            % Arranges analysis figures and GUIs on the secondary monitor (if available)
            % in a browser-like tiled layout for better multi-monitor workflows.
            % Falls back to primary monitor if only one display is available.
            mp = sortMonitor;
            monitorIndex = 1;
            if size(mp,1) > 1
                appHandle = get(findall(0, 'Tag', obj.ControlAppName), 'RunningAppInstance');
                if ~isempty(appHandle)
                    if isvalid(appHandle)
                        monitorIndex = 2;
                    end
                end
            end
            for ii = 1:numel(obj.AnalysisMethod)
                for jj = 1:numel(obj.(obj.AnalysisMethod(ii)).Gui)
                    obj.(obj.AnalysisMethod(ii)).Gui(jj).Monitor = monitorIndex;
                end
                for jj = 1:numel(obj.(obj.AnalysisMethod(ii)).Chart)
                    obj.(obj.AnalysisMethod(ii)).Chart(jj).IsBrowser = true;
                    obj.(obj.AnalysisMethod(ii)).Chart(jj).Monitor = monitorIndex;
                end
                obj.(obj.AnalysisMethod(ii)).show;
            end
        end

        function refresh(obj,anaylsisName,isRefreshData)
            % Recompute analysis data and refresh visualizations.
            %
            % Reprocesses all run data through the analysis pipeline and updates
            % figures. Can refresh all modules or start from a specific module
            % (refreshing it and all downstream dependencies).
            %
            % :param anaylsisName: Analysis module to start refresh from (default: all)
            % :type anaylsisName: string, optional
            arguments
                obj BecExp
                anaylsisName string = string.empty
                isRefreshData logical = false
            end
            if obj.IsHoldRefresh
                obj.displayLog("Refresh is on hold.")
                return
            end

            if isRefreshData
                refreshMethod = "refreshData";
            else
                refreshMethod = "refresh";
            end

            nAnalysis = numel(obj.AnalysisMethod);
            if obj.NCompletedRun < 1
                obj.displayLog("No run has been acquired. Initializing the figures instead.")
                for ii = 1:nAnalysis
                    obj.(obj.AnalysisMethod(ii)).initialize;
                end
            else
                obj.displayLog("Refreshing the figures.")
                if isempty(anaylsisName)
                    for ii = 1:nAnalysis
                        obj.(obj.AnalysisMethod(ii)).(refreshMethod);
                    end
                elseif ~isscalar(anaylsisName)
                    error("Input must be a string scalar.")
                elseif ~ismember(anaylsisName,vertcat(obj.AnalysisOrder{:}))
                    warning(anaylsisName + " is not in AnalysisOrder. Will refresh all.")
                    for ii = 1:nAnalysis
                        obj.(obj.AnalysisMethod(ii)).(refreshMethod);
                    end
                else
                    % First refresh [anaylsisName]
                    if ismember(anaylsisName,obj.AnalysisMethod)
                        obj.(anaylsisName).(refreshMethod)
                    end

                    % Then refresh everthing after [anaylsisName]
                    orderIdx = find(cellfun(@(x) any(anaylsisName==x),obj.AnalysisOrder));
                    afterAnalysis = obj.AnalysisOrder(orderIdx+1:end);
                    afterAnalysis = vertcat(afterAnalysis{:});
                    if ~isempty(afterAnalysis)
                        aMethodIdx = find(ismember(obj.AnalysisMethod,afterAnalysis),1);
                        if ~isempty(aMethodIdx)
                            for ii = aMethodIdx:nAnalysis
                                obj.(obj.AnalysisMethod(ii)).(refreshMethod);
                            end
                        else
                            % Refresh everthing that are not in AanalysisOrder
                            extraAnalysis = obj.AnalysisMethod(~ismember(obj.AnalysisMethod,vertcat(obj.AnalysisOrder{:})));
                            for ii = 1:numel(extraAnalysis)
                                obj.(extraAnalysis(ii)).(refreshMethod);
                            end
                        end
                    end
                end
                obj.displayLog("Refresh done.")
            end
        end

        function refreshData(obj,anaylsisName)
            arguments
                obj BecExp
                anaylsisName string = string.empty
            end
            obj.refresh(anaylsisName,true)
        end

        function refreshFigure(obj)
            % Update all analysis figures with current data without recomputing.
            %
            % Refreshes the visual display of all analysis modules using existing
            % processed data. Faster than :meth:`refresh` since it skips data
            % recomputation.
            arguments
                obj BecExp
            end
            if obj.NCompletedRun >= 1
                for ii = 1:numel(obj.AnalysisMethod)
                    obj.(obj.AnalysisMethod(ii)).updateFigure(obj.NCompletedRun);
                end
            end
        end

        function mData = readRun(obj,runIdx)
            % Read raw image data for specified run indices.
            %
            % Loads atom, light, and dark images from disk, applies bad pixel
            % correction, and returns as a 4D array.
            %
            % :param runIdx: Run index or indices to read
            % :type runIdx: double
            % :return: Image data with shape (:math:`N_y`, :math:`N_x`, :math:`N_\mathrm{run}`, 3)
            % :rtype: double
            runIdx = string(runIdx(:));
            runPath = fullfile(obj.DataPath,obj.DataPrefix) + "_" + runIdx ...
                + ["_atom","_light","_dark"] + obj.DataFormat;
            mData = zeros([obj.Acquisition.ImageSize,numel(runIdx),3]);
            for ii = 1:numel(runIdx)
                for jj = 1:3
                    mData(:,:,ii,jj) = imread(runPath(ii,jj));
                end
            end
            mData = double(mData);
            mData = obj.Acquisition.killBadPixel(mData);
        end

        function roiData = readRunRoi(obj,runIdx)
            % Read ROI-cropped image data for specified run indices.
            %
            % Similar to :meth:`readRun` but returns only the ROI-selected regions
            % to reduce memory usage and improve processing speed. Uses parallel
            % processing when available.
            %
            % :param runIdx: Run index or indices to read
            % :type runIdx: double
            % :return: ROI-cropped image data with shape (:math:`N_{y,\mathrm{ROI}}`, :math:`N_{x,\mathrm{ROI}}`, :math:`N_\mathrm{run}`, 3)
            % :rtype: double
            runIdx = string(runIdx(:));
            nRun = numel(runIdx);
            runPath = fullfile(obj.DataPath,obj.DataPrefix) + "_" + runIdx ...
                + ["_atom","_light","_dark"] + obj.DataFormat;
            acq = obj.Acquisition;
            roi = obj.Roi;
            roiSize = roi.CenterSize(3:4);
            roiData = zeros([roiSize,nRun,3]);
            p = gcp('nocreate');
            if isempty(p) || p.NumWorkers <= 2
                for ii = 1:nRun
                    for jj = 1:3
                        roiData(:,:,ii,jj) = roi.select(acq.killBadPixel(double(imread(runPath(ii,jj)))));
                    end
                end
            else
                parfevalOnAll(@warning,0,'off','all');

                % Preallocate future array
                futures(nRun) = parallel.FevalFuture;

                % Submit async jobs
                for ii = 1:nRun
                    futures(ii) = parfeval(@processOneRun, 1,runPath(ii,:));
                end

                % Collect results
                for ii = 1:nRun
                    [completedIdx, value] = fetchNext(futures);
                    roiData(:,:,completedIdx,:) = value;  % assign the 3-jj slice
                end

                parfevalOnAll(@warning,0,'on','all');
            end

            % Read one run function
            function data = processOneRun(filePaths)
                % Process one run's image files in parallel worker.
                %
                % :param filePaths: Array of file paths for [atom, light, dark] images
                % :type filePaths: string
                % :return: ROI-selected image data for one run
                % :rtype: double
                data = zeros([roiSize, 1, 3]);  % adjust dimensions as needed
                for kk = 1:3
                    data(:,:,1,kk) = roi.select(acq.killBadPixel(double(imread(filePaths(kk)))));
                end
            end
        end

        function deleteRun(obj,runIdx)
            % Delete run data (images, logs) and update in-memory tables.
            %
            % :param runIdx: Run index or indices to delete
            % :type runIdx: double|double[]
            if isempty(runIdx)
                return
            elseif obj.IsAcquiring
                obj.displayLog("Still saving images. Can not delete now.","warning")
                return
            end
            obj.displayLog("Deleting Run " + join("#"+string(runIdx),", ") + ".")
            runIdx = round(runIdx);
            NComp = obj.NCompletedRun;
            dataPath = obj.DataPath;
            dataFormat = obj.DataFormat;
            dataPrefix = obj.DataPrefix;
            ciceroLogPath = obj.CiceroLogPath;
            hardwareLogPath = obj.HardwareLogPath;

            %% Validate input run numbers
            if any(runIdx<1)
                error("Run number has to be greater than zero.")
            end

            if any(runIdx>NComp)
                warning("Input run numbers are greater than the number of completed runs. Will try to delete residual files.")
                obj.DeletedRunVariableList = [obj.DeletedRunVariableList,obj.ScannedVariableList(runIdx(runIdx<=NComp))];
                obj.NCompletedRun = NComp - sum(runIdx<=NComp);
            else
                try
                    obj.DeletedRunVariableList = [obj.DeletedRunVariableList,obj.ScannedVariableList(runIdx(runIdx<=NComp))];
                catch
                end
                obj.NCompletedRun = NComp - numel(runIdx);
            end

            if obj.NCompletedRun > 0
                obj.NRun = obj.NCompletedRun;
            else
                obj.NRun = 1;
            end

            %% Delete image files
            fList = dir(fullfile(dataPath,"*"+dataFormat));
            imageList = string({fList.name});
            if ~isempty(imageList)
                imageNumberList = arrayfun(@(x) str2double(regexp(x,'\d*','match')),imageList);
                deleteList = imageList(ismember(imageNumberList,runIdx));
                for ii = 1:numel(deleteList)
                    deleteFile(fullfile(dataPath,deleteList(ii)))
                end
            end

            %% Rename the rest of the image files
            fList = dir(fullfile(dataPath,"*"+dataFormat));
            oldImageList = string({fList.name});
            if ~isempty(oldImageList)
                oldImageNumbers = zeros(1,numel(oldImageList));
                for ii = 1:numel(oldImageList)
                    str = split(oldImageList(ii),"_");
                    oldImageNumbers(ii) = str2double(regexp(str(2),'\d*','match'));
                end
                [oldImageNumbers,idx] = sort(oldImageNumbers);
                oldImageList = oldImageList(idx);
                newImageNumbers = cumsum([1,logical(diff(oldImageNumbers))]);
                for ii = 1:numel(oldImageList)
                    str = split(oldImageList(ii),"_");
                    str(2) = newImageNumbers(ii);
                    newImageName = strjoin(str,"_");
                    if oldImageList(ii) ~= newImageName
                        try
                            movefile(fullfile(dataPath,oldImageList(ii)),fullfile(dataPath,newImageName),'f')
                        catch me
                            warning(me.message)
                        end
                    end
                end
            end

            %% Delete CiceroData
            if ~isempty(obj.CiceroData)
                if numel(obj.CiceroData.IterationNum) ~= NComp
                    warning("CiceroData size is different from the completed run number. Will try to read Cicero log files.")
                    obj.CiceroData = obj.readCiceroLog(1:NComp);
                end
                if numel(obj.CiceroData.IterationNum) ~= NComp
                    warning("CiceroData size is different from the completed run number. Will not delete corresponding data in CiceroData.")
                else
                    deleteIdx = runIdx(runIdx<=NComp);
                    sData = obj.CiceroData;
                    mData = cell2mat(struct2cell(sData));
                    mData(:,deleteIdx) = [];
                    obj.CiceroData = cell2struct(num2cell(mData,2),fieldnames(obj.CiceroData));
                    obj.CiceroLogTime(deleteIdx) = [];
                end
            end

            %% Delete Cicero files
            fList = dir(fullfile(ciceroLogPath,"*.clg"));
            cLogList = string({fList.name});
            if ~isempty(cLogList)
                cLogNumberList = arrayfun(@(x) str2double(regexp(x,'\d*','match')),cLogList);
                deleteList = cLogList(ismember(cLogNumberList,runIdx));
                for ii = 1:numel(deleteList)
                    deleteFile(fullfile(ciceroLogPath,deleteList(ii)))
                end
            end

            %% Rename the rest of the Cicero files
            fList = dir(fullfile(ciceroLogPath,"*.clg"));
            oldCLogList = string({fList.name});
            if ~isempty(oldCLogList)
                oldCLogNumbers = zeros(1,numel(oldCLogList));
                for ii = 1:numel(oldCLogList)
                    str = split(oldCLogList(ii),"_");
                    oldCLogNumbers(ii) = str2double(regexp(str(2),'\d*','match'));
                end
                [oldCLogNumbers,idx] = sort(oldCLogNumbers);
                oldCLogList = oldCLogList(idx);
                newCLogNumbers = cumsum([1,logical(diff(oldCLogNumbers))]);
                for ii = 1:numel(oldCLogList)
                    str = split(oldCLogList(ii),"_");
                    str(2) = newCLogNumbers(ii);
                    newCLogName = strjoin(str,"_") + ".clg";
                    if oldCLogList(ii) ~= newCLogName
                        movefile(fullfile(ciceroLogPath,oldCLogList(ii)),fullfile(ciceroLogPath,newCLogName),'f')
                    end
                end
            end

            %% Delete HardwareData
            if ~isempty(obj.HardwareData)
                sData = obj.HardwareData;
                mData = cell2mat(struct2cell(sData));
                if size(mData,2) ~= NComp
                    warning("HardwareData size is different from the completed run number. Will not delete corresponding data in HardwareData.")
                else
                    deleteIdx = runIdx(runIdx<=NComp);
                    mData(:,deleteIdx) = [];
                    obj.HardwareData = cell2struct(num2cell(mData,2),fieldnames(obj.HardwareData));
                end
            end

            %% Delete hardware log files
            fList = dir(fullfile(hardwareLogPath));
            fList = fList(~[fList.isdir]);
            hLogList = string({fList.name});
            if ~isempty(hLogList)
                hLogNumberList = arrayfun(@(x) str2double(regexp(x,'\d*','match')),hLogList);
                deleteList = hLogList(ismember(hLogNumberList,runIdx));
                for ii = 1:numel(deleteList)
                    deleteFile(fullfile(hardwareLogPath,deleteList(ii)))
                end
            end

            %% Rename the rest of the hardware log files
            fList = dir(fullfile(hardwareLogPath));
            fList = fList(~[fList.isdir]);
            oldHLogList = string({fList.name});
            if ~isempty(oldHLogList)
                oldHLogNumbers = zeros(1,numel(oldHLogList));
                for ii = 1:numel(oldHLogList)
                    str = split(oldHLogList(ii),"_");
                    oldHLogNumbers(ii) = str2double(regexp(str(2),'\d*','match'));
                end
                [oldHLogNumbers,idx] = sort(oldHLogNumbers);
                oldHLogList = oldHLogList(idx);
                newHLogNumbers = cumsum([1,logical(diff(oldHLogNumbers))]);
                for ii = 1:numel(oldHLogList)
                    str = split(oldHLogList(ii),"_");
                    str(2) = newHLogNumbers(ii);
                    newHLogName = strjoin(str,"_");
                    if oldHLogList(ii) ~= newHLogName
                        try
                            movefile(fullfile(hardwareLogPath,oldHLogList(ii)),fullfile(hardwareLogPath,newHLogName),'f')
                        catch me
                            warning(me.message)
                        end
                    end
                end
            end

            %% Reset existed log file number
            obj.countExistedLog

            %% Refresh
            obj.refresh;

        end

        function countExistedLog(obj)
            % Count existing Cicero and hardware log files in origin directories.
            %
            % Updates counters for pre-existing log files to distinguish new
            % files generated during the current experiment run.
            obj.ExistedCiceroLogNumber = countFileNumber(obj.CiceroLogOrigin,".clg");
            obj.coutExistedHardwareLog
        end

        function coutExistedHardwareLog(obj)
            % Count existing hardware log files for all configured devices.
            %
            % Updates the hardware log file counters by checking each device's
            % data path for pre-existing log files.
            obj.ExistedHardwareLogNumber = arrayfun(@countFileNumber,obj.HardwareList.readColumn("DataPath"));
        end

        function [sData, readsuccess] = readCiceroLog(obj,runIdx)
            % Read and deserialize Cicero log files for specified runs.
            %
            % Loads binary Cicero log files (.clg) and extracts sequence variables
            % using .NET binary formatter. Handles file access errors gracefully.
            %
            % :param runIdx: Run index or indices to read
            % :type runIdx: double
            % :return: Structure with sequence variables per run, and success flag
            % :rtype: struct, logical
            readsuccess=false;
            try
                runIdx = string(runIdx(:));
                logName = fullfile(obj.CiceroLogPath,obj.DataPrefix) + "_" + runIdx ...
                    + ".clg";
                dataStructuresLibrary=[matlabroot '\bin\win64\DataStructures.dll'];
                ds=NET.addAssembly(dataStructuresLibrary);
                import ds.*
                serializer=System.Runtime.Serialization.Formatters.Binary.BinaryFormatter;
                sData=struct;
                for ii = 1:numel(runIdx)
                    inputstream=System.IO.FileStream(logName(ii),...
                        System.IO.FileMode.Open,System.IO.FileAccess.Read,System.IO.FileShare.Read);
                    ret_obj=serializer.Deserialize(inputstream);
                    for kk=1:ret_obj.RunSequence.Variables.Count
                        thisvar=Item(ret_obj.RunSequence.Variables,kk-1);
                        variable_name=strrep(char(thisvar.VariableName), ' ', '');
                        variable_value=double(thisvar.VariableValue);
                        if ii > 1
                            sData.(variable_name)=[sData.(variable_name),variable_value];
                        else
                            sData.(variable_name)=variable_value;
                        end
                    end
                    % for kk=1:ret_obj.RunSettings.PermanentVariables.Count
                    %     thisvar=Item(ret_obj.RunSequence.Variables,kk-1);
                    %     variable_name=strrep(char(thisvar.VariableName), ' ', '');
                    %     variable_value=double(thisvar.VariableValue);
                    %     if ii > 1
                    %         sData.(variable_name)=[sData.(variable_name),variable_value];
                    %     else
                    %         sData.(variable_name)=variable_value;
                    %     end
                    % end
    
                    inputstream.Close %Need to be closed otherwise we can not delete the log file if we want
                end
                readsuccess=true;
            catch
                inputstream.Close
                sData=struct;
                sData=false;
            end
        end

        function isFetched = fetchCiceroLog(obj,runIdx)
            % Wait for and move new Cicero log file from origin to trial directory.
            %
            % Monitors the origin directory for new .clg files, waits up to 10 seconds
            % for file creation, then attempts to move it to the trial log folder
            % with proper naming convention.
            %
            % :param runIdx: Run number for file naming
            % :type runIdx: double
            % :return: True if log file was successfully fetched and moved
            % :rtype: logical
            obj.displayLog("Fetching the Cicero log file for run #" + num2str(runIdx) + ".")
            newLogNum = 0; % Number of new log files.
            t = 0; % Total pause time.
            tPause = 0.1; % Pause time.
            existedLogNum = obj.ExistedCiceroLogNumber; % Number of old log files.
            originPath = obj.CiceroLogOrigin;
            dataPrefix = obj.DataPrefix;
            isFetched = false; % Error flag

            % Scan the origin folder to find if a new log file is created.
            while newLogNum<1 && t<10
                pause(tPause)
                newLogNum = countFileNumber(originPath,".clg") - existedLogNum;
                if newLogNum>1
                    obj.displayLog(">1 log files found","warning")
                    return
                end
                t = t + tPause;
            end

            if t>= 10
                obj.displayLog("Can not find a log file in 10 seconds","warning")
                return
            end

            % Get the newest log file.
            logList = string(ls(originPath));
            logList = logList(3:end);
            logList = sort(logList);
            newLogPath = fullfile(originPath,logList(end));
            obj.CiceroLogTime(runIdx) = datetime;

            % Try moving the log file to the data path.
            t = 0;
            moveStatus = false;
            tPause2 = 0.5;
            while t<5 && ~moveStatus
                pause(tPause2)
                try
                    moveStatus = movefile(newLogPath,...
                        fullfile(obj.CiceroLogPath,dataPrefix + "_" + num2str(runIdx)+".clg"),'f');
                catch
                end
                t = t+tPause2;
            end

            if t >= 5
                obj.displayLog("Can not move the log file in 5 seconds","warning")
                return
            end

            isFetched = true;

        end

        function fetchHardwareLog(obj,runIdx)
            % Trigger scope data collection and fetch hardware log files.
            %
            % Commands the hardware control panel to read current scope data,
            % then searches for and moves new hardware log files from device
            % directories to the trial hardware log folder.
            %
            % :param runIdx: Run number for file naming
            % :type runIdx: double
            obj.displayLog("Reading scope data for run #" + num2str(runIdx) + ".")
            hwApp = get(findall(0, 'Tag', "HwControlPanel"), 'RunningAppInstance');
            if ~isempty(hwApp)
                if isvalid(hwApp)
                    hwApp.readScope;
                end
            end
            obj.displayLog("Fetching the hardware log files for run #" + num2str(runIdx) + ".")
            existedLogNum = obj.ExistedHardwareLogNumber; % Number of old log files.
            hardwareList = obj.HardwareList;
            dataPrefix = obj.DataPrefix;

            % Scan the origin folder to find if a new log file is created.
            newLogNum = arrayfun(@countFileNumberJava,hardwareList.readColumn("DataPath")) - existedLogNum;
            if any(newLogNum>1)
                warning('>1 hardware log files found.')
            end
            newLogList = hardwareList.readEntry(newLogNum == 1);

            if isempty(newLogList)
                obj.displayLog("No hardware data found.")
                return
            end

            % Get the newest log file.
            newLogPath = arrayfun(@findLatestFile,newLogList.DataPath,UniformOutput=false);

            % Try moving the log file to the data path.
            for ii = 1:numel(newLogPath)
                if ~isempty(newLogPath{ii})
                    obj.displayLog("Fetching " + newLogList.Name(ii))
                    [~,~,ext] = fileparts(newLogPath{ii});
                    movefile(newLogPath{ii},...
                        fullfile(obj.HardwareLogPath,dataPrefix + "_" + num2str(runIdx)) + "_" + newLogList.Name(ii) + ext,'f');
                end
            end

        end

        function setHardware(obj)
            % Configure hardware settings and upload to hardware control panel.
            %
            % Reads trial-specific hardware associations from the database,
            % updates hardware settings, and uploads configurations to the
            % hardware control panel application.

            %% Set HardwareSetting
            obj.displayLog("Checking hardware associations...")
            t = obj.HardwareAssociation.readEntry(obj.ConfigParameter.ID,"TrialID",true);
            if isempty(t)
                obj.displayLog("Found no hardware association.")
                return
            end
            if isstruct(t)
                t = struct2table(t);
            end
            t = renamevars(t,"SettingID","ID");
            p = HardwareSetting;
            p.updateEntry(t)
            hwId = unique(p.readValue(t.ID,"HardwareID"));

            %% Get the HardwareControlPanel app and upload
            hwApp = get(findall(0, 'Tag', "HwControlPanel"), 'RunningAppInstance');
            if isempty(hwApp)
                hwApp = HardwareControlPanel;
            end
            hwApp.setAssociation(hwId);

        end

        function unlock(obj)
            % Unlock phase locks through hardware control panel.
            %
            % Attempts to disable phase locks via the hardware control panel
            % application. Issues a warning if unlocking fails due to hardware
            % connection issues.
            hwApp = get(findall(0, 'Tag', "HwControlPanel"), 'RunningAppInstance');
            if ~isempty(hwApp)
                hwApp = HardwareControlPanel;
                try
                    hwApp.unlock;
                catch
                    obj.displayLog("Can not unlock. Please check if phase lock is connected","warning")
                end
            end
        end
        
        function updateHardware(obj)
            % Read current hardware values into :attr:`HardwareData` and update UI.
            hwApp = get(findall(0, 'Tag', "HwControlPanel"), 'RunningAppInstance');
            if ~isempty(hwApp)
                if isvalid(hwApp)
                    hardwareData = table2cell(obj.VariableList.readColumn(["Name","CurrentValue"]));
                    hardwareData = cell2struct(hardwareData(:,2),string(hardwareData(:,1)));
                    if isempty(obj.HardwareData)
                        obj.HardwareData = hardwareData;
                    else
                        f = fields(obj.HardwareData);
                        for ii = 1:numel(f)
                            obj.HardwareData.(f{ii}) = [obj.HardwareData.(f{ii}),hardwareData.(f{ii})];
                        end
                    end
                    hwApp.update
                end
            end

        end

        function updateScopeData(obj)
            % Update scope-derived measurement values from hardware logs.
            %
            % Reads oscilloscope data from hardware log files and extracts
            % measurement values (RMS, peak, etc.) for channels specified in
            % the scanned variables or scope value analysis.
            fullValueName = string.empty;
            if contains(obj.ScannedVariable,"Scope","IgnoreCase",true)
                fullValueName = [fullValueName,obj.ScannedVariable];
            end
            if isprop(obj,"ScopeValue") && ~isempty(obj.ScopeValue.FullValueName)
                fullValueName = [fullValueName,obj.ScopeValue.FullValueName];
            end
            if isempty(fullValueName)
                return
            end
            fullValueName = unique(fullValueName);
            currentRunNumber = obj.NCompletedRun;
            for kk = 1:numel(fullValueName)
                C = strsplit(fullValueName(kk),"_");
                scopeName = C(1);
                channelName = C(2);
                valueName = C(3);
                channelNumber = getNumberFromString(channelName);
                if isfield(obj.ScopeData,fullValueName(kk)) && numel(obj.ScopeData.(fullValueName(kk))) == (currentRunNumber - 1)
                    obj.ScopeData.(fullValueName(kk))(end+1) = readRun(currentRunNumber,scopeName,valueName,channelNumber);
                elseif isfield(obj.ScopeData,fullValueName(kk)) && numel(obj.ScopeData.(fullValueName(kk))) == currentRunNumber
                    continue
                else
                    for ii = 1:currentRunNumber
                        obj.ScopeData(1).(fullValueName(kk))(ii) = readRun(ii,scopeName,valueName,channelNumber);
                    end
                end
            end

            function value = readRun(runIdx,sName,vName,cNumber)
                % Read specific scope measurement value from hardware log file.
                %
                % :param runIdx: Run number
                % :type runIdx: double
                % :param sName: Scope device name
                % :type sName: string
                % :param vName: Measurement value name (e.g., "Rms", "Peak")
                % :type vName: string  
                % :param cNumber: Channel number
                % :type cNumber: double
                % :return: Measurement value for specified channel
                % :rtype: double
                try
                    scopeData = loadVar(fullfile(obj.HardwareLogPath,obj.DataPrefix + "_" + num2str(runIdx)) + "_" + sName + ".mat");
                catch
                    error(sName+" has no data fetched in HardwareLogPath.")
                end
                if ~scopeData.IsEnabled(cNumber)
                    error("Channel"+cNumber+" of "+sName+" was disabled.")
                end
                valueIdx = (cNumber == find(scopeData.IsEnabled));
                try
                    valueList = scopeData.(vName);
                catch
                    error(vName + " is not a valid scope value.")
                end
                value = valueList(valueIdx);
            end
        end

        function writeDatabase(obj)
            % Write trial metadata to PostgreSQL database.
            %
            % Converts trial object to table format and writes to database,
            % excluding transient analysis method references.
            sData = struct(obj);
            sData = rmfield(sData,{'AnalysisMethod'});
            tData = struct2table(sData,AsArray=true);
            pgWrite(obj.Writer,obj.DatabaseTableName,tData);
        end

        function updateDatabase(obj)
            % Update existing database entry with current trial state.
            %
            % Updates the database record with current trial metadata, Cicero
            % data, and hardware data using the trial's serial number as key.
            obj.displayLog("Updating the database entry.")
            sData = struct(obj);
            tData = struct2table(sData,AsArray=true);
            tDataCicero = struct2table(obj.CiceroData,AsArray=true);
            tDataHardware = struct2table(obj.HardwareData,AsArray=true);
            rf = rowfilter('SerialNumber');
            rf = rf.SerialNumber == obj.SerialNumber;
            pgUpdate(obj.Writer,obj.DatabaseTableName,tData,rf);
            if ~isempty(tDataCicero)
                pgUpdate(obj.Writer,obj.DatabaseTableName,tDataCicero,rf,isForceArray = true);
            end
            if ~isempty(tDataHardware)
                pgUpdate(obj.Writer,obj.DatabaseTableName,tDataHardware,rf,isForceArray = true);
            end
        end

        function set.IsUseWeightedPosition(obj, value)
            if ~isempty(obj.CenterFit)
                obj.CenterFit.IsUseWeighted=value;
            end
        end
    end

    methods (Hidden)

        function setFolder(obj)
            % Create data storage folder hierarchy and set analysis paths.
            %
            % Creates nested directory structure organized by date and trial index:
            % ``[ParentPath]\year\year.month\month.day\[datafolder]``
            % where ``[datafolder]`` is named as ``idx1 - Name_idx2_Trial_serialNumber``
            % with idx1 being the daily folder index and idx2 the daily trial index
            % for the given name.

            %% Look at the watch
            t = obj.DateTime;
            mm = num2str(t.Month,'%02u');
            dd = num2str(t.Day,'%02u');
            yyyy = num2str(t.Year);

            %% Delimiters
            dateDelimiter = '.'; %These delimiters are arbitrary.
            indexDelimiter = '-';
            trialDelimiter = '_';

            %% Create date folder
            obj.DatePath = string(fullfile(obj.ParentPath,yyyy,[yyyy,dateDelimiter,mm], ...
                [mm,dateDelimiter,dd]));
            createFolder(obj.DatePath); %Create the Date folder if it doesn't exist.

            %% Find trial index
            todaystr = string(datetime("today",Format='yyyy-MM-dd'));
            if obj.IsAutoDelete == true %Delete trials with no data collected
                query = "SELECT ""SerialNumber"" FROM " + obj.DatabaseTableName + " WHERE ""DateTime"" >= '" + todaystr + "'" + " AND " +...
                    """DateTime"" <= '" + todaystr + " 23:59:59" + "'" + " AND ""NCompletedRun"" = 0;";
                emptyData = pgFetch(obj.Writer,query);
                deleteTrial(obj.Writer,obj.DatabaseTableName,emptyData.SerialNumber,true) %Delete folders with no data.
            end

            query = "SELECT ""SerialNumber"" FROM " + obj.DatabaseTableName + " WHERE ""Name"" = '" + obj.Name + "'" + " AND " +...
                """DateTime"" >= '" + todaystr + "'" + " AND " +...
                """DateTime"" <= '" + todaystr + " 23:59:59" + "';";
            todayData = pgFetch(obj.Writer,query);
            obj.TrialIndex = size(todayData,1) + 1;

            %% Find trial number
            sqlQuery = "SELECT last_value FROM " + "public."""+obj.DatabaseTableName+"_SerialNumber_seq"";";
            data = pgFetch(obj.Writer,sqlQuery);
            trialNumber = data.last_value + 1;

            %% Find data folder index
            newestFolderList = sortNewestFolder(obj.DatePath);
            newestFolderList = newestFolderList(cellfun(@(x) contains(x,indexDelimiter),{newestFolderList.name}));
            if isempty(newestFolderList)
                folderIndex = 1;
            else
                str = split(newestFolderList(1).name,indexDelimiter);
                folderIndex = str2double(regexp(str{1},'\d*','match'));
                folderIndex = folderIndex(1) + 1;
            end

            %% Create data folders
            obj.DataPath = fullfile(obj.DatePath,num2str(folderIndex,'%02u')+" "+indexDelimiter+" "+ ...
                obj.Name+trialDelimiter+num2str(obj.TrialIndex) + trialDelimiter + "Trial" + trialDelimiter + trialNumber);
            obj.DataAnalysisPath = fullfile(obj.DataPath,'dataAnalysis');
            obj.ObjectPath = fullfile(obj.DataAnalysisPath, ...
                obj.Name+yyyy+mm+dd+trialDelimiter+num2str(obj.TrialIndex)+'.mat');
            obj.CiceroLogPath = fullfile(obj.DataPath,'logFiles');
            obj.HardwareLogPath = fullfile(obj.DataPath,'hardwareLogFiles');

            createFolder(obj.DataPath);
            createFolder(obj.DataAnalysisPath);
            createFolder(obj.CiceroLogPath);
            createFolder(obj.HardwareLogPath);

        end

        function setConfigProperty(obj,s)
            % Set object properties from structure fields.
            %
            % Compares object properties with structure fields and sets matching
            % properties to the structure values. Requires the object to inherit
            % from :class:`matlab.mixin.SetGetExactNames`.
            %
            % :param s: Structure containing property-value pairs
            % :type s: struct
            mc = metaclass(obj); %use metaclass to access non-public properties
            propList = {mc.PropertyList.Name};
            fieldList = fieldnames(s);
            [~,ia,ib] = intersect(propList,fieldList);
            structcell = struct2cell(s);
            set(obj,propList(ia)',structcell(ib)')
        end

    end

    methods (Static)
        function obj = loadobj(s)
            % Reconnect DB writer and GUI handle when the object is loaded.
            %
            % :return: Loaded object with transient handles restored when possible.
            % :rtype: :class:`Trial`

            % This is for back-ward compatibility
            if isstruct(s)
                if isfield(s,"ScannedParameter")
                    p = BecExpVariableUnit;
                    s.ScannedVariableID = p.readValue(s.ScannedParameter,"ID","ScannedVariable");
                end
                obj = BecExp(s.Name,s,true);
            else
                obj = s;
            end
            try
                obj.Writer = createWriter(obj.DatabaseName); %Create writer type database connection
            catch
            end
            if ~isempty(obj.ControlAppName)
                obj.ControlApp = get(findall(0, 'Tag', obj.ControlAppName), 'RunningAppInstance');
            end
        end
    end
end

