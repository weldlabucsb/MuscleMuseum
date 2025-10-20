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
        Manifold string % Atomic manifold identifier (e.g., "DGround")
        StateIndex double % State index within manifold (e.g., Zeeman sublevel)
    end
    
    methods
        function obj = Potential(atom,name)
            % Construct a :class:`Potential`.
            %
            % :param atom: Atom context for computing derived quantities
            % :type atom: :class:`Atom`
            % :param name: A short name/label for the potential
            % :type name: string
            arguments
                atom Atom
                name string
            end
            obj.Atom = atom;
            obj.Name = name;
        end
        
    end
end

