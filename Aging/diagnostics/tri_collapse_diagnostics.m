function out = tri_collapse_diagnostics(cfg)
% tri_collapse_diagnostics
% Quantify how strongly Aging DeltaM(T, t_w) maps collapse onto a rank-1
% temperature shape across the structured TRI-style Aging runs.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagnosticsDir = fileparts(thisFile);
agingRoot = fileparts(diagnosticsDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);
similarDiagnostics = discoverSimilarDiagnostics();
sourceRuns = resolveStructuredRuns(cfg);
data = loadStructuredRuns(sourceRuns);

runCtx = initializeRequestedRun(repoRoot, cfg, sourceRuns, similarDiagnostics);
runDir = runCtx.run_dir;

fprintf('TRI collapse diagnostics run root:\n%s\n', runDir);
appendText(runCtx.log_path, sprintf('[%s] run initialized\n', stampNow()));

[summaryTbl, varianceTbl, spectrumTbl] = computeDiagnosticTables(data);

summaryPath = save_run_table(summaryTbl, 'collapse_quality_metrics.csv', runDir);
variancePath = save_run_table(varianceTbl, 'collapse_variance_profiles.csv', runDir);
spectrumPath = save_run_table(spectrumTbl, 'svd_spectra_by_tp.csv', runDir);

figVarProfiles = makeVarianceProfileFigure(data, cfg);
figVarProfilesPaths = save_run_figure(figVarProfiles, 'collapse_variance_profiles_vs_Tp', runDir);
close(figVarProfiles);

figVarMetric = makeVarianceMetricFigure(summaryTbl, cfg.highlightTp);
figVarMetricPaths = save_run_figure(figVarMetric, 'collapse_variance_metric_vs_Tp', runDir);
close(figVarMetric);

figSvd = makeSvdFigure(summaryTbl, spectrumTbl, cfg.highlightTp);
figSvdPaths = save_run_figure(figSvd, 'svd_spectra_vs_Tp', runDir);
close(figSvd);

figResidual = makeResidualMapFigure(data);
figResidualPaths = save_run_figure(figResidual, 'residual_structure_maps_vs_Tp', runDir);
close(figResidual);

figQuality = makeCollapseQualityFigure(summaryTbl, cfg.highlightTp);
figQualityPaths = save_run_figure(figQuality, 'collapse_quality_vs_Tp', runDir);
close(figQuality);

reportText = buildReportText(runCtx, cfg, similarDiagnostics, sourceRuns, summaryTbl, ...
    figVarProfilesPaths, figVarMetricPaths, figSvdPaths, figResidualPaths, figQualityPaths);
reportPath = save_run_report(reportText, 'tri_collapse_diagnostics_report.md', runDir);

zipPath = createReviewZip(runDir, cfg.reviewZipName);
appendRunNotes(runCtx.notes_path, summaryTbl);
appendText(runCtx.log_path, sprintf('[%s] summary table: %s\n', stampNow(), summaryPath));
appendText(runCtx.log_path, sprintf('[%s] variance table: %s\n', stampNow(), variancePath));
appendText(runCtx.log_path, sprintf('[%s] spectrum table: %s\n', stampNow(), spectrumPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] review zip: %s\n', stampNow(), zipPath));

fprintf('TRI collapse diagnostics complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.summary_table = string(summaryPath);
out.variance_table = string(variancePath);
out.spectrum_table = string(spectrumPath);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runId', 'run_TRI_collapse_diagnostics');
cfg = setDefault(cfg, 'datasetName', 'TRI_collapse_diagnostics');
cfg = setDefault(cfg, 'tpValues', [6 10 14 18 22 26 30 34]);
cfg = setDefault(cfg, 'highlightTp', 26);
cfg = setDefault(cfg, 'structuredRunsRoot', fullfile(repoRoot, 'results', 'aging', 'runs'));
cfg = setDefault(cfg, 'reviewZipName', 'TRI_collapse_diagnostics_bundle.zip');
cfg = setDefault(cfg, 'residualSystematicThreshold', 0.60);
cfg = setDefault(cfg, 'residualNoiseThreshold', 0.35);
end

function similar = discoverSimilarDiagnostics()
similar = struct([]);

similar(end + 1).path = "Aging/analysis/aging_shape_collapse_analysis.m"; %#ok<AGROW>
similar(end).summary = "Structured-profile collapse audit with normalized overlays, rank-1 reconstruction, and a T_p = 26 K residual map.";

similar(end + 1).path = "Aging/analysis/aging_tri_scaling_test.m"; %#ok<AGROW>
similar(end).summary = "Per-T_p collapse RMSE, profile-variance, and rank metrics across the TRI structured exports.";

similar(end + 1).path = "Aging/diagnostics/diagnose_deltaM_svd_pca.m"; %#ok<AGROW>
similar(end).summary = "Legacy SVD/PCA diagnostic for DeltaM curve families in raw-T and T-T_p coordinates.";
end

function runs = resolveStructuredRuns(cfg)
entries = dir(fullfile(cfg.structuredRunsRoot, 'run_*_tp_*_structured_export'));
entries = entries([entries.isdir]);
names = string({entries.name});

runs = repmat(struct('Tp', NaN, 'run_id', "", 'run_dir', ""), numel(cfg.tpValues), 1);
for i = 1:numel(cfg.tpValues)
    tp = cfg.tpValues(i);
    token = sprintf('_tp_%g_structured_export', tp);
    matches = names(endsWith(names, token));
    assert(~isempty(matches), 'No structured-export run found for T_p = %g K.', tp);
    matches = sort(matches);
    runId = matches(end);
    runs(i).Tp = tp;
    runs(i).run_id = runId;
    runs(i).run_dir = fullfile(cfg.structuredRunsRoot, char(runId));
end
end

function data = loadStructuredRuns(sourceRuns)
data = repmat(initDataRow(), numel(sourceRuns), 1);
for i = 1:numel(sourceRuns)
    runDir = sourceRuns(i).run_dir;
    tTbl = readtable(fullfile(runDir, 'tables', 'T_axis.csv'));
    twTbl = readtable(fullfile(runDir, 'tables', 'tw_axis.csv'));
    mapTbl = readtable(fullfile(runDir, 'tables', 'DeltaM_map.csv'));
    svdTbl = readtable(fullfile(runDir, 'tables', 'svd_singular_values.csv'));

    T = extractFirstNumericColumn(tTbl);
    twSeconds = twTbl.tw_seconds;
    waitTime = string(twTbl.wait_time);
    M = table2array(mapTbl);

    assert(size(M, 1) == numel(T), 'DeltaM row count mismatch in %s.', runDir);
    assert(size(M, 2) == numel(twSeconds), 'DeltaM column count mismatch in %s.', runDir);

    [Mnorm, amplitudes, refIdx] = normalizeProfileMatrix(M);
    varianceProfile = var(Mnorm, 0, 2, 'omitnan');
    pairRmse = computePairwiseProfileRmse(Mnorm);
    rank = computeRankMetrics(M, svdTbl);
    residual = computeResidualMetrics(M, T, twSeconds);

    data(i).Tp = sourceRuns(i).Tp;
    data(i).run_id = string(sourceRuns(i).run_id);
    data(i).run_dir = string(runDir);
    data(i).T = T(:);
    data(i).tw_seconds = twSeconds(:);
    data(i).wait_time = waitTime(:);
    data(i).M = M;
    data(i).M_norm = Mnorm;
    data(i).profile_amplitudes = amplitudes(:);
    data(i).reference_profile_index = refIdx;
    data(i).variance_profile = varianceProfile(:);
    data(i).pairwise_rmse = pairRmse(:);
    data(i).rank = rank;
    data(i).residual = residual;
    data(i).n_temperatures = size(M, 1);
    data(i).n_profiles = size(M, 2);
end
end

function row = initDataRow()
row = struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T', [], ...
    'tw_seconds', [], ...
    'wait_time', strings(0, 1), ...
    'M', [], ...
    'M_norm', [], ...
    'profile_amplitudes', [], ...
    'reference_profile_index', NaN, ...
    'variance_profile', [], ...
    'pairwise_rmse', [], ...
    'rank', struct(), ...
    'residual', struct(), ...
    'n_temperatures', NaN, ...
    'n_profiles', NaN);
end

function [summaryTbl, varianceTbl, spectrumTbl] = computeDiagnosticTables(data)
summaryRows = repmat(initSummaryRow(), numel(data), 1);
varianceRows = repmat(initVarianceRow(), 0, 1);
spectrumRows = repmat(initSpectrumRow(), 0, 1);

for i = 1:numel(data)
    d = data(i);
    summaryRows(i).Tp = d.Tp;
    summaryRows(i).source_run = d.run_id;
    summaryRows(i).n_temperatures = d.n_temperatures;
    summaryRows(i).n_profiles = d.n_profiles;
    summaryRows(i).rmse_metric = mean(d.pairwise_rmse, 'omitnan');
    summaryRows(i).max_pairwise_rmse = max(d.pairwise_rmse, [], 'omitnan');
    summaryRows(i).variance_metric = mean(d.variance_profile, 'omitnan');
    summaryRows(i).sigma1 = d.rank.sigma1;
    summaryRows(i).sigma2 = d.rank.sigma2;
    summaryRows(i).sigma1_over_sum_sigma = d.rank.sigma1_over_sum_sigma;
    summaryRows(i).sigma1_over_sigma2 = d.rank.sigma1_over_sigma2;
    summaryRows(i).mode1_explained_variance = d.rank.mode1_explained_variance;
    summaryRows(i).residual_relative_rmse = d.residual.relative_rmse;
    summaryRows(i).residual_frobenius_fraction = d.residual.frobenius_fraction;
    summaryRows(i).residual_sigma1_over_sum_sigma = d.residual.sigma1_over_sum_sigma;
    summaryRows(i).residual_mode1_explained_variance = d.residual.mode1_explained_variance;
    summaryRows(i).residual_temperature_coherence = d.residual.temperature_coherence;
    summaryRows(i).residual_waittime_coherence = d.residual.waittime_coherence;
    summaryRows(i).residual_label = string(d.residual.label);
    summaryRows(i).residual_structure_score = d.residual.structure_score;
    summaryRows(i).residual_peak_temperature_K = d.residual.peak_temperature;
    summaryRows(i).reference_wait_time = string(d.wait_time(d.reference_profile_index));

    for j = 1:numel(d.T)
        vRow = initVarianceRow();
        vRow.Tp = d.Tp;
        vRow.T_K = d.T(j);
        vRow.variance_over_wait_time = d.variance_profile(j);
        vRow.source_run = d.run_id;
        varianceRows(end + 1, 1) = vRow; %#ok<AGROW>
    end

    for j = 1:height(d.rank.spectrum_table)
        sRow = initSpectrumRow();
        sRow.Tp = d.Tp;
        sRow.mode = d.rank.spectrum_table.mode(j);
        sRow.singular_value = d.rank.spectrum_table.singular_value(j);
        sRow.sigma_over_sum_sigma = d.rank.spectrum_table.sigma_over_sum_sigma(j);
        sRow.explained_variance_ratio = d.rank.spectrum_table.explained_variance_ratio(j);
        sRow.cumulative_variance_ratio = d.rank.spectrum_table.cumulative_variance_ratio(j);
        sRow.source_run = d.run_id;
        spectrumRows(end + 1, 1) = sRow; %#ok<AGROW>
    end
end

summaryTbl = sortrows(struct2table(summaryRows), 'Tp');
summaryTbl.rmse_rank = rankValues(summaryTbl.rmse_metric, 'ascend');
summaryTbl.variance_rank = rankValues(summaryTbl.variance_metric, 'ascend');
summaryTbl.sigma1_over_sum_rank = rankValues(summaryTbl.sigma1_over_sum_sigma, 'descend');
summaryTbl.sigma1_over_sigma2_rank = rankValues(summaryTbl.sigma1_over_sigma2, 'descend');

varianceTbl = sortrows(struct2table(varianceRows), {'Tp', 'T_K'});
spectrumTbl = sortrows(struct2table(spectrumRows), {'Tp', 'mode'});
end

function row = initSummaryRow()
row = struct( ...
    'Tp', NaN, ...
    'source_run', "", ...
    'n_temperatures', NaN, ...
    'n_profiles', NaN, ...
    'rmse_metric', NaN, ...
    'max_pairwise_rmse', NaN, ...
    'variance_metric', NaN, ...
    'sigma1', NaN, ...
    'sigma2', NaN, ...
    'sigma1_over_sum_sigma', NaN, ...
    'sigma1_over_sigma2', NaN, ...
    'mode1_explained_variance', NaN, ...
    'residual_relative_rmse', NaN, ...
    'residual_frobenius_fraction', NaN, ...
    'residual_sigma1_over_sum_sigma', NaN, ...
    'residual_mode1_explained_variance', NaN, ...
    'residual_temperature_coherence', NaN, ...
    'residual_waittime_coherence', NaN, ...
    'residual_label', "", ...
    'residual_structure_score', NaN, ...
    'residual_peak_temperature_K', NaN, ...
    'reference_wait_time', "");
end

function row = initVarianceRow()
row = struct( ...
    'Tp', NaN, ...
    'T_K', NaN, ...
    'variance_over_wait_time', NaN, ...
    'source_run', "");
end

function row = initSpectrumRow()
row = struct( ...
    'Tp', NaN, ...
    'mode', NaN, ...
    'singular_value', NaN, ...
    'sigma_over_sum_sigma', NaN, ...
    'explained_variance_ratio', NaN, ...
    'cumulative_variance_ratio', NaN, ...
    'source_run', "");
end

function [Mnorm, amplitudes, refIdx] = normalizeProfileMatrix(M)
amplitudes = max(abs(M), [], 1, 'omitnan');
finiteAmp = amplitudes;
finiteAmp(~isfinite(finiteAmp)) = -inf;
[~, refIdx] = max(finiteAmp);
if ~isfinite(finiteAmp(refIdx))
    refIdx = 1;
end

ref = M(:, refIdx);
refScale = max(abs(ref), [], 'omitnan');
if ~(isfinite(refScale) && refScale > 0)
    refScale = 1;
end
refNorm = ref ./ refScale;

Mnorm = nan(size(M));
for j = 1:size(M, 2)
    profile = M(:, j);
    scale = max(abs(profile), [], 'omitnan');
    if ~(isfinite(scale) && scale > 0)
        continue;
    end

    profileNorm = profile ./ scale;
    valid = isfinite(profileNorm) & isfinite(refNorm);
    if nnz(valid) >= 2 && sum(profileNorm(valid) .* refNorm(valid), 'omitnan') < 0
        profileNorm = -profileNorm;
    end
    Mnorm(:, j) = profileNorm;
end
end

function values = computePairwiseProfileRmse(M)
nProfiles = size(M, 2);
if nProfiles < 2
    values = NaN;
    return;
end

values = nan(nchoosek(nProfiles, 2), 1);
cursor = 0;
for i = 1:(nProfiles - 1)
    for j = (i + 1):nProfiles
        cursor = cursor + 1;
        delta = M(:, i) - M(:, j);
        values(cursor) = sqrt(mean(delta .^ 2, 'omitnan'));
    end
end
values = values(1:cursor);
end

function rank = computeRankMetrics(M, svdTbl)
s = svdTbl.singular_value;
if ~ismember('normalized_singular_value', svdTbl.Properties.VariableNames)
    sigmaOverSum = s ./ max(sum(s, 'omitnan'), eps);
else
    sigmaOverSum = svdTbl.normalized_singular_value;
end

rank = struct();
rank.sigma1 = getVectorValue(s, 1);
rank.sigma2 = getVectorValue(s, 2);
rank.mode1_explained_variance = getTableValue(svdTbl, 'explained_variance_ratio', 1);
rank.sigma1_over_sum_sigma = getVectorValue(sigmaOverSum, 1);
if isfinite(rank.sigma1) && isfinite(rank.sigma2) && abs(rank.sigma2) > eps
    rank.sigma1_over_sigma2 = rank.sigma1 ./ rank.sigma2;
else
    rank.sigma1_over_sigma2 = NaN;
end

specTbl = table();
specTbl.mode = svdTbl.mode;
specTbl.singular_value = svdTbl.singular_value;
specTbl.sigma_over_sum_sigma = sigmaOverSum;
specTbl.explained_variance_ratio = svdTbl.explained_variance_ratio;
specTbl.cumulative_variance_ratio = svdTbl.cumulative_variance_ratio;
rank.spectrum_table = specTbl;

rank.matrix_rows = size(M, 1); %#ok<STRNU>
rank.matrix_cols = size(M, 2); %#ok<STRNU>
end

function residual = computeResidualMetrics(M, T, twSeconds)
[U, S, V] = svd(M, 'econ');
s = diag(S);
rank1Map = s(1) * U(:, 1) * V(:, 1).';
R = M - rank1Map;

mRms = rmsFinite(M);
rRms = rmsFinite(R);
if ~(isfinite(mRms) && mRms > 0)
    mRms = 1;
end

residS = svd(R, 'econ');
residEv = (residS .^ 2) ./ max(sum(residS .^ 2, 'omitnan'), eps);
residSigmaNorm = residS ./ max(sum(residS, 'omitnan'), eps);
meanAbsResidualByT = mean(abs(R), 2, 'omitnan');
[peakResidual, peakIdx] = max(meanAbsResidualByT, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakIdx)
    peakIdx = 1;
end

temperatureCoherence = rowCoherence(R);
waittimeCoherence = columnCoherence(R);
structureScore = max([getVectorValue(residEv, 1), temperatureCoherence, waittimeCoherence]);
if structureScore >= 0.60
    label = "systematic";
elseif structureScore <= 0.35
    label = "noise-like";
else
    label = "mixed";
end

residual = struct();
residual.rank1_map = rank1Map;
residual.map = R;
residual.map_relative = R ./ mRms;
residual.relative_rmse = rRms ./ mRms;
residual.frobenius_fraction = froFinite(R) ./ max(froFinite(M), eps);
residual.sigma1_over_sum_sigma = getVectorValue(residSigmaNorm, 1);
residual.mode1_explained_variance = getVectorValue(residEv, 1);
residual.temperature_coherence = temperatureCoherence;
residual.waittime_coherence = waittimeCoherence;
residual.structure_score = structureScore;
residual.label = label;
residual.peak_temperature = T(peakIdx);
residual.peak_mean_abs_value = peakResidual;
residual.log10_tw = log10(twSeconds(:));
end

function fig = makeVarianceProfileFigure(data, cfg)
fig = create_figure('Visible', 'off', 'Position', [2 2 20 9.5]);
ax = axes(fig);
hold(ax, 'on');

tpVals = [data.Tp];
colors = parula(256);
cmin = min(tpVals);
cmax = max(tpVals);

for i = 1:numel(data)
    colorIdx = 1 + round((size(colors, 1) - 1) * (tpVals(i) - cmin) / max(cmax - cmin, eps));
    colorIdx = min(max(colorIdx, 1), size(colors, 1));
    plot(ax, data(i).T, data(i).variance_profile, '-', 'Color', colors(colorIdx, :), ...
        'LineWidth', 2.2);
end

xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Var_{t_w}[\DeltaM_{norm}(T, t_w)]');
title(ax, 'Collapse variance profiles across T_p');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
colormap(ax, parula(256));
cb = colorbar(ax);
cb.Label.String = 'T_p (K)';
caxis(ax, [cmin cmax]);

highlightPoint(ax, cfg.highlightTp, data);
end

function highlightPoint(ax, highlightTp, data)
for i = 1:numel(data)
    if abs(data(i).Tp - highlightTp) < 1e-9
        plot(ax, data(i).T, data(i).variance_profile, '-', ...
            'Color', [0.85 0.33 0.10], 'LineWidth', 2.8, ...
            'HandleVisibility', 'off');
        break;
    end
end
end

function fig = makeVarianceMetricFigure(summaryTbl, highlightTp)
fig = create_figure('Visible', 'off', 'Position', [2 2 12.5 7.2]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, summaryTbl.Tp, summaryTbl.variance_metric, '-o', ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'LineWidth', 2.4, 'MarkerSize', 7);
highlightSummaryTp(ax, summaryTbl.Tp, summaryTbl.variance_metric, highlightTp);

xlabel(ax, 'T_p (K)');
ylabel(ax, 'Mean_T Var_{t_w}[\DeltaM_{norm}]');
title(ax, 'Collapse variance metric vs T_p');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
end

function fig = makeSvdFigure(summaryTbl, spectrumTbl, highlightTp)
fig = create_figure('Visible', 'off', 'Position', [2 2 22 10]);
tlo = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

tpVals = summaryTbl.Tp.';
modes = unique(spectrumTbl.mode).';
nModes = min(4, numel(modes));
heatMat = nan(nModes, numel(tpVals));

for i = 1:numel(tpVals)
    for k = 1:nModes
        mask = spectrumTbl.Tp == tpVals(i) & spectrumTbl.mode == k;
        if any(mask)
            heatMat(k, i) = spectrumTbl.sigma_over_sum_sigma(find(mask, 1, 'first'));
        end
    end
end

ax1 = nexttile(tlo, 1);
imagesc(ax1, tpVals, 1:nModes, heatMat);
axis(ax1, 'xy');
colormap(ax1, parula(256));
cb1 = colorbar(ax1);
cb1.Label.String = '\sigma_i / \Sigma_j \sigma_j';
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Mode index');
title(ax1, 'Normalized singular spectrum');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'on');

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
plot(ax2, summaryTbl.Tp, summaryTbl.sigma1_over_sum_sigma, '-o', ...
    'Color', [0.2 0.5 0.85], 'MarkerFaceColor', [0.2 0.5 0.85], ...
    'LineWidth', 2.4, 'MarkerSize', 7);
highlightSummaryTp(ax2, summaryTbl.Tp, summaryTbl.sigma1_over_sum_sigma, highlightTp);
xlabel(ax2, 'T_p (K)');
ylabel(ax2, '\sigma_1 / \Sigma_i \sigma_i');
title(ax2, 'Leading-mode weight');
grid(ax2, 'on');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

ax3 = nexttile(tlo, 3);
hold(ax3, 'on');
plot(ax3, summaryTbl.Tp, summaryTbl.sigma1_over_sigma2, '-o', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.4, 'MarkerSize', 7);
highlightSummaryTp(ax3, summaryTbl.Tp, summaryTbl.sigma1_over_sigma2, highlightTp);
xlabel(ax3, 'T_p (K)');
ylabel(ax3, '\sigma_1 / \sigma_2');
title(ax3, 'Rank-dominance ratio');
grid(ax3, 'on');
set(ax3, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

title(tlo, 'SVD dominance diagnostics vs T_p');
end

function fig = makeResidualMapFigure(data)
fig = create_figure('Visible', 'off', 'Position', [2 2 26 13]);
tlo = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

relLim = 0;
for i = 1:numel(data)
    relLim = max(relLim, max(abs(data(i).residual.map_relative(:)), [], 'omitnan'));
end
if ~(isfinite(relLim) && relLim > 0)
    relLim = 1;
end

for i = 1:numel(data)
    ax = nexttile(tlo, i);
    imagesc(ax, data(i).T, data(i).residual.log10_tw, data(i).residual.map_relative.');
    axis(ax, 'xy');
    colormap(ax, blueWhiteRedMap(256));
    clim(ax, [-relLim relLim]);
    if i == numel(data)
        cb = colorbar(ax);
        cb.Label.String = 'Residual / RMS(M)';
    end
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'log_{10}(t_w / s)');
    title(ax, sprintf('T_p = %.0f K | %s | score = %.2f', ...
        data(i).Tp, char(data(i).residual.label), data(i).residual.structure_score));
    set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'on');
end

title(tlo, 'Residual structure after rank-1 fit, M(T,t_w) \approx a(t_w)\phi(T)');
end

function fig = makeCollapseQualityFigure(summaryTbl, highlightTp)
fig = create_figure('Visible', 'off', 'Position', [2 2 13 16]);
tlo = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

metricDefs = {
    'rmse_metric', 'Mean pairwise RMSE of \DeltaM_{norm}', [0 0.4470 0.7410]
    'variance_metric', 'Mean_T Var_{t_w}[\DeltaM_{norm}]', [0 0.6200 0.4510]
    'sigma1_over_sigma2', '\sigma_1 / \sigma_2', [0.8500 0.3250 0.0980]
    };

for i = 1:size(metricDefs, 1)
    ax = nexttile(tlo, i);
    fieldName = metricDefs{i, 1};
    y = summaryTbl.(fieldName);
    hold(ax, 'on');
    plot(ax, summaryTbl.Tp, y, '-o', ...
        'Color', metricDefs{i, 3}, 'MarkerFaceColor', metricDefs{i, 3}, ...
        'LineWidth', 2.4, 'MarkerSize', 7);
    highlightSummaryTp(ax, summaryTbl.Tp, y, highlightTp);
    xlabel(ax, 'T_p (K)');
    ylabel(ax, metricDefs{i, 2});
    grid(ax, 'on');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
end

title(tlo, 'Collapse quality metrics vs T_p');
end

function highlightSummaryTp(ax, x, y, targetTp)
mask = abs(x - targetTp) < 1e-9;
if any(mask)
    plot(ax, x(mask), y(mask), 'o', ...
        'Color', [0.20 0.20 0.20], ...
        'MarkerFaceColor', [1.0 0.85 0.15], ...
        'MarkerSize', 10, 'LineWidth', 1.5, ...
        'HandleVisibility', 'off');
end
end

function reportText = buildReportText(runCtx, cfg, similarDiagnostics, sourceRuns, summaryTbl, ...
    figVarProfilesPaths, figVarMetricPaths, figSvdPaths, figResidualPaths, figQualityPaths)
tp26 = summaryTbl(summaryTbl.Tp == cfg.highlightTp, :);
bestRmse = bestFiniteRow(summaryTbl, 'rmse_metric', 'ascend');
bestVar = bestFiniteRow(summaryTbl, 'variance_metric', 'ascend');
bestSigmaSum = bestFiniteRow(summaryTbl, 'sigma1_over_sum_sigma', 'descend');
bestSigmaRatio = bestFiniteRow(summaryTbl, 'sigma1_over_sigma2', 'descend');

lines = strings(0, 1);
lines(end + 1) = '# TRI collapse diagnostics';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', string(runCtx.run_dir));
lines(end + 1) = '';
lines(end + 1) = '## Scope';
lines(end + 1) = '- Analysis-only task. No pipeline files or staged exports were modified.';
lines(end + 1) = '- Inputs were the existing structured `\DeltaM(T, t_w)` maps from the Aging runs listed below.';
lines(end + 1) = '- Residual maps were computed from the best rank-1 factorization `M(T,t_w) \approx a(t_w)\phi(T)` of each saved matrix.';
lines(end + 1) = '';
lines(end + 1) = '## Similar diagnostics already present';
for i = 1:numel(similarDiagnostics)
    lines(end + 1) = sprintf('- `%s`: %s', similarDiagnostics(i).path, similarDiagnostics(i).summary);
end
lines(end + 1) = '- Conclusion of the scan: the repository already had partial collapse and SVD audits, but not one fixed-run bundle focused on the requested variance metric, `\sigma_1/\Sigma\sigma_i`, `\sigma_1/\sigma_2`, and residual-structure check across all TRI structured exports.';
lines(end + 1) = '';
lines(end + 1) = '## Source runs';
for i = 1:numel(sourceRuns)
    lines(end + 1) = sprintf('- `T_p = %.0f K` -> `%s`', sourceRuns(i).Tp, string(sourceRuns(i).run_id));
end
lines(end + 1) = '';
lines(end + 1) = '## Methods';
lines(end + 1) = '- For each `T_p`, every waiting-time curve was normalized by its own `max|\DeltaM|`. A sign-alignment step was applied only to remove arbitrary global sign flips relative to the strongest profile, so the collapse metrics probe shape rather than amplitude.';
lines(end + 1) = '- The variance metric is `mean_T Var_{t_w}[\DeltaM_{norm}(T,t_w)]`; lower values indicate stronger collapse.';
lines(end + 1) = '- The RMSE metric is the mean pairwise RMSE across normalized waiting-time profiles within one `T_p`; lower values indicate stronger collapse.';
lines(end + 1) = '- The SVD dominance metrics were taken from the saved structured-export singular spectra so this diagnostic reuses the existing SVD machinery rather than rebuilding a separate spectrum pipeline.';
lines(end + 1) = '- Residual structure was quantified by the relative residual RMSE, the residual leading-mode explained variance, and coherence scores across temperature and waiting time. High residual coherence indicates a systematic missing correction rather than noise-like leftovers.';
lines(end + 1) = '';
lines(end + 1) = '## Findings';
lines(end + 1) = sprintf('- Lowest normalized-profile RMSE: `T_p = %.0f K` with RMSE `%.4f`. At `26 K`, RMSE = `%.4f` and rank = `%d/%d`.', ...
    bestRmse.Tp, bestRmse.rmse_metric, tp26.rmse_metric, tp26.rmse_rank, height(summaryTbl));
lines(end + 1) = sprintf('- Lowest collapse-variance metric: `T_p = %.0f K` with `%.5f`. At `26 K`, the variance metric is `%.5f` and rank = `%d/%d`.', ...
    bestVar.Tp, bestVar.variance_metric, tp26.variance_metric, tp26.variance_rank, height(summaryTbl));
lines(end + 1) = sprintf('- Largest `\\sigma_1 / \\Sigma_i \\sigma_i`: `T_p = %.0f K` with `%.4f`. At `26 K`, `\\sigma_1 / \\Sigma_i \\sigma_i = %.4f` and rank = `%d/%d`.', ...
    bestSigmaSum.Tp, bestSigmaSum.sigma1_over_sum_sigma, tp26.sigma1_over_sum_sigma, tp26.sigma1_over_sum_rank, height(summaryTbl));
lines(end + 1) = sprintf('- Largest `\\sigma_1 / \\sigma_2`: `T_p = %.0f K` with `%.4f`. At `26 K`, `\\sigma_1 / \\sigma_2 = %.4f` and rank = `%d/%d`.', ...
    bestSigmaRatio.Tp, bestSigmaRatio.sigma1_over_sigma2, tp26.sigma1_over_sigma2, tp26.sigma1_over_sigma2_rank, height(summaryTbl));
lines(end + 1) = sprintf('- At `26 K`, the raw-map residual has relative RMSE `%.4f`, residual mode-1 explained variance `%.4f`, temperature-coherence `%.4f`, wait-time coherence `%.4f`, and is classified as `%s`.', ...
    tp26.residual_relative_rmse, tp26.residual_mode1_explained_variance, ...
    tp26.residual_temperature_coherence, tp26.residual_waittime_coherence, tp26.residual_label);
lines(end + 1) = '';
lines(end + 1) = '## Interpretation';
if bestRmse.Tp == cfg.highlightTp && bestVar.Tp == cfg.highlightTp
    lines(end + 1) = '- The collapse-strength metrics peak directly at the relaxation maximum near `26 K`.';
elseif abs(bestRmse.Tp - cfg.highlightTp) <= 4 || abs(bestVar.Tp - cfg.highlightTp) <= 4
    lines(end + 1) = sprintf('- Collapse quality is enhanced in the neighborhood of `26 K`, but the strongest measured point in this sweep is `%.0f K`, not `26 K`.', bestRmse.Tp);
else
    lines(end + 1) = sprintf('- Collapse quality does not peak at `26 K` in this sweep; the strongest measured point is `%.0f K` by RMSE and `%.0f K` by the variance metric.', ...
        bestRmse.Tp, bestVar.Tp);
end

if bestSigmaRatio.Tp == cfg.highlightTp && bestSigmaSum.Tp == cfg.highlightTp
    lines(end + 1) = '- Rank-1 dominance is maximal at `26 K` by both singular-value ratios.';
elseif bestSigmaRatio.Tp == cfg.highlightTp || bestSigmaSum.Tp == cfg.highlightTp
    lines(end + 1) = '- Rank-1 dominance is strongest at `26 K` by one ratio but not both; the peak is therefore suggestive rather than unambiguous.';
else
    lines(end + 1) = sprintf('- Rank-1 dominance does not peak at `26 K`; both `\\sigma_1 / \\Sigma \\sigma_i` and `\\sigma_1 / \\sigma_2` peak at `%.0f K` in the sampled temperatures.', bestSigmaRatio.Tp);
end

if tp26.residual_structure_score >= cfg.residualSystematicThreshold
    lines(end + 1) = '- The 26 K residual is structured rather than random. The rank-1 collapse leaves a coherent correction mode, so the map is close to separable but not perfectly one-parameter.';
elseif tp26.residual_structure_score <= cfg.residualNoiseThreshold
    lines(end + 1) = '- The 26 K residual is weak and noise-like. That supports a nearly complete rank-1 collapse at the relaxation maximum.';
else
    lines(end + 1) = '- The 26 K residual is intermediate: weaker than the main rank-1 mode but still not fully noise-like, which suggests modest missing structure beyond pure amplitude rescaling.';
end
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- `collapse_variance_profiles_vs_Tp`: 8 curves, colormap plus labeled colorbar, no smoothing, used because the curve count exceeds 6 and the goal is to compare where in `T` the collapse variance concentrates.';
lines(end + 1) = '- `collapse_variance_metric_vs_Tp`: single metric curve with a highlighted `26 K` marker, no colormap, no smoothing.';
lines(end + 1) = '- `svd_spectra_vs_Tp`: one heatmap for the normalized singular spectrum and two line plots for the rank-dominance ratios; `parula` is used for the heatmap.';
lines(end + 1) = '- `residual_structure_maps_vs_Tp`: 8 residual heatmaps in one grid so the residual morphology can be inspected side by side; the color scale is applied to `Residual / RMS(M)` to keep comparisons fair across `T_p`.';
lines(end + 1) = '- `collapse_quality_vs_Tp`: 3 stacked metric curves for RMSE, variance, and `\\sigma_1/\\sigma_2`, with `26 K` highlighted.';
lines(end + 1) = '- Smoothing applied: none. The diagnostics were intended to reflect the saved structured maps directly.';
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/collapse_quality_metrics.csv`';
lines(end + 1) = '- `tables/collapse_variance_profiles.csv`';
lines(end + 1) = '- `tables/svd_spectra_by_tp.csv`';
lines(end + 1) = '- `figures/collapse_variance_profiles_vs_Tp.png`';
lines(end + 1) = '- `figures/collapse_variance_metric_vs_Tp.png`';
lines(end + 1) = '- `figures/svd_spectra_vs_Tp.png`';
lines(end + 1) = '- `figures/residual_structure_maps_vs_Tp.png`';
lines(end + 1) = '- `figures/collapse_quality_vs_Tp.png`';
lines(end + 1) = '- `reports/tri_collapse_diagnostics_report.md`';
lines(end + 1) = sprintf('- `review/%s`', string(cfg.reviewZipName));
lines(end + 1) = '';
lines(end + 1) = '## Absolute artifact paths';
lines(end + 1) = sprintf('- Variance profiles figure: `%s`', string(figVarProfilesPaths.png));
lines(end + 1) = sprintf('- Variance metric figure: `%s`', string(figVarMetricPaths.png));
lines(end + 1) = sprintf('- SVD figure: `%s`', string(figSvdPaths.png));
lines(end + 1) = sprintf('- Residual maps figure: `%s`', string(figResidualPaths.png));
lines(end + 1) = sprintf('- Collapse quality figure: `%s`', string(figQualityPaths.png));

reportText = strjoin(lines, newline);
end

function appendRunNotes(notesPath, summaryTbl)
fid = fopen(notesPath, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

bestRmse = bestFiniteRow(summaryTbl, 'rmse_metric', 'ascend');
bestVar = bestFiniteRow(summaryTbl, 'variance_metric', 'ascend');
bestSigma = bestFiniteRow(summaryTbl, 'sigma1_over_sigma2', 'descend');
tp26 = summaryTbl(summaryTbl.Tp == 26, :);

fprintf(fid, 'Best RMSE collapse: T_p = %.0f K, RMSE = %.4f\n', bestRmse.Tp, bestRmse.rmse_metric);
fprintf(fid, 'Best variance collapse: T_p = %.0f K, variance = %.5f\n', bestVar.Tp, bestVar.variance_metric);
fprintf(fid, 'Best rank dominance: T_p = %.0f K, sigma1/sigma2 = %.4f\n', bestSigma.Tp, bestSigma.sigma1_over_sigma2);
fprintf(fid, 'At 26 K: RMSE = %.4f, variance = %.5f, sigma1/sigma2 = %.4f, residual = %s\n', ...
    tp26.rmse_metric, tp26.variance_metric, tp26.sigma1_over_sigma2, char(tp26.residual_label));
end

function runCtx = initializeRequestedRun(repoRoot, cfg, sourceRuns, similarDiagnostics)
runDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(string(cfg.runId)));
if exist(runDir, 'dir') ~= 7
    mkdir(runDir);
end
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end

runCtx = struct();
runCtx.run_id = char(string(cfg.runId));
runCtx.run_dir = runDir;
runCtx.manifest_path = fullfile(runDir, 'run_manifest.json');
runCtx.config_snapshot_path = fullfile(runDir, 'config_snapshot.m');
runCtx.log_path = fullfile(runDir, 'log.txt');
runCtx.notes_path = fullfile(runDir, 'run_notes.txt');
runCtx.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
runCtx.repo_root = repoRoot;
runCtx.git_commit = resolveGitCommit(repoRoot);
runCtx.matlab_version = version;
runCtx.host = getComputerName();
runCtx.user = getUserName();

writeManifest(runCtx, cfg);
writeConfigSnapshot(runCtx, cfg, sourceRuns, similarDiagnostics);
writeLogHeader(runCtx, cfg);
ensureNotesFile(runCtx.notes_path);
end

function writeManifest(runCtx, cfg)
manifest = struct();
manifest.run_id = runCtx.run_id;
manifest.timestamp = runCtx.timestamp;
manifest.experiment = 'aging';
manifest.label = 'TRI_collapse_diagnostics';
manifest.dataset = cfg.datasetName;
manifest.repo_root = runCtx.repo_root;
manifest.run_dir = runCtx.run_dir;
manifest.git_commit = runCtx.git_commit;
manifest.matlab_version = runCtx.matlab_version;
manifest.host = runCtx.host;
manifest.user = runCtx.user;

try
    jsonText = jsonencode(manifest, 'PrettyPrint', true);
catch
    jsonText = jsonencode(manifest);
end

fid = fopen(runCtx.manifest_path, 'w');
assert(fid >= 0, 'Could not write manifest: %s', runCtx.manifest_path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', jsonText);
end

function writeConfigSnapshot(runCtx, cfg, sourceRuns, similarDiagnostics)
fid = fopen(runCtx.config_snapshot_path, 'w');
assert(fid >= 0, 'Could not write config snapshot: %s', runCtx.config_snapshot_path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '%% Auto-generated config snapshot for %s\n', runCtx.run_id);
fprintf(fid, '%% Timestamp: %s\n\n', runCtx.timestamp);
fprintf(fid, 'cfg = struct();\n');
fprintf(fid, 'cfg.runId = ''%s'';\n', char(string(cfg.runId)));
fprintf(fid, 'cfg.datasetName = ''%s'';\n', char(string(cfg.datasetName)));
fprintf(fid, 'cfg.tpValues = [%s];\n', sprintf(' %.0f', cfg.tpValues));
fprintf(fid, 'cfg.highlightTp = %.15g;\n', cfg.highlightTp);
fprintf(fid, 'cfg.structuredRunsRoot = ''%s'';\n', escapeSingleQuotes(cfg.structuredRunsRoot));
fprintf(fid, 'cfg.reviewZipName = ''%s'';\n', char(string(cfg.reviewZipName)));
fprintf(fid, '\nsource_runs = strings(%d, 2);\n', numel(sourceRuns));
for i = 1:numel(sourceRuns)
    fprintf(fid, 'source_runs(%d, :) = ["%.0f", "%s"];\n', i, sourceRuns(i).Tp, char(sourceRuns(i).run_id));
end
fprintf(fid, '\nsimilar_diagnostics = strings(%d, 2);\n', numel(similarDiagnostics));
for i = 1:numel(similarDiagnostics)
    fprintf(fid, 'similar_diagnostics(%d, :) = ["%s", "%s"];\n', ...
        i, escapeDoubleQuotes(similarDiagnostics(i).path), escapeDoubleQuotes(similarDiagnostics(i).summary));
end
end

function writeLogHeader(runCtx, cfg)
fid = fopen(runCtx.log_path, 'w');
assert(fid >= 0, 'Could not write log: %s', runCtx.log_path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '[%s] Run initialized\n', runCtx.timestamp);
fprintf(fid, 'run_id: %s\n', runCtx.run_id);
fprintf(fid, 'experiment: aging\n');
fprintf(fid, 'dataset: %s\n', char(string(cfg.datasetName)));
fprintf(fid, 'git_commit: %s\n', runCtx.git_commit);
fprintf(fid, 'matlab_version: %s\n', runCtx.matlab_version);
fprintf(fid, 'run_dir: %s\n\n', runCtx.run_dir);
end

function ensureNotesFile(pathStr)
if exist(pathStr, 'file') == 2
    return;
end
fid = fopen(pathStr, 'w');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
end

function zipPath = createReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function row = bestFiniteRow(tbl, fieldName, direction)
row = [];
if isempty(tbl)
    return;
end
valid = isfinite(tbl.(fieldName));
if ~any(valid)
    return;
end
sub = tbl(valid, :);
sub = sortrows(sub, fieldName, direction);
row = sub(1, :);
end

function ranks = rankValues(values, direction)
ranks = nan(size(values));
mask = isfinite(values);
if ~any(mask)
    return;
end
sub = values(mask);
if strcmp(direction, 'ascend')
    [~, idx] = sort(sub, 'ascend');
else
    [~, idx] = sort(sub, 'descend');
end
localRanks = nan(size(sub));
localRanks(idx) = 1:numel(sub);
ranks(mask) = localRanks;
end

function value = extractFirstNumericColumn(tbl)
value = table2array(tbl(:, 1));
if ~isnumeric(value)
    value = str2double(string(value));
end
end

function value = getVectorValue(values, idx)
if idx <= numel(values)
    value = values(idx);
else
    value = NaN;
end
end

function value = getTableValue(tbl, fieldName, idx)
if idx <= height(tbl) && ismember(fieldName, tbl.Properties.VariableNames)
    value = tbl.(fieldName)(idx);
else
    value = NaN;
end
end

function out = rowCoherence(M)
rowMean = mean(M, 2, 'omitnan');
denom = froFinite(M) ./ max(sqrt(size(M, 2)), eps);
out = norm(rowMean) ./ max(denom, eps);
end

function out = columnCoherence(M)
colMean = mean(M, 1, 'omitnan');
denom = froFinite(M) ./ max(sqrt(size(M, 1)), eps);
out = norm(colMean) ./ max(denom, eps);
end

function value = froFinite(M)
M = M(isfinite(M));
if isempty(M)
    value = NaN;
else
    value = norm(M);
end
end

function value = rmsFinite(M)
M = M(isfinite(M));
if isempty(M)
    value = NaN;
else
    value = sqrt(mean(M .^ 2));
end
end

function cmap = blueWhiteRedMap(n)
if nargin < 1
    n = 256;
end
n = max(2, round(n));
half = floor(n / 2);
top = [linspace(0, 1, half)', linspace(0.2, 1, half)', ones(half, 1)];
bottom = [ones(n - half, 1), linspace(1, 0.2, n - half)', linspace(1, 0, n - half)'];
cmap = [top; flipud(bottom)];
if size(cmap, 1) > n
    cmap = cmap(1:n, :);
end
end

function commit = resolveGitCommit(repoRoot)
commit = '';
try
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
    if status == 0
        commit = strtrim(out);
    end
catch
    commit = '';
end
if isempty(commit)
    commit = 'unknown';
end
end

function name = getComputerName()
name = getenv('COMPUTERNAME');
if isempty(name)
    name = getenv('HOSTNAME');
end
if isempty(name)
    name = 'unknown';
end
end

function user = getUserName()
user = getenv('USERNAME');
if isempty(user)
    user = getenv('USER');
end
if isempty(user)
    user = 'unknown';
end
end

function appendText(pathStr, textStr)
fid = fopen(pathStr, 'a');
if fid < 0
    error('Could not open %s for append.', pathStr);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textStr);
end

function value = escapeSingleQuotes(value)
value = strrep(char(string(value)), '''', '''''');
end

function value = escapeDoubleQuotes(value)
value = strrep(char(string(value)), '"', '""');
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
