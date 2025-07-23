conn = sqlite("test.db");
tablename = "toyTable";
data = table([1;23]);
sqlwrite(conn,tablename,data,ColumnType="numeric")