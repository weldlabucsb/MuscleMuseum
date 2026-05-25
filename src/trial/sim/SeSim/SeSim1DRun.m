classdef SeSim1DRun < TimeSimRun & SpaceSimRun
    %SESIM1DRUN Summary of this class goes here
    %   Single-particle time-dependent Schrodinger equation simulation in 
    %   1D.
    
    properties
        Mass (1,1) double % mass of the particle
        Potential function_handle
    end

    properties (SetAccess = protected)
        KineticPropagator
    end
    
    methods
        function obj = SeSim1DRun(seSim1D,options)
            %SESIM1DRUN Construct an instance of this class
            %   Detailed explanation goes here
            arguments
                seSim1D  
                options.totalTime double
                options.timeStep double
                options.spaceOrigin double
                options.spaceRange double
                options.spaceStep double
                options.mass double
                options.initialCondition InitialCondition
                options.boundaryCondition string = "Periodic"
                options.potential function_handle
            end
            obj@TimeSimRun(seSim1D)
            obj@SpaceSimRun(seSim1D)
            obj.Dimension = 1;

            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end

            % Kinetic energy propagator
            k = obj.SpaceAngularFrequencyList.';
            hbar = Constants.SI("hbar");
            m = obj.Mass;
            dt = obj.TimeStep;
            obj.KineticPropagator = exp(-1i * hbar / 2 / m * k.^2 * dt);
        end

        function start(obj)
            tList = obj.TimeList;
            nt = obj.NTimeStep;
            dt = obj.TimeStep;
            % psiFunc = obj.InitialCondition.WaveFunctionFunc;
            V = obj.Potential;
            Uk = obj.KineticPropagator;
            x = obj.SpaceList;
            dx = obj.SpaceStep;
            psi = obj.InitialCondition.WaveFunction;
            psi = psi ./ sqrt(sum(abs(psi).^2*dx));
            if obj.IsUsingGpu
                psi = gpuArray(psi);
                Uk = gpuArray(Uk);
            end

            savePeriod = obj.SavePeriod;
            avePeriod = obj.AveragePeriod;
            nDataRowMemory = obj.NDataRowMemory;

            outputVarSize = obj.Output.Size;
            outputVarName = obj.Output.VariableName;
            runtimeName = obj.Output.RuntimeName;
            nDataColumn = sum(outputVarSize);
            dataColumnStartIdx = 1 + [0;cumsum(outputVarSize(1:end-1))];
            dataColumnStopIdx = cumsum(outputVarSize);
            % tempExpr = "temp = temp + [" + strjoin(runtimeName,",") + "];";
            tempExpr = "temp = [" + strjoin(runtimeName,",") + "];";
            temp = zeros(1,nDataColumn);
            data = zeros(floor(savePeriod/avePeriod),nDataColumn);
            for ii = 1:numel(outputVarName)
                expr = outputVarName(ii) + "=complex(zeros(1,"+num2str(outputVarSize(ii))+"));";
                eval(expr)
            end
            save(obj.RunPath,obj.Output.VariableName{:},"-v7.3")
            matObj = matfile(obj.RunPath,'Writable',true);

            % figure(1)
           
            for tt = 1:nt
                % Strang splitting time evolution
                t = tList(tt);
                V1 = (V(t) + 4 * V(t + 1/4*dt) + V(t + 1/2*dt))/6;
                V2 = (V(t + 1/2*dt) + 4 * V(t + 3/4*dt) + V(t + dt))/6;
                UV1 = exp(-1i * 2 * pi * V1 * dt / 2);
                UV2 = exp(-1i * 2 * pi * V2 * dt / 2);
                psi = UV1 .* psi;
                psi = ifft(Uk.*fft(psi));
                psi = UV2 .* psi;

                % Output
                psicj = psi';

                if mod(tt,savePeriod) == 0
                    eval(tempExpr);
                    % data(nDataRowMemory,:)=temp/avePeriod;
                    data(nDataRowMemory,:)=temp;
                    s = floor(tt/avePeriod/nDataRowMemory);
                    for ii = 1:numel(outputVarName)
                        matObj.(char(outputVarName(ii)))((s-1)*nDataRowMemory+1:s*nDataRowMemory,:) = ...
                            data(:,dataColumnStartIdx(ii):dataColumnStopIdx(ii));
                    end
                        temp = zeros(1,nDataColumn);
                elseif tt == (nt - mod(nt,avePeriod))
                    eval(tempExpr);
                    if mod(tt,savePeriod) == 0
                        rowIdx = floor(savePeriod/avePeriod);
                    else
                        rowIdx = floor(mod(tt,savePeriod)/avePeriod);
                    end
                    data(rowIdx,:) = temp;
                    % data(rowIdx,:) = temp/avePeriod;
                    data(rowIdx+1:end,:) = [];
                    if mod(tt,savePeriod) == 0
                        s = floor(tt/avePeriod/nDataRowMemory);
                    else
                        s = floor(tt/avePeriod/nDataRowMemory) + 1;
                    end
                    for ii = 1:numel(outputVarName)
                        matObj.(char(outputVarName(ii)))((s-1)*nDataRowMemory+1:(s-1)*nDataRowMemory + size(data,1),:) =...
                            data(:,dataColumnStartIdx(ii):dataColumnStopIdx(ii));
                    end
                        temp = zeros(1,nDataColumn);
                elseif mod(tt,avePeriod) == 0
                    eval(tempExpr);
                    % data(floor(mod(tt,savePeriod)/avePeriod),:) = temp/avePeriod;
                    data(floor(mod(tt,savePeriod)/avePeriod),:) = temp;
                    temp = zeros(1,nDataColumn);
                else
                    eval(tempExpr);
                end
            end
            FinalWaveFunction = psicj;
            save(obj.RunPath,"FinalWaveFunction",'-append')         
        end

        function showSpaceTime(obj)
            psi = obj.readRun("WaveFunction");
            n = abs(psi).^2;
            x = obj.SpaceList * 1e6;
            t = obj.TimeList * 1e3;
            fig = figure(8911 + round(rand * 1000));
            img = imagesc(n.');
            renderTicks(img,t,x)
            xlabel("$t~[\mathrm{ms}]$",'Interpreter','latex')
            ylabel("$y~[\mu\mathrm{m}]$",'Interpreter','latex')
            title("Run " + obj.RunIndex)
            clim([0,max(n(1,:))])
            render
            exportgraphics(fig,fullfile(obj.DataAnalysisPath,"run"+obj.RunIndex+"_spacetime.png"),Resolution=300)
        end

        function [psicj,time] = showTimeSlice(obj,idx)
            m = matfile(obj.RunPath);
            psicj = m.WaveFunction(idx,:);
            time = m.Time(idx,:);
        end

        function output = showPeak(obj)
            psi = obj.readRun("WaveFunction");
            n = abs(psi).^2;
            x = obj.SpaceList * 1e6;
            t = obj.readRun("Time") * 1e3;
            [~,idx] = max(n,[],2);
            xMax = x(idx);
            if nargout == 0
                figure(8912);
                plot(t,xMax);
                xlabel("$t~[\mathrm{ms}]$",'Interpreter','latex')
                ylabel("$y~[\mu\mathrm{m}]$",'Interpreter','latex')
                render
                savefig(fullfile(obj.DataAnalysisPath,"run"+obj.RunIndex+"_peak.fig"))
                exportgraphics(gcf,fullfile(obj.DataAnalysisPath,"run"+obj.RunIndex+"_peak.png"),Resolution=300)
            else
                output = [t(:) / 1e3,xMax(:) / 1e6];
            end
        end

    end
end

