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
            try
                AndorShutDown();
            catch
            end
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
            

            while true
                pause(0.1)
                if ~isSet
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "SetParameter"
                        %% Set temperature
                        [ret]=SetCoolerMode(1);     % Camera temperature is maintained on ShutDown
                        CheckError(ret);
                        [ret]=CoolerON();           %   Turn on temperature cooler
                        CheckError(ret);

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
                        [ret]=SetEMCCDGain(1);                        %   Set EMCCD gain
                        CheckError(ret);
                        bitPerSample = data.BitPerSample;

                        %% Set acquisition mode
                        switch data.AcquisitionMode
                            case "Absorption"
                                acqMode = "Absorption";
                                groupSize = 3;

                                [ret]=SetAcquisitionMode(3);        %   Set acquisition mode; 3 for Kinetic Series
                                CheckError(ret);
                                [ret]=SetNumberKinetics(groupSize);
                                CheckError(ret);
                                [ret]=SetTriggerMode(1);            %   Set external trigger mode
                                CheckError(ret);
                        end
                        isSet = true;
                        mData = zeros(YPixels,XPixels,groupSize);
                    end
                elseif ~isAcq
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "Start"
                        %% Start acquisition
                        [ret] = FreeInternalMemory();
                        CheckError(ret);
                        [ret] = StartAcquisition();
                        CheckError(ret);
                        isAcq = true;
                        [~, lastGotten, ~] = GetNumberNewImages();% Find the starting index of the buffer.
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
                    [~, firstIndex, lastIndex] = GetNumberNewImages();

                    if lastGotten~=lastIndex
                        indexToGet = firstIndex;

                        % Retreive the oldest new image from the camera buffer.
                        [ret, imageData, ~, ~] = GetImages(indexToGet, indexToGet, XPixels * YPixels);

                        % Update the last gotten image.
                        if ret == atmcd.DRV_SUCCESS % data returned
                            lastGotten = firstIndex;
                            imageCount = imageCount + 1;
                            imageData = flip(transpose(reshape(imageData, XPixels, YPixels)),1);
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
                                send(cdq,mData)
                                [ret] = FreeInternalMemory();
                                CheckError(ret);
                                [ret] = StartAcquisition();
                                CheckError(ret);
                            end
                        end
                    end
                    
                    %% Stop
                    [data,datarcvd] = poll(wq);
                    if datarcvd && data.Message == "Stop"
                        disp("stopping camera")
                        [ret] = AbortAcquisition();
                        CheckError(ret);
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

