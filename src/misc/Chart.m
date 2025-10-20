classdef Chart < handle
    %CHART Summary of this class goes here
    %   Detailed explanation goes here

    properties (SetAccess = protected)
        Name string
        Number double
        Path string
        Location
        Size
        IsGif logical = false
    end

    properties
        IsEnabled logical = true
        Monitor double = 1
    end

    properties (Transient)
        Figure matlab.ui.Figure
    end

    properties (Hidden)
        IsBrowser logical = false
    end

    properties (Constant,Hidden)
        NumberOffset = 1064
    end

    methods

        function obj = Chart(NameValueArgs)
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

