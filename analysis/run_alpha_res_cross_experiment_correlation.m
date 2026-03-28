function run_alpha_res_cross_experiment_correlation(varargin)
%RUN_ALPHA_RES_CROSS_EXPERIMENT_CORRELATION  Agent A — alpha_res cross-experiment correlation
%
% Aligns switching residual rank-1 amplitude kappa(T) (from switching residual decomposition)
% with alpha_res(T) (alpha decomposition) and LOOCV residuals from the best aging closure model
% (from tables/aging_alpha_closure_best_model.csv).
%
% Outputs (repo root):
%   tables/alpha_res_cross_correlation.csv
%   figures/alpha_res_cross_scatter.png|pdf|fig
%   reports/alpha_res_cross_experiment_report.md
%
% Name-value:
%   'repoRoot'           — default: parent of analysis/
%   'switchingKappaPath' — default: canonical residual-decomposition kappa_vs_T.csv
%   'masterPath'         — default: tables/aging_alpha_closure_master_table.csv
%   'bestModelPath'      — default: tables/aging_alpha_closure_best_model.csv

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'figures'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end

kapTbl = readtable(opts.switchingKappaPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T', 'kappa'}, kapTbl.Properties.VariableNames)), ...
    'switching kappa table must have T, kappa');
kapTbl.Properties.VariableNames{strcmp(kapTbl.Properties.VariableNames, 'T')} = 'T_K';

master = readtable(opts.masterPath, 'VariableNamingRule', 'preserve');
reqM = {'T_K', 'R', 'spread90_50', 'kappa1', 'kappa2', 'alpha', 'abs_alpha', ...
    'alpha_res', 'abs_alpha_res', 'alpha_geom'};
assert(all(ismember(reqM, master.Properties.VariableNames)), ...
    'aging_alpha_closure_master_table missing columns');

bestTbl = readtable(opts.bestModelPath, 'VariableNamingRule', 'preserve');
assert(ismember('best_overall_model', bestTbl.Properties.VariableNames), ...
    'best model table missing best_overall_model');
bestModel = char(string(bestTbl.best_overall_model(1)));

merged = innerjoin(master(:, [{'T_K'}, setdiff(reqM, {'T_K'}, 'stable')]), ...
    kapTbl(:, {'T_K', 'kappa'}), 'Keys', 'T_K');
merged = sortrows(merged, 'T_K');

% Predictor columns for best aging model (same naming as run_aging_alpha_closure_agent24f)
predCols = localModelToCols(bestModel);

m = true(height(merged), 1);
m = m & isfinite(double(merged.kappa(:)));
m = m & isfinite(double(merged.R(:)));
m = m & isfinite(double(merged.alpha_res(:)));
for c = 1:numel(predCols)
    col = predCols{c};
    m = m & isfinite(double(merged.(col)(:)));
end
sub = merged(m, :);
n = height(sub);
assert(n >= 5, 'alpha_res cross-experiment: insufficient aligned rows (n=%d).', n);

T_K = double(sub.T_K(:));
y = double(sub.R(:));
swK = double(sub.kappa(:));
swKabs = abs(swK);
aRes = double(sub.alpha_res(:));

yhat = localLooPred(sub, predCols);
agingRes = y - yhat;
absAgingRes = abs(agingRes);

% Correlations (complete-case on each pair; same n for all rows here)
pairs = {
    'switching_kappa_abs_vs_aging_loocv_residual', swKabs, agingRes
    'switching_kappa_abs_vs_abs_aging_loocv_residual', swKabs, absAgingRes
    'switching_kappa_abs_vs_alpha_res', swKabs, aRes
    'switching_kappa_vs_aging_loocv_residual', swK, agingRes
    'switching_kappa_vs_abs_aging_loocv_residual', swK, absAgingRes
    'switching_kappa_vs_alpha_res', swK, aRes
    };

corrRows = table();
for i = 1:size(pairs, 1)
    x = pairs{i, 2};
    z = pairs{i, 3};
    ok = isfinite(x) & isfinite(z);
    nn = nnz(ok);
    rP = corr(x(ok), z(ok), 'rows', 'complete');
    rS = corr(x(ok), z(ok), 'type', 'Spearman', 'rows', 'complete');
    corrRows = [corrRows; table({pairs{i, 1}}, nn, rP, rS, ...
        'VariableNames', {'comparison', 'n', 'pearson_r', 'spearman_r'})]; %#ok<AGROW>
end

rKappaMatch = localCorr(swK, double(sub.kappa1(:)));

writetable(corrRows, fullfile(repoRoot, 'tables', 'alpha_res_cross_correlation.csv'));

% Primary figure: 2x2 scatter
fig = create_figure('Name', 'alpha_res_cross_scatter', 'NumberTitle', 'off');
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
localScatter(nexttile, swKabs, agingRes, T_K, '|kappa_{sw}|', 'aging LOOCV residual');
localScatter(nexttile, swKabs, absAgingRes, T_K, '|kappa_{sw}|', '|aging LOOCV residual|');
localScatter(nexttile, swKabs, aRes, T_K, '|kappa_{sw}|', 'alpha_{res}');
localScatter(nexttile, aRes, agingRes, T_K, 'alpha_{res}', 'aging LOOCV residual');
figPath = save_run_figure(fig, 'alpha_res_cross_scatter', repoRoot);
close(fig);

verdict = localVerdict(corrRows);

rep = localBuildReport(repoRoot, opts, bestModel, predCols, n, T_K, ...
    swK, swKabs, aRes, agingRes, absAgingRes, corrRows, rKappaMatch, figPath, verdict);
fid = fopen(fullfile(repoRoot, 'reports', 'alpha_res_cross_experiment_report.md'), 'w');
fprintf(fid, '%s', rep);
fclose(fid);

fprintf(1, '\n=== Alpha_res cross-experiment correlation ===\n');
fprintf(1, 'n = %d  T_K: %s\n', n, strjoin(string(T_K(:)'), ', '));
fprintf(1, 'Best aging model: %s\n', bestModel);
fprintf(1, 'ALPHA_RES_SHARED_BETWEEN_EXPERIMENTS: %s\n', verdict);
fprintf(1, 'CSV: %s\n', fullfile(repoRoot, 'tables', 'alpha_res_cross_correlation.csv'));
fprintf(1, 'Report: %s\n', fullfile(repoRoot, 'reports', 'alpha_res_cross_experiment_report.md'));
end

%% ------------------------------------------------------------------------
function cols = localModelToCols(modelStr)
% Map "R ~ a + b + c" to master column names.
s = strtrim(strrep(modelStr, 'R ~', ''));
parts = strtrim(split(s, '+'));
cols = cell(numel(parts), 1);
for i = 1:numel(parts)
    tok = strtrim(parts{i});
    if strcmp(tok, 'abs(alpha)')
        cols{i} = 'abs_alpha';
    elseif strcmp(tok, 'abs(alpha_res)')
        cols{i} = 'abs_alpha_res';
    else
        cols{i} = char(string(tok));
    end
end
end

function yhat = localLooPred(sub, cols)
y = double(sub.R(:));
n = numel(y);
yhat = nan(n, 1);
if isempty(cols)
    for i = 1:n
        yhat(i) = mean(y(setdiff(1:n, i)));
    end
    return
end
X = zeros(n, numel(cols));
for c = 1:numel(cols)
    X(:, c) = double(sub.(cols{c})(:));
end
Z = [ones(n, 1), X];
if n <= size(Z, 2) || any(~isfinite(Z), 'all') || any(~isfinite(y)) || rank(Z) < size(Z, 2)
    return
end
for i = 1:n
    tr = setdiff(1:n, i);
    beta = Z(tr, :) \ y(tr);
    yhat(i) = Z(i, :) * beta;
end
end

function localScatter(ax, x, y, T_K, xlab, ylab)
scatter(ax, x, y, 70, 'filled', 'MarkerFaceAlpha', 0.85);
hold(ax, 'on');
grid(ax, 'on');
for k = 1:numel(T_K)
    text(ax, x(k), y(k), sprintf('  %g', T_K(k)), 'FontSize', 9, 'VerticalAlignment', 'bottom');
end
hold(ax, 'off');
xlabel(ax, xlab, 'Interpreter', 'tex', 'FontSize', 12);
ylabel(ax, ylab, 'Interpreter', 'tex', 'FontSize', 12);
end

function r = localCorr(a, b)
ok = isfinite(a) & isfinite(b);
if nnz(ok) < 3
    r = NaN;
else
    r = corr(a(ok), b(ok));
end
end

function v = localVerdict(corrRows)
% Heuristic verdict from primary comparisons (small n — interpret cautiously).
idx1 = strcmp(corrRows.comparison, 'switching_kappa_abs_vs_aging_loocv_residual');
idx2 = strcmp(corrRows.comparison, 'switching_kappa_abs_vs_abs_aging_loocv_residual');
idx3 = strcmp(corrRows.comparison, 'switching_kappa_abs_vs_alpha_res');
r1 = abs(corrRows.pearson_r(idx1));
r2 = abs(corrRows.pearson_r(idx2));
r3 = abs(corrRows.pearson_r(idx3));
m = max([r1, r2, r3], [], 'omitnan');
% Thresholds (small n, conservative): require |r|>=0.55 for YES on any primary pair.
if m >= 0.55
    v = "YES";
elseif m >= 0.30
    v = "PARTIAL";
else
    v = "NO";
end
end

function rep = localBuildReport(repoRoot, opts, bestModel, predCols, n, T_K, ...
    swK, swKabs, aRes, agingRes, absAgingRes, corrRows, rKappaMatch, figPath, verdict)

lines = strings(0, 1);
lines(end + 1) = "# Alpha_res cross-experiment correlation (Agent A)";
lines(end + 1) = "";
lines(end + 1) = "## Goal";
lines(end + 1) = "Test whether the switching-stack residual amplitude (rank-1 kappa from `switching_residual_decomposition_analysis`, tabulated as `kappa` in `kappa_vs_T.csv`) tracks the aging closure residual and/or `alpha_res` from PT geometry decomposition, on a common temperature grid.";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = sprintf("- **Switching residual amplitude:** `%s`", localRelPath(repoRoot, opts.switchingKappaPath));
lines(end + 1) = sprintf("- **Aging + alpha merge:** `%s`", localRelPath(repoRoot, opts.masterPath));
lines(end + 1) = sprintf("- **Best aging model (overall):** `%s` → predictors: **%s**", bestModel, strjoin(string(predCols), ', '));
lines(end + 1) = "";
lines(end + 1) = "## Alignment";
lines(end + 1) = sprintf("- **n (finite overlap):** %d", n);
lines(end + 1) = sprintf("- **T_K (K):** %s", strjoin(string(T_K(:)'), ', '));
lines(end + 1) = "";
lines(end + 1) = "## Identity check (pipeline consistency)";
lines(end + 1) = sprintf("- **Pearson(switching kappa, master kappa1):** %.6g (1.0 expected when decomposition uses the same ridge amplitude as `alpha_structure`.)", rKappaMatch);
lines(end + 1) = "";
lines(end + 1) = "## Aligned quantities (per T)";
lines(end + 1) = "| T_K | switching kappa (rank-1 res.) | alpha_res | aging LOOCV residual | |aging res.| |";
lines(end + 1) = "|---:|---:|---:|---:|---:|";
for k = 1:numel(T_K)
    lines(end + 1) = sprintf('| %g | %.6g | %.6g | %.6g | %.6g |', ...
        T_K(k), swK(k), aRes(k), agingRes(k), absAgingRes(k));
end
lines(end + 1) = "";
lines(end + 1) = "## Correlations";
lines(end + 1) = "| comparison | n | Pearson r | Spearman rho |";
lines(end + 1) = "|---|---:|---:|---:|";
for k = 1:height(corrRows)
    lines(end + 1) = sprintf('| %s | %d | %.6g | %.6g |', ...
        corrRows.comparison{k}, corrRows.n(k), corrRows.pearson_r(k), corrRows.spearman_r(k));
end
lines(end + 1) = "";
lines(end + 1) = "## Figure";
lines(end + 1) = "- `figures/alpha_res_cross_scatter.png` (PDF/FIG siblings written alongside)";
lines(end + 1) = "";
lines(end + 1) = "## Tables";
lines(end + 1) = "- `tables/alpha_res_cross_correlation.csv` — correlation summary";
lines(end + 1) = "";
lines(end + 1) = "## Interpretation notes";
lines(end + 1) = "- **Small n:** With n≈11, correlation magnitudes are indicative only; use alongside mechanistic audits.";
lines(end + 1) = "- **Kappa naming:** Decomposition `kappa` is the rank-1 amplitude of **delta S** after the PT-CDF term; when sourced from the default switching runs it matches `kappa1` in `alpha_structure` / master table (see identity check above).";
lines(end + 1) = "";
lines(end + 1) = "## Final verdict";
lines(end + 1) = sprintf('ALPHA_RES_SHARED_BETWEEN_EXPERIMENTS: **%s**', verdict);
lines(end + 1) = "";
lines(end + 1) = sprintf("_Generated: %s_", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

rep = join(lines, newline);
end

function r = localRelPath(repoRoot, absPath)
absPath = char(string(absPath));
repoRoot = char(string(repoRoot));
if isempty(repoRoot) || isempty(absPath)
    r = absPath;
    return
end
if length(absPath) >= length(repoRoot) && strcmpi(absPath(1:length(repoRoot)), repoRoot)
    k = length(repoRoot) + 1;
    if k <= length(absPath) && (absPath(k) == '\' || absPath(k) == '/')
        r = absPath(k + 1:end);
    else
        r = absPath;
    end
else
    r = absPath;
end
r = strrep(strrep(r, '\', '/'), '//', '/');
end

function opts = localParseOpts(varargin)
p = inputParser;
addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'switchingKappaPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'masterPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'bestModelPath', '', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;
thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
if strlength(string(opts.repoRoot)) == 0
    opts.repoRoot = fileparts(analysisDir);
end
opts.repoRoot = char(string(opts.repoRoot));
if strlength(string(opts.switchingKappaPath)) == 0
    opts.switchingKappaPath = fullfile(opts.repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_24_220314_residual_decomposition', 'tables', 'kappa_vs_T.csv');
end
opts.switchingKappaPath = char(string(opts.switchingKappaPath));
if strlength(string(opts.masterPath)) == 0
    opts.masterPath = fullfile(opts.repoRoot, 'tables', 'aging_alpha_closure_master_table.csv');
end
opts.masterPath = char(string(opts.masterPath));
if strlength(string(opts.bestModelPath)) == 0
    opts.bestModelPath = fullfile(opts.repoRoot, 'tables', 'aging_alpha_closure_best_model.csv');
end
opts.bestModelPath = char(string(opts.bestModelPath));
end
