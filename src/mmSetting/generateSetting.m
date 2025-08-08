settingName = "WaveformGeneratorSetting";
t = loadVar(settingName + ".mat",settingName);
s = eval(settingName);
s.checkTable;
s.updateTable(t)