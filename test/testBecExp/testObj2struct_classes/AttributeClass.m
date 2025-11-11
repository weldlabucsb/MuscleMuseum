classdef AttributeClass
    properties
        PublicProp = 1
    end
    properties (Hidden)
        HiddenProp = 2
    end
    properties (Transient)
        TransientProp = 3
    end
    properties (Dependent)
        DependentProp
    end
    methods
        function val = get.DependentProp(obj)
            val = obj.PublicProp * 10;
        end
    end
end

