function acqObj = getAcq(name,isLoadingSetting)
arguments
    name string
    isLoadingSetting logical = false
end
p = AcquisitionConfig;
acqConfig = p.readEntry(name,"Name");
if ~isempty(acqConfig)
    acqObj = feval(acqConfig.DeviceModel,acqConfig.Name);
else
    error("No device named [" + name + "] found in Config. Check your setConfig.")
end
end
