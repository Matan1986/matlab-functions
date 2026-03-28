function out = run_alternative_coordinate_search()
%RUN_ALTERNATIVE_COORDINATE_SEARCH Simple coordinate pool vs X for A, R, kappa (LOOCV).
set(0, 'DefaultFigureVisible', 'off');

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

% Manual run folder (avoids createRunContext system/git calls that can stall in batch).
runsRoot = fullfile(repoRoot, 'results', 'cross_experiment', 'runs');
if exist(runsRoot, 'dir') ~= 7
    mkdir(runsRoot);
end
ts = char(datetime('now', 'Format', 'yyyy_MM_dd_HHmmss'));
runId = ['run_' ts '_alternative_coordinate_search'];
runDir = fullfile(runsRoot, runId);
mkdir(runDir);
ensureRunSubdirs(runDir);
fid = fopen(fullfile(runDir, 'run_manifest.json'), 'w');
if fid > 0
    fprintf(fid, '{ "run_id": "%s", "experiment": "cross_experiment", "label": "alternative_coordinate_search" }\n', runId);
    fclose(fid);
end
fid = fopen(fullfile(runDir, 'log.txt'), 'w');
if fid > 0
    fprintf(fid, 'run_alternative_coordinate_search\n');
    fclose(fid);
end
fid = fopen(fullfile(runDir, 'run_notes.txt'), 'w');
if fid > 0
    fprintf(fid, 'Agent 11 alternative coordinate search.\n');
    fclose(fid);
end
fid = fopen(fullfile(runDir, 'config_snapshot.m'), 'w');
if fid > 0
    fprintf(fid, '%% manual run folder\n');
    fclose(fid);
end

barrierPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
kappaPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', 'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'kappa_vs_T.csv');
ptSumPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_25_013849_pt_robust_minpts7', 'tables', 'PT_summary.csv');

bd = readtable(barrierPath, 'VariableNamingRule', 'preserve');
kap = readtable(kappaPath, 'VariableNamingRule', 'preserve');
if ismember('T', kap.Properties.VariableNames) && ~ismember('T_K', kap.Properties.VariableNames)
    kap.Properties.VariableNames{'T'} = 'T_K';
end
merged = innerjoin(bd, kap(:, {'T_K', 'kappa'}), 'Keys', 'T_K');

pt = readtable(ptSumPath, 'VariableNamingRule', 'preserve');
pt = renamevars(pt, {'mean_threshold_mA', 'skewness', 'cdf_rmse'}, ...
    {'pt_sum_mean_thr_mA', 'pt_sum_thr_skewness', 'pt_sum_cdf_rmse'});
pt = pt(:, {'T_K', 'pt_sum_mean_thr_mA', 'pt_sum_thr_skewness', 'pt_sum_cdf_rmse'});
merged = outerjoin(merged, pt, 'Keys', 'T_K', 'MergeKeys', true);

use = merged.row_valid == 1 ...
    & isfinite(merged.A_T_interp) & isfinite(merged.R_T_interp) ...
    & isfinite(merged.X_T_interp) & isfinite(merged.I_peak_mA) ...
    & isfinite(merged.S_peak) & isfinite(merged.kappa);
df = sortrows(merged(use, :), 'T_K');

df = augmentCoordinateCandidates(df);

candSingles = candidateSingleNames();
primaryPairs = candidatePrimaryPairList();

rows = struct('target', {}, 'model_type', {}, 'coordinate', {}, 'predictors', {}, ...
    'n', {}, 'loocv_rmse', {}, 'pearson_loocv', {}, 'spearman_loocv', {});
targets = {'A_T_interp', 'R_T_interp', 'kappa'};
maskNo22 = df.T_K ~= 22;

for ti = 1:numel(targets)
    yName = targets{ti};
    for ci = 1:numel(candSingles)
        cname = candSingles{ci};
        if ~isCandidateValidForTarget(cname, yName)
            continue;
        end
        r = evalRow(df, yName, 'single', cname, {cname});
        if ~isempty(r)
            rows = [rows; r]; %#ok<AGROW>
        end
    end
    prim = primaryPairs;
    prim = prim(cellfun(@(s) isCandidateValidForTarget(s, yName), prim));
    for i = 1:numel(prim)
        for j = i+1:numel(prim)
            n1 = prim{i};
            n2 = prim{j};
            if ~isCandidateValidForTarget(n1, yName) || ~isCandidateValidForTarget(n2, yName)
                continue;
            end
            label = sprintf('%s+%s', n1, n2);
            r = evalRow(df, yName, 'pair', label, {n1, n2});
            if ~isempty(r)
                rows = [rows; r]; %#ok<AGROW>
            end
        end
    end
end

metrics = struct2table(rows);
writetable(metrics, fullfile(runDir, 'tables', 'coordinate_candidate_metrics.csv'));

stabRows = [];
for ti = 1:numel(targets)
    yName = targets{ti};
    [rmse, pr, sp] = loocvLinearCoreY(df(maskNo22, :), {'X_T_interp'}, yName);
    stabRows = [stabRows; table({yName}, {'X_T_interp_only'}, rmse, pr, sp, ...
        'VariableNames', {'target', 'model', 'loocv_rmse_no22K', 'pearson_loocv_no22K', 'spearman_loocv_no22K'})]; %#ok<AGROW>
end
writetable(stabRows, fullfile(runDir, 'tables', 'coordinate_stability_no22K.csv'));

bestLines = [];
for ti = 1:numel(targets)
    yName = targets{ti};
    sub = metrics(strcmp(metrics.target, yName) & strcmp(metrics.model_type, 'single'), :);
    [~, ix] = min(sub.loocv_rmse);
    best1 = sub(ix, :);
    subp = metrics(strcmp(metrics.target, yName) & strcmp(metrics.model_type, 'pair'), :);
    [~, jx] = min(subp.loocv_rmse);
    best2 = subp(jx, :);
    xrow = sub(strcmp(sub.coordinate, 'X_T_interp'), :);
    xRmse = xrow.loocv_rmse(1);
    bestLines = [bestLines; table({yName}, best1.coordinate, best1.loocv_rmse, xRmse, ...
        best1.loocv_rmse < xRmse - 1e-12, best2.coordinate, best2.loocv_rmse, ...
        best2.loocv_rmse < xRmse - 1e-12, ...
        'VariableNames', {'target', 'best_single_name', 'best_single_loocv_rmse', 'X_only_loocv_rmse', ...
        'single_beats_X_rmse', 'best_pair_formula', 'best_pair_loocv_rmse', 'pair_beats_X_rmse'})]; %#ok<AGROW>
end
writetable(bestLines, fullfile(runDir, 'tables', 'best_coordinate_models.csv'));

% Figures: best single per target
for ti = 1:numel(targets)
    yName = targets{ti};
    sub = metrics(strcmp(metrics.target, yName) & strcmp(metrics.model_type, 'single'), :);
    [~, ix] = min(sub.loocv_rmse);
    cname = sub.coordinate{ix};
    xv = df.(cname);
    yv = df.(yName);
    stem = figureStemForTarget(yName);
    fig = create_figure('Name', stem, 'NumberTitle', 'off');
    ax = axes(fig);
    plot(ax, xv, yv, 'o', 'MarkerSize', 10, 'LineWidth', 2);
    hold(ax, 'on');
    for ii = 1:height(df)
        text(ax, xv(ii), yv(ii), sprintf('  %g', df.T_K(ii)), 'FontSize', 11);
    end
    grid(ax, 'on');
    xlabel(ax, cname, 'FontSize', 14);
    ylabel(ax, yLabelPretty(yName), 'FontSize', 14);
    save_run_figure(fig, stem, runDir);
    close(fig);
end

% Verdict
beats = 0;
repLines = strings(0, 1);
for ti = 1:numel(targets)
    yName = targets{ti};
    sub = metrics(strcmp(metrics.target, yName) & strcmp(metrics.model_type, 'single'), :);
    xrow = sub(strcmp(sub.coordinate, 'X_T_interp'), :);
    [bestRmse, bx] = min(sub.loocv_rmse);
    bestC = sub.coordinate{bx};
    if bestRmse < xrow.loocv_rmse(1) - 1e-15
        beats = beats + 1;
    end
    repLines(end+1, 1) = sprintf('%s: X_RMSE=%.6g best=%s RMSE=%.6g', yName, xrow.loocv_rmse(1), bestC, bestRmse); %#ok<AGROW>
end
if beats == 3
    verdict = 'YES';
elseif beats > 0
    verdict = 'PARTIAL';
else
    verdict = 'NO';
end

singles = metrics(strcmp(metrics.model_type, 'single'), :);
u = unique(singles.coordinate);
meanRmse = nan(numel(u), 1);
for k = 1:numel(u)
    msk = strcmp(singles.coordinate, u{k});
    meanRmse(k) = mean(singles.loocv_rmse(msk), 'omitnan');
end
[~, ord] = sort(meanRmse, 'ascend');
bestGlobal = u{ord(1)};
bestGlobalMean = meanRmse(ord(1));

report = buildReportMd(repoRoot, runDir, barrierPath, kappaPath, ptSumPath, height(df), ...
    bestLines, verdict, beats, bestGlobal, bestGlobalMean, repLines);
reportPath = save_run_report(report, 'alternative_coordinate_report.md', runDir);

zipPath = buildReviewZipLocal(runDir, 'alternative_coordinate_search_bundle.zip');

fprintf('\nRun directory:\n%s\n', runDir);
fprintf('Verdict vs X (singles): %s\n', verdict);
fprintf('Best global single (mean RMSE A,R,kappa): %s (%.6g)\n', bestGlobal, bestGlobalMean);

out = struct('runDir', string(runDir), 'verdict', verdict, 'bestGlobal', string(bestGlobal));
end

%% ------------------------------------------------------------------------
function df = augmentCoordinateCandidates(df)
Ip = df.I_peak_mA;
Sp = df.S_peak;
Xv = df.X_T_interp;
kap = df.kappa;
df.I_peak_over_S_peak = Ip ./ Sp;
df.kappa_over_S_peak = kap ./ Sp;
df.q90_over_q10 = df.q90_I_mA ./ df.q10_I_mA;
df.q75_over_q25 = df.q75_I_mA ./ df.q25_I_mA;
df.iq90_10_over_iq75_25 = df.iq90_10_mA ./ df.iq75_25_mA;
tr = max(df.tail_ratio_high_over_low, 1e-300);
df.log10_tail_ratio = log10(tr);
df.X_times_kappa = Xv .* kap;
df.X_over_kappa = Xv ./ kap;
for a = [-1, 0, 1]
    for b = [-1, 0, 1]
        if a == 0 && b == 0
            continue;
        end
        if a == 0
            Ia = ones(height(df), 1);
        else
            Ia = Ip .^ a;
        end
        if b == 0
            Sb = ones(height(df), 1);
        else
            Sb = Sp .^ b;
        end
        nm = ipowSpName(a, b);
        df.(nm) = Ia .* Sb;
    end
end
end

function v = candidateSingleNames()
v = { ...
    'I_peak_mA', 'S_peak', 'kappa', 'X_T_interp', ...
    'mean_I_mA', 'median_I_mA', 'mode_I_mA', ...
    'q10_I_mA', 'q25_I_mA', 'q50_I_mA', 'q75_I_mA', 'q90_I_mA', ...
    'iq75_25_mA', 'iq90_10_mA', ...
    'asym_q75_50_minus_q50_25', 'tail_ratio_high_over_low', 'skewness_quantile', ...
    'cheb_m2_z', 'cheb_m4_z', 'moment_I2_weighted', ...
    'pt_svd_score1', 'pt_svd_score2', 'mass_upper_half', ...
    'pt_sum_mean_thr_mA', 'pt_sum_thr_skewness', 'pt_sum_cdf_rmse', ...
    'log10_tail_ratio', ...
    'I_peak_over_S_peak', 'kappa_over_S_peak', ...
    'q90_over_q10', 'q75_over_q25', 'iq90_10_over_iq75_25', ...
    'Ip_m1_Sp_m1', 'Ip_m1_Sp0', 'Ip_m1_Sp1', 'Ip0_Sp_m1', 'Ip0_Sp1', 'Ip1_Sp_m1', 'Ip1_Sp0', 'Ip1_Sp1', ...
    'X_times_kappa', 'X_over_kappa'};
end

function v = candidatePrimaryPairList()
v = { ...
    'X_T_interp', 'I_peak_mA', 'S_peak', 'kappa', ...
    'mean_I_mA', 'median_I_mA', 'q50_I_mA', ...
    'asym_q75_50_minus_q50_25', 'skewness_quantile', ...
    'pt_svd_score1', 'pt_svd_score2', ...
    'I_peak_over_S_peak', 'kappa_over_S_peak', ...
    'log10_tail_ratio', 'pt_sum_mean_thr_mA'};
end

function ok = usesKappa(name)
ok = strcmp(name, 'kappa') || contains(name, 'kappa');
end

function nm = ipowSpName(a, b)
% Valid MATLAB identifier for I_peak^a * S_peak^b with a,b in {-1,0,1}.
sa = ternab(a);
sb = ternab(b);
nm = sprintf('Ip%s_Sp%s', sa, sb);
end

function s = ternab(v)
if v == -1
    s = 'm1';
elseif v == 0
    s = '0';
else
    s = '1';
end
end

function ok = isCandidateValidForTarget(cname, yName)
ok = true;
if strcmp(yName, 'kappa') && usesKappa(cname)
    ok = false;
end
if strcmp(yName, 'A_T_interp') && strcmp(cname, 'A_T_interp')
    ok = false;
end
if strcmp(yName, 'R_T_interp') && strcmp(cname, 'R_T_interp')
    ok = false;
end
end

function row = evalRow(df, yName, mtype, label, predCols)
row = [];
yv = df.(yName);
n = height(df);
mfin = true(n, 1);
for k = 1:numel(predCols)
    mfin = mfin & isfinite(df.(predCols{k}));
end
mfin = mfin & isfinite(yv);
d = df(mfin, :);
minN = 3 + (numel(predCols) - 1);
if height(d) < minN
    return;
end
[rmse, pr, sp] = loocvLinearCoreY(d, predCols, yName);
if ~isfinite(rmse)
    return;
end
row = struct('target', yName, 'model_type', mtype, 'coordinate', label, ...
    'predictors', strjoin(predCols, '|'), 'n', height(d), ...
    'loocv_rmse', rmse, 'pearson_loocv', pr, 'spearman_loocv', sp);
end

function [rmse, pear_r, spear_r] = loocvLinearCoreY(d, predCols, yName)
yv = d.(yName);
n = height(d);
X = ones(n, 1);
for k = 1:numel(predCols)
    X = [X, d.(predCols{k})]; %#ok<AGROW>
end
p = size(X, 2);
sse = 0;
yhat = nan(n, 1);
for i = 1:n
    mask = true(n, 1);
    mask(i) = false;
    Xi = X(mask, :);
    yi = yv(mask);
    if rank(Xi) < p
        rmse = NaN; pear_r = NaN; spear_r = NaN; return;
    end
    b = Xi \ yi;
    yhat(i) = X(i, :) * b;
    sse = sse + (yv(i) - yhat(i))^2;
end
rmse = sqrt(sse / n);
pear_r = corr(yv, yhat, 'rows', 'pairwise');
spear_r = corr(yv, yhat, 'rows', 'pairwise', 'type', 'Spearman');
end

function s = figureStemForTarget(yName)
switch yName
    case 'A_T_interp'
        s = 'A_vs_coordinate';
    case 'R_T_interp'
        s = 'R_vs_coordinate';
    otherwise
        s = 'kappa_vs_coordinate';
end
end

function s = yLabelPretty(yName)
switch yName
    case 'A_T_interp'
        s = 'A (interp)';
    case 'R_T_interp'
        s = 'R (interp)';
    otherwise
        s = '\kappa';
end
end

function txt = buildReportMd(~, runDir, barrierPath, kappaPath, ptPath, nT, bestLines, verdict, beats, bestGlobal, bestGlobalMean, repLines)
lines = strings(0, 1);
lines(end+1, 1) = "# Alternative coordinate search (beyond X)";
lines(end+1, 1) = "";
lines(end+1, 1) = "## Inputs (read-only)";
lines(end+1, 1) = sprintf("- `barrier_descriptors.csv`: `%s`", barrierPath);
lines(end+1, 1) = sprintf("- `kappa_vs_T.csv`: `%s`", kappaPath);
lines(end+1, 1) = sprintf("- `PT_summary.csv`: `%s`", ptPath);
lines(end+1, 1) = "";
lines(end+1, 1) = sprintf("Merged n = **%d** temperatures.", nT);
lines(end+1, 1) = "";
lines(end+1, 1) = "## Versus X (`X_T_interp` single-coordinate LOOCV)";
lines(end+1, 1) = "";
for i = 1:height(bestLines)
    lines(end+1, 1) = sprintf("- **%s**: best single `%s` (RMSE=%.6g) vs X (RMSE=%.6g). Beats X: %s", ...
        bestLines.target{i}, bestLines.best_single_name{i}, bestLines.best_single_loocv_rmse(i), ...
        bestLines.X_only_loocv_rmse(i), tern(bestLines.single_beats_X_rmse(i)));
end
lines(end+1, 1) = "";
lines(end+1, 1) = sprintf("**Targets where some single beats X:** %d / 3 → verdict **%s**.", beats, verdict);
lines(end+1, 1) = "";
lines(end+1, 1) = "### Detail";
for i = 1:numel(repLines)
    lines(end+1, 1) = char(repLines(i));
end
lines(end+1, 1) = "";
lines(end+1, 1) = sprintf("**Best single by mean LOOCV RMSE across A, R, kappa:** `%s` (mean = %.6g).", bestGlobal, bestGlobalMean);
lines(end+1, 1) = "";
lines(end+1, 1) = "## Artifacts";
lines(end+1, 1) = sprintf("- `tables/coordinate_candidate_metrics.csv`");
lines(end+1, 1) = sprintf("- `tables/best_coordinate_models.csv`");
lines(end+1, 1) = sprintf("- `tables/coordinate_stability_no22K.csv`");
lines(end+1, 1) = sprintf("- `figures/A_vs_coordinate.*`");
lines(end+1, 1) = sprintf("- `figures/R_vs_coordinate.*`");
lines(end+1, 1) = sprintf("- `figures/kappa_vs_coordinate.*`");
lines(end+1, 1) = "";
lines(end+1, 1) = sprintf("Run folder: `%s`", runDir);
txt = join(lines, newline);
end

function s = tern(tf)
if tf
    s = 'yes';
else
    s = 'no';
end
end

function ensureRunSubdirs(runDir)
for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
end

function zipPath = buildReviewZipLocal(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, ...
    runDir);
end
