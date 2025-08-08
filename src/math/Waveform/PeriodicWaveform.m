classdef (Abstract) PeriodicWaveform < Waveform
    %:class:`PeriodicWaveform` abstract base class for periodic waveform generation.
    %
    % Provides common functionality for waveforms that repeat with a defined
    % frequency, period, and phase. Supports cycle-based repetition and
    % hardware-optimized sample generation for efficient waveform output.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a periodic sine wave
    %     sine = SineWave(frequency = 1000, amplitude = 1.0, duration = 0.01);
    %     sine.plotOneCycle();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Check repetition properties
    %     disp(['Period: ', num2str(sine.Period), ' s']);
    %     disp(['Number of repeats: ', num2str(sine.NRepeat)]);
    
    properties
        Amplitude double = 0 % Peak-to-peak amplitude, usually in Volts.
        Offset double = 0 % Offest, usually in Volts.
        Frequency double {mustBePositive} = 100 % In Hz
        Phase double = 0 % In radians
    end

    properties (Hidden)
        NCycle double = 10 % Number of cycles per repeat segment.
        MinimumSampleSize double = 32 % Minimum sample size for hardware compatibility.
    end

    properties (Dependent)
        Period % In s - Time period of one complete cycle.
        NPeriod % Number of complete periods in the waveform duration.
        NRepeat % Number of times the cycle segment repeats.
        DurationOneCycle % Duration of one complete cycle segment.
        EndTimeAllCycle % End time of all complete cycles.
        SampleOneCycle % Sample values for one complete cycle.
        SampleExtra % Extra samples beyond complete cycles.
    end
    
    methods
        function obj = PeriodicWaveform()
            %Construct a PeriodicWaveform object.
            %
            % Abstract base class constructor. Subclasses should implement
            % their own constructors with appropriate parameters.
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
            %Get the number of complete periods in the waveform duration.
            %
            % :return: Number of periods
            % :rtype: double
            nP = obj.Duration / obj.Period;
        end

        function nR = get.NRepeat(obj)
            %Get the number of times the cycle segment repeats.
            %
            % Calculates optimal repeat count based on cycle duration and
            % minimum sample size requirements for hardware compatibility.
            %
            % :return: Number of repeats
            % :rtype: double
            if obj.NPeriod <= obj.NCycle
                nR = 1;
            else
                nR = floor(obj.NPeriod / obj.NCycle);
                teC = obj.DurationOneCycle * nR + obj.StartTime - obj.TimeStep;
                tFunc = obj.TimeFunc;
                if isa(obj,"ConstantTop")
                    s = [];
                elseif abs(obj.EndTime - teC) <= obj.TimeStep
                    s = [];
                else
                    t = (teC + obj.TimeStep) : obj.TimeStep : obj.EndTime;
                    s = tFunc(t);
                end

                if ~isempty(s)
                    if numel(s) < obj.MinimumSampleSize
                        NPatchCycle = ceil((obj.MinimumSampleSize - numel(s))...
                            / (obj.DurationOneCycle * obj.SamplingRate));
                        nR = nR - NPatchCycle;
                        if nR < 1
                            nR = 1;
                        end
                    end
                end
            end
        end

        function tC = get.DurationOneCycle(obj)
            %Get the duration of one complete cycle segment.
            %
            % :return: Duration in seconds
            % :rtype: double
            tC = obj.Period * obj.NCycle;
        end

        function s = get.SampleOneCycle(obj)
            %Get sample values for one complete cycle.
            %
            % :return: Vector of sample values for one cycle
            % :rtype: double
            % if obj.NRepeat == 1
                % s = obj.Sample;
            % else
                tFunc = obj.TimeFunc;
                t = obj.StartTime : obj.TimeStep : (obj.StartTime + obj.DurationOneCycle - obj.TimeStep);
                s = tFunc(t);
            % end
        end

        function teC = get.EndTimeAllCycle(obj)
            %Get the end time of all complete cycles.
            %
            % :return: End time in seconds
            % :rtype: double
            if obj.NRepeat == 1
                teC = obj.EndTime;
            else
                teC = obj.DurationOneCycle * obj.NRepeat + obj.StartTime - obj.TimeStep;
            end
        end

        function s = get.SampleExtra(obj)
            %Get extra samples beyond complete cycles.
            %
            % Returns samples for the remaining time after all complete
            % cycles, if any. Empty if waveform ends exactly at cycle boundary.
            %
            % :return: Vector of extra sample values (may be empty)
            % :rtype: double
            tFunc = obj.TimeFunc;
            if isa(obj,"ConstantTop")
                s = [];
            elseif abs(obj.EndTime - obj.EndTimeAllCycle) <= obj.TimeStep
                s = [];
            else
                t = (obj.EndTimeAllCycle + obj.TimeStep) : obj.TimeStep : obj.EndTime;
                s = tFunc(t);
            end
        end

        function plotOneCycle(obj)
            %Plot one complete cycle of the periodic waveform.
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     sine = SineWave(frequency = 1000, amplitude = 1.0);
            %     sine.plotOneCycle();
            figure(10843)
            t = obj.StartTime : obj.TimeStep : (obj.StartTime + obj.DurationOneCycle - obj.TimeStep);
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
            %     sine = SineWave(frequency = 1000, amplitude = 1.0, duration = 0.015);
            %     sine.plotExtra();
            s = obj.SampleExtra;
            if isempty(s)
                return
            end
            figure(10844)
            t = (obj.EndTimeAllCycle + obj.TimeStep) : obj.TimeStep : obj.EndTime;            
            plot(t,s)
            xlabel("Time [s]",Interpreter="latex")
            ylabel("Signal",Interpreter="latex")
            render
        end
    end
end

