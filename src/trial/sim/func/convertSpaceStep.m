function spaceStep = convertSpaceStep(spaceRange,spaceStep)
%CONVERTSPACESTEP Summary of this function goes here
%   Detailed explanation goes here

nSpaceStep = spaceRange ./ spaceStep;
nSpaceStep = 2.^(ceil(log2(nSpaceStep)));
spaceStep = spaceRange ./ (nSpaceStep - 1);
end

