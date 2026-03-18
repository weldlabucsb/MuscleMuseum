classdef (Abstract) Scope < Hardware
    %:class:`Scope` abstract base for oscilloscopes.
    %
    % Provides common acquisition timing (:attr:`Duration`, :attr:`NSample`),
    % trigger configuration (:attr:`TriggerMode`, :attr:`TriggerSource`, :attr:`TriggerSlope`, :attr:`TriggerLevel`),
    % measurement helpers (peak-to-peak, extrema, mean, RMS, std), and sine-fit
    % quantities (:attr:`SineAmplitude`, :attr:`SineFrequency`, :attr:`SinePhase`, :attr:`SineOffset`).
    % Concrete subclasses implement vendor-specific connections and I/O.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    sc = Tektronix1104("USB0::...", name="Scope");
    %    sc.connect();
    %    sc.Duration = 0.01; sc.NSample = 2500; sc.IsEnabled = [true true false false];
    %    sc.set();
    %    sc.read();
    %    sc.plot();

    properties
        Duration double {mustBePositive} = 0.1 % Total record length [s]
        NSample double {mustBeInteger,mustBePositive} = 2500 % Number of samples to acquire
        TriggerMode string {mustBeMember(TriggerMode,{'Normal','Auto','Software'})} = "Normal" % Trigger mode
        TriggerSource string = "External" % Trigger source identifier
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise" % Trigger edge
        TriggerLevel double = 0.1 % Trigger threshold (in :attr:`SampleUnit`)
        IsEnabled logical % Per-channel enable flags
        VerticalCoupling string {mustBeMember(VerticalCoupling,{'DC','AC'})} = "DC" % Input coupling per channel
        VerticalOffset double = 0 % Vertical offset per channel (in :attr:`SampleUnit`)
        VerticalRange double = 10 % Vertical range per channel (in :attr:`SampleUnit`)
    end

    properties (SetAccess = protected)
        SamplingRateMax double % Maximum supported sampling rate [Hz]
        Sample double % Latest acquired samples [nCh x NSample]
        SampleUnit string % Engineering unit for samples (e.g., "V")
        NSampleMax double % Maximum supported samples per record
        TrapezoidalFit TrapezoidalFit
    end

    properties (Dependent)
        TimeList % Time vector corresponding to :attr:`Sample`
        SamplingRate % Sampling rate [Hz]
        PeakToPeak % Peak-to-peak per channel
        Max % Max per channel
        Min % Min per channel
        Mean % Mean per channel
        Rms % RMS per channel
        Std % Standard deviation per channel
        SineFit SineFit1D % Sine fits per enabled channel
        SineAmplitude % Fitted sine amplitude per enabled channel
        SineFrequency % Fitted sine frequency per enabled channel [Hz]
        SinePhase % Fitted sine phase per enabled channel [rad]
        SineOffset % Fitted sine DC offset per enabled channel
        TrapezoidalAmplitude
        TrapezoidalDuration
        TrapezoidalOffset
    end

    methods
        function obj = Scope(resourceName,name)
            arguments
                resourceName string
                name string = string.empty
            end
            obj@Hardware(resourceName,name)
        end

        function set.NSample(obj,val)
            if isempty(obj.SamplingRateMax)
                obj.NSample = val;
            else
                sr = val / obj.Duration;
                if sr > obj.SamplingRateMax
                    obj.NSample = obj.SamplingRateMax * obj.Duration;
                else
                    obj.NSample = val;
                end
            end
        end

        function set.Duration(obj,val)
            if isempty(obj.SamplingRateMax)
                obj.Duration = val;
            else
                obj.Duration = val;
                sr = obj.NSample / val;
                if sr > obj.SamplingRateMax
                    obj.NSample = obj.SamplingRateMax * val;
                end
            end
        end

        function tL = get.TimeList(obj)
            % Get time vector of the acquired record.
            %
            % :return: Time values from 0 to :attr:`Duration` with :attr:`NSample` points
            % :rtype: double row vector
            tL = linspace(0,obj.Duration,obj.NSample);
        end

        function sR = get.SamplingRate(obj)
            % Get sampling rate from :attr:`NSample` and :attr:`Duration`.
            %
            % :return: Sampling rate [Hz]
            % :rtype: double
            sR = obj.NSample / obj.Duration;
        end

        function p2p = get.PeakToPeak(obj)
            % Compute peak-to-peak values per enabled channel.
            %
            % :return: Peak-to-peak amplitudes
            % :rtype: double column vector
            data = obj.Sample;
            p2p = max(data,[],2) - min(data,[],2);
        end

        function maxV = get.Max(obj)
            % Get maximum per channel.
            data = obj.Sample;
            maxV = max(data,[],2);
        end

        function minV = get.Min(obj)
            % Get minimum per channel.
            data = obj.Sample;
            minV = min(data,[],2);
        end

        function meanV = get.Mean(obj)
            % Get mean per channel.
            data = obj.Sample;
            meanV = mean(data,2);
        end

        function rmsV = get.Rms(obj)
            % Get RMS per channel.
            data = obj.Sample;
            rmsV = rms(data,2);
        end

        function stdV = get.Std(obj)
            % Get standard deviation per channel.
            data = obj.Sample;
            stdV = std(data,0,2);
        end

        function sineFit = get.SineFit(obj)
            % Fit each channel with a sine model using :class:`SineFit1D`.
            %
            % :return: Sine fits for enabled channels
            % :rtype: :class:`SineFit1D` array
            data = obj.Sample;
            t = obj.TimeList;
            sineFit = SineFit1D.empty;
            for ii = 1:size(data,1)
                sineFit(ii) = SineFit1D([t.',data(ii,:).']);
                sineFit(ii).do;
            end
        end

        function sineA = get.SineAmplitude(obj)
            % Get sine-fit amplitudes for enabled channels.
            %
            % :return: Amplitudes
            % :rtype: double column vector
            sineA = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineA(ii) = sF(ii).Coefficient(1);
            end
        end

        function sineF = get.SineFrequency(obj)
            % Get sine-fit frequencies for enabled channels.
            %
            % :return: Frequencies [Hz]
            % :rtype: double column vector
            sineF = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineF(ii) = sF(ii).Coefficient(2);
            end
        end

        function sinePhi = get.SinePhase(obj)
            % Get sine-fit phases for enabled channels.
            %
            % :return: Phases [rad]
            % :rtype: double column vector
            sinePhi = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sinePhi(ii) = sF(ii).Coefficient(3);
            end
        end

        function sineC = get.SineOffset(obj)
            % Get sine-fit DC offsets for enabled channels.
            %
            % :return: DC offsets
            % :rtype: double column vector
            sineC = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineC(ii) = sF(ii).Coefficient(4);
            end
        end

        function doTrapezFit(obj)
            % Fit each channel with a sine model using :class:`SineFit1D`.
            %
            % :return: Sine fits for enabled channels
            % :rtype: :class:`SineFit1D` array
            if ~isempty(obj.TrapezoidalFit)
                return
            end
            data = obj.Sample;
            t = obj.TimeList;
            for ii = 1:size(data,1)
                obj.TrapezoidalFit(ii) = TrapezoidalFit([t.',data(ii,:).']);
                obj.TrapezoidalFit(ii).do;
            end
        end

        function trapezA = get.TrapezoidalAmplitude(obj)
            % Get sine-fit amplitudes for enabled channels.
            %
            % :return: Amplitudes
            % :rtype: double column vector
            obj.doTrapezFit
            tF = obj.TrapezoidalFit;
            trapezA = zeros(sum(obj.IsEnabled),1);
            for ii = 1:sum(obj.IsEnabled)
                trapezA(ii) = tF(ii).Coefficient(5);
            end
        end

        function trapezC = get.TrapezoidalOffset(obj)
            % Get sine-fit amplitudes for enabled channels.
            %
            % :return: Amplitudes
            % :rtype: double column vector
            obj.doTrapezFit
            tF = obj.TrapezoidalFit;
            trapezC = zeros(sum(obj.IsEnabled),1);
            for ii = 1:sum(obj.IsEnabled)
                trapezC(ii) = tF(ii).Coefficient(6);
            end
        end

        function trapezT = get.TrapezoidalDuration(obj)
            % Get sine-fit amplitudes for enabled channels.
            %
            % :return: Amplitudes
            % :rtype: double column vector
            obj.doTrapezFit
            tF = obj.TrapezoidalFit;
            trapezT = zeros(sum(obj.IsEnabled),1);
            for ii = 1:sum(obj.IsEnabled)
                t0 = tF(ii).Coefficient(1);
                te = tF(ii).Coefficient(2);
                tr = tF(ii).Coefficient(3);
                tf = tF(ii).Coefficient(4);
                trapezT(ii) = te - t0 - (tr + tf)/2;
            end
        end

        function plot(obj,ax)
            % Plot captured waveforms vs time.
            %
            % :param ax: Target axes (default: create new figure)
            % :type ax: axes, optional
            arguments
                obj Scope
                ax = []
            end
            t = obj.TimeList;
            data = obj.Sample;
            if isempty(ax)
                figure(8672)
                plot(t,data)
                xlabel("Time [s]",'Interpreter','latex')
                ylabel("Sample Data ["+ obj.SampleUnit + "]",'Interpreter','latex')
                cName = "Channel " + string(find(obj.IsEnabled));
                legend(cName(:),'Interpreter','latex')
                render
            elseif isa(ax,"matlab.graphics.axis.Axes")
                l = plot(ax,t,data);
                xlabel(ax,"Time [s]",'Interpreter','latex')
                ylabel(ax,"Sample Data ["+ obj.SampleUnit + "]",'Interpreter','latex')
                cName = "Channel " + string(find(obj.IsEnabled));
                legend(ax,cName(:),'Interpreter','latex')
                for ii = 1:numel(l)
                    l(ii).LineWidth = 2;
                end
            else
                error("ax must be a MATLAB graphicx axis object.")
            end
        end

    end

    methods (Abstract)
        connect(obj)
        % Establish a connection to the scope.
        set(obj)
        % Apply acquisition, trigger, and channel configuration to the scope.
        read(obj)
        % Acquire data into :attr:`Sample`.
        close(obj)
        % Close the scope session.
        status = check(obj)
        % Return true if the instrument state is valid and limits are satisfied.
    end
end

