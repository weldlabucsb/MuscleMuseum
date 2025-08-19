function plObj = getPl(name,isLoadingSetting)
%GETWG Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
p = PhaseLockConfig;
plConfig = p.readEntry(name,"Name",true);
if ~isempty(plConfig)
    plObj = feval(plConfig.DeviceModel,plConfig.ResourceName,plConfig.Name);
    if isLoadingSetting
        p = PhaseLockSetting;
        setting = p.readEntry(name,"Name",true);
        plObj.Frequency = setting.Frequency;
        plObj.VariableName = setting.VariableName;
    end
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end

