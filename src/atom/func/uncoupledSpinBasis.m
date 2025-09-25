function b = uncoupledSpinBasis(j1,mj1,j2,mj2)
% Convert coupled spin basis to uncoupled weights (Clebsch–Gordan).
%
% :param j1: First total spin :math:`j_1`
% :type j1: double
% :param mj1: Magnetic sublevel :math:`m_{j,1}`
% :type mj1: double
% :param j2: Second total spin :math:`j_2`
% :type j2: double
% :param mj2: Magnetic sublevel :math:`m_{j,2}`
% :type mj2: double
% :return: Weights for each coupled :math:`|j_3,m_{j,3}\rangle` basis element
% :rtype: double
%
% Computes coefficients so that :math:`|j_1,m_{j,1}; j_2,m_{j,2}\rangle = \sum C\,|j_3,m_{j,3}\rangle`.

j3 = totalAngularMomentum(j1,j2);
j3List = angularMomentumList(j3);
mj3List = magneticAngularMomentum(j3);
nn = numel(mj3List);
b = zeros(nn,1);
for ii = 1:nn
    if mj3List(ii) == mj1 + mj2
        b(ii) = cgcoefficient(j1,mj1,j2,mj2,j3List(ii),mj3List(ii));
    end
end
end

