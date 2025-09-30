function t = updateTableVarfun(func,t,varList)
arguments
    func function_handle
    t table
    varList string
end
if isempty(varList)
    return
end
tRep = varfun(func, t, 'InputVariables', varList);
s = functions(func);
for ii = 1:numel(varList)
    t.(varList(ii)) = tRep.(string(s.function) + "_" + varList(ii));
end
end

