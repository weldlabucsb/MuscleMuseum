function saveBecImageAbsorption(vid,~,becExp)
% saveBecImageAbsorption Save 3-frame absorption images and notify analysis.
%
% Callback for a VideoInput FramesAvailable event that acquires three images
% ("atom", "light", "dark"), writes them to disk, transfers processed data
% to the experiment object, and triggers the :code:`NewRunFinished` event.
%
% :param vid: VideoInput handle or numeric buffer (Andor path)
% :type vid: videoinput | double array
% :param becExp: Experiment controller with Acquisition and paths
% :type becExp: object

%% Set BecExp to be at acquiring
becExp.IsAcquiring = true;

%% Get data from camera
if ~isnumeric(vid)
    mData = getdata(vid,3);
else
    % This is for Andor
    mData = vid;
end

%% Name the data
nn = num2str(becExp.NCompletedRun + 1);
imageName = fullfile(becExp.DataPath,becExp.DataPrefix) + "_" + nn;
imageFormat = becExp.DataFormat;
imageLabel = ["_atom";"_light";"_dark"];

%% Write the data to files
for ii = 1:3
    fullFilePath = imageName + imageLabel(ii) + imageFormat;
    if imageFormat == ".tif"
        t = Tiff(fullFilePath,'w');
        setTag(t,'ImageWidth',double(becExp.Acquisition.ImageSize(2)));
        setTag(t,'ImageLength',double(becExp.Acquisition.ImageSize(1)));
        setTag(t,'Photometric',Tiff.Photometric.MinIsBlack)
        setTag(t,'BitsPerSample',double(becExp.Acquisition.BitsPerSample));
        setTag(t,'SamplesPerPixel',1);
        setTag(t,'Compression',Tiff.Compression.None);
        setTag(t,'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky)
        setTag(t,'RowsPerStrip',1)
        write(t,mData(:,:,ii));
        close(t)
    else
        imwrite(mData(:,:,ii), fullFilePath);
    end
end

%% Transfer data to becExp and trigger the event
becExp.TempData = becExp.Acquisition.killBadPixel(double(mData));
notify(becExp,'NewRunFinished')
becExp.IsAcquiring = false;

end