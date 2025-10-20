classdef (Abstract) AtomManifold < matlab.mixin.Heterogeneous
    %TRANSITION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        Atom Atom
        NNState int32 %Total number of states
        Frequency double %The center of gravity transition frequency.
    end

    properties (Dependent)
        Wavelength double
        AngularWavenumber double
        RecoilMomentum double
        RecoilVelocity double
        RecoilEnergy double
        RecoilTemperature double % in K
    end

    properties (Constant,Hidden)
        DipoleUnit = Constants.SI("a0")*Constants.SI("e") % For converting ARC output to SI unit
    end
    
    methods
        function obj = AtomManifold(atom)
            %TRANSITION Construct an instance of this class
            %   Detailed explanation goes here
            obj.Atom = atom;
        end

        function lambda0 = get.Wavelength(obj)
            lambda0 = Constants.SI("c")./obj.Frequency;
        end
        function k0 = get.AngularWavenumber(obj)
            k0 = 2*pi./obj.Wavelength;
        end
        function pr = get.RecoilMomentum(obj)
            pr = Constants.SI("hbar")*obj.AngularWavenumber;
        end
        function vr = get.RecoilVelocity(obj)
            vr = obj.RecoilMomentum./obj.Atom.mass;
        end
        function er = get.RecoilEnergy(obj)
            er = 1/2*obj.Atom.mass*((obj.RecoilVelocity).^2) ./ Constants.SI("hbar")/2/pi;
        end
        function tr = get.RecoilTemperature(obj)
            tr = 2*obj.RecoilEnergy.*Constants.SI("hbar")*2*pi./Constants.SI("kB"); %Notice the factor of 2
        end
    end
end

