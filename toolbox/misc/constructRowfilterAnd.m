function rf = constructRowfilterAnd(keyColumnName,columnValue)
rf0 = rowfilter(keyColumnName);
if iscell(columnValue)
    rf = rf0.(keyColumnName(1)) == columnValue{1};
    for ii = 2:numel(keyColumnName)
        rf = rf & rf0.(keyColumnName(ii)) == columnValue{ii};
    end
else
    rf = rf0.(keyColumnName(1)) == columnValue(1);
    for ii = 2:numel(keyColumnName)
        rf = rf & rf0.(keyColumnName(ii)) == columnValue(ii);
    end
end

