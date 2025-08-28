% Generate or update parameter tables from .mat snapshots.
%
% Loads configuration tables from peer ``.mat`` files and
% initializes/updates the corresponding parameter tables implemented as
% :class:`MmParameter` subclasses. Run after installation or when parameter
% snapshots change to populate the local SQLite database.

%% Generate config
clear
configList = [
    "BecExpParameterUnit"
    "AcquisitionConfig";
    "DatabaseConfig";
    "DatabaseServerConfig";
    "ComputerConfig";
    "RoiConfig"
    ];
for ii = 1:numel(configList)
    configName = configList(ii);
    t = loadVar("Config" + ".mat",configName);
    if configName == "RoiConfig"
        s = RoiSetting;
    elseif configName == "BecExpParameterUnit"
        s = BecExpVariableUnit;
    elseif configName == "AcquisitionConfig"
        s = AcquisitionSetting;
    else
        s = eval(configName);
    end
    s.checkTable;
    if configName == "DatabaseConfig"
        tList = t.Table;
        t.Table = [];
        t.TableList = tList;
    end
    if configName == "BecExpParameterUnit"
        t(t.ScannedParameter == "RunIndex",:) = [];
        t = renamevars(t,...
            ["ScannedParameter","ScannedParameterUnit"],...
            ["ScannedVariable","ScannedVariableUnit"]);
    end
    s.updateTable(t)
end



%% Variable
settingList = [
    "ListList";
    "VariableList"
    ];
for ii = 1:numel(settingList)
    settingName = settingList(ii);
    t = loadVar("HardwareVariable" + ".mat",settingName);
    if settingName == "VariableList"
        temp = t.Value;
        t.Value = [];
        t.DefaultValue = temp;
        temp = t.EquationValue;
        t.EquationValue = [];
        t.CurrentValue = temp;
    end
    s = eval(settingName);
    s.checkTable;
    s.updateTable(t)
end

%% BecExp
becExpType = readtable("becExpType.csv.xlsx",'TextType','string');
becExpType.FringeRemovalMask = arrayfun(@str2num,becExpType.FringeRemovalMask,'UniformOutput',false);
becExpType.AnalysisMethod = arrayfun(@str2strmat,becExpType.AnalysisMethod,'UniformOutput',false);
s0 = BecExpVariableUnit;
dict = dictionary(s0.readColumn("ScannedVariable"),s0.readColumn("ID"));
becExpType.ScannedVariableID = dict(becExpType.ScannedParameter);
becExpType.WaveformAssociation = arrayfun(@(x) str2table(x), becExpType.WaveformAssociation,'UniformOutput',false);
becExpType.PhaseLockAssociation = arrayfun(@(x) str2table(x), becExpType.PhaseLockAssociation,'UniformOutput',false);
s = BecExpSetting;
s.checkTable;
s.updateTable(becExpType)

%% Waveform
p = WaveformListLibrary;
wfl = loadVar("WaveformLibrary.mat","WaveformLibrary");
modwfl = [];
for ii = 1:numel(wfl)
    if any(cellfun(@(x) isa(x,"ModulatedWaveform"), wfl(ii).WaveformOrigin))
        modwfl = [modwfl,ii];
    else
        p.saveEntry(wfl(ii));
    end
end

for ii = modwfl
    p.saveEntry(wfl(ii));
end

%% Generate hardware setting
settingList = [
    "WaveformGenerator";
    "PhaseLock";
    "Scope";
    ];
p = HardwareList;
t = p.readColumn(["Name","Type"]);

for ii = 1:height(t)
    switch t.Type(ii)
        case "WaveformGenerator"
            hw = getWg(t.Name(ii),true);
            p.saveEntry(hw,true);
        case "PhaseLock"
            hw = getPl(t.Name(ii),true);
            p.saveEntry(hw,true);
        case "Scope"
            hw = getScope(t.Name(ii),true);
            p.saveEntry(hw,true);
    end
end
pset = loadVar("PhaseLockSetting.mat","PhaseLockSetting");
for ii = 1:height(pset)
    if ismember(pset.Name(ii),t.Name)
        varName = pset.VariableName(ii);
        p2 = VariableList;
        varID = p2.readValue(varName,"ID","Name");
        hwID = p.readValue(pset.Name(ii),"ID","Name");
        p3 = HardwareSetting;
        p3.updateSettingVariable(hwID,"Frequency",varID);
    end
end

%% Reset database column names
p = BecExpConfig;
s = p.readEntry(2);
conn = createWriter(s.DatabaseName);

try
    sqlquery = "ALTER TABLE " + s.DatabaseTableName + newline + ...
        "RENAME COLUMN ""ScannedParameter"" TO ""ScannedVariable"";";
    execute(conn,sqlquery)
catch
end

try
    sqlquery = "ALTER TABLE " + s.DatabaseTableName + newline + ...
        "RENAME COLUMN ""ScannedParameterUnit"" TO ""ScannedVariableUnit"";";
    execute(conn,sqlquery)
catch
end

try
    sqlquery = "ALTER TABLE " + s.DatabaseTableName + newline + ...
        "RENAME COLUMN ""IsCompeted"" TO ""IsCompleted"";";
    execute(conn,sqlquery)
catch
end

close(conn)

%% Hardware association
p = HardwareAssociation;
hwl = HardwareList;
wfll = WaveformListLibrary;
bs = BecExpSetting;
hws = HardwareSetting;
vl = VariableList;
for ii = 1:height(becExpType)
    wa = becExpType.WaveformAssociation{ii};
    if ~isempty(wa)
        for jj = 1:height(wa)
            HardwareID = hwl.readValue(wa.WaveformGeneratorName(jj),"ID","Name");
            ChannelNumber = regexp(wa.ChannelName(jj), '\d+', 'match');
            ss.DefaultValue = wfll.readValue(wa.WaveformListName(jj),"ID","Name");
            ss.TrialID = bs.readValue(becExpType.TrialName(ii),"ID","TrialName");
            if isempty(ss.DefaultValue)
                ss.DefaultValue = 0;
            end
            ss.DefaultValue = string(ss.DefaultValue);
            ss.SettingID = hws.readSettingID(HardwareID,"WaveformList",double(ChannelNumber));
            p.writeEntry(ss)
        end
    end
    pla = becExpType.PhaseLockAssociation{ii};
    if ~isempty(pla)
        for jj = 1:height(pla)
            HardwareID = hwl.readValue(pla.PhaseLockName(jj),"ID","Name");
            ChannelNumber = 1;
            ss2.DefaultValue = pla.Frequency(jj);
            ss2.TrialID = bs.readValue(becExpType.TrialName(ii),"ID","TrialName");
            ss2.VariableID = vl.readValue(pla.VariableName(jj),"ID","Name");
            ss2.DefaultValue = string(ss2.DefaultValue);
            ss2.SettingID = hws.readSettingID(HardwareID,"Frequency",double(ChannelNumber));
            p.writeEntry(ss2)
        end
    end
end

%% Old get functions

function wgObj = getWg(name,isLoadingSetting)
%GETWG Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
load("Config.mat","WaveformGeneratorConfig")
wgConfig = WaveformGeneratorConfig(WaveformGeneratorConfig.Name == name,:);
if ~isempty(wgConfig)
    wgObj = feval(wgConfig.DeviceModel,wgConfig.ResourceName,wgConfig.Name);
    if isLoadingSetting
        load("WaveformGeneratorSetting","WaveformGeneratorSetting")
        load("WaveformLibrary.mat","WaveformLibrary")
        setting = WaveformGeneratorSetting(WaveformGeneratorSetting.Name == name,:);
        wgObj.SamplingRate = setting.SamplingRate{1};
        wgObj.TriggerSource = setting.TriggerSource{1};
        wgObj.TriggerSlope = setting.TriggerSlope{1};
        wgObj.OutputMode = setting.OutputMode{1};
        wgObj.OutputLoad = setting.OutputLoad{1};
        wgObj.IsOutput = setting.IsOutput{1};
        wfName = setting.WaveformListName{1};
        for ii = 1:numel(wfName)
            if any(wfName(ii) == [WaveformLibrary.Name])
                wgObj.WaveformList{ii} = WaveformLibrary([WaveformLibrary.Name] == wfName(ii));
            else
                wgObj.WaveformList{ii} = [];
            end
        end
    end
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end

function scopeObj = getScope(name,isLoadingSetting)
%GETSCOPE Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
load("Config.mat","ScopeConfig")
scopeConfig = ScopeConfig(ScopeConfig.Name == name,:);
if ~isempty(ScopeConfig)
    scopeObj = feval(scopeConfig.DeviceModel,scopeConfig.ResourceName,scopeConfig.Name);
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end

function plObj = getPl(name,isLoadingSetting)
%GETWG Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
load("Config.mat","PhaseLockConfig")
plConfig = PhaseLockConfig(PhaseLockConfig.Name == name,:);
if ~isempty(plConfig)
    plObj = feval(plConfig.DeviceModel,plConfig.ResourceName,plConfig.Name);
    if isLoadingSetting
        load("PhaseLockSetting","PhaseLockSetting")
        setting = PhaseLockSetting(PhaseLockSetting.Name == name,:);
        plObj.Frequency = setting.Frequency;
        % plObj.VariableName = setting.VariableName;
    end
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end
