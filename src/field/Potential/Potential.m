classdef (Abstract) Potential < handle
    %:class:`Potential` is an abstract base for particle potentials.
    %
    % Encapsulates an :class:`Atom` context and a short name for the potential,
    % with optional manifold and state index information for internal state.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    % See concrete subclasses like :class:`OpticalTrap` or :class:`OpticalLattice`.
    %
    properties (SetAccess = protected)
        Atom Atom % Atom used to compute recoil, polarizability, etc.
        Name string % Short human-readable label for the potential
    end

    properties
        AtomicState struct % Quantum state of the atom. Including quantum numbers like N,L,J...
    end
    
    methods
        function obj = Potential(atom,name,options)
            % Construct a :class:`Potential`.
            %
            % :param atom: Atom context for computing derived quantities
            % :type atom: :class:`Atom`
            % :param name: A short name/label for the potential
            % :type name: string
            arguments
                atom Atom
                name string
                options.atomicState = struct.empty
            end
            obj.Atom = atom;
            obj.Name = name;

            if ~isempty(options.atomicState)
                obj.AtomicState = options.atomicState;
            else
                % Assign default atomic state as the ground state
                s.N = atom.groundStateN;
                s.L = 0;
                s.J = 1/2;
                s.F = min(totalAngularMomentum(1/2,atom.I));
                s.MF = -s.F;
                obj.AtomicState = s;
            end
        end
        
    end
end

