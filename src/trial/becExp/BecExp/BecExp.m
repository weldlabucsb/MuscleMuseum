classdef BecExp < Trial
    %BecExp This is BecExp. Test Test.
    %   Detailed explanation goes here
    properties
        Roi Roi
        SubRoi Roi
        Acquisition Acquisition
        AnalysisMethod string % List of analysis methods
        CloudCenter double % Cloud center [y_0,x_0] from previous measurement, in pixels
        AveragingMethod string = "StdErr" %Averaging method
    end

    properties(Dependent)
        ScannedVariable string
        ScannedVariableUnit string  
        ScannedVariable2 string  
        ScannedVariableUnit2 string  
    end

    properties(Hidden)
        ScannedVariableID (1,1) double = 1
        ScannedVariableID2 (1,1) double = 0
        IsAutoAcquire logical = false %If we want to automatically set the camera through MATLAB
        IsHoldRefresh logical = false
        IsAcquiring logical = false %If the program is still acquiring images
        IsOdPreview logical = false
    end

    properties (Hidden,Transient)
        ExistedCiceroLogNumber %Count the number of log files that are already in the Origin folder.
        ExistedHardwareLogNumber %Count the number of hardware log files that are already in the folder.
    end

    properties (SetAccess = private, Hidden)
        CiceroLogOrigin = "."
        CiceroLogPath string
        CiceroLogTime datetime
        DeletedRunVariableList
        VariableUnitSetting
        HardwareList
        VariableList
        HardwareAssociation
        HardwareLogPath string
    end

    properties (SetAccess = private)
        CiceroData struct
        HardwareData struct
        ScopeData struct
        Atom Atom
    end

    properties (Dependent,Hidden)
        ScannedVariableList
        RunListSorted
        ScannedVariableListSorted
        XLabel
        YLabel                     % Y-axis label for 2D scans
        VariableGrid              % 2D parameter grid for 2D scans
    end

    properties (Constant,Hidden)
        AnalysisOrder = {"Od";"Imaging";"Ad";...
            "DensityFit";["AtomNumber";"Tof";"CenterFit";"KapitzaDirac"];"ScopeValue"}
    end

    methods
        function obj = BecExp(trialName,config,isLoad)
            %BECEXP Construct an instance of this class
            %   Detailed explanation goes here
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
                    obj.AnalysisMethod]);
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
            obj.VariableUnitSetting = BecExpVariableUnit;
            obj.HardwareList = HardwareList;
            obj.VariableList = VariableList;
            obj.HardwareAssociation = HardwareAssociation;
        end
        
        function var1 = get.ScannedVariable(obj)
            id = obj.ScannedVariableID;
            var1 = obj.VariableUnitSetting.readValue(id,"ScannedVariable");
        end

        function var2 = get.ScannedVariable2(obj)
            id = obj.ScannedVariableID2;
            if id == 0
                var2 = "None";
            else
                var2 = obj.VariableUnitSetting.readValue(id,"ScannedVariable");
            end
        end

        function unit1 = get.ScannedVariableUnit(obj)
            id = obj.ScannedVariableID;
            unit1 = obj.VariableUnitSetting.readValue(id,"ScannedVariableUnit");
        end

        function unit2 = get.ScannedVariableUnit2(obj)
            id = obj.ScannedVariableID2;
            if id == 0
                unit2 = "None";
            else
                unit2 = obj.VariableUnitSetting.readValue(id,"ScannedVariableUnit");
            end
        end
        
        function varList = get.ScannedVariableList(obj)
            if obj.Is2DScan
                % For 2D scans, return a 2xN matrix with both parameters
                var1 = obj.ScannedVariable;
                var2 = obj.ScannedVariable2;
                
                % Get first parameter values
                switch var1
                    case "RunIndex"
                        varList1 = double(1:obj.NCompletedRun);
                    case "CiceroLogTime"
                        if ~isempty(obj.CiceroLogTime)
                            varList1 = obj.CiceroLogTime;
                            varList1 = varList1 - varList1(1);
                            varList1 = seconds(varList1);
                        else
                            varList1 = [];
                        end
                    otherwise
                        if isfield(obj.CiceroData,var1)
                            varList1 = obj.CiceroData.(var1);
                        elseif isfield(obj.HardwareData,var1)
                            varList1 = obj.HardwareData.(var1);
                        else
                            obj.updateScopeData
                            if isfield(obj.ScopeData,var1)
                                varList1 = obj.ScopeData.(var1);
                            else
                                varList1 = [];
                            end
                        end
                end
                
                % Get second parameter values
                switch var2
                    case "RunIndex"
                        varList2 = double(1:obj.NCompletedRun);
                    case "CiceroLogTime"
                        if ~isempty(obj.CiceroLogTime)
                            varList2 = obj.CiceroLogTime;
                            varList2 = varList2 - varList2(1);
                            varList2 = seconds(varList2);
                        else
                            varList2 = [];
                        end
                    otherwise
                        if isfield(obj.CiceroData,var2)
                            varList2 = obj.CiceroData.(var2);
                        elseif isfield(obj.HardwareData,var2)
                            varList2 = obj.HardwareData.(var2);
                        else
                            obj.updateScopeData
                            if isfield(obj.ScopeData,var2)
                                varList2 = obj.ScopeData.(var2);
                            else
                                varList2 = [];
                            end
                        end
                end
                
                % Return 2xN matrix
                if ~isempty(varList1) && ~isempty(varList2)
                    varList = [varList1; varList2];
                else
                    varList = [];
                end
            else
                % 1D scan - original logic
                switch obj.ScannedVariable
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
                        if isfield(obj.CiceroData,obj.ScannedVariable)
                            varList = obj.CiceroData.(obj.ScannedVariable);
                        elseif isfield(obj.HardwareData,obj.ScannedVariable)
                            varList = obj.HardwareData.(obj.ScannedVariable);
                        else
                            obj.updateScopeData
                            if isfield(obj.ScopeData,obj.ScannedVariable)
                                varList = obj.ScopeData.(obj.ScannedVariable);
                            else
                                varList = [];
                            end
                        end
                end
            end
        end

        function runListSorted = get.RunListSorted(obj)
            varList = obj.ScannedVariableList;
            [~,runListSorted] =  sort(varList,2);
        end

        function varListSorted = get.ScannedVariableListSorted(obj)
            varList = obj.ScannedVariableList;
            [varListSorted,~] =  sort(varList,2);
        end

        function xLabel = get.XLabel(obj)
            sP = obj.ScannedVariable;
            sP = strrep(sP,'_','\_');
            if obj.ScannedVariableUnit == "None"
                xLabel = sP;
            else
                xLabel = sP + "~[$\mathrm{" + obj.ScannedVariableUnit + "}$]";
            end
        end

        function yLabel = get.YLabel(obj)
            if ~obj.Is2DScan
                yLabel = "";
                return
            end
            
            sP = obj.ScannedVariable2;
            sP = strrep(sP,'_','\_');
            if obj.ScannedVariable2Unit == "None"
                yLabel = sP;
            else
                yLabel = sP + "~[$\mathrm{" + obj.ScannedVariable2Unit + "}$]";
            end
        end

        function l = ScannedVariableLabel(obj,runNumber)
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
            % Create 2D parameter grid for 2D scans
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
    end

    methods

        function setAnalyzer(obj)
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
            %ADDANALYSIS Summary of this function goes here
            %   Detailed explanation goes here
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
            %REMOVEANALYSIS Summary of this function goes here
            %   Detailed explanation goes here
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
            %SORTANALYSIS Summary of this function goes here
            %   We need to run different analysis in certain order so we have to sort
            %   the analysis methods
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
            %PAUSE Summary of this function goes here
            %   Detailed explanation goes here
            obj.displayLog("Pausing data acquisition and real-time analysis.")
            if obj.IsAutoAcquire
                obj.Acquisition.pauseCamera;
            else
                obj.Watcher.Enabled = false;
            end
            obj.Analyzer.Enabled = false;
        end

        function resume(obj)
            %RESUME Summary of this function goes here
            %   Detailed explanation goes here
            obj.displayLog("Resuming data acquisition and real-time analysis.")

            obj.ExistedCiceroLogNumber = countFileNumber(obj.CiceroLogOrigin,".clg");

            if obj.IsAutoAcquire
                obj.Acquisition.startCamera;
            else
                obj.Watcher.Enabled = true;
            end
            obj.Analyzer.Enabled = true;
        end

        function stop(obj)
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
            %SHOW Summary of this function goes here
            %   Detailed explanation goes here
            for ii = 1:numel(obj.AnalysisMethod)
                obj.(obj.AnalysisMethod(ii)).show;
            end
        end

        function browserShow(obj)
            %SHOW Summary of this function goes here
            %   Detailed explanation goes here
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

        function refresh(obj,anaylsisName)
            %REFRESH Summary of this function goes here
            %   Detailed explanation goes here
            arguments
                obj BecExp
                anaylsisName string = string.empty
            end
            if obj.IsHoldRefresh
                obj.displayLog("Refresh is on hold.")
                return
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
                        obj.(obj.AnalysisMethod(ii)).refresh;
                    end
                elseif ~isscalar(anaylsisName)
                    error("Input must be a string scalar.")
                elseif ~ismember(anaylsisName,vertcat(obj.AnalysisOrder{:}))
                    warning(anaylsisName + " is not in AnalysisOrder. Will refresh all.")
                    for ii = 1:nAnalysis
                        obj.(obj.AnalysisMethod(ii)).refresh;
                    end
                else
                    % First refresh [anaylsisName]
                    if ismember(anaylsisName,obj.AnalysisMethod)
                        obj.(anaylsisName).refresh
                    end

                    % Then refresh everthing after [anaylsisName]
                    orderIdx = find(cellfun(@(x) any(anaylsisName==x),obj.AnalysisOrder));
                    afterAnalysis = obj.AnalysisOrder(orderIdx+1:end);
                    afterAnalysis = vertcat(afterAnalysis{:});
                    if ~isempty(afterAnalysis)
                        aMethodIdx = find(ismember(obj.AnalysisMethod,afterAnalysis),1);
                        if ~isempty(aMethodIdx)
                            for ii = aMethodIdx:nAnalysis
                                obj.(obj.AnalysisMethod(ii)).refresh;
                            end
                        else
                            % Refresh everthing that are not in AanalysisOrder
                            extraAnalysis = obj.AnalysisMethod(~ismember(obj.AnalysisMethod,vertcat(obj.AnalysisOrder{:})));
                            for ii = 1:numel(extraAnalysis)
                                obj.(extraAnalysis(ii)).refresh;
                            end
                        end
                    end
                end
                obj.displayLog("Refresh done.")
            end
        end

        function refreshFigure(obj)
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
            %READRUNROI Summary of this function goes here
            %   Detailed explanation goes here
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
                data = zeros([roiSize, 1, 3]);  % adjust dimensions as needed
                for kk = 1:3
                    data(:,:,1,kk) = roi.select(acq.killBadPixel(double(imread(filePaths(kk)))));
                end
            end
        end

        function deleteRun(obj,runIdx)
            %DELETERUN Summary of this function goes here
            %   Detailed explanation goes here
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
            %COUNTEXISTEDLOG Summary of this function goes here
            %   Detailed explanation goes here
            obj.ExistedCiceroLogNumber = countFileNumber(obj.CiceroLogOrigin,".clg");
            obj.ExistedHardwareLogNumber = arrayfun(@countFileNumber,obj.HardwareList.readColumn("DataPath"));
        end

        function [sData, readsuccess] = readCiceroLog(obj,runIdx)
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
            %UPDATEHARDWARE Summary of this function goes here
            %   Detailed explanation goes here
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
            %UPDATESCOPEDATA Summary of this function goes here
            %   Detailed explanation goes here
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
            sData = struct(obj);
            sData = rmfield(sData,{'AnalysisMethod'});
            tData = struct2table(sData,AsArray=true);
            pgWrite(obj.Writer,obj.DatabaseTableName,tData);
        end

        function updateDatabase(obj)
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

    end

    methods (Hidden)

        function setFolder(obj)
            %SETFOLDER This method creates data storage folders and sets up data
            %analysis paths.
            %   The data are stored in the folder:
            %   [ParentPath]\year\year.month\month.day\[datafolder]
            %   [datafolder] is named as "idx1 - Name_idx2" where idx1 indicates
            %   it is the idx1-th data taken this day, and idx2 indicates it is the
            %   idx2-th data taken this day with the same Name.

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
            %This method compares the properties of the handle object 'obj' with
            %the fields of a structure 'struct'. Then it sets the properties to the
            %values of the fields. The obj must inherit the set method from
            %matlab.mixin.SetGetExactNames
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

