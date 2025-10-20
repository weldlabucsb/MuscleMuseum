classdef Andor < Acquisition

    %:class:`Andor` acquisition class using Andor's proprietary SDK via a worker.
    %
    % Uses a parallel worker loop (:meth:`andorLoop`) to manage camera acquisition
    % asynchronously and communicates via :class:`parallel.pool.DataQueue`.
    properties (SetAccess=protected,Transient)
        CallbackFunc function_handle
        Future parallel.FevalFuture
        ClientDataQueue parallel.pool.DataQueue
        ClientQueue parallel.pool.PollableDataQueue
        WorkerQueue parallel.pool.PollableDataQueue
        ClientListener event.listener
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
            % Connect to the camera by launching a worker loop and queues.

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
            % Set absorption-imaging camera parameters on the worker.
            data.Message = "SetParameter";
            data.AcquisitionMode = "Absorption";
            data.ExposureTime = obj.ExposureTime;
            data.BitPerSample = obj.BitsPerSample;
            obj.ImageGroupSize = 3;
            send(obj.WorkerQueue,data);
        end

        function setCallback(obj,callbackFunc)
            % Set camera callback function.
            obj.ClientListener = afterEach(obj.ClientDataQueue,@(x) callbackFunc(x,[]));
        end

        function startCamera(obj)
            % Start acquisition on the worker.
            data.Message = "Start";
            send(obj.WorkerQueue,data);
            obj.checkError;
        end

        function pauseCamera(obj)
            % Pause camera recording (not implemented; Andor SDK example).
            % [ret] = AbortAcquisition();
            % CheckWarning(ret);
        end

        function stopCamera(obj)
            % Stop camera recording and tear down worker-side state.
            data.Message = "Stop";
            send(obj.WorkerQueue,data);
            obj.checkError;
            cancel(obj.Future)
            delete(obj.ClientListener)
        end

        function checkError(obj)
            % Throw worker errors on the client if present.
            if ~isempty(obj.Future.Error)
                obj.Future.Error.throw
            end
        end
    end

    methods (Static)
        function andorLoop(cq,cdq)
            % Worker loop managing Andor SDK calls.
            %
            % Sends a worker queue back to the client, initializes SDK, and handles
            % messages for parameter setup, Start, data transfer, and Stop.
            % Uses :class:`parallel.pool.PollableDataQueue` for communication.
            % Send the worker queue to the client
            wq = parallel.pool.PollableDataQueue;
            send(cq,wq);

            % Initialize the andor SDK libariry
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

            while true
                pause(0.1)
                if ~isSet
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "SetParameter"
                        %% Set temperature
                        [ret]=SetCoolerMode(1);     % Camera temperature is maintained on ShutDown
                        CheckWarning(ret);
                        [ret]=CoolerON();           %   Turn on temperature cooler
                        CheckWarning(ret);

                        %% Set other parameters
                        [ret]=SetExposureTime(data.ExposureTime);     %   Set exposure time in second  THIS IS THE USUAL VALUE
                        CheckWarning(ret);
                        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
                        CheckWarning(ret);
                        [ret]=SetShutter(1, 1, 0, 0);                 %   Open Shutter
                        CheckWarning(ret);
                        [ret,XPixels, YPixels]=GetDetector;           %   Get the CCD size
                        CheckWarning(ret);
                        [ret]=SetImage(1, 1, 1, XPixels, 1, YPixels); %   Set the image size
                        CheckWarning(ret);
                        [ret]=SetEMCCDGain(1);                        %   Set EMCCD gain
                        CheckWarning(ret);
                        bitPerSample = data.BitPerSample;

                        %% Set acquisition mode
                        switch data.AcquisitionMode
                            case "Absorption"
                                acqMode = "Absorption";
                                groupSize = 3;

                                [ret]=SetAcquisitionMode(3);        %   Set acquisition mode; 3 for Kinetic Series
                                CheckWarning(ret);
                                [ret]=SetNumberKinetics(groupSize);
                                CheckWarning(ret);
                                [ret]=SetTriggerMode(1);            %   Set external trigger mode
                                CheckWarning(ret);
                        end
                        isSet = true;                      
                    end
                elseif ~isAcq
                    [data,datarcvd] = poll(wq,10);
                    if datarcvd && data.Message == "Start"
                        %% Start acquisition
                        [ret] = StartAcquisition();
                        CheckWarning(ret);
                        isAcq = true;
                    end
                else
                    % Setting this return value to avoid evaluation of the "if" statement
                    % for saving a new image if there is no new image.
                    atmcd.DRV_NO_NEW_DATA;

                    % Find "first" which is the index for the oldest image in the buffer.
                    % Updates when GetImages is called, but after having gotten all the
                    % images, it returns first = last = "the newest image that exists" even
                    % if the "newest image" in the buffer was already retreived.
                    [~, firstIndex, lastIndex] = GetNumberNewImages();

                    %% Send image data to the client
                    if (lastIndex - firstIndex + 1) == groupSize
                        switch acqMode
                            case "Absorption"
                                [~, mData, ~, ~] = GetImages(firstIndex, lastIndex, ...
                                    prod([XPixels,YPixels,groupSize]));
                                mData = reshape(mData, XPixels, YPixels, groupSize);
                                for ii = 1:groupSize
                                    mData(:,:,ii) = flip(transpose(mData(:,:,ii)),1);
                                end

                                switch bitPerSample
                                    case 8
                                        mData = uint8(mData);
                                    case 16
                                        mData = uint16(mData);
                                    case 32
                                        mData = uint32(mData);
                                end

                                [ret] = StartAcquisition();
                                CheckWarning(ret);
                                send(cdq,mData)
                        end
                    end
                    
                    %% Stop
                    [data,datarcvd] = poll(wq);
                    if datarcvd && data.Message == "Stop"
                        [ret] = AbortAcquisition();
                        CheckWarning(ret);
                        [ret]=SetShutter(1, 2, 1, 1);
                        CheckWarning(ret);
                        [ret] = AndorShutDown();
                        CheckWarning(ret);
                        break
                    end
                end
            end
        end
    end
end

