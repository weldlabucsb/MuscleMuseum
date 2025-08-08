function deleteTrial(conn,databaseTableName,serialNumber,isForceDelete)
% Delete trial folders and database rows for given serial numbers.
%
% :param conn: Open database connection
% :type conn: any
% :param databaseTableName: Table name containing trials
% :type databaseTableName: string | char
% :param serialNumber: Serial numbers to delete
% :type serialNumber: double array | int array
% :param isForceDelete: If true, skip interactive confirmation
% :type isForceDelete: logical, optional
%DELETETRIAL delete folders and database rows for trials with serialNumber
%   conn: database connection
%   databaseTableName: databas table name
%   serialNumber: serial number of the trails to be deleted. can be a
%   vector
%   isForceDelete: boolean. Force to delete or not.
arguments
    conn
    databaseTableName
    serialNumber
    isForceDelete = false
end
if isempty(serialNumber)
    return
end
if isForceDelete ~= true
    choice = input('Delete these trials? Please type [Y] or [N]:','s');
    if choice=='Y'
        disp('Attempt to delete trials...')
    elseif choice=='N'
        disp('Abort.')
        return
    else
        disp('Wrong input.')
        return
    end
end

serialNumber = serialNumber(:).';

%Delete folders
query = "SELECT ""DataPath"" FROM "+databaseTableName+" WHERE ""SerialNumber"" in ("+...
    regexprep(num2str(serialNumber),'\s+',',')+")";
data = pgFetch(conn,query);
arrayfun(@deleteFolder, data.DataPath);

%Delete database enries
query = "DELETE FROM "+databaseTableName+" WHERE ""SerialNumber"" in ("+...
    regexprep(num2str(serialNumber),'\s+',',')+")";
execute(conn,query);

if isForceDelete ~= true
    disp('Trials are deleted.')
end
end

