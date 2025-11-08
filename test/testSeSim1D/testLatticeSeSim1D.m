clear
close all
sigmaList = [1.53,5,10] * 1e-6;
for ss = 1:numel(sigmaList)
    %% atom
    atom = Alkali("Lithium7");
    atomicState.N = atom.groundStateN;
    atomicState.L = 0;
    atomicState.J = 1/2;
    atomicState.F = 1;
    atomicState.MF = -1;

    %% B field
    quad = zeros(3,3,3);
    % quad(3,2,2) = -1.415^2 * (2/9)^2;
    bList = num2cell(linspace(1.25e-2,1.26e-2,100));
    niB = 543.6e-4; %non-interacting feshbach field
    bField = cellfun(@(x) MagneticField(...
        bias = [0;0;niB],...
        gradient = [0,0,0;0,0,0;0,x,0],quadratic=quad),bList,'UniformOutput',false);

    %% set laser
    laser = Laser( ...
        wavelength = 1064e-9,...
        direction = [0;1;0],...
        polarization = [0;0;1],...
        intensity = 3.852874965460643e7 ...
        );
    laser = {laser};

    %% set optical lattice
    ol = OpticalLattice(atom,laser{1});
    ol.DepthSpec = 7.735 * ol.RecoilEnergy;
    ol.updateIntensity;
    kL = ol.Laser.AngularWavenumber;
    laser = {ol.Laser};

    %% set modulation
    p = WaveformListLibrary;
    latticeMod = p.loadEntry(18);
    latticeMod.WaveformOrigin{1}.Amplitude = 0.24;
    latticeMod.WaveformOrigin{1}.Frequency = 110e3;
    latticeMod.WaveformOrigin{1}.Duration = 5.3e-3;
    latticeMod.WaveformOrigin{2}.Frequency = 95.563e3;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{1}.Duration = 0.001e-3;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{2}.Duration = 3.106e-3;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{3}.Duration = 2 * 2.194e-3;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{4}.Duration = 3.106e-3;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{4}.Amplitude = 0.023 * 4;
    % latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{2}.Amplitude = 0.023 * 4;
    % latticeMod.WaveformOrigin{2}.StartTime = 0;
    latticeMod = {latticeMod};

    %% Simulation
    ic = InitialCondition("SeSim1D");
    se = LatticeSeSim1D("Test", ...
        atom = atom,...
        atomicState = atomicState,...
        laser = laser,...
        magneticField = bField,...
        latticeModulation = latticeMod,...
        timeStep=1e-7,...
        totalTime=16.4e-3,...
        spaceRange = 1000e-06,...
        spaceStep = 1e-8,initialCondition = ic);

    % initial condition
    x = se.SimRun(1).SpaceList;
    x = x.';
    sigma = sigmaList(ss);
    kL = ol.Laser.AngularWavenumber;
    qIni = -kL;
    [~,~,phi] = ol.computeBand1D(qIni,0,x);

    psi = exp(-(x).^2 / 4 / sigma^2) .* phi;
    ic.WaveFunction = psi;
    for ii = 1:numel(se.SimRun)
        se.SimRun(ii).InitialCondition.WaveFunction = psi;
    end

    se.start

    %% Plot
    nSpace = se.SimRun(1).NSpaceStep;
    nRun = numel(se.SimRun);
    psiList = zeros(nRun,nSpace);
    x = se.SimRun(1).SpaceList;
    for ii = 1:nRun
        psiList(ii,:) = se.SimRun(ii).readRun("FinalWaveFunction");
    end
    bandPop = ol.computeBandPopulation1D(psiList,int32(2),x);

    mp = MagneticPotential(atom,bField{1});
    stateIdx = mp.StateIndex;
    stateList = atom.(mp.Manifold).StateList;
    mJ = stateList.MJ(stateIdx);
    gJ = stateList.gJ(stateIdx);
    mI = stateList.MI(stateIdx);
    gI = stateList.gI(stateIdx);
    muB = Constants.SI("muB");
    h = Constants.SI("hbar") * 2 * pi;
    hbar = Constants.SI("hbar");
    prefactor = (mJ * gJ + mI * gI) * muB / h;
    FList0 = abs(h * prefactor * cell2mat(bList));
    g = 9.81;
    M = atom.mass;
    a = laser{1}.Wavelength/2;
    h = Constants.SI('hbar')*2*pi;
    fB = FList0*a/h;
    fig = figure(48294);
    plot(1./fB * 1e3,bandPop)
    xlabel("$T_{\mathrm{B}}$ (ms)")
    ylabel("$D$ Band Fraction")
    axis([min(1e3./fB),max(1e3./fB),0,1])
    title(['$\sigma_x =',num2str(sigmaList(ss) * 1e6),'\,\mu\mathrm{m}$, Trial ',num2str(se.SerialNumber)],'Interpreter','latex')
    render
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"png")
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"fig")
    close all
end