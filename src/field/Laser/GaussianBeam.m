classdef GaussianBeam < Laser
    %:class:`GaussianBeam` represents a TEM00 Gaussian laser beam.
    %
    % Adds beam waist and center position to :class:`Laser` and provides
    % Rayleigh range and average intensity for convenience.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    g = GaussianBeam(waist=[50e-6; 60e-6], center=[0;0;0], wavelength=1064e-9, power=3);
    %    zR = g.RayleighRange;
    %
    properties
        Waist (2,1) double = [NaN;NaN] % 1/e^2 radii :math:`(w_x, w_y)` in [m]
        Center (3,1) double = [0;0;0] % Beam center :math:`(x,y,z)` in [m]
    end
    
    properties(Dependent)
       RayleighRange % Rayleigh range :math:`z_R = \pi w_x w_y / \lambda` in [m]
       IntensityAveraged % Average intensity :math:`I = P/(\pi w_x w_y)` in [W/m^2]
    end
    
    methods
        function obj = GaussianBeam(options1,options2)
            % Construct a :class:`GaussianBeam`.
            %
            % :param waist: Beam waist :math:`(w_x, w_y)` in [m] (default: [NaN;NaN])
            % :type waist: double(2,1), optional
            % :param center: Beam center :math:`(x,y,z)` in [m] (default: (0,0,0))
            % :type center: double(3,1), optional
            % :param frequency: Laser frequency :math:`f` in [Hz]
            % :type frequency: double, optional
            % :param wavelength: Laser wavelength :math:`\lambda` in [m]
            % :type wavelength: double, optional
            % :param polarization: Jones vector :math:`(E_x,E_y,E_z)`
            % :type polarization: double(3,1), optional
            % :param phase: Phase :math:`\phi` in [rad]
            % :type phase: double, optional
            % :param direction: Direction unit vector :math:`(x,y,z)`
            % :type direction: double(3,1), optional
            % :param intensity: Intensity :math:`I` in [W/m^2]
            % :type intensity: double, optional
            % :param power: Power :math:`P` in [W]
            % :type power: double, optional
            arguments
                options1.waist = [NaN;NaN]
                options1.center = [0;0;0]
                options2.frequency = NaN
                options2.wavelength = NaN
                options2.polarization = [1;0;0]
                options2.phase = 0
                options2.direction = [0;0;1]
                options2.intensity = NaN
                options2.power = NaN
            end
            varargin = struct2pairs(options2);
            obj@Laser(varargin{:})
            obj.Waist = options1.waist;
            obj.Center = options1.center;
            if ~isnan(obj.Intensity)
                obj.Power = pi * obj.Intensity * obj.Waist(1) * obj.Waist(2) / 2;
            elseif ~isnan(obj.Power)
                obj.Intensity = 2 * obj.Power / obj.Waist(1) / obj.Waist(2) / pi;
            end
        end
        function zR = get.RayleighRange(obj)
            % Get Rayleigh range :math:`z_R = \pi w_x w_y / \lambda`.
            %
            % :return: Rayleigh range :math:`z_R` in [m]
            % :rtype: double
            zR = pi * obj.Waist(1) * obj.Waist(2) / obj.Wavelength;
        end
        function I = get.IntensityAveraged(obj)
           % Get average intensity :math:`I = P/(\pi w_x w_y)`.
           %
           % :return: Average intensity :math:`I` in [W/m^2]
           % :rtype: double
           I = obj.Power/obj.Waist(1)/obj.Waist(2)/pi;
        end
        function obj = set.Waist(obj,val)
            if isscalar(val)
                val = [val;val];
            end
            if (norm(val - obj.Waist)>eps || any(isnan(obj.Waist)) ) && all(~isnan(val))
                obj.Waist = val;
                if ~isnan(obj.Power)
                    obj.Intensity = 2 * obj.Power / obj.Waist(1) / obj.Waist(2) / pi;
                elseif ~isnan(obj.Intensity)
                    obj.Power = obj.Intensity * obj.Waist(1) * obj.Waist(2) * pi / 2;
                end
            end
        end
    end
end

