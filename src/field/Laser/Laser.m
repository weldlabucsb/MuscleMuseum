classdef Laser < matlab.mixin.Heterogeneous & handle
    %:class:`Laser` specifies monochromatic laser parameters and derived quantities.
    %
    % Stores wavelength/frequency, polarization, direction/angles, phase, intensity
    % and power. Provides dependent properties (e.g., :attr:`Wavevector`, :attr:`AngularFrequency`)
    % and helpers (:meth:`spacePhaseFunc`, :meth:`timePhaseFunc`, :meth:`spaceTimePhaseFunc`,
    % :meth:`rotate`, :meth:`rotateToAngle`).
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    l = Laser(frequency=3.84e14, polarization=[1;0;0], direction=[0;0;1]);
    %    k = l.AngularWavevector;  % [rad/m]
    %    f = l.timePhaseFunc();    % function_handle for :math:`e^{i \omega t}`
    %
    properties
        Wavelength (1,1) double = NaN % Wavelength :math:`\lambda` in [m]
        Frequency (1,1) double = NaN % Linear frequency :math:`f` in [Hz]
        Polarization (3,1) double = [NaN;NaN;NaN] % Jones polarization vector :math:`(E_x,E_y,E_z)`
        Phase (1,1) double = 0 % Optical phase :math:`\phi` in [rad]
        Direction (3,1) double = [NaN;NaN;NaN] % Propagation unit vector :math:`\hat{\mathbf{k}} = (x,y,z)`
        Angle (1,2) double = [NaN,NaN] % Spherical angles :math:`(\theta,\phi)` in [rad]
        Intensity double = NaN % Intensity :math:`I` in [W/m^2]
        Power double = NaN % Optical power :math:`P` in [W]
    end

    properties (Dependent)
        Wavenumber % :math:`k_0 = 1/\lambda` [1/m]
        Wavevector % :math:`\mathbf{k}_0 = k_0\, \hat{\mathbf{k}}` [1/m]
        AngularFrequency % :math:`\omega = 2\pi f` [rad/s]
        AngularWavenumber % :math:`k = 2\pi/\lambda` [rad/m]
        AngularWavevector % :math:`\mathbf{k} = k\, \hat{\mathbf{k}}` [rad/m]
        WavelengthInAir % :math:`\lambda_{\mathrm{air}}` in [m]
        IntensityLu % Intensity in [mW/cm^2]
        ElectricFieldAmplitude % Field amplitude :math:`|E| = \sqrt{2 Z_0 I}` in [V/m]
    end
    
    methods
        
        function obj = Laser(options)
            % Construct a :class:`Laser`.
            %
            % :param frequency: Linear frequency :math:`f` in [Hz] (sets :math:`\lambda`)
            % :type frequency: double, optional
            % :param wavelength: Wavelength :math:`\lambda` in [m] (sets :math:`f`)
            % :type wavelength: double, optional
            % :param polarization: Jones vector :math:`(E_x,E_y,E_z)`
            % :type polarization: double(3,1), optional
            % :param phase: Optical phase :math:`\phi` in [rad]
            % :type phase: double, optional
            % :param direction: Propagation direction unit vector :math:`(x,y,z)`
            % :type direction: double(3,1), optional
            % :param angle: Spherical angles :math:`(\theta,\phi)` in [rad]
            % :type angle: double(1,2), optional
            % :param intensity: Intensity :math:`I` in [W/m^2]
            % :type intensity: double, optional
            % :param power: Power :math:`P` in [W]
            % :type power: double, optional
            arguments
                options.frequency = NaN
                options.wavelength = NaN
                options.polarization = [NaN;NaN;NaN]
                options.phase = 0
                options.direction = [NaN;NaN;NaN]
                options.angle = [NaN,NaN]
                options.intensity = NaN
                options.power = NaN
            end
            if ~isnan(options.frequency)
                obj.Frequency = options.frequency;
            elseif ~isnan(options.wavelength)
                obj.Wavelength = options.wavelength;
            end
            obj.Polarization = options.polarization;
            obj.Phase = options.phase;
            if ~isnan(options.direction)
                obj.Direction = options.direction;
            elseif ~isnan(options.angle)
                obj.Angle = options.angle;
            end
            obj.Intensity = options.intensity;
            obj.Power = options.power;
        end
        function obj = set.Frequency(obj,val)
            if (abs(val - obj.Frequency)>eps || any(isnan(obj.Frequency)) )&& ~isnan(val)
                 obj.Frequency = val;
                 obj.Wavelength = Constants.SI("c")/val;
            end
        end
        function obj = set.Wavelength(obj,val)
            if (abs(val - obj.Wavelength)>eps || any(isnan(obj.Wavelength)) ) && ~isnan(val)
                 obj.Wavelength = val;
                 obj.Frequency = Constants.SI("c")/val;
            end
        end
        function obj = set.Polarization(obj,val)
            obj.Polarization = val / vecnorm(val);
        end
        function obj = set.Direction(obj,val)
            val = val / vecnorm(val);
            if (~all(abs(obj.Direction - val)<eps) || any(isnan(obj.Direction)) ) && all(~isnan(val))
                obj.Direction = val;
                [azimuth,elevation,~] = cart2sph(val(1),val(2),val(3));
                obj.Angle = [pi/2-elevation,azimuth];
            end
        end
        function obj = set.Angle(obj,val)
            if (~all(abs(obj.Angle - val)<eps) || any(isnan(obj.Angle)) ) && all(~isnan(val))
                obj.Angle = val;
                [x,y,z] = sph2cart(val(2),pi/2-val(1),1);
                obj.Direction = [x,y,z];
            end
        end
        function obj = set.Power(obj,val)
            if (abs(val - obj.Power)>eps || isnan(obj.Power) ) && ~isnan(val)
                obj.Power = val;
                if class(obj) == "GaussianBeam"
                    obj.Intensity = 2 * obj.Power / obj.Waist(1) / obj.Waist(2) / pi;
                end
            end
        end
        function obj = set.Intensity(obj,val)
            if (abs(val - obj.Intensity)>eps || isnan(obj.Intensity) ) && ~isnan(val)
                obj.Intensity = val;
                if class(obj) == "GaussianBeam"
                    obj.Power = pi * obj.Intensity * obj.Waist(1) * obj.Waist(2) / 2;
                end
            end
        end
        function lambdaAir = get.WavelengthInAir(obj)
            % Get wavelength in air :math:`\lambda_{\mathrm{air}}`.
            %
            % :return: Wavelength in air [m]
            % :rtype: double
            lambdaAir = obj.Wavelength/1.000293;
        end
        function nu = get.Wavenumber(obj)
            % Get wavenumber :math:`k_0 = 1/\lambda`.
            %
            % :return: Wavenumber [1/m]
            % :rtype: double
            nu = 1/obj.Wavelength;
        end
        function k = get.AngularWavenumber(obj)
            % Get angular wavenumber :math:`k = 2\pi/\lambda`.
            %
            % :return: Angular wavenumber [rad/m]
            % :rtype: double
            k = obj.Wavenumber * 2 * pi;
        end
        function omega = get.AngularFrequency(obj)
            % Get angular frequency :math:`\omega = 2\pi f`.
            %
            % :return: Angular frequency [rad/s]
            % :rtype: double
            omega = obj.Frequency * 2 * pi;
        end
        function nuVec = get.Wavevector(obj)
            % Get wavevector :math:`\mathbf{k}_0 = k_0\, \hat{\mathbf{k}}`.
            %
            % :return: Wavevector [1/m]
            % :rtype: double(3,1)
            nuVec = obj.Wavenumber * obj.Direction;
        end
        function kVec = get.AngularWavevector(obj)
            % Get angular wavevector :math:`\mathbf{k} = k\, \hat{\mathbf{k}}`.
            %
            % :return: Angular wavevector [rad/m]
            % :rtype: double(3,1)
            kVec = obj.Wavevector * 2 * pi;
        end
        function I = get.IntensityLu(obj)
            % Get intensity in mW/cm^2.
            %
            % :return: Intensity in mW/cm^2
            % :rtype: double
            I = obj.Intensity / 10;
        end
        function E = get.ElectricFieldAmplitude(obj)
            % Get electric field amplitude :math:`|E| = \sqrt{2 Z_0 I}`.
            %
            % :return: Electric field amplitude [V/m]
            % :rtype: double
            E = sqrt(obj.Intensity * 2 * Constants.SI("Z0"));
        end
        function obj = rotate(obj,eul)
            % Rotate direction and polarization by ZYZ Euler angles.
            %
            % :param eul: Euler angles :math:`[\alpha,\beta,\gamma]` (ZYZ) in radians
            % :type eul: double(1,3)
            % :return: Self-reference
            % :rtype: :class:`Laser`
            rotm = eul2rotm(eul,"ZYZ");
            dir = obj.Direction;
            dir = dir(:);
            dir = rotm * dir;
            obj.Direction = reshape(dir,size(obj.Direction));
            pol = obj.Polarization;
            pol = pol(:);
            pol = rotm * pol;
            obj.Polarization = reshape(pol,size(obj.Polarization));
        end
        function obj = rotateToAngle(obj,angle)
            % Rotate to target spherical angles :math:`[\theta,\phi]`.
            %
            % :param angle: :math:`[\theta,\phi]` in radians
            % :type angle: double(1,2)
            % :return: Self-reference
            % :rtype: :class:`Laser`
            oldAngle = obj.Angle;
            rotm = eul2rotm([angle(2),angle(1),0],"ZYZ") * ...
                (eul2rotm([oldAngle(2),oldAngle(1),0],"ZYZ"))^(-1);
            dir = obj.Direction;
            dir = dir(:);
            dir = rotm * dir;
            obj.Direction = reshape(dir,size(obj.Direction));
            pol = obj.Polarization;
            pol = pol(:);
            pol = rotm * pol;
            obj.Polarization = reshape(pol,size(obj.Polarization));
        end
        function func = spacePhaseFunc(obj)
            % Build :math:`e^{i(\phi - \mathbf{k}\cdot \mathbf{r})}` phase function of space.
            %
            % :return: function handle mapping position :math:`\mathbf{r}` to phase factor
            % :rtype: function_handle
            kvec = obj.AngularWavevector;
            phase = obj.Phase;
            func = @(r) spacePhase(r);
            function out = spacePhase(r)
                out = exp(1i*(phase - kvec.'*r(:)));
            end
        end
        function func = timePhaseFunc(obj)
            % Build :math:`e^{i \omega t}` phase function of time.
            %
            % :return: function handle mapping :math:`t` to phase factor
            % :rtype: function_handle
            omega = obj.AngularFrequency;
            func = @(t) timePhase(t);
            function out = timePhase(t)
                out = exp(1i*(omega*t));
            end
        end
        function func = spaceTimePhaseFunc(obj)
            % Build :math:`e^{i(\omega t + \phi - \mathbf{k}\cdot \mathbf{r})}` phase function.
            %
            % :return: function handle mapping (:math:`\mathbf{r},t`) to phase factor
            % :rtype: function_handle
            omega = obj.AngularFrequency;
            kvec = obj.AngularWavevector;
            phase = obj.Phase;
            func = @(r,t) spacePhase(r,t);
            function out = spacePhase(r,t)
                out = exp(1i*(omega*t + phase - kvec.'*r(:)));
            end
        end
    end
end

