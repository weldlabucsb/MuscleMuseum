classdef InterpolatedWaveform < Waveform
    
    properties
        TimeData double
        SampleData double
    end
    
    methods
        function obj = InterpolatedWaveform(options)
            % Construct a :class:`SineWave`.
            %
            % :param samplingRate: Sampling rate [Hz] (default: [])
            % :type samplingRate: double, optional
            % :param startTime: Start time :math:`t_0` [s] (default: 0)
            % :type startTime: double, optional
            % :param duration: Duration :math:`T` [s] (default: [])
            % :type duration: double, optional
            % :param amplitude: Waveform amplitude (default: [])
            % :type amplitude: double, optional
            % :param offset: DC offset (default: 0)
            % :type offset: double, optional
            % :param frequency: Frequency :math:`f` [Hz] (default: [])
            % :type frequency: double, optional
            % :param phase: Phase :math:`\phi` [rad] (default: 0)
            % :type phase: double, optional
            %
            arguments
                options.samplingRate double = [];
                options.startTime double = 0;
                options.duration double = [];
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = TimeFunc(obj)
            % Get the time function for the sine wave.
            %
            % Implements the abstract :meth:`TimeFunc` from :class:`Waveform` by
            % returning :math:`f(t) = \mathbb{1}_{[t_0,t_0+T]}(t)\,(A/2\,\sin(2\pi f (t-t_0)+\phi)+\mathrm{offset})`.
            %
            % :return: Function that takes time array and returns sine wave values
            % :rtype: function_handle
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     sine = SineWave(frequency = 1000, amplitude = 1.0);
            %     func = sine.TimeFunc();
            %     t = 0:0.001:0.01;
            %     y = func(t);
            tDat = obj.TimeData;
            sDat = obj.SampleData;
            td = obj.Duration;
            t0 = obj.StartTime;
            func = @(t) (t>=t0 & t<=(t0+td)) .* interp1(tDat,sDat,t,'pchip','extrap');
        end
    end
end

