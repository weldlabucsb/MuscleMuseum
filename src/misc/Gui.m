classdef Gui < handle
    %GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name
        Path
        Location
        Size
        IsEnabled logical = true
        Monitor double = 1
    end

    properties (Transient)
        App matlab.apps.AppBase
    end
    
    methods
        function obj = Gui(NameValueArgs)
            %GUI Construct an instance of this class
            %   Detailed explanation goes here
            arguments
                NameValueArgs.name
                NameValueArgs.fpath
                NameValueArgs.loc
                NameValueArgs.size
                NameValueArgs.isEnabled logical = true
            end
            obj.Name = NameValueArgs.name;
            obj.Path = NameValueArgs.fpath;
            obj.Location = NameValueArgs.loc;
            obj.Size = NameValueArgs.size;
            obj.IsEnabled = NameValueArgs.isEnabled;
        end
        
        function initialize(obj,varargin)
            if ~obj.IsEnabled
                return
            end

            obj.close
            % allfigs = findall(0,'Type','figure'); 
            % app2Handle = findall(allfigs, 'Name', obj.Name);
            % close(app2Handle)
            % try
                obj.App = feval(obj.Name,varargin{:});
            % catch
                % obj.App = eval(obj.Name);
            % end

            obj.App.UIFigure.Visible = 'off';
            mp = sortMonitor;
            ss = mp(1,:);

            if isstring(obj.Size)
                switch obj.Size
                    case "small"
                        fWidth = ss(3)/4.1;
                        fHeight = ss(4)/2.1;
                    case "medium"
                        fWidth = ss(3)/3.1;
                        fHeight = ss(4)/2.1;
                    case "large"
                        fWidth = ss(3)/3.1 * 1.5;
                        fHeight = ss(4)/2.1 *1.5;
                    case "largetall"
                        fWidth = ss(3)/3.1 * 1.5;
                        fHeight = ss(4)/1.1;
                    case "full"
                        fWidth = ss(3)/1.1;
                        fHeight = ss(4)/1.1;
                end
            else
                fWidth = obj.Size(1) * ss(3);
                fHeight = obj.Size(2) * ss(4);
            end

            if isstring(obj.Location)
                switch obj.Location
                    case "eastnorthwest"
                        loc = [ss(3)/2,-1];
                    otherwise
                        loc = obj.Location;
                end
            else
                loc = [obj.Location(1) * ss(3),obj.Location(2) * ss(4)];
            end

            if isstring(loc)
                obj.App.UIFigure.Position = [200,600,fWidth,fHeight];
                movegui(obj.App.UIFigure,loc);
            else
                obj.App.UIFigure.Position = [loc,fWidth,fHeight];
            end

            obj.App.UIFigure.Name = obj.Name;
            if obj.Monitor > 1 && obj.Monitor <= size(mp,1)
                pause(0.02) % This is somehow critical
                obj.App.UIFigure.Position = ...
                    [obj.App.UIFigure.Position(1:2)./ss(3:4).*mp(obj.Monitor,3:4) + mp(obj.Monitor,1:2),...
                    obj.App.UIFigure.Position(3:4)./ss(3:4).*mp(obj.Monitor,3:4)];
            end
            obj.App.UIFigure.Visible = 'on';
        end

        function update(obj)
            if obj.IsEnabled
                obj.App.update
            end
        end

        function close(obj)
            if ~isempty(obj.App)
                if isvalid(obj.App)
                    obj.App.delete
                end
            end
        end
    end
end

