classdef Acquisition < handle & matlab.mixin.SetGetExactNames
    %ACQUISITION Acquisition class.
    %   Class that describes camera properties and enables saving images
    %   taken from the camera of interest. 

    properties (SetAccess = protected)
        Name string %Nickname/label of the acquisition
        CameraType string %Producer of the camera
        CameraModel string %Model of the camera
        AdaptorName string %MATLAB camera adaptor used to connect to camera.
        DeviceID int32 %To distinguish devices if multiple devices are connected through the same adaptor
        SerialNumber int32 %Camera serial number
        PixelSize double %In microns
        ImageSize uint32 %size y (int)* size x (int)
        BitsPerSample int16 %How many bits per pixel
        BadRow uint32 %rows that have bad pixels
        BadColumn uint32 %columns that have bad pixels
        Magnification double %Magnification of the optical system, determined by lens setup.
        Transmission double = 1 %Transmission of the optical system
        ConfigFun function_handle %Function handle that configures the camera parameters. Must be pre-defined.
        QuantumEfficiencyData double = [] %Quantum efficiency data from the company. First column: wavelength. Second column: quantum efficiency.
    end

    properties (Constant, Hidden)
        BadWidth = 1 % Defines width of rows of bad pixels
    end

    properties (SetAccess = private,Transient)
        VideoInput %MATLAB camera connection object, class videoinput
    end

    properties
        ExposureTime double %In micro-seconds
        IsExternalTriggered logical %Tells whether camera is externally triggered or not.
        ImageGroupSize int32 %Specify the number of frames that must be acquired before we save the images
        ImagePath {mustBeFolder} = "." %Folder location where to save the generated images
        ImagePrefix string = "run" %String prefix that describes how to name the images
        ImageFormat string = "tif" %Image format
        NewRoi (1, 4) int32 %2x2 int array [ymin ymax xmin xmax]that sets the ROI of the images to be saved, ideally smaller than the max ROI
        UseNewRoi logical = 0 %Logical value determining whether to use default ROI or use a smaller defined one.
    end

    properties (Dependent)
        PixelSizeReal % Calculated size of the pixels in the plane of the atoms.
    end

    methods
        function obj = Acquisition(acqName)
            %Acquisition Construct an instance of the Acquisition class
            %   Acquisition handles mainly the camera parameters and the
            %   data acquisition process. Given "cameraName", the
            %   constructor load the configuration and set the acquisition
            %   parameters properly from the MMUser config folder. 
            %   acqName is a string that identifies the camera in the
            %   config file Config.mat.
            load("Config.mat","AcquisitionConfig")
            setConfigProperty(obj,table2struct(AcquisitionConfig(AcquisitionConfig.Name==acqName,:)))
        end

        function qe = QuantumEfficiency(obj,lambda)
            % Calculates and saves QuantumEfficiency for given wavelength
            % lambda (in m) from data table
            qeData = obj.QuantumEfficiencyData;
            if isempty(qeData)
                qe = 1;
            elseif lambda < min(qeData(:,1)) || lambda > max(qeData(:,1))
                qe = 0;
            else
                qe = interp1(qeData(:,1),qeData(:,2),lambda,'linear');
            end
        end

        function connectCamera(obj)
            %Connect to the camera. Return the VideoInput object.
            try
                vid = videoinput(obj.AdaptorName,obj.DeviceID);
            catch ME
                msg = ['Camera connection failed. Check if the camera is connected. To connect to Basler cameras,', ...
                    ' you may need to restart MATLAB. Error message from MATLAB:',newline,...
                    ME.message];
                error(msg)
            end
            obj.VideoInput = vid;
        end

        function setCameraParameter(obj)
            %Set camera parameters using the predefined configuration
            %functions.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            configFun = obj.ConfigFun;
            configFun(obj);
        end

        function setCameraROI(obj, ROI)
            % Sets NewROI property, sets UseNewROI property to true, and if enabled adjusts videoinput with new roi. 
            % ROI is of the format [ymin ymax xmin xmax];
            obj.NewRoi=ROI;
            obj.UseNewRoi=1;
            if ~isempty(obj.VideoInput)
                obj.VideoInput.ROIPosition=[obj.NewRoi(3)-1 obj.NewRoi(4)-obj.NewRoi(3)+1 obj.NewRoi(1)-1 obj.NewRoi(2)-obj.NewRoi(1)+1];
            end
        end

        function clearCameraROI(obj)
            % Clears NewRoi property, sets UseNewROI property to false, and
            % if enabled adjusts videoinput back to old roi.
            obj.NewRoi=[1 obj.ImageSize(1) 1 obj.ImageSize(2)];
            obj.UseNewRoi=0;
            if ~isempty(obj.VideoInput)
                obj.VideoInput.ROIPosition=[obj.NewRoi(3)-1 obj.NewRoi(4)-obj.NewRoi(3)+1 obj.NewRoi(1)-1 obj.NewRoi(2)-obj.NewRoi(1)+1];
            end
        end

        function setCallback(obj,callbackFunc)
            %Set camera callback function to be called when sufficient
            %images have been taken.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            vid.FramesAcquiredFcn = callbackFunc;
        end

        function startCamera(obj)
            %Start camera recording
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            start(vid);
        end

        function pauseCamera(obj)
            %Pause camera recording
            vid = obj.VideoInput;
            stop(vid);
        end

        function stopCamera(obj)
            %Stop camera recording, deletes videoinput object.
            vid = obj.VideoInput;
            stop(vid);
            delete(vid);
            clear vid;
        end

        function imageDataKilled = killBadPixel(obj,imageData)
            %Takes an average of rows/collumns surrounding bad pixels and
            %replaces them.
            if (~all(size(imageData,1,2) == obj.ImageSize)) && (~obj.UseNewRoi)
                error("Image data size is wrong.")
            end

            if (obj.UseNewRoi) && (~all(size(imageData,1,2)== [obj.NewRoi(4)-obj.NewRoi(3)+1 obj.NewRoi(2)-obj.NewRoi(1)+1]))
                error("Image data size is wrong.")

            end

            imageDataKilled = imageData;
            nDim = ndims(imageData);
            C=repmat({':'},1,nDim-2);
            bW = obj.BadWidth;
            if ~isempty(obj.BadRow)
                bR = obj.BadRow;
                if obj.UseNewRoi
                    bR=bR-obj.NewRoi(3)+1;
                    bR=bR(bR>0); % selects only positive values from adjusted array.
                end
                for ii = 1:numel(bR)
                    replace = (imageDataKilled(bR(ii)-bW-1,:,C{:})+imageDataKilled(bR(ii)+bW+1,:,C{:}))/2;
                    imageDataKilled(bR(ii)-bW:bR(ii)+bW,:,C{:}) = repmat(replace,2*bW + 1,1);
                    % slope = (imageDataKilled(bR(ii)+bW+1,:,C{:}) - imageDataKilled(bR(ii)-bW-1,:,C{:}))/(2*bW+2);
                    % for jj = 1:(2*bW+1)
                    %     imageDataKilled(jj + bR(ii)-bW-1,:,C{:}) = imageDataKilled(bR(ii)-bW-1,:,C{:}) + slope * jj;
                    % end
                end
            end
            if ~isempty(obj.BadColumn)
                bC = obj.BadColumn;
                if obj.UseNewRoi
                    bC=bC-obj.NewRoi(1)+1;
                    bC=bC(bC>0); % selects only positive values from adjusted array.
                end
                for ii = 1:numel(bC)
                    replace = (imageDataKilled(:,bC(ii)-obj.BadWidth-1,C{:})+imageDataKilled(:,bC(ii)+obj.BadWidth+1,C{:}))/2;
                    imageDataKilled(:,bC(ii)-obj.BadWidth : bC(ii)+obj.BadWidth,C{:}) = repmat(replace,1,2*obj.BadWidth + 1);
                end
            end
        end

        function px = get.PixelSizeReal(obj)
            % Calculates pixel size at atomic plane using magnification
            px = obj.PixelSize / obj.Magnification;
        end

    end
    methods (Access = private, Hidden)

        function  setConfigProperty(obj,struct)
            %This method compares the properties of the handle object 'obj' with
            %the fields of a structure 'struct'. Then it sets the properties to the
            %values of the fields. The obj must inherit the set method from
            %matlab.mixin.SetGetExactNames. Used to extract config
            %properties.
            mc = metaclass(obj); %use metaclass to access non-public properties
            propList = {mc.PropertyList.Name};
            fieldList = fieldnames(struct);
            [~,ia,ib] = intersect(propList,fieldList);
            structcell = struct2cell(struct);
            set(obj,propList(ia)',structcell(ib)')
        end

    end
end

