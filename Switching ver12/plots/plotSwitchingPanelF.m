
function out = plotSwitchingPanelF(cfg)

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

% ===== NEW OPTION =====
if ~isfield(cfg, 'verticalT') || isempty(cfg.verticalT)
    cfg.verticalT = true;   % default = old behavior
end

thisFile = mfilename('fullpath');
plotsDir = fileparts(thisFile);
switchingRoot = fileparts(plotsDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
source = resolveSourceRun(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('panel_f_source:%s', char(source.runId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

paramsTbl = readtable(source.paramsPath);

T = double(paramsTbl.T_K(:));
I_peak = double(paramsTbl.Ipeak_mA(:));
w = double(paramsTbl.width_chosen_mA(:));
Speak = double(paramsTbl.S_peak(:));

X = I_peak ./ (w .* Speak);

[T, idx] = sort(T, 'ascend');
I_peak = I_peak(idx);
w = w(idx);
Speak = Speak(idx);
X = X(idx);

valid = isfinite(T) & isfinite(I_peak) & isfinite(w) & isfinite(Speak) & isfinite(X);

T = T(valid);
I_peak = I_peak(valid);
w = w(valid);
Speak = Speak(valid);
X = X(valid);

I_norm = normalizeToMax(I_peak);
w_norm = normalizeToMax(w);
S_norm = normalizeToMax(Speak);
X_norm = normalizeToMax(X);

figureName = 'switching_panel_f';

fig = figure('Name', figureName, ...
    'NumberTitle','off', ...
    'Color','w', ...
    'Visible','off');

set(fig, 'Units','centimeters', ...
    'Position',[2 2 8.6 6.2], ...
    'PaperUnits','centimeters', ...
    'PaperPosition',[0 0 8.6 6.2], ...
    'PaperSize',[8.6 6.2]);

ax = axes(fig);
hold(ax,'on');

% ===== COLORS =====
col_I = [0.75 0.75 0.75];
col_w = [0.82 0.82 0.82];
col_S = [0.65 0.65 0.65];
col_X = [0.85 0.33 0.1];

% ===== PLOTTING WITH SWITCH =====
if cfg.verticalT
    % ---- T on Y-axis ----
    plot(ax, I_norm, T, '-', 'LineWidth',1.2, 'Color',col_I);
    plot(ax, w_norm, T, '-', 'LineWidth',1.2, 'Color',col_w);
    plot(ax, S_norm, T, '-', 'LineWidth',1.2, 'Color',col_S);
    plot(ax, X_norm, T, '-o', ...
        'LineWidth',2.5, ...
        'Color',col_X, ...
        'MarkerSize',4, ...
        'MarkerFaceColor',col_X, ...
        'MarkerEdgeColor',[0.3 0.3 0.3]);

    [~, iMax] = max(X_norm);
    plot(ax, X_norm(iMax), T(iMax), 'o', ...
        'MarkerSize',5, ...
        'MarkerFaceColor',col_X, ...
        'MarkerEdgeColor','k');

    xlabel(ax, 'Normalized value');
    ylabel(ax, 'Temperature T (K)');

    xlim(ax, [0 1.02]);
    ylim(ax, [min(T) max(T)]);

else
    % ---- ORIGINAL: T on X-axis ----
    plot(ax, T, I_norm, '-', 'LineWidth',1.2, 'Color',col_I);
    plot(ax, T, w_norm, '-', 'LineWidth',1.2, 'Color',col_w);
    plot(ax, T, S_norm, '-', 'LineWidth',1.2, 'Color',col_S);
    plot(ax, T, X_norm, '-o', ...
        'LineWidth',2.5, ...
        'Color',col_X, ...
        'MarkerSize',4, ...
        'MarkerFaceColor',col_X, ...
        'MarkerEdgeColor',[0.3 0.3 0.3]);

    [~, iMax] = max(X_norm);
    plot(ax, T(iMax), X_norm(iMax), 'o', ...
        'MarkerSize',5, ...
        'MarkerFaceColor',col_X, ...
        'MarkerEdgeColor','k');

    xlabel(ax, 'Temperature T (K)');
    ylabel(ax, 'Normalized value');

    xlim(ax, [min(T) max(T)]);
    ylim(ax, [0 1.02]);
end

legend(ax, {'I','w','S','X'}, 'Location','eastoutside', 'Box','off');

styleAxes(ax);

figPaths = save_run_figure(fig, figureName, runDir);
close(fig);

out = struct();
out.figurePng = string(figPaths.png);
out.figurePdf = string(figPaths.pdf);
out.figureFig = string(figPaths.fig);

end

% ================= HELPERS =================

function yNorm = normalizeToMax(y)
yNorm = NaN(size(y));
mask = isfinite(y);

if ~any(mask)
    return;
end

maxVal = max(y(mask), [], 'omitnan');

if ~isfinite(maxVal) || abs(maxVal) <= eps
    return;
end

yNorm(mask) = y(mask) ./ maxVal;
end

function styleAxes(ax)
set(ax, 'FontName','Helvetica', ...
    'FontSize',8, ...
    'LineWidth',1.0, ...
    'TickDir','out', ...
    'Box','off', ...
    'Layer','top');
grid(ax,'off');
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_panel_f');
cfg = setDefaultField(cfg, 'sourceRunId', '');
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

function source = resolveSourceRun(repoRoot, cfg)

runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');

assert(exist(runsRoot, 'dir') == 7, ...
    'Switching runs root not found: %s', runsRoot);

source = struct();
source.runId = "";
source.paramsPath = "";

% אם ביקשו run ספציפי
requested = string(cfg.sourceRunId);

if strlength(strtrim(requested)) > 0
    runDir = fullfile(runsRoot, char(requested));
    paramsPath = fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv');

    assert(exist(runDir, 'dir') == 7, 'Run not found: %s', runDir);
    assert(exist(paramsPath, 'file') == 2, ...
        'Missing parameters file: %s', paramsPath);

    source.runId = requested;
    source.paramsPath = paramsPath;
    return;
end

% ===== Find latest VALID run (with parameters file) =====

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);

assert(~isempty(runDirs), 'No switching runs found');

% sort newest → oldest
[~, order] = sort([runDirs.datenum], 'descend');
runDirs = runDirs(order);

found = false;

for k = 1:numel(runDirs)
    paramsPath = fullfile(runDirs(k).folder, runDirs(k).name, ...
        'tables', 'switching_full_scaling_parameters.csv');

    if exist(paramsPath, 'file') == 2
        source.runId = string(runDirs(k).name);
        source.paramsPath = paramsPath;
        found = true;
        break;
    end
end

assert(found, 'No run with switching_full_scaling_parameters.csv found');
end