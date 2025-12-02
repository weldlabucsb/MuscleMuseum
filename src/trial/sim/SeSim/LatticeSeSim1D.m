classdef LatticeSeSim1D < SpaceTimeSim
    %SESIM Summary of this class goes here
    %   Detailed explanation goes here

    properties(SetAccess = private)
        Atom Atom
        AtomicState struct
        Laser cell
        WallLaser cell
        MagneticField cell
        LatticeModulation cell
        WallModulation cell
        FieldModulation cell
        OpticalLattice OpticalLattice
        OpticalWall cell
        MagneticPotential MagneticPotential
        InitialCondition InitialCondition
    end

    properties
        ScannedVariableList
    end

    methods
        function obj = LatticeSeSim1D(trialName,options1,options2)
            arguments
                trialName string
                options1.atom Atom
                options1.atomicState struct
                options1.totalTime double
                options1.timeStep double
                options1.spaceOrigin double = [0;0;0]
                options1.spaceRange double
                options1.spaceStep double
                options1.boundaryCondition string = "Periodic"
                options1.output string
                options2.laser cell
                options2.wallLaser cell
                options2.magneticField cell
                options2.latticeModulation cell
                options2.fieldModulation cell
                options2.wallModulation cell
                options2.initialCondition InitialCondition
            end
            obj@SpaceTimeSim(trialName,"LatticeSeSim1D");

            %% Atom setting
            if isfield(obj.ConfigParameter,'Parameter') && isstruct(obj.ConfigParameter.Parameter) &&...
                    isfield(obj.ConfigParameter.Parameter,"AtomName")
                obj.Atom = getAtom(obj.ConfigParameter.Parameter.AtomName);
            end

            %% Change parameters if they are manually set
            field1 = string(fieldnames(options1));
            for ii = 1:numel(field1)
                if ~isempty(options1.(field1(ii)))
                    obj.(capitalizeFirst(field1(ii))) = options1.(field1(ii));
                end
            end
            field2 = string(fieldnames(options2));
            for ii = 1:numel(field2)
                if ~isempty(options2.(field2(ii)))
                    obj.(capitalizeFirst(field2(ii))) = options2.(field2(ii));
                end
            end

            %% Set output parameter
            obj.setOutput
            obj.setWaveFunctionSize

            %% Find scanned variable
            nPara = cellfun(@numel,struct2cell(options2));
            obj.NRun = max(nPara);
            if any(nPara(nPara~=obj.NRun)>1)
                error("Parameter lengths do not match")
            else
                scannedVariableIdx = find(nPara==obj.NRun);
                scannedVariableName = string(field2(scannedVariableIdx));
                if ~isempty(scannedVariableName)
                    scannedVariableName = scannedVariableName(1);
                else
                    scannedVariableName = "laser";
                end
            end
            obj.ScannedVariable = scannedVariableName;

            %% Construct modulations
            if isempty(obj.LatticeModulation)
                obj.LatticeModulation = {SineWave(...
                    amplitude = 0, ...
                    duration = 1e-3, ...
                    frequency = 1);};
            end
            if isempty(obj.FieldModulation)
                obj.FieldModulation = {SineWave(...
                    amplitude = 0, ...
                    duration = 1e-3, ...
                    frequency = 1);};
            end
            if isempty(obj.WallModulation)
                obj.WallModulation = {SineWave(...
                    amplitude = 0, ...
                    duration = 1e-3, ...
                    frequency = 1);};
                if ~isempty(obj.WallLaser)
                    obj.WallModulation{1} = repmat(obj.WallModulation{1},1,numel(obj.WallLaser{1}));
                end
            end

            %% Construct OpticalLattice and MagneticPotential
            for ii = 1:obj.NRun
                if ii == 1
                    obj.OpticalLattice(1) = OpticalLattice(obj.Atom,obj.Laser{1},...
                        atomicState=obj.AtomicState);
                    if ~isempty(obj.MagneticField)
                        obj.MagneticPotential(1) = MagneticPotential(obj.Atom,obj.MagneticField{1},...
                            atomicState=obj.AtomicState);
                    else
                        obj.MagneticPotential(1) = MagneticPotential(obj.Atom,MagneticField(bias=[0;0;0]),...
                            atomicState=obj.AtomicState);
                    end
                    if ~isempty(obj.WallLaser)
                        obj.OpticalWall{1} = arrayfun(@(x) OpticalWall(obj.Atom,x,...
                            atomicState=obj.AtomicState),obj.WallLaser{1});
                    else
                        obj.OpticalWall{1} = OpticalWall(obj.Atom,GaussianBeam(wavelength = 1e-6,intensity=0,waist=[1;1]),...
                            atomicState=obj.AtomicState);
                    end
                else
                    if scannedVariableName == "laser"
                        obj.OpticalLattice(ii) = OpticalLattice(obj.Atom,obj.Laser{ii},...
                            atomicState=obj.AtomicState);
                    elseif scannedVariableName == "magneticField"
                        obj.MagneticPotential(ii) = MagneticPotential(obj.Atom,obj.MagneticField{ii},...
                            atomicState=obj.AtomicState);
                    elseif scannedVariableName == "wallLaser"
                        obj.OpticalWall{ii} = arrayfun(@(x) OpticalWall(obj.Atom,x,...
                            atomicState=obj.AtomicState),obj.WallLaser{ii});
                    end
                end
            end

            %% Set SeSim1DRun parameters
            options.mass = obj.Atom.mass;
            options.totalTime = obj.TotalTime;
            options.timeStep = obj.TimeStep;
            options.spaceOrigin = obj.SpaceOrigin;
            options.spaceRange = obj.SpaceRange;
            options.spaceStep = obj.SpaceStep;
            options.boundaryCondition = obj.BoundaryCondition;

            obj.SimRun = SeSim1DRun.empty;
            for ii = 1:obj.NRun
                varargin = struct2pairs(options);
                obj.SimRun(ii) = SeSim1DRun(obj,varargin{:});
                obj.SimRun(ii).RunIndex = ii;
                if scannedVariableName == "initialCondition" || numel(obj.InitialCondition) == obj.NRun
                    obj.SimRun(ii).InitialCondition = obj.InitialCondition(ii);
                else
                    obj.SimRun(ii).InitialCondition = obj.InitialCondition;
                end
            end

            %% Set the potential function handles
            x = obj.SimRun(1).SpaceList;
            dir = obj.Laser{1}(1).Direction;
            r = dir * x;
            for ii = 1:obj.NRun
                switch scannedVariableName
                    case "laser"
                        lFunc = obj.OpticalLattice(ii).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "magneticField"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(ii).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "latticeModulation"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{ii}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "fieldModulation"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{ii}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "initialCondition"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "wallLaser"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{ii}(x).spaceFunc,1:numel(obj.OpticalWall{ii}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{1}(x).TimeFunc,1:numel(obj.WallModulation{1}),'UniformOutput',false);
                    case "wallModulation"
                        lFunc = obj.OpticalLattice(1).spaceFunc;
                        lFunc2 = arrayfun(@(x) obj.OpticalWall{1}(x).spaceFunc,1:numel(obj.OpticalWall{1}),'UniformOutput',false);
                        bFunc = obj.MagneticPotential(1).spaceFunc;
                        lmFunc = {obj.LatticeModulation{1}.TimeFunc};
                        fmFunc = {obj.FieldModulation{1}.TimeFunc};
                        wmFunc = arrayfun(@(x) obj.WallModulation{ii}(x).TimeFunc,1:numel(obj.WallModulation{ii}),'UniformOutput',false);
                end
                dx = x(2) - x(1);
                Vl = lFunc(r).';
                Vl2 = cellfun(@(F) F(r).',lFunc2,"UniformOutput",false);
                Vl2t = @(t) 0;
                for jj = 1:numel(lFunc2)
                    Vl2t = @(t) Vl2t(t) + circshift(Vl2{jj},round(wmFunc{jj}(t)/dx));
                end
                Vb = bFunc(r).';
                Vb = Vb - max(Vb);
                lmFuncSum = @(x) sum(cellfun(@(F) F(x),lmFunc));
                fmFuncSum = @(x) sum(cellfun(@(F) F(x),fmFunc));
                obj.SimRun(ii).Potential = @(t) (1+lmFuncSum(t)) * Vl + (1+fmFuncSum(t)) * Vb + Vl2t(t);
            end
            obj.update
        end

        function plotBand(obj,runIdx,bandNumber)
            psicj = obj.SimRun(runIdx).readRun("WaveFunction");
            x = obj.SimRun(1).SpaceList;
            t = obj.SimRun(1).TimeListAvg * 1e3;
            pop = obj.OpticalLattice.computeBandPopulation1D(psicj,max(bandNumber),x);
            bandNumber = bandNumber + 1;
            pop = pop(:,bandNumber);
            figure(2943)
            plot(t,pop)
            render
        end

        function showSpaceTime(obj)
            for ii = 1:obj.NRun
                obj.SimRun(ii).showSpaceTime;
                close all
            end
        end

        function showQuasimomentumTime(obj,n)
            x = obj.SimRun(1).SpaceList;
            ol = obj.OpticalLattice(1);
            if isempty(ol.BlochState)
                ol.computeAll1D(2000,n,x)
            end
            for ii = 1:obj.NRun
                if numel(obj.OpticalLattice) > 1
                    ol = obj.OpticalLattice(ii);
                    if isempty(ol.BlochState)
                        ol.computeAll1D(2000,n,x)
                    end
                end
                qList = ol.QuasiMomentumList;
                kL = ol.Laser.AngularWavenumber;
                psi = obj.SimRun(ii).readRun("WaveFunction");
                
                qDist = ol.computeQuasimomentumDistribution1D(psi,n);
                t = obj.SimRun(ii).TimeList * 1e3;
                fig = figure(8911 + round(rand * 1000));
                img = imagesc(qDist.');
                renderTicks(img,t,qList/kL)
                xlabel("$t~[\mathrm{ms}]$",'Interpreter','latex')
                ylabel("$q~[\hbar k_\mathrm{L}]$",'Interpreter','latex')
                title("Trial " + obj.SerialNumber + ", Run " + ii)
                clim([0,max(qDist(:))])
                render
                exportgraphics(fig,fullfile(obj.DataAnalysisPath,"run"+obj.SimRun(ii).RunIndex+"_qTime.png"),Resolution=300)
                close all
            end
        end

        function  setConfigProperty(obj,s)
            %This method compares the properties of the handle object 'obj' with
            %the fields of a structure 'struct'. Then it sets the properties to the
            %values of the fields. The obj must inherit the set method from
            %matlab.mixin.SetGetExactNames
            mc = metaclass(obj); %use metaclass to access non-public properties
            propList = {mc.PropertyList.Name};
            fieldList = fieldnames(s);
            [~,ia,ib] = intersect(propList,fieldList);
            structcell = struct2cell(s);
            set(obj,propList(ia)',structcell(ib)')
            if isfield(s,"Parameter") && isstruct(s.Parameter)
                p = s.Parameter;
                fieldList = fieldnames(p);
                [~,ia,ib] = intersect(propList,fieldList);
                structcell = struct2cell(p);
                set(obj,propList(ia)',structcell(ib)')
            end
        end

        function updateDatabase(obj)
            sData = struct(obj);
            sData.SpaceOrigin = sData.SpaceOrigin.';
            sData.SpaceStep = sData.SpaceStep.';
            sData.SpaceRange = sData.SpaceRange.';
            tData = struct2table(sData,AsArray=true);
            rf = rowfilter('SerialNumber');
            rf = rf.SerialNumber == obj.SerialNumber;
            pgUpdate(obj.Writer,obj.DatabaseTableName,tData,rf);
        end

        function writeDatabase(obj)
            sData = struct(obj);
            sData = rmfield(sData,{'SimRun'});
            sData.SpaceOrigin = sData.SpaceOrigin.';
            sData.SpaceStep = sData.SpaceStep.';
            sData.SpaceRange = sData.SpaceRange.';
            tData = struct2table(sData,AsArray=true);
            pgWrite(obj.Writer,obj.DatabaseTableName,tData);
        end

        function updateTrialType(obj,trialName)
            arguments
                obj
                trialName string = string.empty
            end
            p = obj.SimSetting;

            s = struct(obj);
            s.OutputVariableName = obj.Output.VariableName;
            s.ParentPath = obj.ParentPath;
            s.DatabaseName = obj.DatabaseName;
            s.DatabaseTableName = obj.DatabaseTableName;
            para = struct;
            para.AtomName = s.Atom;
            para.TotalTime = s.TotalTime;
            para.TimeStep = s.TimeStep;
            para.SavePeriod = s.SavePeriod;
            para.AveragePeriod = s.AveragePeriod;
            para.SpaceRange = s.SpaceRange;
            para.SpaceStep = s.SpaceStep;
            s.Parameter = para;
            if isempty(trialName)
                s.TrialName = obj.Name;
            else
                s.TrialName = trialName;
            end
            s.SimName = string(class(obj));

            p.updateEntry(s,["SimName","TrialName"])
        end

    end


end

