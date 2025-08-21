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
    "WaveformGeneratorConfig";
    "AcquisitionConfig";
    "DatabaseConfig";
    "DatabaseServerConfig";
    "ComputerConfig";
    "HardwareList";
    "RoiConfig"
    ];
for ii = 1:numel(configList)
    configName = configList(ii);
    t = loadVar("Config" + ".mat",configName);
    if configName == "RoiConfig"
        s = RoiSetting;
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
    end
    s.updateTable(t)
end

%% Generate setting
settingList = [
    "WaveformGeneratorSetting";
    "PhaseLockSetting";
    "ScopeSetting";
    ];

for ii = 1:numel(settingList)
    settingName = settingList(ii);
    t = loadVar(settingName + ".mat",settingName);
    s = eval(settingName);
    s.checkTable;
    s.updateTable(t)
end

%% HardwareList
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
s0 = BecExpParameterUnit;
dict = dictionary(s0.readColumn("ScannedParameter"),s0.readColumn("ID"));
becExpType.ScannedParameterID = dict(becExpType.ScannedParameter);
becExpType.WaveformAssociation = arrayfun(@(x) str2table(x), becExpType.WaveformAssociation,'UniformOutput',false);
becExpType.PhaseLockAssociation = arrayfun(@(x) str2table(x), becExpType.PhaseLockAssociation,'UniformOutput',false);
s = BecExpSetting;
s.checkTable;
s.updateTable(becExpType)

%% Waveform
p = WaveformListLibrary;
p2 = WaveformLibrary;
wfl = loadVar("WaveformLibrary.mat","WaveformLibrary");
modwfl = [];
for ii = 1:numel(wfl)
    if any(cellfun(@(x) isa(x,"ModulatedWaveform"), wfl(ii).WaveformOrigin))
        modwfl = [modwfl,ii];
    else
        saveWaveformList(wfl(ii),p,p2)
    end
end

for ii = modwfl
    saveWaveformList(wfl(ii),p,p2)
end
