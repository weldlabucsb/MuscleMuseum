function [xUni,yAve,yError] = computeStd(x,y, method)
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
method string = "StdErr"
end

% Validate array sizes
if ~all(size(x) == size(y))
    error("sizes of x and y do not match.")
end
%% No Averaging
if strcmp(method, "None")
xUni =x;
yAve=y;
yError = zeros(size(xUni));

end

%% Standard Deviation
if strcmp(method, "StdDev")
% Find unique x array
[xUni,~,ic] = unique(x);

% Initialize yError and yAve
yError = zeros(size(xUni));
yAve = zeros(size(xUni));

% Find out how to select y data to do average
[icSorted,icSortIdx] = sort(ic);
icSortedDiff = find(diff(icSorted));
selectIdx = [[1;(icSortedDiff+1)],[icSortedDiff;numel(ic)]];

% Calculate std and mean
for ii = 1:size(selectIdx,1)
    ySelected = y(icSortIdx(selectIdx(ii,1):selectIdx(ii,2)));
    [yError(ii),yAve(ii)] = std(ySelected); % standard deviation and mean
    yError(ii) = yError(ii);
end
end




%% Standard Error
if strcmp(method, "StdErr")
% Find unique x array
[xUni,~,ic] = unique(x);

% Initialize yError and yAve
yError = zeros(size(xUni));
yAve = zeros(size(xUni));

% Find out how to select y data to do average
[icSorted,icSortIdx] = sort(ic);
icSortedDiff = find(diff(icSorted));
selectIdx = [[1;(icSortedDiff+1)],[icSortedDiff;numel(ic)]];

% Calculate std and mean
for ii = 1:size(selectIdx,1)
    ySelected = y(icSortIdx(selectIdx(ii,1):selectIdx(ii,2)));
    [yError(ii),yAve(ii)] = std(ySelected); % standard deviation and mean
    yError(ii) = yError(ii) / sqrt(numel(ySelected));
end
end



end

