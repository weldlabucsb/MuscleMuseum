function conn = createWriter(databaseName)
%createWriter Create a writer connection to the specific database.
%  "databaseName" has to be a stored MATLAB datasource
username = "writer";
password = "writer";
conn = postgresql(databaseName,username,password);
conn.AutoCommit = 'on';
end

