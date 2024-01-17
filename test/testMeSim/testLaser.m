atom = Alkali("Lithium7");
Isat = atom.CyclerSaturationIntensity;
laser = Laser( ...
    frequency = atom.CyclerFrequency,...
    direction = [0,0,1],...
    polarization = sphericalBasis(-1),...
    intensity = 0.22*Isat,...
    power = 1 ...
    );
% laser.rotateToAngle([pi/2,0]);
fRot = laser.Frequency;
Hal = atom.D2.HamiltonianAtomLaser(laser,fRot);
Ha = atom.D2.HamiltonianAtom(fRot);
