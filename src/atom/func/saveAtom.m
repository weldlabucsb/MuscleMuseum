function saveAtom
% Save a small set of :class:`Atom` objects to disk for reuse.
%
% Saves an ``AtomData.mat`` file under :attr:`Atom.DataPath` containing
% several pre-constructed atoms.
atomNameList = ["Lithium7","Rubidium87","Sodium"];
for ii = 1:numel(atomNameList)
    try 
        atom = Alkali(atomNameList(ii));
    catch
        atom = Divalent(atomNameList(ii));
    end
    S.(atomNameList(ii)) = atom;
end
save(fullfile(atom.DataPath,"AtomData.mat"),'-struct', 'S','-mat')
end

