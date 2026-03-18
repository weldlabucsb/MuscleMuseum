classdef LatticeFourierSeSim1D < TimeSim
    %SESIM Summary of this class goes here
    %   Detailed explanation goes here

    properties(SetAccess = private)
        Atom Atom
        AtomicState struct
        Laser cell
        MagneticField cell
        LatticeModulation cell
        FieldModulation cell
        OpticalLattice OpticalLattice
        MagneticPotential MagneticPotential
        InitialCondition InitialCondition
    end

    properties
        ScannedParameterList
    end

    methods
        function obj = LatticeFourierSeSim1D(trialName,options1,options2)
            arguments
                trialName string
                options1.atom Atom
                options1.atomicState struct
                options1.totalTime double
                options1.timeStep double
                options1.output string
                options2.laser cell
                options2.magneticField cell
                options2.latticeModulation cell
                options2.fieldModulation cell
                options2.initialCondition InitialCondition
            end
            obj@TimeSim(trialName,"LatticeFourierSeSim1D");

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
            if any(obj.Output.VariableName == "WaveFunction")
                obj.Output(obj.Output.VariableName == "WaveFunction",:).Size = numel(obj.InitialCondition(1).WaveFunction);
            end

            %% Find scanned parameter
            nPara = cellfun(@numel,struct2cell(options2));
            obj.NRun = max(nPara);
            if any(nPara(nPara~=obj.NRun)>1)
                error("Parameter lengths do not match")
            else
                scannedParaIdx = find(nPara==obj.NRun);
            end

            %% Set LatticeFourierSeSim1DRun parameters
            options0.atom = obj.Atom;
            options0.atomicState = obj.AtomicState;
            options0.totalTime = obj.TotalTime;
            options0.timeStep = obj.TimeStep;
            obj.SimRun = LatticeFourierSeSim1DRun.empty;
            for ii = 1:obj.NRun
                options = options0;
                for jj = 1:numel(field2)
                    if any(jj == scannedParaIdx)
                        if iscell(options2.(field2(jj)))
                            options.(field2(jj)) = options2.(field2(jj)){ii};
                        else
                            options.(field2(jj)) = options2.(field2(jj))(ii);
                        end
                    else
                        if iscell(options2.(field2(jj))) && ~isempty(options2.(field2(jj)))
                            options.(field2(jj)) = options2.(field2(jj)){1};
                        elseif ~isempty(options2.(field2(jj)))
                            options.(field2(jj)) = options2.(field2(jj));
                        end
                    end
                end
                varargin = struct2pairs(options);
                obj.SimRun(ii) = LatticeFourierSeSim1DRun(obj,varargin{:});
                obj.SimRun(ii).RunIndex = ii;
            end
            obj.update
        end

        function data = readBand(obj,bandNumber)
            nRun = obj.NRun;
            data = zeros(numel(bandNumber),nRun);
            for ii = 1:nRun
                ol = obj.SimRun(ii).OpticalLattice;
                q = obj.SimRun(ii).InitialCondition.QuasiMomentum;
                fOverHbar = obj.SimRun(ii).FOverHbar;
                t = obj.SimRun(ii).TimeList(end);
                qt = q + fOverHbar * t; 
                data(:,ii) = ol.computeBandPopulationFourier1D(obj.SimRun(ii).readRun("FinalWaveFunction"),qt,bandNumber);
            end
        end
        
        % function plotBand(obj,runIdx,bandNumber)
        %     psi = obj.SimRun(runIdx).readRun("WaveFunction");
        %     x = obj.SimRun(1).SpaceList;
        %     t = obj.SimRun(1).TimeListAvg * 1e3;
        %     pop = obj.OpticalLattice.computeBandPopulation1D(psi.',max(bandNumber),x);
        %     bandNumber = bandNumber + 1;
        %     pop = pop(:,bandNumber);
        %     figure(2943)
        %     plot(t,pop)
        %     render
        % end

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
        end

        function updateDatabase(obj)
            sData = struct(obj);
            tData = struct2table(sData,AsArray=true);
            rf = rowfilter('SerialNumber');
            rf = rf.SerialNumber == obj.SerialNumber;
            pgUpdate(obj.Writer,obj.DatabaseTableName,tData,rf);
        end

        function writeDatabase(obj)
            sData = struct(obj);
            sData = rmfield(sData,{'SimRun'});
            tData = struct2table(sData,AsArray=true);
            pgWrite(obj.Writer,obj.DatabaseTableName,tData);
        end

    end


end

