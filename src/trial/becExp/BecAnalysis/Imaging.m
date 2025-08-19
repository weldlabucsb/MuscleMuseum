classdef Imaging < BecAnalysis
    %IMAGING Summary of this class goes here
    %   Detailed explanation goes here

    properties (SetAccess = protected)
        SaturationParameterMean double %I/I_sat, averaged over ROI
        LightMean double %averaged over the ROI
        DarkMean double %averaged over the ROI
        ImagingTime double = []
        ImagingTimeUnit string
        QuantumEfficiency double = 1 %read from the camera specs
        Transmission double = 1 %read from the camera specs
    end

    properties
        ImagingStage string = "LF" % LF:low-field. HF:high-field. NI:non-inter
        ImagingMethod string = "Absorption"
    end

    properties (SetAccess = protected, Hidden)
        Prefactor %For calculating SaturationParameter
    end

    properties (Dependent)
        SaturationParameterMeanOverall double %I/I_sat, averaged over ROI and all runs
    end

    properties (Transient)
        SaturationParameterPropagation % (s_atom + s_light)/2, 2D distribution. This accounts for the propagation effects
    end

    methods
        function obj = Imaging(becExp)
            %IMAGING Construct an instance of this class
            %   Detailed explanation goes here
            obj@BecAnalysis(becExp)
            obj.Chart(1) = Chart(...
                name = "Imaging analysis",...
                num = 24, ...
                fpath = fullfile(becExp.DataAnalysisPath,"ImagingAnalysis"),...
                loc = [0.3919,0.6014],...
                size = [0.3069,0.3995]...
                );

            % Calcualte the prefactor
            Isat = becExp.Atom.CyclerSaturationIntensity;
            pixelSize = becExp.Acquisition.PixelSize;
            mag = becExp.Acquisition.Magnification;
            hbar = Constants.SI("hbar");
            c = Constants.SI("c");
            omega = 2*pi*becExp.Atom.CyclerFrequency;
            lambda = 2*pi*c/omega;
            obj.ImagingTimeUnit = becExp.ParameterUnitSetting.readValue("t_image","ScannedParameterUnit","ScannedParameter");
            mul = unit2SI(obj.ImagingTimeUnit);
            obj.Prefactor = hbar*omega/(pixelSize/mag)^2/Isat/mul;

            % Quantum efficiency
            obj.QuantumEfficiency = becExp.Acquisition.QuantumEfficiency(lambda);

            % Transmission
            obj.Transmission = becExp.Acquisition.Transmission;
        end

        function initialize(obj)
            fig = obj.Chart(1).initialize;
            obj.SaturationParameterMean = 0;
            obj.LightMean = 0;
            obj.DarkMean = 0;
            obj.ImagingTime = 0;
            obj.SaturationParameterPropagation = zeros([obj.BecExp.Roi.CenterSize(3:4),1]);

            if ~ishandle(fig)
                return
            end

            % Sat parameter plot
            ax1 = subplot(2,1,1,'parent',fig,...
                'box','on');
            co=get(ax1,'colororder');
            errorbar(ax1,0,0,[],'ko','MarkerFaceColor',co(1,:),'linewidth',2,...
                'markeredgecolor',co(1,:)*.5,'markersize',8,'CapSize',0);
            grid on
            ax1.FontSize = 12;

            % Photon count plot
            ax2 = subplot(2,1,2,'parent',fig,...
                'box','on');
            hold on
            errorbar(ax2,0,0,[],'ko','MarkerFaceColor',co(1,:),'linewidth',2,...
                'markeredgecolor',co(1,:)*.5,'markersize',8,'CapSize',0);
            errorbar(ax2,0,0,[],'o','MarkerFaceColor',co(2,:),'linewidth',2,...
                'markeredgecolor',co(2,:)*.5,'markersize',8,'CapSize',0);
            hold off
            legend(ax2,"Light","Dark","Interpreter","latex")
            grid on
            ax2.FontSize = 12;

            ylabel(ax1,"$s$","Interpreter","latex")
            ylabel(ax2,"$\bar{N}_{\mathrm{photon}}$","Interpreter","latex")
            xlabel(ax2,obj.BecExp.XLabel,"Interpreter","latex")
        end

        function updateData(obj,runIdx)
            becExp = obj.BecExp;
            roiData = squeeze(becExp.Od.RoiData(:,:,runIdx,:));
            eff = obj.QuantumEfficiency * obj.Transmission;
            pf = obj.Prefactor;
            atomData = roiData(:,:,1)/eff;
            lightData = roiData(:,:,2)/eff;
            darkData = roiData(:,:,3)/eff;
            obj.LightMean(runIdx) = mean(lightData(:));
            obj.DarkMean(runIdx) = mean(darkData(:));
            t = becExp.CiceroData.t_image(runIdx);
            obj.ImagingTime(runIdx) = t;
            obj.SaturationParameterMean(runIdx) = pf * (obj.LightMean(runIdx) - obj.DarkMean(runIdx)) / t;
            obj.SaturationParameterPropagation(:,:,runIdx) = pf * (atomData + becExp.Od.CameraLightData(:,:,runIdx) / eff) / 2 / t;
        end

        function updateFigure(obj,~)
            % Check if we have the figure handle
            if ishandle(obj.Chart(1).Figure)
                fig = figure(obj.Chart(1).Figure);
            else
                return
            end

            % Check if 2D scan and call appropriate plotting method
            if obj.BecExp.Is2DScan
                obj.updateFigure2D(fig);
            else
                obj.updateFigure1D(fig);
            end
        end
        
        function updateFigure1D(obj, fig)
            % 1D plotting logic (original implementation)
            % Parameters
            paraList = obj.BecExp.ScannedParameterList;
            ax = findobj(fig,'Type','Axes');

            % Find x, y, and error plot data
            [xLight,yLight,stdLight] = computeStd(paraList,obj.LightMean);
            [xDark,yDark,stdDark] = computeStd(paraList,obj.DarkMean);
            [xSat,ySat,stdSat] = computeStd(paraList,obj.SaturationParameterMean);

            % Update imaging counts plots
            l = findobj(ax(1),'Type','ErrorBar');
            l(1).XData = xLight;
            l(1).YData = yLight;
            l(1).YNegativeDelta = stdLight;
            l(1).YPositiveDelta = stdLight;
            l(2).XData = xDark;
            l(2).YData = yDark;
            l(2).YNegativeDelta = stdDark;
            l(2).YPositiveDelta = stdDark;

            % Update sat parameter plots
            l = findobj(ax(2),'Type','ErrorBar');
            l(1).XData = xSat;
            l(1).YData = ySat;
            l(1).YNegativeDelta = stdSat;
            l(1).YPositiveDelta = stdSat;

            title(ax(2),obj.ImagingStage + " " + obj.ImagingMethod + ...
                ". First run $t_{\mathrm{image}}=" + num2str(obj.ImagingTime(1)) + "~\mathrm{" + ...
                obj.ImagingTimeUnit + "}.~\bar{s} = " + num2str(obj.SaturationParameterMeanOverall) + "$",...
                Interpreter="latex")
        end
        
        function updateFigure2D(obj, fig)
            % 2D plotting logic
            becExp = obj.BecExp;
            
            % Get 2D plot data
            [xData, yData] = obj.get2DPlotData();
            
            if isempty(xData) || isempty(yData)
                % Fallback to 1D plotting if 2D data is not available
                obj.updateFigure1D(fig);
                return;
            end
            
            % Clear figure and create new subplots
            clf(fig);
            
            % Create subplot for saturation parameter
            ax1 = subplot(2,1,1);
            
            % Reshape saturation parameter to 2D
            sat2D = obj.reshapeDataTo2D(obj.SaturationParameterMean);
            
            % Create density plot for saturation parameter
            imagesc(ax1, xData, yData, sat2D);
            ax1.Colormap = jet;
            colorbar(ax1);
            ax1.XLabel.String = becExp.XLabel;
            ax1.XLabel.Interpreter = "latex";
            ax1.YLabel.String = becExp.YLabel;
            ax1.YLabel.Interpreter = "latex";
            ax1.Title.String = "Saturation Parameter";
            ax1.Title.Interpreter = "latex";
            
            % Create subplot for light/dark comparison
            ax2 = subplot(2,1,2);
            
            % Reshape light and dark data to 2D
            light2D = obj.reshapeDataTo2D(obj.LightMean);
            dark2D = obj.reshapeDataTo2D(obj.DarkMean);
            
            % Create combined plot (light - dark)
            combined2D = light2D - dark2D;
            imagesc(ax2, xData, yData, combined2D);
            ax2.Colormap = jet;
            colorbar(ax2);
            ax2.XLabel.String = becExp.XLabel;
            ax2.XLabel.Interpreter = "latex";
            ax2.YLabel.String = becExp.YLabel;
            ax2.YLabel.Interpreter = "latex";
            ax2.Title.String = "Light - Dark";
            ax2.Title.Interpreter = "latex";
            
            % Add overall title
            sgtitle(fig, obj.ImagingStage + " " + obj.ImagingMethod + ...
                ". First run $t_{\mathrm{image}}=" + num2str(obj.ImagingTime(1)) + "~\mathrm{" + ...
                obj.ImagingTimeUnit + "}.~\bar{s} = " + num2str(obj.SaturationParameterMeanOverall) + "$",...
                Interpreter="latex")
        end

        function sMean = get.SaturationParameterMeanOverall(obj)
            sMean = mean(obj.SaturationParameterMean(:));
        end

        function refresh(obj)
            obj.initialize;
            becExp = obj.BecExp;
            roiData = becExp.Od.RoiData(:,:,:,:);
            qe = obj.QuantumEfficiency;
            pf = obj.Prefactor;
            obj.LightMean = squeeze(mean(roiData(:,:,:,2)/qe,[1,2])).';
            obj.DarkMean = squeeze(mean(roiData(:,:,:,3)/qe,[1,2])).';
            t = becExp.CiceroData.t_image;
            obj.ImagingTime = t;
            obj.SaturationParameterMean = pf * (obj.LightMean - obj.DarkMean) ./ t;
            t = reshape(t,1,1,becExp.NCompletedRun);
            obj.SaturationParameterPropagation = pf * (roiData(:,:,:,1) / qe + becExp.Od.CameraLightData(:,:,:) / qe) / 2 ./ t;
            obj.updateFigure(1);
        end
    end
end

