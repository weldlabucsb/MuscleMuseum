function updateConfig(configName,t)
% Update a parameter table with provided rows.
%
% :param configName: Name of the :class:`MmParameter` subclass to update
% :type configName: string
% :param t: Rows to upsert into the table
% :type t: table or struct
para = eval(configName);
para.checkTable
para.updateTable(t,false)
end