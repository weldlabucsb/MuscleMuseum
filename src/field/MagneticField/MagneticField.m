classdef MagneticField
    %:class:`MagneticField` defines static or spatially varying magnetic fields.
    %
    % Supports uniform bias, gradients, and quadratic terms, or a fully custom
    % spatial distribution via :meth:`spaceFunc`. Provides derived-unit views
    % and the field zero :attr:`FieldZero` (for diagonal gradient).
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    B = MagneticField(bias=[0;0;5e-4], gradient=diag([10,10,30])*1e-2);
    %    Bz = B.spaceFunc();
    %    B0 = B.FieldZero;
    %
    properties
        Bias (3,1) double = zeros(3,1) % Uniform bias field :math:`\mathbf{B}_0=(B_x,B_y,B_z)` in [T]
        Gradient (3,3) double = zeros(3,3) % Gradient matrix :math:`\partial B_i/\partial x_j` in [T/m]
        Quadratic (3,3,3) double = zeros(3,3,3) % Quadratic tensor (not implemented)
        ArbitraryDistribution function_handle % Custom :math:`\mathbf{B}(\mathbf{r})` overriding components
    end

    properties(Dependent)
        BiasLu % Bias in [G]
        GradientLu % Gradient in [G/cm]
        FieldZero % Field-zero position :math:`\mathbf{r}_0` in [m] (diagonal gradient)
    end

    methods

        function obj = MagneticField(options)
            % Construct a :class:`MagneticField`.
            %
            % :param bias: Uniform bias :math:`\mathbf{B}_0=(B_x,B_y,B_z)` in [T]
            % :type bias: double(3,1), optional
            % :param gradient: Gradient matrix :math:`\partial B_i/\partial x_j` in [T/m]
            % :type gradient: double(3,3), optional
            % :param quadratic: Quadratic tensor (not yet implemented)
            % :type quadratic: double(3,3,3), optional
            % :param distribution: Custom spatial distribution :math:`\mathbf{B}(\mathbf{r})`
            % :type distribution: function_handle, optional
            %
            % If ``distribution`` is provided, sets :attr:`ArbitraryDistribution` and bypasses
            % :attr:`Bias`, :attr:`Gradient`, and :attr:`Quadratic`.
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
            % Get bias field in Gauss.
            %
            % :return: :math:`\mathbf{B}_0` in [G]
            % :rtype: double(3,1)
            biasLu = obj.Bias * 1e4;
        end

        function gradLu = get.GradientLu(obj)
            % Get gradient in Gauss/cm.
            %
            % :return: :math:`\partial B_i/\partial x_j` in [G/cm]
            % :rtype: double(3,3)
            gradLu = obj.Gradient * 1e2;
        end

        function fieldZero = get.FieldZero(obj)
            % Get position :math:`\mathbf{r}_0` where :math:`\mathbf{B}(\mathbf{r}_0)=0` (diag gradient).
            %
            % :return: Field-zero position :math:`\mathbf{r}_0` in [m]
            % :rtype: double(3,1)
            fieldZero = -obj.Bias./diag(obj.Gradient);
        end

        function func = spaceFunc(obj)  
            % Build spatial magnetic field function :math:`\mathbf{B}(\mathbf{r})`.
            %
            % :return: function handle mapping :math:`\mathbf{r}` to :math:`\mathbf{B}(\mathbf{r})`
            % :rtype: function_handle
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

