classdef Basler < Acquisition
    %:class:`Basler` acquisition using the GenTL adaptor.
    %
    % Provides an absorption-imaging configuration via :meth:`setCameraParameterAbsorption`.
    methods
        function obj = Basler(acqName)
            % Construct a :class:`Basler` acquisition instance.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Acquisition(acqName);
            obj.CameraType = "Basler";
            obj.AdaptorName = "gentl";
        end

        function setCameraParameterAbsorption(obj)
            % Configure absorption-imaging parameters for Basler GenTL.
            %
            % Requires connected :attr:`VideoInput`. Sets trigger to external rising edge,
            % logs to memory, and frames per trigger suitable for 3-image sequences.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            vid.FramesPerTrigger = 1; %Set frames per trigger
            vid.FramesAcquiredFcnCount = 3;
            vid.LoggingMode = 'memory'; %Set logging to memory
            src = getselectedsource(vid); %Create adaptor source
            src.ShutterMode = 'GlobalResetRelease';
            obj.IsExternalTriggered = true;
            obj.ImageGroupSize = 3;

            triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific'); %Configure trigger type and mode
            vid.TriggerRepeat = inf;
            src.TriggerSelector = 'FrameStart';
            src.TriggerSource = 'Line1';
            src.TriggerActivation = 'RisingEdge';
            src.TriggerMode = 'on';
            src.ExposureMode = 'Timed';
            src.ExposureTime = obj.ExposureTime * 1e6;
        end
    end
end

