function pgWrite(conn, tableName, data, varargin)
%pgWrite Write a MATLAB table to PostgreSQL with Case Sensitivity and Array support.
%
%   Replaces sqlwrite to support:
%   1. "CamelCase" columns (PostgreSQL requires double quotes).
%   2. Arrays (converting vectors to '{1,2}' strings).
%   3. Schema Evolution (adding missing columns).
%
%   Syntax:
%       pgWrite(conn, "MyTable", data)
%       pgWrite(conn, "MyTable", data, 'isForceArray', true)

    % 1. Input Parsing
    p = inputParser;
    addRequired(p, "conn", @(x) validateattributes(x, "database.relational.connection", "scalar"));
    addRequired(p, "tableName", @(x) validateattributes(x, ["string", "char"], "scalartext"));
    addRequired(p, "data", @(x) validateattributes(x, "table", {}));
    addParameter(p, "isForceArray", false, @islogical);
    parse(p, conn, tableName, data, varargin{:});
    
    isForceArray = p.Results.isForceArray;
    tableName = string(tableName);
    
    if isempty(data), return; end

    % 2. Schema Evolution (Add Missing Columns)
    % We must check if columns exist and add them if they don't.
    try
        % Get existing column names using a dummy fetch (Public API)
        % We use fetch instead of sqlfind for precise column name casing.
        querySchema = "SELECT * FROM " + tableName + " WHERE FALSE";
        schemaTable = fetch(conn, querySchema);
        dbCols = string(schemaTable.Properties.VariableNames);
        
        inputCols = string(data.Properties.VariableNames);
        missingCols = inputCols(~ismember(inputCols, dbCols));
        
        if ~isempty(missingCols)
            alterStmts = strings(0);
            for col = missingCols
                colData = data.(col);
                % Detect type
                isVec = iscell(colData) || (size(colData, 2) > 1 && ~ischar(colData));
                
                sqlType = "text"; % default
                if isnumeric(colData)
                    if isVec || isForceArray, sqlType = "numeric[]"; else, sqlType = "numeric"; end
                elseif isstring(colData) || iscellstr(colData)
                    if isVec || isForceArray, sqlType = "text[]"; else, sqlType = "text"; end
                elseif islogical(colData)
                    sqlType = "boolean";
                end
                
                % Quote the column name for case sensitivity
                alterStmts(end+1) = "ADD COLUMN """ + col + """ " + sqlType; %#ok<AGROW>
            end
            
            fullAlter = "ALTER TABLE " + tableName + " " + join(alterStmts, ", ");
            execute(conn, fullAlter);
        end
    catch ME
        % If table doesn't exist, we might need CREATE TABLE. 
        % For this refactor, we assume table exists or let the INSERT fail safely.
        warning("Schema check warning: " + ME.message);
    end

    % 3. Data Preparation & Serialization
    % Convert all data to SQL-safe strings (handling arrays and quotes)
    numRows = height(data);
    numCols = width(data);
    formattedData = strings(numRows, numCols);
    varNames = data.Properties.VariableNames;
    
    for c = 1:numCols
        colName = varNames{c};
        colData = data.(colName);
        
        % Check if this column requires array formatting
        isArrayCol = iscell(colData) || (isnumeric(colData) && size(colData,2)>1) || isForceArray;
        
        if isArrayCol
            formattedData(:, c) = helperMatlabToPgArray(colData);
        else
            % Standard Scalar Handling
            if isnumeric(colData) || islogical(colData)
                % Convert NaN to NULL
                strVals = string(double(colData)); % double handles logicals too
                strVals(ismissing(strVals)) = "NULL";
                formattedData(:, c) = strVals;
            else
                % Strings: Escape single quotes
                strVals = string(colData);
                isMiss = ismissing(strVals);
                strVals = "'" + strrep(strVals, "'", "''") + "'";
                strVals(isMiss) = "NULL";
                formattedData(:, c) = strVals;
            end
        end
    end
    
    % 4. Construct and Execute INSERT Statements (Batching)
    % Prepare Column List: "Col1", "Col2", ...
    colList = "(" + join("""" + string(varNames) + """", ", ") + ")";
    
    batchSize = 1000; % Prevent query string from getting too large
    
    for i = 1:batchSize:numRows
        endIdx = min(i + batchSize - 1, numRows);
        batchData = formattedData(i:endIdx, :);
        
        % Join rows: (val1, val2), (val3, val4)
        % We join columns with commas, then wrap in parens
        rowStrings = "(" + join(batchData, ", ", 2) + ")";
        
        valuesClause = join(rowStrings, ", ");
        
        sql = "INSERT INTO " + tableName + " " + colList + " VALUES " + valuesClause;
        
        execute(conn, sql);
    end
end

function strCol = helperMatlabToPgArray(colData)
    % Helper to convert MATLAB vectors/cells to Postgres "{...}" strings
    % Returns a string array where each element is a valid SQL value (quoted if needed)
    
    rows = size(colData, 1);
    strCol = strings(rows, 1);
    
    for k = 1:rows
        if iscell(colData)
            val = colData{k};
        else
            val = colData(k, :);
        end
        
        if isempty(val)
            strCol(k) = "'{}'";
            continue;
        end
        
        if isnumeric(val) || islogical(val)
            % Numeric array: '{1,2,3}'
            % Treat NaN as NULL inside array if needed, or just numbers
            if islogical(val), val = double(val); end
            content = join(string(val), ",");
            strCol(k) = "'{" + content + "}'";
        else
            % Text array: '{"a","b"}'
            % Must double-escape quotes for the SQL string literal
            valStr = string(val);
            % Escape internal double quotes for Postgres array format
            valStr = strrep(valStr, '"', '\"');
            % Wrap elements in double quotes
            content = join("""" + valStr + """", ",");
            % Wrap array in single quotes for SQL, escape any single quotes inside
            finalStr = "{" + content + "}";
            finalStr = strrep(finalStr, "'", "''"); 
            strCol(k) = "'" + finalStr + "'";
        end
    end
end