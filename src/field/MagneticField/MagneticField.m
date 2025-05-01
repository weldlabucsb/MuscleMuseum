classdef MagneticField
    %MAGFIELD Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Bias double = zeros(3,1) %In Tesla.
        Gradient double = zeros(3,3) %[dBx/dx,dBx/dy,dBx/dz;dBy/dx,dBy/dy,dBy/dz;dBz/dx,dBz/dy,dBz/dz]. %In Tesla/meter
        Quadratic double = zeros(3,3,3) %not implemented.
        ArbitraryDistribution function_handle
    end

    properties(Dependent)
        BiasLu %In Gauss
        GradientLu %In Gauss/cm
        FieldZero %In meter
    end

    methods

        function obj = MagneticField(options)
            arguments
                options.bias double = zeros(3,1)
                options.gradient double = zeros(3,3)
                options.quadratic double = zeros(3,3,3)
                options.distribution function_handle = function_handle.empty
            end
            if ~isempty(options.distribution)
                obj.ArbitraryDistribution = options.distribution;
            else
                obj.Bias = options.bias;
                obj.Gradient = options.gradient;
                obj.Quadratic = options.quadratic;
            end
        end

        function biasLu = get.BiasLu(obj)
            biasLu = obj.Bias * 1e4;
        end

        function gradLu = get.GradientLu(obj)
            gradLu = obj.Gradient * 1e2;
        end

        function fieldZero = get.FieldZero(obj)
            fieldZero = -obj.Bias./diag(obj.Gradient);
        end

        function func = spaceFunc(obj)  
            bias = obj.Bias;
            grad = obj.Gradient;
            quad = obj.Quadratic;
            if ~isempty(obj.ArbitraryDistribution)
                func = obj.ArbitraryDistribution;
            else
                func = @(r) sFunc(r);
            end
            function B = sFunc(r)
                B = bias + grad*r + ...
                    [sum(r.*(squeeze(quad(1,:,:))*r),1);
                    sum(r.*(squeeze(quad(2,:,:))*r),1);
                    sum(r.*(squeeze(quad(3,:,:))*r),1)];
            end
        end

    end

end

