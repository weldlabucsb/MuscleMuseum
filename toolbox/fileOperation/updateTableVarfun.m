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
for ii = 1:numel(varList)
    t.(varList(ii)) = tRep.("Fun_" + varList(ii));
end
end

