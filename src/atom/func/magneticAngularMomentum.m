function m = magneticAngularMomentum(j)
% Build list of :math:`m=-j,\dots,+j` values for each :math:`j`.
%
% :param j: Total angular momenta (can be vector)
% :type j: double
% :return: Concatenated magnetic sublevels :math:`M` per :math:`j`
% :rtype: double
mSize = 2*j+1;
m = zeros(1,sum(mSize));
for ii = 1:numel(j)
    m((sum(mSize(1:(ii-1)))+1):sum(mSize(1:ii))) = flip(-j(ii):1:j(ii));
end
end

