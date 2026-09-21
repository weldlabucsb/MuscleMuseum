function [data,metadata] = pgFetchHook(connection,second_input,optsObject,isDynamicQuery,dynamicQuery,maxRows,preserveNames,dataReturnFormat)
%FETCHHOOK Fetch data from a PostgreSQL connection

%   Copyright 2022-2026 The MathWorks, Inc.

query = second_input;
validateattributes(query,{'char','cell','string'},{'scalartext'},...
    'fetch','query');
query = char(query);

if maxRows ~= 0
    limitQuery =  matlab.io.datastore.internal.utilities.getLimitQuery('PostgreSQL');
    limitQuery = limitQuery{:};
    query = eval(limitQuery);
    if ~isempty(optsObject)
        dynamicLimitQuery = strrep(limitQuery,'query','dynamicQuery');
        dynamicQuery = eval(dynamicLimitQuery);
    end
end

% Determine MATLAB version for compatibility routing
persistent isLegacyMatlab;
if isempty(isLegacyMatlab)
    relStr = version('-release'); % e.g., '2023a' or '2025a'
    currentYear = str2double(relStr(1:4));
    if currentYear <= 2023
        isLegacyMatlab = true;
    else
        isLegacyMatlab = false;
    end
end

try
    if isDynamicQuery
        targetQuery = dynamicQuery;
    else
        targetQuery = query;
    end

    % Execution block with automatic version compatibility fallback
    executedSuccessfully = false;
    
    if isLegacyMatlab
        % Legacy path (MATLAB 2023a and older)
        try
            result = connection.Handle.fetch(targetQuery);
            executedSuccessfully = true;
        catch
            % Fall back to standard query if dynamic query failed
            if isDynamicQuery
                targetQuery = query;
                result = connection.Handle.fetch(targetQuery);
                isDynamicQuery = false;
                executedSuccessfully = true;
            end
        end
    else
        % Modern path (MATLAB 2023b through 2025a/2026a+)
        try
            if isprop(connection, 'Handle') && ~isempty(metaclass(connection.Handle))
                m = metaclass(connection.Handle);
                hasFetchMethod = any(strcmp({m.MethodList.Name}, 'fetch'));
                if hasFetchMethod
                    result = connection.Handle.fetch(targetQuery);
                    executedSuccessfully = true;
                end
            end
        catch
            executedSuccessfully = false;
        end
        
        % If direct handle fetch isn't supported, use Database Toolbox fetch
        if ~executedSuccessfully
            try
                tempTable = fetch(connection, targetQuery);
                result = tableToResultWrapper(tempTable);
                executedSuccessfully = true;
            catch eModern
                rethrow(eModern);
            end
        end
    end
    
    if ~executedSuccessfully
        error('MuscleMuseum:pgFetchHook:ConnectionError', 'Could not execute query across database connection for this MATLAB version.');
    end

    %Determine column names based on either names from the db or names
    %specified in options object
    if isempty(optsObject)
        columnNames = result.getColumnNames();
        if strcmpi(preserveNames,'modify') || strcmpi(dataReturnFormat,'structure')
            columnNames = matlab.lang.makeValidName(columnNames);
        end
        columnNames = matlab.lang.makeUniqueStrings(columnNames);
    else
        if isDynamicQuery
            originalNames = optsObject.SelectedVariableNames;
        else
            originalNames = optsObject.VariableNames;
        end


        if strcmpi(preserveNames,'modify') || strcmpi(dataReturnFormat,'structure')
            columnNames = database.internal.utilities.makeValidVariableNames(originalNames);
        else
            columnNames = originalNames;
        end
    end

    warning off
    connstruct = struct(connection);
    dataTypes = result.getColumnTypes();
    
    if isfield(connstruct, 'DataTypes') && ~isempty(connstruct.DataTypes)
        [~,categoryIdx] = ismember(dataTypes,connstruct.DataTypes.oid);
        typeCategories = connstruct.DataTypes.typcategory(categoryIdx);
        typeName = connstruct.DataTypes.typname(categoryIdx);
    else
        % Fallback for modern MATLAB versions where DataTypes schema isn't exposed
        categoryIdx = zeros(size(dataTypes));
        typeCategories = repmat({'s'}, size(dataTypes));
        typeName = repmat({'text'}, size(dataTypes));
        for idx = 1:length(dataTypes)
            if isnumeric(dataTypes{idx}) || contains(lower(string(dataTypes{idx})), {'int','float','numeric','double','real'})
                categoryIdx(idx) = 110; % Numeric category oid proxy
                typeCategories{idx} = 'n';
            end
        end
    end
    modifiedTypeCategories = typeCategories;
    warning on
    %Need to alter typeCategories for money type as it needs to be handled
    %differently from other numeric types

    modifiedTypeCategories(typeName == "money") = {'money'};
    modifiedTypeCategories(typeName == "int2") = {'smallint'};
    modifiedTypeCategories(typeName == "int4") = {'integer'};
    modifiedTypeCategories(typeName == "int8") = {'bigint'};
    modifiedTypeCategories(typeName == "float4") = {'real'};

    result.parseResult();

    data = table();
    for n = 1:length(columnNames)
        if categoryIdx(n) == 160
            data.(columnNames{n}) = ...
            cellfun(@(x) str2double(split(regexprep(x,'{|}',''),',')).',...
            result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
        elseif categoryIdx(n) == 120
            data.(columnNames{n}) = ...
            cellfun(@(x) int32(str2double(split(regexprep(x,'{|}',''),','))).',...
            result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
        elseif categoryIdx(n) == 122
            data.(columnNames{n}) = ...
            cellfun(@(x) string(split(regexprep(x,'{|}',''),',').'),...
            result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
        else
            data.(columnNames{n}) = result.fetchData(n,modifiedTypeCategories{n});
        end
    end

    nullRows = result.getNullRows();

    if ~isempty(data)
        if isempty(optsObject)
            for n = 1:length(typeName)
                if upper(typeCategories{n}) == "N"
                    if ~isa(data.(columnNames{n}),"double")
                        data.(columnNames{n}) = double(data.(columnNames{n}));
                        data.(columnNames{n})(nullRows{n}) = NaN;
                    end
                end
                if upper(typeCategories{n}) == "E"
                    allCats = fetch(connection,"SELECT unnest(enum_range(null::" + typeName{n} + "))::text AS enumTypes");
                    allCats = allCats.enumtypes;
                    cats = categorical(data.(columnNames{n}),allCats);
                    data.(columnNames{n}) = cats;
                elseif upper(typeName{n}) == "DATE"
                    dateValues = datetime(data.(columnNames{n}),'InputFormat','yyyy-MM-dd');
                    dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
                    dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
                    data.(columnNames{n}) = dateValues;
                elseif upper(typeName{n}) == "TIMESTAMP"
                    dateValues = datetime(data.(columnNames{n}));
                    dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
                    dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
                    [data.(columnNames{n})] = dateValues;
                elseif upper(typeName{n}) == "TIMESTAMPTZ" || upper(typeName{n}) == "ABSTIME"
                    nonNanTimestampIdx = find(~strcmp(data.(columnNames{n}),'NaN'),1);
                    firstTime = data.(columnNames{n}){nonNanTimestampIdx};
                    subSeconds = string(regexp(firstTime,'(?<=\.)\d*(?=+|-)','match'));
                    if isempty(subSeconds)
                        inputFormat = 'yyyy-MM-dd HH:mm:ssZ';
                    else
                        numSubSeconds = strlength(subSeconds);
                        inputFormat = "yyyy-MM-dd HH:mm:ss." + string(repmat('S',[1 numSubSeconds])) + "Z";
                    end
                    dateValues = datetime(data.(columnNames{n}),'InputFormat',inputFormat,'TimeZone','local');

                    dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
                    dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
                    data.(columnNames{n}) = dateValues;
                elseif upper(typeName{n}) == "TIME" || upper(typeName{n}) == "TIMETZ"
                    timeStrings = regexprep(data.(columnNames{n}),"-\d{2}","");
                    durs = duration(timeStrings);
                    data.(columnNames{n}) = durs;
                elseif upper(typeName{n}) == "INTERVAL" || upper(typeName{n}) == "RELTIME"
                    data.(columnNames{n}) = string2CalendarDuration(data.(columnNames{n}));
                end

                if isstring(data.(columnNames{n}))
                    data.(columnNames{n})(nullRows{n}) = missing;
                end
            end
        else
            for n = 1:width(data)
                varopts = getoptions(optsObject,originalNames{n});
                switch(varopts.Type)
                    case {'char','string'}
                        if ~strcmpi(class(data.(varopts.Name)),'string')
                            data.(n) = string(data.(n));
                        end
                        if ~strcmpi(varopts.WhitespaceRule, 'preserve') && ~isempty(data.(n))
                            side = varopts.WhitespaceRule;
                            if strcmpi(side,'trim')
                                side = 'both';
                            elseif strcmpi(side,'trimtrailing')
                                side = 'right';
                            else
                                side = 'left';
                            end
                            data.(n) = strip(data.(n),side);
                        end
                        if ~strcmpi(varopts.TextCaseRule, 'preserve')
                            caserule = varopts.TextCaseRule;
                            if strcmpi(caserule,'upper')
                                data.(n) = upper(data.(n));
                            else
                                data.(n) = lower(data.(n));
                            end
                        end
                        if strcmpi(varopts.Type,'char')
                            data.(n) = cellstr(data.(n));
                            data.(n)(nullRows{n}) = {varopts.FillValue};
                        end
                        if strcmpi(varopts.Type,'string')
                            data.(n)(nullRows{n}) = {varopts.FillValue};
                        end
                    case 'double'
                        data.(n) = double(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'single'
                        data.(n) = single(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'int64'
                        data.(n) = int64(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'uint64'
                        data.(n) = uint64(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'int32'
                        data.(n) = int32(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'uint32'
                        data.(n) = uint32(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'int16'
                        data.(n) = int16(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'uint16'
                        data.(n) = uint16(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'int8'
                        data.(n) = int8(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'uint8'
                        data.(n) = uint8(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'logical'
                        data.(n)(isnan(data.(n))) = -1;
                        data.(n) = logical(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'datetime'
                        data.(n)  = datetime(data.(n), ...
                            'Format',varopts.DatetimeFormat, ...
                            'Locale',varopts.DatetimeLocale, ...
                            'TimeZone',varopts.TimeZone, ...
                            'InputFormat',varopts.InputFormat);
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'duration'
                        if isempty(varopts.InputFormat)
                            data.(n) = duration(data.(n),...
                                'Format',varopts.DurationFormat);
                        else
                            data.(n) = duration(data.(n),...
                                'InputFormat',varopts.InputFormat,...
                                'Format',varopts.DurationFormat);
                        end
                        data.(n)(nullRows{n}) = varopts.FillValue;
                    case 'categorical'
                        data.(n) = database.internal.utilities.convertToCategoricalArray(data.(n), ...
                            varopts.Categories, ...
                            varopts.Ordinal, ...
                            varopts.Protected, ...
                            varopts.FillValue, ...
                            nullRows{n});
                    case 'calendarDuration'
                        data.(n) = string2CalendarDuration(data.(n));
                        data.(n)(nullRows{n}) = varopts.FillValue;
                        if strlength(varopts.Format) > 0
                            data.(n).Format = varopts.Format;
                        end
                end
            end

            if ~isDynamicQuery
                data = filter(optsObject.RowFilter,data);

                missingindices = [];
                for i = 1:width(data)
                    varopts = getoptions(optsObject,i);
                    if strcmpi(varopts.MissingRule,'omitrow')
                        missingindices = [missingindices; nullRows{i}]; %#ok<AGROW>
                    end
                end
                missingindices = unique(missingindices);
                data(missingindices,:) = [];

                [~,idxToRemove] = setdiff(optsObject.VariableNames,optsObject.SelectedVariableNames);
                data(:,idxToRemove) = [];
                nullRows(idxToRemove) = [];

                if optsObject.ExcludeDuplicates
                    data = database.internal.utilities.uniqueMissingIsEqual(data);
                end
            end
        end
    end
catch e
    throw(e);
end

if nargout > 1
    hasData = height(data) > 0;
    if hasData
        rowNames = data.Properties.VariableNames;
        variableType = cell(length(rowNames),1);
        fillValue = cell(length(rowNames),1);

        if dataReturnFormat == "numeric"
            variableType = repmat({'double'},length(rowNames),1);
            fillValue = NaN(length(rowNames),1);
        else
            for n = 1:length(rowNames)
                if isempty(optsObject)
                    variableType{n} = class(data.(columnNames{n}));
                    fillValue{n} = database.options.internal.fillValueSelectorforSQL(connection,variableType{n});
                else
                    variableType{n} = optsObject.VariableTypes{n};
                    fillValue{n} = optsObject.FillValues{n};
                end
            end
        end

        metadata = table(variableType,fillValue,nullRows,'RowNames',rowNames,...
            'VariableNames',{'VariableType','FillValue','MissingRows'});
    else
        metadata = table([],[],[],'VariableNames',{'VariableType','FillValue','MissingRows'});
    end
end

try
    result.close();
catch
end

if dataReturnFormat == "structure"
    data.Properties.VariableNames = database.internal.utilities.makeValidVariableNames(data.Properties.VariableNames);
    data = table2struct(data);
elseif dataReturnFormat == "cellarray"
    data = table2cell(data);
elseif dataReturnFormat == "numeric"
    temp = NaN(height(data), width(data));
    for n = 1:width(data)
        if isnumeric(data.(n)) || islogical(data.(n))
            temp(1:height(data),n) = double(data.(data.Properties.VariableNames{n}));
        else
            temp(1:height(data),n) = NaN;
        end
    end
    data = temp;
end

end

function caldurs = string2CalendarDuration(intervals)
numYears = str2double(regexp(intervals,"-?\d*(?= years?)","match","once"));
numYears(isnan(numYears) & strlength(intervals)~=0) = 0;
numMonths = str2double(regexp(intervals,"-?\d*(?= mons?)","match","once"));
numMonths(isnan(numMonths) & strlength(intervals)~=0) = 0;
numWeeks = str2double(regexp(intervals,"-?\d*(?= weeks?)","match","once"));
numWeeks(isnan(numWeeks) & strlength(intervals)~=0) = 0;
numDays = str2double(regexp(intervals,"-?\d*(?= days?)","match","once"));
numDays(isnan(numDays) & strlength(intervals)~=0) = 0;
numHours = str2double(regexp(intervals,"-?\d*(?= hours?)","match","once"));
numHours(isnan(numHours) & strlength(intervals)~=0) = 0;
numMins = str2double(regexp(intervals,"-?\d*(?= mins?)","match","once"));
numMins(isnan(numMins) & strlength(intervals)~=0) = 0;
numSecs = str2double(regexp(intervals,"-?\d*(?= secs?)","match","once"));
numSecs(isnan(numSecs) & strlength(intervals)~=0) = 0;
agoIdx = endsWith(intervals,'ago');
caldurs = calyears(numYears) + calmonths(numMonths) + calweeks(numWeeks) + ...
    caldays(numDays) + hours(numHours) + minutes(numMins) + seconds(numSecs);
caldurs(agoIdx) = -caldurs(agoIdx);
end

function wrapper = tableToResultWrapper(T)
wrapper.T = T;
wrapper.getColumnNames = @() T.Properties.VariableNames;
wrapper.getColumnTypes = @() cellfun(@class, table2cell(T(1,:)), 'UniformOutput', false);
wrapper.parseResult = @() [];
wrapper.fetchData = @(n, typeCat) T{:, n};
wrapper.getNullRows = @() repmat({false(height(T), 1)}, 1, width(T));
wrapper.close = @() [];
end
% query = second_input;
% validateattributes(query,{'char','cell','string'},{'scalartext'},...
%     'fetch','query');
% query = char(query);

% if maxRows ~= 0
%     limitQuery =  matlab.io.datastore.internal.utilities.getLimitQuery('PostgreSQL');
%     limitQuery = limitQuery{:};
%     query = eval(limitQuery);
%     if ~isempty(optsObject)
%         dynamicLimitQuery = strrep(limitQuery,'query','dynamicQuery');
%         dynamicQuery = eval(dynamicLimitQuery);
%     end
% end

% try
%     if isDynamicQuery
%         try
%             result = connection.Handle.fetch(dynamicQuery);
%         catch
%             result = connection.Handle.fetch(query);
%             isDynamicQuery = false;
%         end
%     else
%         try
%             result = connection.Handle.fetch(query);
%         catch e
%             throw(e);
%         end
%     end
%     %Determine column names based on either names from the db or names
%     %specified in options object
%     if isempty(optsObject)
%         columnNames = result.getColumnNames();
%         if strcmpi(preserveNames,'modify') || strcmpi(dataReturnFormat,'structure')
%             columnNames = matlab.lang.makeValidName(columnNames);
%         end
%         columnNames = matlab.lang.makeUniqueStrings(columnNames);
%     else
%         if isDynamicQuery
%             originalNames = optsObject.SelectedVariableNames;
%         else
%             originalNames = optsObject.VariableNames;
%         end


%         if strcmpi(preserveNames,'modify') || strcmpi(dataReturnFormat,'structure')
%             columnNames = database.internal.utilities.makeValidVariableNames(originalNames);
%         else
%             columnNames = originalNames;
%         end
%     end


%     warning off
%     connstruct = struct(connection);
%     dataTypes = result.getColumnTypes;
%     [~,categoryIdx] = ismember(dataTypes,connstruct.DataTypes.oid);
%     typeCategories = connstruct.DataTypes.typcategory(categoryIdx);
%     modifiedTypeCategories = typeCategories;
%     typeName = connstruct.DataTypes.typname(categoryIdx);
%     warning on
%     %Need to alter typeCategories for money type as it needs to be handled
%     %differently from other numeric types

%     modifiedTypeCategories(typeName == "money") = {'money'};
%     modifiedTypeCategories(typeName == "int2") = {'smallint'};
%     modifiedTypeCategories(typeName == "int4") = {'integer'};
%     modifiedTypeCategories(typeName == "int8") = {'bigint'};
%     modifiedTypeCategories(typeName == "float4") = {'real'};

%     result.parseResult();

%     data = table();
%     for n = 1:length(columnNames)
%         if categoryIdx(n) == 160
%             data.(columnNames{n}) = ...
%             cellfun(@(x) str2double(split(regexprep(x,'{|}',''),',')).',...
%             result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
%             % newColumn.Properties.VariableNames(1) = columnNames(n);
%             % data.(columnNames{n}) = newColumn.Var1;
%         elseif categoryIdx(n) == 120
%             data.(columnNames{n}) = ...
%             cellfun(@(x) int32(str2double(split(regexprep(x,'{|}',''),','))).',...
%             result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
%         elseif categoryIdx(n) == 122
%             data.(columnNames{n}) = ...
%             cellfun(@(x) string(split(regexprep(x,'{|}',''),',').'),...
%             result.fetchData(n,modifiedTypeCategories{n}),'UniformOutput',false);
%         else
%             data.(columnNames{n}) = result.fetchData(n,modifiedTypeCategories{n});
%         end
%     end

%     nullRows = result.getNullRows();

%     if ~isempty(data)
%         if isempty(optsObject)
%             for n = 1:length(typeName)
%                 if upper(typeCategories{n}) == "N"
%                     if ~isa(data.(columnNames{n}),"double")
%                         data.(columnNames{n}) = double(data.(columnNames{n}));
%                         data.(columnNames{n})(nullRows{n}) = NaN;
%                     end
%                 end
%                 if upper(typeCategories{n}) == "E"
%                     allCats = fetch(connection,"SELECT unnest(enum_range(null::" + typeName{n} + "))::text AS enumTypes");
%                     allCats = allCats.enumtypes;
%                     cats = categorical(data.(columnNames{n}),allCats);
%                     data.(columnNames{n}) = cats;
%                 elseif upper(typeName{n}) == "DATE"
%                     dateValues = datetime(data.(columnNames{n}),'InputFormat','yyyy-MM-dd');
%                     dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
%                     dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
%                     data.(columnNames{n}) = dateValues;
%                 elseif upper(typeName{n}) == "TIMESTAMP"
%                     dateValues = datetime(data.(columnNames{n}));
%                     dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
%                     dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
%                     [data.(columnNames{n})] = dateValues;
%                 elseif upper(typeName{n}) == "TIMESTAMPTZ" || upper(typeName{n}) == "ABSTIME"
%                     nonNanTimestampIdx = find(~strcmp(data.(columnNames{n}),'NaN'),1);
%                     firstTime = data.(columnNames{n}){nonNanTimestampIdx};
%                     subSeconds = string(regexp(firstTime,'(?<=\.)\d*(?=+|-)','match'));
%                     if isempty(subSeconds)
%                         inputFormat = 'yyyy-MM-dd HH:mm:ssZ';
%                     else
%                         numSubSeconds = strlength(subSeconds);
%                         inputFormat = "yyyy-MM-dd HH:mm:ss." + string(repmat('S',[1 numSubSeconds])) + "Z";
%                     end
%                     dateValues = datetime(data.(columnNames{n}),'InputFormat',inputFormat,'TimeZone','local');

%                     dateValues(strcmp(data.(columnNames{n}),'infinity')) = datetime(inf,inf,inf);
%                     dateValues(strcmp(data.(columnNames{n}),'-infinity')) = datetime(-inf,-inf,-inf);
%                     data.(columnNames{n}) = dateValues;
%                 elseif upper(typeName{n}) == "TIME" || upper(typeName{n}) == "TIMETZ"
%                     %Remove the time zones if present
%                     timeStrings = regexprep(data.(columnNames{n}),"-\d{2}","");
%                     durs = duration(timeStrings);
%                     data.(columnNames{n}) = durs;
%                 elseif upper(typeName{n}) == "INTERVAL" || upper(typeName{n}) == "RELTIME"
%                     data.(columnNames{n}) = string2CalendarDuration(data.(columnNames{n}));
%                 end

%                 if isstring(data.(columnNames{n}))
%                     data.(columnNames{n})(nullRows{n}) = missing;
%                 end
%             end
%         else
%             %Use Option object to determine types etc.
%             for n = 1:width(data)
%                 varopts = getoptions(optsObject,originalNames{n});
%                 switch(varopts.Type)
%                     case {'char','string'}
%                         if ~strcmpi(class(data.(varopts.Name)),'string')
%                             data.(n) = string(data.(n));
%                         end
%                         if ~strcmpi(varopts.WhitespaceRule, 'preserve') && ~isempty(data.(n))
%                             side = varopts.WhitespaceRule;
%                             if strcmpi(side,'trim')
%                                 side = 'both';
%                             elseif strcmpi(side,'trimtrailing')
%                                 side = 'right';
%                             else
%                                 side = 'left';
%                             end
%                             data.(n) = strip(data.(n),side);
%                         end
%                         if ~strcmpi(varopts.TextCaseRule, 'preserve')
%                             caserule = varopts.TextCaseRule;
%                             if strcmpi(caserule,'upper')
%                                 data.(n) = upper(data.(n));
%                             else
%                                 data.(n) = lower(data.(n));
%                             end
%                         end
%                         if strcmpi(varopts.Type,'char')
%                             data.(n) = cellstr(data.(n));
%                             data.(n)(nullRows{n}) = {varopts.FillValue};
%                         end
%                         if strcmpi(varopts.Type,'string')
%                             data.(n)(nullRows{n}) = {varopts.FillValue};
%                         end

%                         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                     case 'double'
%                         data.(n) = double(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'single'
%                         data.(n) = single(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'int64'
%                         data.(n) = int64(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'uint64'
%                         data.(n) = uint64(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'int32'
%                         data.(n) = int32(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'uint32'
%                         data.(n) = uint32(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'int16'
%                         data.(n) = int16(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'uint16'
%                         data.(n) = uint16(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'int8'
%                         data.(n) = int8(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'uint8'
%                         data.(n) = uint8(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'logical'
%                         %Force NaNs to be false
%                         data.(n)(isnan(data.(n))) = -1;
%                         data.(n) = logical(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'datetime'
%                         data.(n)  = datetime(data.(n), ...
%                             'Format',varopts.DatetimeFormat, ...
%                             'Locale',varopts.DatetimeLocale, ...
%                             'TimeZone',varopts.TimeZone, ...
%                             'InputFormat',varopts.InputFormat);
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'duration'
%                         if isempty(varopts.InputFormat)
%                             data.(n) = duration(data.(n),...
%                                 'Format',varopts.DurationFormat);
%                         else
%                             data.(n) = duration(data.(n),...
%                                 'InputFormat',varopts.InputFormat,...
%                                 'Format',varopts.DurationFormat);
%                         end
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                     case 'categorical'
%                         data.(n) = database.internal.utilities.convertToCategoricalArray(data.(n), ...
%                             varopts.Categories, ...
%                             varopts.Ordinal, ...
%                             varopts.Protected, ...
%                             varopts.FillValue, ...
%                             nullRows{n});
%                     case 'calendarDuration'
%                         data.(n) = string2CalendarDuration(data.(n));
%                         data.(n)(nullRows{n}) = varopts.FillValue;
%                         if strlength(varopts.Format) > 0
%                             data.(n).Format = varopts.Format;
%                         end
%                 end
%             end

%             if ~isDynamicQuery
%                 %If the dynamic query didn't work, apply the options in
%                 %MATLAB

%                 %Apply RowFilter
%                 data = filter(optsObject.RowFilter,data);

%                 %Apply Missing Rule
%                 missingindices = [];
%                 for i = 1:width(data)
%                     varopts = getoptions(optsObject,i);
%                     if strcmpi(varopts.MissingRule,'omitrow')
%                         missingindices = [missingindices; nullRows{i}]; %#ok<AGROW>
%                     end
%                 end
%                 missingindices = unique(missingindices);
%                 data(missingindices,:) = [];

%                 %Apply SelectedVariableNames
%                 [~,idxToRemove] = setdiff(optsObject.VariableNames,optsObject.SelectedVariableNames);
%                 data(:,idxToRemove) = [];
%                 nullRows(idxToRemove) = [];

%                 % Apply ExcludeDuplicates
%                 if optsObject.ExcludeDuplicates
%                     data = database.internal.utilities.uniqueMissingIsEqual(data);
%                 end
%             end
%         end
%     end
% catch e
%     throw(e);
% end

% if nargout > 1

%     hasData = height(data) > 0;
%     if hasData
%         rowNames = data.Properties.VariableNames;
%         variableType = cell(length(rowNames),1);
%         fillValue = cell(length(rowNames),1);

%         if dataReturnFormat == "numeric"
%             variableType = repmat({'double'},length(rowNames),1);
%             fillValue = NaN(length(rowNames),1);
%         else
%             for n = 1:length(rowNames)
%                 if isempty(optsObject)
%                     variableType{n} = class(data.(columnNames{n}));
%                     fillValue{n} = database.options.internal.fillValueSelectorforSQL(connection,variableType{n});
%                 else
%                     variableType{n} = optsObject.VariableTypes{n};
%                     fillValue{n} = optsObject.FillValues{n};
%                 end
%             end
%         end

%         metadata = table(variableType,fillValue,nullRows,'RowNames',rowNames,...
%             'VariableNames',{'VariableType','FillValue','MissingRows'});
%     else
%         metadata = table([],[],[],'VariableNames',{'VariableType','FillValue','MissingRows'});
%     end
% end

% result.close();

% if dataReturnFormat == "structure"
%     data.Properties.VariableNames = database.internal.utilities.makeValidVariableNames(data.Properties.VariableNames);
%     data = table2struct(data);
% elseif dataReturnFormat == "cellarray"
%     data = table2cell(data);
% elseif dataReturnFormat == "numeric"
%     temp = NaN(height(data), width(data));
%     for n = 1:width(data)
%         if isnumeric(data.(n)) || islogical(data.(n))
%             temp(1:height(data),n) = double(data.(data.Properties.VariableNames{n}));
%         else
%             temp(1:height(data),n) = NaN;
%         end
%     end

%     data = temp;
% end

% end

% function caldurs = string2CalendarDuration(intervals)

% numYears = str2double(regexp(intervals,"-?\d*(?= years?)","match","once"));
% numYears(isnan(numYears) & strlength(intervals)~=0) = 0;
% numMonths = str2double(regexp(intervals,"-?\d*(?= mons?)","match","once"));
% numMonths(isnan(numMonths) & strlength(intervals)~=0) = 0;
% numWeeks = str2double(regexp(intervals,"-?\d*(?= weeks?)","match","once"));
% numWeeks(isnan(numWeeks) & strlength(intervals)~=0) = 0;
% numDays = str2double(regexp(intervals,"-?\d*(?= days?)","match","once"));
% numDays(isnan(numDays) & strlength(intervals)~=0) = 0;
% numHours = str2double(regexp(intervals,"-?\d*(?= hours?)","match","once"));
% numHours(isnan(numHours) & strlength(intervals)~=0) = 0;
% numMins = str2double(regexp(intervals,"-?\d*(?= mins?)","match","once"));
% numMins(isnan(numMins) & strlength(intervals)~=0) = 0;
% numSecs = str2double(regexp(intervals,"-?\d*(?= secs?)","match","once"));
% numSecs(isnan(numSecs) & strlength(intervals)~=0) = 0;
% %See which strings contain 'ago' and flip the sign for them
% agoIdx = endsWith(intervals,'ago');
% caldurs = calyears(numYears) + calmonths(numMonths) + calweeks(numWeeks) + ...
%     caldays(numDays) + hours(numHours) + minutes(numMins) + seconds(numSecs);
% caldurs(agoIdx) = -caldurs(agoIdx);
% end
