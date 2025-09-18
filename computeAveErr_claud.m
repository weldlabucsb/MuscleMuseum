function [xUni,dataAve,dataError] = computeAveErr(x,data, method)

arguments
    x double {mustBeVector}
    data double {mustBeVector}
    method string = "StdErr"
end

% Validate array sizes
if ~all(size(x) == size(data))
    error("sizes of x and data do not match.")
end

%% No Averaging
if strcmp(method, "None")
    xUni = x;
    dataAve = data;
    dataError = zeros(size(xUni));
    return;
end

%% Find unique x values and group indices
[xUni, ~, indices] = unique(x);
numGroups = numel(xUni);

%% Compute averages using accumarray
dataAve = accumarray(indices, data, [numGroups, 1], @mean);

%% Compute errors based on method
if strcmp(method, "StdDev")
    % Standard deviation
    dataError = accumarray(indices, data, [numGroups, 1], @std, 0);
elseif strcmp(method, "StdErr")
    % Standard error (std/sqrt(n))
    dataError = accumarray(indices, data, [numGroups, 1], @(vals) std(vals)/sqrt(numel(vals)), 0);
else
    error("Invalid method. Use 'None', 'StdDev', or 'StdErr'.");
end

end

