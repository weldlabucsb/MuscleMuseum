% This is a function to set the configuration file
function setParameter
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

%% Set computer configuration

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

%% Set database configuration
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

%% Set database server configuration
if exist('ServerName','var')
    Name = ServerName;
    t = table(Name,Port,Username,Password);
    updateConfig("DatabaseServerConfig",t)
end

%% Set acquisition configuration
if exist('AcquisitionName','var')
    Name = AcquisitionName;
    DeviceModel = CameraDeviceModel;
    DeviceID = CameraDeviceID;
    SerialNumber = CameraSerialNumber;
    t = table(Name,DeviceModel,DeviceID,SerialNumber,ExposureTime,...
        BadRow,Magnification,Transmission);
    updateConfig("AcquisitionConfig",t)
end

%% Set waveform generator configuration
if exist('WgName','var')
    Name = WgName;
    DeviceModel = WgDeviceModel;
    ResourceName = WgResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("WaveformGeneratorConfig",t)
end

%% Set scope configuration
if exist("ScopeName",'var')
    Name = ScopeName;
    DeviceModel = ScopeDeviceModel;
    ResourceName = ScopeResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("ScopeConfig",t)
end

%% Set phase lock configuration
if exist("PlName",'var')
    Name = PlName;
    DeviceModel = PlDeviceModel;
    ResourceName = PlResourceName;
    t = table(Name,DeviceModel,ResourceName);
    updateConfig("PhaseLockConfig",t)
end

%% Set hardware list
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

%% Set BEC experiment configuration
if exist("BecExpDataPrefix","var")
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

    userParameter = [
        "ParentPath";
        "DataPrefix";
        "DataFormat";
        "IsAutoDelete";
        "DatabaseName";
        "DatabaseTableName";
        "DataGroupSize";
        "IsAutoAcquire";
        "OdColormap";
        "AtomName";
        "ImagingStageList";
    ];
    userParameter2 = intersect("BecExp"+userParameter,varList);
    userParameter = replace(userParameter2,"BecExp","");
    s = struct;
    s.IsLocalTest = false;
    for ii = 1:numel(userParameter)
        s.(userParameter(ii)) = eval(userParameter2(ii));
    end
    s.ControlAppName = "BecControl";
    if exist('CiceroLogOrigin','var')
        s.CiceroLogOrigin = CiceroLogOrigin;
    end
    updateConfig("BecExpConfig",s)
end

%% Set BEC experiment local test configuration
if exist("BecExpDataPrefix","var")
    s.IsLocalTest = true;
    s.DatabaseName = BecExpDatabaseName + "_local";
    s.ParentPath = fullfile(mainPath,"becExp");
    s.CiceroLogOrigin = fullfile(RepoPath,"test","testData","testLogFiles");
    s.IsAutoAcquire= false;
    s.IsAutoDelete = false;
    p = BecExpConfig;
    p.writeEntry(s)
end

disp("Done.")

%% Check setting
disp(newline + "Checking user settings...")
settingList = [
    "WaveformGeneratorSetting";
    "PhaseLockSetting";
    "ScopeSetting";
    "ListList";
    "VariableList";
    "BecExpSetting";
    "BecExpParameterUnit";
    "RoiSetting";
    "WaveformLibrary";
    "WaveformListLibrary";
    ];

for ii = 1:numel(settingList)
    s = eval(settingList(ii));
    s.checkTable;
end
disp("Done.")

end