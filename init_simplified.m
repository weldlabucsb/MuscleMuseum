%% Set Path
disp(newline + "Setting path...")
addpath(genpath_exclude(pwd,{'.git','testData','sampleData','.gitignore','.github','doc'}));
userPath = fullfile(getHome,"Documents","MMUser");

if exist(userPath,'dir')==0
    disp(newline + "Detected it is the first time installing. Creating config files...")
    createFolder(userPath);
    createFolder(fullfile(userPath,"script"));
    createFolder(fullfile(userPath,"temp"));
    createFolder(fullfile(userPath,"atomData"));
    unzip("configDefault.zip",userPath)
    open(fullfile(userPath,"config","setConfig.m"))
    disp("Please edit the setConfig.m file if this is the firt time installing. " + newline + "You may clone " +...
        "a sameple MMUser folder from ... " + newline + "Once it's done, please run init agian.")
    msgbox("Please edit the setConfig.m file if this is the firt time installing. You may clone " +...
        "a sameple MMUser folder from ... Once it's done, please run init agian.")
    return
else
    disp(newline + "Detected MMUser folder already exists. I will not touch it...")
end

addpath(genpath_exclude(char(userPath),{'.git','testData','sampleData','.gitignore','.github','doc'}));
disp("Done.")

%% genpath from jhopkin
function p = genpath_exclude(d,excludeDirs)
% if the input is a string, then use it as the searchstr
if ischar(excludeDirs)
    excludeStr = excludeDirs;
else
    excludeStr = '';
    if ~iscellstr(excludeDirs)
        error('excludeDirs input must be a cell-array of strings');
    end

    for i = 1:length(excludeDirs)
        excludeStr = [excludeStr '|^' excludeDirs{i} '$'];
    end
end


% Generate path based on given root directory
files = dir(d);
if isempty(files)
    return
end

% Add d to the path even if it is empty.
p = [d pathsep];

% set logical vector for subdirectory entries in d
isdir = logical(cat(1,files.isdir));
%
% Recursively descend through directories which are neither
% private nor "class" directories.
%
dirs = files(isdir); % select only directory entries from the current listing

for i=1:length(dirs)
    dirname = dirs(i).name;
    %NOTE: regexp ignores '.', '..', '@.*', and 'private' directories by default.
    if ~any(regexp(dirname,['^\.$|^\.\.$|^\@.*|^private$|' excludeStr ],'start'))
        p = [p genpath_exclude(fullfile(d,dirname),excludeStr)]; % recursive calling of this function.
    end
end
end