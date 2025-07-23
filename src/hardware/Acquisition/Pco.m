classdef Pco < Acquisition
    % PCO Pco class
    % Creates a subclass of the Acquisition class with properties specific
    % to our PCO camera as well as explicit code to connect to and control
    % this camera.
    methods
        function obj = Pco(acqName)
            %PCO Construct an instance of this class
            %   Creates an Acquisition object and saves the CameraType and
            %   AdaptorName used to connect to the camera.
            arguments
                acqName string
            end
            obj@Acquisition(acqName);
            obj.CameraType = "Pco";
            obj.AdaptorName = "pcocameraadaptor_r2023a";
            obj.ImageGroupSize= 3;
            obj.ConfigFun=@(obj) obj.setCameraParameterAbsorption;
        end

        function setCameraParameterAbsorption(obj)
            %Set camera parameters using the predefined configuration
            %functions. Assumes videoinput object has been created and
            %modifies it to predefined settings.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            vid.FramesPerTrigger = 1; %Set frames per trigger
            vid.FramesAcquiredFcnCount = obj.ImageGroupSize;
            vid.LoggingMode = 'memory'; %Set logging to memory
            src = getselectedsource(vid); %Create adaptor source
            src.TMTimestampMode = 'Binary'; %Set timestamp mode
            obj.IsExternalTriggered = true;

            triggerconfig(vid, 'hardware', '', 'ExternExposureStart'); %Configure trigger type and mode
            vid.TriggerRepeat = inf;
            src.IO_1SignalPolarity = 'rising'; %Configure polarity of IO signal at trigger port
            src.ExposureTime_s = obj.ExposureTime;
        end
    end
end

