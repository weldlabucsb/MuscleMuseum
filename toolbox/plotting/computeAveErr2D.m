function [xUni,yUni,dataAve,dataError] = computeAveErr2D(x,y,data, method)
% :meth:`computeAveErr2D` Compute grouped 2D averages and errors over (x,y) bins.
%
% Groups samples by the unique pairs :math:`(x,y)` and computes the mean and an
% error metric of :math:`\text{data}` per 2D bin. Inputs :attr:`x` and :attr:`y`
% are vectors of length :math:`N`. The input :attr:`data` can be either a vector
% of length :math:`N`, or an N-D array whose last dimension has size :math:`N`
% (samples on the last axis). The outputs are arranged on a grid of size
% :math:`(n_y, n_x)` determined by the unique, sorted values of :attr:`y` and
% :attr:`x` respectively. For N-D inputs, the output size is ``[..., n_y, n_x]``.
%
% The error is selected by :attr:`method`:
%
% - **"None"**: return means with zero-valued errors.
% - **"StdDev"**: return unbiased sample standard deviation per bin.
% - **"StdErr"**: return standard error per bin,
%   :math:`\mathrm{SE}=\sigma/\sqrt{n}`.
%
% Internally, vector inputs use ``accumarray`` on linearized 2D indices, while
% N-D inputs use a sparse-selection approach similar to :meth:`computeAveErr`
% to compute sums and counts efficiently. Variance uses
% :math:`\mathrm{Var}(X)=\mathbb{E}[X^2]-\mathbb{E}[X]^2` with the unbiased
% correction :math:`n/(n-1)` for :math:`n>1`; singleton bins have zero variance
% and zero error.
%
% **Parameters:**
%
% - **x** (double): Vector of independent x-values of length :math:`N`.
% - **y** (double): Vector of independent y-values of length :math:`N`.
% - **data** (double): Measured values; either length-:math:`N` vector, or array
%   with size ``[..., N]`` where the last dimension indexes samples.
% - **method** (string, optional): One of ``"None"``, ``"StdDev"``, ``"StdErr"``;
%   default is ``"StdErr"``.
%
% **Returns:**
%
% - **xUni** (double): Sorted unique x values, length :math:`n_x`.
% - **yUni** (double): Sorted unique y values, length :math:`n_y`.
% - **dataAve** (double): Grouped means with size ``[..., n_y, n_x]``.
% - **dataError** (double): Grouped error (per :attr:`method`) with the same
%   size as :attr:`dataAve`.
%
% **Examples:**
%
% - **Example1 (vector data):**
%   ``[xu,yu,za,ze] = computeAveErr2D([1 1 2 2 3],[10 10 20 20 30],[5 7 1 2 9],"StdErr");``
%
% - **Example2 (N-D data):**
%   ``data = rand(4,5,100); x = repelem(1:10,10); y = repelem(1:10,10);``
%   ``[xu,yu,da,de] = computeAveErr2D(x,y,data,"StdDev");``
%
arguments
    x double {mustBeVector}
    y double {mustBeVector}
    data double
    method string = "StdErr"
end

% --- Input Validation ---
dataDim = ndims(data);
isVector = isvector(data);
nSample = numel(x);
if ~(numel(y) == nSample)
    error('sizes of x and y do not match.')
end

if nSample == 1
    % For scalar input just return the input
    xUni = x;
    yUni = y;
    dataAve = data;
    dataError = zeros(size(data));
    return
elseif isVector
    if numel(data) ~= nSample
        error('The number of elements in x/y must match numel(data) when data is a vector.')
    end
elseif nSample ~= size(data, dataDim)
    error('The number of elements in x/y must match size(data, end).')
end

% --- Find unique x,y values and group indices ---
[xUni, ~, xIdx] = unique(x);
[yUni, ~, yIdx] = unique(y);
nx = numel(xUni);
ny = numel(yUni);
linIdx = sub2ind([ny, nx], yIdx(:), xIdx(:));

if isVector
    % Vector data: use accumarray directly
    dataAve = accumarray(linIdx, data(:), [ny*nx, 1], @mean, 0);
    dataAve = reshape(dataAve, [ny, nx]);
    if method == "None"
        dataError = zeros(size(dataAve));
        return
    elseif method == "StdDev"
        dataError = accumarray(linIdx, data(:), [ny*nx, 1], @std, 0);
    elseif method == "StdErr"
        dataError = accumarray(linIdx, data(:), [ny*nx, 1], @(v) std(v)./sqrt(numel(v)), 0);
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
    end
    dataError = reshape(dataError, [ny, nx]);
else
    % N-D data, with samples on the last dimension
    dataSize = size(data);
    dataSizeOther = dataSize(1:dataDim-1);
    data2D = reshape(data, [], nSample); % [prod(otherDims) x nSample]

    % Build sparse selector for (x,y) groups
    S = sparse(linIdx, 1:nSample, 1, ny*nx, nSample); % [ny*nx x nSample]

    % Means
    groupCount = full(sum(S, 2).'); % [1 x G]
    groupCount(groupCount == 0) = 1;
    sumPerGroup = full(data2D * S.');     % [prod(other) x G]
    dataAve2D = sumPerGroup ./ groupCount; 

    outputSize = [dataSizeOther, ny, nx];
    dataAve = reshape(dataAve2D, outputSize);

    % Variance via E[X^2] - (E[X])^2 with sample correction
    if method == "None"
        dataError = zeros(size(dataAve));
        return
    elseif method == "StdDev" || method == "StdErr"
        meanSq2D = (data2D.^2) * S.' ./ groupCount;
        var2D = meanSq2D - dataAve2D.^2;
        isSingle = (groupCount <= 1);
        corr = groupCount ./ max(groupCount - 1, 1); % define 1 when count==1, then set 0 below
        corr(isSingle) = 0;
        std2D = sqrt(max(var2D .* corr, 0));
        if method == "StdErr"
            dataErr2D = std2D ./ sqrt(groupCount);
        else
            dataErr2D = std2D;
        end
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
    end
    dataError = reshape(dataErr2D, outputSize);
end

end
