classdef UserPreferences < MmSetting
    %:class:`UserPreferences` stores user preferences using the :class:`MmSetting` SQLite backend.
    %
    % Defines a schema for user-configurable preferences (e.g., theme, language,
    % auto-save) and provides helper APIs to set, get, list, and reset values.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    prefs = :class:`UserPreferences`();
    %    prefs.checkTable();
    %    prefs.setPreference("Theme","Dark","UI","Application theme");
    %    theme = prefs.getPreference("Theme","Light");
    %
    % **Notes:**
    %
    %     This class is a concrete :class:`MmSetting` schema; call :meth:`checkTable` after
    %     construction to ensure the SQLite table exists and is up to date.
    %
    methods
        function obj = UserPreferences()
            % Construct :class:`UserPreferences` and define the table schema.
            %
            % The schema includes name, value, type, category, description,
            % last modified time string, and a boolean indicating default entries.
            % Define the table structure - column names and their MATLAB types (see :attr:`TableColumn`)
            obj.TableColumn = dictionary(...
                "PreferenceName", "string", ...      % Name of the preference
                "PreferenceValue", "string", ...     % Value of the preference
                "PreferenceType", "string", ...      % Type: string, logical, double
                "Description", "string", ...         % Description of the preference
                "LastModified", "stringMatrix", ...        % When it was last modified
                "IsDefault", "doubleMatrix", ...           % Whether this is a default value
                "IsTrue", "logical" ...           % Whether this is a default value
            );
            
            % Define default values for each column (used when adding new columns) via :attr:`DefaultValue`
            obj.DefaultValue = dictionary(...
                "PreferenceName", "default", ...
                "PreferenceValue", "default_value", ...
                "PreferenceType", "string", ...
                "Description", "Default preference", ...
                "LastModified", "asdfasd", ...
                "IsDefault", 1, ...
                "IsTrue", true ...
            );
            
            % Define default entries for initial table setup in :attr:`DefaultEntry`
            obj.DefaultEntry = table(...
                ["Theme"; "Language"; "AutoSave"; "DefaultROI"; "AnalysisMethod"], ...
                ["Dark"; "English"; "true"; "Full"; "Standard"], ...
                ["string"; "string"; "logical"; "string"; "string"], ...
                ["Application theme (Light/Dark)"; "Interface language"; "Auto-save data"; "Default ROI selection"; "Default analysis method"], ...
                {"Asdf1"; "Asdf2"; "Asdf4"; "Asdf5"; "Asdf"}, ...
                {1; 1; 1; 1; [2]}, ...
                [true;true;true;true;true],...
                'VariableNames', ["PreferenceName", "PreferenceValue", "PreferenceType", "Description", "LastModified", "IsDefault","IsTrue"] ...
            );
        end
        
        function setPreference(obj, name, value, category, description)
            % Set a user preference, creating or updating an entry.
            %
            % :param name: Preference name (unique key)
            % :type name: string
            % :param value: Preference value (converted to string for storage)
            % :type value: string | logical | double | char
            % :param category: Category label, e.g., "UI", "General", "Analysis"
            % :type category: string
            % :param description: Human-readable description
            % :type description: string
            
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
            % Get a preference value with optional default fallback.
            %
            % :param name: Preference name
            % :type name: string
            % :param defaultValue: Default value returned if preference not found
            % :type defaultValue: any
            % :return: Preference value converted to its declared type
            % :rtype: string | double | logical
            
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
            % Delete a preference by name.
            %
            % :param name: Preference name to delete
            % :type name: string
            
            conn = sqlite(which(obj.DataBaseName), "connect");
            sqlquery = "DELETE FROM " + obj.TableName + " WHERE PreferenceName = '" + name + "';";
            execute(conn, sqlquery);
            close(conn);
        end
        
        function preferences = getPreferencesByCategory(obj, category)
            % Get all preferences within a given category.
            %
            % :param category: Category name to filter by
            % :type category: string
            % :return: Table of matching preferences
            % :rtype: table
            
            conn = sqlite(which(obj.DataBaseName), "readonly");
            sqlquery = "SELECT * FROM " + obj.TableName + " WHERE Category = '" + category + "';";
            preferences = fetch(conn, sqlquery);
            preferences = obj.convertOutput(preferences);
            close(conn);
        end
        
        function resetToDefaults(obj)
            % Reset all user preferences to default values.
            %
            % Deletes non-default entries and re-inserts default rows from :attr:`DefaultEntry`.
            
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