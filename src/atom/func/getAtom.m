function atom = getAtom(atomName)
%GETATOM Summary of this function goes here
%   Detailed explanation goes here
arguments
    atomName string
end

try
    atom = Alkali(atomName);
catch
    try
        atom = Divalent(atomName);
    catch
        error("[" + atomName + "] is not a supported element.")
    end
end
end

