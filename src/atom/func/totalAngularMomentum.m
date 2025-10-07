function j3 = totalAngularMomentum(j1,j2)
% Compute coupled total angular momenta :math:`j_3=|j_1-j_2|,\dots,j_1+j_2`.
%
% :param j1: First total spin :math:`j_1`
% :type j1: double
% :param j2: Second total spin :math:`j_2`
% :type j2: double
% :return: Vector of allowed :math:`j_3`
% :rtype: double
j3 = flip(abs(j1-j2):abs(j1+j2));
end

