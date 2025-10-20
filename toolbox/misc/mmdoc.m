function mmdoc(name)
%MMHELP Open the help documentation for the MM function/class in your
%browser
arguments
    name string
end

htmlFolder = fullfile(findFolderInPath("MuscleMuseum"),"doc","sphinx","build","html");
pattern = fullfile(htmlFolder, '**', name + ".html");
htmlFile = dir(pattern);
if ~isempty(htmlFile)
    winopen(fullfile(htmlFile(1).folder,htmlFile(1).name))
end
end

