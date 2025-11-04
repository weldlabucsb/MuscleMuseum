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
                options.atomicState struct = struct.empty 
            end
            obj@Potential(atom,name,atomicState = options.atomicState);
            obj.MagneticField = magneticField;
        end

        function func = spaceFunc(obj)
            % Build low-field potential :math:`V(\mathbf{r}) = \alpha \|\mathbf{B}(\mathbf{r})\|`.
            %
            % :return: function handle mapping :math:`\mathbf{r}` to :math:`V(\mathbf{r})` [Hz]
            % :rtype: function_handle
            bias = vecnorm(obj.MagneticField.Bias);
            prefactor = obj.Atom.ZeemanShiftFactor( ...
                bias,...
                obj.AtomicState.N,...
                obj.AtomicState.L,...
                obj.AtomicState.J,...
                obj.AtomicState.F,...
                obj.AtomicState.MF...
                );
            bSpaceFunc = obj.MagneticField.spaceFunc;
            func = @(r) prefactor * vecnorm(bSpaceFunc(r));
        end

    end
end

