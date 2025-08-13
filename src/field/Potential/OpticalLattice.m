classdef OpticalLattice < OpticalPotential
    %:class:`OpticalLattice` models 1D optical lattice band structure and couplings.
    %
    % Provides band energies and states via :attr:`BandEnergy`, :attr:`BlochState`,
    % :attr:`BlochStateFourier`, :attr:`BlochStatePeriodic`, Berry connection
    % :attr:`BerryConnection`, amplitude-modulation couplings :attr:`AmpModCoupling`, and
    % frequency scalings (:attr:`AxialFrequency`, :attr:`RadialFrequency`) derived from the
    % :class:`Laser` and :class:`Atom` parameters. Quasi-
    % momentum :math:`q` is in [1/m], lattice spacing :math:`a=\lambda/2` in [m], and
    % wavevector :math:`\mathbf{k}` in [rad/m].
    %
    properties
        DepthKd % Lattice depth from Kapitza–Dirac calibration :math:`V_0` in [Hz]
        DepthSpec % Lattice depth from spectroscopy :math:`V_0` in [Hz]
        RadialFrequencySlosh % Measured radial slosh frequency :math:`f_\rho` in [Hz]
    end

    properties (SetAccess = protected)
        SpaceList % Spatial sampling list :math:`x` or grid specification (implementation-dependent)
        QuasiMomentumList % Quasi-momentum sampling :math:`q` in [1/m]
        BandIndexMax % Maximum band index included (largest :math:`n` requested)
        BandIndexMaxFourier = 101 % Plane-wave cutoff (odd) : number of Fourier components :math:`n_{\mathrm{max}}`
        BandEnergy % Cached band energies :math:`E_n(q)` in [Hz]; size ~ (nBands x n_q)
        BlochState % Cached Bloch states :math:`\phi_{n,q}(x)` (functions or arrays)
        BlochStateFourier % Cached plane-wave coefficients :math:`F_{j n}(q)`; size ~ (n_max x nBands x n_q)
        BlochStatePeriodic % Cached periodic part :math:`u_{n,q}(x)` (functions or arrays)
        BerryConnection % Cached Berry connection :math:`\mathcal{A}_{mn}(q)`; size ~ (nBands x nBands x n_q)
        AmpMod % Cached amplitude-modulation response (implementation-dependent)
        AmpModCoupling % Cached amplitude-modulation coupling :math:`A_{mn}(q)`; size ~ (nBands x nBands x n_q)
    end

    properties (Constant)
        BandIndexMaxFourierDefault = 101 % Default plane-wave cutoff :math:`n_{\mathrm{max}}` (odd)
        % BandIndexMaxFourierDefault = 54
    end

    properties (Dependent)
        LatticeSpacing % Lattice spacing :math:`a=\lambda/2` in [m]
        DepthLaser % Depth from laser intensity :math:`V_0` in [Hz]
        AxialFrequencyLaser % Axial frequency :math:`f_z` in [Hz] from laser-derived depth
        AxialFrequencyKd % Axial frequency :math:`f_z` in [Hz] from KD depth
        AxialFrequencySpec % Axial frequency :math:`f_z` in [Hz] from spectroscopic depth
        RadialFrequencyLaser % Radial frequency :math:`f_\rho` in [Hz] from laser-derived depth
        RadialFrequencyKd % Radial frequency :math:`f_\rho` in [Hz] from KD depth
        RadialFrequencySpec % Radial frequency :math:`f_\rho` in [Hz] from spectroscopic depth
        Depth % Best-available depth :math:`V_0` in [Hz]
        DepthLu % Dimensionless depth :math:`V_0/E_r` (in recoil units)
        AxialFrequency % Best-available :math:`f_z` in [Hz]
        RadialFrequency % Best-available :math:`f_\rho` in [Hz]
    end

    methods
        function obj = OpticalLattice(atom,laser,name,options)
            %:class:`OpticalLattice` constructor.
            %
            % :param atom: Atomic species and structure data
            % :type atom: :class:`Atom`
            % :param laser: Lattice-forming laser/beam
            % :type laser: :class:`Laser`
            % :param name: Identifier for this lattice
            % :type name: string, optional
            % :param manifold: Hyperfine manifold used for polarizability calculations
            % :type manifold: string, optional
            % :param stateIndex: Sublevel index within the chosen manifold
            % :type stateIndex: double, optional
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
            % Lattice spacing :math:`a = \lambda/2`.
            %
            % :return: :math:`a` in [m]
            % :rtype: double
            a0 = obj.Laser.Wavelength / 2;
        end

        function v0 = get.DepthLaser(obj)
            % Lattice depth from laser intensity :math:`V_0 = |\alpha_0 E^2|` (convention).
            %
            % :return: Depth :math:`V_0` in [Hz]
            % :rtype: double
            v0 =  4 * abs(obj.ScalarPolarizabilityGround * abs(obj.Laser.ElectricFieldAmplitude)^2 / 4);
        end

        function fZ = get.AxialFrequencyLaser(obj)
            % Axial frequency from laser-derived depth.
            %
            % :return: :math:`f_z` in [Hz]
            % :rtype: double
            fZ = obj.computeAxialFrequency(obj.DepthLaser);
        end

        function fZ = get.AxialFrequencyKd(obj)
            % Axial frequency from Kapitza-Dirac-derived depth.
            %
            % :return: :math:`f_z` in [Hz]
            % :rtype: double
            fZ = obj.computeAxialFrequency(obj.DepthKd);
        end

        function fZ = get.AxialFrequencySpec(obj)
            % Axial frequency from spectroscopic depth.
            %
            % :return: :math:`f_z` in [Hz]
            % :rtype: double
            fZ = obj.computeAxialFrequency(obj.DepthSpec);
        end

        function fRho = get.RadialFrequencyLaser(obj)
            % Radial frequency from laser-derived depth.
            %
            % :return: :math:`f_\rho` in [Hz]
            % :rtype: double
            fRho = obj.computeRadialFrequency(obj.DepthLaser);
        end

        function fRho = get.RadialFrequencyKd(obj)
            % Radial frequency from Kapitza-Dirac-derived depth.
            %
            % :return: :math:`f_\rho` in [Hz]
            % :rtype: double
            fRho = obj.computeRadialFrequency(obj.DepthKd);
        end

        function fRho = get.RadialFrequencySpec(obj)
            % Radial frequency from spectroscopic depth.
            %
            % :return: :math:`f_\rho` in [Hz]
            % :rtype: double
            fRho = obj.computeRadialFrequency(obj.DepthSpec);
        end

        function v0 = get.Depth(obj)
            % Best-available lattice depth.
            %
            % :return: Depth :math:`V_0` in [Hz]
            % :rtype: double
            if ~isempty(obj.DepthSpec)
                v0 = obj.DepthSpec;
            elseif ~isempty(obj.DepthKd)
                v0 = obj.DepthKd;
            else
                v0 = obj.DepthLaser;
            end
        end

        function v0 = get.DepthLu(obj)
            % Dimensionless depth (recoil units).
            %
            % :return: :math:`V_0 / E_r`
            % :rtype: double
            v0 = obj.Depth/obj.RecoilEnergy;
        end

        function fZ = get.AxialFrequency(obj)
            % Best-available axial frequency.
            %
            % :return: :math:`f_z` in [Hz]
            % :rtype: double
            if ~isempty(obj.DepthSpec)
                fZ = obj.AxialFrequencySpec;
            elseif ~isempty(obj.DepthKd)
                fZ = obj.AxialFrequencyKd;
            else
                fZ = obj.AxialFrequencyLaser;
            end
        end

        function fRho = get.RadialFrequency(obj)
            % Best-available radial frequency.
            %
            % :return: :math:`f_\rho` in [Hz]
            % :rtype: double
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

    end

    methods

        function fZ = computeAxialFrequency(obj,depth)
            % Compute axial frequency :math:`f_z = \sqrt{V_0/(m\,\lambda^2)}` up to constants.
            %
            % :param depth: Lattice depth :math:`V_0` in [Hz]
            % :type depth: double
            % :return: :math:`f_z` in [Hz]
            % :rtype: double
            lambda = obj.Laser.Wavelength;
            m = obj.Atom.mass;
            v0 =  2 * pi * Constants.SI("hbar") * depth;
            fZ = sqrt(v0 / m / lambda^2);
        end

        function fRho = computeRadialFrequency(obj,depth)
            % Compute radial frequency :math:`f_\rho = \frac{1}{2\pi}\sqrt{4 V_0/(m w_0^2)}` for Gaussian beam.
            %
            % :param depth: Lattice depth :math:`V_0` in [Hz]
            % :type depth: double
            % :return: :math:`f_\rho` in [Hz]
            % :rtype: double
            if class(obj.Laser) == "GaussianBeam"
                w0 = sqrt(prod(obj.Laser.Waist));
                m = obj.Atom.mass;
                v0 = 2 * pi * Constants.SI("hbar") * depth;
                fRho = sqrt(4 * v0 / m / w0^2) / 2 / pi;
            else
                fRho = NaN;
            end
        end

        function func = spaceFunc(obj)
            % Build lattice potential :math:`V(\mathbf{r})` for 1D standing wave or Gaussian.
            %
            % :return: function handle mapping :math:`\mathbf{r}` to :math:`V(\mathbf{r})` [Hz]
            % :rtype: function_handle
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
            % Set laser intensity to achieve target depth :math:`V_0`.
            obj.Laser.Intensity = abs(obj.Depth / obj.ScalarPolarizabilityGround) / 2 / Constants.SI("Z0");
        end

        function [E,Fjn,phi,u] = computeBand1D(obj,q,n,x,options)
            % Compute 1D Bloch bands and states for quasimomentum :math:`q` and band index :math:`n`.
            % 
            % :param q: Quasi-momentum in [1/m] (can be vector)
            % :type q: double
            % :param n: Band indices (0=s,1=p,...) (vector of nonnegative integers)
            % :type n: double
            % :param x: Spatial grid :math:`x` in [m] for real-space wavefunctions (optional)
            % :type x: double, optional
            % :param nMax: Plane-wave cutoff (odd) overriding default
            % :type nMax: double, optional
            % :return: Band energies :math:`E_n(q)` in [Hz]
            % :rtype: double array (length(n) x length(q))
            % :return: Fourier coefficients :math:`F_{j n}(q)`
            % :rtype: double array (nMax x length(n) x length(q))
            % :return: Bloch states :math:`\phi_{n,q}(x)` in real space
            % :rtype: function_handle cell or double array depending on :math:`x`
            % :return: Periodic parts :math:`u_{n,q}(x)` when requested
            % :rtype: function_handle cell or double array
            arguments
                obj OpticalLattice
                q double {mustBeVector} % Sampling quasi-momentum [1/m]
                n double {mustBeVector,mustBeInteger,mustBeNonnegative}
                x double = []
                options.nMax = []
            end
            Er = obj.RecoilEnergy;
            v0 = obj.DepthLu; % Dimensionless lattice depth.
            kL = obj.Laser.AngularWavenumber;
            lambda = 2 * pi / kL;
            q = q / kL; % Dimensionless quasi-momentum.
            n = n + 1; % For easier indexing.
            if isempty(options.nMax)
                nMax = max(2 * max(n)+49,obj.BandIndexMaxFourierDefault); % Band index cutoff (odd)
            else
                nMax = options.nMax;
            end
            [~,qCenterIdx] = min(abs(q));
            j = 1-nMax:2:nMax-1;
            Vmat = -v0/4*gallery('tridiag',nMax,1,2,1);
            E = zeros(nMax,length(q));
            Fjn = zeros(nMax,nMax,length(q));
            for qIdx = 1:length(q)
                Tmat = sparse(1:nMax,1:nMax,(q(qIdx)+j).^2,nMax,nMax);
                [Fjn(:,:,qIdx),tempE] = eig(full(Vmat+Tmat));
                E(:,qIdx) = diag(tempE);
            end
            E = E(n,:) * Er; % in Hz
            Fjn = Fjn * sqrt(2 / lambda); % Normalization

            % Phase convention: continuity along q
            if numel(q) >= 3
                for nIdx = 1:nMax
                    m = sum(abs(diff((squeeze(Fjn(:,nIdx,:))),1,2))>0.1 * sqrt(2 / lambda),1);
                    m(1) = 0;
                    if all(m==0)
                        continue
                    else
                        flipPos = find(m,1);
                        flipPos(abs(flipPos - qCenterIdx) <= 1) = [];
                        if ~isempty(flipPos)
                            Fjn(:,nIdx,flipPos+1:end) = -Fjn(:,nIdx,flipPos+1:end);
                        end
                    end
                end
            end
            Fjn = Fjn(:,n,:);

            if nargout >= 3
                k = (1-nMax:2:nMax-1) * kL;
                q = q * kL;
                if isempty(x)
                    phiFunc = cell(numel(q),numel(n));
                    uFunc = cell(numel(q),numel(n));
                    for nIdx = 1:numel(n)
                        for qIdx = 1:numel(q)
                            phiFunc{qIdx,nIdx} = @(x) 0;
                            uFunc{qIdx,nIdx} = @(x) 0;
                            vn = Fjn(:,nIdx,qIdx);
                            for ii = 1:nMax
                                phiFunc{qIdx,nIdx} = @(x) phiFunc{qIdx,nIdx}(x) + vn(ii)*exp(1i*(k(ii)+q(qIdx))*x);
                                if nargout == 4
                                    uFunc{qIdx,nIdx} = @(x) uFunc{qIdx,nIdx}(x) + vn(ii)*exp(1i*k(ii)*x);
                                end
                            end
                        end
                    end
                    phi = phiFunc;
                    if nargout == 4
                        u = uFunc;
                    end
                else
                    if ~isvector(x)
                        error("x must be a vector")
                    end
                    phi = zeros(numel(x),numel(q),numel(n));
                    u = zeros(numel(x),numel(q),numel(n));
                    x = x(:);
                    nx = numel(x);
                    dx = abs(x(2) - x(1));
                    cellIdx = x < lambda/4 & x >= -lambda/4;
                    % center index not needed

                    k = repmat(k,nx,1);
                    for nIdx = 1:numel(n)
                        for qIdx = 1:numel(q)
                            vn = Fjn(:,nIdx,qIdx).';
                            vn = repmat(vn,nx,1);

                            temp = vn.* exp(1i*(k+q(qIdx)).* x);
                            phi(:,qIdx,nIdx) = sum(temp,2);
                            if nargout == 4
                                u(:,qIdx,nIdx) = phi(:,qIdx,nIdx) ./ exp(1i * q(qIdx) * x);
                            end
                        end
                    end
                    phi = phi ./ sqrt(sum(abs(phi).^2,1) * dx);
                    if nargout == 4
                        u = u ./ sqrt(sum(abs(u(cellIdx,:,:)).^2,1) * dx);
                    end
                end
            end
        end

        function X = computeBerryConnection1D(obj,q,n)
            % Compute Berry connection :math:`\mathcal{A}_{mn}(q)` from plane-wave :math:`F_{jn}(q)`.
            %
            % :param q: Quasi-momentum grid in [1/m]
            % :type q: double, optional
            % :param n: Band indices
            % :type n: double, optional
            % :return: Berry connection :math:`\mathcal{A}_{mn}(q)`
            % :rtype: double array (nBands x nBands x n_q)
            arguments
                obj OpticalLattice
                q double = []
                n double = []
            end
            if ~isempty(q)
                [~,Fjn] = obj.computeBand1D(q,n);
            elseif ~isempty(obj.BlochStateFourier)
                Fjn = obj.BlochStateFourier;
                q = obj.QuasiMomentumList;
            else
                error("Must specify q,n")
            end

            % Compute gradient of Fjn along q
            dq = abs(q(2) - q(1));
            [~,~,dFdq] = gradient(Fjn,1,1,dq);

            % Compute Berry connection
            sz = size(Fjn);
            nq = sz(3);
            nBand = sz(2);
            X = zeros(nBand,nBand,nq);
            for qq = 1:nq
                BB = squeeze(dFdq(:,:,qq));
                AA = squeeze(Fjn(:,:,qq))';
                X(:,:,qq) = AA * BB;
            end

            lambda = obj.Laser.Wavelength;
            X = 1i * lambda / 2 * X;
        end

        function A = computeAmpModCoupling1D(obj,q,n)
            % Compute amplitude-modulation coupling matrix between bands.
            %
            % :param q: Quasi-momentum grid in [1/m]
            % :type q: double, optional
            % :param n: Band indices
            % :type n: double, optional
            % :return: Coupling matrix :math:`A_{mn}(q)`
            % :rtype: double array (nBands x nBands x n_q)
            arguments
                obj OpticalLattice
                q double = []
                n double = []
            end
            if ~isempty(q)
                [~,Fjn] = obj.computeBand1D(q,n);
            elseif ~isempty(obj.BlochStateFourier)
                Fjn = obj.BlochStateFourier;
            else
                error("Must specify q,n")
            end

            % Parameters
            sz = size(Fjn);
            nq = sz(3);
            nBand = sz(2);
            lambda = obj.Laser.Wavelength;

            % Matrices for computing
            FjnShift = circshift(Fjn,1) + circshift(Fjn,-1);
            idenMat = eye(nBand,nBand);

            % Compute coupling
            A = zeros(nBand,nBand,nq);
            for qq = 1:nq
                AA = squeeze(Fjn(:,:,qq))';
                BB = squeeze(FjnShift(:,:,qq));
                A(:,:,qq) = lambda / 8 * AA * BB + idenMat;
            end

        end

        function plotBand1D(obj,n)
            % Plot 1D band energies :math:`E_n(q)` versus quasi-momentum :math:`q`.
            %
            % :param n: Band indices to plot (0=s,1=p,...)
            % :type n: double, optional
            arguments
                obj OpticalLattice
                n double {mustBeInteger,mustBeNonnegative} = 0:3
            end

            kL = obj.Laser.AngularWavenumber;
            Er = obj.RecoilEnergy;

            if obj.BandIndexMax >= max(n)
                E = obj.BandEnergy;
                E = E(n+1,:);
                qList = obj.QuasiMomentumList;
            else
                nGrid = 2000;
                qList = linspace(-kL,kL,nGrid);
                E = obj.computeBand1D(qList,n);
            end

            close(figure(13548))
            figure(13548)
            plot(qList / kL,E / Er)
            xlabel("$q/k_{\mathrm{L}}$",Interpreter="latex")
            ylabel("$E/E_{\mathrm{R}}$",Interpreter="latex")
            title("$V_0 = " + num2str(obj.Depth/Er) +"E_{\mathrm{R}}$",'Interpreter','latex')

            % draw band letters at the mean band position
            letters={'s','p','d','f','g','h','i','j','k',...
                'l','m','n','o','p','q','r'};
            co = colororder;
            for nn=1:numel(n)
                yy=mean(E(nn,:))/Er;
                tL=text(1.05,yy+1,['$' letters{mod(n(nn),7)+1} '$'],...
                    'units','data','fontsize',15,...
                    'horizontalalignment','left',...
                    'color',co(mod(nn-1,7)+1,:),'interpreter','latex',...
                    'verticalalignment','middle');
                tL.Units='pixels';
                tL.Position(1)=tL.Position(1)+10;
                tL.Units='data';
            end
            render
            ax = gca;
            ax.Position(3) = ax.Position(3) * 0.9;
        end

        function plotBandTransition1D(obj,freq,n)
            % Plot vertical transition lines at resonance for frequency :math:`f`.
            %
            % :param freq: Modulation frequency :math:`f` in [Hz]
            % :type freq: double, optional
            % :param n: Band indices (0=s,1=p,...) used for overlays
            % :type n: double, optional
            arguments
                obj OpticalLattice
                freq double {mustBeScalarOrEmpty}
                n double {mustBeInteger,mustBeNonnegative} = 0:3
            end
            obj.plotBand1D(n);
            freqList = freq * (1:4);
            kL = obj.Laser.AngularWavenumber;
            Er = obj.RecoilEnergy;
            ax = gca;
            ax.Title.String = ax.Title.String + ", $\omega=2\pi \times" + num2str(freq/1e3) + "~\mathrm{kHz}$";
            hold on
            for ii = n
                for jj = n
                    if jj <= ii
                        continue
                    end
                    qRes = -obj.computeTransitionQuasiMomentum1D(freqList,ii,jj);
                    for kk = 1:4
                        if ~isnan(qRes(kk))
                            E = obj.computeBand1D(qRes(kk),[ii,jj]);
                            p1 = plot([1,1]*qRes(kk)/kL,...
                                E/Er,...
                                'k-','linewidth',1);
                            p2 = plot(-[1,1]*qRes(kk)/kL,...
                                E/Er,...
                                'k-','linewidth',1);
                            switch kk
                                case 1
                                    p1.LineStyle='-';
                                    p1.LineWidth=3;
                                    p2.LineStyle='-';
                                    p2.LineWidth=3;
                                case 2
                                    p1.LineStyle='--';
                                    p1.LineWidth=2;
                                    p2.LineStyle='--';
                                    p2.LineWidth=2;
                                case 3
                                    p1.LineStyle='-.';
                                    p1.LineWidth=1;
                                    p2.LineStyle='-.';
                                    p2.LineWidth=1;
                                otherwise
                                    p1.LineStyle = ':';
                                    p1.LineWidth=.2;
                                    p2.LineStyle = ':';
                                    p2.LineWidth=.2;
                            end
                        end
                    end
                end
            end
            hold off

        end

        function plotAmpModCoupling1D(obj,n,isPlotDiagonal)
            % Plot amplitude-modulation coupling amplitude and phase versus :math:`q`.
            %
            % :param n: Band indices (vector)
            % :type n: double, optional
            % :param isPlotDiagonal: Whether to include diagonal terms :math:`m=n`
            % :type isPlotDiagonal: logical, optional
            arguments
                obj OpticalLattice
                n double {mustBeVector,mustBeInteger,mustBeNonnegative} = 0:2
                isPlotDiagonal logical = false
            end
            if isscalar(n)
                error("dim(n) must be larger than 1.")
            end

            kL = obj.Laser.AngularWavenumber;

            % compute coupling
            if obj.BandIndexMax >= max(n)
                qList = obj.QuasiMomentumList;
                A = obj.AmpModCoupling;
                A = A(n+1,n+1,:);
            else
                nGrid = 2000;
                qList = linspace(-kL,kL,nGrid);
                A = obj.computeAmpModCoupling1D(qList,n);
            end

            % initialize legend
            nBand = numel(n);
            if isPlotDiagonal
                lg = cell(1,(nBand * (nBand  +1) / 2));
            else
                lg = cell(1,(nBand * (nBand  - 1) / 2));
            end

            % plot absolute value
            ll = 1;
            letters={'s','p','d','f','g','h','i','j','k',...
                'l','m','n','o','p','q','r'};
            close(figure(21542))
            figure(21542)
            hold on
            for mm = 1:nBand
                for nn = 1:nBand
                    if nn >= mm
                        if ~isPlotDiagonal
                            if mm == nn
                                continue
                            end
                        end
                        plot(qList / kL,squeeze(abs(A(mm,nn,:))))
                        lg{ll} = ['$',letters{n(mm)+1},'\leftrightarrow ',letters{n(nn)+1},'$'];
                        ll = ll + 1;
                    end
                end
            end
            hold off
            xlabel("$q/k_{\mathrm{L}}$",Interpreter="latex")
            ylabel("$|A|$",Interpreter="latex")
            legend(lg{:},'interpreter','latex')
            box on
            title("$V_0 = " + num2str(obj.Depth/obj.RecoilEnergy) + "E_{\mathrm{R}}$",'Interpreter','latex')
            render

            % plot phase
            close(figure(21543))
            figure(21543)
            hold on
            for mm = 1:nBand
                for nn = 1:nBand
                    if nn >= mm
                        if ~isPlotDiagonal
                            if mm == nn
                                continue
                            end
                        end
                        plot(qList / kL,squeeze(angle(A(mm,nn,:))))
                    end
                end
            end
            hold off
            xlabel("$q/k_{\mathrm{L}}$",Interpreter="latex")
            ylabel("$\mathrm{arg}(A)$",Interpreter="latex")
            legend(lg{:},'interpreter','latex')
            box on
            title("$V_0 = " + num2str(obj.Depth/obj.RecoilEnergy) + "E_{\mathrm{R}}$",'Interpreter','latex')
            render

        end

        function plotBerryConnection1D(obj,n,isPlotDiagonal)
            % Plot Berry connection amplitude and phase versus :math:`q`.
            %
            % :param n: Band indices (vector)
            % :type n: double, optional
            % :param isPlotDiagonal: Whether to include diagonal terms :math:`m=n`
            % :type isPlotDiagonal: logical, optional
            arguments
                obj OpticalLattice
                n double {mustBeVector,mustBeInteger,mustBeNonnegative} = 0:2
                isPlotDiagonal logical = false
            end
            if isscalar(n)
                error("dim(n) must be larger than 1.")
            end

            kL = obj.Laser.AngularWavenumber;
            lambda = obj.Laser.Wavelength;

            % compute Berry connection
            if obj.BandIndexMax >= max(n)
                qList = obj.QuasiMomentumList;
                X = obj.BerryConnection;
                X = X(n+1,n+1,:);
            else
                nGrid = 2000;
                qList = linspace(-kL,kL,nGrid);
                X = obj.computeBerryConnection1D(qList,n);
            end

            % initialize legend
            nBand = numel(n);
            if isPlotDiagonal
                lg = cell(1,(nBand * (nBand  +1) / 2));
            else
                lg = cell(1,(nBand * (nBand  - 1) / 2));
            end

            % plot absolute value
            ll = 1;
            letters={'s','p','d','f','g','h','i','j','k',...
                'l','m','n','o','p','q','r'};
            close(figure(12325))
            figure(12325)
            hold on
            for mm = 1:nBand
                for nn = 1:nBand
                    if nn >= mm
                        if ~isPlotDiagonal
                            if mm == nn
                                continue
                            end
                        end
                        plot(qList / kL,squeeze(abs(X(mm,nn,:))) / (lambda/2))
                        lg{ll} = ['$',letters{n(mm)+1},'\leftrightarrow ',letters{n(nn)+1},'$'];
                        ll = ll + 1;
                    end
                end
            end
            hold off
            xlabel("$q/k_{\mathrm{L}}$",Interpreter="latex")
            ylabel("$|X| / (\lambda/2)$",Interpreter="latex")
            legend(lg{:},'interpreter','latex')
            box on
            title("$V_0 = " + num2str(obj.Depth/obj.RecoilEnergy) + "E_{\mathrm{R}}$",'Interpreter','latex')
            render

            % plot phase
            close(figure(12326))
            figure(12326)
            hold on
            for mm = 1:nBand
                for nn = 1:nBand
                    if nn >= mm
                        if ~isPlotDiagonal
                            if mm == nn
                                continue
                            end
                        end
                        plot(qList / kL,squeeze(angle(X(mm,nn,:))))
                    end
                end
            end
            hold off
            xlabel("$q/k_{\mathrm{L}}$",Interpreter="latex")
            ylabel("$\mathrm{arg}(X)$",Interpreter="latex")
            legend(lg{:},'interpreter','latex')
            box on
            title("$V_0 = " + num2str(obj.Depth/obj.RecoilEnergy) + "E_{\mathrm{R}}$",'Interpreter','latex')
            render

        end

        function pop = computeBandPopulation1D(obj,psicj,n,x)
            % Compute band populations from real-space wavefunction :math:`\psi(x)`.
            %
            % :param psicj: Conjugate row-vectors of :math:`\psi` (nPsi x N_x)
            % :type psicj: double
            % :param n: Band index/indices (0=s,1=p,...)
            % :type n: double, optional
            % :param x: Spatial grid :math:`x` in [m] (optional)
            % :type x: double, optional
            % :return: Populations per state and band (nPsi x nBands)
            % :rtype: double
            arguments
                obj OpticalLattice
                psicj double
                n double {mustBeInteger,mustBeNonnegative} = 2
                x double {mustBeVector} = []
            end

            %% Input validation
            if ~ismatrix(psicj)
                error("Incorrect dimension of psi.")
            elseif isempty(x)
                if ~isempty(obj.SpaceList)
                    nx = numel(obj.SpaceList);
                else
                    error("Need to specify x.")
                end
            else
                nx = numel(x);
            end
            if size(psicj,1) == nx
                psicj = psicj'; % The spatial dimension of psi must be the second dimension.
            elseif size(psicj,2) ~= nx
                error("Incorrect dimension of psi.")
            end

            %% Get bands
            if ~isempty(x)
                dx = x(2) - x(1); % Spatial grid size
                kL = obj.Laser.AngularWavenumber;
                dk = 2 * pi / numel(x) / dx; % Momentum grid size
                q = -kL:dk:kL; % Sampling quasi-momentum
                [~,~,phi] = obj.computeBand1D(q,0:n,x);
            else
                phi = obj.BlochStateList;
                if max(n) > max(obj.BandIndexMax)
                    error("n is too large. Change BandIndexMax or reset n.")
                end
            end

            %% Compute population
            pop = zeros(size(psicj,1),numel(n));
            for nIdx = 1:numel(n)
                pop(:,nIdx) = sum(abs(psicj * phi(:,:,n(nIdx)+1) * dx).^2,2);
            end

        end

        function pop = computeBandPopulationFourier1D(obj,ucj,q,n)
            % Compute band populations from Fourier-periodic part :math:`u(x)`.
            %
            % :param ucj: Conjugate row-vectors of :math:`u` in Fourier basis (n_u x nFourier)
            % :type ucj: double
            % :param q: Quasi-momentum samples in [1/m]
            % :type q: double, optional
            % :param n: Band index/indices (0=s,1=p,...)
            % :type n: double, optional
            % :return: Populations per q and band (n_q x nBands)
            % :rtype: double
            arguments
                obj OpticalLattice
                ucj double
                q double {mustBeVector} = 0
                n double {mustBeInteger,mustBeNonnegative} = 2
            end

            %% Input validation
            if ~ismatrix(ucj)
                error("Incorrect dimension of ucj.")
            else
                nMax = size(ucj,2);
            end

            if numel(q) > 1
                if numel(q) ~= size(ucj,1)
                    error("Incorrect dimension of q")
                end
            end

            %% Get bands
            [~,Fjn] = obj.computeBand1D(q,0:max(n),nMax=nMax);

            %% Renormalize ucj
            lambda = obj.Laser.Wavelength;
            ucj = ucj ./ sqrt(sum(ucj .* conj(ucj),2));
            ucj = ucj * sqrt(2 / lambda);

            %% Compute population
            pop = zeros(size(ucj,1),numel(n));
            if numel(q) == 1
                for nIdx = 1:numel(n)
                    pop(:,nIdx) = abs(ucj * Fjn(:,n(nIdx)+1)).^2;
                end
            else
                for nIdx = 1:numel(n)
                    for qIdx = 1:numel(q)
                        pop(qIdx,nIdx) = abs(ucj(qIdx,:) * Fjn(:,n(nIdx)+1,qIdx)).^2;
                    end
                end
            end
            pop = pop * lambda^2 / 4;

        end

        function freq = computeTransitionFrequency1D(obj,q,n1,n2)
            % Compute transition frequencies :math:`|E_{n_2}(q)-E_{n_1}(q)|`.
            %
            % :param q: Quasi-momentum in [1/m]
            % :type q: double
            % :param n1: Lower band index :math:`n_1`
            % :type n1: double
            % :param n2: Upper band index :math:`n_2`
            % :type n2: double
            % :return: Transition frequency in [Hz] (same shape as :math:`q`)
            % :rtype: double
            arguments
                obj OpticalLattice
                q double {mustBeVector}
                n1 double {mustBeVector,mustBeInteger,mustBeNonnegative}
                n2 double {mustBeVector,mustBeInteger,mustBeNonnegative}
            end
            E = obj.computeBand1D(q,[n1,n2]);
            freq = abs(E(2,:) - E(1,:));
        end

        function qRes = computeTransitionQuasiMomentum1D(obj,freq,n1,n2)
            % Compute quasi-momentum :math:`q` at which :math:`|E_{n_2}(q)-E_{n_1}(q)|=f`.
            %
            % :param freq: Target transition frequency in [Hz]
            % :type freq: double
            % :param n1: Lower band index :math:`n_1`
            % :type n1: double
            % :param n2: Upper band index :math:`n_2`
            % :type n2: double
            % :return: Resonant :math:`q` values in [1/m]
            % :rtype: double
            arguments
                obj OpticalLattice
                freq double {mustBeVector}
                n1 double {mustBeVector,mustBeInteger,mustBeNonnegative}
                n2 double {mustBeVector,mustBeInteger,mustBeNonnegative}
            end
            % if obj.BandIndexMax < max(n1,n2)
                nq = 2^10;
                kL = obj.Laser.AngularWavenumber;
                q = linspace(-kL,kL,nq+1);
                q(end) = [];
                E = obj.computeBand1D(q,0:max([n1,n2]));
            % else
                % E = obj.BandEnergy;
                % q = obj.QuasiMomentumList;
            % end

            qIdx = q<=0;
            q = q(qIdx);
            E = E(:,qIdx);
            dE = abs(E(n2+1,:) - E(n1+1,:));
            bandDist = max(dE);
            bandGap = min(dE);
            tol = bandDist / 1e6;
            qRes = zeros(1,numel(freq));
            for ii = 1:numel(freq)
                if freq(ii) > bandDist || freq(ii) < bandGap
                    qRes(ii) = NaN;
                else
                    [~,resIdx] = sort(abs(freq(ii) - dE));
                    resIdx = resIdx(1:2);
                    q1 = q(resIdx(1));
                    q2 = q(resIdx(2));
                    E1err = abs(dE(resIdx(1)) - freq(ii));
                    E2err = abs(dE(resIdx(2)) - freq(ii));
                    err = tol * 10;
                    while err > tol
                        qResTemp = (q1 + q2) / 2;
                        EE = obj.computeBand1D(qResTemp,0:max([n1,n2]));
                        Emid = abs(EE(n2+1,:) - EE(n1+1,:));
                        err = abs(Emid - freq(ii));
                        if E1err > E2err
                            q1 = qResTemp;
                            E1err = err;
                        else
                            q2 = qResTemp;
                            E2err = err;
                        end
                    end
                    qRes(ii) = qResTemp;
                end
            end
            qRes = -qRes;


        end
        function qRes = computeTransitionQuasiMomentumFast1D(obj,freq,n1,n2)
            % Approximate resonant :math:`q` using linearized :math:`\Delta E(q)` near two roots.
            %
            % :param freq: Target transition frequency in [Hz]
            % :type freq: double
            % :param n1: Lower band index :math:`n_1`
            % :type n1: double
            % :param n2: Upper band index :math:`n_2`
            % :type n2: double
            % :return: Estimated resonant :math:`q` in [1/m]
            % :rtype: double
            arguments
                obj OpticalLattice
                freq double {mustBeVector}
                n1 double {mustBeVector,mustBeInteger,mustBeNonnegative}
                n2 double {mustBeVector,mustBeInteger,mustBeNonnegative}
            end
            % if obj.BandIndexMax < max(n1,n2)
                nq = 2^10;
                kL = obj.Laser.AngularWavenumber;
                q = linspace(-kL,kL,nq+1);
                q(end) = [];
                E = obj.computeBand1D(q,0:max([n1,n2]));
            % else
                % E = obj.BandEnergy;
                % q = obj.QuasiMomentumList;
            % end

            qIdx = q<=0;
            q = q(qIdx);
            dq = q(2) - q(1);
            E = E(:,qIdx);
            deltaE = abs(E(n2+1,:) - E(n1+1,:));
            bandDist = max(deltaE);
            bandGap = min(deltaE);
            qRes = zeros(1,numel(freq));
            for ii = 1:numel(freq)
                if freq(ii) > bandDist || freq(ii) < bandGap
                    qRes(ii) = NaN;
                else
                    [~,resIdx] = sort(abs(freq(ii) - deltaE));
                    resIdx = resIdx(1:2);
                    q1 = q(resIdx(1));
                    q2 = q(resIdx(2));
                    qResTemp = (q1 + q2) / 2;
                    dEdq = gradient(deltaE,dq);
                    dEdq = (dEdq(resIdx(1)) + dEdq(resIdx(2)))/2;
                    deltaE0 = (deltaE(resIdx(1)) + deltaE(resIdx(2)))/2;
                    
                    qRes(ii) = (freq(ii) - deltaE0)/dEdq + qResTemp;
                end
            end
            qRes = -qRes;
        end

        function computeAll1D(obj,nq,n)
            % Precompute bands, plane-wave coeffs, and couplings on a uniform q-grid.
            %
            % :param nq: Number of q samples
            % :type nq: double, optional
            % :param n: Max band index n to include
            % :type n: double, optional
            arguments
                obj OpticalLattice
                nq double {mustBeInteger,mustBePositive} = 1e4
                n double {mustBeVector,mustBeInteger,mustBeNonnegative} = 3
            end
            kL = obj.Laser.AngularWavenumber;
            q = linspace(-kL,kL,nq + 1);
            q(end) = [];
            obj.QuasiMomentumList = q;
            obj.BandIndexMax = n;

            [E,Fjn] = computeBand1D(obj,q,0:n);
            obj.BandIndexMaxFourier = size(Fjn,1);
            obj.BandEnergy = E;
            obj.BlochStateFourier = Fjn;
            obj.AmpModCoupling = obj.computeAmpModCoupling1D;
            obj.BerryConnection = obj.computeBerryConnection1D;
            obj.removeGauge;
            obj.BerryConnection = obj.computeBerryConnection1D;


        end

        function removeGauge(obj)
            % Fix gauge to make :math:`\mathcal{A}_{nn}(q)` single-valued and smooth.
            X = obj.BoCouplingList;
            q = obj.QuasiMomentumList;
            x = obj.SpaceList;
            sz = size(X);
            nBand = sz(1);
            nq = sz(3);
            dq = q(2) - q(1);
            dx = x(2) - x(1);
            lambda = obj.Laser.Wavelength;
            cellIdx = x < lambda/4 & x >= -lambda/4;
            phase = zeros(nBand,nq);
            for nIdx = 1:nBand
                Xnn = X(nIdx,nIdx,:);
                phase(nIdx,:) = cumtrapz(q,Xnn);
            end
            phase = exp(1i * phase);

            phi = obj.BlochStateList;
            u = obj.BlochStatePeriodicList;

            for nIdx = 1:nBand
                for qq = 1:nq
                    phi(:,qq,nIdx) = phi(:,qq,nIdx) * phase(nIdx,qq);
                    u(:,qq,nIdx) = u(:,qq,nIdx) * phase(nIdx,qq);
                end
            end
            phi = phi ./ sqrt(sum(abs(phi).^2,1) * dx);
            u = u ./ sqrt(sum(abs(u(cellIdx,:,:)).^2,1) * dx);

            obj.BlochStateList = phi;
            obj.BlochStatePeriodicList = u;

        end

        function H = HamiltonianAmpModFourier1D(obj,q,wf,nMax)
            % Build time-dependent Fourier-space Hamiltonian under amplitude modulation.
            %
            % :param q: Quasi-momentum in [1/m]
            % :type q: double
            % :param wf: Modulation waveform :math:`m(t)`
            % :type wf: :class:`Waveform`
            % :param nMax: Plane-wave cutoff (odd)
            % :type nMax: double
            % :return: Function handle :math:`H(t)` that yields the Hamiltonian matrix
            % :rtype: function_handle
            arguments
                obj OpticalLattice
                q double
                wf Waveform
                nMax double
            end
            if isempty(nMax)
                nMax = obj.BandIndexMaxFourier;
            end
            Er = obj.RecoilEnergy;
            V0 = obj.Depth / Er;
            kL = obj.Laser.AngularWavenumber;
            jVec = 1-nMax:2:nMax-1;
            trigMat = -gallery('tridiag',nMax,1,2,1);
            modFunc = wf.TimeFunc;
            Hp = Er * diag((jVec + q / kL).^2); % Here we must go back to SI units
            HV0 = Er * trigMat * V0 / 4;
            H = @HFunc;
            function Htotal = HFunc(t)
                HV = HV0 .* (1 + modFunc(t));
                Htotal = Hp + HV;
            end
        end

        function [EF,vF] = computeFloquetAmpMod1D(obj,q,n,wf)
            % Compute Floquet quasi-energies and modes under amplitude modulation.
            %
            % :param q: Quasi-momentum samples in [1/m]
            % :type q: double
            % :param n: Band indices used for projection
            % :type n: double
            % :param wf: Modulation waveform :math:`m(t)`
            % :type wf: :class:`Waveform`
            % :return: Quasi-energies :math:`E_F` in [Hz]
            % :rtype: double array (nBands x n_q)
            % :return: Floquet modes projected onto plane-wave basis
            % :rtype: double array (nMax x nBands x n_q)
            arguments
                obj OpticalLattice
                q double {mustBeVector} % Sampling quasimomentum [p/hbar] in unit of 1/meter.
                n double {mustBeVector,mustBeInteger,mustBeNonnegative}
                wf Waveform
            end
            [~,Fjn] = obj.computeBand1D(q,n); % compute static Bloch states
            nMax = size(Fjn,1);
            T = wf.Period;
            EF = zeros(length(n),length(q));
            vF = zeros(nMax,length(n),length(q));
            HList = arrayfun(@(qq) obj.HamiltonianAmpModFourier1D(qq,wf,nMax),...
                q,'UniformOutput',false);
            p = gcp('nocreate');
            if ~isempty(p)
                parfor qIdx = 1:length(q)
                    % H = obj.HamiltonianAmpModFourier1D(q(qIdx),wf,nMax);
                    HF = computeFloquetHamiltonian(HList{qIdx},T);
                    [vFAll,EFAll]=eig(full(HF));
                    EFAll=real(diag(EFAll));
                    P = abs(vFAll' * Fjn(:,:,qIdx)).^2;
                    [~,idx] = max(P,[],1);
                    EF(:,qIdx) = EFAll(idx);
                    vF(:,:,qIdx) = vFAll(:,idx);
                end
            else
                for qIdx = 1:length(q)
                    % H = obj.HamiltonianAmpModFourier1D(q(qIdx),wf,nMax);
                    HF = computeFloquetHamiltonian(HList{qIdx},T);
                    [vFAll,EFAll]=eig(full(HF));
                    EFAll=real(diag(EFAll));
                    P = abs(vFAll' * Fjn(:,:,qIdx)).^2;
                    [~,idx] = max(P,[],1);
                    EF(:,qIdx) = EFAll(idx);
                    vF(:,:,qIdx) = vFAll(:,idx);
                end
            end
        end

    end
end

