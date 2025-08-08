classdef (Abstract) Waveform < handle
    %:class:`Waveform` generates and stores waveforms for experimental control.
    %
    % A waveform can represent either a continuous function of time or a discrete
    % time-sequence of samples. The waveform definition is given by the output
    % of the :meth:`TimeFunc` method, which returns a function handle that takes
    % a time array as input. Every concrete subclass must implement the
    % :meth:`TimeFunc` method.
    %
    % The waveform samples are calculated automatically when the :attr:`Sample`
    % property is accessed, based on the :meth:`TimeFunc` and timing parameters.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a sine wave
    %     sine = SineWave(frequency = 1000, amplitude = 1.0, duration = 0.01);
    %     samples = sine.Sample;  % Get waveform samples
    %     sine.plot();            % Plot the waveform
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a constant waveform
    %     const = ConstantWave(amplitude = 5.0, duration = 0.005);
    %     const.plot();
    
    properties
        SamplingRate double {mustBePositive} = 1 % Sampling rate in Hz. Must be positive.
        StartTime double = 0 % Start time of the waveform in seconds.
        Duration double {mustBeNonnegative} = 0.1 % Duration of the waveform in seconds. Must be non-negative.
        Scan table = table(string.empty,string.empty, 'VariableNames',{'ParameterName','VariableName'}) % Table for scanning parameters in hardware control panel. Contains parameter names and their corresponding variable names.
    end

    properties (Dependent)
        EndTime % End time of the waveform in seconds. Calculated as :attr:`StartTime` + :attr:`Duration`.
        TimeStep % Time step between samples in seconds. Calculated as 1/:attr:`SamplingRate`.
        NSample % Number of samples in the waveform. Calculated based on :attr:`SamplingRate` and :attr:`Duration`.
        Sample % Waveform samples as a vector. Calculated by evaluating :meth:`TimeFunc` at time points from :attr:`StartTime` to :attr:`EndTime` with :attr:`TimeStep` spacing.
    end
    
    methods
        function obj = Waveform()
            %Construct an instance of the Waveform class.
        end

        function te = get.EndTime(obj)
            %Get the end time of the waveform.
            %
            % :return: End time in seconds
            % :rtype: double
            te = obj.StartTime + obj.Duration;
        end

        function nS = get.NSample(obj)
            %Get the number of samples in the waveform.
            %
            % :return: Number of samples
            % :rtype: double
            nS = floor(obj.Duration * obj.SamplingRate) + 1;
        end

        function dt = get.TimeStep(obj)
            %Get the time step between samples.
            %
            % :return: Time step in seconds
            % :rtype: double
            dt = 1/obj.SamplingRate;
        end

        function s = get.Sample(obj)
            %Get the waveform samples by evaluating the time function.
            %
            % :return: Vector of waveform samples
            % :rtype: double
            tFunc = obj.TimeFunc;
            t = obj.StartTime : obj.TimeStep : obj.EndTime;
            s = tFunc(t);
        end
        
        function plot(obj)
            %Creates a plot of the waveform samples versus time with
            %LaTeX-formatted axis labels.
            %
            %**Example:**
            %
            %.. code-block:: matlab
            %
            %    sine = SineWave(frequency = 1000, amplitude = 1.0);
            %    sine.plot();
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
        %Abstract method that must be implemented by subclasses.
        %
        %:return: Function that takes time array and returns waveform values
        %:rtype: function_handle
        %
        %**Example:**
        %
        %.. code-block:: matlab
        %
        %    function func = TimeFunc(obj)
        %        func = @(t) obj.Amplitude * sin(2*pi*obj.Frequency*t + obj.Phase);
        %    end
    end

end

