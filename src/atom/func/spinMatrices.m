function J = spinMatrices(j)
%SPINMATRICES Summary of this function goes here
%   Detailed explanation goes here
mj = -(-j+1:j);
JElement = sqrt(j*(j+1)-mj.*(mj+1));
JPlus = diag(JElement,1);
JMinus = diag(JElement,-1);
Jx = (JPlus + JMinus) / 2;
Jy = (-JPlus + JMinus) * 1i /2;
Jz = (JPlus * JMinus - JMinus * JPlus) / 2;
J = {Jx;Jy;Jz};
end

