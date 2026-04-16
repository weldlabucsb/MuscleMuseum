%% Set Path
disp(newline + "Setting path...")
addpath(genpath_exclude(pwd,{'.git','testData','sampleData','.gitignore','.github','doc'}));
userPath = fullfile(getHome,"Documents","MMUser");

if exist(userPath,'dir')==0
    disp(newline + "Detected it is the first time installing. Creating config files...")
    createFolder(userPath);
    createFolder(fullfile(userPath,"script"));
    createFolder(fullfile(userPath,"temp"));
    unzip("MMUserDefault.zip",userPath)
    open(fullfile(userPath,"config","mmConfig.m"))
    disp("Please edit the mmConfig.m file if this is the firt time installing. " + newline + "You may clone " +...
        "a sameple MMUser folder from https://github.com/weldlabucsb/MMUser." + newline + "Once it's done, please run init agian.")
    msgbox("Please edit the mmConfig.m file if this is the firt time installing. You may clone " +...
        "a sameple MMUser folder from https://github.com/weldlabucsb/MMUser. Once it's done, please run init agian.")
    return
else
    disp(newline + "Detected MMUser folder already exists. I will not touch it...")
end

addpath(genpath_exclude(char(userPath),{'.git','testData','sampleData','.gitignore','.github','doc'}));
disp("Done.")

%% Check MATLAB version
disp(newline + "Checking MATLAB version...")
vers = version('-release');
if string(vers) == "2023b" || str2double(vers(1:4))>2023
    warning(['MuscleMuseum is only compatible with MATLAB 2023a or earlier versions. ' ...
        'Newer MATLAB releases may break the database functions of this package.'])
elseif str2double(vers(1:4)) < 2020
    warning('MATLAB version is too old. Try MATLAB 2023a.')
else
    disp("MATLAB version [" + string(vers) + "] is good.")
end

%% Check MATLAB packages
disp(newline + "Checking MATLAB packages...")
packageList = getPackageList;
requiredPackageList = [
    "Data Acquisition Toolbox",...
    "Curve Fitting Toolbox",...
    "Database Toolbox",...
    "Image Processing Toolbox",...
    "Parallel Computing Toolbox",...
    "Instrument Control Toolbox",...
    "Signal Processing Toolbox",...
    "Navigation Toolbox",...
    "Statistics and Machine Learning Toolbox"
    ];
missedPackageList = requiredPackageList(~ismember(requiredPackageList,packageList));
if ~isempty(missedPackageList)
    warning("Packages " + strjoin("["+ missedPackageList + "]",", ") + " are missing. Please " + ...
        "install those packages.")
else
    disp("Required MATLAB packages are installed.")
end

%% Set Python
setPython;

%% Set Parameter
setParameter;

%% Set DataBase
setDatabase;

%% Set Color Order
disp(newline + "Setting color order...")
newcolors = slanCL(617,1:80);
set(groot, "defaultaxescolororder", newcolors)
disp("Done.")

clear
close all

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