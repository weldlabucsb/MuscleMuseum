classdef TwoAtom
    %:class:`TwoAtom` coupled two-atom helper with separate manifolds.
    
    properties (SetAccess = protected)
        Atom1
        Atom2
    end

    properties
        Manifold1
        Manifold2
    end
    
    methods
        function obj = TwoAtom(atomName1,atomName2,manifoldName1,manifoldName2)
            % Construct a :class:`TwoAtom`.
            %
            % :param atomName1: First atom name (ARC-known)
            % :type atomName1: string
            % :param atomName2: Second atom name
            % :type atomName2: string
            % :param manifoldName1: Optional manifold property name for atom1
            % :type manifoldName1: string, optional
            % :param manifoldName2: Optional manifold property name for atom2
            % :type manifoldName2: string, optional
            arguments
                atomName1 string
                atomName2 string
                manifoldName1 string = string.empty
                manifoldName2 string = string.empty
            end
            obj.Atom1 = getAtom(atomName1);
            obj.Atom2 = getAtom(atomName2);
            if ~isempty(manifoldName1)
                obj.Manifold1 = obj.Atom1.(manifoldName1);
            end
            if ~isempty(manifoldName2)
                obj.Manifold2 = obj.Atom2.(manifoldName2);
            end
        end
        
        function Ha = HamiltonianAtom(obj,fRot,U)
            % Build two-atom Hamiltonian (sum) at rotation frequency :math:`f_\mathrm{rot}`.
            %
            % :param fRot: Rotation frequency [Hz]
            % :type fRot: double, optional
            % :param U: Optional basis transform
            % :type U: double matrix, optional
            % :return: Block-sum Hamiltonian :math:`H_1 \oplus H_2`
            % :rtype: double matrix
            arguments
                obj TwoAtom
                fRot double = 0
                U double = 1
            end
            Ha1 = obj.Manifold1.HamiltonianAtom(fRot,U);
            eye1 = eye(obj.Manifold1.NNState);
            Ha2 = obj.Manifold2.HamiltonianAtom(fRot,U);
            eye2 = eye(obj.Manifold2.NNState);
            Ha = kron(Ha1,eye2) + kron(eye1,Ha2);
        end
    end
end

