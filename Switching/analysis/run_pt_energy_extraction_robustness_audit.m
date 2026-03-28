function out = run_pt_energy_extraction_robustness_audit(cfg)
% run_pt_energy_extraction_robustness_audit
% Compare P_T extraction (switching_barrier_distribution_from_map) across
% reasonable cfg variants; summarize PT_summary and energy stats (E = alpha*I).
%
% Does not modify switching_barrier_distribution_from_map.m. Each variant
% invokes that function and produces its own standard PT run directory.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingDir = fileparts(analysisDir);
repoRoot = fileparts(switchingDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'analysis')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyAuditDefaults(cfg);

runCfg = struct();
runCfg.runLabel = cfg.auditRunLabel;
runCfg.dataset = 'pt_extraction_robustness_audit';
if isfield(cfg, 'sourceRunId') && strlength(string(cfg.sourceRunId)) > 0
    runCfg.dataset = sprintf('map_source:%s', char(string(cfg.sourceRunId)));
end
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
ensureArtifactDirs(runDir);

fprintf('PT / energy robustness audit run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_pt_energy_extraction_robustness_audit started', stampNow()));

variants = buildVariantSpecs(cfg);
nV = numel(variants);
childRunIds = strings(nV, 1);
childRunDirs = strings(nV, 1);

for k = 1:nV
    v = variants(k);
    bcfg = v.barrierCfg;
    appendText(run.log_path, sprintf('Running extraction variant %s ...', v.key));
    bout = switching_barrier_distribution_from_map(bcfg);
    childRunIds(k) = string(bout.run.run_id);
    childRunDirs(k) = bout.runDir;
    appendText(run.log_path, sprintf('Variant %s -> %s', v.key, bout.runDir));
end

vk = strings(numel(variants), 1);
vl = strings(numel(variants), 1);
for ii = 1:numel(variants)
    vk(ii) = string(variants(ii).key);
    vl(ii) = string(variants(ii).label);
end
variantManifest = table(vk, vl, childRunIds(:), childRunDirs(:), ...
    'VariableNames', {'variant_key', 'variant_label', 'child_run_id', 'child_run_dir'});
save_run_table(variantManifest, 'pt_variant_child_runs.csv', runDir);

summaries = cell(nV, 1);
matrices = cell(nV, 1);
currentsCell = cell(nV, 1);
for k = 1:nV
    ptPath = fullfile(char(childRunDirs(k)), 'tables', 'PT_matrix.csv');
    smPath = fullfile(char(childRunDirs(k)), 'tables', 'PT_summary.csv');
    summaries{k} = readtable(smPath, 'VariableNamingRule', 'preserve');
    [tk, currents, PT] = loadPTMatrixLocal(ptPath);
    matrices{k} = struct('T_K', tk, 'currents', currents, 'PT', PT);
    currentsCell{k} = currents(:);
end

refK = 1;
Tref = matrices{refK}.T_K(:);
Iref = matrices{refK}.currents(:);
commonT = Tref;
for k = 2:nV
    commonT = intersect(commonT, matrices{k}.T_K(:), 'stable');
end
if isempty(commonT)
    error('run_pt_energy_extraction_robustness_audit:NoCommonT', 'No overlapping temperatures across variants.');
end

ptRows = table( ...
    string.empty(0, 1), string.empty(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'variant_key', 'variant_label', 'T_K', 'mean_threshold_mA', 'std_threshold_mA', ...
    'skewness', 'cdf_rmse', 'PT_area'});
energyRows = table( ...
    string.empty(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'variant_key', 'T_K', 'mean_E', 'std_E', 'skew_E'});
metrics = initRobustnessMetrics(nV, variants);

for k = 1:nV
    M = matrices{k};
    [~, ia] = ismember(commonT, M.T_K(:));
    valid = ia > 0;
    Tuse = commonT(valid);
    ia = ia(valid);
    PTsub = M.PT(ia, :);
    cur = M.currents(:);
    if numel(cur) ~= numel(Iref) || max(abs(cur - Iref)) > 1e-9
        error('run_pt_energy_extraction_robustness_audit:CurrentGridMismatch', ...
            'Variant %s current grid differs from reference; audit expects a fixed I axis.', variants(k).key);
    end

    Sm = summaries{k};
    [~, ism] = ismember(Tuse, Sm.T_K(:));
    for j = 1:numel(Tuse)
        if ism(j) < 1
            continue;
        end
        row = table();
        row.variant_key = string(variants(k).key);
        row.variant_label = string(variants(k).label);
        row.T_K = Tuse(j);
        row.mean_threshold_mA = Sm.mean_threshold_mA(ism(j));
        row.std_threshold_mA = Sm.std_threshold_mA(ism(j));
        row.skewness = Sm.skewness(ism(j));
        row.cdf_rmse = Sm.cdf_rmse(ism(j));
        row.PT_area = Sm.PT_area(ism(j));
        ptRows = [ptRows; row]; %#ok<AGROW>
    end

    maskCanon = isfinite(Tuse) & Tuse <= cfg.canonicalTemperatureMaxK;
    Tcan = Tuse(maskCanon);
    PTcan = PTsub(maskCanon, :);
    [statsE, ~] = computeEnergyStatsLocal(Tcan, cur, PTcan, cfg.alpha, 1.0);
    for j = 1:numel(Tcan)
        er = table();
        er.variant_key = string(variants(k).key);
        er.T_K = Tcan(j);
        er.mean_E = statsE.mean_E(j);
        er.std_E = statsE.std_E(j);
        er.skew_E = statsE.skew_E(j);
        energyRows = [energyRows; er]; %#ok<AGROW>
    end

    mRef = matrices{refK};
    [~, ir] = ismember(Tuse, mRef.T_K(:));
    PTref = mRef.PT(ir, :);
    rowL2 = sqrt(sum((PTsub - PTref).^ 2, 2, 'omitnan')) ./ max(sqrt(sum(PTref.^2, 2, 'omitnan')), eps);
    metrics.max_pt_row_l2_rel(k) = max(rowL2, [], 'omitnan');
    metrics.median_pt_row_l2_rel(k) = median(rowL2, 'omitnan');

    vRefMean = interp1(mRef.T_K(:), summaries{refK}.mean_threshold_mA(:), Tuse, 'linear', NaN);
    vMk = Sm.mean_threshold_mA(ism);
    relM = abs(vMk - vRefMean) ./ max(abs(vRefMean), eps);
    metrics.max_rel_mean_threshold(k) = max(relM, [], 'omitnan');
    metrics.median_rel_mean_threshold(k) = median(relM, 'omitnan');

    vRefStd = interp1(mRef.T_K(:), summaries{refK}.std_threshold_mA(:), Tuse, 'linear', NaN);
    relS = abs(Sm.std_threshold_mA(ism) - vRefStd) ./ max(abs(vRefStd), eps);
    metrics.max_rel_std_threshold(k) = max(relS, [], 'omitnan');

    rho = corr(vMk, vRefMean, 'Type', 'Spearman', 'rows', 'pairwise');
    metrics.spearman_mean_vs_ref(k) = rho;

    fin = isfinite(vMk) & isfinite(vRefMean);
    if nnz(fin) >= 2
        dRef = diff(vRefMean(fin));
        dVar = diff(vMk(fin));
        agree = (sign(dRef) == sign(dVar)) | (abs(dRef) < 1e-12 & abs(dVar) < 1e-12);
        metrics.trend_step_agreement_frac(k) = mean(agree, 'omitnan');
    else
        metrics.trend_step_agreement_frac(k) = NaN;
    end

    if nnz(fin) >= 2
        pRef = polyfit(Tuse(fin), vRefMean(fin), 1);
        pVar = polyfit(Tuse(fin), vMk(fin), 1);
        metrics.slope_mean_sign_match(k) = (sign(pRef(1)) == sign(pVar(1))) || ...
            ((abs(pRef(1)) < 1e-12) && (abs(pVar(1)) < 1e-12));
    else
        metrics.slope_mean_sign_match(k) = false;
    end
end

ptSummaryPath = save_run_table(ptRows, 'PT_variant_summary_comparison.csv', runDir);
energyPath = save_run_table(energyRows, 'energy_stats_variant_comparison.csv', runDir);
metricsTbl = struct2table(metrics);
metricsPath = save_run_table(metricsTbl, 'pt_robustness_metrics_by_variant.csv', runDir);

savePTSummaryComparisonFig(runDir, commonT, summaries, variants, refK);
saveEnergyComparisonFig(runDir, energyRows, variants);
saveRepresentativePTRowsFig(runDir, matrices, variants, Iref, cfg.representativeTemperaturesK);

grade = classifyGrade(metrics, refK);
reportText = buildAuditReport(cfg, runDir, variants, childRunIds, metrics, grade, ptSummaryPath, energyPath, metricsPath);
reportPath = save_run_report(reportText, 'PT_energy_robustness_report.md', runDir);

zipPath = buildReviewZip(runDir, 'pt_energy_robustness_bundle.zip');

appendText(run.notes_path, sprintf('Robustness grade: %s', grade));
appendText(run.log_path, sprintf('Saved %s', ptSummaryPath));
appendText(run.log_path, sprintf('Saved %s', energyPath));
appendText(run.log_path, sprintf('Saved %s', reportPath));
appendText(run.log_path, sprintf('Saved %s', zipPath));
appendText(run.log_path, sprintf('[%s] run_pt_energy_extraction_robustness_audit complete', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.grade = grade;
out.variant_child_runs = variantManifest;
out.metrics = metricsTbl;
out.paths = struct( ...
    'pt_variant_summary', string(ptSummaryPath), ...
    'energy_stats', string(energyPath), ...
    'metrics', string(metricsPath), ...
    'report', string(reportPath), ...
    'review_zip', string(zipPath));

fprintf('\n=== PT / energy extraction robustness audit complete ===\n');
fprintf('Grade: %s\n', grade);
fprintf('Report: %s\n', reportPath);
end

function cfg = applyAuditDefaults(cfg)
cfg = setDf(cfg, 'auditRunLabel', 'pt_energy_robustness_audit');
cfg = setDf(cfg, 'canonicalTemperatureMaxK', 30);
cfg = setDf(cfg, 'alpha', 1.0);
cfg = setDf(cfg, 'representativeTemperaturesK', [4, 16, 22, 28]);
cfg = setDf(cfg, 'sourceRunId', '');
end

function variants = buildVariantSpecs(cfg)
base = struct();
if isfield(cfg, 'sourceRunId') && strlength(string(cfg.sourceRunId)) > 0
    base.sourceRunId = char(string(cfg.sourceRunId));
end

specs = struct('key', {}, 'label', {}, 'barrierCfg', {});
idx = 0;

idx = idx + 1;
specs(idx).key = 'canonical';
specs(idx).label = 'Canonical defaults (movmean w=5, monotone CDF)';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_canonical', ...
    'smoothingWindow', 5, ...
    'smoothingMethod', 'movmean', ...
    'enforceMonotoneCDF', true, ...
    'minPointsPerTemperature', 6));

idx = idx + 1;
specs(idx).key = 'smooth_w3';
specs(idx).label = 'Mild smoothing: movmean window 3';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_smooth_w3', ...
    'smoothingWindow', 3, ...
    'smoothingMethod', 'movmean', ...
    'enforceMonotoneCDF', true, ...
    'minPointsPerTemperature', 6));

idx = idx + 1;
specs(idx).key = 'smooth_w7';
specs(idx).label = 'Stronger smoothing: movmean window 7';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_smooth_w7', ...
    'smoothingWindow', 7, ...
    'smoothingMethod', 'movmean', ...
    'enforceMonotoneCDF', true, ...
    'minPointsPerTemperature', 6));

idx = idx + 1;
specs(idx).key = 'sgolay_w5';
specs(idx).label = 'Savitzky-Golay smooth, window 5';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_sgolay_w5', ...
    'smoothingWindow', 5, ...
    'smoothingMethod', 'sgolay', ...
    'enforceMonotoneCDF', true, ...
    'minPointsPerTemperature', 6));

idx = idx + 1;
specs(idx).key = 'no_monotone_cdf';
specs(idx).label = 'No monotone CDF enforcement (derivative on smoothed S_norm only)';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_no_monotone', ...
    'smoothingWindow', 5, ...
    'smoothingMethod', 'movmean', ...
    'enforceMonotoneCDF', false, ...
    'minPointsPerTemperature', 6));

idx = idx + 1;
specs(idx).key = 'minpts_7';
specs(idx).label = 'Stricter row validity: minPointsPerTemperature = 7 (marginal vs default 6)';
specs(idx).barrierCfg = mergeBarrier(base, struct( ...
    'runLabel', 'pt_robust_minpts7', ...
    'smoothingWindow', 5, ...
    'smoothingMethod', 'movmean', ...
    'enforceMonotoneCDF', true, ...
    'minPointsPerTemperature', 7));

variants = specs(:);
end

function b = mergeBarrier(base, extra)
b = base;
f = fieldnames(extra);
for i = 1:numel(f)
    b.(f{i}) = extra.(f{i});
end
end

function m = initRobustnessMetrics(nV, variants)
m = struct();
m.variant_key = string({variants.key}).';
m.max_pt_row_l2_rel = NaN(nV, 1);
m.median_pt_row_l2_rel = NaN(nV, 1);
m.max_rel_mean_threshold = NaN(nV, 1);
m.median_rel_mean_threshold = NaN(nV, 1);
m.max_rel_std_threshold = NaN(nV, 1);
m.spearman_mean_vs_ref = NaN(nV, 1);
m.trend_step_agreement_frac = NaN(nV, 1);
m.slope_mean_sign_match = false(nV, 1);
end

function grade = classifyGrade(metrics, refK)
% Grades emphasize whether thermal *trends* and mean location survive, while
% allowing larger sensitivity in width-like (std) and full-row shape (L2)
% when smoothing method changes — consistent with the audit goal.
mask = true(size(metrics.variant_key));
mask(refK) = false;
if ~any(mask)
    grade = 'A';
    return;
end

maxRelMean = max(metrics.max_rel_mean_threshold(mask), [], 'omitnan');
maxRelStd = max(metrics.max_rel_std_threshold(mask), [], 'omitnan');
maxL2 = max(metrics.max_pt_row_l2_rel(mask), [], 'omitnan');
minRho = min(metrics.spearman_mean_vs_ref(mask), [], 'omitnan');
minStep = min(metrics.trend_step_agreement_frac(mask), [], 'omitnan');
slopeOk = all(metrics.slope_mean_sign_match(mask));

if ~slopeOk || minRho < 0.82 || minStep < 0.55
    grade = 'D';
    return;
end

if maxRelMean < 0.05 && maxRelStd < 0.35 && maxL2 < 0.35 && minRho > 0.98 && minStep > 0.88
    grade = 'A';
elseif maxRelMean < 0.20 && maxRelStd < 1.75 && maxL2 < 0.85 && minRho > 0.92 && minStep > 0.80
    grade = 'B';
elseif maxRelMean < 0.35 && minRho > 0.88
    grade = 'C';
else
    grade = 'D';
end
end

function savePTSummaryComparisonFig(runDir, commonT, summaries, variants, refK)
base_name = 'PT_summary_method_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 16 12]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

meanM = NaN(numel(commonT), numel(variants));
stdM = meanM;
skM = meanM;
for k = 1:numel(variants)
    Sm = summaries{k};
    [~, ik] = ismember(commonT, Sm.T_K(:));
    for j = 1:numel(commonT)
        if ik(j) < 1
            continue;
        end
        meanM(j, k) = Sm.mean_threshold_mA(ik(j));
        stdM(j, k) = Sm.std_threshold_mA(ik(j));
        skM(j, k) = Sm.skewness(ik(j));
    end
end

ax1 = nexttile(tl);
hold(ax1, 'on');
grid(ax1, 'on');
cols = lines(numel(variants));
for k = 1:numel(variants)
    lw = 2.3;
    if k == refK
        lw = 3;
    end
    plot(ax1, commonT, meanM(:, k), '-o', 'Color', cols(k, :), 'LineWidth', lw, ...
        'MarkerSize', 5, 'DisplayName', char(variants(k).key));
end
hold(ax1, 'off');
xlabel(ax1, 'Temperature T (K)');
ylabel(ax1, 'Mean threshold (mA)');
title(ax1, 'P_T summary: mean threshold vs T');
legend(ax1, 'Location', 'best');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl);
hold(ax2, 'on');
grid(ax2, 'on');
for k = 1:numel(variants)
    lw = 2.3;
    if k == refK
        lw = 3;
    end
    plot(ax2, commonT, stdM(:, k), '-s', 'Color', cols(k, :), 'LineWidth', lw, ...
        'MarkerSize', 5, 'DisplayName', char(variants(k).key));
end
hold(ax2, 'off');
xlabel(ax2, 'Temperature T (K)');
ylabel(ax2, 'Std threshold (mA)');
title(ax2, 'P_T summary: width (\sigma) vs T');
legend(ax2, 'Location', 'best');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

ax3 = nexttile(tl);
hold(ax3, 'on');
grid(ax3, 'on');
for k = 1:numel(variants)
    lw = 2.3;
    if k == refK
        lw = 3;
    end
    plot(ax3, commonT, skM(:, k), '-^', 'Color', cols(k, :), 'LineWidth', lw, ...
        'MarkerSize', 5, 'DisplayName', char(variants(k).key));
end
hold(ax3, 'off');
xlabel(ax3, 'Temperature T (K)');
ylabel(ax3, 'Skewness');
title(ax3, 'P_T summary: skew vs T');
legend(ax3, 'Location', 'best');
set(ax3, 'FontSize', 14, 'LineWidth', 1.2);

save_run_figure(fig, base_name, runDir);
close(fig);
end

function saveEnergyComparisonFig(runDir, energyRows, variants)
base_name = 'energy_stats_method_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 16 10]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

keys = string({variants.key});
cols = lines(numel(variants));

ax1 = nexttile(tl);
hold(ax1, 'on');
grid(ax1, 'on');
for k = 1:numel(variants)
    sub = energyRows(energyRows.variant_key == keys(k), :);
    [Ts, ord] = sort(sub.T_K);
    plot(ax1, Ts, sub.mean_E(ord), '-o', 'Color', cols(k, :), 'LineWidth', 2.3, ...
        'MarkerSize', 5, 'DisplayName', char(keys(k)));
end
hold(ax1, 'off');
xlabel(ax1, 'Temperature T (K)');
ylabel(ax1, '\langleE\rangle (arb. units)');
title(ax1, 'Energy stats: mean_E vs T (canonical window)');
legend(ax1, 'Location', 'best');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl);
hold(ax2, 'on');
grid(ax2, 'on');
for k = 1:numel(variants)
    sub = energyRows(energyRows.variant_key == keys(k), :);
    [Ts, ord] = sort(sub.T_K);
    plot(ax2, Ts, sub.std_E(ord), '-s', 'Color', cols(k, :), 'LineWidth', 2.3, ...
        'MarkerSize', 5, 'DisplayName', char(keys(k)));
end
hold(ax2, 'off');
xlabel(ax2, 'Temperature T (K)');
ylabel(ax2, '\sigma_E (arb. units)');
title(ax2, 'Energy stats: std_E vs T');
legend(ax2, 'Location', 'best');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

ax3 = nexttile(tl);
hold(ax3, 'on');
grid(ax3, 'on');
for k = 1:numel(variants)
    sub = energyRows(energyRows.variant_key == keys(k), :);
    [Ts, ord] = sort(sub.T_K);
    plot(ax3, Ts, sub.skew_E(ord), '-^', 'Color', cols(k, :), 'LineWidth', 2.3, ...
        'MarkerSize', 5, 'DisplayName', char(keys(k)));
end
hold(ax3, 'off');
xlabel(ax3, 'Temperature T (K)');
ylabel(ax3, 'Skew_E');
title(ax3, 'Energy stats: skew vs T');
legend(ax3, 'Location', 'best');
set(ax3, 'FontSize', 14, 'LineWidth', 1.2);

save_run_figure(fig, base_name, runDir);
close(fig);
end

function saveRepresentativePTRowsFig(runDir, matrices, variants, Iref, targets)
base_name = 'representative_PT_rows_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 16 12]);
Tref = matrices{1}.T_K(:);
targets = unique(targets(:), 'stable');
nTgt = min(4, numel(targets));
cols = lines(numel(variants));
tl = tiledlayout(fig, nTgt, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for ti = 1:nTgt
    [~, jt] = min(abs(Tref - targets(ti)));
    Tplot = Tref(jt);
    ax = nexttile(tl);
    hold(ax, 'on');
    grid(ax, 'on');
    for k = 1:numel(variants)
        M = matrices{k};
        [~, ik] = ismember(Tplot, M.T_K(:));
        if ik < 1
            continue;
        end
        p = M.PT(ik, :);
        plot(ax, Iref, p, '-', 'Color', cols(k, :), 'LineWidth', 2.2, ...
            'DisplayName', char(variants(k).key));
    end
    hold(ax, 'off');
    xlabel(ax, 'Current I (mA)');
    ylabel(ax, 'P_T(I) (1/mA)');
    title(ax, sprintf('P_T(I) at T \\approx %.2f K', Tplot));
    legend(ax, 'Location', 'best');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2);
end

save_run_figure(fig, base_name, runDir);
close(fig);
end

function txt = buildAuditReport(cfg, runDir, variants, childRunIds, metrics, grade, ptPath, enPath, metPath)
lines = strings(0, 1);
lines(end + 1) = '# P_T extraction and energy-mapping robustness audit';
lines(end + 1) = '';
lines(end + 1) = '## Scope';
lines(end + 1) = 'This run compares **reasonable variants** of the **canonical** pipeline in `analysis/switching_barrier_distribution_from_map.m` (unchanged). ';
lines(end + 1) = 'Each variant is a full child run with standard `PT_matrix.csv` / `PT_summary.csv` exports.';
lines(end + 1) = '';
lines(end + 1) = '**Related work:** `Switching/analysis/switching_energy_mapping_analysis.m` already probes **Jacobian / exponent** sensitivity on a **fixed** `PT_matrix`; this audit probes **extraction choices** that produce that matrix.';
lines(end + 1) = '';
lines(end + 1) = sprintf('- Audit run directory: `%s`', runDir);
lines(end + 1) = sprintf('- Canonical energy window: **T \\leq %.1f K**, mapping **E = %.6g \\cdot I** (gamma = 1).', ...
    cfg.canonicalTemperatureMaxK, cfg.alpha);
lines(end + 1) = '';
lines(end + 1) = '## Variants';
for i = 1:numel(variants)
    lines(end + 1) = sprintf('- **%s**: %s → child run `%s`', ...
        variants(i).key, variants(i).label, childRunIds(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Metrics (non-reference variants vs canonical row)';
lines(end + 1) = '| variant | max rel \\|mean\\| | max rel \\|std\\| | max L2 row diff (rel) | Spearman(mean) | step trend agreement | slope sign match |';
lines(end + 1) = '| --- | --- | --- | --- | --- | --- | --- |';
for i = 1:numel(metrics.variant_key)
    lines(end + 1) = sprintf('| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %d |', ...
        metrics.variant_key(i), metrics.max_rel_mean_threshold(i), metrics.max_rel_std_threshold(i), ...
        metrics.max_pt_row_l2_rel(i), metrics.spearman_mean_vs_ref(i), metrics.trend_step_agreement_frac(i), ...
        double(metrics.slope_mean_sign_match(i)));
end
lines(end + 1) = '';
lines(end + 1) = '## Final classification';
lines(end + 1) = sprintf('- **Grade %s** (A = highly robust, B = robust with modest extraction sensitivity, C = mixed, D = fragile).', grade);
lines(end + 1) = '- **22 K context:** low-T / coarse-grid sectors (including ~22 K) can show larger **local** sensitivity; this audit uses **all common temperatures**, not only 22 K.';
lines(end + 1) = '';
lines(end + 1) = '## Interpretation checklist';
lines(end + 1) = '- **PT row shapes:** see `figures/representative_PT_rows_comparison.png` and `tables/PT_variant_summary_comparison.csv`.';
lines(end + 1) = '- **Thermal trends:** Spearman correlation and step-agreement proxy whether **rank-order** structure of mean threshold vs T is stable.';
lines(end + 1) = '- **Energy carry-forward:** `tables/energy_stats_variant_comparison.csv` and `figures/energy_stats_method_comparison.png` show whether **mean_E / std_E / skew** track the same qualitative story.';
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = sprintf('- `%s`', ptPath);
lines(end + 1) = sprintf('- `%s`', enPath);
lines(end + 1) = sprintf('- `%s`', metPath);
lines(end + 1) = '- `figures/PT_summary_method_comparison.png`';
lines(end + 1) = '- `figures/energy_stats_method_comparison.png`';
lines(end + 1) = '- `figures/representative_PT_rows_comparison.png`';
lines(end + 1) = '- `tables/pt_variant_child_runs.csv`';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = sprintf('- number of curves: %d variant traces per panel (\\leq 6 → explicit legend).', numel(variants));
lines(end + 1) = '- legend vs colormap: legend only.';
lines(end + 1) = '- colormap: MATLAB `lines` for distinct variants.';
lines(end + 1) = '- smoothing: none beyond what each **child extraction** already applied.';
lines(end + 1) = '- justification: compare extraction choices on equal footing over the **same** current grid and **intersection** of temperature rows.';

txt = strjoin(lines, newline);
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function ensureArtifactDirs(runDir)
req = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(req)
    p = fullfile(runDir, req{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
end

function s = setDf(s, f, v)
if ~isfield(s, f) || isempty(s.(f))
    s.(f) = v;
end
end

function [temps, currents, PT] = loadPTMatrixLocal(ptMatrixPath)
tbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
assert(ismember('T_K', tbl.Properties.VariableNames), 'T_K missing');
vn = tbl.Properties.VariableNames;
ptNames = setdiff(vn, {'T_K'}, 'stable');
temps = double(tbl.T_K(:));
PT = double(table2array(tbl(:, ptNames)));
currents = parseCurrentGridLocal(ptNames);
[currents, io] = sort(currents(:), 'ascend');
PT = PT(:, io);
[temps, it] = sort(temps(:), 'ascend');
PT = PT(it, :);
end

function currents = parseCurrentGridLocal(varNames)
n = numel(varNames);
currents = NaN(n, 1);
for i = 1:n
    vName = string(varNames{i});
    token = regexp(vName, '^Ith_(.*)_mA$', 'tokens', 'once');
    assert(~isempty(token), 'Bad column %s', vName);
    raw = string(token{1});
    candidates = [raw; strrep(raw, "_", "."); strrep(raw, "_", ""); ...
        regexprep(raw, '_+', '.'); regexprep(raw, '_+', '')];
    val = NaN;
    for k = 1:numel(candidates)
        val = str2double(candidates(k));
        if isfinite(val)
            break;
        end
    end
    assert(isfinite(val), 'Parse fail %s', vName);
    currents(i) = val;
end
end

function [stats, mapped] = computeEnergyStatsLocal(temps, currents, PT, alpha, gamma)
temps = temps(:);
currents = currents(:);
energyRaw = alpha .* sign(currents) .* (abs(currents) .^ gamma);
[energyAxis, order] = sort(energyRaw, 'ascend');
currentsOrdered = currents(order);
dE_dI = gradient(energyAxis, currentsOrdered);
badJacobian = ~isfinite(dE_dI) | abs(dE_dI) <= eps;
dE_dI(badJacobian) = NaN;
nT = numel(temps);
nE = numel(energyAxis);
PT_E = NaN(nT, nE);
mean_E = NaN(nT, 1);
std_E = NaN(nT, 1);
skew_E = NaN(nT, 1);
for it = 1:nT
    pI = PT(it, order);
    pI = double(pI(:));
    pI(~isfinite(pI)) = 0;
    pI = max(pI, 0);
    valid = isfinite(energyAxis) & isfinite(pI) & isfinite(dE_dI);
    if nnz(valid) < 2
        continue;
    end
    E = energyAxis(valid);
    jac = abs(dE_dI(valid));
    pE = pI(valid) ./ jac;
    [pE, area] = normalizeDistributionLocal(E, pE);
    if ~isfinite(area) || area <= 0
        continue;
    end
    PT_E(it, valid) = pE;
    mu = trapz(E, pE .* E);
    varE = trapz(E, pE .* (E - mu) .^ 2);
    varE = max(varE, 0);
    sigma = sqrt(varE);
    mean_E(it) = mu;
    std_E(it) = sigma;
    if sigma > 0
        skewNum = trapz(E, pE .* (E - mu) .^ 3);
        skew_E(it) = skewNum / (sigma ^ 3);
    end
end
stats = struct('temps', temps, 'mean_E', mean_E, 'std_E', std_E, 'skew_E', skew_E);
mapped = struct('energyAxis', energyAxis(:), 'PT_E', PT_E);
end

function [pNorm, area] = normalizeDistributionLocal(axisVals, pVals)
axisVals = axisVals(:);
pVals = pVals(:);
pVals(~isfinite(pVals)) = 0;
pVals = max(pVals, 0);
if nnz(isfinite(axisVals)) < 2
    pNorm = NaN(size(pVals));
    area = NaN;
    return;
end
area = trapz(axisVals, pVals);
if ~isfinite(area) || area <= 0
    pNorm = NaN(size(pVals));
    area = NaN;
    return;
end
pNorm = pVals ./ area;
end

function appendText(pathText, lineText)
fid = fopen(pathText, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lineText);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
