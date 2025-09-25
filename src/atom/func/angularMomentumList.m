function jList = angularMomentumList(j)
% Build a list by repeating each :math:`j` value :math:`2j+1` times.
%
% :param j: Total angular momenta (can be vector)
% :type j: double
% :return: Repeated list matching state multiplicities
% :rtype: double
mSize = 2*j+1;
jList = zeros(1,sum(mSize));
for ii = 1:numel(j)
    jList((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii))) = repmat(j(ii),1,mSize(ii));
end
end

