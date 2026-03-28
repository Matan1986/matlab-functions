function out = run_A_prediction_from_switching_agent24a(cfg)
%RUN_A_PREDICTION_FROM_SWITCHING_AGENT24A
% Agent 24A: LOOCV predictive test of relaxation A(T) from PT/barrier descriptors.
% Reuses canonical barrier_descriptors merge (no PT recompute).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

cfg = applyAgent24aDefaults(cfg, repoRoot);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('barrier_merge:%s | alpha:%s', cfg.barrierRunId, cfg.alphaTableTag);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
ensureAgent24aSubdirs(runDir);

fprintf('Agent 24A run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_A_prediction_from_switching_agent24a started\n', stampNow()));
appendText(run.log_path, sprintf('Barrier descriptors: %s\n', cfg.barrierDescriptorsPath));
appendText(run.log_path, sprintf('Alpha table: %s\n', cfg.alphaStructurePath));

tbl = readtable(cfg.barrierDescriptorsPath, 'VariableNamingRule', 'preserve');
alphaTbl = readtable(cfg.alphaStructurePath, 'VariableNamingRule', 'preserve');
alphaJoin = alphaTbl(:, {'T_K', 'kappa1', 'alpha'});
merged = innerjoin(tbl, alphaJoin, 'Keys', 'T_K');

y = merged.A_T_interp(:);
T_K = merged.T_K(:);
use = merged.row_valid(:) & isfinite(y);
for k = 1:numel(cfg.ptFeaturePool)
    fn = cfg.ptFeaturePool{k};
    if ~ismember(fn, merged.Properties.VariableNames)
        error('Missing PT feature column: %s', fn);
    end
    use = use & isfinite(merged.(fn)(:));
end
use = use & isfinite(merged.kappa1(:)) & isfinite(merged.alpha(:));

merged = merged(use, :);
y = merged.A_T_interp(:);
T_K = merged.T_K(:);
n = numel(y);

if n < 5
    error('Agent24a: insufficient overlap after filtering (n=%d).', n);
end

Xpt = table2array(merged(:, cfg.ptFeaturePool));
Xpt = double(Xpt);
kappa1 = double(merged.kappa1(:));
alpha = double(merged.alpha(:));

%% GROUP 1 — Naive mean LOOCV
yhat_naive = loocvMeanPredictor(y);
rmse_naive = sqrt(mean((y - yhat_naive).^2));
rP_naive = corrSafe(y, yhat_naive, 'Pearson');
rS_naive = corrSafe(y, yhat_naive, 'Spearman');

%% GROUP 2 — register single-feature PT metrics (descriptive, in-sample lin)
rowsG2 = table();
for k = 1:size(Xpt, 2)
    name = string(cfg.ptFeaturePool{k});
    xk = Xpt(:, k);
    mask = isfinite(y) & isfinite(xk);
    b = [ones(sum(mask), 1), xk(mask)] \ y(mask);
    yin = [ones(sum(mask), 1), xk(mask)] * b;
    rowsG2 = [rowsG2; table(name, sum(mask), corrSafe(y(mask), xk(mask), 'Pearson'), ...
        corrSafe(y(mask), xk(mask), 'Spearman'), sqrt(mean((y(mask) - yin).^2)), ...
        'VariableNames', {'feature', 'n', 'pearson_xy', 'spearman_xy', 'rmse_insample_ls'})]; %#ok<AGROW>
end

%% GROUP 3 — best small PT-only model (LOOCV)
best1 = pickBestPtSubset(y, Xpt, cfg.ptFeaturePool, 1);
best2 = pickBestPtSubset(y, Xpt, cfg.ptFeaturePool, 2);
if best2.rmse_loocv < best1.rmse_loocv * (1 - cfg.twoVarImprovementMin)
    ptBest = best2;
else
    ptBest = best1;
end
if isempty(ptBest.idx) || ~isfinite(ptBest.rmse_loocv)
    error('Agent24a: failed to select a PT-only LOOCV model (check feature validity).');
end

yhat_pt = loocvLinearPredictor(y, Xpt(:, ptBest.idx));
rmse_pt = sqrt(mean((y - yhat_pt).^2));
rP_pt = corrSafe(y, yhat_pt, 'Pearson');
rS_pt = corrSafe(y, yhat_pt, 'Spearman');
imp_pt_vs_naive = (rmse_naive - rmse_pt) / max(rmse_naive, eps);

%% GROUP 4 — PT best + state (LOOCV)
ext_k = extendPtWithState(y, Xpt, ptBest.idx, kappa1, cfg.ptFeaturePool, "kappa1");
ext_a = extendPtWithState(y, Xpt, ptBest.idx, alpha, cfg.ptFeaturePool, "alpha");
if ext_k.rmse_loocv <= ext_a.rmse_loocv
    stateBest = ext_k;
    stateName = 'kappa1';
else
    stateBest = ext_a;
    stateName = 'alpha';
end
if ~all(isfinite(stateBest.yhat))
    stateBest = ext_k;
    stateName = 'kappa1';
    if ~all(isfinite(stateBest.yhat))
        stateBest = ext_a;
        stateName = 'alpha';
    end
end
if ~all(isfinite(stateBest.yhat))
    stateBest = struct('rmse_loocv', rmse_pt, 'yhat', yhat_pt, 'formula', string(ptBest.formula));
    stateName = 'none_fallback_PT';
end

yhat_state = stateBest.yhat;
rmse_state = stateBest.rmse_loocv;
rP_state = corrSafe(y, yhat_state, 'Pearson');
rS_state = corrSafe(y, yhat_state, 'Spearman');
imp_state_vs_naive = (rmse_naive - rmse_state) / max(rmse_naive, eps);
rel_state_vs_pt = (rmse_pt - rmse_state) / max(rmse_pt, eps);

%% LOOCV summary table
loocvTbl = table( ...
    ["naive_mean"; "PT_best"; "PT_plus_state"], ...
    [n; n; n], ...
    [rP_naive; rP_pt; rP_state], ...
    [rS_naive; rS_pt; rS_state], ...
    [rmse_naive; rmse_pt; rmse_state], ...
    [0; imp_pt_vs_naive; imp_state_vs_naive], ...
    ["mean(others)"; ptBest.formula; stateBest.formula], ...
    'VariableNames', {'model', 'n', 'pearson_loocv_yhat', 'spearman_loocv_yhat', ...
    'rmse_loocv', 'rmse_improvement_over_naive', 'formula'});

%% Final flags
ptBeatsNaive = rmse_pt < rmse_naive * (1 - cfg.materialBeatFrac) && abs(rP_pt) >= cfg.minPearsonPt;
strongPt = abs(rP_pt) >= cfg.minPearsonPt && rmse_pt < rmse_naive * 0.85;
stateHelps = rel_state_vs_pt > cfg.stateHelpFrac;
A_PREDICTED_FROM_SWITCHING = ternary(ptBeatsNaive, "YES", "NO");
PT_IS_SUFFICIENT_FOR_A = ternary(~stateHelps && strongPt, "YES", "NO");
if stateHelps && rel_state_vs_pt > cfg.stateHelpFrac
    STATE_IMPROVES_A = "YES";
else
    STATE_IMPROVES_A = "NO";
end

if STATE_IMPROVES_A == "YES"
    BEST_A_MODEL = "PT_plus_" + string(stateName);
else
    BEST_A_MODEL = "PT_only: " + string(ptBest.namesJoined);
end

%% Export prediction table
predTbl = table(T_K, y, yhat_naive, yhat_pt, yhat_state, ...
    y - yhat_naive, y - yhat_pt, y - yhat_state, ...
    'VariableNames', {'T_K', 'A_T_true', 'A_pred_naive_mean', 'A_pred_PT_best_loocv', ...
    'A_pred_PT_plus_state_loocv', 'residual_naive', 'residual_PT_best', 'residual_PT_plus_state'});

save_run_table(predTbl, 'A_prediction_from_switching.csv', runDir);
save_run_table(loocvTbl, 'A_prediction_loocv_metrics.csv', runDir);
save_run_table(rowsG2, 'A_prediction_pt_single_feature_summary.csv', runDir);

flagsTbl = table(string(A_PREDICTED_FROM_SWITCHING), string(PT_IS_SUFFICIENT_FOR_A), ...
    string(STATE_IMPROVES_A), string(BEST_A_MODEL), ...
    'VariableNames', {'A_PREDICTED_FROM_SWITCHING', 'PT_IS_SUFFICIENT_FOR_A', ...
    'STATE_IMPROVES_A', 'BEST_A_MODEL'});
save_run_table(flagsTbl, 'A_prediction_final_flags.csv', runDir);

manifest = table( ...
    ["barrier_descriptors"; "pt_matrix"; "relaxation_A_T"; "alpha_structure"; "script"], ...
    [string(cfg.barrierDescriptorsPath); string(cfg.ptSourceNote); string(cfg.relaxSourceNote); ...
    string(cfg.alphaStructurePath); string(thisFile)], ...
    'VariableNames', {'artifact', 'path_or_note'});
save_run_table(manifest, 'A_prediction_source_manifest.csv', runDir);

figPath = saveAgent24aComparisonFigure(T_K, y, yhat_naive, yhat_pt, yhat_state, runDir);

report = buildAgent24aReport(cfg, merged, n, loocvTbl, ptBest, stateBest, stateName, ...
    flagsTbl, predTbl, figPath, thisFile);
save_run_report(report, 'A_prediction_from_switching_report.md', runDir);

zipPath = buildAgent24aReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] complete\n', stampNow()));
noteLine = sprintf('flags: A_PREDICTED_FROM_SWITCHING=%s PT_IS_SUFFICIENT_FOR_A=%s STATE_IMPROVES_A=%s BEST_A_MODEL=%s\n', ...
    char(flagsTbl.A_PREDICTED_FROM_SWITCHING(1)), char(flagsTbl.PT_IS_SUFFICIENT_FOR_A(1)), ...
    char(flagsTbl.STATE_IMPROVES_A(1)), char(flagsTbl.BEST_A_MODEL(1)));
appendText(run.notes_path, noteLine);

out = struct();
out.runDir = string(runDir);
out.loocvTbl = loocvTbl;
out.flags = flagsTbl;
out.predTbl = predTbl;
out.reportPath = fullfile(runDir, 'reports', 'A_prediction_from_switching_report.md');

fprintf('\n=== Agent 24A complete ===\n%s\n', out.reportPath);
end

%% ------------------------------------------------------------------------
function cfg = applyAgent24aDefaults(cfg, repoRoot)
cfg = setDef(cfg, 'runLabel', 'a_prediction_from_switching_agent24a');
barrierRun = 'run_2026_03_25_031904_barrier_to_relaxation_mechanism';
cfg = setDef(cfg, 'barrierRunId', barrierRun);
cfg = setDef(cfg, 'barrierDescriptorsPath', ...
    fullfile(repoRoot, 'results', 'cross_experiment', 'runs', barrierRun, 'tables', 'barrier_descriptors.csv'));
cfg = setDef(cfg, 'alphaStructurePath', fullfile(repoRoot, 'tables', 'alpha_structure.csv'));
cfg = setDef(cfg, 'alphaTableTag', 'tables/alpha_structure.csv');
cfg = setDef(cfg, 'materialBeatFrac', 0.05);
cfg = setDef(cfg, 'minPearsonPt', 0.75);
cfg = setDef(cfg, 'stateHelpFrac', 0.03);
cfg = setDef(cfg, 'twoVarImprovementMin', 0.02);
cfg = setDef(cfg, 'ptSourceNote', 'run_2026_03_25_013849_pt_robust_minpts7 (from barrier merge manifest)');
cfg = setDef(cfg, 'relaxSourceNote', 'run_2026_03_10_175048_relaxation_observable_stability_audit — A_T_interp via pchip on PT grid');
cfg = setDef(cfg, 'ptFeaturePool', { ...
    'median_I_mA', 'iq75_25_mA', 'skewness_quantile', 'cheb_m2_z', 'pt_svd_score1', 'moment_I2_weighted'});
end

function cfg = setDef(cfg, field, v)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = v;
end
end

function ensureAgent24aSubdirs(runDir)
for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
end

function yhat = loocvMeanPredictor(y)
n = numel(y);
yhat = nan(n, 1);
s = sum(y);
for i = 1:n
    if n > 1
        yhat(i) = (s - y(i)) / (n - 1);
    else
        yhat(i) = y(i);
    end
end
end

function yhat = loocvLinearPredictor(y, X)
% X: n x p (may be empty for intercept-only — not used here)
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    Xtr = X(tr, :);
    ytr = y(tr);
    Z = [ones(sum(tr), 1), Xtr];
    if rank(Z) < size(Z, 2) || sum(tr) < p + 1
        continue;
    end
    b = Z \ ytr;
    yhat(i) = [1, X(i, :)] * b;
end
end

function best = pickBestPtSubset(y, Xpt, poolNames, nFeat)
n = numel(y);
p = size(Xpt, 2);
best = struct('rmse_loocv', inf, 'idx', [], 'formula', "", 'namesJoined', "");
if nFeat <= 0 || nFeat > p
    return;
end
idxAll = nchoosek(1:p, nFeat);
for r = 1:size(idxAll, 1)
    idx = idxAll(r, :);
    yh = loocvLinearPredictor(y, Xpt(:, idx));
    if any(~isfinite(yh))
        continue;
    end
    e = sqrt(mean((y - yh).^2));
    if e < best.rmse_loocv
        best.rmse_loocv = e;
        best.idx = idx;
        nm = string(poolNames(idx));
        terms = join(nm, " + ");
        if nFeat == 1
            best.formula = "A ~ 1 + " + terms;
        else
            best.formula = "A ~ 1 + " + terms;
        end
        best.namesJoined = join(nm, " + ");
    end
end
end

function ext = extendPtWithState(y, Xpt, ptIdx, stateCol, poolNames, stateLabel)
X = [Xpt(:, ptIdx), stateCol(:)];
ext = struct('rmse_loocv', inf, 'yhat', nan(numel(y), 1), 'formula', "");
yh = loocvLinearPredictor(y, X);
if ~all(isfinite(yh))
    return;
end
ext.rmse_loocv = sqrt(mean((y - yh).^2));
ext.yhat = yh;
nm = string(poolNames(ptIdx));
ext.formula = "A ~ 1 + " + join(nm, " + ") + " + " + stateLabel;
end

function r = corrSafe(x, y, typ)
m = isfinite(x) & isfinite(y);
if sum(m) < 3
    r = NaN;
    return;
end
r = corr(x(m), y(m), 'rows', 'complete', 'type', typ);
end

function figP = saveAgent24aComparisonFigure(T_K, y, yhat_n, yhat_p, yhat_s, runDir)
base_name = 'A_prediction_comparison';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [1.5 1.5 18 11]);
[Ts, ord] = sort(T_K);
plot(Ts, y(ord), 'k-o', 'LineWidth', 2.2, 'MarkerSize', 7, 'MarkerFaceColor', [0.15 0.15 0.15], ...
    'DisplayName', 'A(T) measured');
hold on;
plot(Ts, yhat_n(ord), ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 2, 'DisplayName', 'Naive mean LOOCV');
plot(Ts, yhat_p(ord), '-s', 'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.65 0.85 0.95], 'DisplayName', 'Best PT-only LOOCV');
plot(Ts, yhat_s(ord), '-^', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.98 0.75 0.55], 'DisplayName', 'PT + state LOOCV');
hold off;
grid on;
xlabel('Temperature T (K)');
ylabel('Relaxation amplitude A(T)');
legend('Location', 'best');
figP = save_run_figure(fig, base_name, runDir);
close(fig);
end

function txt = buildAgent24aReport(cfg, merged, n, loocvTbl, ptBest, stateBest, stateName, ...
    flagsTbl, ~, figPath, thisFile)
lines = strings(0, 1);
lines(end + 1) = "# Relaxation A(T) prediction from switching / PT (Agent 24A)";
lines(end + 1) = "";
lines(end + 1) = "## Executive summary";
lines(end + 1) = sprintf("- **A_PREDICTED_FROM_SWITCHING** = `%s`", flagsTbl.A_PREDICTED_FROM_SWITCHING(1));
lines(end + 1) = sprintf("- **PT_IS_SUFFICIENT_FOR_A** = `%s`", flagsTbl.PT_IS_SUFFICIENT_FOR_A(1));
lines(end + 1) = sprintf("- **STATE_IMPROVES_A** = `%s`", flagsTbl.STATE_IMPROVES_A(1));
lines(end + 1) = sprintf("- **BEST_A_MODEL** = `%s`", flagsTbl.BEST_A_MODEL(1));
lines(end + 1) = "";
lines(end + 1) = "## 1. Sources (exact)";
lines(end + 1) = sprintf("- Canonical merged descriptors: `%s`", cfg.barrierDescriptorsPath);
lines(end + 1) = "- That merge used **PT_matrix** from switching run **`run_2026_03_25_013849_pt_robust_minpts7`**.";
lines(end + 1) = "- **A(T)** column in merge: `A_T_interp` = relaxation **`A_T`** from **`run_2026_03_10_175048_relaxation_observable_stability_audit`**, `pchip`-interpolated onto the PT temperature grid (same as `run_barrier_to_relaxation_mechanism`).";
lines(end + 1) = sprintf("- Collective-state table: `%s` (joined on `T_K`).", cfg.alphaStructurePath);
lines(end + 1) = sprintf("- **Overlap n** after requiring finite PT pool + `kappa1` + `alpha`: **%d**.", n);
lines(end + 1) = sprintf("- Temperatures: **%s**.", mat2str(unique(merged.T_K)'));
lines(end + 1) = "";
lines(end + 1) = "## 2. Feature groups";
lines(end + 1) = "- **GROUP 1**: naive mean (LOOCV).";
lines(end + 1) = "- **GROUP 2**: single PT/barrier terms (table `A_prediction_pt_single_feature_summary.csv`; in-sample LS RMSE listed).";
lines(end + 1) = sprintf("- **GROUP 3**: best **small** PT-only linear model under **strict LOOCV** within pool {%s} (sizes 1 and 2; keep 2 only if RMSE improves by ≥2%% vs best single).", ...
    strjoin(string(cfg.ptFeaturePool), ", "));
lines(end + 1) = sprintf("- **GROUP 4**: **PT best** + **`kappa1`** vs **PT best** + **`alpha`**; keep better LOOCV as **PT + state** comparison.");
lines(end + 1) = "";
lines(end + 1) = "## 3. Model formulas (structure)";
lines(end + 1) = sprintf("- **Best PT-only (selected)**: `%s`", ptBest.formula);
lines(end + 1) = sprintf("- **PT + state (selected: %s)**: linear extension `%s`", stateName, stateBest.formula);
lines(end + 1) = "";
lines(end + 1) = "## 4. LOOCV metrics (y vs LOOCV predictions)";
lines(end + 1) = formatMarkdownTable(loocvTbl);
lines(end + 1) = "";
lines(end + 1) = "## 5. Verdict";
lines = [lines; verdictParagraph(loocvTbl, flagsTbl, ptBest, stateName)];
lines(end + 1) = "";
lines(end + 1) = "## 6. Outputs";
lines(end + 1) = sprintf("- Table: `tables/A_prediction_from_switching.csv`");
lines(end + 1) = sprintf("- Figure: `%s`", figPath.png);
lines(end + 1) = "";
lines(end + 1) = "## Reproducibility";
lines(end + 1) = "### MATLAB command";
lines(end + 1) = "```";
lines(end + 1) = "cd <REPO_ROOT>";
lines(end + 1) = "addpath(""analysis"");";
lines(end + 1) = "run_A_prediction_from_switching_agent24a();";
lines(end + 1) = "```";
lines(end + 1) = sprintf("- Wrapper (per AGENT_RULES): `tools\\run_matlab_safe.bat \"cd(''<REPO_ROOT>''); addpath(''analysis''); run_A_prediction_from_switching_agent24a(); exit;\"`");
lines(end + 1) = sprintf("- Run folder: written to `results/cross_experiment/runs/run_<timestamp>_a_prediction_from_switching_agent24a/`.");
lines(end + 1) = "- **Assumptions**: canonical barrier merge run remains available at the path above; `tables/alpha_structure.csv` covers the same `T_K` ladder.";
lines(end + 1) = "";
lines(end + 1) = "## Provenance";
lines(end + 1) = sprintf("- Script: `%s`", thisFile);
txt = join(lines, newline);
end

function lines = verdictParagraph(loocvTbl, flagsTbl, ptBest, stateName)
lines = strings(0, 1);
rowPt = loocvTbl(loocvTbl.model == "PT_best", :);
rowSt = loocvTbl(loocvTbl.model == "PT_plus_state", :);
if height(rowPt) == 1 && height(rowSt) == 1
    lines(end + 1) = sprintf(['**Quantitative readout (LOOCV)**: PT-only RMSE = %.6g, Pearson(y,ŷ) = %.4f; ', ...
        'PT+%s RMSE = %.6g, Pearson = %.4f. Naive RMSE = %.6g.'], ...
        rowPt.rmse_loocv(1), rowPt.pearson_loocv_yhat(1), stateName, rowSt.rmse_loocv(1), ...
        rowSt.pearson_loocv_yhat(1), loocvTbl.rmse_loocv(1));
end
lines(end + 1) = sprintf(['**Is A(T) predicted from switching-derived PT?** Flag `A_PREDICTED_FROM_SWITCHING` = **%s** ', ...
    '(YES means PT-only beats naive mean by ≥5%% RMSE with |Pearson(LOOCV)| ≥ 0.75).'], ...
    flagsTbl.A_PREDICTED_FROM_SWITCHING(1));
lines(end + 1) = sprintf('**Does state help OOS?** `STATE_IMPROVES_A` = **%s** (>3%% relative LOOCV RMSE gain over PT-only).', ...
    flagsTbl.STATE_IMPROVES_A(1));
lines(end + 1) = sprintf('**Is PT alone sufficient?** `PT_IS_SUFFICIENT_FOR_A` = **%s** (strong PT + no material state gain).', ...
    flagsTbl.PT_IS_SUFFICIENT_FOR_A(1));
lines(end + 1) = sprintf(['**Landscape interpretation**: Best PT structure `%s`. With **%s** = `%s`, ', ...
    'the compact story is: **%s**.'], char(ptBest.formula), char(stateName), ...
    char(flagsTbl.BEST_A_MODEL(1)), landscapeVerdict(flagsTbl, ptBest));
end

function s = landscapeVerdict(flagsTbl, ~)
if flagsTbl.A_PREDICTED_FROM_SWITCHING(1) == "YES" && flagsTbl.STATE_IMPROVES_A(1) == "NO"
    s = 'relaxation amplitude behaves as a landscape-controlled observable on this overlap (PT predicts A(T); state adds no material OOS gain)';
elseif flagsTbl.A_PREDICTED_FROM_SWITCHING(1) == "YES" && flagsTbl.STATE_IMPROVES_A(1) == "YES"
    s = 'PT predicts A(T), but a collective-state term still yields a small LOOCV gain — treat PT as primary, not literally sufficient';
else
    s = 'strict Agent24A gates on PT-vs-naive RMSE and LOOCV Pearson were not met; see table before claiming a locked quantitative prediction';
end
end

function md = formatMarkdownTable(T)
hdr = "| " + strjoin(string(T.Properties.VariableNames), " | ") + " |";
sep = "|" + strjoin(repmat(" --- ", 1, width(T)), "|") + "|";
body = strings(height(T), 1);
for i = 1:height(T)
    row = strings(1, width(T));
    for j = 1:width(T)
        v = T{i, j};
        if isnumeric(v)
            row(j) = sprintf('%.6g', v);
        elseif islogical(v)
            row(j) = string(v);
        else
            row(j) = string(v);
        end
    end
    body(i) = "| " + strjoin(row, " | ") + " |";
end
md = join([hdr; sep; body], newline);
end

function zipPath = buildAgent24aReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipName = 'A_prediction_from_switching_agent24a_bundle.zip';
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
