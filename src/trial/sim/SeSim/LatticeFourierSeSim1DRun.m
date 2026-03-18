classdef LatticeFourierSeSim1DRun < TimeSimRun
    %SESIM1DRUN Summary of this class goes here
    %   Single-particle time-dependent Schrodinger equation simulation in 
    %   1D.
    
    properties
        Atom Atom
        AtomicState struct
        Laser Laser
        MagneticField MagneticField
        LatticeModulation WaveformList
        FieldModulation WaveformList
    end

    properties (SetAccess = protected)
        OpticalLattice OpticalLattice
        MagneticPotential MagneticPotential
        FOverHbar double = 0 % Hz/m
    end
    
    methods
        function obj = LatticeFourierSeSim1DRun(sim1D,options)
            %SESIM1DRUN Construct an instance of this class
            %   Detailed explanation goes here
            arguments
                sim1D
                options.atom Atom
                options.atomicState struct
                options.totalTime double
                options.timeStep double
                options.initialCondition InitialCondition
                options.laser Laser
                options.magneticField MagneticField
                options.latticeModulation WaveformList
                options.fieldModulation WaveformList
            end
            obj@TimeSimRun(sim1D)

            field = string(fieldnames(options));
            for ii = 1:numel(field)
                if ~isempty(options.(field(ii)))
                    obj.(capitalizeFirst(field(ii))) = options.(field(ii));
                end
            end

            % Set potential
            obj.OpticalLattice = OpticalLattice(obj.Atom,obj.Laser,...
                atomicState=obj.AtomicState);
            if ~isempty(obj.MagneticField)
                obj.MagneticPotential = MagneticPotential(obj.Atom,obj.MagneticField,...
                    atomicState=obj.AtomicState);
            end

            % Compute FOverHbar
            if ~isempty(obj.MagneticField)
                laserDir = obj.Laser.Direction;
                bField = obj.MagneticField;
                if any(bField.Gradient(:))
                    gradField = bField.Gradient;
                    if norm(bField.Bias) ~= 0
                        biasDir = bField.Bias / vecnorm(bField.Bias);
                        gradProj = sum(gradField .* repmat(biasDir,1,3),2);
                        if vecnorm(gradProj) ~= norm(gradField)
                            error("Can not do simulation when the " + ...
                                "gradient field is not along the bias field diretion")
                        end
                    end
                    gradProj2 = gradField * laserDir;
                    obj.FOverHbar = - 2 * pi * obj.MagneticPotential.EnergyFactor * (gradProj2.' * biasDir);
                end
            end
        end

        function start(obj)
            % Time parameters
            tList = obj.TimeList;
            nt = obj.NTimeStep;
            dt = obj.TimeStep;
            
            % Modulation
            latticeMod = obj.LatticeModulation;
            magMod = obj.FieldModulation;
            if ~isempty(latticeMod)
                latticeModFunc = latticeMod.TimeFunc;
                latticeModList = latticeModFunc(tList);
            else
                latticeModList = zeros(1,nt);
            end
            if ~isempty(magMod)
                magModFunc = magMod.TimeFunc;
                magModList = magModFunc(tList);
            else
                magModList = zeros(1,nt);
            end

            % Simulation parameters
            ol = obj.OpticalLattice;
            lambda = ol.Laser.Wavelength;
            kL = ol.Laser.AngularWavenumber;
            Er = ol.RecoilEnergy;
            V0 = ol.Depth / Er;
            fOverHbar = obj.FOverHbar;
            
            % Initial condition
            u = obj.InitialCondition.WaveFunction;
            q = obj.InitialCondition.QuasiMomentum;

            % Initialize matrices
            nMax = numel(u);
            u = u ./ norm(u) * sqrt(2 / lambda); % renormalize
            trigMat = -gallery('tridiag',nMax,1,2,1);
            jVec = 1-nMax:2:nMax-1;

            % Output parameters
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
                t = tList(tt);
                qeff = (q + fOverHbar * t * (1 + magModList(tt))) / kL;
                % qeff = mod(qeff + 1,2)-1;
                Hp = diag((jVec + qeff).^2);
                HV = trigMat * V0 / 4 * (1+latticeModList(tt));
                U = expm(-1i * 2 * pi * Er * (Hp + HV) * dt);
                u = U * u;

                % Output
                ucj = u';

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
            FinalWaveFunction = ucj;
            save(obj.RunPath,"FinalWaveFunction",'-append')         
        end

        function plotBand(obj,bandNumber)
            ol = obj.OpticalLattice;
            ucj = obj.readRun("WaveFunction");
            q = obj.InitialCondition.QuasiMomentum;
            t = obj.TimeListAvg;
            fOverHbar = obj.FOverHbar;
            qt = q + fOverHbar * t;
            pop = ol.computeBandPopulationFourier1D(ucj,qt,bandNumber);
            plot(t * 1e3,pop)
            xlabel("Time [ms]")
            ylabel("Band Population")
        end

        % function showSpaceTime(obj)
        %     psi = obj.readRun("WaveFunction");
        %     n = abs(psi).^2;
        %     x = obj.SpaceList * 1e6;
        %     t = obj.TimeList * 1e3;
        %     figure(8911)
        %     img = imagesc(n.');
        %     renderTicks(img,t,x)
        %     xlabel("$t~[\mathrm{ms}]$",'Interpreter','latex')
        %     ylabel("$y~[\mu\mathrm{m}]$",'Interpreter','latex')
        %     clim([0,max(n(1,:))])
        %     render
        % end

        % function output = showPeak(obj)
        %     psi = obj.readRun("WaveFunction");
        %     n = abs(psi).^2;
        %     x = obj.SpaceList * 1e6;
        %     t = obj.readRun("Time") * 1e3;
        %     [~,idx] = max(n,[],2);
        %     xMax = x(idx);
        %     if nargout == 0
        %         figure(8912);
        %         plot(t,xMax);
        %         xlabel("$t~[\mathrm{ms}]$",'Interpreter','latex')
        %         ylabel("$y~[\mu\mathrm{m}]$",'Interpreter','latex')
        %         % render
        %     else
        %         output = [t(:) / 1e3,xMax(:) / 1e6];
        %     end
        % end

    end
end

