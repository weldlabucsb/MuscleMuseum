function [xUni,dataAve,dataError] = computeAveErr(x,data, method)
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

x = x(:); % Ensure x is a column vector

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
        colon_indices = repmat({':'}, 1, dataDim - 1);
        dataAve = data(colon_indices{:}, sortOrder);
    end
    dataError = zeros(size(xUni));
    return;
end

% --- Averaging and Error Calculation ---
if isVector
    % --- Method 1: Vector data (use simple accumarray) ---
    data = data(:); % Ensure data is a column vector
    dataAve = accumarray(indices, data, [nGroup, 1], @mean);

    if strcmp(method, "StdDev")
        % Standard deviation
        dataError = accumarray(indices, data, [nGroup, 1], @std, 0);
    elseif strcmp(method, "StdErr")
        % Standard error (std/sqrt(n))
        groupCount = accumarray(indices, 1, [nGroup, 1]);
        stdDev = accumarray(indices, data, [nGroup, 1], @std, 0);
        dataError = stdDev ./ sqrt(groupCount);
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
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
    groupSum2D = data2D * S';
    groupCount = sum(S, 2); % This is a column vector

    % Calculate average
    dataAve2D = groupSum2D ./ groupCount'; % Transpose counts for broadcasting

    % Calculate error
    if strcmp(method, "StdDev") || strcmp(method, "StdErr")
        % To get std, we use Var(X) = E[X^2] - (E[X])^2
        meanOfSquares2D = (data2D.^2 * S') ./ groupCount';
        variance2D = meanOfSquares2D - dataAve2D.^2;

        % Correct for sample variance (n-1 denominator) vs population variance (n)
        % and handle groups with a single member (variance is 0)
        isSingleMember = (groupCount' <= 1);
        correctionFactor = groupCount' ./ (groupCount' - 1);
        correctionFactor(isSingleMember) = 0; % Avoid division by zero, std is 0

        stdDev2D = sqrt(variance2D .* correctionFactor);
        stdDev2D(stdDev2D < 0) = 0; % Correct for potential floating point inaccuracies

        if strcmp(method, "StdErr")
            dataError2D = stdDev2D ./ sqrt(groupCount');
        else
            dataError2D = stdDev2D;
        end
    else
        error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
    end

    % Reshape results back to original N-D structure
    outputSize = [dataSizeOther, nGroup];
    dataAve = reshape(full(dataAve2D), outputSize);
    dataError = reshape(full(dataError2D), outputSize);
end

end