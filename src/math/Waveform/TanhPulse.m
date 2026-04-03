classdef TanhPulse < PartialPeriodicWaveform & ConstantTop
    %:class:`TanhPulse` generates pulses with hyperbolic tangent rise and fall transitions.
    %
    % Creates sine wave pulses with smooth rise and fall transitions using
    % hyperbolic tangent (tanh) functions. Provides smooth, sigmoid-like
    % transitions for pulse shaping. Inherits from :class:`PartialPeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a tanh-shaped pulse with rise and fall times
    %     pulse = TanhPulse(amplitude = 2.0, ...
    %                      riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with only rise time
    %     pulse = TanhPulse(amplitude = 1.0, riseTime = 0.002);
    %     pulse.plot();
    
    properties

    end
    
    methods
        function obj = TanhPulse(options)
            %Construct a :class:`TanhPulse` object.
            %
            % :param samplingRate: Sampling rate in Hz (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time in seconds (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration in seconds (default: [])
            % :type duration: double, optional
            % :param amplitude: Peak-to-peak amplitude (default: [])
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param frequency: Frequency in Hz (default: [])
            % :type frequency: double, optional
            % :param phase: Initial phase in radians (default: 0)
            % :type phase: double, optional
            % :param riseTime: Rise transition time in seconds (default: 0)
            % :type riseTime: double, optional
            % :param fallTime: Fall transition time in seconds (default: 0)
            % :type fallTime: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
                options.amplitude double = [];
                options.offset double = 0;

                options.riseTime double = 0;
                options.fallTime double = 0;
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            %Get the time function for the tanh-shaped pulse.
            %
            % Creates a function handle that generates sine wave pulse values
            % with hyperbolic tangent rise and fall transitions. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns tanh-shaped pulse values
            % :rtype: function_handle
            amp = obj.Amplitude;
            t0 = obj.StartTime;
            te = obj.EndTime;
            offset = obj.Offset;
            tr = obj.RiseTime;
            tf = obj.FallTime;
            trCenter = t0 + tr / 2;
            tfCenter = te - tf / 2;
            if tf == 0
                func = @trFunc;
            elseif tr == 0
                func = @tfFunc;
            else
                func = @tFunc;
            end
            function waveOut = trFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    (((tanh((t-trCenter)./(tr).* 2 * pi) - 1)./2 .* (t<=(t0+tr))...
                     + 1) .*...
                    amp + offset);
            end
            function waveOut = tfFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((...
                    - (tanh((t-tfCenter)./(tf).* 2 * pi) + 1)./2 .* (t>=(te-tf)) + 1) .*...
                    amp + offset);
            end
            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    (((tanh((t-trCenter)./(tr).* 2 * pi) - 1)./2 .* (t<=(t0+tr))...
                    - (tanh((t-tfCenter)./(tf).* 2 * pi) + 1)./2 .* (t>=(te-tf)) + 1) .*...
                    amp + offset);
            end
        end
    end
end

