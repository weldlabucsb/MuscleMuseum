classdef Andor < Acquisition
    %:class:`Andor` acquisition class using Andor's proprietary SDK via a worker.
    %
    % Uses a parallel worker loop (:meth:`andorLoop`) to manage camera acquisition
    % asynchronously and communicates via :class:`parallel.pool.DataQueue`.
    %
    % - **Workflow:**
    %
    %   1. :meth:`connectCamera` (client): Launch worker and establish queues
    %      (client receives worker :class:`parallel.pool.PollableDataQueue`).
    %   2. :meth:`setCameraParameterAbsorption` (client→worker): Send
    %      ``SetParameter`` message with ``AcquisitionMode="Absorption"``,
    %      ``ExposureTime``, and ``BitPerSample``; sets :attr:`ImageGroupSize=3` on client.
    %   3. :meth:`setCallback`: Register a client callback ``@(data,event)`` that
    %      handles the 3-frame group (atom, light, dark) pushed by the worker.
    %   4. :meth:`startCamera` (client→worker): Send ``Start``; worker acquires frames
    %      until a full group is ready, then sends data via :class:`DataQueue`.
    %   5. :meth:`stopCamera` (client→worker): Send ``Stop``; worker aborts acquisition,
    %      closes shutter, and shuts down SDK. Client cancels :attr:`Future` and removes listener.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    cam = Andor("MainAndor");
    %    cam.ExposureTime = 0.01;  % [s]
    %    cam.BitsPerSample = 16;
    %    cam.connectCamera();
    %    cam.setCameraParameterAbsorption();
    %    cam.setCallback(@(m,~) disp(size(m)));
    %    cam.startCamera(); pause(1); cam.stopCamera();
    properties (SetAccess=protected,Transient)
        CallbackFunc function_handle % Client-side callback: @(data,event)
        Future parallel.FevalFuture % Handle to the worker task running :meth:`andorLoop`
        ClientDataQueue parallel.pool.DataQueue % Queue to receive data from worker
        ClientQueue parallel.pool.PollableDataQueue % Queue to receive the worker queue handle
        WorkerQueue parallel.pool.PollableDataQueue % Queue to send commands to worker
        ClientListener event.listener % Listener that adapts queue messages to callback signature
    end

    methods
        function obj = Andor(acqName)
            % Construct an :class:`Andor` acquisition instance.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Acquisition(acqName);
            obj.CameraType = "Andor";
        end

        function connectCamera(obj)
            % Connect by launching a worker loop and establishing queues.
            %
            % Spawns a background worker running :meth:`andorLoop`, sets up a
            % :class:`parallel.pool.DataQueue` (worker→client) and a
            % :class:`parallel.pool.PollableDataQueue` (client→worker), and stores
            % the returned worker queue in :attr:`WorkerQueue`.
            %
            % :raises error: When worker reports an error during startup

            % Create client queue
            obj.ClientQueue = parallel.pool.PollableDataQueue;
            obj.ClientDataQueue = parallel.pool.DataQueue;

            % Run andor on the worker process
            p = gcp('nocreate');
            if isempty(p)
                p = parpool(1);
            end

            obj.Future = parfeval(p,@(cq,cdq) obj.andorLoop(cq,cdq),0,obj.ClientQueue,obj.ClientDataQueue);

            % Retrieve the worker queue from the worker
            obj.WorkerQueue = poll(obj.ClientQueue,10);

            % Check for errors
            obj.checkError;
        end

        function setCameraParameterAbsorption(obj)
            % Set absorption-imaging parameters on the worker.
            %
            % Sends a message over :attr:`WorkerQueue` with fields:
            % ``Message="SetParameter"``, ``AcquisitionMode="Absorption"``,
            % ``ExposureTime``, and ``BitPerSample``. Also sets
            % :attr:`ImageGroupSize` to ``3`` on the client for a 3-frame sequence
            % (atom, light, dark).
            data.Message = "SetParameter";
            data.AcquisitionMode = "Absorption";
            data.ExposureTime = obj.ExposureTime;
            data.BitPerSample = obj.BitsPerSample;
            obj.ImageGroupSize = 3;
            send(obj.WorkerQueue,data);
        end

        function setCallback(obj,callbackFunc)
            % Set camera callback function.
            %
            % :param callbackFunc: Function handle invoked as ``callbackFunc(data, event)``
            % :type callbackFunc: function_handle
            %
            % The listener adapts queue payloads to the standard acquisition
            % callback signature by passing an empty event struct.
            obj.ClientListener = afterEach(obj.ClientDataQueue,@(x) callbackFunc(x,[]));
        end

        function startCamera(obj)
            % Start acquisition on the worker.
            %
            % Sends ``Message="Start"`` over :attr:`WorkerQueue` and checks for
            % pending worker errors via :meth:`checkError`.
            data.Message = "Start";
            send(obj.WorkerQueue,data);
            obj.checkError;
        end

        function pauseCamera(obj)
            % Pause camera recording (not implemented in this backend).
            %
            % **Notes:**
            %
            %     Pausing is not supported by the current Andor worker example.
            %     Use :meth:`stopCamera` to end an acquisition.
            % [ret] = AbortAcquisition();
            % CheckError(ret);
        end

        function stopCamera(obj)
            % Stop camera recording and tear down worker-side state.
            %
            % Sends ``Message="Stop"`` to the worker, checks for errors, cancels
            % the running :attr:`Future`, and deletes :attr:`ClientListener`.
            data.Message = "Stop";
            send(obj.WorkerQueue,data);
            pause(0.2)
            obj.checkError;
            cancel(obj.Future)
            delete(obj.ClientListener)
        end

        function checkError(obj)
            % Throw worker errors on the client if present.
            %
            % :raises error: Re-throws :attr:`Future.Error` when non-empty
            if ~isempty(obj.Future.Error)
                obj.Future.Error.throw
            end
        end
    end

    methods (Static)
        function andorLoop(cq,cdq)
            % Worker loop managing Andor SDK calls.
            %
            % :param cq: Client queue used to deliver the worker queue handle back
            % :type cq: :class:`parallel.pool.PollableDataQueue`
            % :param cdq: Data queue used to stream image data to the client
            % :type cdq: :class:`parallel.pool.DataQueue`
            %
            % **Protocol:**
            %
            % - Returns a worker :class:`parallel.pool.PollableDataQueue` to client
            %   via ``cq`` for receiving messages.
            % - Message ``SetParameter`` with fields ``AcquisitionMode``, ``ExposureTime``,
            %   ``BitPerSample`` configures SDK (cooler, read mode, shutter, ROI, etc.).
            % - Message ``Start`` begins acquisition; worker polls for a full group
            %   of frames (group size set during parameter stage).
            % - When a group is ready, frames are fetched, oriented, converted to
            %   the specified bit depth, and sent to the client via ``cdq``.
            % - Message ``Stop`` aborts acquisition, closes shutter, and shuts down SDK.
            % Send the worker queue to the client
            wq = parallel.pool.PollableDataQueue;
            send(cq,wq);

            % Initialize the Andor SDK library
            % try
            %     AndorShutDown();
            % catch
            % end
            try
                ret=AndorInitialize('');
                CheckError(ret);
            catch ME
                msg = ['Camera connection failed. Check if the camera is connected. To connect to Andor cameras,', ...
                    ' you may need to restart MATLAB. Error message from MATLAB:',newline,...
                    ME.message];
                error(msg)
            end

            % Initialize camera state identifier
            isSet = false;
            isAcq = false;
            acqMode = "Absorption";
            bitPerSample = 16;
            imageCount = 0;

            % Logger Setup
            logFolder = "C:\Data\AndorDebugLogs\";
            logName = string(datestr(now, 'mmddyy-HHMMSS')) + ".txt";  
            fullLogPath = fullfile(logFolder, logName);
            if ~exist(logFolder, 'dir'); mkdir(logFolder); end
            Logger = logger(fullLogPath,0);
            Logger.info("Beginning Andor Loop")
            gain=21; % this is real emccd gain (20x min)
            checktemp=0; % (0 = no monitoring) use this to monitor camera temperature before chillerON -- debugging mainly
            stabilizewait=0; % time to wait for temp to stabilize (s)
            waitduration = 1; % time btwn temp checks for stabilization (s)
            
            % testing this out -------------- (nh) ----------------------
            % this is to readout the return status (instead of e.g. 20035)
            function txt = andorRetString(ret)
                switch ret
                    case atmcd.DRV_SUCCESS
                        txt = "SUCCESS";
                    case atmcd.DRV_TEMP_OFF
                        txt = "Note: TEMP_OFF";
                    case atmcd.DRV_TEMP_STABILIZED
                        txt = "Note: TEMP_STABILIZED";
                    case atmcd.DRV_TEMP_NOT_REACHED
                        txt = "Note: TEMP_NOT_REACHED";
                    case atmcd.DRV_TEMP_DRIFT
                        txt = "Note: TEMP_DRIFT";
                    case atmcd.DRV_TEMP_NOT_STABILIZED
                        txt = "Note: TEMP_NOT_STABILIZED";
                    case atmcd.DRV_ACQUIRING
                        txt = "Note: ACQUIRING";
                    case atmcd.DRV_NOT_INITIALIZED
                        txt = "Note: NOT_INITIALIZED";
                    otherwise
                        txt = "ERROR";
                end
            end

            function logAndor(Logger, label, ret, varargin)
                statusTxt = andorRetString(ret);
            
                isSuccess = (ret == atmcd.DRV_SUCCESS);
                isTempStatus = contains(statusTxt,"TEMP");
            
                % only show numeric code for real errors
                showCode = ~(isSuccess || isTempStatus);
            
                % build value string if present
                hasValue = (nargin >= 4);
                if hasValue
                    value = varargin{1};
                    if label == "IsCoolerOn"
                        if value == 1
                            valueStr = "ON";
                        elseif value == 0
                            valueStr = "OFF";
                        else
                            valueStr = sprintf('UNKNOWN (%d)', value);
                        end
                    else
                        if numel(varargin) >= 2
                            units = varargin{2};
                            valueStr = sprintf('%g %s', value, units);
                        else
                            valueStr = sprintf('%g', value);
                        end
                    end
                end     
                % ---- Logging ----
                if isSuccess || isTempStatus
                    % INFO-level logging
                    if hasValue
                        Logger.info('%s → %s | value = %s', label, statusTxt, valueStr);
                    else
                        Logger.info('%s → %s', label, statusTxt);
                    end
                else
                    % ERROR-level logging
                    if hasValue
                        Logger.error('%s → %s (%d) | value = %s', label, statusTxt, ret, valueStr);
                    else
                        Logger.error('%s → %s (%d)', label, statusTxt, ret);
                    end
                end
            end
            % to monitor temp after shutdown
            function monitorCooler(durationMinutes, intervalSec, Logger)          
                    if nargin < 1 || isempty(durationMinutes)
                        durationMinutes = 5;
                    end
                    if nargin < 2 || isempty(intervalSec)
                        intervalSec = 30;
                    end
                
                    Logger.info('Starting temperature monitoring BEFORE initializing coolerON() for %d minutes, interval %d s', ...
                        durationMinutes, intervalSec);
                
                    tStart = tic;
                
                    while toc(tStart) < durationMinutes*60
                        try
                            [ret, temp] = GetTemperature();
                
                            if ret == atmcd.DRV_SUCCESS || contains(andorRetString(ret),"TEMP")
                                Logger.info('GetTemperature → %s | value = %.2f °C', ...
                                    andorRetString(ret), temp);
                            else
                                Logger.warn('GetTemperature failed → code %d', ret);
                            end
                
                        catch ME
                            Logger.error('Error reading temperature: %s', ME.message);
                        end
                
                        pause(intervalSec);
                    end
                
                    Logger.info('Finished temperature monitoring');
                end

            % (nh) end of test above ----------------------------------


            while true
                pause(0.1)
                if ~isSet
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "SetParameter"
                        %% Check Temp on startup and state of cooler
                        % intial cooler monitoring -----------------
                        if checktemp
                            monitorCooler(5, 60, Logger); 
                        else
                            pause(5)
                        end
                        [ret, status] = IsCoolerOn();
                        logAndor(Logger, 'IsCoolerOn', ret, status);
                        [ret, temperature] = GetTemperature();
                        logAndor(Logger, 'GetTemperature()', ret, temperature, '°C');
                        % [ret, tmin, tmax] = GetTemperatureRange();
                        % logAndor(Logger, 'GetTemperatureRange MIN', ret, tmin, '°C');
                        % logAndor(Logger, 'GetTemperatureRange MAX', ret, tmax, '°C');

                        % 

                        %% Set temperature
                        [ret]=SetCoolerMode(1);     % Camera temperature is maintained on ShutDown
                        CheckError(ret);
                        logAndor(Logger, 'SetCoolerMode(1)', ret);

                        [ret] = SetTemperature(-50);
                        logAndor(Logger, 'SetTemperature(-50)', ret);

                        
                        [ret]=CoolerON();           %   Turn on temperature cooler
                        CheckError(ret);
                        logAndor(Logger, 'CoolerOn()', ret);

                        %(nh) trying out temp stabilization wait-----------
                        % Wait for temperature to stabilize
                        tStart = tic;
                        while true
                            pause(waitduration); % wait a couple of seconds between checks
                            [ret, temp] = GetTemperature();
                            logAndor(Logger, 'GetTemperature()', ret, temp, '°C');
                        
                            if ret == atmcd.DRV_TEMP_STABILIZED
                                Logger.info('Temperature stabilized at %.1f °C', temp);
                                break;
                            end
                        
                            % Optional timeout to avoid infinite loop
                            if toc(tStart) > stabilizewait  % 5 minutes if 300
                                Logger.warn('Temperature not stabilized after wait period');
                                break;
                            end
                        end
                        % (nh) end of temp stabilization monitoring -----

                        %% Check Temp after setting systems
                        [ret, temperature] = GetTemperature();
                        logAndor(Logger, 'GetTemperature()', ret, temperature, '°C');

                        %% Set other parameters
                        [ret]=SetExposureTime(data.ExposureTime);     %   Set exposure time in second  THIS IS THE USUAL VALUE
                        CheckError(ret);
                        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
                        CheckError(ret);
                        [ret]=SetShutter(1, 1, 0, 0);                 %   Open Shutter

                        CheckError(ret);
                        [ret,XPixels, YPixels]=GetDetector;           %   Get the CCD size
                        CheckError(ret);
                        [ret]=SetImage(1, 1, 1, XPixels, 1, YPixels); %   Set the image size
                        CheckError(ret);
                        
                         
                        % (nh) adding in these lines as a test ----------
                        [ret, nPreAmp] = GetNumberPreAmpGains();
                        % logAndor(Logger, 'GetNumberPreAmpGains', ret, nPreAmp);
                        % ^ removing log, since we confirmed preamp works
                        
                        % setting preamp = 2 here, confirming it's act. 2
                        preAmpIndex = -1;
                        for i = 0:nPreAmp-1
                            [ret, gainVal] = GetPreAmpGain(i);
                            %Logger.info('PreAmp index %d → gain %.2f', i, gainVal);
                            if abs(gainVal - 2.0) < 0.01
                                preAmpIndex = i;
                            end
                        end

                        if preAmpIndex < 0
                            Logger.error('Requested preamp gain 2x not available');
                        else
                            [ret] = SetPreAmpGain(preAmpIndex);
                            logAndor(Logger, 'SetPreAmpGain(2x)', ret);
                        end
                        % [ret, state] = GetBaselineClamp();
                        % logRet(Logger, 'GetBaselineClamp()', state); ---
                        % OK, baseline is enabled
                        % (nh) end of test code -------------------------
                        
                        [ret]=SetEMGainMode(3);
                        CheckError(ret);
                        [ret]=SetEMCCDGain(gain-1);                        %   Set EMCCD gain
                        CheckError(ret);
                        
                        if gain>20
                            [ret]=SetCountConvertMode(1);
                            CheckError(ret);
                            logAndor(Logger, 'SetCountConvertMode(1)', ret);
                            imagegain=1;
                            [ret] = IsCountConvertModeAvailable(1);
                            logAndor(Logger, 'IsCountConvertModeAvailable(1)', ret);
                            [ret, gain] = GetEMCCDGain();
                            logAndor(Logger, 'GetEMCCDGain()', ret, gain);
                        else
                            [ret]=SetCountConvertMode(0); %cannot convert to electrons for gain<20
                            CheckError(ret);
                            imagegain=gain/5; %Rough e/adc with preamp gain 2 is about 5 from datasheet, so this gives rough post amp counts to electron conversion.   
                        end
                            %End of edited codes
                        bitPerSample = data.BitPerSample;

                        

                        %% Set acquisition mode
                        switch data.AcquisitionMode
                            case "Absorption"
                                acqMode = "Absorption";
                                groupSize = 3;
                                
                                [ret]=SetAcquisitionMode(5);        %   Run till abort
                                CheckError(ret);
                                [ret]=SetTriggerMode(1);            %   Set external trigger mode
                                CheckError(ret);
                        end
                        isSet = true;
                        mData = zeros(YPixels,XPixels,groupSize);
                        Logger.info("Settings complete.")
                       
                        %% Check Temp after setting systems
                        [ret, temperature] = GetTemperature();
                        logAndor(Logger, 'GetTemperature', ret, temperature, '°C');

                    end
                elseif ~isAcq
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "Start"
                        %% Start acquisition
                        [ret] = FreeInternalMemory();
                        CheckError(ret);
                        [ret] = atmcdmex('SetMetaData', 1);
                        CheckError(ret);
                        [ret] = StartAcquisition();
                        CheckError(ret);
                        isAcq = true;
                        [ret, lastGotten, lastIndex] = GetNumberNewImages();% Find the starting index of the buffer.

                        if (ret == atmcd.DRV_SUCCESS || ret == atmcd.DRV_NO_NEW_DATA) Logger.info('GNNI: R-%d, FI-%d, LI-%d', ret, lastGotten, lastIndex);
                        else Logger.error('GNNI: R-%d, FI-%d, LI-%d', ret, lastGotten, lastIndex); end
                        Logger.info("Beginning Acquisition");
                        GroupNumber = 1;
                    end
                else
                    %% Acuiqision

                    % Setting this return value to avoid evaluation of the "if" statement
                    % for saving a new image if there is no new image.
                    atmcd.DRV_NO_NEW_DATA;

                    % Find "first" which is the index for the oldest image in the buffer.
                    % Updates when GetImages is called, but after having gotten all the
                    % images, it returns first = last = "the newest image that exists" even
                    % if the "newest image" in the buffer was already retreived.
                    [ret, firstIndex, lastIndex] = GetNumberNewImages();

                    if (ret == atmcd.DRV_SUCCESS) Logger.info('GNNI: R-%d, FI-%d, LI-%d', ret, firstIndex, lastIndex);
                    elseif (ret ~= atmcd.DRV_NO_NEW_DATA) Logger.error('GNNI: R-%d, FI-%d, LI-%d', ret, firstIndex, lastIndex); end
                    
                    if lastGotten~=lastIndex
                        indexToGet = firstIndex;

                        % Retreive the oldest new image from the camera buffer.
                        [ret, imageData, validfirst, validlast] = GetImages(indexToGet, indexToGet, XPixels * YPixels);
                        if (ret == atmcd.DRV_SUCCESS) Logger.info('GI: R-%d, VF-%d, VL-%d', ret, validfirst, validlast);
                        elseif (ret ~= atmcd.DRV_NO_NEW_DATA) Logger.error('GI: R-%d, VF-%d, VL-%d', ret, validfirst, validlast); end

                        if ret == atmcd.DRV_SUCCESS % data returned
                            [ret, ~, pfTimeFromStart] = GetMetaDataInfo(indexToGet);%atmcdmex('GetMetaDataInfo', indexToGet);
                            if (ret == atmcd.DRV_SUCCESS) Logger.info('GMDI: R-%d, TFS-%d', ret, pfTimeFromStart);
                            else Logger.warn('GMDI: R-%d, TFS-%d', ret, pfTimeFromStart); end
                            
                            lastGotten = firstIndex;
                            imageCount = imageCount + 1;
                            imageData = flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                            imageData = imageData/imagegain;
                            mData(:,:,imageCount) = imageData;

                            % Send image data to the client
                            if imageCount == groupSize
                                imageCount = 0;
                                switch bitPerSample
                                    case 8
                                        mData = uint8(mData);
                                    case 16
                                        mData = uint16(mData);
                                    case 32
                                        mData = uint32(mData);
                                end
                                send(cdq,mData);
                                Logger.info("Sent Data Group %d", GroupNumber)
                                GroupNumber = GroupNumber + 1;

                                % added this to check temperature again: 
                                [ret, temperature] = GetTemperature();
                                logAndor(Logger, 'GetTemperature', ret, temperature, '°C');
                            end
                        end
                    end
                    
                    %% Stop
                    [data,datarcvd] = poll(wq);
                    if datarcvd && data.Message == "Stop"
                        Logger.info("Stopping Camera");
                        disp("stopping camera");
                        [ret] = AbortAcquisition();
                        CheckError(ret);

                        [ret, status] = IsCoolerOn();
                        logAndor(Logger, 'IsCoolerOn', ret, status);
                        
                        [ret]=SetShutter(1, 2, 1, 1);
                        CheckError(ret);
                        [ret] = AndorShutDown();
                        CheckError(ret);

                        break
                    end
                end
            end
        end
    end
end

