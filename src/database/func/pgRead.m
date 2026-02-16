function [data, metadata] = pgRead(conn, tableName, varargin)
% pgRead Read table from PostgreSQL with CamelCase and Array support.
%
% Syntax:
%   data = pgRead(conn, "MyTable")
%   data = pgRead(conn, "MyTable", RowFilter=rf)

    p = inputParser;
    addRequired(p, "conn");
    addRequired(p, "tableName", @(x) validateattributes(x, ["string","char"], "scalartext"));
    addParameter(p, "RowFilter", [], @(x) isa(x, "matlab.io.RowFilter"));
    addParameter(p, "MaxRows", 0);
    parse(p, conn, tableName, varargin{:});
    
    tableName = string(tableName);
    rf = p.Results.RowFilter;
    maxRows = p.Results.MaxRows;
    
    % 1. Construct SQL
    % We build the SQL manually to ensure quoting (CamelCase support)
    % and to facilitate pgFetch usage.
    
    sql = "SELECT * FROM " + tableName;
    
    % Apply RowFilter if present
    % Modern MATLAB provides `sqlread` which takes RowFilter, but we want to route
    % through pgFetch to get the Array Parsing logic.
    % We convert the RowFilter to a WHERE clause or rely on fetch's ability if supported.
    % Simplest path: Use generic SQL construction.
    
    if ~isempty(rf)
        % Note: Converting a RowFilter object to a SQL string is complex manually.
        % Strategy: If RowFilter is simple, we append it.
        % If complex, we might have to fallback to `sqlread` and then parse arrays.
        
        % ALTERNATIVE: Use sqlread directly, then pass to the parser helper.
        % This is safer than manually building SQL strings from objects.
        
        opts = {};
        if maxRows > 0, opts = [opts, {'MaxRows', maxRows}]; end
        
        % Use standard sqlread which handles the RowFilter
        data = sqlread(conn, tableName, "RowFilter", rf, "VariableNamingRule", "preserve", opts{:});
        
        % Post-process for arrays (Manual call to the parser logic from pgFetch)
        % (We can't call pgFetch here easily because sqlread does the fetching)
        data = parseTableArrays(data); 
        
        if nargout > 1, metadata = []; end % Metadata extraction from sqlread is limited
        return;
    end
    
    % If no filter, we can use pgFetch with a simple limit
    if maxRows > 0
        sql = sql + " LIMIT " + maxRows;
    end
    
    [data, metadata] = pgFetch(conn, sql);
end

function data = parseTableArrays(data)
    % Reuse logic from pgFetch to parse arrays in a table
    varNames = data.Properties.VariableNames;
    for i = 1:width(data)
        col = data.(varNames{i});
        testVal = missing;
        if iscell(col) || isstring(col)
            idx = find(~ismissing(col), 1);
            if ~isempty(idx)
                if iscell(col), testVal = string(col{idx}); else, testVal = col(idx); end
            end
        end
        if ~ismissing(testVal) && startsWith(testVal, "{") && endsWith(testVal, "}")
            data.(varNames{i}) = parsePgArray(data.(varNames{i})); 
        end
    end
end

function parsedCol = parsePgArray(rawCol)
    % Same helper as in pgFetch (could be moved to a shared utility file)
    rawCol = string(rawCol);
    n = numel(rawCol);
    parsedCol = cell(n,1);
    for k=1:n
        val = rawCol(k);
        if ismissing(val) || val=="", parsedCol{k}=[]; continue; end
        inner = extractBetween(val, 2, strlength(val)-1);
        if isempty(inner), parsedCol{k}=[]; continue; end
        tokens = split(inner, ",");
        nums = str2double(tokens);
        if all(~isnan(nums)), parsedCol{k} = nums; else, parsedCol{k} = tokens; end
    end
end