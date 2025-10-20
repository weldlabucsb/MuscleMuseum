function jList = angularMomentumList(j)
mSize = 2*j+1;
jList = zeros(1,sum(mSize));
for ii = 1:numel(j)
    jList((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii))) = repmat(j(ii),1,mSize(ii));
end
end

