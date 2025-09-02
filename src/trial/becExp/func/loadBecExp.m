function obj = loadBecExp(serialNumber)
%LOADBECEX Summary of this function goes here
%   Detailed explanation goes here
p = BecExpConfig;
databaseName = p.readValue(1,"DatabaseName");
databaseTableName = p.readValue(1,"DatabaseTableName");
conn = createReader(databaseName);
obj = loadTrial(conn,databaseTableName,serialNumber);
end

