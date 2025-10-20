function absorp = computeAbsorption(imageData,absorpMin)
%CALCULATEABSORPTION calculate absorption signal
%   imageData: must be a 4-D array. The first two dimensions store the
%   image data. The third dimension is the run index. The last dimension
%   represents "atom"/"light"/"dark" image labels (or "atom"/"light").
%   absorp: absorption signal. Must be between 0 and 1 where 0 means
%   totally absorbed by atoms.
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

