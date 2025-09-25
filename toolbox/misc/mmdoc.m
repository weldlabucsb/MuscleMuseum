function mmdoc(name)
%MMHELP Open the help documentation for the MM function/class in your
%browser
arguments
    name string
end

if contains(name,".")
    strParts = strsplit(name,".");
    if numel(strParts) > 2
        return
    else
        pageName = strParts(1);
        mpName = strParts(2);
    end
else
    pageName = name;
    mpName = "";
end

htmlFolder = fullfile(findFolderInPath("MuscleMuseum"),"doc","sphinx","build","html");
pattern = fullfile(htmlFolder, '**', pageName + ".html");
htmlFile = dir(pattern);
if ~isempty(htmlFile)
    htmlJump = fullfile(htmlFile(1).folder,htmlFile(1).name) + "#" + pageName + "." + mpName;
    web(htmlJump)
end
end

