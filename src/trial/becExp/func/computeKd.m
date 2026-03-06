function pop = computeKd(ol,V0List,t,orderMax,isPlot)
%COMPUTEKDORDER Summary of this function goes here
%   Detailed explanation goes here
arguments
    ol OpticalLattice
    V0List double %Lattice depth in Hz
    t double %Pulse duration in s
    orderMax double {mustBeInteger,mustBePositive} = 20 %
    isPlot logical = false
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

