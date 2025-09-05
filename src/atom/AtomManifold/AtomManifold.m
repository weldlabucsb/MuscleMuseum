classdef (Abstract) AtomManifold < matlab.mixin.Heterogeneous
    %:class:`AtomManifold` base for hyperfine/Zeeman manifolds and transitions.
    %
    % Encapsulates an :class:`Atom` context, the number of states, and
    % transition center frequency. Provides derived quantities such as
    % wavelength, angular wavenumber, recoil momentum/velocity/energy,
    % and recoil temperature.
    
    properties (SetAccess = protected)
        Atom Atom % Atom context
        NNState int32 % Total number of states
        Frequency double % Center-of-gravity transition frequency [Hz]
    end

    properties (Dependent)
        Wavelength double % :math:`\lambda = c/f` [m]
        AngularWavenumber double % :math:`k=2\pi/\lambda` [rad/m]
        RecoilMomentum double % :math:`p_r=\hbar k` [kg·m/s]
        RecoilVelocity double % :math:`v_r=p_r/m` [m/s]
        RecoilEnergy double % :math:`E_r/h` [Hz]
        RecoilTemperature double % :math:`T_r=2 E_r h/k_B` [K]
    end

    properties (Constant,Hidden)
        DipoleUnit = Constants.SI("a0")*Constants.SI("e") % For converting ARC output to SI unit
    end
    
    methods
        function obj = AtomManifold(atom)
            % Construct an :class:`AtomManifold` with an :class:`Atom` context.
            %
            % :param atom: Atom context
            % :type atom: :class:`Atom`
            obj.Atom = atom;
        end

        function lambda0 = get.Wavelength(obj)
            % Wavelength :math:`\lambda=c/f`.
            %
            % :return: Wavelength [m]
            % :rtype: double
            lambda0 = Constants.SI("c")./obj.Frequency;
        end
        function k0 = get.AngularWavenumber(obj)
            % Angular wavenumber :math:`k=2\pi/\lambda`.
            %
            % :return: :math:`k` [rad/m]
            % :rtype: double
            k0 = 2*pi./obj.Wavelength;
        end
        function pr = get.RecoilMomentum(obj)
            % Recoil momentum :math:`p_r=\hbar k`.
            %
            % :return: :math:`p_r` [kg·m/s]
            % :rtype: double
            pr = Constants.SI("hbar")*obj.AngularWavenumber;
        end
        function vr = get.RecoilVelocity(obj)
            % Recoil velocity :math:`v_r=p_r/m`.
            %
            % :return: :math:`v_r` [m/s]
            % :rtype: double
            vr = obj.RecoilMomentum./obj.Atom.mass;
        end
        function er = get.RecoilEnergy(obj)
            % Recoil energy :math:`E_r/h`.
            %
            % :return: :math:`E_r` [Hz]
            % :rtype: double
            er = 1/2*obj.Atom.mass*((obj.RecoilVelocity).^2) ./ Constants.SI("hbar")/2/pi;
        end
        function tr = get.RecoilTemperature(obj)
            % Recoil temperature :math:`T_r=2 E_r h / k_B`.
            %
            % :return: :math:`T_r` [K]
            % :rtype: double
            tr = 2*obj.RecoilEnergy.*Constants.SI("hbar")*2*pi./Constants.SI("kB"); % factor of 2
        end
    end
end

