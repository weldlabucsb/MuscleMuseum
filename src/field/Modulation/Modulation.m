classdef Modulation < handle
    %:class:`Modulation` defines a scalar modulation envelope in time.
    %
    % Described by :attr:`Depth`, :attr:`Frequency`, :attr:`Duration`, and :attr:`Timing`.
    % Provides :meth:`timeFunc` that returns the modulation value versus time.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    m = Modulation(depth=0.2, frequency=10e3, duration=3e-3, timing=1e-3);
    %    f = m.timeFunc();
    %    y = f(0:1e-6:5e-3);
    %
    properties
        Depth % Modulation depth (unitless or client-defined)
        Frequency % Modulation frequency :math:`f_m` in [Hz]
        Duration % Modulation duration :math:`T_m` in [s]
        Timing % Start time :math:`t_0` in [s]
    end
    
    methods
        function obj = Modulation(options)
            % Construct a :class:`Modulation` object.
            %
            % :param depth: Modulation depth (unitless or physical as used by client)
            % :type depth: double, optional
            % :param frequency: Modulation frequency :math:`f_m` in [Hz]
            % :type frequency: double, optional
            % :param duration: Duration :math:`T_m` in [s]
            % :type duration: double, optional
            % :param timing: Start time :math:`t_0` in [s]
            % :type timing: double, optional
            arguments
                options.depth double
                options.frequency double
                options.duration double
                options.timing double
            end
            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end
        end
        
        function func = timeFunc(obj)
            % Build modulation function :math:`m(t) = \mathbb{1}_{[t_0,t_0+T_m]}(t)\, \alpha\, \sin(2\pi f_m t)`.
            %
            % :return: function handle mapping time :math:`t` to :math:`m(t)`
            % :rtype: function_handle
            alpha = obj.Depth;
            freq = obj.Frequency;
            tMod = obj.Duration;
            t0 = obj.Timing;
            func = @tFunc;
            function modAmp = tFunc(t)
                modAmp = (t>=t0 & t<=(t0+tMod)) .* ...
                    alpha .* sin(2 * pi .* freq .* t);
            end
        end
    end
end

