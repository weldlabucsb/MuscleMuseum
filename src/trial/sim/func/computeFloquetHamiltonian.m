function HF = computeFloquetHamiltonian(H,T,nt)
% Compute the (effective) Floquet Hamiltonian from a time-periodic Hamiltonian.
%
% :param H: Matrix-valued Hamiltonian function handle :math:`H(t)`
% :type H: function_handle
% :param T: Modulation period :math:`T` in [s]
% :type T: double
% :param nt: Number of time samples over one period (uniform grid)
% :type nt: double, optional
% :return: Effective Floquet Hamiltonian :math:`H_F` in [Hz]
% :rtype: double matrix
%
% **Notes:**
%
%     The evolution operator over one period is approximated by a product
%     :math:`U(T) \approx \prod_k \exp\{-i\,2\pi\, H(t_k)\, \Delta t\}`, and
%     the effective Hamiltonian is extracted as
%     :math:`H_F = \frac{i}{2\pi T}\,\log U(T)`.
arguments
    H function_handle
    T double {mustBeScalarOrEmpty,mustBePositive}
    nt double {mustBePositive,mustBeInteger} = 20
end
% Check if H is a matrix valued function
try
    dim = size(H(0),1);
catch
    error("H must be a matrix valued function handle")
end

tList = linspace(0,T,nt);
tList(end) = [];
dt = tList(2) - tList(1);
U = eye(dim);
for tt = 1:(nt-1)
    t = tList(tt);
    U = expm(-1i * 2 * pi * H(t) * dt) * U;
end
HF = 1i * logm(U) / T / 2 / pi; %In unit of Hz
HF = (HF + HF') / 2; %make it Hermitian

end

