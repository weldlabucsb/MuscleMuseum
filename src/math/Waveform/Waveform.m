classdef (Abstract) Waveform < handle
    %:class:`Waveform` generates and stores waveforms for experimental control.
    %
    % A waveform can represent either a continuous function of time or a discrete
    % time-sequence of samples. The definition is given by :meth:`TimeFunc`, which
    % returns a function handle mapping time :math:`t` to the waveform value.
    %
    % The waveform samples are calculated lazily when :attr:`Sample` is accessed,
    % based on :meth:`TimeFunc` and timing parameters (:attr:`StartTime`,
    % :attr:`Duration`, :attr:`SamplingRate`).
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
        SamplingRate double {mustBePositive} = 1 % Sampling rate [Hz]
        StartTime double = 0 % Start time :math:`t_0` [s]
        Duration double {mustBeNonnegative} = 0.1 % Duration :math:`T` [s]
        Scan = table(string.empty,string.empty, 'VariableNames',{'ParameterName','VariableName'}) % Parameter scan table for control panels
        % Scan dictionary = dictionary([],[]) % Parameter scan table for control panels
    end

    properties (Dependent)
        EndTime % :math:`t_\mathrm{end} =` :attr:`StartTime` + :attr:`Duration` [s]
        TimeStep % :math:`\Delta t = 1/` :attr:`SamplingRate` [s]
        NSample % Number of samples derived from :attr:`SamplingRate` and :attr:`Duration`
        Sample % Samples constructed by evaluating :meth:`TimeFunc` on [StartTime, EndTime]
    end
    
    methods
        function obj = Waveform()
            % Construct an instance of :class:`Waveform`.
        end

        function te = get.EndTime(obj)
            % Get the end time of the waveform.
            %
            % :return: End time [s]
            % :rtype: double
            te = obj.StartTime + obj.Duration;
        end

        function nS = get.NSample(obj)
            % Get the number of samples in the waveform.
            %
            % :return: Number of samples
            % :rtype: double
            nS = floor(obj.Duration * obj.SamplingRate) + 1;
        end

        function dt = get.TimeStep(obj)
            % Get the time step between samples.
            %
            % :return: :math:`\Delta t` [s]
            % :rtype: double
            dt = 1/obj.SamplingRate;
        end

        function s = get.Sample(obj)
            % Get the waveform samples by evaluating the time function.
            %
            % :return: Vector of waveform samples
            % :rtype: double
            tFunc = obj.TimeFunc;
            t = obj.StartTime : obj.TimeStep : obj.EndTime;
            s = tFunc(t);
        end
        
        function plot(obj)
            % Plot waveform samples versus time with LaTeX-formatted labels.
            %
            % **Example:**
            %
            % .. code-block:: matlab
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

        function t = convert2Table(obj)
            %Get a table representation of waveform parameters for UI/database.
            %
            % Collects configurable properties, applies scan mappings if present,
            % and returns a compact table for storage or display.
            %
            % :return: Table with columns: Type, SamplingRate, Parameter, and optionally modulation IDs
            % :rtype: table

            %% Get properties from the Waveform
            mc = metaclass(obj);
            Type = string(mc.Name);
            Name = mc.PropertyList;
            Name = Name(~([Name.Dependent] | [Name.Constant] | [Name.Hidden]));
            Name = string({Name.Name});
            Name(ismember(Name,["SamplingRate","Scan"])) = [];
            if isa(obj,"ConstantTop")
                Name(ismember(Name,["Frequency","Phase"]))=[];
            end
            if ismember(Type, ["LinearRamp","PchipRamp","TanhRamp"])
                Name(ismember(Name,["Offset","Amplitude","RiseTime","FallTime"]))=[];
            end
            modList = ["AmplitudeModulation","FrequencyModulation","PhaseModulation"];
            Name(ismember(Name,modList)) = [];
            Name = Name(:);
            DefaultValue = zeros(numel(Name),1);
            nProp = numel(Name);

            %% Get values
            for ii = 1:nProp
                DefaultValue(ii) = obj.(Name(ii));
            end
            VariableID = zeros(numel(Name),1);

            %% Get Scan
            if istable(obj.Scan) && ~isempty(obj.Scan)
                p = VariableList;
                for ii = 1:nProp
                    if ismember(Name(ii),obj.Scan.ParameterName)
                        varName = obj.Scan(obj.Scan.ParameterName == Name(ii),:).VariableName;
                        id = p.readValue(varName,"ID","Name");
                        if ~isempty(id)
                            VariableID(ii) = p.readValue(varName,"ID","Name");
                        end
                    end
                end
            elseif class(obj.Scan) == "dictionary"
                key = obj.Scan.keys;
                if ~isempty(key)
                    for ii = 1:nProp
                        if ismember(Name(ii),key)
                            VariableID(ii) = obj.Scan(Name(ii));
                        end
                    end
                end
            end

            %% Construct table
            Parameter = {table(Name,VariableID,DefaultValue)};
            SamplingRate = obj.SamplingRate;
            if isa(obj,"ModulatedWaveform")
                p = WaveformListLibrary;
                if ~isempty(obj.AmplitudeModulation)
                    AmplitudeModulation = obj.AmplitudeModulation.Name;
                    AmplitudeModulation = p.readValue(AmplitudeModulation,"ID","Name");
                else
                    AmplitudeModulation = 0;
                end
                if ~isempty(obj.FrequencyModulation)
                    FrequencyModulation = obj.FrequencyModulation.Name;
                    FrequencyModulation = p.readValue(FrequencyModulation,"ID","Name");
                else
                    FrequencyModulation = 0;
                end
                if ~isempty(obj.PhaseModulation)
                    PhaseModulation = obj.PhaseModulation.Name;
                    PhaseModulation = p.readValue(PhaseModulation,"ID","Name");
                else
                    PhaseModulation = 0;
                end
                t = table(Type,SamplingRate,Parameter,AmplitudeModulation,FrequencyModulation,PhaseModulation);
            else
                t = table(Type,SamplingRate,Parameter);
            end
        end
    end

    methods (Abstract)
        TimeFunc(obj)
        % Abstract method that must be implemented by subclasses.
        %
        % :return: Function :math:`f(t)` mapping time array to waveform values
        % :rtype: function_handle
        %
        % **Example:**
        %
        % .. code-block:: matlab
        %
        %    function func = TimeFunc(obj)
        %        func = @(t) obj.Amplitude * sin(2*pi*obj.Frequency*t + obj.Phase);
        %    end
    end

end

