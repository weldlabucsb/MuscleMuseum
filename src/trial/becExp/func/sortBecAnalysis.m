function analysisListSorted = sortBecAnalysis(analysisList)
%SORTANALYSIS Summary of this function goes here
%   We need to run different analysis in certain order so we have to sort
%   the analysis methods
analysisListSorted = analysisList(:);
allAnalysis = ["DensityFit";"AtomNumber";"Tof";"CenterFit";"KapitzaDirac"];
extraAnalysis = analysisListSorted(~ismember(analysisListSorted,allAnalysis));
analysisListSorted = [allAnalysis(ismember(allAnalysis,analysisListSorted));...
    extraAnalysis];
analysisListSorted = reshape(analysisListSorted,size(analysisList));
end

