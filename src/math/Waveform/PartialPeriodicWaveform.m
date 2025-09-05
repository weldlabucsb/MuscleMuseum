classdef (Abstract) PartialPeriodicWaveform < Waveform
    %:class:`PartialPeriodicWaveform` abstract base class for partial periodic waveforms.
    %
    % Provides common functionality for waveforms that have periodic behavior
    % only during a portion of their duration, with rise and fall transitions.
    % Useful for pulse-like signals with smooth transitions. Inherits from :class:`Waveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with rise and fall times
    %     pulse = TrapezoidalPulse(amplitude = 2.0, ...
    %                              riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Check periodic properties
    %     disp(['Periodic duration: ', num2str(pulse.PeriodicDuration), ' s']);
    %     disp(['Number of periods: ', num2str(pulse.NPeriod)]);
    
    properties
        Amplitude double = 0 % Peak-to-peak amplitude, usually in Volts.
        Offset double = 0 % Offset, usually in Volts.
        Frequency double {mustBePositive} = 100 % In Hz
        Phase double = 0 % In radians
        RiseTime double {mustBeNonnegative} = 0 % In s - Rise transition time.
        FallTime double {mustBeNonnegative} = 0 % In s - Fall transition time.
    end

    properties (Dependent)
        PeriodicStartTime % Start time of the periodic portion.
        PeriodicDuration % Duration of the periodic portion.
        PeriodicEndTime % End time of the periodic portion.
        Period % In s - Time period of one complete cycle.
        NPeriod % Number of complete periods in the periodic duration.
        NRepeat % Number of times the cycle segment repeats.
        DurationOneCycle % Duration of one complete cycle segment.
        EndTimeAllCycle % End time of all complete cycles.
        SampleOneCycle % Sample values for one complete cycle.
        SampleExtra % Extra samples beyond complete cycles.
        SampleBefore % Samples before the periodic portion.
        SampleAfter % Samples after the periodic portion.
    end

    properties (Hidden)
        NPeriodPerCycle double = 10 % Number of cycles per repeat segment.
    end
    
    methods
        function obj = PartialPeriodicWaveform()
            %Construct a PartialPeriodicWaveform object.
            %
            % Abstract base class constructor. Subclasses should implement
            % their own constructors with appropriate parameters.
        end
        
        function t0P = get.PeriodicStartTime(obj)
            %Get the start time of the periodic portion.
            %
            % Calculated as :attr:`StartTime` + :attr:`RiseTime`.
            %
            % :return: Start time in seconds
            % :rtype: double
            t0P = obj.StartTime + obj.RiseTime;
        end

        function tdP = get.PeriodicDuration(obj)
            %Get the duration of the periodic portion.
            %
            % Calculated as :attr:`Duration` - :attr:`RiseTime` - :attr:`FallTime`.
            %
            % :return: Duration in seconds
            % :rtype: double
            tdP = obj.Duration - obj.RiseTime - obj.FallTime;
        end

        function teP = get.PeriodicEndTime(obj)
            %Get the end time of the periodic portion.
            %
            % Calculated as :attr:`PeriodicStartTime` + :attr:`PeriodicDuration`.
            %
            % :return: End time in seconds
            % :rtype: double
            teP = obj.PeriodicStartTime + obj.PeriodicDuration;
        end
        
        function T = get.Period(obj)
            %Get the time period of one complete cycle.
            %
            % :return: Period in seconds
            % :rtype: double
            if isa(obj,"ConstantTop")
                T = 1 / obj.SamplingRate * 10;
            else
                T = 1 / obj.Frequency;
            end
        end

        function nP = get.NPeriod(obj)
            %Get the number of complete periods in the periodic duration.
            %
            % :return: Number of periods
            % :rtype: double
            nP = obj.PeriodicDuration / obj.Period;
        end

        function nR = get.NRepeat(obj)
            %Get the number of times the cycle segment repeats.
            %
            % :return: Number of repeats
            % :rtype: double
            if obj.NPeriod <= obj.NPeriodPerCycle
                nR = 1;
            else
                nR = floor(obj.NPeriod / obj.NPeriodPerCycle);
            end
        end

        function tC = get.DurationOneCycle(obj)
            %Get the duration of one complete cycle segment.
            %
            % :return: Duration in seconds
            % :rtype: double
            tC = (obj.Period * obj.NPeriodPerCycle);
        end

        function s = get.SampleOneCycle(obj)
            %Get sample values for one complete cycle.
            %
            % :return: Vector of sample values for one cycle
            % :rtype: double
            if obj.NRepeat == 1 && isempty(obj.SampleExtra)
                tFunc = obj.TimeFunc;
                t = obj.PeriodicStartTime : obj.TimeStep : (obj.PeriodicEndTime -  - obj.TimeStep);
                s = tFunc(t);
            else
                if obj.PeriodicStartTime ~= obj.PeriodicEndTime
                    tFunc = obj.TimeFunc;
                    t = obj.PeriodicStartTime : obj.TimeStep : (obj.PeriodicStartTime + obj.DurationOneCycle - obj.TimeStep);
                    s = tFunc(t);
                else
                    s = [];
                end
            end
        end

        function teC = get.EndTimeAllCycle(obj)
            %Get the end time of all complete cycles.
            %
            % :return: End time in seconds
            % :rtype: double
            if obj.NRepeat == 1
                teC = obj.PeriodicEndTime;
            else
                teC = obj.DurationOneCycle * obj.NRepeat + obj.PeriodicStartTime - obj.TimeStep;
            end
        end

        function s = get.SampleExtra(obj)
            %Get extra samples beyond complete cycles.
            %
            % Returns samples for the remaining time after all complete
            % cycles within the periodic portion.
            %
            % :return: Vector of extra sample values (may be empty)
            % :rtype: double
            tFunc = obj.TimeFunc;
            if isa(obj,"ConstantTop")
                s = [];
            elseif abs(obj.PeriodicEndTime - obj.EndTimeAllCycle) <= obj.TimeStep
                s = [];
            else
                t = (obj.EndTimeAllCycle + obj.TimeStep) : obj.TimeStep : obj.PeriodicEndTime;
                s = tFunc(t);
            end
        end

        function s = get.SampleBefore(obj)
            %Get samples before the periodic portion.
            %
            % Returns samples for the rise transition period.
            %
            % :return: Vector of sample values before periodic portion (may be empty)
            % :rtype: double
            if abs(obj.PeriodicStartTime - obj.StartTime) <= obj.TimeStep
                s = [];
            else
                t = obj.StartTime:obj.TimeStep:(obj.PeriodicStartTime - obj.TimeStep);
                tFunc = obj.TimeFunc;
                s = tFunc(t);
            end
        end

        function s = get.SampleAfter(obj)
            %Get samples after the periodic portion.
            %
            % Returns samples for the fall transition period and any extra
            % samples beyond the periodic portion.
            %
            % :return: Vector of sample values after periodic portion
            % :rtype: double
            if abs(obj.PeriodicEndTime - obj.EndTime) <= obj.TimeStep
                s = obj.SampleExtra;
            else
                t = (obj.PeriodicEndTime + obj.TimeStep):obj.TimeStep:obj.EndTime;
                tFunc = obj.TimeFunc;
                s = tFunc(t);
                s = [obj.SampleExtra,s];
            end
        end

        function plotOneCycle(obj)
            %Plot one complete cycle of the periodic portion.
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     pulse = TrapezoidalPulse(amplitude = 2.0, frequency = 1000);
            %     pulse.plotOneCycle();
            figure(10843)
            t = obj.PeriodicStartTime : obj.TimeStep : (obj.PeriodicStartTime + obj.DurationOneCycle - obj.TimeStep);
            s = obj.SampleOneCycle;
            plot(t,s)
            xlabel("Time [s]",Interpreter="latex")
            ylabel("Signal",Interpreter="latex")
            render
        end

        function plotExtra(obj)
            %Plot extra samples beyond complete cycles.
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     pulse = TrapezoidalPulse(amplitude = 2.0, frequency = 1000, duration = 0.015);
            %     pulse.plotExtra();
            s = obj.SampleExtra;
            if isempty(s)
                return
            end
            figure(10844)
            t = (obj.EndTimeAllCycle + obj.TimeStep) : obj.TimeStep : obj.PeriodicEndTime;            
            plot(t,s)
            xlabel("Time [s]",Interpreter="latex")
            ylabel("Signal",Interpreter="latex")
            render
        end
    end
end

