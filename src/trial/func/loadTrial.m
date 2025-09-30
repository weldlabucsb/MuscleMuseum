function obj = loadTrial(conn,databaseTableName,serialNumber)
% Load trial objects by serial number from a database table.
%
% Retrieves trial object file paths from the database and loads the saved
% :class:`Trial` objects from disk. Handles multiple serial numbers and
% returns an array of loaded objects.
%
% :param conn: Open PostgreSQL database connection
% :type conn: database.postgre.connection
% :param databaseTableName: Database table name containing trial records
% :type databaseTableName: string
% :param serialNumber: Trial serial numbers to load (can be array)
% :type serialNumber: double
% :return: Loaded trial objects (array if multiple serial numbers provided)
% :rtype: :class:`Trial`
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = createReader("myDatabase");
%    trials = loadTrial(conn, "BecExpTrial", [1234, 1235]);
if isempty(serialNumber)
    return
end
serialNumber = serialNumber(:).';
query = "SELECT ""ObjectPath"" FROM "+databaseTableName+" WHERE ""SerialNumber"" in ("+...
    regexprep(num2str(serialNumber),'\s+',',')+")";
data = pgFetch(conn,query);
warning off
obj = arrayfun(@(fName) loadVar(fName,"obj"), data.ObjectPath);
warning on
end

