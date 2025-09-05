function [J1,J2] = uncoupledSpinMatrices(j1,j2)
% Build uncoupled spin operators :math:`\mathbf{J}_1,\mathbf{J}_2` in the coupled basis.
%
% :param j1: First total spin :math:`j_1`
% :type j1: double
% :param j2: Second total spin :math:`j_2`
% :type j2: double
% :return: Cells of 3 matrices for each spin (x,y,z) in the :math:`|j,m\rangle` basis
% :rtype: cell, cell
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
    J1{ii} = (J1{ii}+J1{ii}')/2; % Hermitize
    J2{ii} = (J2{ii}+J2{ii}')/2;
    J1{ii}(abs(J1{ii}) < 1e-8) = 0; % Clean tiny numerical noise
    J2{ii}(abs(J2{ii}) < 1e-8) = 0;
end

end


