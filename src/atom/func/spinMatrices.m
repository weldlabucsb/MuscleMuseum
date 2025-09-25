function J = spinMatrices(j)
% Build spin matrices :math:`J_x,J_y,J_z` for spin :math:`j`.
%
% :param j: Total spin (e.g., 1/2, 1, 3/2)
% :type j: double
% :return: Cell array {Jx; Jy; Jz}
% :rtype: cell
mj = -(-j+1:j);
JElement = sqrt(j*(j+1)-mj.*(mj+1));
JPlus = diag(JElement,1);
JMinus = diag(JElement,-1);
Jx = (JPlus + JMinus) / 2;
Jy = (-JPlus + JMinus) * 1i /2;
Jz = (JPlus * JMinus - JMinus * JPlus) / 2;
J = {Jx;Jy;Jz};
end

