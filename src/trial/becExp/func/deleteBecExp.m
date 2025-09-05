function deleteBecExp(serialNumber,isForceDelete)
% Delete a :class:`BecExp` trial from the database (and optionally files).
%
% Removes the database entry for a given trial serial number. When
% ``isForceDelete`` is true, also deletes associated folders/files as
% defined by the trial deletion routine.
%
% :param serialNumber: Trial serial identifier
% :type serialNumber: double|string
% :param isForceDelete: Also remove associated files/folders (default: false)
% :type isForceDelete: logical, optional
%
% **Example:**
%
% .. code-block:: matlab
%
%    deleteBecExp(1234, true);
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

