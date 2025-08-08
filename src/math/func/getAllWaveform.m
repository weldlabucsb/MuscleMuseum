function nameList = getAllWaveform()
    % Get all Waveform class names in the current path.
    %
    % Searches for all MATLAB class files that inherit from :class:`Waveform`
    % and returns their names as a string array. This includes direct subclasses
    % and deeper inheritance levels.
    %
    % :return: Array of Waveform class names
    % :rtype: string array
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %     waveformClasses = getAllWaveform();
    %     disp(waveformClasses);
    %
    name = "Waveform";
    parentFolder = findFolderInPath(name);
    fileList = dir(fullfile(parentFolder,"*.m"));
    nameList = string.empty;
    for ii = 1:numel(fileList)
        try
            cName = fileList(ii).name;
            cName = string(cName(1:end-2));
            mc = eval("metaclass("+ cName +".empty)");
            scList = string({mc.SuperclassList.Name});
            if any(scList==name)
                nameList = [nameList;cName];
            else
                for jj = 1:numel(mc.SuperclassList)
                    sscList = string({mc.SuperclassList(jj).SuperclassList.Name});
                    if any(sscList==name)
                        nameList = [nameList;cName];
                    else
                        for kk = 1:numel(mc.SuperclassList(jj).SuperclassList)
                            sscList = string({mc.SuperclassList(jj).SuperclassList(kk).SuperclassList.Name});
                            if any(sscList==name)
                                nameList = [nameList;cName];
                            end
                        end
                    end
                end
            end
        catch
        end
    end
end

