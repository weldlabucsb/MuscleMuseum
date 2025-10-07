function conn = createWriter(databaseName)
% Create a PostgreSQL writer connection to the specified database.
%
% Establishes a database connection with write privileges using predefined
% writer credentials. The database name must be a stored MATLAB datasource.
%
% :param databaseName: Name of the MATLAB-configured datasource
% :type databaseName: string
% :return: PostgreSQL connection with write access and auto-commit enabled
% :rtype: database.postgre.connection
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = createWriter("myDatabase");
%    pgWrite(conn, "myTable", myData);
username = "writer";
password = "writer";
conn = postgresql(databaseName,username,password);
conn.AutoCommit = 'on';
end

