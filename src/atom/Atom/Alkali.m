classdef Alkali < Atom
    %:class:`Alkali` deals with Alkali atoms' data and calculations. When
    %constructed, it calculates some :class:`AtomManifold` and transition
    %properties, e.g. D1, D2 structures, Cycling and repumping transition
    %prameters.
    
    properties(SetAccess=protected)
        D1 TwoJManifold % Alkali D1 manifold: :math:`(L=0,J=1/2) \leftrightarrow (L=1,J=1/2)`.
        D2 TwoJManifold % Alkali D2 manifold: :math:`(L=0,J=1/2) \leftrightarrow (L=1,J=3/2)`.
        DGround OneJManifold % Alkali D line ground manifold: :math:`(L=0,J=1/2)`.
        D1Excited OneJManifold % Alkali D1 excited manifold: :math:`(L=1,J=1/2)`.
        D2Excited OneJManifold % Alkali D2 excited manifold: :math:`(L=1,J=3/2)`.
        Spinor1 OneFManifold % Alkali first ground F manifold: :math:`L=0,J=1/2,F=min{|I-J|,|I+J|}`.
        Spinor2 OneFManifold % Alkali second ground F manifold: :math:`L=0,J=1/2,F=max{|I-J|,|I+J|}`.
        CyclerFrequency double % Cycling transition frequency at zero field, in Hz.
        CyclerSaturationIntensity double % Cycling transition saturation intensity, in W/m^2.
        CyclerSaturationIntensityLu double % Cycling transition saturation intensity, in mW/cm^2.
        CyclerCrossSection double % Cycling transition resonant cross section, in m^2.
        RepumperFrequency double % Repump transition frequency at zero field, in Hz.
        RepumperSaturationIntensity double % Repump transition saturation intensity, in W/m^2. Assume the repumper also has sigma+ polarization.
        RepumperSaturationIntensityLu double % Repump transition saturation intensity, in mW/cm^2.
        RepumperCrossSection double % Repump transition resonant cross section, in m^2.
        % ScalarPolarizabilityGroundFarDetuned %Alkali D line ground state scalar polarizability, in Hz/(V/m)^2.
    end
    
    methods
        function obj = Alkali(atomName)
            %% Set atomic properties
            obj@Atom(atomName)
            if obj.Type ~= "Alkali"
                error("Wrong input. [atomName] must be an alkali atom")
            end

            %% Set transition properties
            nG = obj.groundStateN;
            obj.D1 = TwoJManifold(obj,nG,0,1/2,nG,1,1/2);
            obj.D2 = TwoJManifold(obj,nG,0,1/2,nG,1,3/2);
            obj.DGround = OneJManifold(obj,nG,0,1/2);
            obj.D1Excited = OneJManifold(obj,nG,1,1/2);
            obj.D2Excited = OneJManifold(obj,nG,1,3/2);
            FGround = totalAngularMomentum(1/2,obj.I);
            obj.Spinor1 = OneFManifold(obj,nG,0,1/2,min(FGround));
            obj.Spinor2 = OneFManifold(obj,nG,0,1/2,max(FGround));

            %% Set cycler and repumper properties
            fG = obj.D2.FGround;
            fE = obj.D2.FExcited;
            eG = obj.D2.EnergyGround;
            eE = obj.D2.EnergyExcited;
            obj.CyclerFrequency = eE(fE==max(fE)) - eG(fG==max(fG));
            obj.RepumperFrequency = eE(fE==(max(fE)-1)) - eG(fG==(max(fG)-1));
            obj.CyclerSaturationIntensity = obj.D2.SaturationIntensity(max(fG),max(fG),max(fE),max(fE));
            obj.CyclerSaturationIntensityLu = obj.CyclerSaturationIntensity / 10;
            obj.CyclerCrossSection = ...
                Constants.SI("hbar") * (2*pi*obj.CyclerFrequency) *...
                (obj.D2.NaturalLinewidth * 2 * pi) / 2 / obj.CyclerSaturationIntensity;
            obj.RepumperSaturationIntensity = obj.D2.SaturationIntensity(max(fG)-1,max(fG)-1,max(fE)-1,max(fE)-1);
            obj.RepumperSaturationIntensityLu = obj.RepumperSaturationIntensity / 10;
            obj.RepumperCrossSection = ...
                Constants.SI("hbar") * (2*pi*obj.RepumperFrequency) *...
                (obj.D2.NaturalLinewidth * 2 * pi) / 2 / obj.RepumperSaturationIntensity;

            % %% Set polarizability properties
            % obj.ScalarPolarizabilityGroundFarDetuned

        end

    end

end

