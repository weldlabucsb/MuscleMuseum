function U = uncoupledSpinBasisTransformation(j1,j2)
%uncoupledSpinBasisTransformation 
%   Transform the basis from the coupled spin basis to the uncoupled
%   spin basis
mj1List = magneticAngularMomentum(j1);
mj2List = magneticAngularMomentum(j2);

nj1 = 2*j1 + 1;
nj2 = 2*j2 + 1;
nn = nj1*nj2;

U = zeros(nn,nn);

kk = 1;
for ii = 1:nj1
    for jj = 1:nj2
        U(:,kk) = uncoupledSpinBasis(j1,mj1List(ii),j2,mj2List(jj));
        kk = kk + 1;
    end
end
end

