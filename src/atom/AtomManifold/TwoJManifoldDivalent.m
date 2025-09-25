classdef TwoJManifoldDivalent < AtomManifold
    %:class:`TwoJManifoldDivalent` divalent transition manifolds (:math:`J_g\rightarrow J_e`, with :math:`S`).
    %
    % Provides transition frequency, natural linewidth, reduced dipole matrix
    % element, reduced saturation intensity, and Doppler temperature for
    % divalent-like transitions (with spin :math:`S`).
    %
    % **Examples:**
    %
    % .. code-block:: matlab
    %
    %    % Example1: Build a blue-line-like manifold (divalent)
    %    at = Divalent("Strontium88");
    %    M  = TwoJManifoldDivalent(at, nG=5, lG=0, jG=0, sG=0, ...
    %                                 nE=5, lE=1, jE=1, sE=1);
    %    Isat = M.ReducedSaturationIntensity;
    
    properties (SetAccess = protected)
        NGround int32 % Ground principal quantum number
        LGround int32 % Ground :math:`L`
        JGround double % Ground :math:`J`
        % FGround double
        MJGround double % Ground :math:`M_J`
        SGround double % Ground spin :math:`S`
        % HFSCoefficientGround %[A,B]
        EnergyGround double % Ground energies [Hz]
        LandegJGround double % Ground Landé :math:`g_J`
        LandegFGround double % Ground Landé :math:`g_F` (if applicable)
        NExcited int32 % Excited principal quantum number
        LExcited int32 % Excited :math:`L`
        JExcited double % Excited :math:`J`
        % FExcited double
        MJExcited double % Excited :math:`M_J`
        SExcited % Excited spin :math:`S`
        % HFSCoefficientExcited %[A,B]
        EnergyExcited double % Excited energies [Hz]
        LandegJExcited double % Excited Landé :math:`g_J`
        LandegFExcited double % Excited Landé :math:`g_F` (if applicable)
        StateList table % State table (if constructed)
        JOperator cell % Electronic spin operators
        IOperator cell % Nuclear spin operators
        % FOperator cell
        NaturalLinewidth double % Natural linewidth [Hz] (no 2π)
        LifetimeExcited double % Excited-state lifetime [s]
        ReducedDipoleMatrixElement double % :math:`\langle J_g\Vert d\Vert J_e\rangle` [C·m]
        ReducedSaturationIntensity double % Reduced Isat [W/m^2]
        ReducedSaturationIntensityLu double % Reduced Isat [mW/cm^2]
        DopplerTemperature double % Doppler temperature [K]
    end
    
    methods
        function obj = TwoJManifoldDivalent(atom,nG,lG,jG,sG,nE,lE,jE,sE)
            % Construct a :class:`TwoJManifoldDivalent`.
            %
            % :param atom: Atom context
            % :type atom: :class:`Atom`
            % :param nG: Ground principal quantum number
            % :type nG: int32
            % :param lG: Ground :math:`L`
            % :type lG: int32
            % :param jG: Ground :math:`J`
            % :type jG: double
            % :param sG: Ground spin :math:`S`
            % :type sG: double
            % :param nE: Excited principal quantum number
            % :type nE: int32
            % :param lE: Excited :math:`L`
            % :type lE: int32
            % :param jE: Excited :math:`J`
            % :type jE: double
            % :param sE: Excited spin :math:`S`
            % :type sE: double

            %% Set quantum numbers N,L,J,S
            obj@AtomManifold(atom)
            obj.NGround = nG;
            obj.LGround = lG;
            obj.JGround = jG;
            obj.SGround = sG;
            obj.NExcited = nE;
            obj.LExcited = lE;
            obj.JExcited = jE;
            obj.SExcited = sE;
            
            %% Ground and excited manifold
            % maniG = OneJManifold(atom,nG,lG,jG);
            % maniE = OneJManifold(atom,nE,lE,jE);

            %% Set quantum numbers F,MF
            % obj.FGround = maniG.F;
            % obj.FExcited = maniE.F;
            % obj.MJGround = maniG.MF;
            % obj.MJExcited = maniE.MF;

            %% Set energies and frequencies, in Hz
            obj.Frequency = ...
                atom.ArcObj.getTransitionFrequency(...
                obj.NGround,...
                obj.LGround,...
                obj.JGround,...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited,...
                obj.SGround,...
                obj.SExcited);
            % obj.HFSCoefficientGround = maniG.HFSCoefficient;
            % obj.HFSCoefficientExcited = maniE.HFSCoefficient;
            % obj.EnergyGround = maniG.Energy;
            % obj.EnergyExcited = maniE.Energy + obj.Frequency;
            
            %% Set magnetic properties
            % obj.LandegJGround = maniG.LandegJ;
            % obj.LandegJExcited = maniE.LandegJ;
            % obj.LandegFGround = maniG.LandegF;
            % obj.LandegFExcited = maniE.LandegF;

            %% Set operators
            % JG = maniG.JOperator;
            % IG = maniG.IOperator;
            % FG = maniG.FOperator;
            % JE = maniE.JOperator;
            % IE = maniE.IOperator;
            % FE = maniE.FOperator; 
            % 
            % obj.JOperator = arrayfun(@(r) blkdiag(JE{r,:},JG{r,:}),(1:3)',UniformOutput=false);
            % obj.IOperator = arrayfun(@(r) blkdiag(IE{r,:},IG{r,:}),(1:3)',UniformOutput=false);
            % obj.FOperator = arrayfun(@(r) blkdiag(FE{r,:},FG{r,:}),(1:3)',UniformOutput=false);
            % 

            %% Set state list
            % obj.NNState = numel(obj.MJGround) + numel(obj.MJExcited);
            % Index = 1:obj.NNState;
            % N = [repmat(obj.NExcited,1,numel(obj.MJExcited)),repmat(obj.NGround,1,numel(obj.MJGround))];
            % L = [repmat(obj.LExcited,1,numel(obj.MJExcited)),repmat(obj.LGround,1,numel(obj.MJGround))];
            % J = [repmat(obj.JExcited,1,numel(obj.MJExcited)),repmat(obj.JGround,1,numel(obj.MJGround))];
            % F = angularMomentumList([obj.FExcited,obj.FGround]);
            % MF = [obj.MJExcited,obj.MJGround];
            % gI = repmat(obj.Atom.gI,1,obj.NNState);
            % gJ = [repmat(obj.LandegJExcited,1,numel(obj.MJExcited)),repmat(obj.LandegJGround,1,numel(obj.MJGround))];
            % 
            % 
            % 
            % IsExcited = zeros(1,obj.NNState);
            % IsExcited(1:numel(obj.MJExcited)) = 1;
            % IsExcited = logical(IsExcited);
            % 
            % f = [obj.FExcited,obj.FGround];
            % energy = [obj.EnergyExcited,obj.EnergyGround];
            % gf = [obj.LandegFExcited,obj.LandegFGround];
            % mSize = 2*f + 1;
            % Energy = zeros(1,obj.NNState);
            % gF = zeros(1,obj.NNState);
            % for ii = 1:numel(energy)
            %     Energy((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii)))...
            %         = repmat(energy(ii),1,mSize(ii));
            %     gF((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii)))...
            %         = repmat(gf(ii),1,mSize(ii));
            % end
            % 
            % Label = cell(obj.NNState,1);
            % for ii = 1:obj.NNState
            %     if IsExcited(ii)
            %         Label{ii} = "$F'=" + num2str(F(ii)) + ",M'_F = " + num2str(MF(ii)) + "$";
            %     else
            %         Label{ii} = "$F=" + num2str(F(ii)) + ",M_F = " + num2str(MF(ii)) + "$";
            %     end
            % end
            % Label = string(Label);
            % Index = Index(:);
            % N = N(:);
            % L = L(:);
            % J = J(:);
            % F = F(:);
            % MF = MF(:);
            % gI = gI(:);
            % gJ = gJ(:);
            % gF = gF(:);
            % Energy = Energy(:);
            % IsExcited = IsExcited(:);
            % MI = [maniE.StateList.MI;maniG.StateList.MI];
            % MJ = [maniE.StateList.MJ;maniG.StateList.MJ];
            % obj.StateList = table(Index,N,L,J,F,MF,MI,MJ,gI,gJ,gF,Energy,IsExcited,Label);

            %% Set dipole transition properties
            obj.LifetimeExcited = obj.Atom.ArcObj.getStateLifetime(...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited,...
                0,...
                int32(0),...
                obj.SExcited...
                );
            obj.NaturalLinewidth = obj.Atom.ArcObj.getTransitionRate(...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited,...
                obj.NGround,...
                obj.LGround,...
                obj.JGround,...
                0,...
                obj.SGround)/2/pi;
            obj.ReducedDipoleMatrixElement = obj.Atom.ArcObj.getReducedMatrixElementJ_asymmetric(...
                obj.NGround,...
                obj.LGround,...
                obj.JGround,...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited,...
                obj.SGround) * obj.DipoleUnit;
            obj.ReducedSaturationIntensity = ...
                Constants.SI("hbar")^2 * ...
                (2 * pi * obj.NaturalLinewidth)^2 / 4 /...
                Constants.SI("Z0") /...
                (obj.ReducedDipoleMatrixElement)^2;
            obj.ReducedSaturationIntensityLu = obj.ReducedSaturationIntensity / 10;
            obj.DopplerTemperature = Constants.SI("hbar") * obj.NaturalLinewidth * 2 * pi / 2 / Constants.SI("kB");
        end
        
        function DME = DipoleMatrixElement(obj,fG,mfG,fE,mfE,q,U)
            % Dipole matrix element :math:`\langle f_G,m_F^G| d_q | f_E,m_F^E\rangle` [C·m].
            %
            % Selection rule: :math:`m_F^E + q = m_F^G`. Sign of :math:`q`
            % follows Steck-like convention.
            %
            % .. math::
            %
            %    m_F^E = m_F^G + q
            %
            % :param fG: Ground :math:`F`
            % :type fG: double
            % :param mfG: Ground :math:`M_F`
            % :type mfG: double
            % :param fE: Excited :math:`F'`
            % :type fE: double
            % :param mfE: Excited :math:`M_F'`
            % :type mfE: double
            % :param q: Spherical component (:math:`-1,0,+1`)
            % :type q: double
            % :param U: Basis transform
            % :type U: double, optional
            % :return: Dipole matrix element [C·m]
            % :rtype: double
            arguments
                obj TwoJManifold
                fG double
                mfG double
                fE double
                mfE double
                q double
                U double = 1
            end
            if U == 1
                DME = obj.Atom.ArcObj.getDipoleMatrixElementHFS( ...
                    obj.NGround,...
                    obj.LGround,...
                    obj.JGround,...
                    fG,...
                    mfG,...
                    obj.NExcited,...
                    obj.LExcited,...
                    obj.JExcited,...
                    fE,...
                    mfE,...
                    -int32(q)...
                    ) * obj.DipoleUnit;
            elseif all(size(U) == obj.NNState)
                Sigma = obj.LoweringOperator(q,U);
                sList = obj.StateList;
                idxG = sList(sList.F==fG & sList.MF==mfG & sList.IsExcited==false,:).Index;
                idxE = sList(sList.F==fE & sList.MF==mfE & sList.IsExcited==true,:).Index;
                DME = Sigma(idxG,idxE) * obj.ReducedDipoleMatrixElement;
            end
        end

        function dme = DipoleMatrixElementNu(obj,fG,mfG,fE,mfE,q,U)
            % Dipole matrix element normalized by reduced DME.
            %
            % .. math::
            %
            %    d_\nu = \frac{\langle f_G m_F^G | d_q | f_E m_F^E \rangle}{\langle J_G \Vert d \Vert J_E \rangle}
            %
            % :return: Dimensionless ratio
            % :rtype: double
            arguments
                obj TwoJManifold
                fG double
                mfG double
                fE double
                mfE double
                q double
                U double = 1
            end
            dme = obj.DipoleMatrixElement(fG,mfG,fE,mfE,q,U) / obj.ReducedDipoleMatrixElement;
        end

        function Isat = SaturationIntensity(obj,fG,mfG,fE,mfE,U)
            % Saturation intensity for specified sublevels.
            %
            % .. math::
            %
            %    I_{\mathrm{sat}} = \frac{I_{\mathrm{sat}}^{(\mathrm{red})}}{|d_\nu|^2}
            %
            % :return: :math:`I_{sat}` [W/m^2]
            % :rtype: double
            arguments
                obj TwoJManifold
                fG double
                mfG double
                fE double
                mfE double
                U double = 1
            end
            q = mfG - mfE;
            if abs(q) <= 1
                Isat = obj.ReducedSaturationIntensity / ...
                    abs(obj.DipoleMatrixElementNu(fG,mfG,fE,mfE,q,U))^2;
            else
                Isat = Inf;
            end
        end

        function Sigma = LoweringOperator(obj,q,U)
            % Spherical lowering operator (Steck Eq. 7.407 analogue).
            %
            % .. math::
            %
            %    \Sigma_q = \sum_{g,e} |g\rangle\langle e|\, d_\nu(g\leftarrow e;q)
            arguments
                obj TwoJManifold
                q int32
                U double = 1
            end
            Sigma = zeros(obj.NNState,obj.NNState);
            s = obj.StateList;
            for ii = 1:obj.NNState
                for jj = 1:obj.NNState
                    Sigma(ii,jj) = ...
                        (~s.IsExcited(ii)) * ...
                        s.IsExcited(jj) * ...
                        DipoleMatrixElementNu(obj,s.F(ii),s.MF(ii),s.F(jj),s.MF(jj),q);
                end
            end
            % Sigma = sparse(Sigma);
            Sigma = U'*Sigma*U;
        end
        
        function rabi = ReducedRabiFrequency(obj,laser)
            % Reduced Rabi frequency for linearly polarized light.
            %
            % .. math::
            %
            %    \Omega = -\sqrt{\frac{I}{2 I_{\mathrm{sat}}^{(\mathrm{red})}}}\, \Gamma
            %
            % :param laser: Driving field
            % :type laser: :class:`Laser`
            % :return: :math:`\Omega` [Hz]
            % :rtype: double
            arguments
                obj TwoJManifold
                laser Laser
            end
            Isat = obj.ReducedSaturationIntensity;
            gamma = obj.NaturalLinewidth;
            rabi =  - sqrt(laser.Intensity / Isat / 2) * gamma;
        end

        function Ha = HamiltonianAtom(obj,fRot,U)
            % Diagonal Hamiltonian with rotating-frame shift on excited states.
            %
            % .. math::
            %
            %    H_a = U^\dagger \, \operatorname{diag}\big(E - f_\mathrm{rot}\,\chi_\mathrm{exc}\big) \, U
            %
            % :param fRot: Rotating-frame frequency [Hz]
            % :type fRot: double, optional
            % :param U: Basis transform
            % :type U: double, optional
            % :return: Hamiltonian matrix [Hz]
            % :rtype: double
            arguments
                obj TwoJManifold
                fRot double = 0
                U double = 1
            end
            s = obj.StateList;
            s(s.IsExcited,:).Energy = s(s.IsExcited,:).Energy - fRot;
            Ha = diag(s.Energy);
            % Ha = sparse(Ha);
            Ha = U'*Ha*U;
            Ha = (Ha' + Ha)/2;
        end

        function Hal = HamiltonianAtomLaser(obj,laser,fRot,U)
            % Atom-light interaction Hamiltonian :math:`H_\mathrm{AL}(t)`.
            %
            % .. math::
            %
            %    H_{\mathrm{AL}}(t) = \sum_{q=-1}^{+1} \frac{\Omega^*}{2}\, e_q\, \Sigma_q\, e^{i\Delta t} + \mathrm{h.c.}
            %
            % :param laser: Driving field
            % :type laser: :class:`Laser`
            % :param fRot: Rotating-frame frequency [Hz]
            % :type fRot: double, optional
            % :param U: Basis transform
            % :type U: double, optional
            % :return: Function handle H(r,t) [Hz]
            % :rtype: function_handle
            arguments
                obj TwoJManifold
                laser Laser
                fRot double = 0
                U double = 1
            end
            pol = laser.Polarization;
            OmegaLinear = obj.ReducedRabiFrequency(laser);
            spacePhase = laser.spacePhaseFunc;
            Delta = 2*pi*(laser.Frequency - fRot);
            hal = zeros(obj.NNState);
            for q = 1:-1:-1
                hal = hal + conj(OmegaLinear)/2 * sphericalBasisComponent(pol,q) * obj.LoweringOperator(q,U);
            end
            % hal = sparse(hal);
            Hal = @(r,t) halFunc(r,t);
            function h = halFunc(r,t)
                h = hal*exp(1i*Delta*t)*spacePhase(r);
                h = h + h';
            end
        end
        function Ham = HamiltonianAtomBiasField(obj,B,U)
            % Zeeman Hamiltonian from :class:`OneJManifold` blocks.
            %
            % .. math::
            %
            %    H_Z = U^\dagger \, \mathrm{blkdiag}\big(H_Z^{(e)}, H_Z^{(g)}\big) \, U
            %
            % where each block uses :math:`H_Z = \mu_B ( g_J \mathbf{J} + g_I \mathbf{I} )\cdot\mathbf{B} / h`.
            %
            % :param B: Magnetic field object
            % :type B: :class:`MagneticField`
            % :param U: Basis transform
            % :type U: double, optional
            % :return: Hamiltonian matrix [Hz]
            % :rtype: double
             arguments
                obj TwoJManifold
                B MagneticField
                U double = 1
             end
            maniG = OneJManifold(obj.Atom,obj.NGround,obj.LGround,obj.JGround);
            maniE = OneJManifold(obj.Atom,obj.NExcited,obj.LExcited,obj.JExcited);
            HamG = maniG.HamiltonianAtomBiasField(B);
            HamE = maniE.HamiltonianAtomBiasField(B);
            Ham = blkdiag(HamE,HamG);
            Ham = U'*Ham*U;
            Ham = (Ham + Ham')/2;
        end
        function [dressedStateList,U,brMap] = BiasDressedStateList(obj,B,isPlot,options)
            % Compute dressed states versus bias field and assemble blocks.
            %
            % :param B: Magnetic field
            % :type B: :class:`MagneticField`
            % :param isPlot: Plot results
            % :type isPlot: logical, optional
            % :param samplingSize: Number of bias samples
            % :type samplingSize: double, optional
            % :return: Dressed state table, unitary U, and branch map
            % :rtype: table, double, cell
            arguments
                obj TwoJManifold
                B MagneticField
                isPlot logical = false
                options.samplingSize double = []
            end

            sList = obj.StateList;
            maniG = OneJManifold(obj.Atom,obj.NGround,obj.LGround,obj.JGround);
            maniE = OneJManifold(obj.Atom,obj.NExcited,obj.LExcited,obj.JExcited);
            if ~isempty(options.samplingSize)
                samplingSize = options.samplingSize;
            else
                energy = sList.Energy;
                gF = max(abs(sList.gF));
                energyGap = min(abs(diff(sort(energy))));
                dEdB = gF * Constants.SI("muB") / Constants.SI("hbar") / 2 / pi;
                dB = energyGap / dEdB;
                samplingSize = max(round(B.Bias(3)/ dB *20),1000);
                samplingSize = min(samplingSize,5000);
            end
            
            [sListG,~,brMapG] = maniG.BiasDressedStateList(B,samplingSize = samplingSize);
            [sListE,~,brMapE] = maniE.BiasDressedStateList(B,samplingSize = samplingSize);
            brMap = {brMapG{1},[brMapE{2};brMapG{2}]};

            sListG.Index = sListG.Index + numel(obj.MJExcited);
            sListE.Energy = sListE.Energy + obj.Frequency;
            dressedStateList = [sListE;sListG];
            
            dressedStateList.IsExcited = sList.IsExcited;
            nExcited = sum(sList.IsExcited);
            nGround = sum(~sList.IsExcited);
            dressedStateList.Label = sList.Label;
            for ii = 1:obj.NNState
                if dressedStateList(dressedStateList.Index==ii,:).IsExcited
                    dressedStateList(dressedStateList.Index==ii,:).DressedState{1} = ...
                        [dressedStateList(dressedStateList.Index==ii,:).DressedState{1};zeros(nGround,1)];
                else
                    dressedStateList(dressedStateList.Index==ii,:).DressedState{1} = ...
                        [zeros(nExcited,1);dressedStateList(dressedStateList.Index==ii,:).DressedState{1}];
                end
            end
            U = dressedStateList.DressedState;
            U = horzcat(U{:}); %Unitary operator the connect to the dressed states

            if isPlot
                close(figure(2034))
                figure(2034)
                plot(brMap{1}*1e4,brMap{2}*1e-6)
                xlabel('Bias field [Gauss]',Interpreter='latex')
                ylabel('Energy [MHz]',Interpreter='latex')
                legend(sList.Label(:),'interpreter','latex')
                render
            end
        end

        function mimjList = getMIMJ(obj)
            % Compute :math:`(M_I,M_J)` labels by adiabatic mapping.
            %
            % :return: Table of MI, MJ per basis state
            % :rtype: table
            arguments
                obj TwoJManifold
                % isPlot logical = false
            end
            maniG = OneJManifold(obj.Atom,obj.NGround,obj.LGround,obj.JGround);
            maniE = OneJManifold(obj.Atom,obj.NExcited,obj.LExcited,obj.JExcited);
            mimjListG = maniG.getMIMJ;
            mimjListE = maniE.getMIMJ;
            mimjList = [mimjListE;mimjListG];
            
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

        end
    end
end

