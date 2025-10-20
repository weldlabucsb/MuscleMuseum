function pgUpdate(connect,tablename, data, filter, varargin)

[connect,tablename,data,filter,varargin{:}] = convertCharsToStrings(connect,tablename, data, filter, varargin{:});

%Parse inputs
p = inputParser;

p.addRequired("connect",@(x)validateattributes(x,"database.relational.connection","scalar"));
p.addRequired("tablename",@(x)validateattributes(x,["string" "char"],"scalartext"));
p.addRequired("data",@(x)validateattributes(x,"table",{}));
p.addRequired("filter",@(x)validateattributes(x,["string","matlab.io.RowFilter","cell"],"vector"));
p.addParameter("Catalog","",@(x)validateattributes(x,["string" "char"],"scalartext"));
p.addParameter("Schema","",@(x)validateattributes(x,["string" "char"],"scalartext"));
p.addParameter("isForceArray",false)

p.parse(connect,tablename,data,filter,varargin{:});
isForceArray = p.Results.isForceArray;

%Check for a valid connection
if ~isopen(connect)
    error(message("database:database:invalidConnection"));
end

if isa(filter,"matlab.io.RowFilter")
    filter = {filter};
end

nfilter = numel(filter);
for ii = 1:nfilter
    vNames = properties(filter{ii});
    nNames = numel(vNames);
    for jj = 1:nNames
        filter{ii} = replaceVariableNames(filter{ii},vNames{jj},['"',vNames{jj},'"']);
    end
end

if ~all(cellfun(@(x)isa(x,"matlab.io.RowFilter"),filter))
    error('Cell array must have maltab.io.Rowfilters');
end


%Datamine table information
catalog = string(p.Results.Catalog);
schema = string(p.Results.Schema);
tablename = string(p.Results.tablename);
columnNames = string(data.Properties.VariableNames);
columnNames = arrayfun(@(x) """" + x + """",columnNames); %Add "" for column names for case-sensitivity in pg

% g1781499 - Split tablename to see if there is catalog and/or schema name attached
temp_tablename = strsplit(tablename,".");
tablename = string(temp_tablename(end));
otherparts = "";
switch numel(temp_tablename)
    case 1
        % do nothing
    case 2
        if isempty(connect.Schemas)
            catalog = string(temp_tablename(end-1));
        else
            schema = string(temp_tablename(end-1));
        end
    otherwise
        schema = string(temp_tablename(end-1));
        catalog = string(temp_tablename(end-2));
        otherparts = string(strjoin(temp_tablename(1:end-3)));
end

%g2197693 Remove identifier quotes before running sqlfind to avoid a bad
%matching pattern
% identifier = connect.getIdentifier();
identifier = """";
tableNameToMatch = tablename;
if strlength(tableNameToMatch) > 1 && startsWith(tableNameToMatch,identifier) ...
        && endsWith(tableNameToMatch,identifier)
    tableNameToMatch = extractBetween(tableNameToMatch,1,strlength(tableNameToMatch),...
        'Boundaries','exclusive');
end

catalogNameToMatch = catalog;
if strlength(catalogNameToMatch) > 1 && startsWith(catalogNameToMatch,identifier) ...
        && endsWith(catalogNameToMatch,identifier)
    catalogNameToMatch = extractBetween(catalogNameToMatch,1,strlength(catalogNameToMatch),...
        'Boundaries','exclusive');
end

schemaNameToMatch = schema;
if strlength(schemaNameToMatch) > 1 && startsWith(schemaNameToMatch,identifier) ...
        && endsWith(schemaNameToMatch,identifier)
    schemaNameToMatch = extractBetween(schemaNameToMatch,1,strlength(schemaNameToMatch),...
        'Boundaries','exclusive');
end

%Serach for a table that matches the given name
tabledata = sqlfind(connect,tableNameToMatch,"Catalog",catalogNameToMatch,"Schema",schemaNameToMatch);

if ~isempty(tabledata.Table)
    %Remove any entries that are not an exact match
    tabledata(cellfun(@(x)~strcmpi(x,char(tableNameToMatch)),tabledata.Table),:) = [];
end

if height(tabledata) > 1
    %Error if multiple tables match the name
    error(message('database:database:MultipleTableEntries',tableNameToMatch,"Catalog","Schema"));
elseif height(tabledata) < 1
    %No table was found
    error(message('database:database:TableNonexistent',tableNameToMatch));
end

%Add the schema and catalog to the table name
if schema.strlength ~= 0
    tablename = schema + "." + tablename;
end

if catalog.strlength ~= 0
    tablename = catalog + "." + tablename;
end

% g1781499 - This is needed if using fully qualified table-name. Generally fully
% qualified table-name has only 3 parts, but with cloud solutions one can
% add server-name as well for certain databases.
if numel(temp_tablename) > 3
    tablename = otherparts + "." + tablename;
end

%If the input was a rowfilter, we need to construct a new
%UPDATE statment for each row. we can't use a prepared
%statement as we can't be sure that the structure of each
%query will be the same.

%First Verify that the number of RowFilter objects matches
%the table's height
if length(filter) ~= height(data)
    error('Number of filters must match the height of the table');
end

noRowTable = fetch(connect,"SELECT * FROM "+tablename+" WHERE FALSE;");
columnnamesDB = noRowTable.Properties.VariableNames;
columnnamesDB = cellfun(@(x) """"+string(x)+"""",columnnamesDB);
columnCompare = ismember(columnNames,columnnamesDB);
if ~all(columnCompare)
    addedColumnNames = columnNames(~columnCompare);
    [data,columnTypes] = database.internal.utilities.TypeMapper.matlabToDatabaseTypes(connect,data,connect.DatabaseProductName);
    [data,columnTypes,columnNames] = database.internal.utilities.TypeMapper.modifyData(data,columnTypes,columnNames);
    firstRowData = table2cell(data(1,:));
    for ii = 1:numel(columnNames)
        if numel(firstRowData{ii})>1 || isForceArray
            if isa(firstRowData{ii},'float')
                columnTypes(ii) = "numeric[]";
            elseif isa(firstRowData{ii},'integer')
                columnTypes(ii) = "int[]";
            elseif isa(firstRowData{ii},'string')
                columnTypes(ii) = "text[]";
            end
        end
    end
    addedColumnTypes = columnTypes(~columnCompare);
    query = "ALTER TABLE "+tablename;
    for ii = 1:numel(addedColumnNames)
        query = query + " ADD COLUMN " + addedColumnNames(ii) + " " + addedColumnTypes(ii);
        if ii ~= numel(addedColumnNames)
            query = query + ',';
        end
    end
    query = query + ";";
    execute(connect,query)
end

%get list of columns that are arrays
query = "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '" + tablename + "'" ;
out = pgFetch(connect,query);
aNames = out(out.data_type == "ARRAY",:).column_name;
aNames = cellfun(@(x) """"+string(x)+"""",aNames);
aNames = string(aNames);

query = strings(height(data),1);
%Convert all logicals to numerics before string conversion
data = varfun(@(x)database.postgre.connection.logical2Numeric(x),data);

for n = 1:height(data)
    querybuilder = database.internal.utilities.SQLQueryBuilder;
    tCell = table2cell(data(n,:));
    emptyIdx = cellfun(@isempty,tCell);
    tCell(emptyIdx) = {''};
    for ii = 1:numel(tCell)
        if numel(tCell{ii})>1 || isForceArray || ismember(columnNames(ii),aNames)
            if isempty(tCell{ii})
                tCell{ii} = "{}";
            elseif isa(tCell{ii},"numeric")
                tCell{ii} = "{"+regexprep(num2str(tCell{ii}),'\s+',',')+"}";
            elseif isa(tCell{ii},"string")
                tCell{ii} = "{" + strjoin(arrayfun(@(x) """" + x + """",tCell{ii}),",") + "}";
                tCell{ii} = strrep(tCell{ii},"'","''");
            end
        else
            tCell{ii} = string(tCell{ii});
            tCell{ii} = strrep(tCell{ii},"'","''");
        end
    end
    tCellStr = string(tCell);
    missingVals = ismissing(tCellStr) | strlength(tCellStr) == 0;
    tCell(missingVals) = [];
    columnNames(missingVals) = [];

    querybuilder = querybuilder.update(tablename,columnNames,tCell,connect.DatabaseProductName);
    dispatcher = database.internal.utilities.SQLFilterDispatcher();
    querybuilder = dispatcher.dispatch(filter{n},querybuilder,connect.DatabaseProductName);
    query(n) = querybuilder.SQLQuery;
end

oldState = connect.AutoCommit;
connect.AutoCommit = 'off';

try
    for n = 1:length(query)
        execute(connect,query(n));
    end
catch ME
    if strcmpi(oldState,"on")
        try
            execute(connect,"ROLLBACK");
        catch
        end
    end

    % Reset auto-commit to original value
    connect.AutoCommit = oldState;
    error(message("database:database:WriteTableDriverError",connect.DatabaseProductName,string(ME.message)));
end

% If update succeeds, first COMMIT whatever was written and then
% reset preferences
if strcmpi(oldState,"on")
    try
        execute(connect,"COMMIT");
    catch
    end
end

% Reset auto-commit to original value
connect.AutoCommit = oldState;

end
