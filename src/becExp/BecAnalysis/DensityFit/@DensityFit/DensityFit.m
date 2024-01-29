classdef DensityFit < BecAnalysis
    %OD Summary of this class goes here
    %   Detailed explanation goes here

    properties
        FitMethod string = "BosonicGaussianFit1D"
        FitDataX
        FitDataY
    end

    properties (SetAccess = protected)
        ThermalCloudCenter %[x0t;y0t] in pixel
        ThermalCloudSize % [wt_x;wt_y] in m
        ThermalCloudCentralDensity % m^-2
        CondensateCenter %[x0c;y0c] in pixel
        CondensateSize % [wc_x;wc_y] in m
        CondensateCentralDensity % m^-2
        BackGroundDensity % m^-2
    end

    methods
        function obj = DensityFit(becExp)
            %OD Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Gui(1) = Gui(...
                name = "DensityFitDisplay",...
                fpath = fullfile(becExp.DataAnalysisPath,"DensityFit"),...
                loc = [0.003125,0.032],...
                size = [0.38984375,0.330]...
                );
        end

        function initialize(obj)
            obj.Gui(1).initialize(obj.BecExp)

            if isempty(obj.BecExp.Roi.SubRoi)
                obj.ThermalCloudCenter = [0;0];
                obj.ThermalCloudSize = [0;0];
                obj.ThermalCloudCentralDensity = 0;
                obj.CondensateCenter = [0;0];
                obj.CondensateSize = [0;0];
                obj.CondensateCentralDensity = 0;
                obj.BackGroundDensity = 0;
            else
                obj.ThermalCloudCenter = zeros(2,1,1);
                obj.ThermalCloudSize = zeros(2,1,1);
                obj.ThermalCloudCentralDensity = zeros(1,1,1);
                obj.CondensateCenter = zeros(2,1,1);
                obj.CondensateSize = zeros(2,1,1);
                obj.CondensateCentralDensity = zeros(1,1,1);
                obj.BackGroundDensity = zeros(1,1,1);
            end

            xList = obj.BecExp.Roi.XList;
            yList = obj.BecExp.Roi.YList;

            if isempty(obj.BecExp.Roi.SubRoi)
                nSub = 1;
            else
                nSub = numel(obj.BecExp.Roi.SubRoi);
            end

            switch obj.FitMethod
                case "GaussianFit1D"
                    obj.FitDataX = GaussianFit1D([xList,xList]);
                    obj.FitDataY = GaussianFit1D([yList,yList]);
                case "BosonicGaussianFit1D"
                    obj.FitDataX = BosonicGaussianFit1D([xList,xList]);
                    obj.FitDataY = BosonicGaussianFit1D([yList,yList]);
            end

            obj.FitDataX = repmat(obj.FitDataX,1,1,nSub);
            obj.FitDataY = repmat(obj.FitDataY,1,1,nSub);
        end

        function updateData(obj,runIdx)
            becExp = obj.BecExp;
            px = becExp.Acquisition.PixelSizeReal;
            nRun = numel(runIdx);
            if isempty(becExp.Roi.SubRoi)
                nSub = 1;
            else
                nSub = numel(becExp.Roi.SubRoi);
            end

            %% Initialize the fit objects
            switch obj.FitMethod
                case "GaussianFit1D"
                    fitDataX = GaussianFit1D([1,1]);
                    fitDataY = GaussianFit1D.empty([1,1]);
                case "BosonicGaussianFit1D"
                    fitDataX = BosonicGaussianFit1D([1,1]);
                    fitDataY = BosonicGaussianFit1D([1,1]);
            end

            fitDataX = repmat(fitDataX,1,nRun,nSub);
            fitDataY = repmat(fitDataY,1,nRun,nSub);

            %% Assign data to the fit objects
            for ii = 1:nRun
                if isempty(becExp.Roi.SubRoi)
                    adData = becExp.Ad.AdData(:,:,runIdx(ii));
                else
                    adData = becExp.Roi.selectSub(becExp.Ad.AdData(:,:,runIdx(ii)));
                end
                for jj = 1:nSub
                    if isempty(becExp.Roi.SubRoi)
                        xList = obj.BecExp.Roi.XList;
                        yList = obj.BecExp.Roi.YList;
                        xRaw = sum(adData,1).'*px;
                        yRaw = sum(adData,2)*px;
                    else
                        xList = obj.BecExp.Roi.SubRoi(jj).XList;
                        yList = obj.BecExp.Roi.SubRoi(jj).YList;
                        xRaw = sum(adData{jj},1).'*px;
                        yRaw = sum(adData{jj},2)*px;
                    end
                    switch obj.FitMethod
                        case "GaussianFit1D"
                            fitDataX(1,ii,jj) = GaussianFit1D([xList,xRaw]);
                            fitDataY(1,ii,jj) = GaussianFit1D([yList,yRaw]);
                        case "BosonicGaussianFit1D"
                            fitDataX(1,ii,jj) = BosonicGaussianFit1D([xList,xRaw]);
                            fitDataY(1,ii,jj) = BosonicGaussianFit1D([yList,yRaw]);
                    end
                end
            end

            %% Do fit
            if nRun*nSub > 1
                p = gcp('nocreate');
                if ~isempty(p)
                    parfor ii = 1:nRun*nSub
                        fitDataX(ii) = fitDataX(ii).do;
                        fitDataY(ii) = fitDataY(ii).do;
                    end
                else
                    for ii = 1:nRun*nSub
                        fitDataX(ii) = fitDataX(ii).do;
                        fitDataY(ii) = fitDataY(ii).do;
                    end
                end
                obj.FitDataX(1,runIdx,1:nSub) = fitDataX;
                obj.FitDataY(1,runIdx,1:nSub) = fitDataY;
            else
                fitDataX.do;
                fitDataY.do;
                obj.FitDataX(1,runIdx,1:nSub) = fitDataX;
                obj.FitDataY(1,runIdx,1:nSub) = fitDataY;
            end

            %% Assign values to properties
            for ii = runIdx
                for jj = 1:nSub
                    switch obj.FitMethod
                        case "GaussianFit1D"
                            amp = [obj.FitDataX(1,ii,jj).Coefficient(1);...
                                obj.FitDataY(1,ii,jj).Coefficient(1)];
                            obj.ThermalCloudCenter(:,ii,jj) = px * [obj.FitDataX(1,ii,jj).Coefficient(2);...
                                obj.FitDataY(1,ii,jj).Coefficient(2)];
                            obj.ThermalCloudSize(:,ii,jj) = sqrt(2) * px * ...
                                [obj.FitDataX(1,ii,jj).Coefficient(3);obj.FitDataY(1,ii,jj).Coefficient(3)];
                            obj.ThermalCloudCentralDensity(1,ii,jj) = ...
                                mean(amp/sqrt(2*pi)./flip(obj.ThermalCloudSize(:,ii,jj)));
                        case "BosonicGaussianFit1D"
                            amp = [obj.FitDataX(1,ii,jj).Coefficient(1);...
                                obj.FitDataY(1,ii,jj).Coefficient(1)];
                            obj.ThermalCloudCenter(:,ii,jj) = px * [obj.FitDataX(1,ii,jj).Coefficient(2);...
                                obj.FitDataY(1,ii,jj).Coefficient(2)];
                            obj.ThermalCloudSize(:,ii,jj) = sqrt(2) * px * ...
                                [obj.FitDataX(1,ii,jj).Coefficient(3);obj.FitDataY(1,ii,jj).Coefficient(3)];
                            obj.ThermalCloudCentralDensity(1,ii,jj) = ...
                                mean(amp*boseFunction(1,2)/sqrt(pi)./flip(obj.ThermalCloudSize(:,ii,jj)));
                    end
                end
            end
        end

        function updateFigure(obj,~)
            obj.Gui(1).update
        end

        function refresh(obj)
            obj.initialize;
            nRun = obj.BecExp.NCompletedRun;
            obj.updateData(1:nRun);
            obj.updateFigure(1);
        end

    end
end

