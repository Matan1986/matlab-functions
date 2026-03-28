function run_aging_alpha_closure_agent24f(varargin)
%RUN_AGING_ALPHA_CLOSURE_AGENT24F  Agent 24F — aging closure with alpha-residual term (LOOCV)
%
% Read-only inputs (aligned with Agent 24B lineage):
%   - barrier_descriptors.csv + energy_stats (R_T_interp, spread90_50, gates)
%   - tables/alpha_structure.csv (kappa1, kappa2, alpha)
%   - tables/alpha_decomposition.csv (alpha_geom, alpha_res, PT_geometry_valid)
%
% Tests whether alpha-derived terms improve R ~ spread90_50 + kappa1 under strict LOOCV
% and a common-overlap temperature subset.
%
% Outputs under results/cross_experiment/runs/<run_id>/ (+ mirror to repo root):
%   tables/aging_alpha_closure_models.csv
%   tables/aging_alpha_closure_best_model.csv
%   tables/aging_alpha_closure_residual_audit.csv
%   tables/aging_alpha_closure_master_table.csv
%   figures/aging_alpha_closure_predictions.png|pdf|fig
%   figures/aging_alpha_closure_residuals_vs_T.png|pdf|fig
%   figures/aging_alpha_transition_focus.png|pdf|fig
%   reports/aging_alpha_closure_report.md
%   review/aging_alpha_closure_agent24f_bundle.zip
%
% Name-value: same as Agent 24B (repoRoot, barrierPath, energyStatsPath, clockRatioPath,
%             alphaStructurePath, decompPath)

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

runCfg = struct('runLabel', 'aging_alpha_closure_alpha_residual', ...
    'dataset', 'Aging R(T) closure with alpha_res LOOCV (Agent 24F)');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

fprintf(1, 'Agent 24F run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_aging_alpha_closure_agent24f started\n', datestr(now, 31)));

%% Load inputs (24B-aligned merge)
bar = readtable(opts.barrierPath, 'VariableNamingRule', 'preserve');
en = readtable(opts.energyStatsPath, 'VariableNamingRule', 'preserve');
if ismember('T', en.Properties.VariableNames) && ~ismember('T_K', en.Properties.VariableNames)
    en.Properties.VariableNames{'T'} = 'T_K';
end
assert(ismember('T_K', en.Properties.VariableNames), 'energy_stats needs T_K or T');
en = en(:, intersect({'T_K', 'mean_E', 'std_E'}, en.Properties.VariableNames, 'stable'));
bar = innerjoin(bar, en, 'Keys', 'T_K');

bar.spread90_50 = double(bar.q90_I_mA) - double(bar.q50_I_mA);
bar.asymmetry = double(bar.asym_q75_50_minus_q50_25);

reqB = {'T_K', 'row_valid', 'R_T_interp', 'spread90_50', 'asymmetry'};
for k = 1:numel(reqB)
    assert(ismember(reqB{k}, bar.Properties.VariableNames), 'barrier_descriptors missing %s', reqB{k});
end

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
aD = readtable(opts.decompPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, aS.Properties.VariableNames)), ...
    'alpha_structure missing kappa/alpha columns');
needD = {'T_K', 'PT_geometry_valid', 'alpha_geom', 'alpha_res'};
assert(all(ismember(needD, aD.Properties.VariableNames)), ...
    'alpha_decomposition missing required columns');

merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    aD(:, {'T_K', 'alpha_geom', 'alpha_res', 'PT_geometry_valid'}), 'Keys', 'T_K');

bCols = intersect(reqB, bar.Properties.VariableNames, 'stable');
merged = innerjoin(merged, bar(:, bCols), 'Keys', 'T_K');

merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
merged = merged(double(merged.row_valid) ~= 0, :);
merged = sortrows(merged, 'T_K');

T_K = double(merged.T_K(:));
R_aging = double(merged.R_T_interp(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
aGeom = double(merged.alpha_geom(:));
aRes = double(merged.alpha_res(:));
spread90_50 = double(merged.spread90_50(:));
asym = double(merged.asymmetry(:));
theta_rad = atan2(k2, k1);

abs_aRes = abs(aRes);
abs_alp = abs(alp);

colsOverlap = {'R', 'spread90_50', 'kappa1', 'kappa2', 'alpha', 'alpha_res'};
mOv = true(height(merged), 1);
for c = 1:numel(colsOverlap)
    vn = colsOverlap{c};
    if strcmp(vn, 'R')
        mOv = mOv & isfinite(R_aging);
    elseif strcmp(vn, 'spread90_50')
        mOv = mOv & isfinite(spread90_50);
    elseif strcmp(vn, 'kappa1')
        mOv = mOv & isfinite(k1);
    elseif strcmp(vn, 'kappa2')
        mOv = mOv & isfinite(k2);
    elseif strcmp(vn, 'alpha')
        mOv = mOv & isfinite(alp);
    elseif strcmp(vn, 'alpha_res')
        mOv = mOv & isfinite(aRes);
    end
end
in_overlap_subset = mOv;

master = table(T_K, R_aging, spread90_50, asym, k1, k2, alp, abs_alp, aGeom, aRes, abs_aRes, theta_rad, in_overlap_subset, ...
    'VariableNames', {'T_K', 'R', 'spread90_50', 'asymmetry', 'kappa1', 'kappa2', 'alpha', 'abs_alpha', ...
    'alpha_geom', 'alpha_res', 'abs_alpha_res', 'theta_rad', 'in_LOOCV_overlap_subset'});

save_run_table(master, 'aging_alpha_closure_master_table.csv', runDir);

%% Model list (column names refer to master)
pred = struct('id', {}, 'category', {}, 'cols', {});
pred(end + 1) = struct('id', 'R ~ 1', 'category', 'baseline', 'cols', {{}});
pred(end + 1) = struct('id', 'R ~ spread90_50', 'category', 'baseline', 'cols', {{'spread90_50'}});
pred(end + 1) = struct('id', 'R ~ kappa1', 'category', 'baseline', 'cols', {{'kappa1'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1', 'category', 'PT+state_ref', 'cols', {{'spread90_50', 'kappa1'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha_res', 'category', 'alpha_augmented', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha_res'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + abs(alpha_res)', 'category', 'alpha_augmented', ...
    'cols', {{'spread90_50', 'kappa1', 'abs_alpha_res'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha', 'category', 'alpha_augmented', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + abs(alpha)', 'category', 'alpha_augmented', ...
    'cols', {{'spread90_50', 'kappa1', 'abs_alpha'}});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + kappa2', 'category', 'state_extra', ...
    'cols', {{'spread90_50', 'kappa1', 'kappa2'}});

geomOk = isfinite(master.alpha_geom) & isfinite(master.alpha_res);
if nnz(geomOk) >= 5
    pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha_geom', 'category', 'alpha_geom', ...
        'cols', {{'spread90_50', 'kappa1', 'alpha_geom'}});
    pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha_geom + alpha_res', 'category', 'alpha_geom', ...
        'cols', {{'spread90_50', 'kappa1', 'alpha_geom', 'alpha_res'}});
end

%% Per-model LOOCV (all rows where y and model predictors are finite)
rows = table();

for k = 1:numel(pred)
    m = isfinite(master.R);
    if isempty(pred(k).cols)
        X = zeros(height(master), 0);
    else
        for c = 1:numel(pred(k).cols)
            colVec = master.(pred(k).cols{c});
            m = m & isfinite(colVec);
        end
    end
    sub = master(m, :);
    n = height(sub);
    y = double(sub.R(:));
    Tm = double(sub.T_K(:));
    tempsStr = localTempsStr(Tm);

    if isempty(pred(k).cols)
        [rmse, rP, rS, yhat] = localLoocvMean(y);
    else
        X = zeros(n, numel(pred(k).cols));
        for c = 1:numel(pred(k).cols)
            X(:, c) = double(sub.(pred(k).cols{c})(:));
        end
        [rmse, rP, rS, yhat] = localLoocvOls(y, X);
    end

    rows = [rows; table({pred(k).id}, {pred(k).category}, n, rmse, rP, rS, {tempsStr}, ...
        'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', ...
        'T_K_list'})]; %#ok<AGROW>
end

%% Strict common overlap: all variables for models 1–9 (through kappa2 extension)
mOv = master.in_LOOCV_overlap_subset;
subOv = master(mOv, :);
nOv = height(subOv);
assert(nOv >= 5, 'Agent24F: insufficient common-overlap rows (n=%d).', nOv);

Tov = double(subOv.T_K(:));
yOv = double(subOv.R(:));
tempsOverlapStr = localTempsStr(Tov);

overlapRmse = nan(numel(pred), 1);
overlapPearson = nan(numel(pred), 1);
overlapSpearman = nan(numel(pred), 1);

for k = 1:numel(pred)
    if isempty(pred(k).cols)
        [overlapRmse(k), overlapPearson(k), overlapSpearman(k), ~] = localLoocvMean(yOv);
    else
        useGeom = any(strcmp(pred(k).cols, 'alpha_geom'));
        if useGeom && ~all(isfinite(subOv.alpha_geom))
            continue
        end
        X = zeros(nOv, numel(pred(k).cols));
        ok = true;
        for c = 1:numel(pred(k).cols)
            if ~ismember(pred(k).cols{c}, subOv.Properties.VariableNames)
                ok = false; break
            end
            vc = double(subOv.(pred(k).cols{c})(:));
            X(:, c) = vc;
            ok = ok && all(isfinite(vc));
        end
        if ok
            [overlapRmse(k), overlapPearson(k), overlapSpearman(k), ~] = localLoocvOls(yOv, X);
        end
    end
end

rows.n_overlap = repmat(nOv, height(rows), 1);
rows.loocv_rmse_overlap = overlapRmse;
rows.pearson_overlap = overlapPearson;
rows.spearman_overlap = overlapSpearman;
rows.T_K_list_overlap = repmat({tempsOverlapStr}, height(rows), 1);

save_run_table(rows, 'aging_alpha_closure_models.csv', runDir);

%% Reference RMSE on overlap
idxRef = find(strcmp(rows.model, 'R ~ spread90_50 + kappa1'), 1);
rmseRef = rows.loocv_rmse_overlap(idxRef);
idxRes = find(strcmp(rows.model, 'R ~ spread90_50 + kappa1 + alpha_res'), 1);
idxAbsRes = find(strcmp(rows.model, 'R ~ spread90_50 + kappa1 + abs(alpha_res)'), 1);
idxAlp = find(strcmp(rows.model, 'R ~ spread90_50 + kappa1 + alpha'), 1);
idxAbsAlp = find(strcmp(rows.model, 'R ~ spread90_50 + kappa1 + abs(alpha)'), 1);

rmseRes = rows.loocv_rmse_overlap(idxRes);
rmseAbsRes = rows.loocv_rmse_overlap(idxAbsRes);

alphaAugMask = strcmp(rows.category, 'alpha_augmented');
[~, jBestAlpha] = min(rows.loocv_rmse_overlap(alphaAugMask), [], 'omitnan');
alphaRows = rows(alphaAugMask, :);
bestAlphaModel = alphaRows.model{jBestAlpha};
bestAlphaRmse = alphaRows.loocv_rmse_overlap(jBestAlpha);

[~, jBase] = min(rows.loocv_rmse_overlap(strcmp(rows.category, 'baseline')), [], 'omitnan');
baseRows = rows(strcmp(rows.category, 'baseline'), :);
bestBaselineModel = baseRows.model{jBase};
bestBaselineRmse = baseRows.loocv_rmse_overlap(jBase);

%% LOOCV yhat on overlap for residual audit and figures
yhatRef = localLooPred(subOv, {'spread90_50', 'kappa1'});
ipBest = localFindPredById(pred, bestAlphaModel);
yhatAlphaBest = localLooPred(subOv, pred(ipBest).cols);

resRef = yOv - yhatRef;
resAlpha = yOv - yhatAlphaBest;
mae22_ref = mean(abs(resRef(Tov >= 22 & Tov <= 24)), 'omitnan');
maeOut_ref = mean(abs(resRef(~(Tov >= 22 & Tov <= 24))), 'omitnan');
n22 = nnz(Tov >= 22 & Tov <= 24);
nOut = nnz(~(Tov >= 22 & Tov <= 24));

mae22_alp = mean(abs(resAlpha(Tov >= 22 & Tov <= 24)), 'omitnan');
maeOut_alp = mean(abs(resAlpha(~(Tov >= 22 & Tov <= 24))), 'omitnan');

% Third model for figure: best LOOCV on overlap overall
[~, jOverall] = min(rows.loocv_rmse_overlap, [], 'omitnan');
thirdModel = rows.model{jOverall};
if ~strcmp(thirdModel, 'R ~ spread90_50 + kappa1') && ~strcmp(thirdModel, bestAlphaModel)
    yhatThird = localLooPred(subOv, pred(localFindPredById(pred, thirdModel)).cols);
else
    thirdModel = '';
    yhatThird = [];
end

audit = table( ...
    {'R ~ spread90_50 + kappa1'; bestAlphaModel}, ...
    [rmseRef; bestAlphaRmse], ...
    [mae22_ref; mae22_alp], ...
    [maeOut_ref; maeOut_alp], ...
    [n22; n22], ...
    [nOut; nOut], ...
    'VariableNames', {'model', 'loocv_rmse_overlap', 'mae_abs_residual_22_24_K', ...
    'mae_abs_residual_outside_22_24_K', 'n_points_22_24_K', 'n_points_outside'});

if ~isempty(thirdModel) && ~strcmp(thirdModel, bestAlphaModel) && ~strcmp(thirdModel, 'R ~ spread90_50 + kappa1')
    y3 = localLooPred(subOv, pred(localFindPredById(pred, thirdModel)).cols);
    r3 = yOv - y3;
    audit = [audit; table({thirdModel}, rows.loocv_rmse_overlap(jOverall), ...
        mean(abs(r3(Tov >= 22 & Tov <= 24)), 'omitnan'), ...
        mean(abs(r3(~(Tov >= 22 & Tov <= 24))), 'omitnan'), n22, nOut, ...
        'VariableNames', audit.Properties.VariableNames)]; %#ok<AGROW>
end

save_run_table(audit, 'aging_alpha_closure_residual_audit.csv', runDir);

%% Verdicts (fair overlap)
clearThresh = max(1e-6, 0.02 * rmseRef);
improveRes = min(rmseRes, rmseAbsRes);

if improveRes < rmseRef - clearThresh
    v.ALPHA_RES_IMPROVES_AGING_CLOSURE = "YES";
elseif improveRes < rmseRef - 1e-9
    v.ALPHA_RES_IMPROVES_AGING_CLOSURE = "PARTIAL";
else
    v.ALPHA_RES_IMPROVES_AGING_CLOSURE = "NO";
end

if rmseAbsRes < rmseRes - 1e-9
    v.ABS_ALPHA_RES_BETTER_THAN_SIGNED = "YES";
elseif rmseAbsRes > rmseRes + 1e-9
    v.ABS_ALPHA_RES_BETTER_THAN_SIGNED = "NO";
else
    v.ABS_ALPHA_RES_BETTER_THAN_SIGNED = "PARTIAL";
end

allRmse = rows.loocv_rmse_overlap;
[~, jMinAll] = min(allRmse, [], 'omitnan');
bestOverall = rows.model{jMinAll};
alphaAugIdx = find(alphaAugMask);
isAlphaBest = any(strcmp(bestOverall, rows.model(alphaAugIdx)));

if isAlphaBest && allRmse(jMinAll) < rmseRef - 1e-9
    v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1 = "YES";
elseif isAlphaBest
    v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1 = "PARTIAL";
else
    v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1 = "NO";
end

transThresh = max(0.05 * mae22_ref, 1e-6);
if mae22_alp < mae22_ref - transThresh
    v.TRANSITION_RESIDUAL_REDUCED = "YES";
elseif mae22_alp < mae22_ref - 1e-9
    v.TRANSITION_RESIDUAL_REDUCED = "PARTIAL";
else
    v.TRANSITION_RESIDUAL_REDUCED = "NO";
end

predAlphaHelps = strcmp(v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1, "YES") ...
    || strcmp(v.ALPHA_RES_IMPROVES_AGING_CLOSURE, "YES");
transHelps = strcmp(v.TRANSITION_RESIDUAL_REDUCED, "YES");
if predAlphaHelps && transHelps
    v.REORGANIZATION_TERM_SUPPORTED = "YES";
elseif predAlphaHelps || transHelps
    v.REORGANIZATION_TERM_SUPPORTED = "PARTIAL";
else
    v.REORGANIZATION_TERM_SUPPORTED = "NO";
end

bestTbl = table( ...
    string(bestBaselineModel), bestBaselineRmse, ...
    string('R ~ spread90_50 + kappa1'), rmseRef, ...
    string(bestAlphaModel), bestAlphaRmse, ...
    string(bestOverall), allRmse(jMinAll), ...
    string(v.ALPHA_RES_IMPROVES_AGING_CLOSURE), string(v.ABS_ALPHA_RES_BETTER_THAN_SIGNED), ...
    string(v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1), string(v.TRANSITION_RESIDUAL_REDUCED), ...
    string(v.REORGANIZATION_TERM_SUPPORTED), ...
    nOv, string(tempsOverlapStr), ...
    'VariableNames', {'best_baseline_model', 'loocv_rmse_overlap_baseline', ...
    'pt_kappa1_reference_model', 'loocv_rmse_overlap_pt_kappa1', ...
    'best_alpha_augmented_model', 'loocv_rmse_overlap_best_alpha_aug', ...
    'best_overall_model', 'loocv_rmse_overlap_best_overall', ...
    'ALPHA_RES_IMPROVES_AGING_CLOSURE', 'ABS_ALPHA_RES_BETTER_THAN_SIGNED', ...
    'ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1', 'TRANSITION_RESIDUAL_REDUCED', ...
    'REORGANIZATION_TERM_SUPPORTED', 'n_overlap', 'T_K_list_overlap'});

save_run_table(bestTbl, 'aging_alpha_closure_best_model.csv', runDir);

%% Figures
% Predictions: top models on overlap (legend, <=6)
fig1 = create_figure('Name', 'aging_alpha_closure_predictions', 'NumberTitle', 'off');
ax = axes(fig1);
hold(ax, 'on');
h1 = scatter(ax, yOv, yhatRef, 90, [0.2 0.45 0.7], 'filled', 'DisplayName', 'PT+\kappa_1 ref');
h2 = scatter(ax, yOv, yhatAlphaBest, 90, [0.85 0.35 0.15], 'filled', 'DisplayName', 'Best \alpha-augmented');
plots = [h1 h2];
if ~isempty(thirdModel) && ~isempty(yhatThird)
    h3 = scatter(ax, yOv, yhatThird, 90, [0.2 0.65 0.35], 'filled', 'DisplayName', localShortName(thirdModel));
    plots = [plots h3];
end
lim = [min([yOv; yhatRef; yhatAlphaBest], [], 'omitnan'), max([yOv; yhatRef; yhatAlphaBest], [], 'omitnan')];
if ~isempty(yhatThird)
    lim = [min([lim(1); yhatThird(:)], [], 'omitnan'), max([lim(2); yhatThird(:)], [], 'omitnan')];
end
if isfinite(lim(1)) && isfinite(lim(2)) && lim(2) > lim(1)
    plot(ax, lim, lim, 'k--', 'LineWidth', 2, 'HandleVisibility', 'off');
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'R measured (clock ratio)', 'FontSize', 14);
ylabel(ax, 'R LOOCV prediction', 'FontSize', 14);
legend(ax, plots, 'Location', 'best');
set(ax, 'FontSize', 14);
figPath1 = save_run_figure(fig1, 'aging_alpha_closure_predictions', runDir);
close(fig1);

fig2 = create_figure('Name', 'aging_alpha_closure_residuals_vs_T', 'NumberTitle', 'off');
ax2 = axes(fig2);
hold(ax2, 'on');
plot(ax2, Tov, resRef, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2 0.45 0.7], ...
    'DisplayName', 'Residual ref');
plot(ax2, Tov, resAlpha, 's-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.85 0.35 0.15], ...
    'DisplayName', 'Residual best \alpha');
yline(ax2, 0, 'k--', 'LineWidth', 1.5);
hold(ax2, 'off');
xlabel(ax2, 'T (K)', 'FontSize', 14);
ylabel(ax2, 'Residual R (meas - LOOCV pred)', 'FontSize', 14);
legend(ax2, 'Location', 'best');
grid(ax2, 'on');
set(ax2, 'FontSize', 14);
figPath2 = save_run_figure(fig2, 'aging_alpha_closure_residuals_vs_T', runDir);
close(fig2);

fig3 = create_figure('Name', 'aging_alpha_transition_focus', 'NumberTitle', 'off');
ax3 = axes(fig3);
Yb = [mae22_ref, mae22_alp; maeOut_ref, maeOut_alp];
b = bar(ax3, Yb);
b(1).FaceColor = [0.2 0.45 0.7];
b(2).FaceColor = [0.85 0.35 0.15];
set(ax3, 'XTickLabel', {'22–24 K', 'Outside'});
ylabel(ax3, 'Mean |residual|', 'FontSize', 14);
legend(ax3, {'PT+\kappa_1', 'Best \alpha-aug'}, 'Location', 'best');
grid(ax3, 'on');
set(ax3, 'FontSize', 14);
figPath3 = save_run_figure(fig3, 'aging_alpha_transition_focus', runDir);
close(fig3);

%% Report
gainNote = 'global';
if strcmp(v.TRANSITION_RESIDUAL_REDUCED, "YES") && ~strcmp(v.ALPHA_RES_IMPROVES_AGING_CLOSURE, "YES")
    gainNote = 'mainly transition-local';
elseif strcmp(v.TRANSITION_RESIDUAL_REDUCED, "YES") && strcmp(v.ALPHA_RES_IMPROVES_AGING_CLOSURE, "YES")
    gainNote = 'global and transition-local';
elseif strcmp(v.ALPHA_RES_IMPROVES_AGING_CLOSURE, "YES") && strcmp(v.TRANSITION_RESIDUAL_REDUCED, "NO")
    gainNote = 'global (not transition-focused)';
end

rep = localBuildReport(runDir, opts, master, subOv, rows, audit, bestTbl, v, ...
    rmseRef, improveRes, mae22_ref, mae22_alp, tempsOverlapStr, figPath1, figPath2, figPath3, gainNote);
save_run_report(rep, 'aging_alpha_closure_report.md', runDir);

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
    copyfile(fullfile(runDir, 'tables', 'aging_alpha_closure_models.csv'), fullfile(mirrorTables, 'aging_alpha_closure_models.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_alpha_closure_best_model.csv'), fullfile(mirrorTables, 'aging_alpha_closure_best_model.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_alpha_closure_residual_audit.csv'), fullfile(mirrorTables, 'aging_alpha_closure_residual_audit.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_alpha_closure_master_table.csv'), fullfile(mirrorTables, 'aging_alpha_closure_master_table.csv'));
    copyfile(fullfile(runDir, 'reports', 'aging_alpha_closure_report.md'), fullfile(mirrorRep, 'aging_alpha_closure_report.md'));
    copyfile(figPath1.png, fullfile(mirrorFigs, 'aging_alpha_closure_predictions.png'));
    copyfile(figPath2.png, fullfile(mirrorFigs, 'aging_alpha_closure_residuals_vs_T.png'));
    copyfile(figPath3.png, fullfile(mirrorFigs, 'aging_alpha_transition_focus.png'));
catch ME
    fprintf(2, 'Mirror copy skipped: %s\n', ME.message);
end

%% Console verdicts
fprintf(1, '\n--- Agent 24F verdicts (fair overlap, n=%d) ---\n', nOv);
fprintf(1, 'ALPHA_RES_IMPROVES_AGING_CLOSURE: %s\n', v.ALPHA_RES_IMPROVES_AGING_CLOSURE);
fprintf(1, 'ABS_ALPHA_RES_BETTER_THAN_SIGNED: %s\n', v.ABS_ALPHA_RES_BETTER_THAN_SIGNED);
fprintf(1, 'ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1: %s\n', v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1);
fprintf(1, 'TRANSITION_RESIDUAL_REDUCED: %s\n', v.TRANSITION_RESIDUAL_REDUCED);
fprintf(1, 'REORGANIZATION_TERM_SUPPORTED: %s\n', v.REORGANIZATION_TERM_SUPPORTED);
fprintf(1, '\nBest models summary\n');
fprintf(1, '  best baseline: %s  LOOCV RMSE (overlap)=%.6g\n', bestBaselineModel, bestBaselineRmse);
fprintf(1, '  PT+state reference: R ~ spread90_50 + kappa1  RMSE=%.6g\n', rmseRef);
fprintf(1, '  best alpha-augmented: %s  RMSE=%.6g\n', bestAlphaModel, bestAlphaRmse);
fprintf(1, '  best overall: %s  RMSE=%.6g\n', bestOverall, allRmse(jMinAll));
fprintf(1, '  n_overlap=%d  T_K: %s\n', nOv, tempsOverlapStr);
fprintf(1, '  gain character: %s\n', gainNote);

fprintf(1, '\nAgent 24F complete. Report: %s\n', fullfile(runDir, 'reports', 'aging_alpha_closure_report.md'));
end

%% ------------------------------------------------------------------------
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

function s = localTempsStr(Tv)
s = strjoin(string(Tv(:)'), ';');
end

function s = localShortName(longName)
s = strrep(longName, 'R ~ ', '');
if numel(s) > 40
    s = [s(1:37) '...'];
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

function idx = localFindPredById(pred, name)
idx = [];
for ii = 1:numel(pred)
    if strcmp(pred(ii).id, name)
        idx = ii;
        return
    end
end
error('Agent24F: unknown model id: %s', name);
end

function txt = localBuildReport(runDir, opts, master, subOv, rows, audit, bestTbl, v, ...
    rmseRef, improveRes, mae22_ref, mae22_alp, tempsOverlapStr, figPath1, figPath2, figPath3, gainNote)

lines = {};
lines{end + 1} = '# Aging closure with alpha-residual term (Agent 24F)';
lines{end + 1} = '';
lines{end + 1} = '## Hypothesis';
lines{end + 1} = 'This run tests whether the remaining aging closure error, especially near the **22–24 K** transition, is captured by an **alpha-derived reorganization term** beyond **R ~ spread90_50 + κ₁**, under **strict leave-one-out cross-validation (LOOCV)** on a **common temperature overlap**.';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';

lines{end + 1} = '## Data lineage (read-only)';
lines{end + 1} = sprintf('- **R(T):** `R_T_interp` from barrier table merge (same grid as Agent 24B). Clock lineage: `%s`', ...
    strrep(opts.clockRatioPath, '\', '/'));
lines{end + 1} = sprintf('- **spread90_50, row_valid:** `%s`', strrep(opts.barrierPath, '\', '/'));
lines{end + 1} = sprintf('- **mean_E / std_E (barrier join):** `%s`', strrep(opts.energyStatsPath, '\', '/'));
lines{end + 1} = sprintf('- **kappa1, kappa2, alpha:** `%s`', strrep(opts.alphaStructurePath, '\', '/'));
lines{end + 1} = sprintf('- **alpha_geom, alpha_res, PT_geometry_valid:** `%s` (canonical decomposition; alpha_res not refit here)', ...
    strrep(opts.decompPath, '\', '/'));
lines{end + 1} = '';

lines{end + 1} = '## Fair comparison';
lines{end + 1} = sprintf(['All models report **per-model n** and predictor-specific `T_K_list`. ', ...
    '**Apples-to-apples LOOCV** uses **n_overlap = %d** rows where **R**, **spread90_50**, **kappa1**, **kappa2**, **alpha**, and **alpha_res** are all finite; ', ...
    '`loocv_rmse_overlap` and correlation columns use this subset. **Overlap temperatures (K):** %s.'], ...
    height(subOv), strrep(tempsOverlapStr, ';', ', '));
lines{end + 1} = '';

lines{end + 1} = '## LOOCV results';
lines{end + 1} = '| model | category | n | LOOCV RMSE | Pearson | Spearman | n_overlap | RMSE_overlap | Pearson_ov | Spearman_ov |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|';
for k = 1:height(rows)
    lines{end + 1} = sprintf('| %s | %s | %d | %.6g | %.6g | %.6g | %d | %.6g | %.6g | %.6g |', ...
        rows.model{k}, rows.category{k}, rows.n(k), rows.loocv_rmse(k), rows.pearson_y_yhat(k), ...
        rows.spearman_y_yhat(k), rows.n_overlap(k), rows.loocv_rmse_overlap(k), ...
        rows.pearson_overlap(k), rows.spearman_overlap(k)); %#ok<AGROW>
end
lines{end + 1} = '';

lines{end + 1} = '## Main result';
lines{end + 1} = sprintf(['On the **overlap subset**, **R ~ spread90_50 + kappa1** has LOOCV RMSE **%.6g**. ', ...
    'The better of **+ alpha_res** and **+ abs(alpha_res)** has RMSE **%.6g**.'], rmseRef, improveRes);
lines{end + 1} = '';

lines{end + 1} = '## Transition-focused residual audit (LOOCV residuals)';
lines{end + 1} = '| model | LOOCV RMSE (overlap) | MAE |res| 22–24 K | MAE |res| outside | n(22–24) | n(outside) |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|';
for k = 1:height(audit)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g | %.6g | %d | %d |', ...
        audit.model{k}, audit.loocv_rmse_overlap(k), audit.mae_abs_residual_22_24_K(k), ...
        audit.mae_abs_residual_outside_22_24_K(k), audit.n_points_22_24_K(k), audit.n_points_outside(k)); %#ok<AGROW>
end
lines{end + 1} = sprintf('- Reference **PT+κ₁**: mean |residual| in **22–24 K** = **%.6g**; outside = **%.6g**.', mae22_ref, ...
    audit.mae_abs_residual_outside_22_24_K(1));
lines{end + 1} = sprintf('- **Best α-augmented** (%s): 22–24 K = **%.6g**.', char(bestTbl.best_alpha_augmented_model(1)), mae22_alp);
lines{end + 1} = '';

lines{end + 1} = '## Interpretation';
if strcmp(v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1, "YES") && strcmp(v.REORGANIZATION_TERM_SUPPORTED, "YES")
    lines{end + 1} = 'Out-of-sample LOOCV favors an alpha-based linear term, with reduced errors near 22–24 K; **reorganization-term** language is supported at the level of this linear falsification test.';
elseif strcmp(v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1, "YES")
    lines{end + 1} = 'Alpha-augmented models win on LOOCV RMSE, but transition residuals are not clearly improved; treat **alpha** as a predictive coordinate with **mechanistic follow-up** still required.';
else
    lines{end + 1} = 'No alpha-derived linear term beats **spread90_50 + kappa1** on fair LOOCV; **alpha** remains a **mechanistic hint**, not part of the current predictive law.';
end
lines{end + 1} = '';

lines{end + 1} = '## Conclusion';
lines{end + 1} = sprintf(['Agent 24F compared linear aging closures with strict LOOCV on **n = %d** shared temperatures. ', ...
    'Verdicts below summarize whether **α_res / |α_res|** improves the **PT + κ₁** reference and whether gains localize to **22–24 K**. ', ...
    'Character of gain: **%s**.'], height(subOv), gainNote);
lines{end + 1} = '';

lines{end + 1} = '## Mandatory verdicts';
lines{end + 1} = sprintf('- **ALPHA_RES_IMPROVES_AGING_CLOSURE:** **%s**', v.ALPHA_RES_IMPROVES_AGING_CLOSURE);
lines{end + 1} = sprintf('- **ABS_ALPHA_RES_BETTER_THAN_SIGNED:** **%s**', v.ABS_ALPHA_RES_BETTER_THAN_SIGNED);
lines{end + 1} = sprintf('- **ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1:** **%s**', v.ALPHA_BASED_TERM_OUTPERFORMS_PT_PLUS_KAPPA1);
lines{end + 1} = sprintf('- **TRANSITION_RESIDUAL_REDUCED:** **%s**', v.TRANSITION_RESIDUAL_REDUCED);
lines{end + 1} = sprintf('- **REORGANIZATION_TERM_SUPPORTED:** **%s**', v.REORGANIZATION_TERM_SUPPORTED);
lines{end + 1} = '';

lines{end + 1} = '## Figures';
lines{end + 1} = sprintf('- `%s`', strrep(figPath1.png, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(figPath2.png, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(figPath3.png, '\', '/'));
lines{end + 1} = '';

lines{end + 1} = '*Auto-generated by `analysis/run_aging_alpha_closure_agent24f.m`.*';

txt = strjoin(lines, newline);
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'aging_alpha_closure_agent24f_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0, fwrite(fid, txt); fclose(fid); end
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
