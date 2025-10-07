function absorp = computeAbsorption(imageData,absorpMin)
% Compute absorption ratio from atom/light(/dark) images.
%
% Converts raw images into an absorption ratio :math:`a = I_\mathrm{atom}/I_\mathrm{light}`
% with optional dark subtraction when a third channel is present. Negative
% or non-physical intensities are clipped to small positive values to avoid
% division by zero.
%
% :param imageData: 4-D image stack with shape (:math:`N_y,N_x,N_\mathrm{run},N_\mathrm{ch}`),
%     where the last dimension is either ``[atom, light, dark]`` (3) or ``[atom, light]`` (2)
% :type imageData: double
% :param absorpMin: Minimum allowed absorption; values below are not clipped in code (default: 0)
% :type absorpMin: double, optional
% :return: Absorption ratio :math:`a = I_\mathrm{atom}/I_\mathrm{light}`; values are in [0, +inf)
% :rtype: double
%
% **Notes:**
%   - For 3-channel input, this computes ``atom = atom-dark`` and ``light = light-dark``.
%   - Light values :math:`\le 0` are replaced by ``eps`` to keep :math:`a` finite.
%   - Atom values :math:`< 0` are clipped to 0.
%
% **Example:**
%
% .. code-block:: matlab
%
%    a = computeAbsorption(cat(4, atomImg, lightImg, darkImg));
%    OD = absorption2Od(a);
if nargin == 1
    absorpMin = 0;
end
if size(imageData,4) == 3
    atomData = imageData(:,:,:,1)-imageData(:,:,:,3);
    lightData = imageData(:,:,:,2)-imageData(:,:,:,3);
elseif size(imageData,4) == 2
    atomData = imageData(:,:,:,1);
    lightData = imageData(:,:,:,2);
end
% atomData( abs(atomData) <= abs(min(atomData(:))) ) = 0;
% lightData( abs(lightData) <= abs(min(lightData(:))) ) = eps;
atomData(atomData<0)=0;
lightData(lightData<=0)=eps;
absorp = atomData./lightData;
% absorp(absorp<absorpMin|absorp>1)=1; %Remove points with unreasonably high or low aborption.
end

