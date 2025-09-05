classdef Gui < handle
    %:class:`Gui` lightweight wrapper to launch and place App Designer apps.
    %
    % Instantiates an app by name (via ``feval``), positions the UI figure
    % using preset strings or fractional coordinates/sizes, allows updating via
    % :meth:`update`, and manages lifecycle with :meth:`close`.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    g = Gui(name="MyApp", fpath="", loc=[0.1,0.1], size=[0.5,0.5]);
    %   g.initialize(42); % passes 42 as an argument to app constructor
    %    g.update();
    %    g.close();
    
    properties
        Name % App class name to instantiate (string)
        Path % Unused placeholder to keep interface symmetry with :class:`Chart`
        Location % UI position preset or [xFrac,yFrac]
        Size % UI size preset or [wFrac,hFrac]
        IsEnabled logical = true % Master switch to disable operations
        Monitor double = 1 % Target monitor index (1 is primary)
    end

    properties (Transient)
        App matlab.apps.AppBase
    end
    
    methods
        function obj = Gui(NameValueArgs)
            % Construct a :class:`Gui` from name-value arguments.
            %
            % :param name: App class name (callable via ``feval``)
            % :type name: string
            % :param fpath: Unused
            % :type fpath: string
            % :param loc: Location preset string or [xFrac,yFrac]
            % :type loc: string or double
            % :param size: Size preset string or [wFrac,hFrac]
            % :type size: string or double
            % :param isEnabled: If false, initialization is a no-op
            % :type isEnabled: logical optional
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
            % Instantiate the app and place its UI figure.
            %
            % Additional inputs are forwarded to the app constructor.
            %
            % :param varargin: Arguments passed to the app constructor
            % :type varargin: any optional
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
            % Call the app's ``update`` method if available.
            if obj.IsEnabled
                obj.App.update
            end
        end

        function close(obj)
            % Close and delete the app instance if valid.
            if ~isempty(obj.App)
                if isvalid(obj.App)
                    obj.App.delete
                end
            end
        end
    end
end

