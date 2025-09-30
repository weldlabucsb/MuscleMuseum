classdef (Abstract) Atom < dynamicprops & handle & matlab.mixin.Heterogeneous
    %:class:`Atom` stores information about alkali/divalent atoms and
    %calculates the atomic structure. This class is based on the
    %well-established python package, `ARC (Alkali.ne Rydberg Calculator)
    %<https://arc-alkali-rydberg-calculator.readthedocs.io/en/latest/>`_.
    %Most (but not all) of the atomic data are inherited from the ARC
    %package. I have edited the ARC atomic data in ``arcDataEdit.py`` and
    %``lithium7_literature_dme.csv`` to include more up-to-date data. Some
    %ARC functions have defects or convention conflicts so I have to
    %rewrite.
    %
    %   Note: I follow the conventions in Daniel Steck's `Quantum and Atom
    %   Optics
    %   <https://atomoptics.uoregon.edu/~dsteck/teaching/quantum-optics/>`_
    %   to define, e.g., the transition matrix elements.
    
    properties (SetAccess = protected)
        Name string %e.g., "Lithium7". Check the ARC documents for available atoms.
        DataPath string %Where to save the pre-calcualted data, e.g., the :math:`|M_I,M_J\rangle \leftrightarrow |F,M_F\rangle` mapping data. Distinguish this with the dataFolder property that pointing to the arc atomic data.
    end

    properties (SetAccess = private)
        ArcObj % ARC atom object (Python)
        Type string {mustBeMember(Type,{'Alkali','Divalent'})} % Either "Alkali" or "Divalent"
    end
    
    methods
        function obj = Atom(atomName)
            % Construct an :class:`Atom` and mirror ARC properties.
            %
            % Creates ARC object, mirrors its attributes to dynamic MATLAB
            % properties, infers :attr:`Type`, and prepares :attr:`DataPath`.
            %
            % :param atomName: Atom/isotope name (ARC-known), e.g., "Lithium7"
            % :type atomName: string
            arguments
                atomName string
            end

            obj.Name = atomName; 
            arc = py.importlib.import_module('arcDataEdit'); %Import the ARC python package. The package is edited to include more accurate atomic data.
            pyType = py.importlib.import_module('getTypeNature'); %Import this python module for resolving type name/attributes etc.
            try
                obj.ArcObj = arc.(atomName)(preferQuantumDefects=false); %Load the ARC atom object
            catch ME
                error(atomName + " may not be a valid isotope name in the python ARC package. Error message: " ...
                    + ME.message)
            end

            % Mirror Python attributes to MATLAB dynamic properties
            s = struct(pyType.attributes(obj.ArcObj));  
            fieldList = fieldnames(s);
            for ii = 1:numel(fieldList)
                addprop(obj,fieldList{ii}); %Add properties
                obj.(fieldList{ii}) = py2Mat(s.(fieldList{ii})); %Convert python data type to matlab data type.
            end
            
            %Check the atom type
            tName = string(pyType.baseTypeName(obj.ArcObj));
            if any(cell2mat(strfind(tName,"divalent")))
                obj.Type = "Divalent";
            elseif any(cell2mat(strfind(tName,"alkali")))
                obj.Type = "Alkali";
            end

            % Set data path (distinct from ARC data folder)
            obj.DataPath = fullfile(getHome,"Documents","MMUser","atomData");
            createFolder(obj.DataPath);
        end

        function s = saveobj(obj)
            % Save minimal state (:attr:`Type`, :attr:`Name`).
            s.Type = obj.Type;
            s.Name = obj.Name;
        end
    end

    methods (Static)
        function obj = loadobj(s) 
            % Reconstruct from (:attr:`Type`, :attr:`Name`).
            if isstruct(s)
                switch s.Type
                    case "Alkali"
                        obj = Alkali(s.Name);
                    case "Divalent"
                        obj = Divalent(s.Name);
                end
            else
                obj = s;
            end
        end
    end

end

