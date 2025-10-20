function [J1,J2] = uncoupledSpinMatrices(j1,j2)
%uncoupledSpinMatrices 
%   j1 and j2 couple to get j3. Get the uncoupled angular
%   momentum spin matrices under the j3 basis
J1 = spinMatrices(j1);
nj1 = 2*j1 + 1;
J2 = spinMatrices(j2);
nj2 = 2*j2 + 1;
J1x = kron(J1{1},eye(nj2));
J1y = kron(J1{2},eye(nj2));
J1z = kron(J1{3},eye(nj2));
J2x = kron(eye(nj1),J2{1});
J2y = kron(eye(nj1),J2{2});
J2z = kron(eye(nj1),J2{3});

% J3x = J1x + J2x;
% J3y = J1y + J2y;
% J3z = J1z + J2z;
% J3 = {J3x,J3y,J3z};

U = uncoupledSpinBasisTransformation(j1,j2);

J1x = U * J1x * U';
J1y = U * J1y * U';
J1z = U * J1z * U';
J2x = U * J2x * U';
J2y = U * J2y * U';
J2z = U * J2z * U';


J1 = {J1x;J1y;J1z};
J2 = {J2x;J2y;J2z};
% F = arrayfun(@(j) spinMatrices(j),totalAngularMomentum(j1,j2),'UniformOutput',false);
% F = horzcat(F{:});
% J3 = arrayfun(@(r) blkdiag(F{r,:}),(1:3)','UniformOutput',false);

for ii = 1:3
    J1{ii} = (J1{ii}+J1{ii}')/2;
    J2{ii} = (J2{ii}+J2{ii}')/2;
    J1{ii}(abs(J1{ii}) < 1e-8) = 0;
    J2{ii}(abs(J2{ii}) < 1e-8) = 0;
end

end


