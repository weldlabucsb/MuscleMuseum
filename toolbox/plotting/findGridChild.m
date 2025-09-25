function obj = findGridChild(g,rowToFind,columnToFind)
for k = 1:numel(g.Children)
    child = g.Children(k);
    layout = child.Layout;
    row = layout.Row;
    col = layout.Column;
    if any(row == rowToFind) && any(col == columnToFind)
        obj = child;
        break;
    end
end
end

