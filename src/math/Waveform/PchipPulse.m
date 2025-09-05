classdef PchipPulse < PartialPeriodicWaveform & ConstantTop
    %:class:`PchipPulse` generates pulses with PCHIP-shaped rise and fall transitions.
    %
    % Creates pulse signals with smooth rise and fall transitions using
    % Piecewise Cubic Hermite Interpolating Polynomial (PCHIP) interpolation.
    % Provides smoother transitions than linear ramps. Inherits from :class:`PartialPeriodicWaveform`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a PCHIP pulse with rise and fall times
    %     pulse = PchipPulse(amplitude = 2.0, ...
    %                        riseTime = 0.001, fallTime = 0.001);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a pulse with only rise time
    %     pulse = PchipPulse(amplitude = 1.0, riseTime = 0.002);
    %     pulse.plot();
    
    properties

    end
    
    methods
        function obj = PchipPulse(options)
            %Construct a :class:`PchipPulse` object.
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
            %Get the time function for the PCHIP pulse.
            %
            % Creates a function handle that generates pulse values
            % with PCHIP-interpolated rise and fall transitions. Implements the
            % abstract :meth:`TimeFunc` method from :class:`Waveform`.
            %
            % :return: Function that takes time array and returns PCHIP pulse values
            % :rtype: function_handle
            amp = obj.Amplitude;
            % td = obj.Duration;
            t0 = obj.StartTime;
            te = obj.EndTime;
            offset = obj.Offset;
            tr = obj.RiseTime;
            tf = obj.FallTime;

            % for sampling the pchip function
            tsr = linspace(t0,t0+tr,3);
            dt = tsr(2) - tsr(1);
            ssr = ((tsr-t0)./(tr)-1);
            tsr = [tsr(1)-2 * dt tsr(1)-dt tsr tsr(end)+dt tsr(end)+dt * 2];
            ssr = [-1 -1 ssr 0 0];

            tsf = linspace(te-tf,te,3);
            dt = tsf(2) - tsf(1);
            ssf = (tsf-(te-tf))./(tf);
            tsf = [tsf(1)-2 * dt tsf(1)-dt tsf tsf(end)+dt tsf(end)+2*dt];
            ssf = [0 0 ssf 1 1];

            if tf == 0
                func = @trFunc;
            elseif tr == 0
                func = @tfFunc;
            else
                func = @tFunc;
            end

            function waveOut = trFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((pchip(tsr,ssr,t) .* (t<=(t0+tr)) + 1) .*...
                    amp + offset);
            end

            function waveOut = tfFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    (( - pchip(tsf,ssf,t) .* (t>=(te-tf)) + 1) .*...
                    amp + offset);
            end

            function waveOut = tFunc(t)
                waveOut = (t>=t0 & t<=(te)) .* ...
                    ((pchip(tsr,ssr,t) .* (t<=(t0+tr)) - pchip(tsf,ssf,t) .* (t>=(te-tf)) + 1) .*...
                    amp + offset);
            end
        end
    end
end

