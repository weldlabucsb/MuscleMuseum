classdef Divalent < Atom
    %:class:`Divalent` atom subclass with blue cycling transition properties.
    %
    % Adds the blue transition manifold and derives frequency, saturation intensity,
    % and resonant cross-section from ARC/manifold data.
    properties(SetAccess=protected)
        Blue TwoJManifoldDivalent % Blue cycling transition manifold
        CyclerFrequency double % Cycling transition frequency [Hz]
        CyclerSaturationIntensity double % Saturation intensity [W/m^2]
        CyclerCrossSection double % Resonant cross-section [m^2]
    end

    methods
        function obj = Divalent(atomName)
            % Construct a :class:`Divalent` atom.
            %
            % :param atomName: Isotope name (ARC-known), e.g., "Strontium88"
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

