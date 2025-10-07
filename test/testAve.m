%% Test 1D
x = [3,2,6,5,1,6];
data = rand(2,3,numel(x));
[xUni,dataAve,dataError] = computeAveErr(x,data,"StdDev");

%% Test 2D
x = [3,2,1,1,1];
y = [1,2,2,1,1];
data = rand(2,3,numel(x));
[xUni,yUni,dataAve,dataError] = computeAveErr2D(x,y,data, "StdDev");