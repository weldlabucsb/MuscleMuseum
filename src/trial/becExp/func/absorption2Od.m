function OD = absorption2Od(absorp)
% Convert absorption signal to optical depth (OD).
%
% :param absorp: Absorption ratio :math:`I_\mathrm{atom}/I_\mathrm{light}` (or equivalent)
% :type absorp: double
% :return: Optical depth :math:`\mathrm{OD} = -\ln(\lvert a \rvert + \epsilon)` clipped to finite, real values
% :rtype: double
%
% .. math::
%
%    \mathrm{OD} = -\ln\!\big( |a| + \epsilon \big)
%
OD = -log(abs(absorp)+eps);
% OD(abs(OD)<abs(min(OD(:))))=0;
% OD(OD<0) = 0;
OD(isnan(OD))=0;
OD(isinf(OD))=0;
OD = real(OD);
end

