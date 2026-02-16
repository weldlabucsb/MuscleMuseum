function [data, metadata] = pgFetch(conn, sqlQuery, varargin)
%pgFetch Fetch data from PostgreSQL and parse Array types.
%
%   Refactored to fix "Logical Scalar" errors.
%   1. Fetches data using standard fetch.
%   2. robustly detects "{1,2,3}" strings.
%   3. Parses them into MATLAB vectors/cells.

    % 1. Standard Fetch
    try
        % Force 'table' format to simplify processing
        [data, metadata] = fetch(conn, sqlQuery, "DataReturnFormat", "table", varargin{:});
    catch ME
        rethrow(ME);
    end

    if isempty(data), return; end

    % 2. Post-Process: Detect and Parse PostgreSQL Arrays
    varNames = data.Properties.VariableNames;
    
    for i = 1:width(data)
        col = data.(varNames{i});
        
        % Heuristic: Extract a single sample value to check format
        testVal = string(missing); % Default to missing
        
        if iscell(col) || isstring(col)
             % Find first non-missing row
             idx = find(~ismissing(col), 1);
             if ~isempty(idx)
                 rawVal = col(idx);
                 if iscell(rawVal), rawVal = rawVal{1}; end
                 
                 % Force rawVal to be a SCALAR string
                 if ischar(rawVal)
                     testVal = string(rawVal);
                 elseif isstring(rawVal)
                     if isscalar(rawVal)
                        testVal = rawVal;
                     elseif numel(rawVal) > 0
                        % If cell contained a string array, take the first element
                        testVal = rawVal(1);
                     end
                 end
             end
        end
        
        % Safe Logical Check: Ensure testVal is scalar and not missing
        isTarget = false;
        if isscalar(testVal) && ~ismissing(testVal)
            if startsWith(testVal, "{") && endsWith(testVal, "}")
                isTarget = true;
            end
        end
        
        if isTarget
            data.(varNames{i}) = parsePgArray(col);
        end
    end
end

function parsedCol = parsePgArray(rawCol)
    % Parses PostgreSQL array strings "{1,2,3}" into MATLAB cells/vectors
    
    n = height(rawCol);
    parsedCol = cell(n, 1);
    
    % Ensure input is string array
    rawCol = string(rawCol);
    
    for k = 1:n
        val = rawCol(k);
        if ismissing(val) || val == ""
            parsedCol{k} = [];
            continue;
        end
        
        % Remove braces { }
        % extractBetween returns a string.
        inner = extractBetween(val, 2, strlength(val)-1);
        
        if isempty(inner) || inner == ""
            parsedCol{k} = [];
            continue;
        end
        
        % Split by comma
        % Note: This assumes standard numeric/text arrays. 
        % Complex text with escaped commas would require a regex parser.
        tokens = split(inner, ",");
        
        % Try converting to numbers
        nums = str2double(tokens);
        
        if all(~isnan(nums))
            % It is a numeric vector
            parsedCol{k} = nums;
        else
            % It is a string array
            % Remove quotes if present: "abc" -> abc
            parsedCol{k} = regexprep(tokens, '^"|"$', '');
        end
    end
end