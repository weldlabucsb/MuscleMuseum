function runLocalTest(testCiceroLogOrigin,samplePath,dataPath,pauseTime)
% Simulate file-watcher acquisition locally using sample data/logs.
%
% Copies triplets of TIFF images and corresponding Cicero ``.clg`` log files
% from a sample directory into a target data directory with delays between
% runs, emulating on-the-fly acquisition. Useful for offline testing of
% :class:`BecExp` without hardware.
%
% :param testCiceroLogOrigin: Destination folder watched for new ``.clg`` logs
% :type testCiceroLogOrigin: char|string
% :param samplePath: Source directory containing images and logfiles/logFiles
% :type samplePath: char|string
% :param dataPath: Destination data folder to receive copied images
% :type dataPath: char|string
% :param pauseTime: Delay [s] between consecutive simulated runs
% :type pauseTime: double
%
% **Example:**
%
% .. code-block:: matlab
%
%    runLocalTest("C:\\tmp\\watch", "C:\\samples", "C:\\tmp\\data", 0.5);
sampleLogPath = fullfile(samplePath,"logfiles");
sampleLogPath2 = fullfile(samplePath,"logFiles");

dataFormat = ".tif";
sampleDataList = dir(fullfile(samplePath,"*" + dataFormat));
sampleDataList = sampleDataList(~[sampleDataList.isdir]);
time = [sampleDataList.datenum];
sampleDataList = struct2cell(sampleDataList);
[~,sampleDataName,~] = fileparts(sampleDataList(1,:));
[~,idx] = sort(time);
% [~,idx] = sort(str2double(string((regexp(sampleDataName,'[^\_]*$','match')))));
sampleDataName = string(sampleDataName(idx));

sampleLogList = dir(fullfile(sampleLogPath,"*" + ".clg"));
time = [sampleLogList.datenum];
[~,idx] = sort(time);
sampleLogList = string({sampleLogList.name});
sampleLogList = sampleLogList(idx);

sampleLogList2 = dir(fullfile(sampleLogPath,"*" + ".clg"));
time = [sampleLogList2.datenum];
[~,idx] = sort(time);
sampleLogList2 = string({sampleLogList2.name});
sampleLogList2 = sampleLogList2(idx);


% sampleLogList2 = string(ls(sampleLogPath2));
% sampleLogList2 = sampleLogList2(3:end);
% sampleLogList2 = sort(sampleLogList2);



for iRun = 1:numel(sampleLogList)
    pause(pauseTime)
    copyfile(fullfile(samplePath,sampleDataName((iRun-1)*3+1)+'.tif'),fullfile(dataPath,sampleDataName((iRun-1)*3+1)+'.tif'))
    pause(0.1)
    copyfile(fullfile(samplePath,sampleDataName((iRun-1)*3+2)+'.tif'),fullfile(dataPath,sampleDataName((iRun-1)*3+2)+'.tif'))
    pause(0.1)
    copyfile(fullfile(samplePath,sampleDataName((iRun-1)*3+3)+'.tif'),fullfile(dataPath,sampleDataName((iRun-1)*3+3)+'.tif'))
    try
        copyfile(fullfile(sampleLogPath,sampleLogList(iRun)),fullfile(testCiceroLogOrigin,sampleLogList(iRun)))
    catch
        copyfile(fullfile(sampleLogPath2,sampleLogList2(iRun)),fullfile(testCiceroLogOrigin,sampleLogList2(iRun)))
    end
end
end

