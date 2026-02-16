function pgUpdate(conn, tableName, data, filter, varargin)
%pgUpdate Update PostgreSQL rows preserving Case Sensitivity and Arrays.
%
%   Features:
%   1. Resolves RowFilter case-sensitivity issues by quoting variables.
%   2. Automatically adds missing columns (Schema Evolution).
%   3. Serializes MATLAB vectors to PostgreSQL arrays ("{1,2,3}").
%
%   Syntax:
%       pgUpdate(conn, "MyTable", data, rowFilters)

    % 1. Input Parsing
    p = inputParser;
    addRequired(p, "conn", @(x) validateattributes(x, "database.relational.connection", "scalar"));
    addRequired(p, "tableName", @(x) validateattributes(x, ["string", "char"], "scalartext"));
    addRequired(p, "data", @(x) validateattributes(x, "table", {}));
    addRequired(p, "filter"); 
    addParameter(p, "isForceArray", false, @islogical);
    parse(p, conn, tableName, data, filter, varargin{:});
    
    isForceArray = p.Results.isForceArray;
    tableName = string(tableName);
    
    if isempty(data), return; end

    if isa(filter, "matlab.io.RowFilter")
        if height(data) == 1
            filter = {filter};
        else
            error("Single RowFilter provided for multiple rows of data.");
        end
    end

    % 2. Schema Evolution (Check & Add Missing Columns)
    try
        % Fetch schema to check columns
        querySchema = "SELECT * FROM " + tableName + " WHERE FALSE";
        schemaTable = fetch(conn, querySchema);
        dbCols = string(schemaTable.Properties.VariableNames);
        
        inputCols = string(data.Properties.VariableNames);
        missingCols = inputCols(~ismember(inputCols, dbCols));
        
        if ~isempty(missingCols)
            alterStmts = strings(0);
            for col = missingCols
                colData = data.(col);
                % Determine Column Type (Array vs Scalar)
                isVec = iscell(colData) || (size(colData, 2) > 1 && ~ischar(colData));
                sqlType = "text"; 
                if isnumeric(colData)
                    if isVec || isForceArray, sqlType = "numeric[]"; else, sqlType = "numeric"; end
                elseif isstring(colData) || iscellstr(colData)
                    if isVec || isForceArray, sqlType = "text[]"; else, sqlType = "text"; end
                elseif islogical(colData)
                    sqlType = "boolean";
                end
                
                alterStmts(end+1) = "ADD COLUMN """ + col + """ " + sqlType; %#ok<AGROW>
            end
            execute(conn, "ALTER TABLE " + tableName + " " + join(alterStmts, ", "));
            
            % Update our known list of DB columns after adding new ones
            dbCols = [dbCols, missingCols]; 
        end
    catch ME
        warning("Schema update warning: " + ME.message);
    end

    % 3. Pre-Process Data Strings (Performance)
    varNames = string(data.Properties.VariableNames);
    quotedVarNames = """" + varNames + """"; 
    
    numRows = height(data);
    numCols = width(data);
    dataStr = strings(numRows, numCols);
    
    for c = 1:numCols
        colName = varNames(c);
        colData = data.(colName);
        
        isArrayCol = iscell(colData) || (isnumeric(colData) && size(colData,2)>1) || isForceArray;
        
        if isArrayCol
            dataStr(:, c) = helperMatlabToPgArray(colData); 
        else
            % Scalar handling
            if isnumeric(colData) || islogical(colData)
                if islogical(colData), colData = double(colData); end
                vals = string(colData);
                vals(ismissing(vals)) = "NULL";
                dataStr(:, c) = vals;
            else
                % Strings: Escape single quotes
                vals = string(colData);
                isMiss = ismissing(vals);
                vals = "'" + strrep(vals, "'", "''") + "'";
                vals(isMiss) = "NULL";
                dataStr(:, c) = vals;
            end
        end
    end

    % 4. Execute Updates Row-by-Row
    try
        for i = 1:numRows
            rf = filter{i};
            
            % Since RowFilter is opaque, we iterate through ALL known table columns.
            % We attempt to replace the variable name in the filter with its quoted version.
            % Example: replaces TrialID with "TrialID" inside the filter object.
            
            quotedRF = rf; 
            for col = dbCols
                try
                   % This will only succeed if 'col' is actually used in the filter
                   quotedRF = replaceVariableNames(quotedRF, col, """" + col + """");
                catch
                   % Ignore if the variable isn't in this specific filter
                end
            end
            
            % Step A: Find the row using the QUOTED filter
            targetRows = sqlread(conn, tableName, "RowFilter", quotedRF, "VariableNamingRule", "preserve");
            
            if isempty(targetRows), continue; end
            
            % Step B: Construct WHERE clause using the Primary Key (First Column)
            idColName = targetRows.Properties.VariableNames{1};
            idValue = targetRows.(idColName)(1);
            
            if isnumeric(idValue)
                 whereClause = """" + idColName + """ = " + string(idValue);
            else
                 safeVal = strrep(string(idValue), "'", "''");
                 whereClause = """" + idColName + """ = '" + safeVal + "'";
            end

            % Step C: Manual UPDATE
            setParts = quotedVarNames + " = " + dataStr(i, :);
            setClause = join(setParts, ", ");
            
            sql = "UPDATE " + tableName + " SET " + setClause + " WHERE " + whereClause;
            execute(conn, sql);
        end
    catch ME
        rethrow(ME);
    end
end

function strCol = helperMatlabToPgArray(colData)
    % Helper to convert MATLAB vectors/cells to Postgres "{...}" strings
    rows = size(colData, 1);
    strCol = strings(rows, 1);
    for k = 1:rows
        if iscell(colData), val = colData{k}; else, val = colData(k, :); end
        if isempty(val)
            strCol(k) = "'{}'";
            continue;
        end
        if isnumeric(val) || islogical(val)
            if islogical(val), val = double(val); end
            content = join(string(val), ",");
            strCol(k) = "'{" + content + "}'";
        else
            valStr = string(val);
            valStr = strrep(valStr, '"', '\"');
            content = join("""" + valStr + """", ",");
            finalStr = "{" + content + "}";
            finalStr = strrep(finalStr, "'", "''"); 
            strCol(k) = "'" + finalStr + "'";
        end
    end
end