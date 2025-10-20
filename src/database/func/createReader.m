function conn = createReader(databaseName)
%createWriter Create a writer connection to the specific database.
%  "databaseName" has to be a stored MATLAB datasource
username = "reader";
password = "reader";
conn = postgresql(databaseName,username,password);
end

