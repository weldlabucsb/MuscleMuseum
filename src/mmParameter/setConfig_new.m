% This is a function to set the configuration file
function setConfig_new
disp(newline + "Setting configurations...")
mmConfig; % run the user-defined script to get user configurations
varList = string(who).'; %check the user input parameters

%% Find the repo path
ConfigPath = string(findFunctionPath());
RepoPath = findFolderInPath("MuscleMuseum");
TempPath = fullfile(getenv('USERPROFILE'),"Documents","MMTemp");
if numel(RepoPath) == 0
    error("MuscleMuseum is not in MATLAB Path.")
elseif numel(RepoPath) >= 2
    error("Multiple MuscleMuseum packages are in MATLAB Path. Please resolve.")
end

%% Set the main local data path
mainPath = fullfile(getHome,"Documents","MMData");

%% Set the computer configuration

%This somehow helps with the communication speed if the CiceroLogOrigin folder is a networkfolder
if exist('BecExpControlComputerName','var') &&...
        exist('CiceroLogOrigin','var') &&...
        string(getenv('computername')) == BecExpControlComputerName
    addpath(CiceroLogOrigin); 
end

userParameters = [
"BecExpControlComputerName",...
"BecExpParentPath",...
"BecExpDatabaseName",...
"BecExpDatabaseTableName",...
"CiceroComputerName",...
"CiceroLogOrigin",...
"HardwareLogOrigin",...
];
defaultParameters = [
    "RepoPath",...
    "ConfigPath",...
    "TempPath",...
];
userParameters = join([intersect(userParameters,varList),defaultParameters],",");
t = eval("table("+userParameters+")");
updateConfig("ComputerConfig",t)

%% Set the database configuration
Name = "simulation";
if exist('BecExpDatabaseName','var')
    Name = [Name;BecExpDatabaseName];
end
TableList = {    
["master_equation_simulation",...
    "gross_pitaevskii_equation_simulation",...
    "schrodinger_equation_simulation",...
    "fokker_planck_equation_simulation",...
    "lattice_schrodinger_equation_simulation_1d",...
    "lattice_fourier_simulation_1d"]...
    };
if exist('BecExpDatabaseTableName','var')
    TableList = {TableList{1};BecExpDatabaseTableName};
end
t = table(Name,TableList); %This saves exp/sim database names and the names of the tables
updateConfig("DatabaseConfig",t)

%% Set the database server configuration
if exist('ServerName','var')
    Name = ServerName;
    t = table(Name,Port,Username,Password);
    updateConfig("DatabaseServerConfig",t)
end

%% Set the acquisition configuration
if exist('AcquisitionName','var')
    Name = AcquisitionName;
    DeviceModel = CameraDeviceModel;
    DeviceID = CameraDeviceID;
    SerialNumber = CameraSerialNumber;
    t = table(Name,DeviceModel,DeviceID,SerialNumber,ExposureTime,...
        BadRow,Magnification,Transmission);
    updateConfig("AcquisitionConfig",t)
end

%% Set the waveform generator configuration
if exist('WgName','var')
    Name = WgName;
    DeviceModel = WgDeviceModel;
    ResourceName = WgResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("WaveformGeneratorConfig",t)
end

%% Set the scope configuration
if exist("ScopeName",'var')
    Name = ScopeName;
    DeviceModel = ScopeDeviceModel;
    ResourceName = ScopeResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("ScopeConfig",t)
end

%% Set the phase lock configuration
if exist("PlName",'var')
    Name = PlName;
    DeviceModel = PlDeviceModel;
    ResourceName = PlResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("PhaseLockConfig",t)
end

%% Set the hardware list
Name = [];
Type = [];
if exist('WgName','var')
    Name = [Name;WgName];
    Type = [Type;repmat("WaveformGenerator",numel(WgName),1)];
end
if exist('ScopeName','var')
    Name = [Name;ScopeName];
    Type = [Type;repmat("Scope",numel(ScopeName),1)];
end
if exist('PlName','var')
    Name = [Name;PlName];
    Type = [Type;repmat("PhaseLock",numel(PlName),1)];
end
if ~isempty(Name)
    if exist('HardwareLogOrigin','var')
        DataPath = fullfile(HardwareLogOrigin,Name);
    else
        error("HardwareLogOrigin must be defined when hardware is used.")
    end
    t = table(Name,Type,DataPath);
    updateConfig("HardwareList",t)
end

%% Set the BEC experiment configuration

%copy the .dll for Cicero log reading
dsLibPath = fullfile(matlabroot,'\bin\win64\DataStructures.dll');
if ~exist(dsLibPath,'file')
    try
        copyfile(fullfile(RepoPath,"lib","datastructures","DataStructures.dll"),...
            fullfile(matlabroot,'\bin\win64\DataStructures.dll'),'f');
    catch
        error("No permission to copy file. Try runing MATLAB as admin.")
    end
end

BecExpConfig.ParentPath = BecExpParentPath;
BecExpConfig.DataPrefix = "run";
BecExpConfig.DataFormat = ".tif"; 
BecExpConfig.IsAutoDelete = false; %If you want to auto delete empty BecExp data folders
BecExpConfig.DatabaseName = BecExpDatabaseName;
BecExpConfig.DatabaseTableName = BecExpDatabaseTableName;
BecExpConfig.CiceroLogOrigin = CiceroLogOrigin;
BecExpConfig.DataGroupSize = 3;
BecExpConfig.IsAutoAcquire = true;
BecExpConfig.OdColormap = {jet}; %Change to your favorite colormap
BecExpConfig.AtomName = "Lithium7";
BecExpConfig.ControlAppName = "BecControl";
BecExpConfig.ImagingStageList = ["LF","HF","NI"]; %List your possible imaging stages here. For example, if you do imaging at low/high magnetic fields, type ["LF","HF"].

becExpType = readtable("becExpType.csv.xlsx",'TextType','string');
BecExpConfig = [becExpType,repmat(struct2table(BecExpConfig),size(becExpType,1),1)];
BecExpParameterUnit = readtable("parameterUnit.csv.xlsx",'TextType','string');
BecExpConfig = join(BecExpConfig,BecExpParameterUnit,'Keys',{'ScannedParameter','ScannedParameter'});

BecExpConfig.FringeRemovalMask = arrayfun(@eval,(fillmissing(BecExpConfig.FringeRemovalMask,'constant',"[]")),'UniformOutput',false);
save(configName,"BecExpConfig","BecExpParameterUnit",'-mat','-append')

%% Set the BEC experiment local test configuration
BecExpLocalTestConfig = BecExpConfig;
BecExpLocalTestConfig.DatabaseName(:) = BecExpDatabaseName + "_local";
BecExpLocalTestConfig.ParentPath(:) = fullfile(mainPath,"becExp");
BecExpLocalTestConfig.CiceroLogOrigin(:) = fullfile(RepoPath,"test","testData","testLogFiles");
BecExpLocalTestConfig.IsAutoAcquire(:) = false;
BecExpLocalTestConfig.IsAutoDelete(:) = false;

save(configName,"BecExpLocalTestConfig",'-mat','-append')

disp("Done.")

end