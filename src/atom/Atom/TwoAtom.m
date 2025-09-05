classdef TwoAtom
    %:class:`TwoAtom` helper for coupled atoms with separate manifolds.
    %
    % **Examples:**
    %
    % .. code-block:: matlab
    %
    %    % Example1: Two rubidium atoms, D2 manifolds
    %    T = TwoAtom("Rubidium87","Rubidium87","D2","D2");
    %    H = T.HamiltonianAtom();
    
    properties (SetAccess = protected)
        Atom1 % First :class:`Atom` instance
        Atom2 % Second :class:`Atom` instance
    end

    properties
        Manifold1 % Manifold of atom1 (e.g., :class:`OneJManifold`, :class:`TwoJManifold`)
        Manifold2 % Manifold of atom2 (e.g., :class:`OneJManifold`, :class:`TwoJManifold`)
    end
    
    methods
        function obj = TwoAtom(atomName1,atomName2,manifoldName1,manifoldName2)
            % Construct a :class:`TwoAtom`.
            %
            % :param atomName1: First atom name (ARC-known)
            % :type atomName1: string
            % :param atomName2: Second atom name
            % :type atomName2: string
            % :param manifoldName1: Manifold property name for atom1
            % :type manifoldName1: string, optional
            % :param manifoldName2: Manifold property name for atom2
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
            % Build two-atom Hamiltonian (block-sum) at rotation frequency :math:`f_\mathrm{rot}`.
            %
            % .. math::
            %
            %    H = H_1 \otimes I_2 + I_1 \otimes H_2
            %
            % :param fRot: Rotation frequency [Hz]
            % :type fRot: double, optional
            % :param U: Basis transform
            % :type U: double matrix, optional
            % :return: Two-atom Hamiltonian [Hz] (Kronecker-sum form)
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

