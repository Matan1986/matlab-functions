function run_aging_kappa2_agent24g(varargin)
%RUN_AGING_KAPPA2_AGENT24G  Agent 24G — aging R(T): does κ2 add beyond spread90_50 + κ1? (LOOCV)
%
% Read-only inputs (same lineage as Agent 24B; no decomposition recompute):
%   barrier_descriptors.csv, energy_stats.csv, clock ratio table (lineage),
%   tables/alpha_structure.csv, tables/alpha_decomposition.csv
%
% Outputs under results/cross_experiment/runs/<run_id>/ (+ mirror):
%   tables/aging_kappa2_master_table.csv
%   tables/aging_kappa2_models.csv
%   tables/aging_kappa2_best_model.csv
%   tables/aging_kappa2_residuals.csv
%   figures/aging_kappa2_predictions.png|fig
%   figures/aging_kappa2_residuals_vs_T.png|fig
%   figures/aging_kappa2_transition_focus.png|fig
%   reports/aging_kappa2_report.md
%   review/*.zip
%
% Name-value: 'repoRoot', 'barrierPath', 'energyStatsPath', 'clockRatioPath',
%             'alphaStructurePath', 'decompPath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

runCfg = struct('runLabel', 'aging_kappa2_closure', ...
    'dataset', 'R(T) LOOCV: κ2 beyond spread90_50+κ1 (Agent 24G)');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

fprintf(1, 'Agent 24G run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] run_aging_kappa2_agent24g started\n', datestr(now, 31)));

%% Load inputs (mirror 24B merge; no trajectory columns required)
clkPath = opts.clockRatioPath;
assert(isfile(clkPath), 'Missing clock ratio table: %s', clkPath);

bar = readtable(opts.barrierPath, 'VariableNamingRule', 'preserve');
en = readtable(opts.energyStatsPath, 'VariableNamingRule', 'preserve');
if ismember('T', en.Properties.VariableNames) && ~ismember('T_K', en.Properties.VariableNames)
    en.Properties.VariableNames{'T'} = 'T_K';
end
assert(ismember('T_K', en.Properties.VariableNames), 'energy_stats needs T_K or T column');
en = en(:, intersect({'T_K', 'mean_E', 'std_E'}, en.Properties.VariableNames, 'stable'));

bar = innerjoin(bar, en, 'Keys', 'T_K');
bar.spread90_50 = double(bar.q90_I_mA) - double(bar.q50_I_mA);

reqB = {'T_K', 'row_valid', 'R_T_interp', 'spread90_50', 'q90_I_mA', 'q50_I_mA'};
for k = 1:numel(reqB)
    assert(ismember(reqB{k}, bar.Properties.VariableNames), 'barrier_descriptors missing %s', reqB{k});
end

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
aD = readtable(opts.decompPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, aS.Properties.VariableNames)), ...
    'alpha_structure missing kappa/alpha columns');
assert(all(ismember({'T_K', 'PT_geometry_valid'}, aD.Properties.VariableNames)), ...
    'alpha_decomposition missing PT_geometry_valid');

merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    aD(:, {'T_K', 'PT_geometry_valid'}), 'Keys', 'T_K');

bCols = intersect(reqB, bar.Properties.VariableNames, 'stable');
merged = innerjoin(merged, bar(:, bCols), 'Keys', 'T_K');

merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
merged = merged(double(merged.row_valid) ~= 0, :);
merged = sortrows(merged, 'T_K');

T_K = double(merged.T_K(:));
R = double(merged.R_T_interp(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
spread90_50 = double(merged.spread90_50(:));
abs_k2 = abs(k2);

nMerge = numel(T_K);
mOverlap = isfinite(R) & isfinite(spread90_50) & isfinite(k1) & isfinite(k2);
nOverlap = nnz(mOverlap);
assert(nOverlap >= 5, 'Agent24G: insufficient finite overlap rows (n=%d).', nOverlap);

master = table(T_K, R, spread90_50, k1, k2, abs_k2, alp, ...
    'VariableNames', {'T_K', 'R', 'spread90_50', 'kappa1', 'kappa2', 'abs_kappa2', 'alpha'});

masterOut = master(mOverlap, :);
save_run_table(masterOut, 'aging_kappa2_master_table.csv', runDir);

y = R(mOverlap);
Tplot = T_K(mOverlap);
n = numel(y);

%% Model definitions: cols in masterOut (empty = intercept-only)
pred = struct('id', {}, 'category', {}, 'cols', {});
pred(end + 1) = struct('id', 'R ~ 1', 'category', 'baseline', 'cols', {{}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50', 'category', 'PT', 'cols', {{'spread90_50'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa1', 'category', 'state', 'cols', {{'kappa1'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa2', 'category', 'state', 'cols', {{'kappa2'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1', 'category', 'PT+state', 'cols', {{'spread90_50', 'kappa1'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa2', 'category', 'PT+state', 'cols', {{'spread90_50', 'kappa2'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa1 + kappa2', 'category', 'state2D', 'cols', {{'kappa1', 'kappa2'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + kappa2', 'category', 'PT+state2D', ...
    'cols', {{'spread90_50', 'kappa1', 'kappa2'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + abs_kappa2', 'category', 'PT+state', 'cols', {{'spread90_50', 'abs_kappa2'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + abs_kappa2', 'category', 'PT+state2D', ...
    'cols', {{'spread90_50', 'kappa1', 'abs_kappa2'}}); %#ok<AGROW>
% Comparable α proxy (same rows; alpha from alpha_structure)
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha', 'category', 'PT+state+alpha', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha'}}); %#ok<AGROW>

rows = table();
yhatStore = struct();

for k = 1:numel(pred)
    if isempty(pred(k).cols)
        [rmse, rP, rS, yhat] = localLoocvMean(y);
    else
        X = zeros(n, numel(pred(k).cols));
        ok = true(n, 1);
        for c = 1:numel(pred(k).cols)
            v = masterOut.(pred(k).cols{c});
            X(:, c) = v(:);
            ok = ok & isfinite(X(:, c));
        end
        if ~all(ok)
            rmse = NaN; rP = NaN; rS = NaN; yhat = nan(n, 1);
        else
            [rmse, rP, rS, yhat] = localLoocvOls(y, X);
        end
    end
    rows = [rows; table({pred(k).id}, {pred(k).category}, n, rmse, rP, rS, ...
        'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat'})]; %#ok<AGROW>
    fn = localModelFieldName(pred(k).id);
    yhatStore.(fn) = yhat;
end

save_run_table(rows, 'aging_kappa2_models.csv', runDir);

%% Best non-baseline model
mskNonBase = ~strcmp(rows.model, 'R ~ 1');
subRows = rows(mskNonBase, :);
[bestRmse, jBest] = min(subRows.loocv_rmse, [], 'omitnan');
if isempty(jBest) || ~isfinite(bestRmse)
    error('Agent24G: no valid best model.');
end
bestModelStr = subRows.model{jBest};
bestYhat = yhatStore.(localModelFieldName(bestModelStr));

bestTbl = localBuildBestTable(rows, bestModelStr, bestRmse, y, Tplot, masterOut);

%% Residuals table (reference, main κ2 test, best)
idRef = 'R ~ spread90_50 + kappa1';
idK2 = 'R ~ spread90_50 + kappa1 + kappa2';
residualsLong = localResidualsLong(Tplot, y, {idRef, idK2, bestModelStr}, yhatStore);
save_run_table(residualsLong, 'aging_kappa2_residuals.csv', runDir);

%% Transition diagnostics
mae = struct();
mae.ref_22 = localMeanAbsRes(Tplot, y, yhatStore.(localModelFieldName(idRef)), @(t) t >= 22 & t <= 24);
mae.ref_out = localMeanAbsRes(Tplot, y, yhatStore.(localModelFieldName(idRef)), @(t) ~(t >= 22 & t <= 24));
mae.k2_22 = localMeanAbsRes(Tplot, y, yhatStore.(localModelFieldName(idK2)), @(t) t >= 22 & t <= 24);
mae.k2_out = localMeanAbsRes(Tplot, y, yhatStore.(localModelFieldName(idK2)), @(t) ~(t >= 22 & t <= 24));
mae.best_22 = localMeanAbsRes(Tplot, y, bestYhat, @(t) t >= 22 & t <= 24);
mae.best_out = localMeanAbsRes(Tplot, y, bestYhat, @(t) ~(t >= 22 & t <= 24));

rmseRef = rows.loocv_rmse(strcmp(rows.model, idRef), 1);
rmseK2 = rows.loocv_rmse(strcmp(rows.model, idK2), 1);
rmseK1only = rows.loocv_rmse(strcmp(rows.model, 'R ~ kappa1'), 1);
rmseK1K2 = rows.loocv_rmse(strcmp(rows.model, 'R ~ kappa1 + kappa2'), 1);
rmseAlpha = rows.loocv_rmse(strcmp(rows.model, 'R ~ spread90_50 + kappa1 + alpha'), 1);

verd = localVerdicts(rmseRef, rmseK2, rmseK1only, rmseK1K2, mae, bestModelStr, rmseAlpha);

bestTbl.KAPPA2_IMPROVES_AGING_PREDICTION = repmat(string(verd.KAPPA2_IMPROVES_AGING_PREDICTION), height(bestTbl), 1);
bestTbl.SECOND_MODE_REQUIRED = repmat(string(verd.SECOND_MODE_REQUIRED), height(bestTbl), 1);
bestTbl.TRANSITION_REGION_EXPLAINED_BY_KAPPA2 = repmat(string(verd.TRANSITION_REGION_EXPLAINED_BY_KAPPA2), height(bestTbl), 1);
bestTbl.TWO_DIMENSIONAL_STATE_SUPPORTED = repmat(string(verd.TWO_DIMENSIONAL_STATE_SUPPORTED), height(bestTbl), 1);
bestTbl.KAPPA2_OUTPERFORMS_ALPHA_PROXY = repmat(string(verd.KAPPA2_OUTPERFORMS_ALPHA_PROXY), height(bestTbl), 1);
save_run_table(bestTbl, 'aging_kappa2_best_model.csv', runDir);

%% Figures (prediction panels use main κ2 test model; not the optional α proxy)
yhatMainK2 = yhatStore.(localModelFieldName(idK2));

fig1 = create_figure('Name', 'aging_kappa2_predictions', 'NumberTitle', 'off');
ax = axes(fig1);
scatter(ax, y, yhatMainK2, 90, Tplot, 'filled', 'LineWidth', 1.5);
hold(ax, 'on');
lim = [min([y; yhatMainK2], [], 'omitnan'), max([y; yhatMainK2], [], 'omitnan')];
if isfinite(lim(1)) && isfinite(lim(2)) && lim(2) > lim(1)
    plot(ax, lim, lim, 'k--', 'LineWidth', 2);
end
hold(ax, 'off');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
grid(ax, 'on');
xlabel(ax, 'R measured (clock ratio, interp)', 'FontSize', 14);
ylabel(ax, 'R LOOCV prediction (spread90_50 + kappa1 + kappa2)', 'FontSize', 14);
set(ax, 'FontSize', 14);
figPath1 = localTrySaveRunFigure(fig1, 'aging_kappa2_predictions', runDir);
close(fig1);

resBest = y - yhatMainK2;
fig2 = create_figure('Name', 'aging_kappa2_residuals_vs_T', 'NumberTitle', 'off');
ax2 = axes(fig2);
plot(ax2, Tplot, resBest, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.45 0.7]);
hold(ax2, 'on');
yline(ax2, 0, 'k--', 'LineWidth', 1.5);
xl = [22, 24];
yr = max(abs(resBest), [], 'omitnan');
if ~isfinite(yr) || yr <= 0, yr = 1; end
patch(ax2, [xl(1) xl(2) xl(2) xl(1)], yr * [1 1 -1 -1], [1 0.85 0.85], ...
    'FaceAlpha', 0.35, 'EdgeColor', 'none');
hold(ax2, 'off');
xlabel(ax2, 'T (K)', 'FontSize', 14);
ylabel(ax2, 'Residual R (meas - LOOCV pred)', 'FontSize', 14);
grid(ax2, 'on');
set(ax2, 'FontSize', 14);
figPath2 = localTrySaveRunFigure(fig2, 'aging_kappa2_residuals_vs_T', runDir);
close(fig2);

resRef = y - yhatStore.(localModelFieldName(idRef));
resK2m = y - yhatStore.(localModelFieldName(idK2));
ymax = max([abs(resRef); abs(resK2m)], [], 'omitnan');
if ~isfinite(ymax) || ymax <= 0, ymax = 1; end
fig3 = create_figure('Name', 'aging_kappa2_transition_focus', 'NumberTitle', 'off');
ax3 = axes(fig3);
hold(ax3, 'on');
patch(ax3, [22 24 24 22], [0 ymax ymax 0] * 1.05, ...
    [1 0.9 0.9], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax3, Tplot, abs(resRef), 's-', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', '|res| PT + kappa1');
plot(ax3, Tplot, abs(resK2m), 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '|res| PT + kappa1 + kappa2');
xline(ax3, 22, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(ax3, 24, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
hold(ax3, 'off');
xlabel(ax3, 'T (K)', 'FontSize', 14);
ylabel(ax3, '|residual| (LOOCV)', 'FontSize', 14);
legend(ax3, 'Location', 'best', 'Interpreter', 'none');
grid(ax3, 'on');
set(ax3, 'FontSize', 14);
figPath3 = localTrySaveRunFigure(fig3, 'aging_kappa2_transition_focus', runDir);
close(fig3);

%% Report
rep = localBuildReport(runDir, opts, masterOut, rows, bestTbl, verd, mae, ...
    rmseRef, rmseK2, rmseK1only, rmseK1K2, rmseAlpha, Tplot, resBest, ...
    figPath1, figPath2, figPath3, clkPath, idRef, idK2, bestModelStr);
save_run_report(rep, 'aging_kappa2_report.md', runDir);

zipPath = localBuildZip(runDir);
appendText(run.log_path, sprintf('[%s] complete; zip=%s\n', datestr(now, 31), zipPath));

%% Mirror to repo root
mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end
try
    copyfile(fullfile(runDir, 'tables', 'aging_kappa2_models.csv'), fullfile(mirrorTables, 'aging_kappa2_models.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_kappa2_best_model.csv'), fullfile(mirrorTables, 'aging_kappa2_best_model.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_kappa2_residuals.csv'), fullfile(mirrorTables, 'aging_kappa2_residuals.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_kappa2_master_table.csv'), fullfile(mirrorTables, 'aging_kappa2_master_table.csv'));
    copyfile(fullfile(runDir, 'reports', 'aging_kappa2_report.md'), fullfile(mirrorRep, 'aging_kappa2_report.md'));
    localMirrorIfExists(figPath1.png, fullfile(mirrorFigs, 'aging_kappa2_predictions.png'));
    localMirrorIfExists(figPath2.png, fullfile(mirrorFigs, 'aging_kappa2_residuals_vs_T.png'));
    localMirrorIfExists(figPath3.png, fullfile(mirrorFigs, 'aging_kappa2_transition_focus.png'));
catch ME
    fprintf(2, 'Mirror copy skipped: %s\n', ME.message);
end

fprintf(1, 'Agent 24G complete. Report: %s\n', fullfile(runDir, 'reports', 'aging_kappa2_report.md'));
fprintf(1, 'Verdicts: KAPPA2_IMPROVES=%s SECOND_MODE_REQUIRED=%s TRANSITION_K2=%s 2D_STATE=%s K2_vs_ALPHA=%s\n', ...
    char(verd.KAPPA2_IMPROVES_AGING_PREDICTION), char(verd.SECOND_MODE_REQUIRED), ...
    char(verd.TRANSITION_REGION_EXPLAINED_BY_KAPPA2), char(verd.TWO_DIMENSIONAL_STATE_SUPPORTED), ...
    char(verd.KAPPA2_OUTPERFORMS_ALPHA_PROXY));
end

%% ------------------------------------------------------------------------
function fn = localModelFieldName(modelId)
fn = matlab.lang.makeValidName(['m_' char(strrep(modelId, ' ', '_'))]);
end

function tbl = localResidualsLong(T_K, y, modelIds, yhatStore)
blocks = {};
for i = 1:numel(modelIds)
    mid = modelIds{i};
    yh = yhatStore.(localModelFieldName(mid));
    blocks{end + 1} = table(repmat({mid}, numel(T_K), 1), T_K(:), y(:), yh(:), y(:) - yh(:), ...
        'VariableNames', {'model', 'T_K', 'R', 'yhat_loocv', 'residual'}); %#ok<AGROW>
end
tbl = vertcat(blocks{:});
end

function m = localMeanAbsRes(T, y, yhat, maskFn)
msk = maskFn(T) & isfinite(T(:)) & isfinite(y(:)) & isfinite(yhat(:));
if ~any(msk)
    m = NaN;
else
    m = mean(abs(y(msk) - yhat(msk)), 'omitnan');
end
end

function bestTbl = localBuildBestTable(rows, bestModelStr, bestRmse, y, Tplot, masterOut)
idx = find(strcmp(rows.model, bestModelStr), 1);
pear = rows.pearson_y_yhat(idx);
spear = rows.spearman_y_yhat(idx);
Tstr = mat2str(Tplot(:)', 4);
bestTbl = table(string(bestModelStr), bestRmse, pear, spear, ...
    height(masterOut), string(Tstr), ...
    'VariableNames', {'best_model', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', 'n_rows', 'temperatures_K'});
end

function v = localVerdicts(rmseRef, rmseK2, rmseK1only, rmseK1K2, mae, bestModelStr, rmseAlpha)
v = struct();
% KAPPA2_IMPROVES: adding κ2 to PT+κ1 lowers LOOCV RMSE
if isfinite(rmseRef) && isfinite(rmseK2) && rmseK2 < rmseRef - 1e-9
    v.KAPPA2_IMPROVES_AGING_PREDICTION = "YES";
else
    v.KAPPA2_IMPROVES_AGING_PREDICTION = "NO";
end

% SECOND_MODE_REQUIRED: winning model includes kappa2 (signed or abs)
if contains(bestModelStr, 'kappa2') || contains(bestModelStr, 'abs_kappa2')
    v.SECOND_MODE_REQUIRED = "YES";
else
    v.SECOND_MODE_REQUIRED = "NO";
end

% TRANSITION: mean |res| in 22–24 drops meaningfully vs PT+κ1
relDrop = (mae.ref_22 - mae.k2_22) / max(mae.ref_22, 1e-12);
if isfinite(mae.ref_22) && isfinite(mae.k2_22) && mae.ref_22 > 0 && relDrop >= 0.10
    v.TRANSITION_REGION_EXPLAINED_BY_KAPPA2 = "YES";
elseif isfinite(mae.ref_22) && isfinite(mae.k2_22) && mae.k2_22 < mae.ref_22 - 1e-9
    v.TRANSITION_REGION_EXPLAINED_BY_KAPPA2 = "PARTIAL";
else
    v.TRANSITION_REGION_EXPLAINED_BY_KAPPA2 = "NO";
end

% TWO_DIMENSIONAL_STATE: κ1+κ2 beats κ1 alone
if isfinite(rmseK1only) && isfinite(rmseK1K2) && rmseK1K2 < rmseK1only - 1e-9
    v.TWO_DIMENSIONAL_STATE_SUPPORTED = "YES";
elseif isfinite(rmseK1only) && isfinite(rmseK1K2) && rmseK1K2 < rmseK1only
    v.TWO_DIMENSIONAL_STATE_SUPPORTED = "PARTIAL";
else
    v.TWO_DIMENSIONAL_STATE_SUPPORTED = "NO";
end

% vs α proxy
if ~isfinite(rmseAlpha)
    v.KAPPA2_OUTPERFORMS_ALPHA_PROXY = "N/A (alpha not finite on overlap)";
elseif isfinite(rmseK2) && rmseK2 < rmseAlpha - 1e-9
    v.KAPPA2_OUTPERFORMS_ALPHA_PROXY = "YES";
elseif isfinite(rmseK2) && rmseK2 > rmseAlpha + 1e-9
    v.KAPPA2_OUTPERFORMS_ALPHA_PROXY = "NO";
else
    v.KAPPA2_OUTPERFORMS_ALPHA_PROXY = "TIE";
end
end

function txt = localBuildReport(runDir, opts, masterOut, rows, bestTbl, verd, mae, ...
    rmseRef, rmseK2, rmseK1only, rmseK1K2, rmseAlpha, Tplot, resBest, ...
    figPath1, figPath2, figPath3, clkPath, idRef, idK2, bestModelStr)

lines = {};
lines{end + 1} = '# Aging closure with second mode κ2 (Agent 24G)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## 1. Hypothesis';
lines{end + 1} = 'Test whether the second collective amplitude κ2 adds cross-validated predictive power for aging **R(T)** beyond the reference **R ~ spread90_50 + κ1**, using only raw PT geometry and κ state (no α decomposition, no residual construction).';
lines{end + 1} = '';
lines{end + 1} = '## 2. Data lineage';
lines{end + 1} = sprintf('- **R(T):** `R_T_interp` on the PT grid; clock table (lineage): `%s`', strrep(clkPath, '\', '/'));
lines{end + 1} = sprintf('- **PT geometry:** `spread90_50` from `barrier_descriptors.csv`: `%s`', strrep(opts.barrierPath, '\', '/'));
lines{end + 1} = sprintf('- **mean_E/std_E join:** `%s` (same merge as Agent 24B; spread uses quantile columns)', strrep(opts.energyStatsPath, '\', '/'));
lines{end + 1} = sprintf('- **State:** `kappa1`, `kappa2`, `alpha` from `%s`; gate `%s` (`PT_geometry_valid`, `row_valid`)', ...
    strrep(opts.alphaStructurePath, '\', '/'), strrep(opts.decompPath, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## 3. Fair comparison (overlap)';
lines{end + 1} = sprintf('- **Single common overlap:** all models use the same **n = %d** rows with finite `R`, `spread90_50`, `kappa1`, `kappa2`, after geometry and row-valid gates.', height(masterOut));
lines{end + 1} = sprintf('- **Temperatures (K):** `%s`', mat2str(Tplot(:)', 4));
lines{end + 1} = '';
lines{end + 1} = '## 4. Results (LOOCV)';
lines{end + 1} = '| model | category | n | LOOCV RMSE | Pearson | Spearman |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|';
for k = 1:height(rows)
    lines{end + 1} = sprintf('| %s | %s | %d | %.6g | %.6g | %.6g |', ...
        rows.model{k}, rows.category{k}, rows.n(k), rows.loocv_rmse(k), ...
        rows.pearson_y_yhat(k), rows.spearman_y_yhat(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = sprintf('- **Reference (PT+κ1) LOOCV RMSE:** %.6g', rmseRef);
lines{end + 1} = sprintf('- **Main test (PT+κ1+κ2) LOOCV RMSE:** %.6g', rmseK2);
lines{end + 1} = sprintf('- **State-only:** κ1 alone RMSE = %.6g; κ1+κ2 RMSE = %.6g', rmseK1only, rmseK1K2);
if isfinite(rmseAlpha)
    lines{end + 1} = sprintf('- **α proxy (PT+κ1+α) LOOCV RMSE:** %.6g (same rows)', rmseAlpha);
end
lines{end + 1} = '';
lines{end + 1} = '## Transition analysis (22–24 K)';
lines{end + 1} = sprintf('| model | mean |res| 22–24 K | mean |res| other T |');
lines{end + 1} = '|---|---:|---:|';
lines{end + 1} = sprintf('| %s | %.6g | %.6g |', idRef, mae.ref_22, mae.ref_out);
lines{end + 1} = sprintf('| %s | %.6g | %.6g |', idK2, mae.k2_22, mae.k2_out);
lines{end + 1} = sprintf('| **best: %s** | %.6g | %.6g |', bestModelStr, mae.best_22, mae.best_out);
lines{end + 1} = '';
lines{end + 1} = '## 5. Interpretation';
lines{end + 1} = 'Verdicts follow the Agent 24G brief. **TRANSITION_REGION_EXPLAINED_BY_KAPPA2 = PARTIAL** applies only if mean |residual| in 22–24 K decreases with κ2 but by less than 10% relative to PT+κ1 in that window.';
lines{end + 1} = '';
lines{end + 1} = '## 6. Final conclusion';
improves = char(verd.KAPPA2_IMPROVES_AGING_PREDICTION);
if strcmp(improves, 'YES')
    lines{end + 1} = '**Adding κ2 improves global LOOCV RMSE** relative to spread90_50 + κ1 on this overlap.';
else
    lines{end + 1} = '**Adding κ2 does not improve global LOOCV RMSE** relative to spread90_50 + κ1 on this overlap.';
end
lines{end + 1} = '';
lines{end + 1} = '## Figures';
lines{end + 1} = '- **aging_kappa2_predictions / residuals_vs_T:** observed vs LOOCV for the **main κ2 test** `R ~ spread90_50 + kappa1 + kappa2` (not necessarily the lowest-RMSE model overall).';
lines{end + 1} = '- **aging_kappa2_transition_focus:** |LOOCV residual| for `PT+kappa1` vs `PT+kappa1+kappa2`.';
lines{end + 1} = localFigLine(figPath1, 'aging_kappa2_predictions');
lines{end + 1} = localFigLine(figPath2, 'aging_kappa2_residuals_vs_T');
lines{end + 1} = localFigLine(figPath3, 'aging_kappa2_transition_focus');
lines{end + 1} = '';
lines{end + 1} = '## Required verdicts';
lines{end + 1} = sprintf('- **KAPPA2_IMPROVES_AGING_PREDICTION:** **%s**', char(verd.KAPPA2_IMPROVES_AGING_PREDICTION));
lines{end + 1} = sprintf('- **SECOND_MODE_REQUIRED:** **%s**', char(verd.SECOND_MODE_REQUIRED));
lines{end + 1} = sprintf('- **TRANSITION_REGION_EXPLAINED_BY_KAPPA2:** **%s**', char(verd.TRANSITION_REGION_EXPLAINED_BY_KAPPA2));
lines{end + 1} = sprintf('- **TWO_DIMENSIONAL_STATE_SUPPORTED:** **%s**', char(verd.TWO_DIMENSIONAL_STATE_SUPPORTED));
lines{end + 1} = sprintf('- **KAPPA2_OUTPERFORMS_ALPHA_PROXY:** **%s**', char(verd.KAPPA2_OUTPERFORMS_ALPHA_PROXY));
lines{end + 1} = '';
lines{end + 1} = '## Best model summary';
lines{end + 1} = sprintf('- **Best LOOCV model:** `%s` (RMSE = %.6g, n = %d)', ...
    char(bestTbl.best_model(1)), bestTbl.loocv_rmse(1), bestTbl.n_rows(1));
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_kappa2_agent24g.m`.*';

txt = strjoin(lines, newline);
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'aging_kappa2_agent24g_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0, fwrite(fid, txt); fclose(fid); end
end

function paths = localTrySaveRunFigure(fig, baseName, runDir)
paths = struct('png', '', 'pdf', '', 'fig', '');
try
    paths = save_run_figure(fig, baseName, runDir);
catch ME
    fprintf(2, 'save_run_figure failed for %s: %s\n', baseName, ME.message);
end
end

function localMirrorIfExists(src, dst)
if (ischar(src) || isstring(src)) && strlength(string(src)) > 0 && exist(char(string(src)), 'file') == 2
    copyfile(char(string(src)), dst);
end
end

function s = localFigLine(figPathStruct, label)
p = '';
if isstruct(figPathStruct) && isfield(figPathStruct, 'png')
    p = char(string(figPathStruct.png));
end
if ~isempty(p) && exist(p, 'file') == 2
    s = sprintf('- `%s`', strrep(p, '\', '/'));
else
    s = sprintf('- **%s:** (PNG not written — see run `figures/` for PDF/FIG or re-run with display)', label);
end
end

function [rmse, rP, rS, yhat] = localLoocvMean(y)
y = double(y(:));
n = numel(y);
yhat = nan(n, 1);
if n < 2
    rmse = NaN; rP = NaN; rS = NaN; return
end
for i = 1:n
    yhat(i) = mean(y(setdiff(1:n, i)));
end
rmse = sqrt(mean((y - yhat).^2));
rP = corr(y, yhat, 'rows', 'complete');
rS = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
end

function [rmse, rP, rS, yhat] = localLoocvOls(y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);
rmse = NaN;
rP = NaN;
rS = NaN;
Z = [ones(n, 1), X];
if n <= p + 1 || any(~isfinite(Z), 'all') || any(~isfinite(y))
    return
end
if rank(Z) < size(Z, 2)
    return
end
beta = Z \ y;
yfit = Z * beta;
e = y - yfit;
H = Z * ((Z' * Z) \ Z');
h = diag(H);
loo = e ./ max(1 - h, 1e-12);
yhat = y - loo;
rmse = sqrt(mean(loo.^2));
rP = corr(y, yhat, 'rows', 'complete');
rS = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.barrierPath = fullfile(opts.repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
opts.energyStatsPath = fullfile(opts.repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_24_233256_energy_mapping', 'tables', 'energy_stats.csv');
opts.clockRatioPath = fullfile(opts.repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_14_074613_aging_clock_ratio_analysis', 'tables', 'table_clock_ratio.csv');
opts.alphaStructurePath = fullfile(opts.repoRoot, 'tables', 'alpha_structure.csv');
opts.decompPath = fullfile(opts.repoRoot, 'tables', 'alpha_decomposition.csv');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "barrierpath"
            opts.barrierPath = char(string(val));
        case "energystatspath"
            opts.energyStatsPath = char(string(val));
        case "clockratiopath"
            opts.clockRatioPath = char(string(val));
        case "alphastructurepath"
            opts.alphaStructurePath = char(string(val));
        case "decomppath"
            opts.decompPath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
end
