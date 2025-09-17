function [deepestTabs, tabLabels] = findDeepestTab(fig)
    % FINDDEEPESTTAB finds the deepest nested tabs in a figure and returns 
    % them as a tab array and their labels as a string array.
    
    deepestTabs = matlab.ui.container.Tab.empty;
    tabLabels = string.empty;
    maxDepth = -1;

    % --- NEW: Check for the existence of any tab groups in the figure ---
    % Find all tab groups anywhere in the figure hierarchy.
    allTabGroups = findall(fig, 'Type', 'uitabgroup');
    
    if isempty(allTabGroups)
        % If no tab groups exist, return empty arrays immediately.
        return;
    end
    % --- END OF NEW CHECK ---

    % Nested recursive helper function
    function findRecursive(parent, currentPath, currentDepth)
        
        % Find all uitabgroup objects that are direct children of the parent.
        childTabGroups = findall(parent.Children, 'Type', 'uitabgroup', '-depth', 1);

        if isempty(childTabGroups)
            % This is a deepest tab.
            if currentDepth > maxDepth
                maxDepth = currentDepth;
                % New deepest level, reset outputs
                deepestTabs = parent;
                tabLabels = currentPath;
            elseif currentDepth == maxDepth
                % Same deepest level, append to outputs
                deepestTabs(end+1) = parent;
                tabLabels(end+1) = currentPath;
            end
            return;
        end

        % We found a nested tab group, so we need to go deeper.
        tabs = childTabGroups.Children;
        tabs = flipud(tabs); % Process in creation order
        
        for i = 1:numel(tabs)
            tab = tabs(i);
            % Build the new path string.
            newPath = currentPath + "_" + string(tab.Title);
            
            % Recursively call the function on this tab object.
            findRecursive(tab, newPath, currentDepth + 1);
        end
    end

    % Start the recursion from the figure itself.
    findRecursive(fig, "", 0);

    % Post-process the labels to remove leading underscores.
    tabLabels = regexprep(tabLabels, '^_*', '');

end