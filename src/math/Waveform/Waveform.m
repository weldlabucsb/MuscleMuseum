classdef (Abstract) Waveform < handle
    %:class:`Waveform` generates and stores waveforms. By definition, a
    %waveform can refer to either a function of time, or a time-sequence of
    %samples. The definition of a :class:`Waveform` is given by the output
    %of the :meth:`TimeFunc`, as a function handle, which takes a time
    %array as the argument. Every concrete subclass of :class:`Waveform`
    %must define a :meth:`TimeFunc` method. The samples of the
    %:class:`Waveform` is then calculated whenever :attr:`Sample` is
    %called, based on the :meth:`TimeFunc` and the other paramters.
    
    properties
        SamplingRate double {mustBePositive} = 1 % In Hertz
        StartTime double = 0 % In seconds
        Duration double {mustBeNonnegative} = 0.1 % In seconds
        Scan table = table(string.empty,string.empty, 'VariableNames',{'ParameterName','VariableName'}) % For scanning parameters in Hardware control panel
    end

    properties (Dependent)
        EndTime % Dependent on :attr:`StartTime` and :attr:`Duration`
        TimeStep % Dependent on :attr:`SamplingRate`
        NSample % Dependent on :attr:`SamplingRate` and :attr:`Duration`
        Sample % Dependent on :meth:`TimeFunc`, :attr:`StartTime`, :attr:`TimeStep`, and :attr:`EndTime`
    end
    
    methods
        function obj = Waveform()
            %Construct an instance of this class
        end

        function te = get.EndTime(obj)
            te = obj.StartTime + obj.Duration;
        end

        function nS = get.NSample(obj)
            nS = floor(obj.Duration * obj.SamplingRate) + 1;
        end

        function dt = get.TimeStep(obj)
            dt = 1/obj.SamplingRate;
        end

        function s = get.Sample(obj)
            tFunc = obj.TimeFunc;
            t = obj.StartTime : obj.TimeStep : obj.EndTime;
            s = tFunc(t);
        end
        
        function plot(obj)
            %Plot and render the waveform using the given sampling rate

            t = obj.StartTime : obj.TimeStep : obj.EndTime;
            s = obj.Sample;
            plot(t,s)
            xlabel("Time [s]",Interpreter="latex")
            ylabel("Signal",Interpreter="latex")
            render
        end
    end

    methods (Abstract)
        TimeFunc(obj)
    end

end

