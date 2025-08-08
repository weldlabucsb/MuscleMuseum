classdef Pco < Acquisition
    %:class:`Pco` acquisition using the PCO camera adaptor.
    %
    % Provides an absorption-imaging configuration via :meth:`setCameraParameterAbsorption`.
    methods
        function obj = Pco(acqName)
            % Construct a :class:`Pco` acquisition instance.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Acquisition(acqName);
            obj.CameraType = "Pco";
            obj.AdaptorName = "pcocameraadaptor_r2023a";
        end

        function setCameraParameterAbsorption(obj)
            % Configure absorption-imaging parameters for PCO adaptor.
            %
            % Requires connected :attr:`VideoInput`. Sets hardware trigger (ExternExposureStart),
            % rising polarity, and exposure time from :attr:`ExposureTime`.
            if isempty(obj.VideoInput)
                error('Camera not connected. Try the "connectCamera" method first.')
            end
            vid = obj.VideoInput;
            vid.FramesPerTrigger = 1; %Set frames per trigger
            vid.FramesAcquiredFcnCount = 3;
            vid.LoggingMode = 'memory'; %Set logging to memory
            src = getselectedsource(vid); %Create adaptor source
            src.TMTimestampMode = 'Binary'; %Set timestamp mode
            obj.IsExternalTriggered = true;
            obj.ImageGroupSize = 3;

            triggerconfig(vid, 'hardware', '', 'ExternExposureStart'); %Configure trigger type and mode
            vid.TriggerRepeat = inf;
            src.IO_1SignalPolarity = 'rising'; %Configure polarity of IO signal at trigger port
            src.ExposureTime_s = obj.ExposureTime;
        end
    end
end

