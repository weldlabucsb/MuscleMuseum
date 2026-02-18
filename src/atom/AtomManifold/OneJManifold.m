classdef OneJManifold < AtomManifold
    %:class:`OneJManifold` single-:math:`J` hyperfine manifold (:math:`F,M_F`).
    %
    % Builds the :attr:`StateList` with energies, :math:`g`-factors and labels,
    % and provides spin operators and Zeeman Hamiltonians.
    %
    % **Examples:**
    %
    % .. code-block:: matlab
    %
    %    % Example1: Use prebuilt manifold from an Alkali atom
    %    alk = Alkali("Rubidium87");
    %    mani = alk.DGround;                 % :class:`OneJManifold` for ground state
    %    B   = MagneticField(bias=[0;0;1e-4]);
    %    Hz  = mani.HamiltonianAtomBiasField(B); % Zeeman Hamiltonian [Hz]
    %
    % .. code-block:: matlab
    %
    %    % Example2: Construct directly with (n,L,J)
    %    alk = Alkali("Rubidium87");
    %    mani = OneJManifold(alk, n=alk.groundStateN, l=0, j=1/2);
    %    Ha   = mani.HamiltonianAtom();      % Diagonal hyperfine Hamiltonian

    properties (SetAccess = protected)
        N int32 % Principal quantum number
        L int32 % Orbital angular momentum :math:`L`
        J double % Total electronic angular momentum :math:`J`
        F double % Hyperfine :math:`F` values
        MF double % Magnetic sublevels :math:`M_F`
        HFSCoefficient %[A,B] hyperfine coefficients (Hz)
        Energy double % Hyperfine energy shifts [Hz]
        LandegJ double % Landé :math:`g_J`
        LandegI double % Nuclear :math:`g_I`
        LandegF double % Landé :math:`g_F` per :math:`F`
        StateList table % Basis state table with labels
        JOperator cell % Electronic spin operators :math:`J_{x,y,z}`
        IOperator cell % Nuclear spin operators :math:`I_{x,y,z}`
        FOperator cell % Hyperfine spin operators :math:`F_{x,y,z}`
    end

    methods
        function obj = OneJManifold(atom,n,l,j)
            % Construct a :class:`OneJManifold`.
            %
            % :param atom: Atom context
            % :type atom: :class:`Atom`
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum
            % :type l: int32
            % :param j: Total electronic angular momentum
            % :type j: double

            %% Set quantum numbers N,L,J
            obj@AtomManifold(atom)
            obj.N = n;
            obj.L = l;
            obj.J = j;

            %% Set quantum numbers F,MF
            obj.F = totalAngularMomentum(obj.Atom.I,obj.J);
            obj.MF = magneticAngularMomentum(obj.F);

            %% Set energies and frequencies, in Hz
            obj.Frequency = 0;
            obj.HFSCoefficient = py2Mat(obj.Atom.ArcObj.getHFSCoefficients(obj.N,obj.L,obj.J));
            obj.Energy = zeros(1,numel(obj.F));
            for ii = 1:numel(obj.F)
                obj.Energy(ii) = obj.Atom.ArcObj.getHFSEnergyShift(obj.J,obj.F(ii),obj.HFSCoefficient(1),obj.HFSCoefficient(2));
            end

            %% Set magnetic properties
            obj.LandegI = obj.Atom.gI;
            obj.LandegJ = obj.Atom.ArcObj.getLandegjExact(obj.L,obj.J);
            obj.LandegF = arrayfun(@(x) obj.Atom.ArcObj.getLandegfExact(obj.L,obj.J,x),obj.F);

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

            Label = cell(obj.NNState,1);
            for ii = 1:obj.NNState
                Label{ii} = "$F=" + num2str(F(ii)) + ",M_F = " + num2str(MF(ii)) + "$";
            end
            Label = string(Label);
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
            obj.StateList = table(Index,N,L,J,F,MF,gI,gJ,gF,Energy,Label);

            %% Operators
            F = arrayfun(@(j) spinMatrices(j),obj.F,'UniformOutput',false);
            F = horzcat(F{:});
            obj.FOperator = arrayfun(@(r) blkdiag(F{r,:}),(1:3)','UniformOutput',false);
            [obj.JOperator,obj.IOperator] = uncoupledSpinMatrices(obj.J,obj.Atom.I);

            %% Associate F,MF with MI,MJ
            dataPath = obj.Atom.DataPath;
            filePath = fullfile(dataPath,"mImJ.mat");
            if isfile(filePath)
                warning off
                try
                    mimjList = loadVar(filePath,obj.Atom.Name);
                    sTemp = join(obj.StateList,mimjList);
                    if size(sTemp,1)~=obj.NNState
                        mimjList = obj.getMIMJ;
                    end
                catch
                    mimjList = obj.getMIMJ;
                end
                warning on
            else
                mimjList = obj.getMIMJ;
            end
            obj.StateList = join(obj.StateList,mimjList);

        end

        function Ha = HamiltonianAtom(obj,U)
            % Diagonal hyperfine Hamiltonian; applies optional basis change.
            %
            % :param obj: Hyperfine manifold object.
            % :type obj: :class:`OneJManifold`
            % :param U: Basis-change unitary. Use 1 to keep current basis.
            % :type U: double optional
            % :returns: Ha — atomic Hamiltonian [Hz].
            % :rtype: double
            %
            % .. math::
            %
            %    H_a = U^\dagger \operatorname{diag}(E)\, U
            %
            arguments
                obj OneJManifold
                U double = 1
            end
            s = obj.StateList;
            % s(s.IsExcited,:).Energy = s(s.IsExcited,:).Energy - fRot;
            Ha = diag(s.Energy);
            Ha = U' * Ha * U;
            Ha = (Ha + Ha')/2;
        end

        function Ham = HamiltonianAtomBiasField(obj,B,U)
            % Zeeman Hamiltonian in a static bias field.
            %
            % :param obj: Hyperfine manifold object.
            % :type obj: :class:`OneJManifold`
            % :param B: Magnetic field [T].
            % :type B: :class:`MagneticField`
            % :param U: Basis-change unitary. Use 1 to keep current basis.
            % :type U: double optional
            % :returns: Ham — Zeeman Hamiltonian [Hz].
            % :rtype: double
            %
            % .. math::
            %
            %    H_Z = \mu_B \big( g_J \mathbf{J} + g_I \mathbf{I} \big) \cdot \mathbf{B} / h
            %
             arguments
                obj OneJManifold
                B MagneticField
                U double = 1
             end
             bias = B.Bias;
             IO = obj.IOperator;
             JO = obj.JOperator;
             Ham = Constants.SI('muB') * ...
                 (obj.LandegJ * operatorVectorDot(JO,bias) + ...
                 obj.LandegI * operatorVectorDot(IO,bias)) / Constants.SI('hbar') / 2 / pi;
             Ham = U' * Ham * U;
             Ham = (Ham + Ham')/2;
        end

        function [dressedStateList,U,brMap] = BiasDressedStateList(obj,B,isPlot,options)
            % Compute bias-field dressed states and optional dispersion map.
            %
            % :param obj: Hyperfine manifold object.
            % :type obj: :class:`OneJManifold`
            % :param B: Bias magnetic field [T], aligned with quantization axis.
            % :type B: :class:`MagneticField`
            % :param isPlot: Plot dressed energies vs bias field.
            % :type isPlot: logical optional
            % :param samplingSize: Number of samples along B.
            % :type samplingSize: double optional
            % :returns:
            %   - dressedStateList — table with indices, energies, dressed states
            %   - U — unitary to the dressed basis
            %   - brMap — {Bz [T], eigenvalue matrix [Hz]}
            % :rtype: table, double, cell
            %
            arguments
                obj OneJManifold
                B MagneticField
                isPlot logical = false
                options.samplingSize double = []
            end
            bias = B.Bias;
            if ~(bias(1) == 0 && bias(2) ==0 && bias(3) > 0) %check if quantization axis is aligned with the bias magnetic field
                error("Bias field is not aligned with the quantization axis")
            end

            energy = obj.Energy;
            gF = max(abs(obj.StateList.gF));
            energyGap = min(abs(diff(sort(energy))));
            dEdB = gF * Constants.SI("muB") / Constants.SI("hbar") / 2 / pi;
            dB = energyGap / dEdB;

            if ~isempty(options.samplingSize)
                samplingSize = options.samplingSize;
            else
                samplingSize = max(round(bias(3)/ dB *20),1000);
                samplingSize = min(samplingSize,5000);
            end
            
            Ha = obj.HamiltonianAtom;
            Ham = obj.HamiltonianAtomBiasField(B);
            HMatrix = zeros([size(Ha),samplingSize]);
            scaleFactor = linspace(0,1,samplingSize);
            for ii = 1:samplingSize
                HMatrix(:,:,ii) = Ha + Ham * scaleFactor(ii);
            end
            [V,D] = eigenshuffle(HMatrix);
            EnergyShift = D(:,end);
            dressedState = V(:,:,end);
            DressedState = cell(numel(EnergyShift),1);
            for ii = 1:numel(EnergyShift)
                DressedState{ii} = dressedState(:,ii);
            end
            zeroFieldState = V(:,:,1);
            [Index,~] = find(zeroFieldState);
            dressedStateList = table(Index,EnergyShift,DressedState);
            dressedStateList = sortrows(dressedStateList,"Index");
            dressedStateList = join(obj.StateList,dressedStateList);
            dressedStateList.EnergyShift = dressedStateList.EnergyShift - dressedStateList.Energy;
            U = dressedStateList.DressedState;
            U = horzcat(U{:}); %Unitary operator the connect to the dressed states

            [~,sortIndex] = sort(Index);
            biasList = norm(B.Bias) * scaleFactor;
            brMap = {biasList,D(sortIndex,:)};

            if isPlot
                close(figure(1024))
                figure(1024)

                ll = cell(1,numel(Index));
                for ii = 1:numel(Index)
                    s = dressedStateList(dressedStateList.Index == ii,:);
                    ll{ii} = "$F=" + num2str(s.F) + ",M_F=" + num2str(s.MF) + "$";
                end
                plot(biasList*1e4,D(sortIndex,:)*1e-6)
                xlabel('Bias field [Gauss]',Interpreter='latex')
                ylabel('Energy [MHz]',Interpreter='latex')
                legend(ll{:},'interpreter','latex')
                render
            end
        end
        
        function dressedStateList = LaserDressedStateListLargeDetuning(obj,laser)
            % Compute laser-dressed states for large detuning limit.
            %
            % Calculates AC Stark energy shifts for all hyperfine states in the manifold
            % due to a laser field. The method computes the total AC Stark shift including
            % scalar, vector, and tensor contributions for each :math:`|F,M_F\rangle` state.
            % Valid in the large detuning limit where the laser detuning is much larger
            % than the hyperfine splitting.
            %
            % :param laser: :class:`Laser` object specifying field parameters (frequency, intensity, polarization, direction)
            % :type laser: Laser
            % :return: State table with AC Stark energy shifts
            % :rtype: table
            %
            % **Returns:**
            %
            % Table identical to :attr:`StateList` with additional :attr:`EnergyShift` column
            % containing the AC Stark shift :math:`\Delta E` [Hz] for each state. The shift
            % includes scalar (:math:`\propto I`), vector (:math:`\propto I \cdot M_F`), and
            % tensor (:math:`\propto I \cdot (3M_F^2 - F(F+1))`) contributions.
            %
            % **Notes:**
            %
            % The quantization axis is assumed to be aligned with the :math:`z`-axis.
            % For each state, the method calls :meth:`Atom.AcStarkShiftLargeDetuning`
            % with quantum numbers :math:`(n,\ell,j,f,m_f)` extracted from the state table.
            
            dressedStateList = obj.StateList;
            dressedStateList.EnergyShift = arrayfun(@(x) obj.Atom.AcStarkShiftLargeDetuning(...
                laser,...
                dressedStateList.N(x),...
                dressedStateList.L(x),...
                dressedStateList.J(x),...
                dressedStateList.F(x),...
                dressedStateList.MF(x),...
                [0,0]), dressedStateList.Index);
        end

        function [dressedStateList,U] = BiasDressedStateListTest(obj,B,isPlot)
            % Test variant of bias-field dressed states (alternate indexing).
            %
            % :param obj: Hyperfine manifold object.
            % :type obj: :class:`OneJManifold`
            % :param B: Bias magnetic field [T], aligned with quantization axis.
            % :type B: :class:`MagneticField`
            % :param isPlot: Plot dressed energies vs bias field.
            % :type isPlot: logical optional
            % :returns:
            %   - dressedStateList — table with indices, energies, dressed states
            %   - U — unitary to the dressed basis
            % :rtype: table, double
            %
            arguments
                obj OneJManifold
                B MagneticField
                isPlot logical = false
            end
            bias = B.Bias;
            if ~(bias(1) == 0 && bias(2) ==0 && bias(3) > 0) %check if quantization axis is aligned with the bias magnetic field
                error("Bias field is not aligned with the quantization axis")
            end

            energy = obj.Energy;
            gF = max(abs(obj.StateList.gF));
            energyGap = min(abs(diff(sort(energy))));
            dEdB = gF * Constants.SI("muB") / Constants.SI("hbar") / 2 / pi;
            dB = energyGap / dEdB;

            samplingSize = max(round(bias(3)/ dB *20),1000);
            samplingSize = min(samplingSize,5000);
            BList = arrayfun(@(b) MagneticField(bias=[0;0;b]),linspace(0.01e-4,bias(3),samplingSize));
            HList = arrayfun(@(b) obj.HamiltonianAtom + obj.HamiltonianAtomBiasField(b),BList,UniformOutput=false);
            HMatrix = zeros([size(HList{1}),samplingSize]);
            for ii = 1:samplingSize
                HMatrix(:,:,ii) = HList{ii};
            end
            [V,D] = eigenshuffle(HMatrix);
            EnergyShift = D(:,end);
            dressedState = V(:,:,end);
            DressedState = cell(numel(EnergyShift),1);
            for ii = 1:numel(EnergyShift)
                DressedState{ii} = dressedState(:,ii);
            end
            zeroFieldState = V(:,:,1);
            [~,Index] = max(abs(zeroFieldState));
            Index = Index';
            dressedStateList = table(Index,EnergyShift,DressedState);
            dressedStateList = sortrows(dressedStateList,"Index");
            dressedStateList = join(obj.StateList,dressedStateList);
            dressedStateList.EnergyShift = dressedStateList.EnergyShift - dressedStateList.Energy;
            U = dressedStateList.DressedState;
            U = horzcat(U{:}); %Unitary operator the connect to the dressed states
            if isPlot
                close(figure(1024))
                figure(1024)
                biasList = [BList.Bias];
                biasList = biasList(3,:);
                ll = cell(1,numel(Index));
                [~,sortIndex] = sort(Index);
                for ii = 1:numel(Index)
                    s = dressedStateList(dressedStateList.Index == ii,:);
                    ll{ii} = "$F=" + num2str(s.F) + ",M_F=" + num2str(s.MF) + "$";
                end
                plot(biasList*1e4,D(sortIndex,:)*1e-6)
                xlabel('Bias field [Gauss]',Interpreter='latex')
                ylabel('Energy [MHz]',Interpreter='latex')
                legend(ll{:},'interpreter','latex')
                render
            end
        end
        
        function mimjList = getMIMJ(obj,isPlot)
            % Map zero-field states to uncoupled projections (M_I, M_J) by adiabatic following.
            %
            % :param obj: Hyperfine manifold object.
            % :type obj: :class:`OneJManifold`
            % :param isPlot: Plot energies and labels with (M_I, M_J).
            % :type isPlot: logical optional
            % :returns: mimjList — table with columns MI and MJ per basis state.
            % :rtype: table
            %
            arguments
                obj OneJManifold
                isPlot logical = false
            end
            stateList = obj.StateList;
            eSplit = max(stateList.Energy) - min(stateList.Energy);
            b = 10 * eSplit / (stateList.gJ(1)*Constants.SI("muB") / Constants.SI("hbar") / 2 / pi);


            energy = obj.Energy;
            gF = max(abs(obj.StateList.gF));
            energyGap = min(abs(diff(sort(energy))));
            dEdB = gF * Constants.SI("muB") / Constants.SI("hbar") / 2 / pi;
            dB = energyGap / dEdB;

            samplingSize = max(round(b/ dB *40),1000);

            BList = arrayfun(@(b) MagneticField(bias=[0;0;b]),linspace(0,b,samplingSize));
            HList = arrayfun(@(b) obj.HamiltonianAtom + obj.HamiltonianAtomBiasField(b),BList,UniformOutput=false);
            HMatrix = zeros([size(HList{1}),samplingSize]);
            for ii = 1:samplingSize
                HMatrix(:,:,ii) = HList{ii};
            end
            [V,D] = eigenshuffle(HMatrix);
            zeroFieldState = V(:,:,1);
            MI = round(2*diag(V(:,:,end)'*obj.IOperator{3}*V(:,:,end)))/2;
            MJ = round(2*diag(V(:,:,end)'*obj.JOperator{3}*V(:,:,end)))/2;
            [Index,~] = find(zeroFieldState);
            mimjList = table(Index,MI,MJ);
            mimjList = sortrows(mimjList,"Index");
            mimjList = join(stateList,mimjList);
            mimjList.Energy = [];
            mimjList.gI = [];
            mimjList.gJ = [];
            mimjList.gF = [];
            mimjList.Index = [];

            % save to DataPath
            dataPath = obj.Atom.DataPath;
            filePath = fullfile(dataPath,"mImJ.mat");
            atomName = obj.Atom.Name;
            S.(atomName) = mimjList;
            if isfile(filePath)
                variableInfo = string(who('-file', filePath));
                if ismember(atomName,variableInfo)
                    data = loadVar(filePath,atomName);
                    data = [data;mimjList];
                    data = unique(data);
                    S.(atomName) = data;
                    save(filePath, '-struct', 'S','-append')
                else
                    save(filePath, '-struct', 'S','-append')
                end
            else
                save(filePath, '-struct', 'S')
            end

            if isPlot
                close(figure(1024))
                figure(1024)
                biasList = [BList.Bias];
                biasList = biasList(3,:);
                ll = cell(1,numel(Index));
                [~,sortIndex] = sort(Index);
                for ii = 1:numel(Index)
                    s = stateList(stateList.Index == ii,:);
                    sIJ = mimjList(mimjList.F == s.F & mimjList.MF == s.MF,:);
                    ll{ii} = "$F=" + num2str(s.F) + ",M_F=" + num2str(s.MF) +...
                        ",M_I=" + num2str(sIJ.MI) + ",M_J=" + num2str(sIJ.MJ) +...
                        "$";
                end
                plot(biasList*1e4,D(sortIndex,:)*1e-6)
                xlabel('Bias field [Gauss]',Interpreter='latex')
                ylabel('Energy [MHz]',Interpreter='latex')
                legend(ll{:},'interpreter','latex')
                render
            end
        end
    end
end

