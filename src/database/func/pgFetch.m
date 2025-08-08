function [data,metadata] = pgFetch(connect,second_input,varargin)
% Fetch data and metadata from PostgreSQL using a connection or prepared statement.
%
% :param connect: Open database connection
% :type connect: database.relational.connection
% :param second_input: SQL query string or prepared statement
% :type second_input: char | string | database.preparedstatement.SQLPreparedStatement
% :param varargin: Optional arguments
% :type varargin: any
% :return: Fetched data
% :rtype: table | cell | struct | numeric
% :return: Metadata describing returned data
% :rtype: struct
%
% **Options (name-value):**
%
%     - ``MaxRows``: Maximum number of rows to return (default 0 = unlimited)
%     - ``VariableNamingRule``: "preserve" or "modify" (table output only)
%     - ``DataReturnFormat``: one of "table" (default) | "cellarray" | "structure" | "numeric"
%     - ``RowFilter``: :class:`matlab.io.RowFilter` to push down to SQL
%     - ``rowlimit_or_opts``: Either a row-limit scalar or a SQLImportOptions object
%
% **Notes:**
%
%     When a prepared statement is provided, certain options are mutually exclusive
%     (e.g., ``RowFilter`` and import options). See MATLAB Database Toolbox behavior.
%   DATA = FETCH(CONN,SQLSTRING)
%   imports database data into MATLAB given the connection handle, CONN,
%   and the SQL string, SQLSTRING.
%
%   DATA = FETCH(CONN,SQLSTRING,OPTS)
%   imports database data into MATLAB using the specified import options
%   opts.
%
%   DATA = FETCH(CONN,SQLSTRING,NAME,VALUE)
%   imports database data into MATLAB with additional options specified by one
%   or more name-value arguments. For e.g., you can specify
%   DataReturnFormat or MaxRows name-value argument.
%
%   DATA = FETCH(CONN,PSTMT)
%   imports database data into MATLAB given the connection handle, CONN,
%   and the SQLPreparedStatement, PSTMT.
%
%   DATA = FETCH(CONN,PSTMT,NAME,VALUE)
%   imports database data into MATLAB with additional options specified by one
%   or more name-value arguments. For e.g., you can specify
%   DataReturnFormat or MaxRows name-value argument.
%
%   [data,metadata] = FETCH(_____)
%   imports database data into MATLAB and metadata information for
%   imported data
%
%   Input Arguments:
%   -----------------------------
%   conn      - database.jdbc.connection object.
%   source    - SQL query or SQLPreparedStatement.
%
%
%   Optional Arguments:
%   -------------------------------
%   opts             - import options for sql query defined using databaseImportOptions
%   DataReturnFormat - type of data returned. table (default) | cellarray | structure | numeric
%   MaxRows          - Maximum number of rows to return
%   VariableNamingRule - determine use of arbitrary variable names
%
%   For example,
%
%   data = fetch(conn,'select * from tablename')
%   will return the data as a table by default.
%
%   [data,metadata] = fetch(conn,'select * from tablename','DataReturnFormat','cellarray')
%   will return the data as a cell array.
%
%   data = fetch(conn,'select * from tablename',opts)
%   will return the data using import options specified using opts.
%
%   See also connection/sqlread, databaseImportOptions

%   Copyright 2022 The MathWorks, Inc.

%First check to see if the subclass supports this method
subclass = metaclass(connect);
fetchHookMethod = subclass.MethodList(string({subclass.MethodList.Name}) == "fetchHook");
definingClass = fetchHookMethod.DefiningClass;
if definingClass ~= subclass
    %This class does not support fetch, so error out
    error(message('database:database"MethodNotSupported','fetch',class(connect)));
end

%Check for a valid connection
if ~isopen(connect)
    error(message("database:database:invalidConnection"))
end

%Parse inputs
p = inputParser;

addRequired(p,"connect",@(x)validateattributes(x,"database.relational.connection","scalar","fetch"));
addRequired(p,"second_input",@(x)validateattributes(x,["char" "string" "database.preparedstatement.SQLPreparedStatement"],{},"fetch"));
addOptional(p,"rowlimit_or_opts",0, @(x)validateattributes(x, ["numeric","database.options.SQLImportOptions"],"scalar","fetch"));
addParameter(p,"MaxRows",0, @(x)validateattributes(x, "numeric", ["scalar" "integer" "nonnegative"],"fetch"));
addParameter(p,"VariableNamingRule","preserve", @(x)validateattributes(x, ["char" "string"],"scalartext","fetch"));
addParameter(p,"DataReturnFormat","table", @(x)validateattributes(x, ["char" "string"],"scalartext","fetch"));
p.addParameter("RowFilter",rowfilter(missing),@(x)validateattributes(x,"matlab.io.RowFilter","scalar","fetch"));

parse(p,connect,second_input,varargin{:});

%The second inout can be either a sql query or a prepared
%statment
second_input = p.Results.second_input;
try
    %Check for a sql query first
    validateattributes(second_input,["char" "string"],{'scalartext'},"fetch","sqlquery");
    validateattributes(char(second_input),"char",{'nonempty'},"fetch","sqlquery");
catch ME
    %Check for prepared statmeent only if the interface
    %explicitly supports it
    if isa(second_input,"database.preparedstatement.SQLPreparedStatement") && connect.SupportsPreparedStatements
        validateattributes(second_input,"database.preparedstatement.SQLPreparedStatement",{'scalar'},"fetch","preparedstatement");
        if ~isvalid(second_input)
            error(message('database:preparedstatement:InvalidPreparedStatement'))
        end
        if ~second_input.isReadyForExecution
            error(message('database:preparedstatement:IncompletePreparedStatement'))
        end
        if ~database.internal.utilities.isSingleSelectQuery(second_input.SQLQuery) && ...
                ~database.internal.utilities.DatabaseUtils.isSingleStoredProcedureCall(second_input.SQLQuery)
            error(message('database:preparedstatement:NotAValidSQLQuery','SELECT SQL Query OR a STORED Procedure call'));
        end
    else
        throw(ME);
    end
end

rowlimit_or_opts = p.Results.rowlimit_or_opts;
maxRows = p.Results.MaxRows;
preserveNames = validatestring(p.Results.VariableNamingRule,["modify" "preserve"]);
isvarnamerulespecified = ~any(strcmpi(p.UsingDefaults,'VariableNamingRule'));
dataReturnFormat = p.Results.DataReturnFormat;
dataReturnFormat = char(validatestring(char(dataReturnFormat),{'table','cellarray','structure','numeric'},"fetch"));
rowFilter = p.Results.RowFilter;


%The third input can be either the row limit or the import options
%object
rowLimit = 0;
optsObject = [];

if isa(rowlimit_or_opts,"database.options.SQLImportOptions")
    if ~connect.SupportsImportOptions
        error(message('database:importoptions:ImportOptionsNotSupported',class(connect)));
    end
    optsObject = copy(rowlimit_or_opts);
else
    rowLimit = rowlimit_or_opts;
    validateattributes(rowLimit,"numeric",["scalar","integer","nonnegative"],"fetch","rowLimit")
end

%By default there is no dynmaic query.
isDynamicQuery = false;
dynamicQuery = '';

underlyingFilter = getProperties(rowFilter).UnderlyingFilter;

if ~isa(underlyingFilter,"matlab.io.internal.filter.UnconstrainedRowFilter") && ...
        ~isa(underlyingFilter,"matlab.io.internal.filter.MissingRowFilter")

    if isa(second_input,"database.preparedstatement.SQLPreparedStatement")
        %Cannot have both the prepared statement and rowFilter
        error(message('database:preparedstatement:CannotUseRowFilter'))
    end

    if ~isempty(optsObject)
        %RowFilter name-value pair can't be used with an
        %options object as the options may have its own filter
        %object
        error(message('database:importoptions:RowFilterOptionsIncompatible'));
    end

    if ~database.internal.utilities.isSingleSelectQuery(char(second_input))
        error(message('database:database:NotASelectQuery'));
    end

    %Apply the filters to the SQL query
    dispatcher = database.internal.utilities.SQLFilterDispatcher();
    querybuilder = dispatcher.dispatch(rowFilter,second_input,connect.DatabaseProductName);
    second_input = querybuilder.SQLQuery;
end

if ~isempty(optsObject)
    if isvarnamerulespecified
        %VariableNamingRules not compatible with import options
        error(message('database:importoptions:ImportOptionsVariableNamingRule'));
    end

    if isa(second_input,"database.preparedstatement.SQLPreparedStatement")
        %Cannot have both the prepared statement and options object
        error(message('database:preparedstatement:CannotUseImportOptions','preparedstatement'))
    end

    if strcmpi(dataReturnFormat,'numeric')
        %import options do not support nueric output
        warning(message('database:importoptions:ImportOptionsNumericUnsupported',char(dataReturnFormat)));
    end

    %Options object uses dynamic uery unless Exclude Duplicates
    %in on and the interface doesn't support it
    dynamicQuery = char(optsObject.getDynamicSQLQuery());
    if ~(optsObject.ExcludeDuplicates && ~connect.SupportsDynamicExcludeDuplicates)
        isDynamicQuery = true;
    end
    preserveNames = optsObject.VariableNamingRule;

    %Moidify the option object variable names if needed
    if strcmpi(optsObject.VariableNamingRule,'modify')
        optsObject.VariableNames = database.internal.utilities.makeValidVariableNames(optsObject.VariableNames);
    end

    if ~strcmpi(second_input,optsObject.getSQLQuery())
        %Verify the the query for the options object matches
        %the query to be executed
        error(message('database:importoptions:QueriesDoNotMatch',char(second_input)));
    end

    if preserveNames == "preserve" && dataReturnFormat == "structure"
        %Warn the users that variable names can't be preserved
        %for structs
        warning(message('database:mysql:connection:VariableNamingRuleStructure',char(dataReturnFormat)));
    end
end

if maxRows < rowLimit
    maxRows = rowLimit;
end

%VariableNamingRule is only compatible with table output
if isvarnamerulespecified && (strcmpi(dataReturnFormat,'structure') || strcmpi(dataReturnFormat,'numeric') || strcmpi(dataReturnFormat,'cellarray'))
    error(message('database:mysql:connection:UnsupportedVariableNamingRuleWithTypes',char(dataReturnFormat)));
end

if nargout == 2
    [data,metadata] = pgFetchHook(connect,second_input,optsObject,isDynamicQuery,dynamicQuery,maxRows,preserveNames,dataReturnFormat);
else
    data = pgFetchHook(connect,second_input,optsObject,isDynamicQuery,dynamicQuery,maxRows,preserveNames,dataReturnFormat);
end
end
