function pgWrite(conn,tableName,data,varargin)
% Write a MATLAB table to a PostgreSQL database table, adding columns if needed.
%
% Enhanced version of MATLAB's ``sqlwrite`` that handles vector-valued columns
% and automatically adds missing columns to the database table with appropriate
% array types (numeric[], int[], text[]).
%
% :param conn: Open PostgreSQL database connection
% :type conn: database.postgre.connection
% :param tableName: Target database table name
% :type tableName: string
% :param data: MATLAB table to write to database
% :type data: table
% :param isForceArray: Force new columns to be created as array types (default: false)
% :type isForceArray: logical, optional
%
% **Notes:**
%
%     - Extra variables in ``data`` that do not exist in the DB table are automatically added.
%     - Vector-valued cells are mapped to PostgreSQL array column types (numeric[], int[], text[]).
%     - Column names are case-sensitive and quoted for PostgreSQL compatibility.
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = createWriter("myDatabase");
%    data = table([1; 2], ["a"; "b"], VariableNames=["id", "name"]);
%    pgWrite(conn, "myTable", data);

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


