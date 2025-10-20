function saveAtom
%SAVEATOMDATA Summary of this function goes here
%   Detailed explanation goes here
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

