function OD = absorption2Od(absorp)
%Convert absorption signal to optical depth (OD).
OD = -log(abs(absorp)+eps);
% OD(abs(OD)<abs(min(OD(:))))=0;
% OD(OD<0) = 0;
OD(isnan(OD))=0;
OD(isinf(OD))=0;
OD = real(OD);
end

