function t = str2table(s)
%STR2TABLE Convert a string to a table
arguments
    s string
end
t = table.empty;
if isempty(s) || ismissing(s)
    return
end
s = strsplit(s,";");
for ii = 1:numel(s)
    sSep = strsplit(s(ii),",");
    t.(sSep(1)) = sSep(2:end).';
end
end

