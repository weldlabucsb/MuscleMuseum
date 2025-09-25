function name = enterName(objName)
%ENTERNAME Summary of this function goes here
%   Detailed explanation goes here
f = figure('Renderer', 'painters', 'Position', [-100 -100 0 0]);
name = inputdlg("Please enter the name of the " + objName + ".",objName);
delete(f);
if ~isempty(name)
    name = string(name);
    if ~isAlphaNumUnderscore(name)
        error("Name can only contains alphabetic, numbers, or underscors.")
    end
end

