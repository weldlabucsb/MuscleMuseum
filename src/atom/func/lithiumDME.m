function d = lithiumDME
% Compute reduced dipole matrix element for Li D2 from lifetime.
%
% Uses literature lifetime to infer reduced DME and converts to atomic units,
% then adjusts to Steck conventions via Wigner-3j/6j factors.
%
% :return: Reduced dipole matrix element (atomic units)
% :rtype: double
arc = py.importlib.import_module('arc');
l2 = 1;
l1 = 0;
j2 = 3/2;
j1 = 1/2;
s = 1/2;
atom = Alkali("Lithium7");
trans = TwoJManifold(atom,2,0,j1,2,1,j2);
omega0 = trans.Frequency * 2 * pi;
epsilon0 = Constants.SI("epsilon0");
hbar = Constants.SI("hbar");
c = Constants.SI("c");
tau = 2.7102e-08;
Gamma= 1/tau;
factor = omega0^3/3/pi/epsilon0/hbar/c^3*(2*j1+1)/(2*j2+1);
d = sqrt(Gamma/factor);
au = Constants.SI("e")*Constants.SI("a0");
d = -d/au;
factor1 =             (-1) ^ (round((l2 + l1 + 3.0) / 2.0 + s + j2))...
    * sqrt((2.0 * j2 + 1.0) * (2.0 * l1 + 1.0))...
    * arc.Wigner6j(l1, l2, 1, j2, j1, s)...
    * sqrt((max(l1, l2)) / (2.0 * l1 + 1.0));
factor2 = (...
    (-1) ^ (round(l1 + 0.5 + j2 + 1.0))...
    * sqrt((2.0 * j1 + 1.0) * (2.0 * j2 + 1.0))...
    * arc.Wigner6j(j1, 1.0, j2, l2, 0.5, l1)...
    * (-1) ^ l1...
    * sqrt((2.0 * l1 + 1.0) * (2.0 * l2 + 1.0))...
    * arc.Wigner3j(l1, 1, l2, 0, 0, 0)...
    );
d = d/factor1*factor2;
end