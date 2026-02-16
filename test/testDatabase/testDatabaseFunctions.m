%% Connect to the local postgres database and create a test table
p = DatabaseServerConfig;
svConfig = p.readTable;
localServer = svConfig(svConfig.Name == "localhost",:);
conn = connectPsqlDatabase( ...
    "postgres", ...
    localServer.Name, ...
    localServer.Port, ...
    localServer.Username, ...
    localServer.Password,...
    false);

tableName = "test_table";
try
    execute(conn,"CREATE TABLE " + tableName + "(" + ...
        """SerialNumber"" serial," + ...
        """DateTime"" timestamp," + ...
        """Name"" varchar," + ...
        """NRun"" integer," + ...
        """NCompletedRun"" integer" + ...
        ");")
catch
end

%% Test case sensitivity
Name = "asdf";
DateTime = datetime;
t = table(Name,DateTime); % generate a test table
pgWrite(conn,tableName,t)

%% Test if new columns can be automatically generated
newCol = 123;
t = table(newCol);
pgWrite(conn,tableName,t)

%% Test if new array-type columns can be automatically generated
newCol2 = [1,2,3];
t = table(newCol2);
pgWrite(conn,tableName,t)

%% Test new column generation with pgUpdate;
newCol3 = [1,2,3];
t = table(newCol3);
rf = rowfilter('SerialNumber');
rf = rf.SerialNumber == 1; % row filter
pgUpdate(conn,tableName,t,rf)

%% Read table
pgRead(conn,tableName)

%% Fetch rows
query = "SELECT * FROM " + tableName + " WHERE " + """SerialNumber"""+ " = 1";
pgFetch(conn,query)