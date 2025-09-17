classdef IsoscelesTriangleFit1D < FitData1D
    %:class:`IsoscelesTriangleFit1D` fits isosceles triangle wave functions to 1D data.
    %
    % Fits symmetric triangle wave functions where rise and fall times are equal
    % (isosceles triangles) to experimental data. The function consists of linear
    % rise and fall segments with specified period and phase. Inherits from
    % :class:`FitData1D`.
    %
    % **Formula:**
    %
    %   :math:`u = (x + \phi) \bmod T`
    %
    %   :math:`y(u) = \begin{cases}
    %   A_{\min} + (A_{\max} - A_{\min})\, \dfrac{u}{T/2}, & 0 \le u < T/2 \\
    %   A_{\max} - (A_{\max} - A_{\min})\, \dfrac{u - T/2}{T/2}, & T/2 \le u < T
    %   \end{cases}`
    %
    % **Coefficients:** :math:`A_{\max}`, :math:`A_{\min}`, :math:`\phi`, :math:`T`
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit isosceles triangle wave to experimental data
    %     x = linspace(0, 20, 200);
    %     y = sawtooth(2*pi*0.2*x, 0.5) + 0.1*randn(size(x));
    %     data = [x', y'];
    %     triangleFit = IsoscelesTriangleFit1D(data);
    %     triangleFit.do();
    %     triangleFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit coefficients
    %     triangleFit = IsoscelesTriangleFit1D(data);
    %     triangleFit.do();
    %     amax = triangleFit.Coefficient(1); % maximum amplitude
    %     amin = triangleFit.Coefficient(2); % minimum amplitude
    %     phi = triangleFit.Coefficient(3);  % phase
    %     T = triangleFit.Coefficient(4);    % period
    %

    properties

    end

    methods
        function obj = IsoscelesTriangleFit1D(rawData)
            % Construct an :class:`IsoscelesTriangleFit1D` object.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the isosceles triangle wave fit formula.
            %
            % Configures the :attr:`Func` property with an isosceles triangle function
            % where rise time equals fall time (T/2 each).
            %
            obj.Func = fittype(['(mod((x + phi), T) < T/2) .* (Amin + (Amax - Amin) .* mod((x + phi), T) / (T/2)) +' ...
                '(mod((x + phi), T) >= T/2) .* (Amax -  (Amax - Amin) .* (mod((x + phi), T) - (T/2)) / (T/2))'],'independent', {'x'},...
                'coefficients', {'Amax','Amin','phi', 'T'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit coefficients from data.
            %
            % Estimates maximum/minimum amplitudes, period, and phase based on
            % data characteristics and Fourier analysis. Uses isosceles assumption
            % with equal rise and fall times.
            %
            if isempty(obj.DataSize) || obj.DataSize < obj.MinimumDataSize
                return
            end
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);
            amp = max(y) - min(y);

            % Period guess
            n = numel(x);
            xUnit = max(x)/n;
            yFT = nufft(y,x/xUnit);
            yFT(1) = 0;
            yFT = yFT(1:floor(n/2));
            fList = (0:floor(n/2)-1)/n / xUnit;
            [~,idx] = max(abs(yFT));
            guessPeriod = 1 / fList(idx(1));

            % Phase guess
            guessPhase = -mean(mod(x(y==min(y)),guessPeriod));

            obj.StartPoint = [max(y),min(y),guessPhase,guessPeriod];
            obj.Lower = [max(y) - 0.2 * amp, min(y) - 0.2 * amp,-guessPeriod,guessPeriod*0.5];
            obj.Upper = [max(y) + 0.2 * amp, min(y) + 0.2 * amp,guessPeriod,guessPeriod*2];
        end

    end
end

