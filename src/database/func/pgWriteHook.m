function pgWriteHook(conn,tableName,data,columnNames,isForceArray)
%PGWRITEHOOK write a MATLAB table to a postgresql database table
%Modified from matlab built-in function <sqlwritehook>

statementName = "sqlwrite_statement";
existingPreparedStatementNames = fetch(conn,"SELECT name FROM pg_prepared_statements",'DataReturnFormat','cellarray');
if ~isempty(existingPreparedStatementNames)
    allNames = [existingPreparedStatementNames;statementName];
    allNames = matlab.lang.makeUniqueStrings(allNames);
    statementName = allNames(end);
end

insertStmt = preparedInsert(columnNames,tableName);
result = conn.Handle.prepareStatement(statementName,insertStmt,length(columnNames));
close(result);

oldState = conn.AutoCommit;
conn.AutoCommit = 'off';

numRows = height(data);

%Convert all logicals to numerics before string conversion
transformedData = varfun(@(x)database.postgre.connection.logical2Numeric(x),data);

% Empty Values [] arent' compatible with the string conversion. Convert
% these to empty string ''
transformedData = table2cell(transformedData);
emptyIdx = cellfun(@isempty,transformedData);
transformedData(emptyIdx) = {''};

%Convert to string and find all missing and empty values and convert these to
%[] (NULL in C++)
for ii = 1:numel(transformedData) %Convert array to pg array form
    if numel(transformedData{ii})>1 || isForceArray
        if isa(transformedData{ii},"numeric")
            transformedData{ii} = "{"+regexprep(num2str(transformedData{ii}),'\s+',',')+"}";
        elseif isa(transformedData{ii},"string")
            transformedData{ii} = "{" + strjoin(arrayfun(@(x) """" + x + """",transformedData{ii}),",") + "}";
            transformedData{ii} = strrep(transformedData{ii},"'","''");
        end
    else
        transformedData{ii} = string(transformedData{ii});
        transformedData{ii} = strrep(transformedData{ii},"'","''");
    end
end
transformedData = string(transformedData);
missingVals = ismissing(transformedData) | strlength(transformedData) == 0;
transformedData = cellstr(transformedData);
transformedData(missingVals) = {[]};

try
    for n = 1:numRows
        conn.Handle.executePreparedStatement(statementName,transformedData(n,:));
    end
catch ME
    if strcmpi(oldState,"on")
        try
            execute(conn,"ROLLBACK");
        catch
        end
    end
    
    
    % Reset auto-commit to original value
    conn.AutoCommit = oldState;    
    error(message("database:database:WriteTableDriverError","PostgreSQL",string(ME.message)));
end

% If INSERT succeeds, first COMMIT whatever was written and then
% reset preferences if one of four databases
if strcmpi(oldState,"on")
    try
        execute(conn,"COMMIT");
    catch
    end
end

% Reset auto-commit to original value
conn.AutoCommit = oldState;
end

function stmt = preparedInsert(colnames,tablename)

p = inputParser;

p.addRequired("colnames",@(x)validateattributes(x,"string",{}));
p.addRequired("tablename",@(x)validateattributes(x,"string","scalartext"));

p.parse(colnames,tablename);

stmt = "INSERT INTO " + tablename + " ( ";
stmt = stmt + strjoin(colnames,", "); 
stmt = stmt + ") VALUES (";
params = "$" + (1:length(colnames));
stmt = stmt + strjoin(params,", ");
stmt = stmt + ")";
end