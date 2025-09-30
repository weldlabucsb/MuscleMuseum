function obj = loadBecExp(serialNumber,isLocal)
% Load a :class:`BecExp` trial from the database by serial number.
%
% Retrieves configuration and state from the configured database and
% reconstructs the :class:`BecExp` object using the generic trial loader.
%
% :param serialNumber: Trial serial identifier
% :type serialNumber: double|string
% :return: Loaded :class:`BecExp` object
% :rtype: :class:`BecExp`
%
% **Example:**
%
% .. code-block:: matlab
%
%    bx = loadBecExp(1234);
%    bx.refresh();
arguments
    serialNumber
    isLocal logical = false
end
if isLocal
    rowIdx = 2;
else
    rowIdx = 1;
end
p = BecExpConfig;
databaseName = p.readValue(rowIdx,"DatabaseName");
databaseTableName = p.readValue(rowIdx,"DatabaseTableName");
conn = createReader(databaseName);
obj = loadTrial(conn,databaseTableName,serialNumber);
end

