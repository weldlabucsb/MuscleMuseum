function pgWrite(conn,tableName,data,varargin)
%PGWRITE Write a MATLAB table to a postgresql database table
%pgWrite(conn,tableName,data)
%   
%   conn: connection to pg database
%   tableName: database table name
%   data: input MATLAB table
%   isForceArray: force to create new columns as arrays
%   Writes a MATLAB table to a database table. Modified from matlab
%   function <sqlwrite>. This function can handle vectors in the input
%   table. Extra columns in data that are not in the database table will be
%   created in the database table.

%Parse inputs
p = inputParser;

p.addRequired("conn",@(x)validateattributes(x,"database.relational.connection","scalar"));
p.addRequired("tableName",@(x)validateattributes(x,["string" "char"],"scalartext"))
p.addRequired("data",@(x)validateattributes(x,"table",{}))
p.addParameter("isForceArray",false)
% p.addParameter("Catalog","",@(x)validateattributes(x,["string" "char"],"scalartext"));
% p.addParameter("Schema","",@(x)validateattributes(x,["string" "char"],"scalartext"));
% p.addParameter("ColumnType","",@(x)validateattributes(x,["string" "char" "cell"],{}));

p.parse(conn,tableName,data,varargin{:});
isForceArray = p.Results.isForceArray;

%Check for a valid connection
if ~isopen(conn)
    error(message("database:database:invalidConnection"));
end

tableName = string(p.Results.tableName);
columnNames = string(data.Properties.VariableNames);
columnNames = arrayfun(@(x) """" + x + """",columnNames); %Add "" for column names for case-sensitivity in pg

%Check column names of the table in the database
noRowTable = fetch(conn,"SELECT * FROM "+tableName+" WHERE FALSE;");
columnNamesDB = noRowTable.Properties.VariableNames;
columnNamesDB = cellfun(@(x) """"+string(x)+"""",columnNamesDB);
columnCompare = ismember(columnNames,columnNamesDB);

%If the input data have different columns compared to the database, add
%columns to the database table
if ~all(columnCompare)
    [data,columnTypes] = database.internal.utilities.TypeMapper.matlabToDatabaseTypes(conn,data,conn.DatabaseProductName);
    [data,columnTypes,columnNames] = database.internal.utilities.TypeMapper.modifyData(data,columnTypes,columnNames);
    columnCompare = ismember(columnNames,columnNamesDB);
    addedColumnNames = columnNames(~columnCompare);
    firstRowData = table2cell(data(1,:));
    for ii = 1:numel(columnNames)
        if numel(firstRowData{ii})>1 || isForceArray %If the input data are vectors, create vector type columns in database
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
    query = "ALTER TABLE "+tableName;
    for ii = 1:numel(addedColumnNames)
        query = query + " ADD COLUMN " + addedColumnNames(ii) + " " + addedColumnTypes(ii);
        if ii ~= numel(addedColumnNames)
            query = query + ',';
        end
    end
    query = query + ";";
    if ~isempty(addedColumnTypes)
        execute(conn,query)
    end
end

if isempty(data)
    validateattributes(data,"table","nonempty");
end

pgWriteHook(conn,tableName,data,columnNames,isForceArray)
end


