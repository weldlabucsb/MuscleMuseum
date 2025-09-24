classdef Ad < BecAnalysis
    %:class:`Ad` compute atomic column density (AD) from OD and imaging config.
    %
    % Converts optical depth (:class:`Od`) to atomic column density using
    % a chosen cross section model (:attr:`AdMethod`). Supports uniform and
    % spatially varying saturation corrections via :attr:`CrossSectionData`
    % and :attr:`Imaging.SaturationParameterPropagation`. Provides preview
    % GUI and renders 1D mosaics or 2D density maps, with optional GIF export.
    %
    % **Associated Charts:**
    %   - Chart(1): "AdMix" - Horizontal mosaic or 2D density plot of atomic density
    %   - Chart(2): "AdAnimation" - Animated GIF showing AD evolution
    %
    % **Associated GUIs:**
    %   - Gui(1): "AtomPreviewer" - Real-time preview of atomic density data

    properties (Transient)
        AdData double % Atomic column density :math:`n_\mathrm{col}` per run [m^{-2}]
    end

    properties
        AdMethod string = "StrongLight" % Cross-section model: "TwoLevelWeakLight"|"RandomPolarization"|"UniformStrongLight"|"StrongLight"|"PhaseContrastImaging"
        Colormap = jet % Colormap function handle for atomic density visualization
    end

    properties (SetAccess = private)
        CrossSectionData double = [] % Cross-section lookup table with columns [:math:`s`, :math:`\sigma(s)/\sigma_0`] for saturation-dependent scattering
    end

    properties (SetObservable)
        CLim double = [0,8] % Color axis limits for atomic density plots in units of :attr:`Unit` [m^{-2}]
    end

    properties (Constant)
        Blur = 100 % Gaussian blur kernel size [pixels] applied to saturation-dependent cross-section maps
        Unit = 1e13; % Display scale factor for atomic density values [m^{-2}]
    end

    methods
        function obj = Ad(becExp)
            % Construct :class:`Ad` analyzer.
            %
            % :param becExp: Owning experiment
            % :type becExp: :class:`BecExp`
            obj@BecAnalysis(becExp)
            obj.Gui(1) = Gui(...
                name = "AtomPreviewer",...
                fpath = fullfile(becExp.DataAnalysisPath,"Ad"),...
                loc = [0.003125,0.387037037],...
                size = [0.38984375,0.587037], ...
                isEnabled = true...
                );

            obj.Chart(1) = Chart(...
                name = "AdMix",...
                num = 25, ...
                fpath = fullfile(becExp.DataAnalysisPath,"AdMix"),...
                loc = "center",...
                size = "full"...
                );
            obj.Chart(2) = Chart(...
                name = "AdAnimation",...
                num = 26, ...
                fpath = fullfile(becExp.DataAnalysisPath,"AdAnimation"),...
                loc = "center",...
                size = "large",...
                isGif = true...
                );

            % Load cross section data
            load("CrossSectionData.mat","CrossSectionData")
            t = CrossSectionData(CrossSectionData.ImagingStage...
                == becExp.Imaging.ImagingStage,:);
            if ~isempty(t)
                obj.CrossSectionData = t.CrossSection{1};
            end
        end
    end

    methods

        function initialize(obj)
            % Initialize data storage and preview GUI interface.
            %
            % Sets up atomic density data arrays, launches the atomic density
            % previewer application, configures OD preview mode, and establishes
            % property change listeners for color limits.
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            obj.AdData = zeros([roiSize,1]);

            obj.Gui(1).initialize(obj.BecExp) % invoke AdPreviewer
            obj.Gui(1).App.IsOd = obj.BecExp.IsOdPreview;
            obj.Gui(1).App.updateLabel;
            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
        end

        function update(obj,runIdx)
            % Compute atomic column density from optical depth for given run.
            %
            % Converts optical depth to atomic column density using the selected
            % cross-section model, accounting for saturation effects when applicable.
            %
            % :param runIdx: Run index to process
            % :type runIdx: double
            becExp = obj.BecExp;
            sigma0 = becExp.Atom.CyclerCrossSection;
            sigmaData = obj.CrossSectionData;

            function si = crossSec(s)
                si = sigma0 * interp1(sigmaData(:,1),sigmaData(:,2),s,'linear');
            end

            % Calculate AD from OD using selected cross-section model
            switch obj.AdMethod
                case "TwoLevelWeakLight"
                    obj.AdData(:,:,runIdx) = becExp.Od.OdData(:,:,runIdx) / sigma0;
                case "RandomPolarization"
                    obj.AdData(:,:,runIdx) = becExp.Od.OdData(:,:,runIdx) / sigma0 * 3;
                case "UniformStrongLight"
                    if isempty(sigmaData)
                        error("No cross section data. Can not do Ad with [UniformStrongLight] method.")
                    end
                    s = mean(becExp.Imaging.SaturationParameterPropagation,"all");
                    sigma = crossSec(s);
                    obj.AdData(:,:,runIdx) = becExp.Od.OdData(:,:,runIdx) / sigma;
                case "StrongLight"
                    if isempty(sigmaData)
                        error("No cross section data. Can not do Ad with [StrongLight] method.")
                    end
                    s = becExp.Imaging.SaturationParameterPropagation(:,:,runIdx);
                    s(s<0) = 0;
                    s(s>10) = 10;
                    sigma = crossSec(s);
                    sigma = imgaussfilt(sigma,obj.Blur);
                    obj.AdData(:,:,runIdx) = becExp.Od.OdData(:,:,runIdx) ./ sigma;
                case "UniformStrongLight2"

                case "StrongLight2"
                    
                case "PhaseContrastImaging"
                    %Needs to obtain phase plate for imaging, assume
                    %phi=pi/2 for now, should be between -pi and pi

                    phi=-pi/3; %Assumes additional thickness, use minus for etched
                    
                    freqlistPCI_Imaging=becExp.HardwareData.hw_ImagingPci;
                    freqPCI_Imaging=freqlistPCI_Imaging(runIdx);

                    switch becExp.Imaging.ImagingStage
                        case "NI"
                            freqlist_Imaging=becExp.HardwareData.hw_ImagingNi ;
                        case "LF" 
                            freqlist_Imaging=becExp.HardwareData.hw_ImagingLf ;
                        case "HF"
                            freqlist_Imaging=becExp.HardwareData.hw_ImagingHf ;
                    end

                    freq_Imaging=freqlist_Imaging(runIdx);
                    delta=freq_Imaging-freqPCI_Imaging; %Frequency Detuning (cyclic frequency). Positive means red-detuned for our experiment.
                    
                    obj.AdData(:,:,runIdx)=becExp.Od.ImageRatio(:,:,runIdx);

                    %Correct for spots that are outside of the expected
                    %ratios for the given phase spot plate.
                    Imin=min((3-2*cos(phi)-4*sin(phi/2)), (3-2*cos(phi)+4*sin(phi/2)));
                    Imax=max((3-2*cos(phi)-4*sin(phi/2)), (3-2*cos(phi)+4*sin(phi/2)));
                    obj.AdData(:,:,runIdx)=min(obj.AdData(:,:,runIdx), Imax);
                    obj.AdData(:,:,runIdx)=max(obj.AdData(:,:,runIdx), Imin);

                    %Calculate phase shift from atoms;
                    obj.AdData(:,:,runIdx)=phi/2+asin((obj.AdData(:,:,runIdx)-(3-2*cos(phi)))/(4*sin(phi/2)));

                    %Convert phase shift to density (for within range);
                    %Constants
                    epsilon0=8.8541878188e-12; %Si units for vacuum permitivity
                    electroncharge=1.602e-19; %Electron Charge in Coulombs
                    mLi=1.1649273e-26; %Mass of Li in kg
                    % alpha=electroncharge^2/(mLi*2*pi*delta*(2*4.46784587e14)); %
                    a0=5.29177210544e-11; %Bohr radius in m.
                    
                    

                    %Calculation based on Steck Quantum Optics
                    omegaD1 = 2 * pi * becExp.Atom.D1.Frequency;
                    omegaD2 = 2 * pi * becExp.Atom.D2.Frequency;
                    omegaL = omegaD2-2*pi*delta;
                    dipoleD1 = becExp.Atom.D1.ReducedDipoleMatrixElement;% already in SI units, (C*m)
                    dipoleD2 = becExp.Atom.D2.ReducedDipoleMatrixElement;
                    hbar = Constants.SI("hbar");

                    alpha = 2/3/hbar * (abs(dipoleD1)^2 / (omegaD1 - omegaL) +...
                        abs(dipoleD2)^2 / (omegaD2 - omegaL));
                    
                    % Final densities from phase shift
                    obj.AdData(:,:,runIdx)=obj.AdData(:,:,runIdx)/(2*pi/(671e-9))*2*epsilon0/alpha;
                    
            end

            % Update AdPreviewer
            obj.Gui(1).update;

        end

        function finalize(obj)
            % Generate final atomic density visualizations.
            %
            % Creates the atomic density mosaic plot and animated GIF showing
            % the evolution of atomic column density across parameter values.
            obj.plotAdMix
            obj.plotAdAnimation
        end

        function show(obj)
            % Display atomic density previewer and chart windows.
            %
            % Initializes the atomic density previewer GUI, configures OD preview
            % mode, establishes property change listeners, and shows chart figures.
            % Loads saved data for backwards compatibility when available.
            addlistener(obj,'CLim','PostSet',@obj.handlePropEvents);
            obj.Gui(1).initialize(obj.BecExp)
            obj.Gui(1).App.IsOd = obj.BecExp.IsOdPreview;
            obj.Gui(1).App.updateLabel;
            if isfile(obj.Chart(1).Path + ".fig") % for backwards compatibility
                obj.Chart(1).show
            elseif obj.Chart(1).IsEnabled
                load(fullfile(obj.BecExp.DataAnalysisPath,"AdData.mat"),"adData")
                obj.plotAdMix(adData);
            end
            obj.Chart(2).show
        end

        function refresh(obj)
            % Recompute atomic density for all runs and refresh visualization.
            %
            % Reinitializes data storage, updates the preview GUI, reprocesses
            % all completed runs, and regenerates visualization plots.
            becExp = obj.BecExp;
            nRun = becExp.NCompletedRun;
            roiSize = becExp.Roi.CenterSize(3:4);
            obj.AdData = zeros([roiSize,1]);

            if isempty(obj.Gui(1).App) || ~isvalid(obj.Gui(1).App)
                obj.Gui(1).initialize(obj.BecExp)
            else
                obj.Gui(1).update
            end

            for ii = 1:nRun
                obj.update(ii)
            end

            % Redo plotting
            obj.finalize;
        end

        function save(obj)
            % Save AD data and figure to disk.
            %
            % Writes ``AdData.mat`` under :attr:`BecExp.DataAnalysisPath` with
            % AD values and ROI axes. If the primary chart is enabled, also
            % saves the PNG figure at :attr:`Chart(1).Path`.
            %
            % :return: None
            % :rtype: void
            adData = obj.AdData;
            x = obj.BecExp.Roi.XList * obj.BecExp.Acquisition.PixelSizeReal;
            y = obj.BecExp.Roi.YList * obj.BecExp.Acquisition.PixelSizeReal;
            scannedVariableList = obj.BecExp.ScannedVariableList;
            save(fullfile(obj.BecExp.DataAnalysisPath,"AdData"),"adData","x","y","scannedVariableList");
            if obj.Chart(1).IsEnabled
                saveas(obj.Chart(1).Figure,obj.Chart(1).Path,'png')
            end
        end

        function plotAdMix(obj,adData)
            % Plot AD mosaics (1D scans) or 2D map (2D scans).
            %
            % :param adData: Optional AD to plot; defaults to :attr:`AdData`
            % :type adData: double, optional
            % :return: None
            % :rtype: void

            arguments
                obj
                adData = []
            end

            %% Initialize
            fig = obj.Chart(1).initialize;
            if ishandle(fig)
                figure(fig)
            else
                return
            end

            %% Check if 2D scan and call appropriate plotting method
            if obj.BecExp.Is2DScan
                obj.plotAdMix2D(fig, adData);
            else
                obj.plotAdMix1D(fig, adData);
            end
        end
        
        function plotAdMix1D(obj, fig, adData)
            % 1D plotting logic (mosaic across runs)
            %
            % :param fig: Figure handle
            % :type fig: matlab.ui.Figure
            % :param adData: Optional AD to plot; defaults to :attr:`AdData`
            % :type adData: double, optional
            ax = gca;

            %% Plot AD Data
            if isempty(adData)
                adData = obj.AdData;
            end
            if ~obj.BecExp.IsDensityAverage
                xTick = obj.BecExp.ScannedVariableListSorted;
                adData = adData(:,:,obj.BecExp.RunListSorted);
            else
                [xTick,adData] = computeAveErr(obj.BecExp.ScannedVariableList,adData);
            end

            nRun = numel(xTick);
            cData = cell(1,nRun);

            for ii = 1:numel(xTick)
                cData{ii} = adData(:,:,ii);
            end
            mData = horzcat(cData{:}) / obj.Unit;
            img = imagesc(ax,mData);

            %% Render
            fz = 20;
            cb = colorbar(ax);
            clim(obj.CLim)
            colormap(ax,obj.Colormap)
            
            cb.Label.Interpreter = "Latex";
            cb.Label.String = "AD [$\times 10^{" + string(log(obj.Unit)/log(10))+"} ~ \mathrm{m}^{-2}$]";
            cb.Label.FontSize = fz;
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            yxBoundary = obj.BecExp.Roi.YXBoundary;
            aspect = double(nRun)*roiSize(2)/roiSize(1);
            figPos = fig.InnerPosition;
            targetWidth = figPos(3)*0.85;
            targetHeight = figPos(4)*0.8;
            ax.Units = "pixels";
            if targetWidth > targetHeight * aspect
                ax.Position(4) = targetHeight;
                ax.Position(3) = targetHeight * aspect;
            else
                ax.Position(3) = targetWidth;
                ax.Position(4) = targetWidth / aspect;
            end
            ax.Position(1:2) = [figPos(3)/2 - ax.Position(3)/2,...
                figPos(4)/2 - ax.Position(4)/2];
            pbaspect(ax,[aspect,1,1])

            ax.Units = "normalized";
            ax.XLabel.String = obj.BecExp.XLabel;
            ax.XLabel.Interpreter = "latex";
            ax.XLabel.FontSize = fz;
            ax.YLabel.String = "$y$ position [pixels]";
            ax.YLabel.Interpreter = "latex";
            ax.YLabel.FontSize = fz;
            ax.Title.String = "TrialName: " + obj.BecExp.Name + ...
                ", Trial \#" + num2str(obj.BecExp.SerialNumber);
            ax.Title.Interpreter = "latex";
            ax.Title.FontSize = fz;
            ax.FontSize = fz;

            renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
            ax.TickDir = "out";
            tickSpace = roiSize(2);
            ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nRun)-tickSpace/2);
            ax.XTickLabel = string(xTick);
            set(ax,'box','off')
            ax.Units = "pixels";
            outerpos = ax.OuterPosition;
            fig.Position(4) = fig.Position(3) * outerpos(4)/outerpos(3)*1.05;
            ax.OuterPosition(2) = 0;
        end
        
        function plotAdMix2D(obj, fig, adData)
            % 2D plotting logic
            %
            % :param fig: Figure handle
            % :type fig: matlab.ui.Figure
            % :param adData: Optional AD to plot; defaults to :attr:`AdData`
            % :type adData: double, optional
            %% Plot OD Data
            ax = gca;
            if isempty(adData)
                adData = obj.AdData;
            end
            adData = flip(adData,1) / obj.Unit;
            [xTick,yTick,adData] = computeAveErr2D(...
                obj.BecExp.ScannedVariableList(1,:), ...
                obj.BecExp.ScannedVariableList(2,:), ...
                adData,"None");
            [r, c, ny, nx] = size(adData);
            mData = reshape(permute(adData, [1, 3, 2, 4]), r*ny, c*nx);
            img = imagesc(ax,mData);

            %% Render
            fz = 20;
            cb = colorbar(ax);
            clim(obj.CLim)
            colormap(ax,obj.Colormap)
            
            cb.Label.Interpreter = "Latex";
            cb.Label.String = "AD [$\times 10^{" + string(log(obj.Unit)/log(10))+"} ~ \mathrm{m}^{-2}$]";
            cb.Label.FontSize = fz;
            roiSize = obj.BecExp.Roi.CenterSize(3:4);
            yxBoundary = obj.BecExp.Roi.YXBoundary;
            aspect = double(nx)*roiSize(2)/(roiSize(1) * double(ny));
            figPos = fig.InnerPosition;
            targetWidth = figPos(3)*0.85;
            targetHeight = figPos(4)*0.8;
            ax.Units = "pixels";
            if targetWidth > targetHeight * aspect
                ax.Position(4) = targetHeight;
                ax.Position(3) = targetHeight * aspect;
            else
                ax.Position(3) = targetWidth;
                ax.Position(4) = targetWidth / aspect;
            end
            ax.Position(1:2) = [figPos(3)/2 - ax.Position(3)/2,...
                figPos(4)/2 - ax.Position(4)/2];
            pbaspect(ax,[aspect,1,1])

            ax.Units = "normalized";
            ax.XLabel.String = obj.BecExp.XLabel;
            ax.XLabel.Interpreter = "latex";
            ax.XLabel.FontSize = fz;
            ax.YLabel.String = obj.BecExp.YLabel;
            ax.YLabel.Interpreter = "latex";
            ax.YLabel.FontSize = fz;
            ax.Title.String = "TrialName: " + obj.BecExp.Name + ...
                ", Trial \#" + num2str(obj.BecExp.SerialNumber);
            ax.Title.Interpreter = "latex";
            ax.Title.FontSize = fz;
            ax.FontSize = fz;
            ax.YDir = "normal";

            renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
            ax.TickDir = "out";
            tickSpace = roiSize(2);
            ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nx)-tickSpace/2);
            ax.XTickLabel = string(xTick);
            tickSpace = roiSize(1);
            ax.YTick = (tickSpace/2):tickSpace:(tickSpace*double(ny)-tickSpace/2);
            ax.YTickLabel = string(yTick);
            set(ax,'box','off')
            ax.Units = "pixels";
            outerpos = ax.OuterPosition;
            fig.Position(4) = fig.Position(3) * outerpos(4)/outerpos(3)*1.05;
            ax.OuterPosition(2) = 0;
        end

        function plotAdAnimation(obj)
            % Create animated GIF across runs from AD data.
            %
            % Saves an animated GIF to :attr:`Chart(2).Path` using current AD
            % color scaling and ROI mid-slice profiles.
            
            %% Initialize figure
            if obj.BecExp.Is2DScan
                obj.Chart(2).IsEnabled = false;
            end
            fig = obj.Chart(2).initialize;
            if ishandle(fig)
                figure(fig)
            else
                return
            end
            
            %% Gif parameters
            startDelay=.5;
            midDelay=.1;
            endDelay=.5;
            filename = obj.Chart(2).Path + ".gif";

            %% BecExp parameters
            becExp = obj.BecExp;
            roi = becExp.Roi;
            yxBoundary = roi.YXBoundary;
            roiSize = roi.CenterSize(3:4);
            varName = becExp.ScannedVariable;
            varUnit = becExp.ScannedVariableUnit;
            adData = obj.AdData / obj.Unit;
            if ~obj.BecExp.IsDensityAverage
                varListSorted = becExp.ScannedVariableListSorted;
                adData = adData(:,:,becExp.RunListSorted);
            else
                [varListSorted,adData] = computeAveErr(becExp.ScannedVariableList,adData);
            end
            nRun = numel(varListSorted);

            %% Initialize plots
            roiAspect = roiSize(2)/roiSize(1);
            figPos = fig.InnerPosition;
            gap = 15;
            yxLabelSize = 50;
            yxWidth = 60;
            capSize = 30;
            cbSize = 70;
            targetWidth = figPos(3) - gap - yxLabelSize - yxWidth - cbSize;
            targetHeight = figPos(4) - gap - yxLabelSize - yxWidth - capSize;
            if targetWidth >= targetHeight * roiAspect
                imgHeight = targetHeight;
                imgWidth = targetHeight * roiAspect;
                imgLeft = max(figPos(3)/2 - imgWidth/2,gap + yxLabelSize + yxWidth);
                imgBottom = gap + yxLabelSize + yxWidth;
            else
                imgWidth = targetWidth;
                imgHeight = imgWidth / roiAspect;
                imgLeft = gap + yxLabelSize + yxWidth;
                imgBottom = max(figPos(4)/2 - imgHeight/2,gap + yxLabelSize + yxWidth);
            end

            % AD image
            imgAxes = axes(fig);
            imgAxes.Units = "pixels";
            img = imagesc(imgAxes,zeros(roiSize));
            imgAxes.Colormap = obj.Colormap;
            cb = colorbar(imgAxes,"eastoutside");
            cb.Label.Interpreter = "Latex";
            cb.Label.String = "AD [$\times 10^{" + string(log(obj.Unit)/log(10))+"} ~ \mathrm{m}^{-2}$]";
            cb.Label.FontSize = 14;
            imgAxes.Position = [imgLeft,imgBottom,imgWidth,imgHeight];
            imgAxes.CLim = obj.CLim;
            imgAxes.XTickLabel = '';
            imgAxes.YTickLabel = '';
            imgAxes.Title.Interpreter = "Latex";
            imgAxes.Title.FontSize = 14;
            imgAxes.Toolbar.Visible = "off";


            % X plot
            xAxes = axes(fig);
            xAxes.Units = "pixels";
            xAxes.Position = [imgLeft,imgBottom - (gap + yxWidth),imgWidth,yxWidth];
            xLine = plot(xAxes,yxBoundary(3):yxBoundary(4),zeros(1,roiSize(2)),'k','LineWidth',0.5);
            xAxes.XLabel.String = "$x$ position [Pixels]";
            xAxes.XLabel.Interpreter = "Latex";
            xAxes.XLabel.FontSize = 14;
            xAxes.YLim = obj.CLim;
            xAxes.XLim = [yxBoundary(3),yxBoundary(4)];
            xAxes.Toolbar.Visible = "off";

            % Y plot
            yAxes = axes(fig);
            yAxes.Units = "pixels";
            yAxes.Position = [imgLeft - (gap + yxWidth),imgBottom,yxWidth,imgHeight];
            yLine = plot(yAxes,zeros(1,roiSize(1)),yxBoundary(1):yxBoundary(2),'k','LineWidth',0.5);
            yAxes.YLabel.String = "$y$ position [Pixels]";
            yAxes.YLabel.Interpreter = "Latex";
            yAxes.YLabel.FontSize = 14;
            yAxes.YDir = "reverse";
            yAxes.XLim = obj.CLim;
            yAxes.YLim = [yxBoundary(1),yxBoundary(2)];
            yAxes.Toolbar.Visible = "off";

            %% Animation
            if ~isempty(obj.AdData)
                for ii = 1:nRun

                    % Update plots
                    img.CData = adData(:,:,ii);
                    xLine.YData = squeeze(adData(round(roiSize(1)/2),:,ii));
                    yLine.XData = squeeze(adData(:,round(roiSize(2)/2),ii));

                    % Update title
                    if ismissing(varUnit)
                        varLabel = "$\mathrm{" + varName + "} = ~$" + ...
                            string(varListSorted(ii));
                    else
                        varLabel = "$\mathrm{" + varName + "} = ~$" + ...
                            string(varListSorted(ii)) + "$~\mathrm{" + ...
                            varUnit + "}$";
                    end
                    imgAxes.Title.String = ...
                        "TrialName: " + becExp.Name + ...
                        ", Trial \#" + num2str(becExp.SerialNumber) + ...
                        ", Run \#" + num2str(ii) + ", " + ...
                        varLabel;

                    % Save as gif
                    frame = getframe(fig);
                    im = frame2im(frame);
                    [A,map] = rgb2ind(im,256);
                    if ii == 1
                        imwrite(A,map,filename,'gif','LoopCount',Inf,'DelayTime',startDelay);
                    else
                        if ii==nRun
                            imwrite(A,map,filename,'gif','WriteMode','append','DelayTime',endDelay);
                        else
                            imwrite(A,map,filename,'gif','WriteMode','append','DelayTime',midDelay);
                        end
                    end
                end
            end
            close(fig)
        end
    end

    methods (Static)
        function handlePropEvents(src,evnt)
            % Handle property change events for color limits and GUI updates.
            %
            % :param src: Property metadata object
            % :type src: meta.property
            % :param evnt: Event data containing affected object
            % :type evnt: event.EventData
            switch src.Name
                case 'CLim'
                    obj = evnt.AffectedObject;
                    for ii = 1:numel(obj.Chart)
                        if ishandle(obj.Chart(ii).Figure)
                            fig = obj.Chart(ii).Figure;
                            ax = fig.CurrentAxes;
                            ax.CLim = obj.CLim;
                        end
                    end
                    if ~isempty(obj.Gui(1).App)
                        if isvalid(obj.Gui(1).App)
                            obj.Gui(1).App.OdAxes.CLim = obj.CLim;
                            obj.Gui(1).App.OdYAxes.XLim = obj.CLim;
                            obj.Gui(1).App.OdXAxes.YLim = obj.CLim;
                            obj.Gui(1).App.ODMinEditField.Value = obj.CLim(1);
                            obj.Gui(1).App.ODMaxEditField.Value = obj.CLim(2);
                        end
                    end
            end
        end
    end
end

