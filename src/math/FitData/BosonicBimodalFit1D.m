classdef BosonicBimodalFit1D < FitData1D
    % Thomas-Fermi condensate + thermal Gaussian

    properties
        ScaleFactor double = 1.1  % Exclusion radius factor
    end

    methods
        function obj = BosonicBimodalFit1D(rawData)
            obj@FitData1D(rawData);
        end

        function setFormula(obj)
            
            obj.Func = fittype( ...
              ['A*((max(0,1-((x-x0)./R).^2))).^(3/2) + ', ...
               'B*exp(-(x-xg).^2/(2*sg^2)) + C'], ...
              'independent','x', ...
              'coefficients',{'A','x0','R','B','xg','sg','C'});
        end

        function guessCoefficient(obj)
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
              'B*exp(-(x-xg).^2/(2*sg^2)) + C', ...
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
            % Build fitoptions from guesses and solver tolerances
            opts = fitoptions(obj.Func);
            opts.StartPoint = obj.StartPoint;
            opts.Lower      = obj.Lower;
            opts.Upper      = obj.Upper;
            opts.TolFun     = obj.TolFun;
            opts.MaxFunEvals= obj.MaxFunEvals;
            opts.MaxIter    = obj.MaxIter;

            % optional: down‐weight the TF core
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);
            w = ones(size(y));
            core = abs(x - obj.StartPoint(2)) <= obj.StartPoint(3);
            w(core) = 0.5;
            opts.Weights = w;

            % Execute the combined fit
            [f, gof] = fit(x, y, obj.Func, opts);

            obj.Result      = f;
            obj.Gof         = gof;
            obj.Coefficient = coeffvalues(f);
        end
    end
end
