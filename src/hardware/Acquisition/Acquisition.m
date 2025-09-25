classdef Acquisition < handle & matlab.mixin.SetGetExactNames
    %:class:`Acquisition` base class for camera acquisition/control.
    %
    % Provides common camera identity and configuration, connection helpers,
    % and utilities for setting callbacks, starting/stopping acquisition, and
    % post-processing images (e.g., bad-pixel removal). Concrete subclasses
    % (:class:`Andor`, :class:`Basler`, :class:`Pco`, etc.) apply vendor-specific
    % details.
    %
    % - **Configuration loading**: Constructor reads camera 
    %   via :class:`AcquisitionSetting` and applies matches by property name.
    % - **Quantum efficiency**: :meth:`QuantumEfficiency` interpolates provided data
    %   (if any) to a requested wavelength.
    % - **Pixel size in object plane**: :math:`\mathrm{PixelSizeReal} = \dfrac{\mathrm{PixelSize}}{\mathrm{Magnification}}`.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    acq = Basler("MainCam");
    %    acq.connectCamera();
    %    acq.setCameraParameter();    % or model-specific helper
    %    acq.setCallback(@(data,evt) disp(size(data)));
    %    acq.startCamera();
    %    pause(1);
    %    acq.stopCamera();

    properties (SetAccess = protected)
        Name string % Nickname/label of the acquisition
        CameraType string % Camera vendor/type
        CameraModel string % Camera model identifier
        AdaptorName string % MATLAB adaptor name used to connect
        DeviceID int32 % Device ID if multiple devices share the adaptor
        SerialNumber int32 % Camera serial number
        PixelSize double % Pixel size [m]
        ImageSize uint32 % [size y, size x] in pixels
        BitsPerSample int16 % Bits per pixel (e.g., 8/16/32)
        BadRow uint32 % Row indices with bad pixels
        BadColumn uint32 % Column indices with bad pixels
        Magnification double % Optical magnification (unitless)
        Transmission double = 1 % Optical transmission (0-1)
        ConfigFun function_handle % Function handle to set camera parameters
        QuantumEfficiencyData double = [] % [wavelength (m), quantum efficiency]
    end

    properties (Constant, Hidden)
        BadWidth = 1 % Defines width of rows of bad pixels
    end

    properties (SetAccess = private,Transient)
        VideoInput % videoinput handle
    end

    properties
        ExposureTime double % Exposure time [s]
        IsExternalTriggered logical % Whether camera is externally triggered
        ImageGroupSize int32 % Number of frames before saving
        ImagePath {mustBeFolder} = "." % Save folder
        ImagePrefix string = "run" % Image filename prefix
        ImageFormat string = "tif" % Image format (e.g., 'tif')
    end

    properties (Dependent)
        PixelSizeReal % Pixel size in object plane [m]
    end

    methods
        function obj = Acquisition(acqName)
            % Construct an :class:`Acquisition` and load camera config.
            %
            % :param acqName: Camera name key used in configuration
            % :type acqName: string
            %
            % Loads configuration  via :class:`AcquisitionSetting`
            % and applies matching fields to properties.
            p = AcquisitionSetting;
            s = p.readEntry(acqName,"Name");
            setConfigProperty(obj,s)
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
            %
            % :raises error: When adaptor connection fails
            try
                warning("off")
                vid = videoinput(obj.AdaptorName,obj.DeviceID);
                warning("on")
            catch ME
                msg = ['Camera connection failed. Check if the camera is connected. To connect to Basler cameras,', ...
                    ' you may need to restart MATLAB. Error message from MATLAB:',newline,...
                    ME.message];
                error(msg)
            end
            obj.VideoInput = vid;
        end

        function setCameraParameter(obj)
            % Set camera parameters via :attr:`ConfigFun`.
            %
            % :raises error: If camera is not connected
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
            %
            % :raises error: If camera is not connected
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
            % :type imageData: numeric array
            % :return: Corrected image data
            % :rtype: numeric array
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
            % Compare :attr:`obj` properties with fields of ``struct`` and set matches.
            %
            % Requires :class:`matlab.mixin.SetGetExactNames` to set only exact-name matches.
            mc = metaclass(obj); %use metaclass to access non-public properties
            propList = {mc.PropertyList.Name};
            fieldList = fieldnames(struct);
            [~,ia,ib] = intersect(propList,fieldList);
            structcell = struct2cell(struct);
            set(obj,propList(ia)',structcell(ib)')
        end

    end
end

