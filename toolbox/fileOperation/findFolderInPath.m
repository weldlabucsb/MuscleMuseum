function folderFullPath = findFolderInPath(folderName)
p = string(strsplit(path,';'));
m = regexp(p,".*"+string(folderName)+"$");
if isempty(m)
    folderFullPath = string.empty;
else
    folderFullPath = p(~cellfun(@isempty,m));
end
end

