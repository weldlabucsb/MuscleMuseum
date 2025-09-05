function obj = loadBecExp(serialNumber)
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
p = BecExpConfig;
databaseName = p.readValue(1,"DatabaseName");
databaseTableName = p.readValue(1,"DatabaseTableName");
conn = createReader(databaseName);
obj = loadTrial(conn,databaseTableName,serialNumber);
end

