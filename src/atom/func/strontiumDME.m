function d = strontiumDME
% Compute reduced dipole matrix element for Sr blue line from lifetime.
%
% Uses literature lifetime to infer reduced DME and converts to atomic units,
% then adjusts to Steck-like conventions via Wigner symbols.
%
% :return: Reduced dipole matrix element (atomic units)
% :rtype: double
arc = py.importlib.import_module('arc');
l2 = 1;
l1 = 0;
j2 = 1;
j1 = 0;
s = 0;
atom = Divalent("Strontium84");
omega0 = atom.ArcObj.getTransitionFrequency(5,0,0,5,1,1,0,0) * 2 * pi;
epsilon0 = Constants.SI("epsilon0");
hbar = Constants.SI("hbar");
c = Constants.SI("c");
tau = 5.219e-9;
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