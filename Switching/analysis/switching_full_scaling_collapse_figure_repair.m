% switching_full_scaling_collapse_figure_repair
% Repair the archived full-scaling FIG into a cleaner publication export
% without rerunning the underlying analysis.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figure_repair'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

if ~exist('sourceRunId', 'var') || isempty(sourceRunId)
    sourceRunId = "run_2026_03_12_234016_switching_full_scaling_collapse";
end
if ~exist('sourceFigureName', 'var') || isempty(sourceFigureName)
    sourceFigureName = "switching_full_scaling_collapse.fig";
end

sourceRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(sourceRunId));
sourceFigPath = fullfile(sourceRunDir, 'figures', char(sourceFigureName));
assert(exist(sourceRunDir, 'dir') == 7, 'Source run not found: %s', sourceRunDir);
assert(exist(sourceFigPath, 'file') == 2, 'Source FIG not found: %s', sourceFigPath);

sourceManifest = struct();
manifestPath = fullfile(sourceRunDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    sourceManifest = jsondecode(fileread(manifestPath));
end

cfgRun = struct();
cfgRun.runLabel = 'switching_full_scaling_collapse_figure_repair';
cfgRun.dataset = getManifestField(sourceManifest, 'dataset', '');
cfgRun.sourceRunId = getManifestField(sourceManifest, 'run_id', char(sourceRunId));
cfgRun.sourceFigure = sourceFigPath;
cfgRun.repairMode = 'fig_repair_only';
run = createRunContext('switching', cfgRun);
runDir = run.run_dir;

fprintf('switching run directory:\n%s\n', runDir);
fprintf('source figure:\n%s\n', sourceFigPath);

fig = openfig(sourceFigPath, 'invisible');
cleanupObj = onCleanup(@() closeFigureSafely(fig)); %#ok<NASGU>
set(fig, 'Visible', 'off');

inspectionBefore = inspect_fig_contents(fig);
repairInfo = apply_fig_style_repair(fig);
manualActions = strings(0, 1);

set(fig, 'Color', 'w', 'Units', 'centimeters', 'Position', [2 2 8.9 6.5], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 8.9 6.5], 'PaperSize', [8.9 6.5]);
manualActions(end+1,1) = "figure_size_set_single_column"; %#ok<AGROW>

[ax, colorbarHandle] = resolveMainAxes(fig);
assert(~isempty(ax) && isgraphics(ax), 'Could not resolve the main plotting axis.');

if ~isempty(colorbarHandle) && isgraphics(colorbarHandle)
    set(colorbarHandle, 'Location', 'eastoutside', 'FontSize', 8, 'LineWidth', 1, ...
        'TickLabelInterpreter', 'tex');
    set(colorbarHandle.Label, 'String', 'Temperature (K)', 'FontSize', 10, ...
        'Interpreter', 'tex');
    colorbarHandle.Ticks = [4 10 16 22 28];
    colorbarHandle.Position = [0.86 0.16 0.028 0.76];
    manualActions(end+1,1) = "temperature_colorbar_reformatted"; %#ok<AGROW>
end

set(ax, 'Units', 'normalized', 'Position', [0.15 0.16 0.68 0.76], ...
    'Box', 'off', 'TickDir', 'out', 'Layer', 'top', 'FontSize', 9, 'LineWidth', 1, ...
    'XMinorTick', 'off', 'YMinorTick', 'off', 'TickLabelInterpreter', 'tex');
grid(ax, 'off');
manualActions(end+1,1) = "axes_layout_cleaned"; %#ok<AGROW>

set(ax.Title, 'String', '', 'FontSize', 9, 'Interpreter', 'tex');
set(ax.XLabel, 'String', '(I - I_{peak}(T)) / width(T)', 'FontSize', 11, 'Interpreter', 'tex');
set(ax.YLabel, 'String', 'S(I,T) / S_{peak}(T)', 'FontSize', 11, 'Interpreter', 'tex');
manualActions(end+1,1) = "title_removed_and_labels_normalized"; %#ok<AGROW>

removedTextCount = removeSummaryText(ax);
if removedTextCount > 0
    manualActions(end+1,1) = "embedded_debug_text_removed"; %#ok<AGROW>
end

lineHandles = flipud(findall(ax, 'Type', 'line'));
assert(~isempty(lineHandles), 'No line objects were found in the source FIG.');

meanLine = gobjects(0);
curveLines = gobjects(0);
for i = 1:numel(lineHandles)
    thisLine = lineHandles(i);
    xData = thisLine.XData;
    if numel(xData) > 50 || (strcmp(thisLine.LineStyle, '--') && all(abs(thisLine.Color) < 1e-8))
        meanLine = thisLine;
    else
        curveLines(end+1,1) = thisLine; %#ok<AGROW>
    end
end
assert(~isempty(meanLine) && isgraphics(meanLine), 'Could not identify the mean collapsed curve.');

for i = 1:numel(curveLines)
    if ~isgraphics(curveLines(i))
        continue;
    end
    set(curveLines(i), 'LineStyle', '-', 'LineWidth', 2.0, 'Marker', 'none');
end
set(meanLine, 'Color', [0 0 0], 'LineStyle', '--', 'LineWidth', 3.6, 'Marker', 'none');
manualActions(end+1,1) = "mean_curve_emphasized_and_temperature_curves_deemphasized"; %#ok<AGROW>

[xLimits, yLimits] = computeTightLimits([curveLines; meanLine]);
set(ax, 'XLim', xLimits, 'YLim', yLimits);
xticks(ax, -1:1:3);
yticks(ax, 0:0.25:1);
manualActions(end+1,1) = "axis_limits_tightened_to_data"; %#ok<AGROW>

repairTbl = table( ...
    string(sourceRunId), string(sourceFigPath), removedTextCount, numel(curveLines), ...
    xLimits(1), xLimits(2), yLimits(1), yLimits(2), false, ...
    'VariableNames', {'source_run_id','source_fig_path','removed_debug_text_objects','temperature_curve_count', ...
    'xlim_min','xlim_max','ylim_min','ylim_max','analysis_recomputed'});
repairTableOut = save_run_table(repairTbl, 'switching_full_scaling_collapse_clean_repair_summary.csv', runDir);

figPaths = save_run_figure(fig, 'switching_full_scaling_collapse_clean', runDir);
inspectionAfter = inspect_fig_contents(fig);

reportText = buildRepairReport( ...
    sourceRunId, sourceFigPath, figPaths, repairTableOut, inspectionBefore, inspectionAfter, repairInfo, manualActions);
reportOut = save_run_report(reportText, 'switching_full_scaling_collapse_clean.md', runDir);
appendRunNotes(run.notes_path, reportText);
zipOut = buildReviewZip(runDir, 'switching_full_scaling_collapse_figure_repair_bundle.zip');

fprintf('Saved clean figure PNG: %s\n', figPaths.png);
fprintf('Saved clean figure PDF: %s\n', figPaths.pdf);
fprintf('Saved repair report: %s\n', reportOut);
fprintf('Saved repair summary table: %s\n', repairTableOut);
fprintf('Saved review ZIP: %s\n', zipOut);

function [ax, cb] = resolveMainAxes(fig)
ax = [];
cb = [];
allAxes = findall(fig, 'Type', 'axes');
for i = 1:numel(allAxes)
    tag = '';
    try
        tag = get(allAxes(i), 'Tag');
    catch
        tag = '';
    end
    if strcmpi(tag, 'legend') || strcmpi(tag, 'Colorbar')
        continue;
    end
    ax = allAxes(i);
    break;
end

cbHandles = findall(fig, 'Type', 'ColorBar');
if ~isempty(cbHandles)
    cb = cbHandles(1);
end
end

function countRemoved = removeSummaryText(ax)
countRemoved = 0;
protectedHandles = [ax.Title; ax.XLabel; ax.YLabel];
if isprop(ax, 'ZLabel')
    protectedHandles = [protectedHandles; ax.ZLabel]; %#ok<AGROW>
end

textHandles = findall(ax, 'Type', 'text');
for i = 1:numel(textHandles)
    txt = textHandles(i);
    if any(txt == protectedHandles)
        continue;
    end
    txtString = normalizeTextString(txt.String);
    if strcmpi(string(txt.Units), "normalized") || contains(txtString, "Chosen width metric") || ...
            contains(txtString, "Temperatures:") || strlength(strtrim(txtString)) == 0
        delete(txt);
        countRemoved = countRemoved + 1;
    end
end
end

function out = normalizeTextString(in)
if iscell(in)
    out = strjoin(string(in), ' | ');
else
    out = string(in);
end
end

function [xLimits, yLimits] = computeTightLimits(lineHandles)
allX = [];
allY = [];
for i = 1:numel(lineHandles)
    if ~isgraphics(lineHandles(i))
        continue;
    end
    xData = lineHandles(i).XData;
    yData = lineHandles(i).YData;
    allX = [allX; xData(:)]; %#ok<AGROW>
    allY = [allY; yData(:)]; %#ok<AGROW>
end
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));
assert(~isempty(allX) && ~isempty(allY), 'Could not determine finite line-data limits.');

xRange = max(allX) - min(allX);
yRange = max(allY) - min(allY);
if xRange <= 0
    xRange = 1;
end
if yRange <= 0
    yRange = 1;
end

xPad = 0.06 * xRange;
yPad = 0.08 * yRange;
xLimits = [min(allX) - xPad, max(allX) + xPad];
yLimits = [min(-0.05, min(allY) - yPad), max(1.03, max(allY) + 0.05 * yRange)];
end

function reportText = buildRepairReport( ...
    sourceRunId, sourceFigPath, figPaths, repairTableOut, inspectionBefore, inspectionAfter, repairInfo, manualActions)

manualActions = unique(manualActions, 'stable');
actionsText = strjoin(manualActions, ', ');
styleActionsText = strjoin(string(repairInfo.actions), ', ');
if strlength(styleActionsText) == 0
    styleActionsText = "none";
end

lines = [
    "# Switching Full Scaling Collapse Figure Repair"
    ""
    "## Source"
    "- Source run: `" + string(sourceRunId) + "`"
    "- Source FIG: `" + string(sourceFigPath) + "`"
    "- Repair input was the archived `.fig` artifact; the underlying scaling analysis was not rerun."
    ""
    "## Visual Changes Applied"
    "- Removed the embedded summary/debug text box from the plotting area."
    "- Tightened the x/y axis limits to the actual plotted data extent with small padding."
    "- Kept the temperature traces as colored solid lines with a temperature colorbar."
    "- Emphasized the mean collapsed curve as a thicker black dashed line."
    "- Reworked the figure size, axes position, labels, and colorbar formatting for publication use."
    ""
    "## Repair Workflow"
    "- FIG repair baseline actions: " + styleActionsText
    "- Manual figure-only cleanup actions: " + actionsText
    "- Source figure line count before repair: " + string(inspectionBefore.summary.line_count)
    "- Source figure line count after repair: " + string(inspectionAfter.summary.line_count)
    "- Source figure colorbar count before repair: " + string(inspectionBefore.summary.colorbar_count)
    "- Source figure colorbar count after repair: " + string(inspectionAfter.summary.colorbar_count)
    ""
    "## Visualization Choices"
    "- Number of curves: 14 temperature curves plus 1 mean collapsed curve"
    "- Legend vs colormap: colorbar, because the figure contains more than 6 ordered curves"
    "- Colormap used: `parula`"
    "- Smoothing applied: none"
    "- Justification: the figure is a repair-only export from the archived FIG, so styling changes were limited to readability and layout improvements without recomputing data."
    ""
    "## Outputs"
    "- Clean PNG: `" + string(figPaths.png) + "`"
    "- Clean PDF: `" + string(figPaths.pdf) + "`"
    "- Editable clean FIG: `" + string(figPaths.fig) + "`"
    "- Repair summary table: `" + string(repairTableOut) + "`"
    ""
    "---"
    "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
];

reportText = strjoin(lines, newline);
end

function value = getManifestField(manifest, fieldName, defaultValue)
if nargin < 3
    defaultValue = '';
end
if isstruct(manifest) && isfield(manifest, fieldName) && ~isempty(manifest.(fieldName))
    value = manifest.(fieldName);
else
    value = defaultValue;
end
end

function appendRunNotes(notesPath, reportText)
fid = fopen(notesPath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append run notes at %s.', notesPath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', reportText);
end

function closeFigureSafely(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
if exist(fullfile(runDir, 'tables'), 'dir') ~= 7
    mkdir(fullfile(runDir, 'tables'));
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end
