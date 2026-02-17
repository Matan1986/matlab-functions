function figOut = composeManuscriptFigure(figHandles, spec)
if nargin < 2
    error('composeManuscriptFigure:InvalidInput', 'Expected figHandles and spec.');
end

validateattributes(figHandles, {'matlab.ui.Figure','matlab.graphics.Graphics','double'}, {'nonempty'});
figHandles = figHandles(:);

isValidFig = arrayfun(@(h) isgraphics(h, 'figure') && isvalid(h), figHandles);
if ~all(isValidFig)
    error('composeManuscriptFigure:InvalidFigureHandle', 'All figHandles must be valid figure handles.');
end

requiredSpecFields = {'manuscript','grid','layout','panels','export'};
for i = 1:numel(requiredSpecFields)
    if ~isfield(spec, requiredSpecFields{i})
        error('composeManuscriptFigure:MissingSpecField', 'Missing spec.%s', requiredSpecFields{i});
    end
end

if ~isfield(spec.manuscript, 'type')
    error('composeManuscriptFigure:MissingSpecField', 'Missing spec.manuscript.type');
end
if ~isfield(spec.grid, 'rows') || ~isfield(spec.grid, 'cols')
    error('composeManuscriptFigure:MissingSpecField', 'Missing spec.grid.rows or spec.grid.cols');
end
if ~isfield(spec.layout, 'gap') || ~isfield(spec.layout, 'margin')
    error('composeManuscriptFigure:MissingSpecField', 'Missing spec.layout.gap or spec.layout.margin');
end
if ~isfield(spec.panels, 'autoLabels')
    error('composeManuscriptFigure:MissingSpecField', 'Missing spec.panels.autoLabels');
end
if ~isfield(spec.export, 'filename') || ~isfield(spec.export, 'folder')
    error('composeManuscriptFigure:MissingSpecField', 'Missing spec.export.filename or spec.export.folder');
end

manuscriptType = lower(strtrim(char(string(spec.manuscript.type))));
switch manuscriptType
    case 'single'
        totalWidthInches = 3.375;
    case 'double'
        totalWidthInches = 7.0;
    otherwise
        error('composeManuscriptFigure:InvalidManuscriptType', 'spec.manuscript.type must be ''single'' or ''double''.');
end

rows = double(spec.grid.rows);
cols = double(spec.grid.cols);
gapInches = double(spec.layout.gap);
marginInches = double(spec.layout.margin);
autoLabels = logical(spec.panels.autoLabels);

validateattributes(rows, {'numeric'}, {'scalar','integer','positive'});
validateattributes(cols, {'numeric'}, {'scalar','integer','positive'});
validateattributes(gapInches, {'numeric'}, {'scalar','nonnegative'});
validateattributes(marginInches, {'numeric'}, {'scalar','nonnegative'});

availableWidth = totalWidthInches - 2*marginInches - (cols-1)*gapInches;
if availableWidth <= 0
    error('composeManuscriptFigure:InvalidLayout', 'Non-positive drawable width. Reduce margin/gap or cols.');
end
panelWidthInches = availableWidth / cols;

srcAxFirst = getMainAxes(figHandles(1));
if isempty(srcAxFirst)
    error('composeManuscriptFigure:NoAxesFound', 'First source figure does not contain a usable axes.');
end

aspectRatio = getFigureAspectRatio(figHandles(1));
panelHeightInches = panelWidthInches * aspectRatio;

totalHeightInches = rows*panelHeightInches + (rows-1)*gapInches + 2*marginInches;

figOut = figure('Color','w', 'Units','inches', 'Position',[1 1 totalWidthInches totalHeightInches]);
figOut.PaperUnits = 'inches';
figOut.PaperSize = [totalWidthInches totalHeightInches];
figOut.PaperPosition = [0 0 totalWidthInches totalHeightInches];
figOut.PaperPositionMode = 'manual';

layout = tiledlayout(figOut, rows, cols, 'TileSpacing','compact', 'Padding','compact');

maxPanels = rows * cols;
nToPlace = min(numel(figHandles), maxPanels);

for idx = 1:nToPlace
    sourceFigure = figHandles(idx);
    sourceAxes = getMainAxes(sourceFigure);

    targetAxes = nexttile(layout, idx);
    hold(targetAxes, 'on');

    if ~isempty(sourceAxes)
        sourceChildren = allchild(sourceAxes);
        if ~isempty(sourceChildren)
            copyobj(sourceChildren, targetAxes);
        end
        copyAxesPresentation(sourceAxes, targetAxes);
    end

    if autoLabels
        labelText = panelLabel(idx);
        text(targetAxes, 0.02, 0.98, labelText, ...
            'Units','normalized', ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','top', ...
            'FontWeight','bold', ...
            'Interpreter','none');
    end

    hold(targetAxes, 'off');
end

exportFolder = char(string(spec.export.folder));
exportFile = char(string(spec.export.filename));
if isempty(exportFolder)
    exportFolder = pwd;
end
if ~isfolder(exportFolder)
    mkdir(exportFolder);
end
if isempty(exportFile)
    error('composeManuscriptFigure:InvalidExportFilename', 'spec.export.filename must be non-empty.');
end
[~,~,ext] = fileparts(exportFile);
if isempty(ext)
    exportFile = [exportFile '.pdf'];
elseif ~strcmpi(ext, '.pdf')
    exportFile = [exportFile '.pdf'];
end

outputPath = fullfile(exportFolder, exportFile);
exportgraphics(figOut, outputPath, 'ContentType','vector');
end

function ax = getMainAxes(figHandle)
ax = gobjects(0);
allAxes = findall(figHandle, 'Type', 'axes');
if isempty(allAxes)
    return;
end

children = figHandle.Children;
orderedAxes = gobjects(0);
for i = 1:numel(children)
    if isgraphics(children(i), 'axes')
        orderedAxes(end+1,1) = children(i); %#ok<AGROW>
    end
end
if isempty(orderedAxes)
    orderedAxes = allAxes(:);
end

for i = 1:numel(orderedAxes)
    a = orderedAxes(i);
    if ~isgraphics(a, 'axes') || ~isvalid(a)
        continue;
    end
    tagVal = '';
    try
        tagVal = lower(char(string(a.Tag)));
    catch
    end
    if strcmp(tagVal, 'legend') || strcmp(tagVal, 'colorbar') || contains(tagVal, 'legend') || contains(tagVal, 'colorbar')
        continue;
    end
    ax = a;
    return;
end
end

function aspect = getFigureAspectRatio(figHandle)
oldUnits = figHandle.Units;
c = onCleanup(@() set(figHandle, 'Units', oldUnits));
figHandle.Units = 'inches';
pos = figHandle.Position;
if numel(pos) < 4 || pos(3) <= 0 || pos(4) <= 0
    aspect = 0.75;
else
    aspect = pos(4) / pos(3);
end
if ~isfinite(aspect) || aspect <= 0
    aspect = 0.75;
end
end

function copyAxesPresentation(srcAx, dstAx)
propsToCopy = {'XLim','YLim','XScale','YScale','XDir','YDir','Box','Color','CLim','View'};
for i = 1:numel(propsToCopy)
    p = propsToCopy{i};
    try
        if isprop(srcAx, p) && isprop(dstAx, p)
            dstAx.(p) = srcAx.(p);
        end
    catch
    end
end

copyTextObject(srcAx.Title, dstAx.Title);
copyTextObject(srcAx.XLabel, dstAx.XLabel);
copyTextObject(srcAx.YLabel, dstAx.YLabel);

try
    dstAx.FontSize = srcAx.FontSize;
catch
end
try
    dstAx.TickLabelInterpreter = srcAx.TickLabelInterpreter;
catch
end
end

function copyTextObject(srcText, dstText)
textProps = {'String','Interpreter','FontSize','FontWeight','FontAngle','Color'};
for i = 1:numel(textProps)
    p = textProps{i};
    try
        if isprop(srcText, p) && isprop(dstText, p)
            dstText.(p) = srcText.(p);
        end
    catch
    end
end
end

function out = panelLabel(index)
out = '';
n = index;
while n > 0
    r = mod(n-1, 26);
    out = [char('A' + r) out]; %#ok<AGROW>
    n = floor((n-1)/26);
end
end
