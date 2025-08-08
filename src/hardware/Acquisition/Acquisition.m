classdef Acquisition < handle & matlab.mixin.SetGetExactNames
    %:class:`Acquisition` camera acquisition base class.
    %
    % Describes camera properties and saving images from a camera of interest.
    % Implements helpers for connect/configure/callback/start/stop and image
    % utilities. Subclasses (e.g., :class:`Andor`) override specifics.
    %
    % **Notes:**
    %
    %     Configuration is loaded from ``Config.mat`` by :meth:`Acquisition` and applied
    %     via an internal setter. Quantum efficiency can be interpolated by :meth:`QuantumEfficiency`.

    properties (SetAccess = protected)
        Name string % Nickname/label of the acquisition
        CameraType string % Producer of the camera
        CameraModel string % Model of the camera
        AdaptorName string % MATLAB camera adaptor used to connect to camera.
        DeviceID int32 % ID if multiple devices share the same adaptor
        SerialNumber int32 % Camera serial number
        PixelSize double % Pixel size [micron]
        ImageSize uint32 % [size y, size x]
        BitsPerSample int16 % Bits per pixel
        BadRow uint32 % rows that have bad pixels
        BadColumn uint32 % columns that have bad pixels
        Magnification double % Optical magnification
        Transmission double = 1 % Optical system transmission
        ConfigFun function_handle % Function handle to configure camera parameters
        QuantumEfficiencyData double = [] % Columns: wavelength [m], quantum efficiency
    end

    properties (Constant, Hidden)
        BadWidth = 1 % Defines width of rows of bad pixels
    end

    properties (SetAccess = private,Transient)
        VideoInput % videoinput handle
    end

    properties
        ExposureTime double % Exposure time [us]
        IsExternalTriggered logical % Whether camera is externally triggered
        ImageGroupSize int32 % Number of frames before saving
        ImagePath {mustBeFolder} = "." % Save folder
        ImagePrefix string = "run" % Image filename prefix
        ImageFormat string = "tif" % Image format
    end

    properties (Dependent)
        PixelSizeReal % Pixel size in object plane
    end

    methods
        function obj = Acquisition(acqName)
            % Construct an :class:`Acquisition` and load camera config.
            %
            % :param acqName: Camera name key used in configuration
            % :type acqName: string
            %
            % Loads ``AcquisitionConfig`` from ``Config.mat`` and applies with
            % a protected configuration setter.
            load("Config.mat","AcquisitionConfig")
            setConfigProperty(obj,table2struct(AcquisitionConfig(AcquisitionConfig.Name==acqName,:)))
        end

        function qe = QuantumEfficiency(obj,lambda)
            % Interpolate quantum efficiency at wavelength :math:`\lambda` [m].
            %
            % :param lambda: Wavelength [m]
            % :type lambda: double
            % :return: Quantum efficiency (0-1)
            % :rtype: double
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
            % Connect to the camera and create :attr:`VideoInput`.
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
            % Set camera parameters via the predefined configuration :attr:`ConfigFun`.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            configFun = obj.ConfigFun;
            configFun(obj);
        end

        function setCallback(obj,callbackFunc)
            % Register callback called when enough images are taken.
            %
            % :param callbackFunc: Function handle accepting (data, event)
            % :type callbackFunc: function_handle
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            vid.FramesAcquiredFcn = callbackFunc;
        end

        function startCamera(obj)
            % Start camera recording.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            start(vid);
        end

        function pauseCamera(obj)
            % Pause camera recording.
            vid = obj.VideoInput;
            stop(vid);
        end

        function stopCamera(obj)
            % Stop camera and delete :attr:`VideoInput`.
            vid = obj.VideoInput;
            stop(vid);
            delete(vid);
            clear vid;
        end

        function imageDataKilled = killBadPixel(obj,imageData)
            % Replace bad pixel rows/columns by neighbor averages.
            %
            % :param imageData: Image data array
            % :type imageData: double array | uint*
            % :return: Corrected image data
            % :rtype: same as input
            if ~all(size(imageData,1,2) == obj.ImageSize)
                error("Image data size is wrong.")
            end
            imageDataKilled = imageData;
            nDim = ndims(imageData);
            C=repmat({':'},1,nDim-2);
            bW = obj.BadWidth;
            if ~isempty(obj.BadRow)
                bR = obj.BadRow;
                for ii = 1:numel(bR)
                    replace = (imageDataKilled(bR(ii)-bW-1,:,C{:})+imageDataKilled(bR(ii)+bW+1,:,C{:}))/2;
                    imageDataKilled(bR(ii)-bW:bR(ii)+bW,:,C{:}) = repmat(replace,2*bW + 1,1);
                end
            end
            if ~isempty(obj.BadColumn)
                for ii = 1:numel(obj.BadColumn)
                    replace = (imageDataKilled(:,obj.BadColumn(ii)-obj.BadWidth-1,C{:})+imageDataKilled(:,obj.BadColumn(ii)+obj.BadWidth+1,C{:}))/2;
                    imageDataKilled(:,obj.BadColumn(ii)-obj.BadWidth : obj.BadColumn(ii)+obj.BadWidth,C{:}) = repmat(replace,1,2*obj.BadWidth + 1);
                end
            end
        end

        function px = get.PixelSizeReal(obj)
            % Get pixel size at object plane using :attr:`Magnification`.
            %
            % :return: Pixel size [micron]
            % :rtype: double
            px = obj.PixelSize / obj.Magnification;
        end

    end
    methods (Access = private, Hidden)

        function  setConfigProperty(obj,struct)
            % Compare properties of :attr:`obj` with fields of ``struct`` and set matches.
            %
            % The object must inherit the set method from
            % :class:`matlab.mixin.SetGetExactNames`.
            mc = metaclass(obj); %use metaclass to access non-public properties
            propList = {mc.PropertyList.Name};
            fieldList = fieldnames(struct);
            [~,ia,ib] = intersect(propList,fieldList);
            structcell = struct2cell(struct);
            set(obj,propList(ia)',structcell(ib)')
        end

    end
end

