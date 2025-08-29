classdef Constants
    %:class:`Constants` provides a subset of physical constants and unit helpers.
    %
    % Values are SI by default and accessible via :meth:`SI`. For convenience,
    % :meth:`Micro` loads a scaled set useful for micron-microsecond-kilogram units.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    hbar = Constants.SI("hbar");
    %    Constants.SI();    % load named constants into caller
    %    Constants.Micro(); % load scaled constants into caller
    %
    properties (Constant)
        SpeedOfLight = 2.99792458e8 % c.
        VacuumPermeability = 4*pi*1e-7 % mu0.
        VacuumPermittivity = 8.854187817e-12 % epsilon0.
        ReducedPlanckConstant = 1.054571628e-34 % hbar.
        ElementaryCharge = 1.602176487e-19 % e.
        BohrMagneton = 9.27400915e-24 % muB.
        ElectronMass = 9.10938215e-31 % me.
        BohrRadius = 0.52917720859e-10 % a0.
        BoltzmannConstant = 1.3806504e-23 % kB.
        VacuumImpedance = 1/Constants.VacuumPermittivity/Constants.SpeedOfLight % Z0.
        ElectronSpin = 0.5 % Se.
        ElectronGFactor = 2.0023193043622 % gS.
    end
    
    properties (Constant, Hidden)
        List = struct('Name',{"c","mu0","epsilon0","hbar","e","muB","me","a0","kB","Z0","Se","gS"},...
            "Value",{Constants.SpeedOfLight,Constants.VacuumPermeability,Constants.VacuumPermittivity,...
            Constants.ReducedPlanckConstant,Constants.ElementaryCharge,Constants.BohrMagneton,...
            Constants.ElectronMass,Constants.BohrRadius,Constants.BoltzmannConstant,Constants.VacuumImpedance,...
            Constants.ElectronSpin,Constants.ElectronGFactor});
    end
    
    methods (Static)
        
        function constantValue = SI(constantName)
            % Load constants in SI units into the caller workspace.
            %
            % :param constantName: If provided, return the named constant value instead
            % :type constantName: string, optional
            % :return: Constant value when ``constantName`` is provided
            % :rtype: double, optional
            vList = Constants.List;
            callerList = convertCharsToStrings(evalin('caller','who'));
            if nargin == 1
                names = [vList.Name];
                constantValue = vList(names == constantName).Value;
                return
            end 
            
            for iVar = 1:numel(vList)
                name = vList(iVar).Name;
                value = vList(iVar).Value;
                if find(callerList == name)
                    if evalin('caller',name) ~= value
                        warning(strcat("Variable ",name," already exists."))
                    end
                else
                    assignin('caller',name,value)
                end
            end
        end
        
        function constantValue = Micro(constantName)
            % Load constants in micron–microsecond–kilogram units into caller.
            %
            % :param constantName: If provided, return the named constant value instead
            % :type constantName: string, optional
            % :return: Constant value when ``constantName`` is provided
            % :rtype: double, optional
            vList = Constants.List;
            vList(1).Value = vList(1).Value;
            vList(2).Value = vList(2).Value*1e-6;
            vList(3).Value = vList(3).Value*1e6;
            vList(4).Value = vList(4).Value*1e6;
            vList(5).Value = vList(5).Value*1e6;
            vList(6).Value = vList(6).Value*1e12;
            vList(7).Value = vList(7).Value*1e12;
            vList(8).Value = vList(8).Value*1e6;
            vList(9).Value = vList(9).Value;
            vList(10).Value = vList(10).Value*1e-6;
            callerList = convertCharsToStrings(evalin('caller','who'));
            
            if nargin == 1
                names = [vList.Name];
                constantValue = vList(names == constantName).Value;
                return
            end 
            
            for iVar = 1:numel(vList)
                name = vList(iVar).Name;
                value = vList(iVar).Value;
                if find(callerList == name)
                    if evalin('caller',name) ~= value
                        warning(strcat("Variable ",name," already exists."))
                    end
                else
                    assignin('caller',name,value)
                end
            end
        end
        
    end
end

