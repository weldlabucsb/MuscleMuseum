function conn = connectPsqlDatabase(databaseName,serverName,port,username,password,isDisply)
%connectPsqlDatabase Summary of this function goes here
%   Detailed explanation goes here
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

