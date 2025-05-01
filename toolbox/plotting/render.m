function render(fig,para)
% MATLAB code to make nice figures.

%% Read figure.
if nargin == 0
    fig = gcf;
end
movegui(fig,'center')
ax = fig.CurrentAxes;
set(fig,'Position','default')
set(ax,'OuterPosition','default')

%% Set parameters.
if nargin == 2
    width = para.width;
    height = para.height;
    fsz = para.fsz;
    lw = para.lw;
    msz = para.msz;
    isShowTick = para.isShowTick;
    isShowLabel = para.isShowLabel;
    isShowTitle = para.isShowTitle;
    isShowColorbar = para.isShowColorbar;
    colorbarLocation = para.colorbarLocation;
else
    width = 6; % Width in inches.
    height = width*2/3; % Height in inches.
    fsz = 12/0.8; % Fontsize.
    lw = 2; % LineWidth.
    msz = 8; % MarkerSize.
    isShowTick = [1 1];
    isShowLabel = [1 1];
    isShowTitle = 1;
    isShowColorbar = 1;
    colorbarLocation = 'eastoutside';
end

markers = {'o','^','x','s','d','*','+','v'};
colors = {[0,110,191]/255,[196,0,110]/255,[72,31,205]/255,[205,113,31]/255,...
    [0.4660, 0.6740, 0.1880],[0.6350, 0.0780, 0.1840],[0.9290, 0.6940, 0.1250],...
    [0.8500, 0.3250, 0.0980]};
linestyles = {'-','--',':','-.','-','--',':','-.'};

%% Remove labels
if ~isShowTitle
    ax.Title = [];
end
if ~isShowTick(1)
    ax.XTickLabel = [];
end
if ~isShowTick(2)
    ax.YTickLabel = [];
end
if ~isShowLabel(1)
    ax.XLabel = [];
end
if ~isShowLabel(2)
    ax.YLabel = [];
end

%% Put colarbar
cb = findobj(fig,'Type','colorbar');
if ~isShowColorbar
    delete(cb)
elseif ~isempty(cb)
    cb.Location = colorbarLocation;
end

%% Set sizes.
pos = fig.Position;
fig.Position = [pos(1),pos(2),width*96,height*96]; %set figure size
fig.Color = 'w'; % set background to white

%% Set linewidth.
ax.LineWidth = lw;
p = findobj(fig,'Type','line');
eb = findobj(fig,'Type','errorbar');
for ii = 1:numel(p)
    p(ii).LineWidth = lw;
end

for ii = 1:numel(eb)
    eb(ii).LineWidth = lw;
end

%% Set linespecs.
co=get(gca,'colororder');
nCo = size(co,1);
p = flip(p);
for ii = 1:numel(p)
    if p(ii).LineStyle == "none"
        p(ii).Marker = markers{ii};
        p(ii).MarkerSize = msz;
        % p(ii).Color = colors{numel(p)-ii+1};
        p(ii).Color = co(mod(ii-1,nCo)+1,:);
    elseif p(ii).Marker == "none"
        % if numel(p)<=4
            % p(ii).Color = colors{numel(p)-ii+1};
        if numel(p)<=nCo
            co=get(gca,'colororder');
            p(ii).Color = co(ii,:);
%             p(ii).LineStyle = linestyles{ii};
%             p(ii).Color = 'k';
        else
            co=get(gca,'colororder');
            p(ii).Color = co(mod(ii-1,nCo)+1,:);
            p(ii).LineStyle = linestyles{ceil(ii/nCo)};
        end
    else
        p(ii).Marker = markers{ii};
        % p(ii).Color = colors{numel(p)-ii+1};
        p(ii).Color = co(mod(ii-1,nCo)+1,:);
        p(ii).MarkerSize = msz;
    end
end

% ii0 = ii+1;

for ii = 1:numel(eb)
    if eb(ii).LineStyle == "none"
        eb(ii).Marker = markers{ii};
        eb(ii).MarkerSize = msz;
        eb(ii).Color = colors{ii};
    elseif eb(ii).Marker == "none"
        if numel(eb)>5
            p(ii).Color = 'k';
        else
            eb(ii).LineStyle = linestyles{ii};
            eb(ii).Color = 'k';
        end
    else
        eb(ii).Marker = markers{ii};
        eb(ii).Color = colors{ii};
        eb(ii).MarkerSize = msz;
    end
end

%% Set fontsize.
% ax.FontSizeMode = "Fixed"
ax.FontSize = fsz;
ax.Title.FontSize = 15;

%% Set interpreters
if ~isempty(ax.XLabel)
    if strfind(ax.XLabel.String,'$')
        ax.XLabel.Interpreter = 'latex';
    end
end
if ~isempty(ax.YLabel)
    if strfind(ax.YLabel.String,'$')
        ax.YLabel.Interpreter = 'latex';
    end
end
if ~isempty(ax.Legend)
    if strfind(ax.Legend.String{1},'$')
        ax.Legend.Interpreter = 'latex';
        ax.Legend.Location = 'best';
    end
end

%% Remove margin
outerpos = ax.OuterPosition;
ti = ax.TightInset;
left = outerpos(1) + ti(1);
bottom = outerpos(2) + ti(2);
cb = findobj(fig,'Type','colorbar');
ax_width = outerpos(3) - ti(1) - ti(3);
ax_height = outerpos(4) - ti(2) - ti(4);
cbWidth = 0.05;
cbHeight = 0.04;
if ~isempty(cb)
    %     ax_height = min(ax_height,cb.Position(4));
    ax_width = ax_width - cbWidth;
    if ~isShowLabel(1)
        ax_height = ax_height - cbHeight*2;
        bottom = bottom + cbHeight;
    else
        ax_height = ax_height - 0.01;
    end
elseif ~isShowLabel(1)
    ax_height = ax_height - 0.02;
    bottom = bottom + 0.02; 
end
ax_width = ax_width-0.02;
% left = left + 0.02;
ax_height = ax_height - 0.01;
bottom = bottom + 0.01;
ax.Position = [left bottom ax_width ax_height];

end

