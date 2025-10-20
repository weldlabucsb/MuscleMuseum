function setPcoConfig(acq)
%SETPCOCONFIG set PCO camera configuration
%   Input must be an "Acquisition" object. The following setup is for
%   regular BEC experiment data taking.
arguments
    acq Acquisition
end

vid = acq.VideoInput;
vid.FramesPerTrigger = 1; %Set frames per trigger
vid.FramesAcquiredFcnCount = acq.ImageGroupSize;
vid.LoggingMode = 'memory'; %Set logging to memory
src = getselectedsource(vid); %Create adaptor source
src.TMTimestampMode = 'Binary'; %Set timestamp mode
if acq.IsExternalTriggered == true
    triggerconfig(vid, 'hardware', '', 'ExternExposureStart'); %Configure trigger type and mode
    vid.TriggerRepeat = inf;
    src.IO_1SignalPolarity = 'rising'; %Configure polarity of IO signal at trigger port
    src.ExposureTime_s = acq.ExposureTime;
end

end

