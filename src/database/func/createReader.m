function conn = createReader(databaseName)
% Create a PostgreSQL reader connection to the specified database.
%
% Establishes a database connection with read-only privileges using predefined
% reader credentials. The database name must be a stored MATLAB datasource.
%
% :param databaseName: Name of the MATLAB-configured datasource
% :type databaseName: string
% :return: PostgreSQL connection with read-only access
% :rtype: database.postgre.connection
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = createReader("myDatabase");
%    data = pgFetch(conn, "SELECT * FROM myTable");
username = "reader";
password = "reader";
conn = postgresql(databaseName,username,password);
end

