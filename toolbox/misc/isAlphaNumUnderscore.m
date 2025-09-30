function isAN = isAlphaNumUnderscore(c)
%ISALPHANUM Check if the input string only has alphabatic and numerical
%characters
%   Detailed explanation goes here
if isstring(c)
    TF = isstrprop(c,'alphanum') | (char(c) == '_');
    isAN = all(TF);
else
    error('input is not a string')
end

