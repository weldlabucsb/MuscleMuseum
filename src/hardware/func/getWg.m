function wgObj = getWg(name,isLoadingSetting)
%GETWG Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
p = WaveformGeneratorConfig;
wgConfig = p.readEntry(name,"Name",true);
if ~isempty(wgConfig)
    wgObj = feval(wgConfig.DeviceModel,wgConfig.ResourceName,wgConfig.Name);
    if isLoadingSetting
        p = WaveformGeneratorSetting;
        load("WaveformLibrary.mat","WaveformLibrary")
        setting = p.readEntry(name,"Name",true);
        wgObj.SamplingRate = setting.SamplingRate;
        wgObj.TriggerSource = setting.TriggerSource;
        wgObj.TriggerSlope = setting.TriggerSlope;
        wgObj.OutputMode = setting.OutputMode;
        wgObj.OutputLoad = setting.OutputLoad;
        wgObj.IsOutput = setting.IsOutput;
        wfName = setting.WaveformListName;
        for ii = 1:numel(wfName)
            if any(wfName(ii) == [WaveformLibrary.Name])
                wgObj.WaveformList{ii} = WaveformLibrary([WaveformLibrary.Name] == wfName(ii));
            else
                wgObj.WaveformList{ii} = [];
            end
        end
    end
else
    error("No device named [" + name + "] found. Check your mmConfig.")
end
end

