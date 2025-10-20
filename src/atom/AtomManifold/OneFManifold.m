classdef OneFManifold < AtomManifold
    %TWOJ Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        N int32
        L int32
        J double
        F double
        MF double
        Energy double
        LandegJ double
        LandegF double
        StateList table
        FOperator
    end
    
    methods
        function obj = OneFManifold(atom,n,l,j,f)
            %TWOJ Construct an instance of this class
            %   Detailed explanation goes here

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

