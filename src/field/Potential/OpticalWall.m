classdef OpticalWall < OpticalPotential
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
        Height % Trap height in [Hz]
        AxialFrequency % Axial trap frequency in [Hz]
        RadialFrequency % Radial trap frequency in [Hz]
    end
    
    methods
        function obj = OpticalWall(atom,laser,name,options)
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
                options.atomicState = struct.empty
            end
           obj@OpticalPotential(atom,laser,name,atomicState = options.atomicState);
        end
        
        function v0 = get.Height(obj)
            % Get trap depth :math:`V_0 = |\alpha_0 E^2|/4` (in [Hz]).
            %
            % :return: Trap depth :math:`V_0` in [Hz]
            % :rtype: double
            atom = obj.Atom;
            v0 = abs(atom.AcStarkShiftLargeDetuning(...
                obj.Laser,...
                obj.AtomicState.N,...
                obj.AtomicState.L,...
                obj.AtomicState.J,...
                obj.AtomicState.F,...
                obj.AtomicState.MF));
        end
        function fZ = get.AxialFrequency(obj)
            % Get axial trap frequency :math:`f_z = \frac{1}{2\pi}\sqrt{2 V_0/(m z_R^2)}`.
            %
            % :return: Axial frequency :math:`f_z` in [Hz]
            % :rtype: double
            zR = obj.Laser.RayleighRange;
            m = obj.Atom.mass;
            v0 =  2 * pi * Constants.SI("hbar") * obj.Height;
            fZ = sqrt(2 * v0 / m / zR^2) / 2 / pi;
        end
        function fRho = get.RadialFrequency(obj)
            % Get radial trap frequency :math:`f_\rho = \frac{1}{2\pi}\sqrt{4 V_0/(m w_0^2)}`.
            %
            % :return: Radial frequency :math:`f_\rho` in [Hz]
            % :rtype: double
            w0 = sqrt(prod(obj.Laser.Waist));
            m = obj.Atom.mass;
            v0 = 2 * pi * Constants.SI("hbar") * obj.Height;
            fRho = sqrt(4 * v0 / m / w0^2) / 2 / pi;
        end
        function func = spaceFunc(obj)
            H0 = obj.Height;
            k = obj.Laser.AngularWavevector.';
            c = obj.Laser.Center;
            k0 = norm(k);
            kHat = k ./ k0;
            w0 = sqrt(prod(obj.Laser.Waist));
            zR = obj.Laser.RayleighRange;
            func = @(r) V(r-c);
            function Vout = V(r)
                z = kHat * r;
                r2 = vecnorm(r - kHat.' * z).^2;
                wz = w0 * sqrt(1 + (z./zR).^2);
                Vout = H0 .* (w0./wz).^2 .* exp(-2 .* r2 ./ wz.^2);
            end
        end
    end
end

