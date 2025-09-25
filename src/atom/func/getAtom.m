function atom = getAtom(atomName)
% Construct an :class:`Atom` by trying alkali first, then divalent.
%
% :param atomName: Atom/isotope name (ARC-known), e.g., "Lithium7"
% :type atomName: string
% :return: Constructed atom object (:class:`Alkali` or :class:`Divalent`)
% :rtype: :class:`Atom`
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

