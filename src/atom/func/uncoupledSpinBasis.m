function b = uncoupledSpinBasis(j1,mj1,j2,mj2)
%uncoupledSpinBasis Convert coupled spin basis to uncoupled.
%   :math:`j_1` and :math:`j_2` couple to get :math:`j_3`. Get the uncoupled angular
%   momentum spin eigen-basis :math:`|j_1,m_{j,1},j_2,m_{j,2}\rangle` under the
%   :math:`j_3` basis :math:`|j_3,m_{j,3}\rangle`

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

