classdef OneFManifold < AtomManifold
    %:class:`OneFManifold` single-:math:`F` hyperfine manifold (:math:`M_F`).
    %
    % **Examples:**
    %
    % .. code-block:: matlab
    %
    %    % Example1: Construct a specific F-manifold and get Zeeman Hamiltonian
    %    alk = Alkali("Rubidium87");
    %    Fg  = totalAngularMomentum(1/2, alk.I);
    %    mani = OneFManifold(alk, alk.groundStateN, 0, 1/2, max(Fg));
    %    B   = MagneticField(bias=[0;0;1e-4]);
    %    Ha  = mani.HamiltonianAtom();
    
    properties (SetAccess = protected)
        N int32 % Principal quantum number
        L int32 % Orbital angular momentum :math:`L`
        J double % Total electronic angular momentum :math:`J`
        F double % Total hyperfine angular momentum :math:`F`
        MF double % Magnetic sublevel :math:`M_F`
        Energy double % Hyperfine energy shift [Hz]
        LandegJ double % Landé :math:`g_J`
        LandegF double % Landé :math:`g_F`
        StateList table % Table of basis states and properties
        FOperator % Spin operators :math:`F_{x,y,z}` (cell)
    end
    
    methods
        function obj = OneFManifold(atom,n,l,j,f)
            % Construct a :class:`OneFManifold`.
            %
            % :param atom: Atom context
            % :type atom: :class:`Atom`
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum :math:`L`
            % :type l: int32
            % :param j: Total electronic angular momentum :math:`J`
            % :type j: double
            % :param f: Hyperfine :math:`F`
            % :type f: double

            %% Set quantum numbers N,L,J
            obj@AtomManifold(atom)
            obj.N = n;
            obj.L = l;
            obj.J = j;
            obj.F = f;

            %% Set quantum numbers F,MF
            obj.MF = magneticAngularMomentum(obj.F);

            %% Set energies and frequencies, in Hz
            obj.Frequency = 0;
            obj.Energy = zeros(1,numel(obj.F));
            
            %% Set magnetic properties
            obj.LandegJ = obj.Atom.ArcObj.getLandegjExact(obj.L,obj.J);
            obj.LandegF = obj.Atom.ArcObj.getLandegfExact(obj.L,obj.J,obj.F);

            %% Set state list
            obj.NNState = numel(obj.MF);
            Index = 1:obj.NNState;
            N = repmat(obj.N,1,numel(obj.MF));
            L = repmat(obj.L,1,numel(obj.MF));
            J = repmat(obj.J,1,numel(obj.MF));
            F = angularMomentumList(obj.F);
            MF = obj.MF;
            gI = repmat(obj.Atom.gI,1,obj.NNState);
            gJ = repmat(obj.LandegJ,1,numel(obj.MF));

            f = obj.F;
            energy = obj.Energy;
            gf = obj.LandegF;
            mSize = 2*f + 1;
            Energy = zeros(1,obj.NNState);
            gF = zeros(1,obj.NNState);
            for ii = 1:numel(energy)
                Energy((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii)))...
                    = repmat(energy(ii),1,mSize(ii));
                gF((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii)))...
                    = repmat(gf(ii),1,mSize(ii));
            end
            
            Index = Index(:);
            N = N(:);
            L = L(:);
            J = J(:);
            F = F(:);
            MF = MF(:);
            gI = gI(:);
            gJ = gJ(:);
            gF = gF(:);
            Energy = Energy(:);
            obj.StateList = table(Index,N,L,J,F,MF,gI,gJ,gF,Energy);

            %% Operators
            obj.FOperator = spinMatrices(obj.F);

        end

        function Ha = HamiltonianAtom(obj,fRot)
            % Diagonal Hamiltonian including rotating-frame shift for excited states.
            %
            % :param fRot: Rotation-frame frequency [Hz]
            % :type fRot: double optional
            % :return: Hamiltonian matrix [Hz]
            % :rtype: double
            %
            % .. math::
            %
            %    H_a = \operatorname{diag}\big(E - f_\mathrm{rot}\,\chi_\mathrm{exc}\big)
            %
            % where :math:`\chi_\mathrm{exc}` is 1 on excited states and 0 on ground states.
            arguments
                obj TwoJManifold
                fRot double = 0
            end
            s = obj.StateList;
            s(s.IsExcited,:).Energy = s(s.IsExcited,:).Energy - fRot;
            Ha = diag(s.Energy);
            Ha = sparse(Ha);
        end


    end
end

