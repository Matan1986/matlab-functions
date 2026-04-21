function out = relaxation_temperature_scaling_test(cfg)
% relaxation_temperature_scaling_test
% Test whether relaxation activity A(T) follows internal temperature
% scaling: log(A) vs log(T) (power-law hypothesis).
%
% Usage:
%   out = relaxation_temperature_scaling_test()
%   out = relaxation_temperature_scaling_test(cfg)
%
% Data source:
%   results/relaxation/runs/run_2026_03_10_175048_relaxation_observable_stability_audit/
%       tables/temperature_observables.csv
% Expected columns: T_K (or T) and A (or A_T).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot    = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
if isfield(cfg, 'repoRootOverride') && ~isempty(cfg.repoRootOverride)
    repoRoot = char(string(cfg.repoRootOverride));
end

% ------------------------------------------------------------------ %
% 1. Locate and load data
% ------------------------------------------------------------------ %
csvPath = fullfile(repoRoot, 'results', 'relaxation', 'runs', ...
    char(cfg.relaxRunName), 'tables', 'temperature_observables.csv');
if exist(csvPath, 'file') ~= 2
    error('relaxation_temperature_scaling_test:missingData', ...
        'Required source file not found:\n  %s\n', csvPath);
end

if ~local_relaxation_temp_observables_ok(csvPath)
    error('relaxation_temperature_scaling_test:invalidCsv', ...
        'temperature_observables.csv failed precondition: %s', csvPath);
end

tbl = readtable(csvPath);
varNames = string(tbl.Properties.VariableNames);

% --- resolve T column (accept T_K or T) ---
if any(varNames == "T_K")
    T_K = tbl.T_K(:);
elseif any(varNames == "T")
    T_K = tbl.T(:);
else
    error('relaxation_temperature_scaling_test:missingColumn', ...
        'Cannot find temperature column (T_K or T) in %s', csvPath);
end

% --- resolve A column (accept A or A_T) ---
if any(varNames == "A")
    A = tbl.A(:);
elseif any(varNames == "A_T")
    A = tbl.A_T(:);
else
    error('relaxation_temperature_scaling_test:missingColumn', ...
        'Cannot find activity column (A or A_T) in %s', csvPath);
end

% ------------------------------------------------------------------ %
% 2. Remove invalid entries: NaN, A <= 0
% ------------------------------------------------------------------ %
validMask = isfinite(T_K) & isfinite(A) & (A > 0) & (T_K > 0);
T_K_valid = T_K(validMask);
A_valid   = A(validMask);
N_points  = numel(T_K_valid);

if N_points < 3
    error('relaxation_temperature_scaling_test:insufficientData', ...
        'Only %d valid points after cleaning (need >= 3).', N_points);
end

% ------------------------------------------------------------------ %
% 3. Log-transform
% ------------------------------------------------------------------ %
logT = log(T_K_valid);
logA = log(A_valid);

% ------------------------------------------------------------------ %
% 4. Linear regression: logA = a + alpha * logT
% ------------------------------------------------------------------ %
p     = polyfit(logT, logA, 1);
alpha = p(1);
a     = p(2);

% ------------------------------------------------------------------ %
% 5. Extract fit metrics
% ------------------------------------------------------------------ %
logA_fit = a + alpha .* logT;
residuals = logA - logA_fit;
SS_res    = sum(residuals .^ 2);
SS_tot    = sum((logA - mean(logA)) .^ 2);
if SS_tot > 0
    R2 = 1 - SS_res / SS_tot;
else
    R2 = NaN;
end
RMSE = sqrt(SS_res / N_points);

fprintf('\n=== Relaxation temperature scaling test ===\n');
fprintf('Data: %s\n', csvPath);
fprintf('N valid points: %d\n', N_points);
fprintf('Fit: log(A) = %.6g + %.6g * log(T)\n', a, alpha);
fprintf('alpha = %.6g\n', alpha);
fprintf('R2    = %.6f\n', R2);
fprintf('RMSE  = %.6g\n', RMSE);

% ------------------------------------------------------------------ %
% 6. Create run context
% ------------------------------------------------------------------ %
runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = char(cfg.relaxRunName);
run    = createRunContext('relaxation', runCfg);
runDir = run.run_dir;

fprintf('Run directory:\n  %s\n', runDir);
appendText(run.log_path, sprintf('[%s] relaxation_temperature_scaling_test started\n', stampNow()));
appendText(run.log_path, sprintf('Source CSV: %s\n', csvPath));
appendText(run.log_path, sprintf('N_valid = %d\n', N_points));

% ------------------------------------------------------------------ %
% 7. Save fit table
% ------------------------------------------------------------------ %
fitTbl = table(alpha, a, R2, RMSE, N_points, ...
    'VariableNames', {'slope_alpha', 'intercept_a', 'R2', 'RMSE', 'N_points'});
tablePath = save_run_table(fitTbl, 'relaxation_temperature_scaling_fit.csv', runDir);
appendText(run.log_path, sprintf('Fit table: %s\n', tablePath));

% ------------------------------------------------------------------ %
% 8. Generate plots
% ------------------------------------------------------------------ %
figA = saveAvsT(T_K_valid, A_valid, runDir, 'A_vs_T');
appendText(run.log_path, sprintf('Figure A_vs_T: %s\n', figA.png));

figLogA = saveLogAvsLogT(logT, logA, logA_fit, alpha, a, R2, runDir, 'logA_vs_logT');
figLogAPath = figLogA.png;

appendText(run.log_path, sprintf('Figure logA_vs_logT: %s\n', figLogAPath));

% ------------------------------------------------------------------ %
% 9. Create report
% ------------------------------------------------------------------ %
reportText = buildReport(cfg, csvPath, N_points, T_K_valid, A_valid, alpha, a, R2, RMSE, run.run_id);
reportPath = save_run_report(reportText, 'relaxation_temperature_scaling_report.md', runDir);
appendText(run.log_path, sprintf('Report: %s\n', reportPath));

% ------------------------------------------------------------------ %
% 10. Build review ZIP
% ------------------------------------------------------------------ %
zipPath = buildReviewZip(runDir, 'relaxation_temperature_scaling_bundle.zip');
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

% Record key values in notes
appendText(run.notes_path, sprintf('alpha = %.6g\n', alpha));
appendText(run.notes_path, sprintf('R2    = %.6f\n', R2));
appendText(run.notes_path, sprintf('RMSE  = %.6g\n', RMSE));
appendText(run.notes_path, sprintf('N_points = %d\n', N_points));

appendText(run.log_path, sprintf('[%s] relaxation_temperature_scaling_test complete\n', stampNow()));

% ------------------------------------------------------------------ %
% Output struct
% ------------------------------------------------------------------ %
out = struct();
out.run         = run;
out.runDir      = string(runDir);
out.run_id      = string(run.run_id);
out.alpha       = alpha;
out.a           = a;
out.R2          = R2;
out.RMSE        = RMSE;
out.N_points    = N_points;
out.tablePath   = string(tablePath);
out.reportPath  = string(reportPath);
out.zipPath     = string(zipPath);
out.figures     = struct('A_vs_T', string(figA.png), 'logA_vs_logT', string(figLogAPath));

fprintf('\n--- Summary ---\n');
fprintf('RUN_ID:   %s\n', run.run_id);
fprintf('alpha:    %.6g\n', alpha);
fprintf('R2:       %.6f\n', R2);
fprintf('RMSE:     %.6g\n', RMSE);
fprintf('N_points: %d\n', N_points);
fprintf('Report:   %s\n', reportPath);
fprintf('ZIP:      %s\n\n', zipPath);
end

% ================================================================== %
% Local functions
% ================================================================== %

function tf = local_relaxation_temp_observables_ok(path)
if exist(path, 'file') ~= 2
    tf = false;
    return;
end
tbl = readtable(path);
vn = string(tbl.Properties.VariableNames);
hasT = any(vn == "T_K") || any(vn == "T");
hasA = any(vn == "A") || any(vn == "A_T");
tf = hasT && hasA && height(tbl) >= 3;
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',    'relaxation_temperature_scaling_test');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
end

function s = setDefaultField(s, field, val)
if ~isfield(s, field) || isempty(s.(field))
    s.(field) = val;
end
end

% ------------------------------------------------------------------
function figPaths = saveAvsT(T, A, runDir, figureName)
fh = newFigure([2 2 14 8], 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 14 8]);
ax = axes(fh);
plot(ax, T, A, '-o', ...
    'Color', [0 0 0], 'LineWidth', 1.8, 'MarkerSize', 5, ...
    'MarkerFaceColor', [0 0 0]);
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)');
ylabel(ax, 'Activity A');
title(ax, 'Relaxation activity A vs temperature');
set(ax, 'FontSize', 10, 'Box', 'on');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

% ------------------------------------------------------------------
function figPaths = saveLogAvsLogT(logT, logA, ~, alpha, a, R2, runDir, figureName)
fh = newFigure([2 2 14 9], 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 14 9]);
ax = axes(fh);
hold(ax, 'on');
plot(ax, logT, logA, 'o', ...
    'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], ...
    'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'data');
xFit = linspace(min(logT), max(logT), 200);
plot(ax, xFit, a + alpha .* xFit, '-', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.0, ...
    'DisplayName', sprintf('fit: alpha=%.4g', alpha));
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'log T');
ylabel(ax, 'log A');
title(ax, 'log A vs log T (power-law scaling test)');
set(ax, 'FontSize', 10, 'Box', 'on');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

% ------------------------------------------------------------------
function fig = newFigure(positionCm, visibilityMode)
if exist('create_figure', 'file') == 2
    fig = create_figure('Visible', visibilityMode, 'Position', positionCm);
else
    fig = figure('Visible', visibilityMode, 'Color', 'w', ...
        'Units', 'centimeters', 'Position', positionCm);
end
end

% ------------------------------------------------------------------
function reportText = buildReport(cfg, csvPath, N_points, T_K, A_in, alpha, a, R2, RMSE, runId) %#ok<INUSD>
T_min = min(T_K);
T_max = max(T_K);

if R2 >= 0.95
    interpretation = sprintf('Strong evidence for power-law scaling: A(T) ~ T^(%.4g) (R^2 = %.4f). The activity follows an approximate power law across the temperature range.', alpha, R2);
elseif R2 >= 0.80
    interpretation = sprintf('Moderate evidence for power-law scaling: A(T) ~ T^(%.4g) (R^2 = %.4f). The log-log trend is suggestive but not definitive; other functional forms should be considered.', alpha, R2);
elseif R2 >= 0.50
    interpretation = sprintf('Weak evidence for power-law scaling: A(T) ~ T^(%.4g) (R^2 = %.4f). The data show some trend in log-log space but scatter is substantial.', alpha, R2);
else
    interpretation = sprintf('No significant power-law scaling detected: A(T) ~ T^(%.4g) (R^2 = %.4f). A single power-law exponent does not describe A(T) well over this temperature range.', alpha, R2);
end

L = strings(0, 1);
L(end+1) = '# Relaxation temperature scaling test';
L(end+1) = '';
L(end+1) = sprintf('Generated: %s', stampNow());
L(end+1) = sprintf('Run ID: `%s`', runId);
L(end+1) = '';
L(end+1) = '## Data source';
L(end+1) = sprintf('- Source run: `%s`', char(cfg.relaxRunName));
L(end+1) = sprintf('- File: `%s`', csvPath);
L(end+1) = sprintf('- Temperature range: %.2f K to %.2f K', T_min, T_max);
L(end+1) = sprintf('- Valid points after removing NaN and A <= 0: **%d**', N_points);
L(end+1) = '';
L(end+1) = '## Method';
L(end+1) = '- Fit model: `log(A) = a + alpha * log(T)` (ordinary least squares).';
L(end+1) = '- This is equivalent to testing the power-law hypothesis `A(T) ~ T^alpha`.';
L(end+1) = '- All natural logarithms were used consistently.';
L(end+1) = '';
L(end+1) = '## Fit equation';
L(end+1) = sprintf('```');
L(end+1) = sprintf('log(A) = %.6g + %.6g * log(T)', a, alpha);
L(end+1) = sprintf('  ->   A(T) ~ T^(%.6g)', alpha);
L(end+1) = sprintf('```');
L(end+1) = '';
L(end+1) = '## Fit metrics';
L(end+1) = sprintf('| Metric | Value |');
L(end+1) = '|--------|-------|';
L(end+1) = sprintf('| alpha (exponent) | `%.6g` |', alpha);
L(end+1) = sprintf('| a (intercept of log fit) | `%.6g` |', a);
L(end+1) = sprintf('| R^2 | `%.6f` |', R2);
L(end+1) = sprintf('| RMSE (log units) | `%.6g` |', RMSE);
L(end+1) = sprintf('| N_points | `%d` |', N_points);
L(end+1) = '';
L(end+1) = '## Interpretation';
L(end+1) = interpretation;
L(end+1) = '';
L(end+1) = '## Figures';
L(end+1) = '- `figures/A_vs_T.png` - raw A(T) versus temperature.';
L(end+1) = '- `figures/logA_vs_logT.png` - log(A) versus log(T) with power-law fit overlaid.';
L(end+1) = '';
L(end+1) = '## Saved table';
L(end+1) = '- `tables/relaxation_temperature_scaling_fit.csv` - fit coefficients and quality metrics.';
L(end+1) = '';
L(end+1) = '## Notes';
L(end+1) = '- The test uses the saved `temperature_observables.csv` from the canonical relaxation stability audit run.';
L(end+1) = '- No new Relaxation data was imported; all values are read from the saved table.';
L(end+1) = '- The exponent alpha characterises the internal temperature sensitivity of the relaxation activity.';
L(end+1) = '- A positive alpha indicates activity increasing with temperature; negative alpha indicates the reverse.';

reportText = strjoin(L, newline);
end

% ------------------------------------------------------------------
function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if ~exist(reviewDir, 'dir')
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'tables', 'figures', 'reports'}, runDir);
end

% ------------------------------------------------------------------
function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
fprintf(fid, '%s', txt);
fclose(fid);
end

% ------------------------------------------------------------------
function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
