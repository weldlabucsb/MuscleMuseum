function deleteBecExp(serialNumber,isForceDelete)
%LOADBECEX Summary of this function goes here
%   Detailed explanation goes here
arguments
    serialNumber
    isForceDelete = false
end
p = BecExpConfig;
databaseName = p.readValue(1,"DatabaseName");
databaseTableName = p.readValue(1,"DatabaseTableName");
conn = createWriter(databaseName);
deleteTrial(conn,databaseTableName,serialNumber,isForceDelete);
end

