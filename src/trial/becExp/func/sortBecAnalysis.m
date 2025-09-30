function analysisListSorted = sortBecAnalysis(analysisList)
% Sort analysis method names according to predefined execution order.
%
% Ensures BEC analysis modules run in a consistent order so that
% dependencies are satisfied (e.g., :class:`DensityFit` before
% :class:`AtomNumber`). Items not listed in the canonical order are
% appended while preserving their relative order.
%
% :param analysisList: List of analysis names
% :type analysisList: string|string[]|cellstr
% :return: Sorted list of analysis names
% :rtype: string
analysisListSorted = analysisList(:);
allAnalysis = ["DensityFit";"AtomNumber";"Tof";"CenterFit";"KapitzaDirac"];
extraAnalysis = analysisListSorted(~ismember(analysisListSorted,allAnalysis));
analysisListSorted = [allAnalysis(ismember(allAnalysis,analysisListSorted));...
    extraAnalysis];
analysisListSorted = reshape(analysisListSorted,size(analysisList));
end

