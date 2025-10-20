classdef TwoJManifold < AtomManifold
    %TWOJ Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        NGround int32
        LGround int32
        JGround double
        FGround double
        MFGround double
        HFSCoefficientGround %[A,B]
        EnergyGround double
        LandegJGround double
        LandegFGround double
        NExcited int32
        LExcited int32
        JExcited double
        FExcited double
        MFExcited double
        HFSCoefficientExcited %[A,B]
        EnergyExcited double
        LandegJExcited double
        LandegFExcited double
        StateList table
        JOperator cell
        IOperator cell
        FOperator cell
        NaturalLinewidth double %One should keep in mind that there is no 2pi for consistency. e.g. for Lithium7 it is 5.8724e6 Hz
        LifetimeExcited double
        ReducedDipoleMatrixElement double %Following steck's convention as <Jg||d||Je>, in SI unit.
        ReducedSaturationIntensity double %In SI unit
        ReducedSaturationIntensityLu double %In lab unit. mW/cm^2
        DopplerTemperature double
    end
    
    methods
        function obj = TwoJManifold(atom,nG,lG,jG,nE,lE,jE)
            %TWOJ Construct an instance of this class
            %   Detailed explanation goes here

            %% Set quantum numbers N,L,J
            obj@AtomManifold(atom)
            obj.NGround = nG;
            obj.LGround = lG;
            obj.JGround = jG;
            obj.NExcited = nE;
            obj.LExcited = lE;
            obj.JExcited = jE;
            
            %% Ground and excited manifold
            maniG = OneJManifold(atom,nG,lG,jG);
            maniE = OneJManifold(atom,nE,lE,jE);

            %% Set quantum numbers F,MF
            obj.FGround = maniG.F;
            obj.FExcited = maniE.F;
            obj.MFGround = maniG.MF;
            obj.MFExcited = maniE.MF;

            %% Set energies and frequencies, in Hz
            obj.Frequency = ...
                atom.ArcObj.getTransitionFrequency(...
                obj.NGround,...
                obj.LGround,...
                obj.JGround,...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited);
            obj.HFSCoefficientGround = maniG.HFSCoefficient;
            obj.HFSCoefficientExcited = maniE.HFSCoefficient;
            obj.EnergyGround = maniG.Energy;
            obj.EnergyExcited = maniE.Energy + obj.Frequency;
            
            %% Set magnetic properties
            obj.LandegJGround = maniG.LandegJ;
            obj.LandegJExcited = maniE.LandegJ;
            obj.LandegFGround = maniG.LandegF;
            obj.LandegFExcited = maniE.LandegF;

            %% Set operators
            JG = maniG.JOperator;
            IG = maniG.IOperator;
            FG = maniG.FOperator;
            JE = maniE.JOperator;
            IE = maniE.IOperator;
            FE = maniE.FOperator; 

            obj.JOperator = arrayfun(@(r) blkdiag(JE{r,:},JG{r,:}),(1:3)',UniformOutput=false);
            obj.IOperator = arrayfun(@(r) blkdiag(IE{r,:},IG{r,:}),(1:3)',UniformOutput=false);
            obj.FOperator = arrayfun(@(r) blkdiag(FE{r,:},FG{r,:}),(1:3)',UniformOutput=false);
            

            %% Set state list
            obj.NNState = numel(obj.MFGround) + numel(obj.MFExcited);
            Index = 1:obj.NNState;
            N = [repmat(obj.NExcited,1,numel(obj.MFExcited)),repmat(obj.NGround,1,numel(obj.MFGround))];
            L = [repmat(obj.LExcited,1,numel(obj.MFExcited)),repmat(obj.LGround,1,numel(obj.MFGround))];
            J = [repmat(obj.JExcited,1,numel(obj.MFExcited)),repmat(obj.JGround,1,numel(obj.MFGround))];
            F = angularMomentumList([obj.FExcited,obj.FGround]);
            MF = [obj.MFExcited,obj.MFGround];
            gI = repmat(obj.Atom.gI,1,obj.NNState);
            gJ = [repmat(obj.LandegJExcited,1,numel(obj.MFExcited)),repmat(obj.LandegJGround,1,numel(obj.MFGround))];
            
            

            IsExcited = zeros(1,obj.NNState);
            IsExcited(1:numel(obj.MFExcited)) = 1;
            IsExcited = logical(IsExcited);

            f = [obj.FExcited,obj.FGround];
            energy = [obj.EnergyExcited,obj.EnergyGround];
            gf = [obj.LandegFExcited,obj.LandegFGround];
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
                if IsExcited(ii)
                    Label{ii} = "$F'=" + num2str(F(ii)) + ",M'_F = " + num2str(MF(ii)) + "$";
                else
                    Label{ii} = "$F=" + num2str(F(ii)) + ",M_F = " + num2str(MF(ii)) + "$";
                end
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
            IsExcited = IsExcited(:);
            MI = [maniE.StateList.MI;maniG.StateList.MI];
            MJ = [maniE.StateList.MJ;maniG.StateList.MJ];
            obj.StateList = table(Index,N,L,J,F,MF,MI,MJ,gI,gJ,gF,Energy,IsExcited,Label);

            %% Set dipole transition properties
            obj.LifetimeExcited = obj.Atom.ArcObj.getStateLifetime(...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited...
                );
            obj.NaturalLinewidth = obj.Atom.ArcObj.getTransitionRate(...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited,...
                obj.NGround,...
                obj.LGround,...
                obj.JGround)/2/pi;
            obj.ReducedDipoleMatrixElement = obj.Atom.ArcObj.getReducedMatrixElementJ_asymmetric(...
                obj.NGround,...
                obj.LGround,...
                obj.JGround,...
                obj.NExcited,...
                obj.LExcited,...
                obj.JExcited) * obj.DipoleUnit;
            obj.ReducedSaturationIntensity = ...
                Constants.SI("hbar")^2 * ...
                (2 * pi * obj.NaturalLinewidth)^2 / 4 /...
                Constants.SI("Z0") /...
                (obj.ReducedDipoleMatrixElement)^2;
            obj.ReducedSaturationIntensityLu = obj.ReducedSaturationIntensity / 10;
            obj.DopplerTemperature = Constants.SI("hbar") * obj.NaturalLinewidth * 2 * pi / 2 / Constants.SI("kB");
        end
        
        function DME = DipoleMatrixElement(obj,fG,mfG,fE,mfE,q,U)
            % Dipole Matrix element <fG,mfG|dq|fE,mfE>, in SI unit. The
            % sign of q is reversed to accomodate to Steck's convention.
            % Now the selection rule should be mfE + q = mfG.
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
            % Dipole Matrix element <fG,mfG|dq|fE,mfE>, as multiples of the
            % ReducedDipoleMatrixElement. Same numbers as in Steck's Alkali
            % D line Data.
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
            %See Steck Eq. (7.407)
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
            arguments
                obj TwoJManifold
                laser Laser
            end
            Isat = obj.ReducedSaturationIntensity;
            gamma = obj.NaturalLinewidth;
            rabi =  - sqrt(laser.Intensity / Isat / 2) * gamma;
        end

        function Ha = HamiltonianAtom(obj,fRot,U)
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
            % In Hz
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

            sListG.Index = sListG.Index + numel(obj.MFExcited);
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

