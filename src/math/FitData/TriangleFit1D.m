classdef TriangleFit1D < FitData1D
    % Triangle wave function fit for one-dimensional data.
    %
    % Fits a triangle wave function with customizable rise and fall times to
    % experimental data. The function consists of linear rise and fall segments
    % with specified period and phase.
    %
    % - **Formula**:
    %
    %   :math:`u = (x + \phi) \bmod T`
    %
    %   :math:`y(u) = \begin{cases}
    %   A_{\min} + (A_{\max} - A_{\min})\, \dfrac{u}{T_r}, & 0 \le u < T_r \\
    %   A_{\max} - (A_{\max} - A_{\min})\, \dfrac{u - T_r}{T - T_r}, & T_r \le u < T
    %   \end{cases}`
    %
    % - **Coefficients**: :math:`A_{\max}`, :math:`A_{\min}`, :math:`\phi`, :math:`T`, :math:`T_r`
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Fit triangle wave to experimental data
    %     x = linspace(0, 20, 200);
    %     y = sawtooth(2*pi*0.2*x, 0.5) + 0.1*randn(size(x));
    %     data = [x', y'];
    %     triangleFit = TriangleFit1D(data);
    %     triangleFit.do();
    %     triangleFit.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Access fit parameters
    %     triangleFit = TriangleFit1D(data);
    %     triangleFit.do();
    %     amax = triangleFit.Coefficient(1); % maximum amplitude
    %     amin = triangleFit.Coefficient(2); % minimum amplitude
    %     phi = triangleFit.Coefficient(3);  % phase
    %     T = triangleFit.Coefficient(4);    % period
    %     Tr = triangleFit.Coefficient(5);   % rise time
    %

    properties

    end

    methods
        function obj = TriangleFit1D(rawData)
            % Constructor for TriangleFit1D class.
            %
            % :param rawData: Input data as n x 2 matrix [x, y]
            % :type rawData: double array
            %
            % **Example:**
            %
            % .. code-block:: matlab
            %
            %     data = [1:10; randn(1,10)].';
            %     triangleFit = TriangleFit1D(data);
            %
            obj@FitData1D(rawData)
        end

        function setFormula(obj)
            % Set the triangle wave fit formula.
            %
            obj.Func = fittype(['(mod((x + phi), T) < Tr) .* (Amin + (Amax - Amin) .* mod((x + phi), T) / Tr) +' ...
                '(mod((x + phi), T) >= Tr) .* (Amax -  (Amax - Amin) .* (mod((x + phi), T) - Tr) / (T - Tr))'],'independent', {'x'},...
                'coefficients', {'Amax','Amin','phi', 'T','Tr'});
        end

        function guessCoefficient(obj)
            % Automatically estimate initial fit parameters from data.
            %
            % Estimates maximum/minimum amplitudes, period, rise time, and phase
            % based on data characteristics and zero-crossing analysis.
            %
            if isempty(obj.DataSize) || obj.DataSize < obj.MinimumDataSize
                return
            end
            x = obj.RawData(:,1);
            y = obj.RawData(:,2);

            [xSort,sidx] = sort(x);
            ySort = y(sidx);
            amp = max(y) - min(y);

            % Period guess
            % guessPeriod = mean(diff(xSort(abs(diff(ySort)) > 0.5 * amp)));


            n = numel(x);
            xUnit = max(x)/n;
            yFT = nufft(y,x/xUnit);
            yFT(1) = 0;
            yFT = yFT(1:floor(n/2));
            fList = (0:floor(n/2)-1)/n / xUnit;
            [~,idx] = max(abs(yFT));
            guessPeriod = 1 / fList(idx(1));

            % Rise time guess
            guessRise = 0.5 *  guessPeriod;

            % Phase guess
            guessPhase = -mean(mod(x(y==min(y)),guessPeriod));

            obj.StartPoint = [max(y),min(y),guessPhase,guessPeriod,guessRise];
            obj.Lower = [max(y) - 0.2 * amp, min(y) - 0.2 * amp,-guessPeriod,guessPeriod*0.5,0];
            obj.Upper = [max(y) + 0.2 * amp, min(y) + 0.2 * amp,guessPeriod,guessPeriod*2,guessPeriod];
        end

    end
end

