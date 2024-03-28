classdef OpticalLattice < OpticalPotential
    %OPTICALLATTICE Summary of this class goes here
    %   Detailed explanation goes here

    properties
        DepthKd
        DepthSpec
        RadialFrequencySlosh
    end

    properties (Dependent)
        LatticeSpacing % in meters
        DepthLaser % in Hz, calculated from laser power and waists
        AxialFrequencyLaser % in Hz, linear frequency, calculated from laser power and waists
        AxialFrequencyKd % in Hz, linear frequency, calculated from KD depth
        AxialFrequencySpec % in Hz, linear frequency, calculated from spectrum depth
        RadialFrequencyLaser % in Hz, linear frequency, calculated from laser power and waists
        RadialFrequencyKd % in Hz, linear frequency, calculated from KD depth
        RadialFrequencySpec % in Hz, linear frequency, calculated from spectrum depth
        Depth % in Hz, best value
        DepthLu % in Er, best value
        AxialFrequency % in Hz, best value
        RadialFrequency % in Hz, best value
    end

    methods
        function obj = OpticalLattice(atom,laser,name,options)
            %OPTICALLATTICE Construct an instance of this class
            %   Detailed explanation goes here
            arguments
                atom (1,1) Atom
                laser Laser
                name string = string.empty
                options.manifold string = "DGround"
                options.stateIndex double = []
            end
            obj@OpticalPotential(atom,laser,name);
            obj.Manifold = options.manifold;
            if ~isempty(options.stateIndex)
                obj.StateIndex = options.stateIndex;
            else
                % By default, pick the lowest magnetic trappable state
                obj.StateIndex = atom.(obj.Manifold).StateList.Index(end);
            end
        end

        function a0 = get.LatticeSpacing(obj)
            a0 = obj.Laser.Wavelength / 2;
        end

        function v0 = get.DepthLaser(obj)
            v0 =  4 * abs(obj.ScalarPolarizabilityGround * abs(obj.Laser.ElectricFieldAmplitude)^2 / 4);
        end

        function fZ = get.AxialFrequencyLaser(obj)
            fZ = obj.computeAxialFrequency(obj.DepthLaser);
        end

        function fZ = get.AxialFrequencyKd(obj)
            fZ = obj.computeAxialFrequency(obj.DepthKd);
        end

        function fZ = get.AxialFrequencySpec(obj)
            fZ = obj.computeAxialFrequency(obj.DepthSpec);
        end

        function fRho = get.RadialFrequencyLaser(obj)
            fRho = obj.computeRadialFrequency(obj.DepthLaser);
        end

        function fRho = get.RadialFrequencyKd(obj)
            fRho = obj.computeRadialFrequency(obj.DepthKd);
        end

        function fRho = get.RadialFrequencySpec(obj)
            fRho = obj.computeRadialFrequency(obj.DepthSpec);
        end

        function fZ = computeAxialFrequency(obj,depth)
            lambda = obj.Laser.Wavelength;
            m = obj.Atom.mass;
            v0 =  2 * pi * Constants.SI("hbar") * depth;
            fZ = sqrt(v0 / m / lambda^2);
        end

        function fRho = computeRadialFrequency(obj,depth)
            if class(obj.Laser) == "GaussianBeam"
                w0 = sqrt(prod(obj.Laser.Waist));
                m = obj.Atom.mass;
                v0 = 2 * pi * Constants.SI("hbar") * depth;
                fRho = sqrt(4 * v0 / m / w0^2) / 2 / pi;
            else
                fRho = NaN;
            end
        end

        function v0 = get.Depth(obj)
            if ~isempty(obj.DepthSpec)
                v0 = obj.DepthSpec;
            elseif ~isempty(obj.DepthKd)
                v0 = obj.DepthKd;
            else
                v0 = obj.DepthLaser;
            end
        end

        function v0 = get.DepthLu(obj)
            v0 = obj.Depth/obj.RecoilEnergy;
        end
        
        function fZ = get.AxialFrequency(obj)
            if ~isempty(obj.DepthSpec)
                fZ = obj.AxialFrequencySpec;
            elseif ~isempty(obj.DepthKd)
                fZ = obj.AxialFrequencyKd;
            else
                fZ = obj.AxialFrequencyLaser;
            end
        end

        function fRho = get.RadialFrequency(obj)
            if ~isempty(obj.RadialFrequencySlosh)
                fRho = obj.RadialFrequencySlosh;
            elseif ~isempty(obj.DepthSpec)
                fRho = obj.RadialFrequencySpec;
            elseif ~isempty(obj.DepthKd)
                fRho = obj.RadialFrequencyKd;
            else
                fRho = obj.RadialFrequencyLaser;
            end
        end

        function func = spaceFunc(obj)
            V0 = obj.Depth;
            k = obj.Laser.AngularWavevector.';
            k0 = norm(k);
            kHat = k ./ k0;
            if class(obj.Laser) == "GaussianBeam"
                w0 = sqrt(prod(obj.Laser.Waist));
                zR = obj.Laser.RayleighRange;
                func = @(r) V(r);
            else
                func = @(r) -V0 .* (cos(k * r)).^2;
            end
            function Vout = V(r)
                z = kHat * r;
                r2 = vecnorm(r - kHat.' * z).^2;
                wz = w0 * sqrt(1 + (z./zR).^2);
                Vout = -V0 .* (w0./wz).^2 .* exp(-2 .* r2 ./ wz.^2) .* ...
                    cos(k0 * z .* (1 + 1/2 * r2 ./ zR^2 .* w0^2 ./ wz.^2)).^2;
            end
        end

        function updateIntensity(obj)
            v0 = obj.Depth;
            alpha = obj.ScalarPolarizabilityGround;
            obj.Laser.Intensity = abs(v0 / alpha) / 2 / Constants.SI("Z0");
        end

        [E,u] = computeBand1D(obj,q,n,x)
        plotBand1D(obj,n)
        pop = computeBandPopulation1D(obj,psi,x,n)
        freq = computeTransitionFrequency1D(obj,n1,n2,q)
    end
end

