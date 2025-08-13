classdef DensityFit < BecAnalysis
    %OD Summary of this class goes here
    %   Detailed explanation goes here

    properties
        FitMethod string = "BosonicGaussianFit1D"
        FitData
        DensityLimX double = [0,1]
        DensityLimY double = [0,1]
    end

    properties (SetAccess = protected)
        ThermalCloudCenter %[x0t;y0t] in pixel
        ThermalCloudSize % [wt_x;wt_y] in m
        ThermalCloudCentralDensity % m^-2
        CondensateCenter %[x0c;y0c] in pixel
        CondensateSize % [wc_x;wc_y] in m
        CondensateCentralDensity % m^-2
        BackGroundDensity % m^-2
        LineIntegrationLength % [Lx; Ly] in m
    end

    properties (Hidden, Transient)
        ThermalXLine matlab.graphics.chart.primitive.ErrorBar
        ThermalYLine matlab.graphics.chart.primitive.ErrorBar
        CondensateXLine matlab.graphics.chart.primitive.ErrorBar
        CondensateYLine matlab.graphics.chart.primitive.ErrorBar
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
            obj.Chart(1) = Chart(...
                name = "Cloud size",...
                num = 33, ...
                fpath = fullfile(becExp.DataAnalysisPath,"CloudSize"),...
                loc = [0.6936,0.032],...
                size = [0.3069,0.57]...
                );
        end

        function initialize(obj)
            becExp = obj.BecExp;
            nSub = becExp.Roi.NSub;
            nSub(nSub == 0) = 1;
            obj.DensityLimX = [0,1];
            obj.DensityLimY = [0,1];

            %% Initialize data
            obj.ThermalCloudCenter = zeros(2,1,nSub);
            obj.ThermalCloudSize = zeros(2,1,nSub);
            obj.ThermalCloudCentralDensity = zeros(1,1,nSub);
            obj.CondensateCenter = zeros(2,1,nSub);
            obj.CondensateSize = zeros(2,1,nSub);
            obj.CondensateCentralDensity = zeros(1,1,nSub);
            obj.BackGroundDensity = zeros(1,1,nSub);
            obj.LineIntegrationLength = zeros(2,1, nSub); % added this

            %% Initialize fit objects
            switch obj.FitMethod
                case "GaussianFit1D"
                    obj.FitData = GaussianFit1D([1,1]);
                case "BosonicGaussianFit1D"
                    obj.FitData = BosonicGaussianFit1D([1,1]);
                % added this
                case "BosonicBimodalFit1D"
                    obj.FitData = BosonicBimodalFit1D([1,1]);
            end
            obj.FitData = repmat(obj.FitData,2,1,nSub);

            %% Initialize plots
            obj.Gui(1).initialize(becExp)
            fig = obj.Chart(1).initialize;

            %% Initialize cloud size plots
            if ~ishandle(fig)
                return
            end

            % Initialize axis
            t = tiledlayout(fig,2,1);
            t.TileSpacing = 'compact';
            t.Padding = 'compact';
            ax1 = nexttile(t);
            ax2 = nexttile(t);
            co = ax1.ColorOrder;
            mOrder = markerOrder();

            hold(ax1,'on')
            hold(ax2,'on')
            % Initialize thermal and condensate plots
                switch obj.FitMethod
                    case {"GaussianFit1D","BosonicGaussianFit1D"}
                        for ii = 1:nSub
                            obj.ThermalXLine(ii) = errorbar(ax1,1,1,[]);
                            obj.ThermalXLine(ii).Marker = mOrder(ii);
                            obj.ThermalXLine(ii).MarkerFaceColor = co(ii,:);
                            obj.ThermalXLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.ThermalXLine(ii).MarkerSize = 8;
                            obj.ThermalXLine(ii).LineWidth = 2;
                            obj.ThermalXLine(ii).Color = co(ii,:); 
                            obj.ThermalXLine(ii).CapSize = 0;

                            obj.ThermalYLine(ii) = errorbar(ax2,1,1,[]);
                            obj.ThermalYLine(ii).Marker = mOrder(ii);
                            obj.ThermalYLine(ii).MarkerFaceColor = co(ii,:);
                            obj.ThermalYLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.ThermalYLine(ii).MarkerSize = 8;
                            obj.ThermalYLine(ii).LineWidth = 2;
                            obj.ThermalYLine(ii).Color = co(ii,:); 
                            obj.ThermalYLine(ii).CapSize = 0;
                        end
                        if isempty(becExp.Roi.SubRoi)
                            legendStr = "Thermal";
                        else
                            legendStr = arrayfun(@(x) "Thermal " + x,1:nSub);
                        end
                        lg1 = legend(ax1,legendStr(:));
                        lg2 = legend(ax2,legendStr(:));

                    case "BosonicBimodalFit1D"
                        for ii = 1:nSub
                            % Thermal lines
                            obj.ThermalXLine(ii) = errorbar(ax1,1,1,[]);
                            obj.ThermalXLine(ii).Marker = mOrder(ii);
                            obj.ThermalXLine(ii).MarkerFaceColor = co(ii,:);
                            obj.ThermalXLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.ThermalXLine(ii).MarkerSize = 8;
                            obj.ThermalXLine(ii).LineWidth = 2;
                            obj.ThermalXLine(ii).Color = co(ii,:);
                            obj.ThermalXLine(ii).CapSize = 0;
                
                            obj.ThermalYLine(ii) = errorbar(ax2,1,1,[]);
                            obj.ThermalYLine(ii).Marker = mOrder(ii);
                            obj.ThermalYLine(ii).MarkerFaceColor = co(ii,:);
                            obj.ThermalYLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.ThermalYLine(ii).MarkerSize = 8;
                            obj.ThermalYLine(ii).LineWidth = 2;
                            obj.ThermalYLine(ii).Color = co(ii,:);
                            obj.ThermalYLine(ii).CapSize = 0;
                
                            % Condensate lines
                            obj.CondensateXLine(ii) = errorbar(ax1,1,1,[]);
                            obj.CondensateXLine(ii).Marker = mOrder(ii);
                            obj.CondensateXLine(ii).MarkerFaceColor = 'none';
                            obj.CondensateXLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.CondensateXLine(ii).MarkerSize = 8;
                            obj.CondensateXLine(ii).LineWidth = 2;
                            obj.CondensateXLine(ii).LineStyle = '--';
                            obj.CondensateXLine(ii).Color = co(ii,:)*.7;
                            obj.CondensateXLine(ii).CapSize = 0;
                
                            obj.CondensateYLine(ii) = errorbar(ax2,1,1,[]);
                            obj.CondensateYLine(ii).Marker = mOrder(ii);
                            obj.CondensateYLine(ii).MarkerFaceColor = 'none';
                            obj.CondensateYLine(ii).MarkerEdgeColor = co(ii,:)*.5;
                            obj.CondensateYLine(ii).MarkerSize = 8;
                            obj.CondensateYLine(ii).LineWidth = 2;
                            obj.CondensateYLine(ii).LineStyle = '--';
                            obj.CondensateYLine(ii).Color = co(ii,:)*.7;
                            obj.CondensateYLine(ii).CapSize = 0;
                        end
                
                        
                        if isempty(becExp.Roi.SubRoi)
                            legendStr = ["Thermal","Condensate"];
                        else
                            legendStr = strings(1,2*nSub);
                            k = 1;
                            for ii = 1:nSub
                                legendStr(k)   = "Thermal "    + ii; k = k+1;
                                legendStr(k)   = "Condensate " + ii; k = k+1;
                            end
                        end
                        lg1 = legend(ax1,legendStr(:));
                        lg2 = legend(ax2,legendStr(:));

                end
            hold(ax1,'off')
            hold(ax2,'off')

            % Change axis properties
            ax1.Box = "on";
            ax1.XGrid = "on";
            ax1.YGrid = "on";
            ax1.YLabel.String = "$R_x$ [$\mu\mathrm{m}$]";
            ax1.YLabel.Interpreter = "latex";
            ax1.FontSize = 12;

            ax2.Box = "on";
            ax2.XGrid = "on";
            ax2.YGrid = "on";
            ax2.XLabel.String = obj.BecExp.XLabel;
            ax2.XLabel.Interpreter = "latex";
            ax2.YLabel.String = "$R_y$ [$\mu\mathrm{m}$]";
            ax2.YLabel.Interpreter = "latex";
            ax2.FontSize = 12;
            
            if numel(lg1.String) >= 8
                lg1.NumColumns = 2;
                lg1.FontSize = 8;
                lg1.Location = "best";
                lg2.NumColumns = 2;
                lg2.FontSize = 8;
                lg2.Location = "best";
            end
        end

        function updateData(obj,runIdx)
            becExp = obj.BecExp;
            px = becExp.Acquisition.PixelSizeReal;
            nRun = numel(runIdx);
            nSub = obj.BecExp.Roi.NSub;
            nSub(nSub == 0) = 1;

            %% Initialize fit objects
            switch obj.FitMethod
                case "GaussianFit1D"
                    fitData = GaussianFit1D([1,1]);
                case "BosonicGaussianFit1D"
                    fitData = BosonicGaussianFit1D([1,1]);
                % added this
                case "BosonicBimodalFit1D"
                    fitData = BosonicBimodalFit1D([1,1]);
            end
            fitData = repmat(fitData,2,nRun,nSub);

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
                    % added this
                    Lx = numel(xList)*px;
                    Ly = numel(yList)*px;
                    obj.LineIntegrationLength(:,ii,jj) = [Lx; Ly];

                    switch obj.FitMethod
                        case "GaussianFit1D"
                            fitData(1,ii,jj) = GaussianFit1D([xList,xRaw]);
                            fitData(2,ii,jj) = GaussianFit1D([yList,yRaw]);
                        case "BosonicGaussianFit1D"
                            fitData(1,ii,jj) = BosonicGaussianFit1D([xList,xRaw]);
                            fitData(2,ii,jj) = BosonicGaussianFit1D([yList,yRaw]);
                        % added this
                        case "BosonicBimodalFit1D"
                            fitData(1,ii,jj) = BosonicBimodalFit1D([xList,xRaw]);
                            fitData(2,ii,jj) = BosonicBimodalFit1D([yList,yRaw]);
                    end
                    if min(xRaw)<obj.DensityLimX(1)
                        obj.DensityLimX(1) = min(xRaw);
                    end
                    if max(xRaw)>obj.DensityLimX(2)
                        obj.DensityLimX(2) = max(xRaw);
                    end
                    if min(yRaw)<obj.DensityLimY(1)
                        obj.DensityLimY(1) = min(yRaw);
                    end
                    if max(yRaw)>obj.DensityLimY(2)
                        obj.DensityLimY(2) = max(yRaw);
                    end
                end
            end

            %% Do fit
            p = gcp('nocreate');
            if isempty(p) || nRun == 1 || p.NumWorkers <= 2
                for ii = 1:numel(fitData)
                    fitData(ii) = fitData(ii).do;
                end
            else
                n = numel(fitData);
                futures(n) = parallel.FevalFuture;

                % Submit parfeval jobs
                for ii = 1:n
                    futures(ii) = parfeval(@doFit, 1, fitData(ii));  % 1 output
                end

                % Collect results as they finish
                results = fitData;  % preallocate with same type
                for ii = 1:n
                    [completedIdx, value] = fetchNext(futures);
                    results(completedIdx) = value;
                end
                fitData = reshape(results,size(fitData));
            end
            obj.FitData(:,runIdx,1:nSub) = fitData;

            function results = doFit(fitObj)
                results = fitObj.do;
            end

            %% Assign values to properties
            for ii = runIdx
                for jj = 1:nSub
                    switch obj.FitMethod
                        case "GaussianFit1D"
                            amp = [obj.FitData(1,ii,jj).Coefficient(1);...
                                obj.FitData(2,ii,jj).Coefficient(1)];
                            obj.ThermalCloudCenter(:,ii,jj) = px * [obj.FitData(1,ii,jj).Coefficient(2);...
                                obj.FitData(2,ii,jj).Coefficient(2)];
                            obj.ThermalCloudSize(:,ii,jj) = sqrt(2) * px * ...
                                [obj.FitData(1,ii,jj).Coefficient(3);obj.FitData(2,ii,jj).Coefficient(3)];
                            obj.ThermalCloudCentralDensity(1,ii,jj) = ...
                                mean(amp/sqrt(2*pi)./flip(obj.ThermalCloudSize(:,ii,jj)));
                        case "BosonicGaussianFit1D"
                            amp = [obj.FitData(1,ii,jj).Coefficient(1);...
                                obj.FitData(2,ii,jj).Coefficient(1)];
                            obj.ThermalCloudCenter(:,ii,jj) = px * [obj.FitData(1,ii,jj).Coefficient(2);...
                                obj.FitData(2,ii,jj).Coefficient(2)];
                            obj.ThermalCloudSize(:,ii,jj) = sqrt(2) * px * ...
                                [obj.FitData(1,ii,jj).Coefficient(3);obj.FitData(2,ii,jj).Coefficient(3)];
                            obj.ThermalCloudCentralDensity(1,ii,jj) = ...
                                mean(amp*boseFunction(1,2)/sqrt(pi)./flip(obj.ThermalCloudSize(:,ii,jj)));
                        % added this
                        case "BosonicBimodalFit1D"
                            % Thermal
                            ampT = [obj.FitData(1,ii,jj).Coefficient(4); obj.FitData(2,ii,jj).Coefficient(4)];
                            xg   = [obj.FitData(1,ii,jj).Coefficient(5); obj.FitData(2,ii,jj).Coefficient(5)];
                            sg   = [obj.FitData(1,ii,jj).Coefficient(6); obj.FitData(2,ii,jj).Coefficient(6)];
                    
                            obj.ThermalCloudCenter(:,ii,jj) = px * xg;
                            obj.ThermalCloudSize(:,ii,jj)   = sqrt(2) * px * sg;
                            obj.ThermalCloudCentralDensity(1,ii,jj) = mean(ampT./(sqrt(2*pi).*flip(obj.ThermalCloudSize(:,ii,jj))));
                    
                            % Condensate
                            A_tf = [obj.FitData(1,ii,jj).Coefficient(1); obj.FitData(2,ii,jj).Coefficient(1)];
                            x0   = [obj.FitData(1,ii,jj).Coefficient(2); obj.FitData(2,ii,jj).Coefficient(2)];
                            R_tf = [obj.FitData(1,ii,jj).Coefficient(3); obj.FitData(2,ii,jj).Coefficient(3)];
                            C_bg = [obj.FitData(1,ii,jj).Coefficient(7); obj.FitData(2,ii,jj).Coefficient(7)];
                    
                            obj.CondensateCenter(:,ii,jj)        = px * x0;
                            obj.CondensateSize(:,ii,jj)          = px * R_tf;

                            TFconst = (3*pi/8);
                            n0_x = A_tf(1) / (TFconst * obj.CondensateSize(2,ii,jj));
                            n0_y = A_tf(2) / (TFconst * obj.CondensateSize(1,ii,jj));
                            obj.CondensateCentralDensity(1,ii,jj) = mean([n0_x, n0_y]);

                            LxLy = obj.LineIntegrationLength(:,ii,jj);
                            nbg_x = C_bg(1) / LxLy(2);
                            nbg_y = C_bg(2) / LxLy(1);
                            obj.BackGroundDensity(1,ii,jj) = mean([nbg_x, nbg_y]);
                            
                    end
                end
            end
        end

        function updateFigure(obj,~)
            obj.Gui(1).update
            fig = obj.Chart(1).Figure;
            if isempty(fig) || ~ishandle(fig)
                return
            end

            becExp = obj.BecExp;
            nSub = becExp.Roi.NSub;
            nSub(nSub == 0) = 1;
            paraList = becExp.ScannedParameterList;

            switch obj.FitMethod
                case {"GaussianFit1D","BosonicGaussianFit1D"}
                    for ii = 1:nSub
                        [xThermalX,yThermalX,stdThermalX] = computeStd(paraList,obj.ThermalCloudSize(1,:,ii) * 1e6, becExp.AveragingMethod);
                        [xThermalY,yThermalY,stdThermalY] = computeStd(paraList,obj.ThermalCloudSize(2,:,ii) * 1e6, becExp.AveragingMethod);
                        obj.ThermalXLine(ii).XData = xThermalX;
                        obj.ThermalXLine(ii).YData = yThermalX;
                        obj.ThermalXLine(ii).YNegativeDelta = stdThermalX;
                        obj.ThermalXLine(ii).YPositiveDelta = stdThermalX;
                        obj.ThermalYLine(ii).XData = xThermalY;
                        obj.ThermalYLine(ii).YData = yThermalY;
                        obj.ThermalYLine(ii).YNegativeDelta = stdThermalY;
                        obj.ThermalYLine(ii).YPositiveDelta = stdThermalY;
                    end

                case "BosonicBimodalFit1D"
                    for ii = 1:nSub
                        % Thermal
                        [xThX,yThX,stdThX] = computeStd(paraList,obj.ThermalCloudSize(1,:,ii) * 1e6, becExp.AveragingMethod);
                        [xThY,yThY,stdThY] = computeStd(paraList,obj.ThermalCloudSize(2,:,ii) * 1e6, becExp.AveragingMethod);
            
                        obj.ThermalXLine(ii).XData = xThX;
                        obj.ThermalXLine(ii).YData = yThX;
                        obj.ThermalXLine(ii).YNegativeDelta = stdThX;
                        obj.ThermalXLine(ii).YPositiveDelta = stdThX;
            
                        obj.ThermalYLine(ii).XData = xThY;
                        obj.ThermalYLine(ii).YData = yThY;
                        obj.ThermalYLine(ii).YNegativeDelta = stdThY;
                        obj.ThermalYLine(ii).YPositiveDelta = stdThY;
            
                        % Condensate
                        [xCx,yCx,stdCx] = computeStd(paraList,obj.CondensateSize(1,:,ii) * 1e6, becExp.AveragingMethod);
                        [xCy,yCy,stdCy] = computeStd(paraList,obj.CondensateSize(2,:,ii) * 1e6, becExp.AveragingMethod);
            
                        obj.CondensateXLine(ii).XData = xCx;
                        obj.CondensateXLine(ii).YData = yCx;
                        obj.CondensateXLine(ii).YNegativeDelta = stdCx;
                        obj.CondensateXLine(ii).YPositiveDelta = stdCx;
            
                        obj.CondensateYLine(ii).XData = xCy;
                        obj.CondensateYLine(ii).YData = yCy;
                        obj.CondensateYLine(ii).YNegativeDelta = stdCy;
                        obj.CondensateYLine(ii).YPositiveDelta = stdCy;
                    end


            end
            lg = findobj(fig,"Type","Legend");
            [lg.Location] = deal("best");
            
            %% Update Line connection
            l = findobj(fig,"Type","Line");
            le = findobj(fig,"Type","ErrorBar");
            if becExp.AveragingMethod == "None"
                if ~isempty(l)
                    [l.LineStyle] = deal("none");
                end
                if ~isempty(le)
                    [le.LineStyle] = deal("none");
                end
            else
                if ~isempty(l)
                    [l.LineStyle] = deal("-");
                end
                if ~isempty(le)
                    [le.LineStyle] = deal("-");
                end
            end
        end

        function refresh(obj)
            obj.initialize;
            nRun = obj.BecExp.NCompletedRun;
            obj.updateData(1:nRun);
            obj.updateFigure(1);
        end

    end
end

