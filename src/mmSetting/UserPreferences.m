classdef UserPreferences < MmSetting
    %USERPREFERENCES User preferences settings stored in SQLite database
    %   This class demonstrates how to create a MmSetting subclass for
    %   storing user preferences like theme, language, auto-save settings, etc.
    
    methods
        function obj = UserPreferences()
            % Define the table structure - column names and their MATLAB types
            obj.TableColumn = dictionary(...
                "PreferenceName", "string", ...      % Name of the preference
                "PreferenceValue", "string", ...     % Value of the preference
                "PreferenceType", "string", ...      % Type: string, logical, double
                "Category", "string", ...            % Category: UI, Analysis, Hardware
                "Description", "string", ...         % Description of the preference
                "LastModified", "string", ...        % When it was last modified
                "IsDefault", "logical" ...           % Whether this is a default value
            );
            
            % Define default values for each column (used when adding new columns)
            obj.DefaultValue = dictionary(...
                "PreferenceName", "default", ...
                "PreferenceValue", "default_value", ...
                "PreferenceType", "string", ...
                "Category", "General", ...
                "Description", "Default preference", ...
                "LastModified", "asdfasd", ...
                "IsDefault", true ...
            );
            
            % Define default entries for initial table setup
            obj.DefaultEntry = table(...
                ["Theme"; "Language"; "AutoSave"; "DefaultROI"; "AnalysisMethod"], ...
                ["Dark"; "English"; "true"; "Full"; "Standard"], ...
                ["string"; "string"; "logical"; "string"; "string"], ...
                ["UI"; "UI"; "General"; "Analysis"; "Analysis"], ...
                ["Application theme (Light/Dark)"; "Interface language"; "Auto-save data"; "Default ROI selection"; "Default analysis method"], ...
                ["Asdf1"; "Asdf2"; "Asdf4"; "Asdf5"; "Asdf"], ...
                [true; true; true; true; true], ...
                'VariableNames', ["PreferenceName", "PreferenceValue", "PreferenceType", "Category", "Description", "LastModified", "IsDefault"] ...
            );
        end
        
        function setPreference(obj, name, value, category, description)
            % Set a user preference
            % Inputs:
            %   name - preference name
            %   value - preference value (will be converted to string)
            %   category - category of the preference
            %   description - description of the preference
            
            % Determine the type
            if islogical(value)
                prefType = "logical";
                value = string(value);
            elseif isnumeric(value)
                prefType = "double";
                value = string(value);
            else
                prefType = "string";
                value = string(value);
            end
            
            % Create the data row
            newData = table(...
                string(name), ...
                string(value), ...
                string(prefType), ...
                string(category), ...
                string(description), ...
                string(datestr(now)), ...
                false, ...
                'VariableNames', ["PreferenceName", "PreferenceValue", "PreferenceType", "Category", "Description", "LastModified", "IsDefault"] ...
            );
            
            % Check if preference already exists
            existingData = obj.readTable();
            if ~isempty(existingData)
                existingIdx = find(existingData.PreferenceName == name);
                if ~isempty(existingIdx)
                    % Update existing preference
                    existingData.PreferenceValue(existingIdx) = value;
                    existingData.PreferenceType(existingIdx) = prefType;
                    existingData.Category(existingIdx) = category;
                    existingData.Description(existingIdx) = description;
                    existingData.LastModified(existingIdx) = datestr(now);
                    existingData.IsDefault(existingIdx) = false;
                    
                    % Delete old entry and write updated one
                    obj.deletePreference(name);
                    obj.writeRow(existingData(existingIdx, :));
                    return;
                end
            end
            
            % Write new preference
            obj.writeRow(newData);
        end
        
        function value = getPreference(obj, name, defaultValue)
            % Get a user preference
            % Inputs:
            %   name - preference name
            %   defaultValue - default value if preference doesn't exist
            % Output:
            %   value - preference value (converted to appropriate type)
            
            if nargin < 3
                defaultValue = [];
            end
            
            data = obj.readTable();
            if isempty(data)
                value = defaultValue;
                return;
            end
            
            idx = find(data.PreferenceName == name);
            if isempty(idx)
                value = defaultValue;
                return;
            end
            
            % Get the value and convert to appropriate type
            valueStr = data.PreferenceValue(idx);
            valueType = data.PreferenceType(idx);
            
            switch valueType
                case "logical"
                    if strcmpi(valueStr, "true")
                        value = true;
                    elseif strcmpi(valueStr, "false")
                        value = false;
                    else
                        value = logical(str2double(valueStr));
                    end
                case "double"
                    value = str2double(valueStr);
                otherwise
                    value = valueStr;
            end
        end
        
        function deletePreference(obj, name)
            % Delete a user preference
            % Inputs:
            %   name - preference name to delete
            
            conn = sqlite(which(obj.DataBaseName), "connect");
            sqlquery = "DELETE FROM " + obj.TableName + " WHERE PreferenceName = '" + name + "';";
            execute(conn, sqlquery);
            close(conn);
        end
        
        function preferences = getPreferencesByCategory(obj, category)
            % Get all preferences in a specific category
            % Inputs:
            %   category - category name
            % Output:
            %   preferences - table of preferences in that category
            
            conn = sqlite(which(obj.DataBaseName), "readonly");
            sqlquery = "SELECT * FROM " + obj.TableName + " WHERE Category = '" + category + "';";
            preferences = fetch(conn, sqlquery);
            preferences = obj.convertOutput(preferences);
            close(conn);
        end
        
        function resetToDefaults(obj)
            % Reset all preferences to their default values
            
            % Delete all non-default preferences
            conn = sqlite(which(obj.DataBaseName), "connect");
            sqlquery = "DELETE FROM " + obj.TableName + " WHERE IsDefault = 0;";
            execute(conn, sqlquery);
            close(conn);
            
            % Re-insert default entries
            obj.writeRow(obj.DefaultEntry);
        end
    end
end 