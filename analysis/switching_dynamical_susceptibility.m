function out = switching_dynamical_susceptibility(varargin)
% switching_dynamical_susceptibility
% Compute the temperature-derivative susceptibility of a saved Switching map.
%
% Main usage:
%   out = switching_dynamical_susceptibility();
%   out = switching_dynamical_susceptibility(cfg);
%
% Plot helpers:
%   fh = switching_dynamical_susceptibility("plot_chi_dyn", out);
%   fh = switching_dynamical_susceptibility("plot_derivative_heatmap", out);
%   fh = switching_dynamical_susceptibility("plot_chi_dyn_with_A", out);
%   fh = switching_dynamical_susceptibility("plot_chi_dyn_with_A", out, relaxInput);
%
% Repository orientation note:
%   The observable is written as S(I,T), but the saved repository matrix uses
%   Smap(row, col) = S(T_row, I_col). The temperature derivative is therefore
%   taken along MATLAB dimension 1.

if nargin >= 1 && isTextScalar(varargin{1})
    out = dispatchAction(varargin{:});
    return;
end

cfg = struct();
if nargin >= 1
    if ~isstruct(varargin{1})
        error('switching_dynamical_susceptibility:InvalidInput', ...
            'Expected a cfg struct or an action string.');
    end
    cfg = varargin{1};
end

out = computeSwitchingDynamicalSusceptibility(cfg);
end

function out = dispatchAction(action, varargin)
action = lower(strrep(char(string(action)), '-', '_'));

switch action
    case {'compute', 'run'}
        cfg = struct();
        if ~isempty(varargin)
            if ~isstruct(varargin{1})
                error('switching_dynamical_susceptibility:InvalidCfg', ...
                    'Action "%s" expects a cfg struct.', action);
            end
            cfg = varargin{1};
        end
        out = computeSwitchingDynamicalSusceptibility(cfg);

    case {'plot_chi_dyn', 'plot_chi'}
        [result, args] = requireResult(varargin, action);
        out = plotChiDyn(result, args{:});

    case {'plot_derivative_heatmap', 'plot_ds_dt_heatmap', 'plot_heatmap'}
        [result, args] = requireResult(varargin, action);
        out = plotDerivativeHeatmap(result, args{:});

    case {'plot_chi_dyn_with_a', 'plot_overlay', 'plot_chi_with_a'}
        [result, args] = requireResult(varargin, action);
        out = plotChiDynWithA(result, args{:});

    otherwise
        error('switching_dynamical_susceptibility:UnknownAction', ...
            'Unknown action "%s".', action);
end
end

function [result, args] = requireResult(argsIn, action)
if isempty(argsIn) || ~isstruct(argsIn{1})
    error('switching_dynamical_susceptibility:MissingResult', ...
        'Action "%s" expects the computed result struct first.', action);
end
result = argsIn{1};
args = argsIn(2:end);
validateResultStruct(result);
end

function out = computeSwitchingDynamicalSusceptibility(cfg)
cfg = applyDefaults(cfg);

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

source = resolveSwitchingSource(repoRoot, cfg);
[temps, currents, Smap, source] = loadSwitchingMap(source, cfg);

% Repository convention: rows index temperature and columns index current,
% so dS/dT is computed down dimension 1.
dS_dT = computeTemperatureDerivative(Smap, temps, cfg.tempSmoothWindow);

out = struct();
out.temps = temps;
out.currents = currents;
out.Smap = Smap;
out.dS_dT = dS_dT;
out.chi_dyn = sqrt(rowwiseMean(dS_dT .^ 2));
out.chi_dyn_L1 = rowwiseMean(abs(dS_dT));
out.chi_dyn_max = rowwiseMax(abs(dS_dT));
out.source = source;
out.orientation = "Smap(row, col) = S(T_row, I_col); dS_dT uses dimension 1.";
out.definitions = struct( ...
    'chi_dyn', "sqrt(mean_I((dS_dT).^2))", ...
    'chi_dyn_L1', "mean_I(abs(dS_dT))", ...
    'chi_dyn_max', "max_I(abs(dS_dT))");
out.processing = struct( ...
    'tempSmoothWindow', cfg.tempSmoothWindow, ...
    'temperatureDerivativeMethod', "gradient along temperature axis");
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'switchRunDir', "");
cfg = setDefaultField(cfg, 'switchRunName', "");
cfg = setDefaultField(cfg, 'switchLabelHint', "");
cfg = setDefaultField(cfg, 'tempSmoothWindow', 1);
end

function source = resolveSwitchingSource(repoRoot, cfg)
if strlength(string(cfg.switchRunDir)) > 0
    runDir = char(string(cfg.switchRunDir));
elseif strlength(string(cfg.switchRunName)) > 0
    runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(string(cfg.switchRunName)));
else
    runDir = findLatestRunWithMap(repoRoot, 'switching', string(cfg.switchLabelHint));
end

if exist(runDir, 'dir') ~= 7
    error('switching_dynamical_susceptibility:MissingRunDir', ...
        'Switching run directory not found: %s', runDir);
end

source = struct();
source.repoRoot = string(repoRoot);
source.switchRunDir = string(runDir);
source.corePath = string(fullfile(runDir, 'switching_alignment_core_data.mat'));
source.samplesPath = string(fullfile(runDir, 'switching_alignment_samples.csv'));
source.observableMatrixPath = string(fullfile(runDir, 'observable_matrix.csv'));
source.loadedFrom = "";
source.metricType = "";
end

function runDir = findLatestRunWithMap(repoRoot, experiment, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('switching_dynamical_susceptibility:NoRuns', ...
        'No %s runs found under %s', experiment, runsRoot);
end

names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);

for i = numel(runDirs):-1:1
    candidate = fullfile(runDirs(i).folder, runDirs(i).name);
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    hasCore = exist(fullfile(candidate, 'switching_alignment_core_data.mat'), 'file') == 2;
    hasSamples = exist(fullfile(candidate, 'switching_alignment_samples.csv'), 'file') == 2;
    if hasCore || hasSamples
        runDir = candidate;
        return;
    end
end

error('switching_dynamical_susceptibility:NoMatchingRun', ...
    'No %s run with saved map data matched the requested criteria.', experiment);
end

function [temps, currents, Smap, source] = loadSwitchingMap(source, cfg)
if exist(char(source.corePath), 'file') == 2
    core = load(char(source.corePath), 'temps', 'currents', 'Smap', 'metricType');
    requireField(core, 'temps', char(source.corePath));
    requireField(core, 'currents', char(source.corePath));
    requireField(core, 'Smap', char(source.corePath));
    temps = double(core.temps(:));
    currents = double(core.currents(:));
    Smap = double(core.Smap);
    if isfield(core, 'metricType') && ~isempty(core.metricType)
        source.metricType = string(core.metricType);
    end
    source.loadedFrom = "switching_alignment_core_data.mat";
elseif exist(char(source.samplesPath), 'file') == 2
    samplesTbl = readtable(char(source.samplesPath));
    [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
    temps = double(temps(:));
    currents = double(currents(:));
    Smap = double(Smap);
    source.loadedFrom = "switching_alignment_samples.csv";
else
    error('switching_dynamical_susceptibility:MissingMapData', ...
        'Neither %s nor %s exists.', char(source.corePath), char(source.samplesPath));
end

[Smap, orientationInfo] = orientSwitchingMap(Smap, temps, currents, char(source.observableMatrixPath));
[temps, currents, Smap] = sortAxesAndValidate(temps, currents, Smap);
source.orientation = orientationInfo;
source.tempSmoothWindow = cfg.tempSmoothWindow;
end

function [Smap, orientationInfo] = orientSwitchingMap(Smap, temps, currents, observableMatrixPath)
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);

if rowsAreTemps && ~rowsAreCurrents
    orientationInfo = "Rows already match temperature and columns already match current.";
    return;
end
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
    orientationInfo = "Transposed loaded map so rows match temperature and columns match current.";
    return;
end
if rowsAreTemps && rowsAreCurrents
    orientationInfo = "Square map matched both axis lengths; kept repository convention rows=temperature, cols=current.";
    if exist(observableMatrixPath, 'file') == 2
        orientationInfo = orientationInfo + " observable_matrix.csv was available but not decisive.";
    end
    return;
end

error('switching_dynamical_susceptibility:MapSizeMismatch', ...
    'Smap size [%d %d] does not match temps (%d) and currents (%d).', ...
    size(Smap, 1), size(Smap, 2), numel(temps), numel(currents));
end

function [temps, currents, Smap] = sortAxesAndValidate(temps, currents, Smap)
[temps, tOrder] = sort(temps(:));
[currents, iOrder] = sort(currents(:));
Smap = Smap(tOrder, iOrder);
if any(~isfinite(temps)) || any(diff(temps) <= 0)
    error('switching_dynamical_susceptibility:InvalidTemps', ...
        'Temperature axis must be finite and strictly increasing.');
end
if any(~isfinite(currents)) || any(diff(currents) <= 0)
    error('switching_dynamical_susceptibility:InvalidCurrents', ...
        'Current axis must be finite and strictly increasing.');
end
end

function dS_dT = computeTemperatureDerivative(Smap, temps, tempSmoothWindow)
dS_dT = NaN(size(Smap));
for ii = 1:size(Smap, 2)
    col = Smap(:, ii);
    valid = isfinite(col) & isfinite(temps);
    if nnz(valid) < 2
        continue;
    end
    x = temps(valid);
    y = col(valid);
    window = min(max(1, round(tempSmoothWindow)), numel(y));
    if window >= 2
        y = smoothdata(y, 'movmean', window);
    end
    dtmp = gradient(y, x);
    dcol = NaN(size(col));
    dcol(valid) = dtmp(:);
    dS_dT(:, ii) = dcol;
end
end

function fh = plotChiDyn(result, varargin)
opts = struct('Axes', [], 'ShowVariants', true, 'FontSize', 14, 'LineWidth', 2.2);
opts = parseNameValue(opts, varargin{:});
[fh, ax] = prepareAxes(opts.Axes, [100 100 900 620]);
colors = figureColors();

plot(ax, result.temps, result.chi_dyn, '-o', 'LineWidth', opts.LineWidth, ...
    'MarkerSize', 5, 'Color', colors.black, 'DisplayName', '\chi_{dyn}(T) RMS');
hold(ax, 'on');
if opts.ShowVariants
    plot(ax, result.temps, result.chi_dyn_L1, '--s', 'LineWidth', 1.8, ...
        'MarkerSize', 5, 'Color', colors.blue, 'DisplayName', 'mean_I |dS/dT|');
    plot(ax, result.temps, result.chi_dyn_max, ':^', 'LineWidth', 1.8, ...
        'MarkerSize', 5, 'Color', colors.orange, 'DisplayName', 'max_I |dS/dT|');
    legend(ax, 'Location', 'best', 'Box', 'off');
end
hold(ax, 'off');
grid(ax, 'on');
styleLineAxis(ax, opts.FontSize);
xlabel(ax, 'Temperature T (K)');
ylabel(ax, 'Dynamical susceptibility (signal / K)');
title(ax, 'Switching dynamical susceptibility versus temperature');
end

function fh = plotDerivativeHeatmap(result, varargin)
opts = struct('Axes', [], 'FontSize', 14);
opts = parseNameValue(opts, varargin{:});
[fh, ax] = prepareAxes(opts.Axes, [100 100 920 650]);

imagesc(ax, result.currents, result.temps, result.dS_dT);
axis(ax, 'xy');
colormap(ax, blueWhiteRedMap(256));
absMax = finiteMaxAbs(result.dS_dT);
if isfinite(absMax) && absMax > 0
    caxis(ax, [-absMax absMax]);
end
cb = colorbar(ax);
ylabel(cb, 'dS / dT (signal / K)');
styleHeatmapAxis(ax, opts.FontSize);
xlabel(ax, 'Current I (mA)');
ylabel(ax, 'Temperature T (K)');
title(ax, 'Temperature derivative heatmap of the switching map');
end

function fh = plotChiDynWithA(result, varargin)
relaxInput = [];
if ~isempty(varargin)
    firstArg = varargin{1};
    if isstruct(firstArg) || istable(firstArg)
        relaxInput = firstArg;
        varargin = varargin(2:end);
    elseif isTextScalar(firstArg) && ~isOptionName(firstArg, {'Axes', 'Normalize', 'InterpMethod', 'FontSize'})
        relaxInput = firstArg;
        varargin = varargin(2:end);
    end
end

opts = struct('Axes', [], 'Normalize', true, 'InterpMethod', 'pchip', 'FontSize', 14);
opts = parseNameValue(opts, varargin{:});

relax = loadRelaxationAmplitude(relaxInput, result.source.repoRoot);
Tplot = result.temps(:);
chiPlot = result.chi_dyn(:);
Aplot = interp1(relax.T, relax.A, Tplot, opts.InterpMethod, NaN);
if opts.Normalize
    chiPlot = normalizeToMax(chiPlot);
    Aplot = normalizeToMax(Aplot);
    yLabel = 'Normalized amplitude';
    chiLabel = '\chi_{dyn}(T) / max';
    aLabel = 'A(T) / max';
else
    yLabel = 'Amplitude';
    chiLabel = '\chi_{dyn}(T)';
    aLabel = 'A(T)';
end

[fh, ax] = prepareAxes(opts.Axes, [100 100 900 620]);
colors = figureColors();
plot(ax, Tplot, chiPlot, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, ...
    'Color', colors.black, 'DisplayName', chiLabel);
hold(ax, 'on');
plot(ax, Tplot, Aplot, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, ...
    'Color', colors.blue, 'DisplayName', aLabel);
hold(ax, 'off');
grid(ax, 'on');
styleLineAxis(ax, opts.FontSize);
legend(ax, 'Location', 'best', 'Box', 'off');
xlabel(ax, 'Temperature T (K)');
ylabel(ax, yLabel);
title(ax, 'Dynamical susceptibility overlaid with relaxation A(T)');
end

function relax = loadRelaxationAmplitude(relaxInput, repoRoot)
if nargin < 2 || strlength(string(repoRoot)) == 0
    error('switching_dynamical_susceptibility:MissingRepoRoot', ...
        'A repository root is required to resolve Relaxation data.');
end

if nargin < 1 || isempty(relaxInput)
    runDir = findLatestRelaxationRun(char(repoRoot));
    tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
elseif istable(relaxInput)
    tbl = relaxInput;
elseif isstruct(relaxInput)
    relax = relaxationStructFromInput(relaxInput);
    return;
elseif isTextScalar(relaxInput)
    relaxPath = char(string(relaxInput));
    if exist(relaxPath, 'file') == 2
        tbl = readtable(relaxPath);
    elseif exist(relaxPath, 'dir') == 7
        tbl = readtable(fullfile(relaxPath, 'tables', 'temperature_observables.csv'));
    elseif startsWith(string(relaxPath), "run_")
        runDir = fullfile(char(repoRoot), 'results', 'relaxation', 'runs', relaxPath);
        tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
    else
        error('switching_dynamical_susceptibility:InvalidRelaxInput', ...
            'Could not resolve Relaxation input "%s".', relaxPath);
    end
else
    error('switching_dynamical_susceptibility:InvalidRelaxInput', ...
        'Unsupported Relaxation input type.');
end

relax = relaxationStructFromTable(tbl);
end

function runDir = findLatestRelaxationRun(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('switching_dynamical_susceptibility:NoRelaxRuns', ...
        'No Relaxation runs found under %s', runsRoot);
end

names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);

for i = numel(runDirs):-1:1
    candidate = fullfile(runDirs(i).folder, runDirs(i).name);
    if exist(fullfile(candidate, 'tables', 'temperature_observables.csv'), 'file') == 2
        runDir = candidate;
        return;
    end
end

error('switching_dynamical_susceptibility:NoRelaxRuns', ...
    'No Relaxation run with temperature_observables.csv was found under %s.', runsRoot);
end

function relax = relaxationStructFromInput(relaxInput)
if ~isfield(relaxInput, 'T')
    error('switching_dynamical_susceptibility:InvalidRelaxStruct', ...
        'Relaxation struct must contain field T.');
end
if isfield(relaxInput, 'A')
    A = relaxInput.A;
elseif isfield(relaxInput, 'A_T')
    A = relaxInput.A_T;
else
    error('switching_dynamical_susceptibility:InvalidRelaxStruct', ...
        'Relaxation struct must contain field A or A_T.');
end
[T, A] = sortRelaxationData(double(relaxInput.T(:)), double(A(:)));
relax = struct('T', T, 'A', A);
end

function relax = relaxationStructFromTable(tbl)
if ~ismember('T', tbl.Properties.VariableNames)
    error('switching_dynamical_susceptibility:InvalidRelaxTable', ...
        'Relaxation table must contain column T.');
end
if ismember('A_T', tbl.Properties.VariableNames)
    A = tbl.A_T;
elseif ismember('A', tbl.Properties.VariableNames)
    A = tbl.A;
else
    error('switching_dynamical_susceptibility:InvalidRelaxTable', ...
        'Relaxation table must contain column A_T or A.');
end
[T, A] = sortRelaxationData(double(tbl.T(:)), double(A(:)));
relax = struct('T', T, 'A', A);
end

function [T, A] = sortRelaxationData(T, A)
[T, order] = sort(T(:));
A = A(order);
valid = isfinite(T) & isfinite(A);
T = T(valid);
A = A(valid);
if any(diff(T) <= 0)
    error('switching_dynamical_susceptibility:InvalidRelaxAxis', ...
        'Relaxation temperature axis must be strictly increasing.');
end
end

function validateResultStruct(result)
required = {'temps', 'currents', 'Smap', 'dS_dT', 'chi_dyn', 'chi_dyn_L1', 'chi_dyn_max'};
for i = 1:numel(required)
    if ~isfield(result, required{i})
        error('switching_dynamical_susceptibility:InvalidResult', ...
            'Missing result field "%s".', required{i});
    end
end
end

function tf = isTextScalar(x)
tf = ischar(x) || (isstring(x) && isscalar(x));
end

function opts = parseNameValue(opts, varargin)
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('switching_dynamical_susceptibility:InvalidNameValue', ...
        'Optional arguments must be provided as name/value pairs.');
end
names = fieldnames(opts);
for k = 1:2:numel(varargin)
    idx = find(strcmpi(char(string(varargin{k})), names), 1);
    if isempty(idx)
        error('switching_dynamical_susceptibility:UnknownOption', ...
            'Unknown option "%s".', char(string(varargin{k})));
    end
    opts.(names{idx}) = varargin{k + 1};
end
end

function tf = isOptionName(candidate, optionNames)
name = lower(char(string(candidate)));
optionNames = cellstr(lower(string(optionNames)));
tf = any(strcmp(name, optionNames));
end

function [fh, ax] = prepareAxes(axIn, defaultPosition)
if isempty(axIn)
    fh = figure('Color', 'w', 'Position', defaultPosition);
    ax = axes(fh);
else
    if ~ishandle(axIn) || ~strcmp(get(axIn, 'Type'), 'axes')
        error('switching_dynamical_susceptibility:InvalidAxes', ...
            'Axes option must be a valid axes handle.');
    end
    ax = axIn;
    fh = ancestor(ax, 'figure');
end
end

function styleLineAxis(ax, fontSize)
set(ax, 'FontName', 'Helvetica', 'FontSize', fontSize, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function styleHeatmapAxis(ax, fontSize)
set(ax, 'FontName', 'Helvetica', 'FontSize', fontSize, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'on', 'Layer', 'top');
end

function colors = figureColors()
colors = struct();
colors.black = [0.00 0.00 0.00];
colors.blue = [0.00 0.45 0.70];
colors.orange = [0.90 0.62 0.00];
end

function cmap = blueWhiteRedMap(n)
if nargin < 1 || isempty(n)
    n = 256;
end
half = floor(n / 2);
blue = [0.23 0.30 0.75];
white = [1.00 1.00 1.00];
red = [0.71 0.02 0.15];
down = [linspace(blue(1), white(1), half)', linspace(blue(2), white(2), half)', linspace(blue(3), white(3), half)'];
up = [linspace(white(1), red(1), n - half)', linspace(white(2), red(2), n - half)', linspace(white(3), red(3), n - half)'];
cmap = [down; up];
end

function y = rowwiseMean(X)
valid = isfinite(X);
counts = sum(valid, 2);
X(~valid) = 0;
y = sum(X, 2) ./ counts;
y(counts == 0) = NaN;
end

function y = rowwiseMax(X)
y = NaN(size(X, 1), 1);
for i = 1:size(X, 1)
    row = X(i, :);
    row = row(isfinite(row));
    if ~isempty(row)
        y(i) = max(row);
    end
end
end

function y = normalizeToMax(x)
x = double(x(:));
scale = finiteMaxAbs(x);
if ~(isfinite(scale) && scale > 0)
    y = NaN(size(x));
    return;
end
y = x ./ scale;
end

function value = finiteMaxAbs(x)
x = abs(double(x(:)));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end

function requireField(s, fieldName, sourcePath)
if ~isfield(s, fieldName)
    error('switching_dynamical_susceptibility:MissingField', ...
        'Required field "%s" was not found in %s.', fieldName, sourcePath);
end
end

function value = setDefaultField(s, fieldName, defaultValue)
value = s;
if ~isfield(value, fieldName) || isempty(value.(fieldName))
    value.(fieldName) = defaultValue;
end
end
