
x = repmat(1:2,1,2);
y = repmat(1:2,1,2);
data = rand(3,2,numel(x));
[xUni1,dataAve1] = computeAveErr(x,data,"StdDev");


% [xUni,yUni,dataAve,dataError] = computeAveErr2D(x,y,data, "StdDev");