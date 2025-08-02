function setIxon888Config(acq)
%SETIXON888CONFIG set Andor camera configuration
%Created and edited 2/3/2025 by Eber Nolasco-Martinez
%
%   Input must be an "Acquisition" object. This script modifies the camera
%   settings to specific information. There is no equivalent Andor
%   videoinput object, so must be generalized. 

%Needs work to make compatible.

arguments
    acq Acquisition
end

%% Set Cooling Settings
[ret]=SetCoolerMode(1);                       % Camera temperature is maintained on ShutDown
CheckWarning(ret);
[ret]=CoolerON();                             %   Turn on temperature cooler
CheckWarning(ret);
[ret]=SetAcquisitionMode(3);                  %   Set acquisition mode; 3 for Kinetic Series
CheckWarning(ret);

%% Set Imaging Settings

frameCount = acq.ImageGroupSize;


[ret]=SetNumberKinetics(frameCount);
CheckWarning(ret);
[ret]=SetExposureTime(acq.ExposureTime);                  %   Set exposure time in second  THIS IS THE USUAL VALUE
CheckWarning(ret);
% [ret]=SetExposureTime(0.1);                  %   TESTING EXPOSURE SETTING
% CheckWarning(ret);
[ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
CheckWarning(ret);
[ret]=SetTriggerMode(1);                      %   Set internal trigger mode
CheckWarning(ret);
[ret]=SetShutter(1, 1, 0, 0);                 %   Open Shutter
CheckWarning(ret);
[ret,XPixels, YPixels]=GetDetector;           %   Get the CCD size
CheckWarning(ret);
[ret]=SetImage(1, 1, 1, XPixels, 1, YPixels); %   Set the image size
CheckWarning(ret);
[ret]=SetEMCCDGain(gain);                        %   Set EMCCD gain
CheckWarning(ret);


% vid = acq.VideoInput;
% vid.FramesPerTrigger = 1; %Set frames per trigger
% vid.FramesAcquiredFcnCount = acq.ImageGroupSize;
% vid.LoggingMode = 'memory'; %Set logging to memory
% src = getselectedsource(vid); %Create adaptor source
% src.ShutterMode = 'GlobalResetRelease';
% if acq.IsExternalTriggered == true
%     triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific'); %Configure trigger type and mode
%     vid.TriggerRepeat = inf;
%     src.TriggerSelector = 'FrameStart';
%     src.TriggerSource = 'Line1';
%     src.TriggerActivation = 'RisingEdge';
%     src.TriggerMode = 'on';
%     src.ExposureMode = 'Timed';
%     src.ExposureTime = acq.ExposureTime * 1e6;
% end

end

