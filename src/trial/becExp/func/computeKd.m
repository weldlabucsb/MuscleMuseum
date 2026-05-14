function pop = computeKd(ol,V0List,t,orderMax,isPlot,cloudWidth)
%COMPUTEKDORDER Summary of this function goes here
%   Detailed explanation goes here
arguments
    ol OpticalLattice
    V0List double %Lattice depth in Hz
    t double %Pulse duration in s
    orderMax double {mustBeInteger,mustBePositive} = 20 %
    isPlot logical = false
    cloudWidth double = NaN %Assume this is the 2D cloudWidth
end
V0List = V0List(:);
nV0 = numel(V0List);
nDim = orderMax * 2 + 1;
pop = zeros(nV0,nDim);
Er = ol.RecoilEnergy;

% Initial condition
psi = zeros(nDim,1);
psi(orderMax+1) = 1;  % start in n=0

% Kinetic Energy
Hk = diag(4 * Er * (-orderMax:orderMax).^2);

for ii = 1:nV0
    % Potential energy
    V0 = V0List(ii);
    Hp = -V0/4 * gallery('tridiag',nDim,1,2,1);

    % Time evolution
    H = Hk + Hp;
    U = expm(-1i * 2 * pi * H * t);
    psif = U * psi;
    pop(ii,:) = (abs(psif).^2).';
end

if ~isnan(cloudWidth)
    if ~isa(ol.Laser,"GaussianBeam")
       error("ol's Laser must be GaussianBeam.") 
    end
    if isnan(ol.Laser.Waist(1))
        error("The beam waist of the optical lattice has to be provided.")
    end

    % Interpolate
    KdInterp = cell(1,nDim);
    for nn = 1:nDim
        nthOrder = pop(:,nn);
        KdInterp{nn} = @(q) interp1(V0List, nthOrder, q, 'pchip', 'extrap');
    end

    nx = 1e3;
    x = linspace(-5 * cloudWidth,5 * cloudWidth,nx);
    density1D = boseFunctionApprox(exp(-x.^2/(cloudWidth^2)),2.5);
    density1D = density1D./sum(density1D);
    gaussianBeam1D = exp(-2 * x.^2/prod(ol.Laser.Waist));

    % Compute weighted average
    pop = cell2mat(arrayfun(@(jj) ...
        sum(cell2mat(arrayfun(@(ii) density1D(ii) * KdInterp{jj}(gaussianBeam1D(ii) * V0List),(1:nx),UniformOutput=false)),2),...
        (1:nDim),UniformOutput=false));

    % nx = 1e2;
    % x = linspace(-5 * cloudWidth,5 * cloudWidth,nx);
    % [X,Y] = meshgrid(x,x);
    % density2D = boseFunctionApprox(exp(-(X.^2+Y.^2)/(cloudWidth^2)),2);
    % density2D = density2D./sum(density2D(:));
    % gaussianBeam2D = exp(-2 * (X.^2+Y.^2)/prod(ol.Laser.Waist));
    % 
    % % Compute weighted average
    % for ii = 1:nDim
    %     pop(:,ii) = arrayfun(@(kk) ...
    %         sum(density2D.* KdInterp{ii}(gaussianBeam2D * V0List(kk)),"all"),...
    %         (1:size(V0List)).');
    % end
end

if isPlot
    figure
    plot(V0List/Er,pop(:,orderMax+1:end))
    xlabel("Lattice Depth [$E_{\mathrm{R}}$]",'Interpreter','latex')
    ylabel("$P_{n}$",'Interpreter','latex')
    lgstr = "$n=" + (0:orderMax) + "$";
    legend(lgstr(:),'Interpreter','latex')
    render
end
end

