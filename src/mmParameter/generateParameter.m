% Generate or update parameter tables from .mat snapshots.
%
% This script loads configuration tables from peer ``.mat`` files and
% initializes/updates the corresponding parameter tables. It is intended to be
% run after installation or when parameter snapshots change.

% Generate config
configList = [
    "WaveformGeneratorConfig";
    "AcquisitionConfig";
    "DatabaseConfig"
];
for ii = 1:numel(configList)
    configName = configList(ii);
    t = loadVar("Config" + ".mat",configName);
    s = eval(configName);
    s.checkTable;
    if configName == "DatabaseConfig"
        tList = t.Table;
        t.Table = [];
        t.TableList = tList;
    end
    s.updateTable(t)
end

% Generate setting
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

