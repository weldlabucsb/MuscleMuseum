function files = renderAdGif2D(adData,var1List,var2List,opts)
%RENDERADGIF2D Animated GIF(s) for a 2D scan: one row of ROI tiles per frame.
%
%   files = renderAdGif2D(adData,var1List,var2List,Name,Value,...)
%
%   Generalized, non-experiment-specific port of external Kapitza 2D gif generation. 
%   The ROI size/shape comes entirely from adData's own [r,c] dimensions, which the 
%   caller (Ad.m) already crops to the trial's ROI (or further crops for "Zoom" mode) 
%   — nothing here re-crops or re-shapes it.
%
%   Sizing policy (for GifMode "TrialRoi"): the image footprint is computed
%   directly from the trial ROI's pixel dimensions and aspect ratio. Height is bounded 
%   to the range [MinHeight, MaxHeight] to avoid overly tall or short figures. If that's
%   the case, width and height are both rescaled together. 

%   GIF speed can also be adjusted by varying "Speed", default is 1. 

%   Required inputs:
%       adData     [r,c,nRun] stack of per-run ROI images (already in
%                  desired display units, e.g. divided by Ad.Unit)
%       var1List   1 x nRun, scan variable 1 value for each run
%       var2List   1 x nRun, scan variable 2 value for each run
%
%   Name-Value options:
%       Var1Name,Var1Unit    label/unit for scan variable 1  ("Var1","")
%       Var2Name,Var2Unit    label/unit for scan variable 2  ("Var2","")
%       SweepVar             "both"|"var1"|"var2"            ("both")
%                             (SweepVar is the axis that CHANGES
%                              from frame to frame; the other var is tiled as
%                              a row within each frame)
%       OutputFolder         folder for the .gif file(s)     (pwd)
%       BaseName             filename stem, direction suffix appended (AdAnimation)
%       Speed                playback speed multiplier       (1)
%       CLim                 color axis limits               ([0,8])
%       Colormap             colormap                        (jet)
%       ColorbarLabel        colorbar label string (LaTeX ok) ("")
%       TitleStem            fixed part of the title, e.g. "TrialName: X, Trial #123" ("")
%       FontSize             base font size (title/axis labels)  (13)
%       TickFontSize         x-tick label font size ([] = auto, smaller
%                             than FontSize, shrinks further as nRow grows)
%       MaxTiles             max labeled ticks before thinning (12)
%       ImageWidth           target image width in pixels     (900)
%       MinHeight            minimum image height in pixels    (160)
%       MaxHeight            maximum image height in pixels    (560)
%       ScanPanelFcn         (reserved) function handle hook for a future
%                            bottom panel that tracks scan variables frame
%                            by frame; not used in Phase 1.               ([])
%
%   Returns:
%       files   string array of GIF file paths written

arguments
    adData double
    var1List double
    var2List double
    opts.Var1Name (1,1) string = "Var1"
    opts.Var1Unit (1,1) string = ""
    opts.Var2Name (1,1) string = "Var2"
    opts.Var2Unit (1,1) string = ""
    opts.SweepVar (1,1) string {mustBeMember(opts.SweepVar,["both","var1","var2"])} = "both"
    opts.OutputFolder (1,1) string = pwd
    opts.BaseName (1,1) string = "AdAnimation"
    opts.Speed (1,1) double {mustBePositive} = 1
    opts.CLim (1,2) double = [0,8]
    opts.Colormap = jet
    opts.ColorbarLabel (1,1) string = ""
    opts.TitleStem (1,1) string = ""
    opts.FontSize (1,1) double = 13
    opts.TickFontSize double = []
    opts.MaxTiles (1,1) double = 12
    opts.ImageWidth (1,1) double = 900
    opts.MinHeight (1,1) double = 160
    opts.MaxHeight (1,1) double = 560
    opts.ScanPanelFcn = [] % reserved for future frame-by-frame scan panel
end

%% Average repeats and sort both axes (reuses existing MM utility)
[v1,v2,adData4] = computeAveErr2D(var1List,var2List,adData,"None");
% adData4 dims: [r,c,n2,n1]  (dim3 <-> var2/v2, dim4 <-> var1/v1)

files = strings(0,1);

if opts.SweepVar == "both" || opts.SweepVar == "var2"
    % Row = var1 (tiled), animate over var2 (frame-to-frame)
    f = localBuildGif(adData4,v1,opts.Var1Name,opts.Var1Unit, ...
        v2,opts.Var2Name,opts.Var2Unit,"var1row",opts);
    files(end+1,1) = f; %#ok<AGROW>
end

if opts.SweepVar == "both" || opts.SweepVar == "var1"
    % Row = var2 (tiled), animate over var1
    adData4Perm = permute(adData4,[1 2 4 3]); % swap dim3<->dim4
    f = localBuildGif(adData4Perm,v2,opts.Var2Name,opts.Var2Unit, ...
        v1,opts.Var1Name,opts.Var1Unit,"var2row",opts);
    files(end+1,1) = f; %#ok<AGROW>
end
end

%% ------------------------------------------------------------------
function file = localBuildGif(adData4,rowVals,rowName,rowUnit,sweepVals,sweepName,sweepUnit,tag,opts)
% adData4 dims: [r,c,nSweep,nRow]

[r,c,nSweep,nRow] = size(adData4);

% Escape underscores (and other LaTeX-special chars) in variable names so
% "hw_KPModFreq" doesn't get parsed as "hw" + subscript "K".
rowName   = localLatexEscape(rowName);
sweepName = localLatexEscape(sweepName);
rowUnit   = localLatexEscape(rowUnit);
sweepUnit = localLatexEscape(sweepUnit);

fs = opts.FontSize;

% Tick labels are the thing that overlaps as nRow grows, so they get their
% own (smaller) font, independent of the title/axis-label font, and are
% rotated 45 deg so their footprint along x shrinks to ~cos(45)+sin(45)
% times the glyph box instead of the full label width. Shrinks further as
% more tiles are shown, with a legibility floor.
if isempty(opts.TickFontSize)
    tickFs = fs - 3 - floor(nRow/6);
    tickFs = max(6,tickFs);
else
    tickFs = opts.TickFontSize;
end
tickRotation = 45;

%% ---- image footprint: sized to the TRUE data aspect (kpAdFigure) -------
% W,H start from the true [r x c*nRow] pixel aspect ratio, exactly as
% kpAdFigure computes it for the tile row.
W = opts.ImageWidth;
H = W * r / (c*nRow);

if H > opts.MaxHeight
    % Few/wide tiles: rescale W and H TOGETHER so the true aspect ratio is
    % preserved exactly (never stretched) — just displayed smaller.
    W = opts.MaxHeight * (c*nRow) / r;
    H = opts.MaxHeight;
elseif H < opts.MinHeight
    % Many/narrow tiles or a tall-skinny ROI: stretch ONLY the vertical
    % scale to stay legible. Width is never touched here, so tile width
    % (and therefore label spacing) is preserved.
    H = opts.MinHeight;
end

%% ---- margins (ported from kpAdFigure) ----------------------------------
marL = 5.0*fs + 26;                  % y label + tick labels
marR = 22 + 24 + 4.6*fs;             % colorbar + gap + label
marT = 18 + round(1.9*fs*2);         % 2-line title (TrialName/Trial#, sweep value)
% Rotated labels need vertical room for their diagonal projection: approx
% (max label length in chars) * glyph width * sin(45deg), plus the glyph
% height itself, plus the x-axis label line below that.
rowLabelsForWidth = compose("%.4g",rowVals);
maxLabelChars = max(strlength(rowLabelsForWidth));
if isempty(maxLabelChars) || isnan(maxLabelChars)
    maxLabelChars = 1;
end
approxCharPx = tickFs * 0.62;
approxGlyphHeightPx = tickFs * 1.3;
rotatedLabelHeightPx = maxLabelChars*approxCharPx*sind(tickRotation) + approxGlyphHeightPx*cosd(tickRotation);
xAxisBand = round(rotatedLabelHeightPx) + 10 + round(fs*1.6); % rotated ticks + gap + x label
contentBottom = xAxisBand + 20;      % no panel in Phase 1

figW = marL + W + marR;
figH = contentBottom + H + marT;
mainPos = [marL, contentBottom, W, H];

fig = figure(Color='w',Position=[70 60 round(figW) round(figH)],Visible='off');
ax = axes(fig,Units="pixels",Position=mainPos);

img = imagesc(ax,zeros(r,c*nRow));
colormap(ax,opts.Colormap)
clim(ax,opts.CLim)
% Deliberately do NOT call axis(ax,'image'): mainPos already encodes the
% desired (possibly stretched) aspect ratio directly, matching kpAdFigure.
% Forcing 'image' here would fight that and reintroduce
% distortion/clipping depending on which branch above was taken.

cb = colorbar(ax);
cb.Label.Interpreter = "latex"; % MUST be set before .String
cb.Label.String = opts.ColorbarLabel;
cb.Label.FontSize = fs;
cb.TickLabelInterpreter = "latex";
cb.FontSize = tickFs;
cbPos = [mainPos(1)+mainPos(3)+16, mainPos(2), 18, mainPos(4)];

ax.YDir = "normal";
ax.TickDir = "out";
ax.Box = "off";
ax.FontSize = tickFs;
ax.TickLabelInterpreter = "latex";

ax.XTick = (c/2):c:(c*nRow - c/2);
ax.YTick = r/2;
ax.YTickLabel = "";

% Thin the row ticks if there are too many tiles to label legibly.
rowLabels = rowLabelsForWidth;
keep = localThinTicks(nRow,opts.MaxTiles);
xtl = strings(1,nRow);
xtl(keep) = rowLabels(keep);
ax.XTickLabel = xtl;
ax.XTickLabelRotation = tickRotation;

ax.XLabel.Interpreter = "latex"; % set before String
if strlength(rowUnit) > 0
    ax.XLabel.String = "$\mathrm{" + rowName + "}$ [$\mathrm{" + rowUnit + "}$]";
else
    ax.XLabel.String = "$\mathrm{" + rowName + "}$";
end
ax.XLabel.FontSize = fs + 2;

ax.Title.Interpreter = "latex"; % set before String
ax.Title.FontSize = fs;

%% ---- filename ----------------------------------------------------------
if ~isfolder(opts.OutputFolder)
    mkdir(opts.OutputFolder)
end
file = fullfile(opts.OutputFolder, opts.BaseName + "_" + tag + ".gif");

% Remove any stale/leftover file so the first frame below always creates a
% fresh GIF89a file instead of accidentally appending to old/corrupt data.
if isfile(file)
    delete(file)
end

%% ---- gif timing (Speed is the single easy-to-edit knob) ----------------
speed = opts.Speed;
startDelay = max(0.02, 0.6/speed);
midDelay   = max(0.02, 0.35/speed);
endDelay   = max(0.02, 1.0/speed);

sweepLabels = compose("%.4g",sweepVals);

%% ---- animate ------------------------------------------------------------
cleanupObj = onCleanup(@() closeIfValid(fig));

for kk = 1:nSweep
    tileData = squeeze(adData4(:,:,kk,:)); % [r,c,nRow]
    if nRow == 1
        tileData = reshape(tileData,r,c,1); % guard against squeeze over-collapsing
    end
    cData = cell(1,nRow);
    for jj = 1:nRow
        cData{jj} = tileData(:,:,jj);
    end
    img.CData = horzcat(cData{:});

    if strlength(sweepUnit) > 0
        sweepLabel = "$\mathrm{" + sweepName + "} = " + sweepLabels(kk) + ...
            "~\mathrm{" + sweepUnit + "}$";
    else
        sweepLabel = "$\mathrm{" + sweepName + "} = " + sweepLabels(kk) + "$";
    end
    % Always exactly 2 lines, every frame, so the title never changes the
    % number of lines it occupies (a variable line count reflows the whole
    % axes on some frames only, which is what caused flicker before).
    if strlength(opts.TitleStem) > 0
        ax.Title.String = [opts.TitleStem; sweepLabel];
    else
        ax.Title.String = sweepLabel;
    end

    % Reserved hook: a future bottom panel tracking scan variables per
    % frame would be invoked here, e.g.:
    %   if ~isempty(opts.ScanPanelFcn)
    %       opts.ScanPanelFcn(fig,kk,rowVals,sweepVals);
    %   end

    % Re-pin the exact pixel layout every frame (mirrors kpAdApplyLayout):
    % attaching a colorbar and changing title content both cause MATLAB to
    % silently resize the axes, which is the root cause of frame-to-frame
    % flicker/shift if not corrected right before capture.
    ax.Units = "pixels";
    ax.Position = mainPos;
    if isvalid(cb)
        cb.Units = "pixels";
        cb.Position = cbPos;
    end

    drawnow
    frame = getframe(fig);
    im = frame2im(frame);
    [A,map] = rgb2ind(im,256);
    if kk == 1
        imwrite(A,map,file,'gif','LoopCount',Inf,'DelayTime',startDelay);
    elseif kk == nSweep
        imwrite(A,map,file,'gif','WriteMode','append','DelayTime',endDelay);
    else
        imwrite(A,map,file,'gif','WriteMode','append','DelayTime',midDelay);
    end
end

clear cleanupObj
end


%% ------------------------------------------------------------------
function closeIfValid(fig)
if isgraphics(fig)
    close(fig)
end
end

%% ------------------------------------------------------------------
function keep = localThinTicks(n,maxN)
% Indices of ticks to keep, evenly spaced, so at most maxN are labeled.
if n <= maxN
    keep = 1:n;
else
    keep = round(linspace(1,n,maxN));
    keep = unique(keep);
end
end

%% ------------------------------------------------------------------
function s = localLatexEscape(s)
% Escape characters LaTeX treats specially so raw variable/unit names
% (e.g. "hw_KPModFreq") render literally instead of triggering math-mode
% syntax such as subscripting on "_".
s = string(s);
if strlength(s) == 0
    return
end
s = strrep(s,"\","\textbackslash ");
s = strrep(s,"_","\_");
s = strrep(s,"%","\%");
s = strrep(s,"&","\&");
s = strrep(s,"#","\#");
s = strrep(s,"$","\$");
end