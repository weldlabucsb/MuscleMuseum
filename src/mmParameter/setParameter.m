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
if exist('AcquisitionConfig','var')
    if ~isempty(AcquisitionConfig)
        updateConfig("AcquisitionSetting",AcquisitionConfig)
    end
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

%% Set hardware list and hardware setting
t = array2table(zeros(0,4));
t.Properties.VariableNames = ["Name","Type","DeviceModel","ResourceName"];

if exist("WaveformGeneratorConfig","var")
    if ~isempty(WaveformGeneratorConfig)
        WaveformGeneratorConfig.Type = repmat("WaveformGenerator",height(WaveformGeneratorConfig),1);
        t = [t;WaveformGeneratorConfig];
    end
end

if exist("ScopeConfig","var")
    if ~isempty(ScopeConfig)
        ScopeConfig.Type = repmat("Scope",height(ScopeConfig),1);
        t = [t;ScopeConfig];
    end
end

if exist("PhaseLockConfig","var")
    if ~isempty(PhaseLockConfig)
        PhaseLockConfig.Type = repmat("PhaseLock",height(PhaseLockConfig),1);
        t = [t;PhaseLockConfig];
    end
end

p = HardwareList;
p.checkTable
p2 = HardwareSetting;
p2.checkTable
oldId = p.readColumn("ID");

if ~isempty(t)
    if exist('HardwareLogOrigin','var')
        DataPath = fullfile(HardwareLogOrigin,t.Name);
        if isfolder(HardwareLogOrigin)
            arrayfun(@createFolder,DataPath);
        else
            warning("Can not find the hardware log folder. Check your setConfig")
        end
    else
        error("HardwareLogOrigin must be defined when hardware is used.")
    end
    t.DataPath = DataPath;
    p.updateEntry(t,"Name")
    newId = p.readColumn("ID");
else
    newId = [];
end

deleteId = setdiff(oldId,newId);
if ~isempty(deleteId)
    p.deleteEntry(deleteId)
end

extraId = setdiff(newId,oldId);
if ~isempty(extraId)
    for ii = 1:numel(extraId)
        extraDeviceModel = p.readValue(extraId(ii),"DeviceModel");
        extraName = p.readValue(extraId(ii),"Name");
        hw = eval(extraDeviceModel + "('xxx',extraName)");
        p.saveEntry(hw,true);
    end
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

%% Check other setting
disp(newline + "Checking user settings...")
settingList = [
    "ListList";
    "VariableList";
    "BecExpSetting";
    "BecExpVariableUnit";
    "RoiSetting";
    "WaveformLibrary";
    "WaveformListLibrary";
    ];

for ii = 1:numel(settingList)
    p = eval(settingList(ii));
    p.checkTable;
end
disp("Done.")

end