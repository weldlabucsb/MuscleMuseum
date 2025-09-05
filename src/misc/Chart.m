classdef Chart < handle
    % :class:`Chart` utility to create, position, show, and save figures.
    %
    % Manages figure creation across multiple monitors, supports logical
    % positioning and sizing (fractions or presets), and saving to ``.fig``
    % /``.png`` or opening a ``.gif`` instead when :attr:`IsGif` is true.
    %
    % **Examples:**
    %
    % .. code-block:: matlab
    %
    %    ch = Chart(name="Spectrum", num=2, fpath="C:/tmp/spectrum", ...
    %               loc=[0.05,0.1], size=[0.5,0.4], isGif=false);
    %    fig = ch.initialize();
    %    plot(rand(100,1)); drawnow;
    %    ch.save();
    %    ch.close();

    properties (SetAccess = protected)
        Name string % Human-readable figure name (window title)
        Number double % Figure number/ID (used for reuse)
        Path string % File path without extension for saving/reading
        Location % Logical location [xFrac,yFrac] or preset string (e.g. "eastnorthwest")
        Size % Logical size [wFrac,hFrac] or preset string: "small","medium","large","largetall","full"
        IsGif logical = false % If true, treat target as GIF and open it via :meth:`showGif`
    end

    properties
        IsEnabled logical = true % Master switch to disable all operations
        Monitor double = 1 % Target monitor index (1 is primary)
    end

    properties (Transient)
        Figure matlab.ui.Figure % Handle to the managed figure (created in :meth:`initialize`)
    end

    properties (Hidden)
        IsBrowser logical = false % Use browser-mode numbering offset when true
    end

    properties (Constant,Hidden)
        NumberOffset = 1064 % Offset added to figure number in browser mode
    end

    methods

        function obj = Chart(NameValueArgs)
            % Construct a :class:`Chart` from name-value arguments.
            %
            % :param name: Figure window title
            % :type name: string
            % :param num: Figure number/ID
            % :type num: double
            % :param fpath: Save/load path without extension
            % :type fpath: string
            % :param loc: Location preset string or [xFrac,yFrac] in (0,1)
            % :type loc: string or double
            % :param size: Size preset string or [wFrac,hFrac] in (0,1)
            % :type size: string or double
            % :param isGif: Treat target as GIF for :meth:`showGif`
            % :type isGif: logical optional
            % :param isEnabled: If false, all operations are no-ops
            % :type isEnabled: logical optional
            arguments
                NameValueArgs.name
                NameValueArgs.num
                NameValueArgs.fpath
                NameValueArgs.loc
                NameValueArgs.size
                NameValueArgs.isGif logical = false
                NameValueArgs.isEnabled logical = true
            end
            obj.Name = NameValueArgs.name;
            obj.Number = NameValueArgs.num;
            obj.Path = NameValueArgs.fpath;
            obj.Location = NameValueArgs.loc;
            obj.Size = NameValueArgs.size;
            obj.IsGif = NameValueArgs.isGif;
            obj.IsEnabled = NameValueArgs.isEnabled;
        end

        function fig = initialize(obj)
            % Create or reuse the figure, position and size it, and return its handle.
            %
            % Uses monitor geometry from ``sortMonitor`` and supports both preset
            % strings and fractional coordinates/sizes in (0,1).
            %
            % :returns: fig — Figure handle; if :attr:`IsEnabled` is false returns ``{1}``.
            % :rtype: matlab.ui.Figure or cell
            if ~obj.IsEnabled
                fig = {1};
                return
            end
            
            if ~obj.IsBrowser
                obj.Figure = figure(obj.Number);
            else
                obj.Figure = figure(obj.Number + obj.NumberOffset);
            end
            clf(obj.Figure);
            obj.Figure.Visible = 'off';

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
                obj.Figure.OuterPosition = [200,600,fWidth,fHeight];
                movegui(obj.Figure,loc);
            else
                obj.Figure.OuterPosition = [loc,fWidth,fHeight];
            end

            obj.Figure.NumberTitle = "off";
            obj.Figure.ToolBar = "figure";
            obj.Figure.MenuBar = "none";
            obj.Figure.Name = obj.Name;
            fig = obj.Figure;
            if obj.Monitor > 1 && obj.Monitor <= size(mp,1)
                pause(0.02) % This is somehow critical
                fig.OuterPosition = ...
                    [fig.OuterPosition(1:2)./ss(3:4).*mp(obj.Monitor,3:4) + mp(obj.Monitor,1:2),...
                    fig.OuterPosition(3:4)./ss(3:4).*mp(obj.Monitor,3:4)];
            end
            obj.Figure.Visible = 'on';
        end

        function save(obj)
            % Save figure to ``.fig`` (if size is reasonable) and ``.png``.
            %
            % Checks existence and image data size to avoid extremely large
            % ``.fig`` files, then writes PNG unconditionally.
            if ~obj.IsEnabled
                return
            end

            if ~obj.IsGif
                % Check if figure is valid
                if isempty(obj.Figure) || ~isvalid(obj.Figure)
                    warning("Figure [" + obj.Name+"]" + " was not found." + ...
                        " It might have been closed.")
                    return
                end
                % Check if image is too large
                img = findobj(obj.Figure,'type','image');
                nEle = 0;
                for ii = 1:numel(img)
                    nEle = nEle + numel(img.CData);
                end

                if nEle < 0.5*10^9
                    saveas(obj.Figure,obj.Path,'fig')
                else
                    warning("Image size too large. " + ...
                        "Figure [" + obj.Name+"]" + " was not saved as .fig")
                end
                saveas(obj.Figure,obj.Path,'png')
            end
        end

        function show(obj)
            % Show a previously saved ``.fig`` in a managed figure window.
            %
            % Creates the window via :meth:`initialize` and clones the saved
            % content using ``copyobj`` if the figure file exists.
            if ~obj.IsEnabled
                return
            end

            if ~obj.IsGif
                figPath = obj.Path + ".fig";
                if isfile(figPath)
                    fig = obj.initialize;
                    src = openfig(figPath,"invisible");
                    warning off
                    copyobj(allchild(src),fig)
                    warning on
                end
            end
        end

        function showGif(obj)
            % Open the target ``.gif`` in the system viewer when :attr:`IsGif` is true.
            if ~obj.IsEnabled
                return
            end
            if obj.IsGif
                gifPath = obj.Path + ".gif";
                if isfile(gifPath)
                    winopen(gifPath)
                end
            end
        end
    
        function close(obj)
            % Close the managed figure window if it exists.
            if ~obj.IsEnabled
                return
            end

            if ~obj.IsGif
                if ~obj.IsBrowser
                    close(figure(obj.Number))
                else
                    close(figure(obj.Number + obj.NumberOffset))
                end
            end
        end
    end
end

