conn = sqlite("test.db");


createInventoryTable = strcat("CREATE TABLE inventoryTable5 ", ...
    "(productNumber NUMERIC, Quantity NUMERIC, ", ...
    "Price NUMERIC, inventoryDate TEXT)");
execute(conn,createInventoryTable)
% sqlwrite(conn,tablename,data,ColumnType="numeric")