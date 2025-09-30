function [xUni,dataAve,dataError] = computeAveErr(x,data, method)
% :meth:`computeAveErr` Compute grouped averages and errors for repeated x values.
%
% Computes the average and an error metric of :math:`\text{data}` grouped by
% repeated entries in :math:`x`. The input :attr:`x` must be a vector with
% :math:`N` samples. The input :attr:`data` can be either a vector of length
% :math:`N`, or an N-D array whose last dimension has size :math:`N` (samples
% along the last axis). Grouping is performed by unique values of :attr:`x`.
%
% The error is controlled by :attr:`method`:
%
% - **"None"**: return grouped means with zero-valued errors.
% - **"StdDev"**: return the (unbiased) sample standard deviation per group.
% - **"StdErr"**: return the standard error of the mean per group,
%   :math:`\mathrm{SE}=\sigma/\sqrt{n}`.
%
% Internally, for N-D inputs a sparse-selection strategy is used to compute
% group sums and counts efficiently. Variance is computed via
% :math:`\mathrm{Var}(X)=\mathbb{E}[X^2]-\mathbb{E}[X]^2` with the unbiased
% correction :math:`n/(n-1)` for groups with :math:`n>1`; singletons have zero
% variance and zero error.
%
% **Parameters:**
%
% - **x** (double): Vector of independent values of length :math:`N`.
% - **data** (double): Measured values; either a vector of length :math:`N`,
%   or an array with size ``[..., N]`` where the last dimension indexes samples.
% - **method** (string, optional): One of ``"None"``, ``"StdDev"``, ``"StdErr"``;
%   default is ``"StdErr"``.
%
% **Returns:**
%
% - **xUni** (double): Sorted unique values of :attr:`x`, length :math:`G`.
% - **dataAve** (double): Grouped means with size ``[..., G]`` matching
%   :attr:`data` except that the last dimension is :math:`G`.
% - **dataError** (double): Grouped error (per :attr:`method`) with the same
%   size as :attr:`dataAve`.
%
% **Examples:**
%
% - **Example1 (vector data):**
%   ``[xUni, yAve, yErr] = computeAveErr([1 1 2 2 3], [5 7 1 2 9], method="StdErr");``
%
% - **Example2 (N-D data, samples on last dim):**
%   ``data = rand(4,5,100); x = repelem(1:10,10);``
%   ``[xUni, mAve, mErr] = computeAveErr(x, data, method="StdDev");``
%
arguments
    x double {mustBeVector}
    data double
    method string = "StdErr"
end

% --- Input Validation ---
dataDim = ndims(data);
nSample = numel(x);
isVector = isvector(data);
if nSample == 1
    % For scalar input just return the input
    xUni = x;
    dataAve = data;
    dataError = zeros(size(data));
    return
elseif isVector
    % For vector input check the size
    if numel(data) ~= nSample
        error('The number of elements in x must match the number of elements in data if data is a vector.');
    end
elseif nSample ~= size(data, dataDim)
    % For matrix input check the size
    error('The number of elements in x must match the size of the last dimension of data.');
end


% --- Find unique x values and group indices ---
[xUni, ~, indices] = unique(x);
nGroup = numel(xUni);

% --- Handle Case: x is already unique ---
if method == "None" || nSample == nGroup
    [xUni, sortOrder] = sort(x);
    if isVector
        dataAve = data(sortOrder);
    else
        % Reorder the last dimension of the matrix
        colonIndice = repmat({':'}, 1, dataDim - 1);
        dataAve = data(colonIndice{:}, sortOrder);
    end
    dataError = zeros(size(xUni));
    return;
end

% --- Averaging and Error Calculation ---
if isVector
    % --- Method 1: Vector data (use simple accumarray) ---
    dataAve = accumarray(indices, data, [nGroup, 1], @mean);
    if size(data,1) == 1
        dataAve = dataAve.';
    end
    if nargout < 3
        return
    end

    if method == "StdDev"
        % Standard deviation
        dataError = accumarray(indices, data, [nGroup, 1], @std, 0);
    elseif method == "StdErr"
        % Standard error (std/sqrt(n))
        groupCount = accumarray(indices, 1, [nGroup, 1]);
        stdDev = accumarray(indices, data, [nGroup, 1], @std, 0);
        dataError = stdDev ./ sqrt(groupCount);
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
    end

    if size(data,1) == 1
        dataError = dataError.';
    end

else
    % --- Method 2: N-D data (use sparse matrix for speed) ---
    dataSize = size(data);
    dataSizeOther = dataSize(1:dataDim-1);

    % Reshape data to 2D for matrix operations
    data2D = reshape(data, [], nSample);

    % Create sparse grouping matrix
    S = sparse(indices, 1:nSample, 1, nGroup, nSample);

    % Calculate group sums and counts
    groupSum2D = full(data2D * S.');
    groupCount = full(sum(S, 2).'); % This is a column vector

    % Calculate average
    dataAve2D = groupSum2D ./ groupCount; % Transpose counts for broadcasting
    outputSize = [dataSizeOther, nGroup];
    dataAve = reshape(dataAve2D, outputSize);
    if nargout < 3
        return
    end

    % Calculate error
    if method == "StdDev" || method == "StdErr"
        % To get std, we use Var(X) = E[X^2] - (E[X])^2
        meanOfSquares2D = (data2D.^2 * S') ./ groupCount;
        variance2D = meanOfSquares2D - dataAve2D.^2;

        % Correct for sample variance (n-1 denominator) vs population variance (n)
        % and handle groups with a single member (variance is 0)
        isSingleMember = (groupCount <= 1);
        correctionFactor = groupCount ./ max(groupCount - 1, 1);
        correctionFactor(isSingleMember) = 0; % Avoid division by zero, std is 0

        stdDev2D = sqrt(max(variance2D .* correctionFactor,0));

        if method == "StdErr"
            dataError2D = stdDev2D ./ sqrt(groupCount);
        else
            dataError2D = stdDev2D;
        end
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
    end

    % Reshape results back to original N-D structure

    dataError = reshape(dataError2D, outputSize);
end

end