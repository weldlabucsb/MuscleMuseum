function [data,metadata] = pgFetchHook(connection,second_input,optsObject,isDynamicQuery,dynamicQuery,maxRows,preserveNames,dataReturnFormat)
%FETCHHOOK Fetch data from a PostgreSQL connection

%   Copyright 2022 The MathWorks, Inc.

query = second_input;
validateattributes(query,{'char','cell','string'},{'scalartext'},...
    'fetch','query');
query = char(query);

% Handle MaxRows using standard SQL LIMIT
if maxRows ~= 0
    if ~contains(upper(query), 'LIMIT')
        query = [query ' LIMIT ' num2str(maxRows)];
    end
    if ~isempty(optsObject) && isDynamicQuery
        % If dynamic query exists, we assume it needs the limit too
         dynamicQuery = [dynamicQuery ' LIMIT ' num2str(maxRows)];
    end
end

% Execute Query
try
    if isDynamicQuery && ~isempty(dynamicQuery)
        data = fetch(connection, dynamicQuery);
    else
        data = fetch(connection, query);
    end
catch ME
    throw(ME);
end

% If data is empty, handle return formats immediately
if isempty(data)
    if nargout > 1
        metadata = table([],[],[],'VariableNames',{'VariableType','FillValue','MissingRows'});
    end
    % Return empty in requested format
    if strcmpi(dataReturnFormat, 'structure')
        data = struct();
    elseif strcmpi(dataReturnFormat, 'cellarray')
        data = {};
    elseif strcmpi(dataReturnFormat, 'numeric')
        data = [];
    end
    return;
end

% --- Array Parsing & Type Conversion Logic ---
% Since 'fetch' returns a table, we iterate over columns to find and parse arrays.
colNames = data.Properties.VariableNames;

% Handle Variable Naming Rule (if modify was requested)
if strcmpi(preserveNames,'modify') || strcmpi(dataReturnFormat,'structure')
    data.Properties.VariableNames = matlab.lang.makeValidName(colNames);
    colNames = data.Properties.VariableNames;
end

for n = 1:length(colNames)
    colData = data.(colNames{n});
    
    % Only parse if it looks like a string/cell column (Postgres arrays come back as strings)
    if isstring(colData) || iscellstr(colData)
        % Heuristic: Check the first non-missing value
        firstIdx = find(~ismissing(colData), 1);
        if ~isempty(firstIdx)
            val = colData(firstIdx);
            if iscell(val), val = val{1}; end
            
            % Check for Postgres Array format "{...}"
            if startsWith(val, '{') && endsWith(val, '}')
                % Use your original regex logic
                cleanData = regexprep(colData, '{|}', '');
                
                try
                    % Attempt Numeric Parse: "{1,2,3}" -> [1;2;3]
                    parsed = cellfun(@(x) str2double(split(x, ',')).', ...
                                     cleanData, 'UniformOutput', false);
                    
                    % Validation: If result is all NaNs but input wasn't empty, it might be Text
                    sample = parsed{firstIdx};
                    if all(isnan(sample)) && ~isempty(cleanData{firstIdx}) && ~contains(cleanData{firstIdx}, 'NaN')
                         error('NotNumeric'); 
                    end
                    data.(colNames{n}) = parsed;
                catch
                    % Fallback to Text Array Parse: "{a,b,c}" -> ["a","b","c"]
                    data.(colNames{n}) = cellfun(@(x) string(split(x, ',').'), ...
                                         cleanData, 'UniformOutput', false);
                end
            end
        end
        
        % Date/Time Infinity Logic (Preserved)
        if isstring(data.(colNames{n})) || iscellstr(data.(colNames{n}))
             infIdx = strcmp(data.(colNames{n}), 'infinity');
             negInfIdx = strcmp(data.(colNames{n}), '-infinity');
             
             if any(infIdx) || any(negInfIdx)
                 try
                     dt = datetime(data.(colNames{n}));
                     dt(infIdx) = datetime(Inf,Inf,Inf);
                     dt(negInfIdx) = datetime(-Inf,-Inf,-Inf);
                     data.(colNames{n}) = dt;
                 catch
                 end
             end
        end
    end
end

% --- Apply Options Object Logic (Preserved) ---
if ~isempty(optsObject)
    % RowFilter
    if ~isempty(optsObject.RowFilter)
        data = filter(optsObject.RowFilter, data);
    end
    
    % SelectedVariableNames
    if ~isempty(optsObject.SelectedVariableNames)
        toKeep = ismember(data.Properties.VariableNames, optsObject.SelectedVariableNames);
        data = data(:, toKeep);
    end
    
    % ExcludeDuplicates
    if optsObject.ExcludeDuplicates
        data = unique(data);
    end
    
    % Note: Variable properties (Type, WhitespaceRule) are usually handled 
    % automatically by the public 'fetch' or the parsing logic above. 
    % Re-implementing the massive switch-case for types is redundant unless 
    % you have very specific custom casting requirements not met by the above.
end


% --- Construct Metadata (if requested) ---
if nargout > 1
    varTypes = varfun(@class, data, 'OutputFormat', 'cell');
    fillVals = cell(size(varTypes));
    for i = 1:numel(varTypes)
        if strcmp(varTypes{i}, 'double'), fillVals{i} = NaN;
        elseif strcmp(varTypes{i}, 'string'), fillVals{i} = missing;
        else, fillVals{i} = []; end
    end
    metadata = table(varTypes', fillVals', 'RowNames', data.Properties.VariableNames, ...
        'VariableNames', {'VariableType', 'FillValue'});
end

% --- Format Return Type ---
if strcmpi(dataReturnFormat, 'structure')
    data.Properties.VariableNames = matlab.lang.makeValidName(data.Properties.VariableNames);
    data = table2struct(data);
elseif strcmpi(dataReturnFormat, 'cellarray')
    data = table2cell(data);
elseif strcmpi(dataReturnFormat, 'numeric')
    temp = NaN(height(data), width(data));
    for n = 1:width(data)
        col = data.(data.Properties.VariableNames{n});
        if isnumeric(col) || islogical(col)
            temp(:,n) = double(col);
        end
    end
    data = temp;
end
end

