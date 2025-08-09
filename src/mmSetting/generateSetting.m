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