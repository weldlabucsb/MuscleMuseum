function conn = connectPsqlDatabase(databaseName,serverName,port,username,password,isDisply)
% Establish a PostgreSQL database connection with specified credentials.
%
% Creates a native PostgreSQL connection using the provided server details
% and credentials. Tests the connection before returning and displays
% connection status information.
%
% :param databaseName: Name of the target database
% :type databaseName: string
% :param serverName: PostgreSQL server hostname or IP address
% :type serverName: string
% :param port: Server port number (typically 5432)
% :type port: double
% :param username: Database username
% :type username: string
% :param password: Database password
% :type password: string
% :param isDisply: Display connection status messages (default: true)
% :type isDisply: logical, optional
% :return: Established PostgreSQL database connection
% :rtype: database.postgre.connection
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = connectPsqlDatabase("myDB", "localhost", 5432, "user", "pass");
arguments
    databaseName string
    serverName string
    port double
    username string
    password string
    isDisply logical = true
end

opts = databaseConnectionOptions("native","PostgreSQL");
opts = setoptions(opts, ...
    'DataSourceName',databaseName, ...
    'DatabaseName',databaseName,'Server',serverName, ...
    'PortNumber',port,...
    'connect_timeout', 3);
saveAsDataSource(opts)

[status,message] = testConnection(opts,username,password);
if status == true
    if isDisply
        disp(append(newline,'Database connection succeeded.',newline,...
            'Server: ',serverName,newline,...
            'Database: ',databaseName,newline,...
            'Port: ',num2str(port)))
    end
    conn = postgresql(databaseName,username,password);
    conn.AutoCommit;
else
    error(append('Database connection failed.',newline,...
        'Error message from PostgreSQL:',newline,message))
end
end

