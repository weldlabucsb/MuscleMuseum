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
            if obj.IsOverrideRoi
                calcRoi=[(obj.HwRoi(3)-1) (obj.HwRoi(1)-1) (obj.HwRoi(4)-obj.HwRoi(3)+1)  (obj.HwRoi(2)-obj.HwRoi(1)+1)];
                % obj.VideoInput.ROIPosition=double(calcRoi);
                src.H1HardwareROI_X_Offset=calcRoi(1);
                src.H2HardwareROI_Width=calcRoi(3);
                src.H4HardwareROI_Y_Offset=calcRoi(2);
                src.H5HardwareROI_Height=calcRoi(4);

            end
        end

        function setCameraROI(obj, ROI)
            % Sets NewROI property, sets UseNewROI property to true, and if enabled adjusts src object with new ROI. 
            % ROI is of the format [ymin ymax xmin xmax];
            % Call before startCamera
            % Required to edit videoinput source to properly adjust hwroi
            % for maximum fps.
            obj.HwRoi=ROI;
            obj.IsOverrideRoi=1;
            if ~isempty(obj.VideoInput)
                % disp(obj.HwRoi);
                % disp([(obj.HwRoi(3)-1) (obj.HwRoi(1)-1) (obj.HwRoi(4)-obj.HwRoi(3)+1)  (obj.HwRoi(2)-obj.HwRoi(1)+1)]);
                calcRoi=[(obj.HwRoi(3)-1) (obj.HwRoi(1)-1) (obj.HwRoi(4)-obj.HwRoi(3)+1)  (obj.HwRoi(2)-obj.HwRoi(1)+1)];
                % obj.VideoInput.ROIPosition=double(calcRoi);
                source=getselectedsource(obj.VideoInput);
                source.H1HardwareROI_X_Offset=calcRoi(1);
                source.H2HardwareROI_Width=calcRoi(3);
                source.H4HardwareROI_Y_Offset=calcRoi(2);
                source.H5HardwareROI_Height=calcRoi(4);
                % source.H3HardwareROI_Hor_Sym=0;
                % source.H6HardwareROI_Vert_Sym=0;
            end
        end
    end
end

