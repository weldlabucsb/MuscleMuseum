classdef logger < handle
    
    properties
        LogFile string          % Path to the log file
        WriteToConsole = false  % Boolean: Print to command window?
        MinLevel                % Minimum level to log
    end
    
    properties (Constant)
        % Log Levels
        DEBUG = 0
        INFO  = 1
        WARN  = 2
        ERROR = 3
    end
    
    methods
        function obj = logger(logFile, minLevel)
            
            if nargin > 0
                obj.LogFile = logFile;
            end
            
            if nargin > 1
                obj.MinLevel = minLevel;
            else
                obj.MinLevel = obj.INFO; % Default to INFO
            end
        end
        
        function debug(obj, msg, varargin)
            obj.write(obj.DEBUG, 'D', msg, varargin{:});
        end
        
        function info(obj, msg, varargin)
            obj.write(obj.INFO, 'I', msg, varargin{:});
        end
        
        function warn(obj, msg, varargin)
            obj.write(obj.WARN, 'W', msg, varargin{:});
        end
        
        function error(obj, msg, varargin)
            obj.write(obj.ERROR, 'E', msg, varargin{:});
        end
    end
    
    methods (Access = private)
        function write(obj, level, levelStr, msg, varargin)
            if level < obj.MinLevel
                return;
            end
            
            if ~isempty(varargin)
                formattedMsg = sprintf(msg, varargin{:});
            else
                formattedMsg = msg;
            end
            
            timestamp = datestr(now, 'HHMMSS');
            
            logLine = sprintf('%s|%s|%s', timestamp, levelStr, formattedMsg);
            
            if obj.WriteToConsole
                fprintf('%s\n', logLine);
            end
            
            if ~isempty(obj.LogFile) && strlength(obj.LogFile) > 0
                try
                    fid = fopen(obj.LogFile, 'a');
                    if fid ~= -1
                        fprintf(fid, '%s\n', logLine);
                        fclose(fid);
                    end
                catch ME
                    % If file writing fails, don't crash app, just warn console
                    fprintf(2, 'Logger Warning: Could not write to file. %s\n', ME.message);
                end
            end
        end
    end
end