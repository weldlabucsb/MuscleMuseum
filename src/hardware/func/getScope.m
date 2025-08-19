function scopeObj = getScope(name,isLoadingSetting)
%GETSCOPE Summary of this function goes here
%   Detailed explanation goes here
arguments
    name string
    isLoadingSetting logical = false
end
p = ScopeConfig;
scopeConfig = p.readEntry(name,"Name",true);
if ~isempty(ScopeConfig)
    scopeObj = feval(scopeConfig.DeviceModel,scopeConfig.ResourceName,scopeConfig.Name);
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end
