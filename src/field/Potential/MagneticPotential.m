classdef MagneticPotential < Potential & matlab.mixin.Heterogeneous
    %:class:`MagneticPotential` models Zeeman energy shifts from a magnetic field.
    %
    % Couples an :class:`Atom` state to a :class:`MagneticField` and provides low- and
    % high-field limits for the Zeeman energy factor. Exposes space-dependent potential
    % functions in both limits.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    mp = MagneticPotential(atom, magneticField, "Trap", manifold="DGround");
    %    Vlow = mp.spaceFuncLowField();
    %
    properties
        MagneticField MagneticField % Background magnetic field :math:`\mathbf{B}(\mathbf{r})`
    end

    properties (Dependent)
        EnergyFactor % Effective Zeeman factor :math:`\alpha` [Hz/T]
        EnergyFactorLowField % Low-field :math:`\alpha = m_F g_F \mu_B / h` [Hz/T]
        EnergyFactorHighField % High-field :math:`\alpha = (m_J g_J + m_I g_I) \mu_B / h` [Hz/T]
    end
    
    methods
        function obj = MagneticPotential(atom,magneticField,name,options)
            % Construct a :class:`MagneticPotential`.
            %
            % :param atom: Atomic species
            % :type atom: :class:`Atom`
            % :param magneticField: Magnetic field instance
            % :type magneticField: :class:`MagneticField`
            % :param name: Potential name
            % :type name: string, optional
            % :param manifold: Atomic manifold label (e.g., "DGround")
            % :type manifold: string, optional
            % :param stateIndex: Specific state index within manifold
            % :type stateIndex: double, optional
            arguments
                atom (1,1) Atom
                magneticField MagneticField
                name string = string.empty
                options.manifold string = "DGround"
                options.stateIndex double = []
            end
            obj@Potential(atom,name);
            obj.MagneticField = magneticField;
            obj.Manifold = options.manifold;
            if ~isempty(options.stateIndex)
                obj.StateIndex = options.stateIndex;
            else
                % By default, pick the lowest magnetic trappable state
                sL = atom.(obj.Manifold).StateList;
                F = min(sL.F);
                obj.StateIndex = sL(sL.F==F & sL.MF == F,:).Index;
            end
        end

        function eFactL = get.EnergyFactorLowField(obj)
            % Low-field Zeeman factor :math:`\alpha = m_F g_F \mu_B / h` [Hz/T].
            %
            % :return: :math:`\alpha` in [Hz/T]
            % :rtype: double
            stateIdx = obj.StateIndex;
            stateList = obj.Atom.(obj.Manifold).StateList;
            mF = stateList.MF(stateIdx);
            gF = stateList.gF(stateIdx);
            muB = Constants.SI("muB");
            h = Constants.SI("hbar") * 2 * pi;
            eFactL = mF * gF * muB / h;
        end

        function eFactH = get.EnergyFactorHighField(obj)
            % High-field Zeeman factor :math:`\alpha = (m_J g_J + m_I g_I) \mu_B / h` [Hz/T].
            %
            % :return: :math:`\alpha` in [Hz/T]
            % :rtype: double
            stateIdx = obj.StateIndex;
            stateList = obj.Atom.(obj.Manifold).StateList;
            mJ = stateList.MJ(stateIdx);
            gJ = stateList.gJ(stateIdx);
            mI = stateList.MI(stateIdx);
            gI = stateList.gI(stateIdx);
            muB = Constants.SI("muB");
            h = Constants.SI("hbar") * 2 * pi;
            eFactH = (mJ * gJ + mI * gI) * muB / h;
        end

        function eFact = get.EnergyFactor(obj)
            % Choose :math:`\alpha` based on bias field vs. hyperfine splitting.
            %
            % :return: :math:`\alpha` in [Hz/T]
            % :rtype: double
            energyList = obj.Atom.(obj.Manifold).StateList.Energy;
            hfs = max(energyList) - min(energyList);
            bias = vecnorm(obj.MagneticField.Bias);
            eFactL = obj.EnergyFactorLowField;
            eFactH = obj.EnergyFactorHighField;
            if abs(bias * eFactL) < hfs / 10
                eFact = eFactL;
            else
                eFact = eFactH;
            end
        end

        function func = spaceFuncLowField(obj)
            % Build low-field potential :math:`V(\mathbf{r}) = \alpha \|\mathbf{B}(\mathbf{r})\|`.
            %
            % :return: function handle mapping :math:`\mathbf{r}` to :math:`V(\mathbf{r})` [Hz]
            % :rtype: function_handle
            prefactor = obj.EnergyFactorLowField;
            bSpaceFunc = obj.MagneticField.spaceFunc;
            func = @(r) prefactor * vecnorm(bSpaceFunc(r));
        end

        function func = spaceFuncHighField(obj)
            % Build high-field potential :math:`V(\mathbf{r}) = \alpha \|\mathbf{B}(\mathbf{r})\|`.
            %
            % :return: function handle mapping :math:`\mathbf{r}` to :math:`V(\mathbf{r})` [Hz]
            % :rtype: function_handle
            prefactor = obj.EnergyFactorHighField;
            bSpaceFunc = obj.MagneticField.spaceFunc;
            func = @(r) prefactor * vecnorm(bSpaceFunc(r));
        end

    end
end

