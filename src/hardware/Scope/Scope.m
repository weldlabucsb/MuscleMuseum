classdef (Abstract) Scope < Hardware
    %WAVEFORMGENERATOR Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Duration double {mustBePositive} = 0.1 %The time in seconds that corresponds to the record length
        NSample double {mustBeInteger,mustBePositive} = 2500 % How many data points to collect
        TriggerMode string {mustBeMember(TriggerMode,{'Normal','Auto','Software'})} = "Normal"
        TriggerSource string = "External"
        TriggerSlope string {mustBeMember(TriggerSlope,{'Rise','Fall'})} = "Rise"
        TriggerLevel double = 0.1
        IsEnabled logical
        VerticalCoupling string {mustBeMember(VerticalCoupling,{'DC','AC'})} = "DC"
        VerticalOffset double = 0
        VerticalRange double = 10
    end

    properties (SetAccess = protected)
        SamplingRateMax double
        Sample double
        SampleUnit string
        NSampleMax double
    end

    properties (Dependent)
        TimeList
        SamplingRate
        PeakToPeak
        Max
        Min
        Mean
        Rms
        Std
        SineFit SineFit1D
        SineAmplitude
        SineFrequency
        SinePhase
        SineOffset
    end

    methods
        function obj = Scope(resourceName,name)
            arguments
                resourceName string
                name string = string.empty
            end
            obj@Hardware(resourceName,name)
        end

        function tL = get.TimeList(obj)
            tL = linspace(0,obj.Duration,obj.NSample);
        end

        function sR = get.SamplingRate(obj)
            sR = obj.NSample / obj.Duration;
        end

        function p2p = get.PeakToPeak(obj)
            data = obj.Sample;
            p2p = max(data,[],2) - min(data,[],2);
        end

        function maxV = get.Max(obj)
            data = obj.Sample;
            maxV = max(data,[],2);
        end

        function minV = get.Min(obj)
            data = obj.Sample;
            minV = min(data,[],2);
        end

        function meanV = get.Mean(obj)
            data = obj.Sample;
            meanV = mean(data,2);
        end

        function rmsV = get.Rms(obj)
            data = obj.Sample;
            rmsV = rms(data,2);
        end

        function stdV = get.Std(obj)
            data = obj.Sample;
            stdV = std(data,0,2);
        end

        function sineFit = get.SineFit(obj)
            data = obj.Sample;
            t = obj.TimeList;
            sineFit = SineFit1D.empty;
            for ii = 1:size(data,1)
                sineFit(ii) = SineFit1D([t.',data(ii,:).']);
                sineFit(ii).do;
            end
        end

        function sineA = get.SineAmplitude(obj)
            sineA = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineA(ii) = sF(ii).Coefficient(1);
            end
        end

        function sineF = get.SineFrequency(obj)
            sineF = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineF(ii) = sF(ii).Coefficient(2);
            end
        end

        function sinePhi = get.SinePhase(obj)
            sinePhi = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sinePhi(ii) = sF(ii).Coefficient(3);
            end
        end

        function sineC = get.SineOffset(obj)
            sineC = zeros(sum(obj.IsEnabled),1);
            sF = obj.SineFit;
            for ii = 1:sum(obj.IsEnabled)
                sineC(ii) = sF(ii).Coefficient(4);
            end
        end

        function plot(obj,ax)
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
        set(obj)
        read(obj)
        close(obj)
        status = check(obj)
    end
end

