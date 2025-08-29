classdef OpticalTrap < OpticalPotential
    %:class:`OpticalTrap` models a focused Gaussian dipole trap.
    %
    % Provides trap :attr:`Depth` and harmonic frequencies (:attr:`AxialFrequency`, :attr:`RadialFrequency`)
    % derived from the :class:`GaussianBeam` parameters and atomic properties.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    trap = OpticalTrap(atom, gaussianBeam);
    %    fz = trap.AxialFrequency;
    %
    properties (Dependent)
        Depth % Trap depth in [Hz]
        AxialFrequency % Axial trap frequency in [Hz]
        RadialFrequency % Radial trap frequency in [Hz]
    end
    
    methods
        function obj = OpticalTrap(atom,laser,name)
            % Construct an :class:`OpticalTrap`.
            %
            % :param atom: Atomic species
            % :type atom: :class:`Atom`
            % :param laser: Focused Gaussian beam
            % :type laser: :class:`GaussianBeam`
            % :param name: Optional name
            % :type name: string
            arguments
                atom (1,1) Atom
                laser (1,1) GaussianBeam
                name string = string.empty
            end
            obj@OpticalPotential(atom,laser,name);
        end
        
        function v0 = get.Depth(obj)
            % Get trap depth :math:`V_0 = |\alpha_0 E^2|/4` (in [Hz]).
            %
            % :return: Trap depth :math:`V_0` in [Hz]
            % :rtype: double
            v0 =  abs(obj.ScalarPolarizabilityGround * abs(obj.Laser.ElectricFieldAmplitude)^2 / 4);
        end
        function fZ = get.AxialFrequency(obj)
            % Get axial trap frequency :math:`f_z = \frac{1}{2\pi}\sqrt{2 V_0/(m z_R^2)}`.
            %
            % :return: Axial frequency :math:`f_z` in [Hz]
            % :rtype: double
            zR = obj.Laser.RayleighRange;
            m = obj.Atom.mass;
            v0 =  2 * pi * Constants.SI("hbar") * obj.Depth;
            fZ = sqrt(2 * v0 / m / zR^2) / 2 / pi;
        end
        function fRho = get.RadialFrequency(obj)
            % Get radial trap frequency :math:`f_\rho = \frac{1}{2\pi}\sqrt{4 V_0/(m w_0^2)}`.
            %
            % :return: Radial frequency :math:`f_\rho` in [Hz]
            % :rtype: double
            w0 = sqrt(prod(obj.Laser.Waist));
            m = obj.Atom.mass;
            v0 = 2 * pi * Constants.SI("hbar") * obj.Depth;
            fRho = sqrt(4 * v0 / m / w0^2) / 2 / pi;
        end
    end
end

