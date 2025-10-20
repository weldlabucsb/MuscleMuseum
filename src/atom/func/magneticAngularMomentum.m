function m = magneticAngularMomentum(j)
mSize = 2*j+1;
m = zeros(1,sum(mSize));
for ii = 1:numel(j)
    m((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii))) = flip(-j(ii):1:j(ii));
end
end

