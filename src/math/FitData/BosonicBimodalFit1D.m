classdef BosonicBimodalFit1D < FitData1D
    %:class:`BosonicBimodalFit1D` fits a TF condensate + thermal Gaussian.
    %
    % Models a one-dimensional atomic density profile as the sum of a
    % Thomas–Fermi (condensate) component and a thermal (bosonic) Gaussian
    % wing.
    %
    % - **Formula**: :math:`y = A\,\max\{0,1-((x-x_0)/R)^2\}^{3/2} + B\,\mathrm{Bose}(e^{-(x-x_g)^2/(2\sigma_g^2)};2.5) + C`
    % - **Coefficients**: TF: :math:`A,x_0,R`; Thermal: :math:`B,x_g,\sigma_g`; Offset: :math:`C`
    %
    % Provides a multi-stage initialization routine to generate robust
    % starting values for the final composite fit.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     x = linspace(-5, 5, 201)';
    %     tf  = 1.5 * max(0, 1 - ((x-0.2)/1.2).^2).^(3/2);
    %     th  = 0.6 * boseFunctionApprox(exp(-(x+0.4).^2/(2*0.8^2)), 2.5);
    %     y   = tf + th + 0.05;
    %     data = [x, y];
    %     fitObj = BosonicBimodalFit1D(data);
    %     fitObj.do();
    %     fitObj.plot();

    properties (Constant)
        ScaleFactor double = 1.1  % Exclusion radius factor
    end

    methods
        function obj = BosonicBimodalFit1D(rawData)
            % Construct a :class:`BosonicBimodalFit1D`.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            obj@FitData1D(rawData);
        end

        function setFormula(obj)
            % Set the bimodal fit formula (TF + thermal Gaussian).
            %
            obj.Func = fittype( ...
              ['A*((max(0,1-((x-x0)./R).^2))).^(3/2) + ', ...
               'B*boseFunctionApprox(exp(-(x-xg).^2/(2*sg^2)),2.5) + C'], ...
              'independent','x', ...
              'coefficients',{'A','x0','R','B','xg','sg','C'});
        end

        function guessCoefficient(obj)
            % Generate initial parameter guesses via staged fitting.
            %
            % Step 1: Fit the TF core with a clamped profile to get :math:`A,x_0,R,C`.
            % Step 2: Fit the wings with the thermal component to get :math:`B,x_g,\sigma_g`.
            % Step 3: Assemble composite start points and bounds.
            %
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);

            %% STEP 1: TF‐only fit
            % initial guesses
            x0g = mean(x);
            Rg  = (max(x)-min(x))/4;

            % enforce (1 - ((x-x0g)/Rg)^2) ≥ 0
            frac  = (x - x0g)/Rg;
            mask1 = abs(frac) <= 1;
            x1 = x(mask1);   y1 = y(mask1);

            % zero‐clamped TF fittype
            tfType = fittype( ...
              'A*((max(0,1-((x-x0)./R).^2))).^(3/2) + C', ...
              'independent','x','coefficients',{'A','x0','R','C'});

            opts1 = fitoptions(tfType);
            opts1.StartPoint = [max(y1), x0g, Rg, min(y1)];
            opts1.Lower      = [0, min(x1), eps, min(y1)];
            opts1.Upper      = [1.5*max(y1), max(x1), max(x1)-min(x1), max(y1)];

            fit1 = fit(x1, y1, tfType, opts1);
            A0  = fit1.A;
            x00 = fit1.x0;
            R0  = fit1.R;
            C0  = fit1.C;

            %% STEP 2: thermal Gaussian on wings
            mask2 = abs(x - x00) > obj.ScaleFactor * R0;
            x2 = x(mask2);   y2 = y(mask2);

            gaussType = fittype( ...
              'B*boseFunctionApprox(exp(-(x-xg).^2/(2*sg^2)),2.5) + C', ...
              'independent','x','coefficients',{'B','xg','sg','C'});

            opts2 = fitoptions(gaussType);
            opts2.StartPoint = [max(y2)-min(y2), x00, R0, C0];
            opts2.Lower      = [0, x00-R0, eps, min(y2)];
            opts2.Upper      = [1.5*(max(y2)-min(y2)), x00+R0, max(x)-min(x), max(y2)];

            fit2 = fit(x2, y2, gaussType, opts2);
            B0  = fit2.B;
            xg0 = fit2.xg;
            sg0 = fit2.sg;

            %% STEP 3: final guesses & bounds
            obj.StartPoint = [A0, x00, R0, B0, xg0, sg0, C0];
            obj.Lower      = [ ...
                0,    min(x),    eps, ...   % A,x0,R
                0,    x00-R0,    eps, ...   % B,xg,sg
                min(y)                      % C
            ];
            obj.Upper      = [ ...
                1.5*A0, max(x),  max(x)-min(x), ...  % A,x0,R
                1.5*B0, x00+R0,  max(x)-min(x), ...  % B,xg,sg
                max(y)                               % C
            ];
        end

        function obj = do(obj)
            % Perform the composite bimodal fit with optional weighting.
            %
            % Down-weights the TF core to stabilize the combined fit; runs the
            % final fit using the assembled options and stores results.
            %
            % :return: Self-reference for method chaining
            % :rtype: :class:`BosonicBimodalFit1D`
            %
            % optional: down‐weight the TF core
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);
            w = ones(size(y));
            core = abs(x - obj.StartPoint(2)) <= obj.StartPoint(3);
            w(core) = 0.5;
            opts.Weights = w;

            % Execute the combined fit
            [f, gof] = fit(x, y, obj.Func, obj.Option);

            obj.Result      = f;
            obj.Gof         = gof;
            obj.Coefficient = coeffvalues(f);
        end
    end
end
