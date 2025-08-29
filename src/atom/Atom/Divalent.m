classdef Divalent < Atom
    %:class:`Divalent` atom subclass with cycling transition properties.
    %
    % Adds a blue transition manifold, cycler frequency, saturation intensity,
    % cross-section, and derived quantities from ARC.
    properties(SetAccess=protected)
        Blue TwoJManifoldDivalent
        CyclerFrequency double
        CyclerSaturationIntensity double
        CyclerCrossSection double
    end

    methods
        function obj = Divalent(atomName)
            % Construct a :class:`Divalent` atom.
            %
            % :param atomName: Isotope name known to ARC (e.g., "Strontium88")
            % :type atomName: string
            obj@Atom(atomName)
            if obj.Type ~= "Divalent"
                error("Wrong input [atomName]. [atomName] must be an divalent atom")
            end
            nG = obj.groundStateN();
            obj.Blue = TwoJManifoldDivalent(obj,nG,0,0,0,nG,1,1,0);
            obj.CyclerFrequency = obj.Blue.Frequency;
            obj.CyclerSaturationIntensity = pi * Constants.SI("hbar") * 2 * pi * Constants.SI("c") / ...
                3 / (Constants.SI("c")/obj.CyclerFrequency)^3 / (1/obj.Blue.NaturalLinewidth/2/pi);
            obj.CyclerCrossSection = ...
                Constants.SI("hbar") * (2*pi*obj.CyclerFrequency) *...
                (obj.Blue.NaturalLinewidth * 2 * pi) / 2 / obj.CyclerSaturationIntensity; 
        end
    end
end

