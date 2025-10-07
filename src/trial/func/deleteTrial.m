function deleteTrial(conn,databaseTableName,serialNumber,isForceDelete)
% Delete trial folders and database rows for given serial numbers.
%
% Removes both the file system directories and database entries for the
% specified trials. Prompts for confirmation unless forced deletion is enabled.
%
% :param conn: Open PostgreSQL database connection
% :type conn: database.postgre.connection
% :param databaseTableName: Database table name containing trial records
% :type databaseTableName: string
% :param serialNumber: Trial serial numbers to delete (can be array)
% :type serialNumber: double
% :param isForceDelete: Skip interactive confirmation if true (default: false)
% :type isForceDelete: logical, optional
%
% **Example:**
%
% .. code-block:: matlab
%
%    conn = createWriter("myDatabase");
%    deleteTrial(conn, "BecExpTrial", [1234, 1235], true);
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

