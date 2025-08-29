function obj = loadTrial(conn,databaseTableName,serialNumber)
% Load trial objects by serial number from a database table.
%
% :param conn: Open database connection
% :type conn: any
% :param databaseTableName: Trial table name
% :type databaseTableName: string | char
% :param serialNumber: One or more serial numbers to load
% :type serialNumber: double array | int array
% :return: Loaded objects array
% :rtype: any
%LOADTRIAL Summary of this function goes here
%   Detailed explanation goes here
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

