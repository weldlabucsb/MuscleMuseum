function [xUni,yUni,dataAve,dataError] = computeStd2D(x,y,data, method)
%computeSde Summary of this function goes here
%   computeSde has inputs [x] and [y] as plotting data. x and y must have
%   the same dimension. It returns the independent variable list [xUni]
%   without duplications. [yAve] is the dependent variable list that has
%   been averaged accordingly. [yError] is the corresponding standard
%   deviation.

% 10/4/2024: Updated to include optional argument method to take "None"
% "StdDev" and "StdErr" to switch between the three averaging methods.
% Defaults to "StdErr". "None" just returns the input data with 0's as the
% error bar arguments.
arguments
    x double {mustBeVector}
    y double {mustBeVector}
    data double {mustBeVector}
    method string = "StdErr"
end

% Validate array sizes
sz = numel(data);
if ~(numel(x)==sz && numel(y)==sz)
    error("sizes do not match.")
end

%% Compute indices
xUni = sort(unique(x));
yUni = sort(unique(y));
nx = numel(xUni);
ny = numel(yUni);

[~, xIndices] = ismember(x, xUni);
[~, yIndices] = ismember(y, yUni);
linearIndices = sub2ind([ny, nx], yIndices, xIndices);
linearIndices = linearIndices(:);

%% Compute average
dataAve = accumarray(linearIndices, data, [ny * nx, 1], @mean, 0);
dataAve = reshape(dataAve, [ny, nx]);

%% No Averaging
% by default we want everaging for plotting
if method == "None"
    method = "StdErr";
end

%% Standard Deviation
if strcmp(method, "StdDev")
    dataError = accumarray(linearIndices, data, [ny * nx, 1], @std, 0);
    dataError = reshape(dataError, [ny, nx]);
end

%% Standard Error
if strcmp(method, "StdErr")
    dataError = accumarray(linearIndices, data, [ny * nx, 1], @(x) std(x)./sqrt(numel(x)), 0);
    dataError = reshape(dataError, [ny, nx]);
end

end

