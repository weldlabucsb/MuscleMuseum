classdef WaveformList < handle
    %:class:`WaveformList` manages a collection of waveforms for complex sequences.
    %
    % Combines multiple :class:`Waveform` objects into a single sequence using either
    % sequential concatenation or simultaneous superposition. Supports periodic
    % waveforms with repeat counts and trigger-advance modes for hardware control.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a sequence of different waveforms
    %     sine = SineWave(frequency = 1000, amplitude = 1.0, duration = 0.01);
    %     const = ConstantWave(amplitude = 2.0, duration = 0.005);
    %     list = WaveformList(name = 'mySequence', waveformOrigin = {sine, const});
    %     list.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Simultaneous waveforms
    %     list = WaveformList(name = 'simultaneous', concatMethod = 'Simultaneous', ...
    %                         waveformOrigin = {sine, const});

    properties
        ConcatMethod string {mustBeMember(ConcatMethod,{'Sequential','Simultaneous'})} = "Sequential" % Method for combining waveforms: 'Sequential' or 'Simultaneous'.
        PatchMethod string {mustBeMember(PatchMethod,{'Continue','Constant'})} = "Continue" % Method for filling gaps between waveforms: 'Continue' or 'Constant'.
        PatchConstant double = 0 % Constant value used when PatchMethod is 'Constant'.
        IsTriggerAdvance logical = false % Whether to use trigger-advance mode for hardware control.
        WaveformOrigin cell % Cell array of waveform objects to be combined.
        SamplingRate double % In Hz - Sampling rate for all waveforms in the list.
        NPeriodPerCycle double = 10 % Number of cycles for periodic waveforms.
        TransformFunction string = "None" % To transform the waveform. Must be a function defined in matlab's search path.
        OverrideFunction string = "None" % To override the waveform output. Can take variable input. Must be a function that outputs a WaveformList.
    end

    properties (Dependent)
        Sample % Combined waveform samples as a vector.
        TimeStep % Time step between samples (1/SamplingRate).
        RepeatMode string % Repeat mode for hardware control ('Repeat' or 'RepeatTilTrigger').
        % WaveformPrepared Table % Table containing prepared waveform segments with play modes and repeat counts.
        IsEmpty logical % If this waveform has no WaveformOrigin or all WaveformOrigin has zero duration
        OverrideWaveformList
    end

    properties (SetAccess = protected)
        Name string % Name of the waveform list.
        NSample double % Total number of samples in the combined waveform.
    end

    properties (Constant)
        PlotNumberLimit = 1e6 % Maximum number of points to plot before downsampling for display.
    end

    methods
        function obj = WaveformList(name,options)
            %Construct a WaveformList object.
            %
            % :param name: Name of the waveform list
            % :type name: string
            % :param samplingRate: Sampling rate in Hz (default: 1000)
            % :type samplingRate: double, optional
            % :param concatMethod: Concatenation method (default: 'Sequential')
            % :type concatMethod: string, optional
            % :param patchMethod: Gap filling method (default: 'Continue')
            % :type patchMethod: string, optional
            % :param patchConstant: Constant for gap filling (default: 0)
            % :type patchConstant: double, optional
            % :param isTriggerAdvance: Use trigger advance mode (default: false)
            % :type isTriggerAdvance: logical, optional
            % :param waveformOrigin: Cell array of waveform objects (default: {})
            % :type waveformOrigin: cell, optional
            % :param nCycle: Number of cycles for periodic waveforms (default: 10)
            % :type nCycle: double, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     sine = SineWave(frequency = 1000, amplitude = 1.0);
            %     list = WaveformList(name = 'myList', waveformOrigin = {sine}, samplingRate = 10000);
            arguments
                name string = "Test"
                options.samplingRate double = 1e3
                options.concatMethod string = "Sequential"
                options.patchMethod string = "Continue"
                options.patchConstant double = 0
                options.isTriggerAdvance logical = false
                options.waveformOrigin cell = {}
                options.nPeriodPerCycle double = 10
            end
            obj.Name = name;
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end

        function dt = get.TimeStep(obj)
            %Get the time step between samples.
            %
            % :return: Time step in seconds
            % :rtype: double
            dt = 1/obj.SamplingRate;
        end

        function rM = get.RepeatMode(obj)
            %Get the repeat mode for hardware control.
            %
            % :return: 'Repeat' or 'RepeatTilTrigger'
            % :rtype: string
            if obj.IsTriggerAdvance
                rM = "RepeatTilTrigger";
            else
                rM = "Repeat";
            end
        end

        function ie = get.IsEmpty(obj)
            ie = true;
            if ~isempty(obj.WaveformOrigin)
                if ~isempty(obj.WaveformOrigin{1})
                    dura = 0;
                    for ii = 1:numel(obj.WaveformOrigin)
                        dura = dura + obj.WaveformOrigin{ii}.Duration;
                    end
                    if dura > 0
                        ie = false;
                    end
                end
            end
        end

        function wfl = get.OverrideWaveformList(obj)
            if obj.OverrideFunction ~= "None"
                funcName = regexp(obj.OverrideFunction, '^\w+', 'match', 'once');
                vars = regexp(obj.OverrideFunction, '(?<=\(|\,)\s*(\w+)\s*(?=\,|\))', 'match');
                if ~isempty(vars)
                    p = VariableList;
                    t = p.readColumn(["Name","CurrentValue"]);
                    dict = dictionary(t.Name,t.CurrentValue);
                    freeVarIdx = ~ismember(vars,dict.keys);
                    varEval = zeros(1,numel(vars));
                    varEval(~freeVarIdx) = dict(vars(~freeVarIdx));
                    varEval(freeVarIdx) = double(vars(freeVarIdx));
                    varEval = num2cell(varEval);
                    wfl = feval(funcName,varEval{:});
                else
                    wfl = feval(funcName);
                end
                wfl.SamplingRate = obj.SamplingRate;
            else
                wfl = {};
            end
        end

        function t = WaveformPrepared(obj)
            %Prepare waveform segments for hardware output.
            %
            % Combines individual waveforms according to the concatenation method
            % and returns a table with segments, play modes, and repeat counts.
            %
            % :return: Table with columns: Sample, PlayMode, NRepeat
            % :rtype: table
            %% Check waveform origin
            if isempty(obj.WaveformOrigin)
                return
            else
                nWave = numel(obj.WaveformOrigin);
                if nWave == 0
                    return
                end
            end

            %% Set override function
            if obj.OverrideFunction ~= "None"
                wfl = obj.OverrideWaveformList;
                t = wfl.WaveformPrepared;
                return
            end

            %% Set sampling rate
            for ii = 1:nWave
                obj.WaveformOrigin{ii}.SamplingRate = obj.SamplingRate;
            end

            %% Set NCycle
            for ii = 1:nWave
                if isa(obj.WaveformOrigin{ii},"PeriodicWaveform")
                    obj.WaveformOrigin{ii}.NPeriodPerCycle = obj.NPeriodPerCycle;
                end
            end

            %% Initialization
            sampleIdx = 1;
            NRepeat = double.empty;
            Sample = cell(1,1);
            PlayMode = string.empty;

            %% Construct waveform sequence from segments
            switch obj.ConcatMethod
                case "Sequential"
                    for ii = 1:nWave
                        if obj.WaveformOrigin{ii}.Duration == 0
                            continue
                        end
                        if isa(obj.WaveformOrigin{ii},"PeriodicWaveform") && (obj.WaveformOrigin{ii}.NPeriodPerCycle ~= 0)
                            if isa(obj.WaveformOrigin{ii},"ConstantWave")
                                obj.WaveformOrigin{ii}.Frequency = obj.SamplingRate;
                            end

                            s = obj.WaveformOrigin{ii}.SampleOneCycle;
                            if ~isempty(s)
                                Sample{sampleIdx} = obj.WaveformOrigin{ii}.SampleOneCycle;
                                NRepeat(sampleIdx) = obj.WaveformOrigin{ii}.NRepeat;
                                PlayMode(sampleIdx) = obj.RepeatMode;
                                sampleIdx = sampleIdx + 1;
                            end

                            sExtra = obj.WaveformOrigin{ii}.SampleExtra;
                            if (~isempty(sExtra)) && (~obj.IsTriggerAdvance)
                                Sample{sampleIdx} = sExtra;
                                NRepeat(sampleIdx) = 1;
                                PlayMode(sampleIdx) = "Repeat";
                                sampleIdx = sampleIdx + 1;
                            end
                        elseif isa(obj.WaveformOrigin{ii},"PartialPeriodicWaveform") && (obj.WaveformOrigin{ii}.NPeriodPerCycle~=0)
                            sBefore = obj.WaveformOrigin{ii}.SampleBefore;
                            if ~isempty(sBefore)
                                Sample{sampleIdx} = sBefore;
                                NRepeat(sampleIdx) = 1;
                                PlayMode(sampleIdx) = "Repeat";
                                sampleIdx = sampleIdx + 1;
                            end

                            s = obj.WaveformOrigin{ii}.SampleOneCycle;
                            if ~isempty(s)
                                Sample{sampleIdx} = obj.WaveformOrigin{ii}.SampleOneCycle;
                                NRepeat(sampleIdx) = obj.WaveformOrigin{ii}.NRepeat;
                                PlayMode(sampleIdx) = obj.RepeatMode;
                                sampleIdx = sampleIdx + 1;
                            end

                            sAfter = obj.WaveformOrigin{ii}.SampleAfter;
                            if ~isempty(sAfter)
                                Sample{sampleIdx} = sAfter;
                                NRepeat(sampleIdx) = 1;
                                PlayMode(sampleIdx) = "Repeat";
                                sampleIdx = sampleIdx + 1;
                            end
                        else
                            Sample{sampleIdx} = obj.WaveformOrigin{ii}.Sample;
                            NRepeat(sampleIdx) = 1;
                            PlayMode(sampleIdx) = obj.RepeatMode;
                            sampleIdx = sampleIdx + 1;
                        end
                    end
                case "Simultaneous"
                    intervalList = zeros(nWave,2);
                    for ii = 1:nWave
                        intervalList(ii,1) = obj.WaveformOrigin{ii}.StartTime;
                        intervalList(ii,2) = obj.WaveformOrigin{ii}.EndTime;
                    end
                    [unionList,unionLimit,patchLimit] = findIntervalUnion(intervalList);
                    dt = obj.TimeStep;
                    nUnion = numel(unionList);
                    for jj = 1:nUnion 
                        t = unionLimit(jj,1) : dt : unionLimit(jj,2);
                        sample = zeros(1,numel(t));
                        for kk = 1:numel(unionList{jj})
                            tFunc = obj.WaveformOrigin{unionList{jj}(kk)}.TimeFunc;
                            sample = sample + tFunc(t);
                        end
                        Sample{sampleIdx} = sample;
                        NRepeat(sampleIdx) = 1;
                        PlayMode(sampleIdx) = obj.RepeatMode;
                        sampleIdx = sampleIdx + 1;
                        if jj ~= nUnion
                            if unionLimit(jj,2) ~= unionLimit(jj+1,1)
                                switch obj.PatchMethod
                                    case "Constant"
                                        patchConstant = obj.PatchConstant;
                                    case "Continue"
                                        patchConstant = sample(end);
                                end
                                tPatch = patchLimit(jj,2) - patchLimit(jj,1);
                                Sample{sampleIdx} = repmat(patchConstant,1,32);
                                NRepeat(sampleIdx) = floor(tPatch / dt / 32);
                                PlayMode(sampleIdx) = obj.RepeatMode;
                                sampleIdx = sampleIdx + 1;
                            end
                        end
                    end
            end
            if ~isempty(Sample{1})
                Sample = Sample.';
                if ~isempty(obj.TransformFunction) && obj.TransformFunction ~= "None"
                    Sample = cellfun(@(x) feval(obj.TransformFunction,x),Sample,'UniformOutput',false);
                end
                PlayMode = PlayMode.';
                NRepeat = NRepeat.';
                t = table(Sample,PlayMode,NRepeat);
                obj.NSample = sum(cellfun(@numel,Sample));
            else
                t = table.empty;
            end
        end

        function sample = get.Sample(obj)
            %Get the combined waveform samples.
            %
            % Concatenates all waveform segments according to their repeat counts.
            %
            % :return: Vector of combined waveform samples
            % :rtype: double
            t = obj.WaveformPrepared;
            sample = [];
            for ii = 1:size(t,1)
                sample = [sample,repmat(t.Sample{ii},1,t.NRepeat(ii))];
            end
        end

        function func = TimeFunc(obj)
            %Get the time function for the combined waveform.
            %
            % Creates a function handle that evaluates the combined waveform
            % at any time point, handling the concatenation method and timing.
            %
            % :return: Function that takes time array and returns combined waveform values
            % :rtype: function_handle
            %% Check waveform origin
            if isempty(obj.WaveformOrigin)
                return
            else
                nWave = numel(obj.WaveformOrigin);
                if nWave == 0
                    return
                end
            end

            if obj.OverrideFunction ~= "None"
                func = obj.OverrideWaveformList.TimeFunc;
                return
            end

            %% Construct waveform time function handle
            tShift = zeros(1,nWave);
            if obj.ConcatMethod == "Sequential"
                ti = 0;
                dt = obj.TimeStep;
                tShift(1) = - obj.WaveformOrigin{1}.StartTime;
                for ii = 2:nWave
                    ti = ti + obj.WaveformOrigin{ii-1}.Duration + dt;
                    tShift(ii) = ti - obj.WaveformOrigin{ii}.StartTime;
                end
            end
            funcList = cell(1,nWave);
            for ii = 1:nWave
                funcList{ii} = obj.WaveformOrigin{ii}.TimeFunc;
            end
            function out = timeFunc(t)
                out = 0;
                for jj = 1:nWave
                    out = out + funcList{jj}(t - tShift(jj));
                end
            end
            if ~isempty(obj.TransformFunction) && obj.TransformFunction ~= "None"
                func = @(t) feval(obj.TransformFunction,timeFunc(t));
            else
                func = @(t) timeFunc(t);
            end
        end

        function plot(obj,ax)
            %Plot the combined waveform.
            %
            % :param ax: Target axes for plotting (default: new figure)
            % :type ax: axes, optional
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     list = WaveformList(name = 'myList', waveformOrigin = {sine, const});
            %     list.plot();
            arguments
                obj WaveformList
                ax = []
            end

            if obj.OverrideFunction ~= "None"
                obj.OverrideWaveformList.plot(ax)
                return
            end
            
            sr = obj.SamplingRate;
            if ~isempty(obj.WaveformOrigin)
                tTotal = sum(cellfun(@(x) x.Duration,obj.WaveformOrigin));
                nSample = tTotal * sr; % Estimate the number of samples
                if nSample > obj.PlotNumberLimit
                    % If we have too many samples for plotting, reduce the
                    % sampling rate
                    warning("Too many samples. Will reduce the sampling rate for plotting.")
                    obj.SamplingRate = round(obj.SamplingRate * obj.PlotNumberLimit / nSample);
                end
                dt = obj.TimeStep;
                sample = obj.Sample;
                time = 0:(numel(sample)-1);
                time = time * dt;
            else
                time = 0;
                sample = 0;
            end

            % Plot
            if isempty(ax)
                figure(14739)
                plot(time,sample)
                xlabel("Time [s]",'Interpreter','latex')
                ylabel("Waveform Sample",'Interpreter','latex')
                render
            else
                plot(ax,time,sample,'LineWidth',1.5);
                xlabel(ax,"Time [s]",'Interpreter','latex')
                ylabel(ax,"Waveform Sample",'Interpreter','latex')
            end

            % Set sampling rate back
            if ~isempty(obj.WaveformOrigin) && nSample > obj.PlotNumberLimit
                obj.SamplingRate = sr;
            end
        end

        function set.SamplingRate(obj,val)
            %Set the sampling rate for all waveforms in the list.
            %
            % :param val: New sampling rate in Hz
            % :type val: double
            obj.SamplingRate = round(val);
            nWave = numel(obj.WaveformOrigin);
            for ii = 1:nWave
                obj.WaveformOrigin{ii}.SamplingRate = obj.SamplingRate;
            end
        end

        function set.NPeriodPerCycle(obj,val)
            %Set the number of cycles for periodic waveforms.
            %
            % :param val: New number of cycles
            % :type val: double
            obj.NPeriodPerCycle = round(val);
            nWave = numel(obj.WaveformOrigin);
            for ii = 1:nWave
                if isa(obj.WaveformOrigin{ii},"PeriodicWaveform")
                    obj.WaveformOrigin{ii}.NPeriodPerCycle = obj.NPeriodPerCycle;
                end
            end
        end

        function t = convert2Table(obj)
            %Convert list configuration to a table for serialization.
            %
            % :return: Table with list configuration fields suitable for saving
            % :rtype: table
            Name = obj.Name;
            SamplingRate = obj.SamplingRate;
            ConcatMethod = obj.ConcatMethod;
            PatchMethod = obj.PatchMethod;
            PatchConstant = obj.PatchConstant;
            IsTriggerAdvance = obj.IsTriggerAdvance;
            NPeriodPerCycle = obj.NPeriodPerCycle;
            TransformFunction = obj.TransformFunction;
            OverrideFunction = obj.OverrideFunction;
            if isnan(NPeriodPerCycle)
                NPeriodPerCycle = 0;
            end
            t = table(Name,SamplingRate,ConcatMethod,PatchMethod,PatchConstant,IsTriggerAdvance,NPeriodPerCycle,TransformFunction,OverrideFunction);
        end
    end
end

