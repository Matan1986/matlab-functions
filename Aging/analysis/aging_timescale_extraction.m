function out = aging_timescale_extraction()
% aging_timescale_extraction
% Estimate effective aging timescales tau(T_p) from Dip_depth using a
% consolidated observable dataset and multiple comparison methods.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

defaultDatasetPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', ...
    'aging_observable_dataset.csv');
datasetPath = defaultDatasetPath;
envDatasetPath = strtrim(getenv('AGING_OBSERVABLE_DATASET_PATH'));
if ~isempty(envDatasetPath)
    datasetPath = envDatasetPath;
end
assert(exist(datasetPath, 'file') == 2, ...
    'Missing consolidated Aging observable dataset: %s', datasetPath);

cfgRun = struct();
cfgRun.runLabel = 'aging_timescale_extraction';
cfgRun.datasetName = 'aging_observable_dataset';
runCtx = createRunContext('aging', cfgRun);
run_output_dir = runCtx.run_dir;

fprintf('Aging timescale extraction run root:\n%s\n', run_output_dir);
fprintf('Input dataset: %s\n', datasetPath);
if ~strcmp(datasetPath, defaultDatasetPath)
    fprintf('Dataset override via AGING_OBSERVABLE_DATASET_PATH is active.\n');
else
    fprintf('Dataset override not set; using default dataset path.\n');
end

dataTbl = normalizeDatasetTable(loadObservableDataset(datasetPath));
dataTbl = sortrows(dataTbl, {'Tp', 'tw'});

tauTbl = buildTauTable(dataTbl);
tauTbl = sortrows(tauTbl, 'Tp');
f7gMeta = struct( ...
    'writer_family_id', 'WF_TAU_DIP_CURVEFIT', ...
    'tau_or_R_flag', 'TAU', ...
    'tau_domain', 'DIP_MEMORY_CURVEFIT', ...
    'tau_input_observable_identities', '{"Dip_depth":"consolidated_aging_observable_dataset_column"}', ...
    'tau_input_observable_family', 'Dip_depth_memory_curve', ...
    'source_writer_script', 'Aging/analysis/aging_timescale_extraction.m', ...
    'source_artifact_basename', 'tau_vs_Tp.csv', ...
    'source_artifact_path', fullfile(run_output_dir, 'tables', 'tau_vs_Tp.csv'), ...
    'canonical_status', 'non_canonical_pending_lineage', ...
    'model_use_allowed', 'NO_UNLESS_LINEAGE_RESOLVED', ...
    'semantic_status', 'tau_effective_seconds_is_legacy_alias_DIP_CURVEFIT', ...
    'lineage_status', 'REQUIRES_DATASET_PATH_AND_DIP_BRANCH_RESOLUTION');
tauTbl = appendF7GTauRMetadataColumns(tauTbl, f7gMeta);
tauPath = save_run_table(tauTbl, 'tau_vs_Tp.csv', run_output_dir);

figDip = makeDipDepthFigure(dataTbl, tauTbl);
save_run_figure(figDip, 'Dip_depth_vs_tw_by_Tp', run_output_dir);
close(figDip);

figTau = makeTauFigure(tauTbl);
save_run_figure(figTau, 'tau_vs_Tp', run_output_dir);
close(figTau);

reportText = buildReportText(run_output_dir, datasetPath, dataTbl, tauTbl);
reportPath = save_run_report(reportText, 'aging_timescale_extraction_report.md', run_output_dir);

zipPath = buildReviewZip(run_output_dir, 'aging_timescale_extraction.zip');

fprintf('Aging timescale extraction complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = run_output_dir;
out.dataset_path = datasetPath;
out.table_path = tauPath;
out.report_path = reportPath;
out.zip_path = zipPath;
out.tau_table = tauTbl;
end

function dataTbl = loadObservableDataset(datasetPath)
fid = fopen(datasetPath, 'r');
assert(fid >= 0, 'Failed to open Aging observable dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

headerLine = fgetl(fid);
assert(ischar(headerLine), 'Aging observable dataset is empty: %s', datasetPath);

headerParts = textscan(headerLine, '%q', 'Delimiter', ',');
header = string(headerParts{1});
expected = ["Tp"; "tw"; "Dip_depth"; "FM_abs"; "source_run"];
headerCanon = lower(regexprep(header, '[^A-Za-z0-9]', ''));
expectedCanon = lower(regexprep(expected, '[^A-Za-z0-9]', ''));
assert(numel(header) == numel(expected) && all(headerCanon == expectedCanon), ...
    'Unexpected Aging observable dataset header in %s.', datasetPath);

cols = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'CollectOutput', false);
assert(numel(cols) == 5, 'Failed to parse Aging observable dataset: %s', datasetPath);

dataTbl = table( ...
    str2double(cols{1}), ...
    str2double(cols{2}), ...
    str2double(cols{3}), ...
    str2double(cols{4}), ...
    string(cols{5}), ...
    'VariableNames', cellstr(expected));
end
function dataTbl = normalizeDatasetTable(dataTbl)
required = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
missing = required(~ismember(required, dataTbl.Properties.VariableNames));
assert(isempty(missing), ...
    'Aging observable dataset is missing required columns: %s', strjoin(missing, ', '));

numericVars = {'Tp', 'tw', 'Dip_depth', 'FM_abs'};
for i = 1:numel(numericVars)
    vn = numericVars{i};
    if ~isnumeric(dataTbl.(vn))
        dataTbl.(vn) = str2double(string(dataTbl.(vn)));
    end
end

dataTbl.source_run = string(dataTbl.source_run);
end

function tauTbl = buildTauTable(dataTbl)
tpValues = unique(dataTbl.Tp, 'sorted');
rows = repmat(initTauRow(), numel(tpValues), 1);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = dataTbl(dataTbl.Tp == tp, :);
    sub = sortrows(sub, 'tw');
    rows(i) = analyzeTpGroup(sub);
end

tauTbl = struct2table(rows);
end

function row = initTauRow()
row = struct( ...
    'Tp', NaN, ...
    'n_points', NaN, ...
    'fragile_low_point_count', false, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'peak_tw_seconds', NaN, ...
    'Dip_depth_start', NaN, ...
    'Dip_depth_peak', NaN, ...
    'Dip_depth_range_to_peak', NaN, ...
    'n_downturns', NaN, ...
    'tau_logistic_half_seconds', NaN, ...
    'tau_logistic_sigma_decades', NaN, ...
    'tau_logistic_rmse', NaN, ...
    'tau_logistic_r2', NaN, ...
    'tau_logistic_trusted', false, ...
    'tau_logistic_status', "", ...
    'tau_stretched_half_seconds', NaN, ...
    'tau_stretched_char_seconds', NaN, ...
    'tau_stretched_beta', NaN, ...
    'tau_stretched_rmse', NaN, ...
    'tau_stretched_r2', NaN, ...
    'tau_stretched_trusted', false, ...
    'tau_stretched_status', "", ...
    'tau_half_range_seconds', NaN, ...
    'tau_half_range_status', "", ...
    'tau_effective_seconds', NaN, ...
    'tau_consensus_method_count', NaN, ...
    'tau_consensus_methods', "", ...
    'tau_method_spread_decades', NaN, ...
    'source_run', "");
end

function row = analyzeTpGroup(sub)
row = initTauRow();
tw = sub.tw(:);
y = sub.Dip_depth(:);

[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    peakIdx = NaN;
    peakValue = NaN;
end

row.Tp = sub.Tp(1);
row.n_points = numel(tw);
row.fragile_low_point_count = numel(tw) < 4;
row.tw_min_seconds = min(tw, [], 'omitnan');
row.tw_max_seconds = max(tw, [], 'omitnan');
if isfinite(peakIdx)
    row.peak_tw_seconds = tw(peakIdx);
end
row.Dip_depth_start = y(1);
row.Dip_depth_peak = peakValue;
row.Dip_depth_range_to_peak = peakValue - y(1);
row.n_downturns = nnz(diff(y) < 0);
row.source_run = sub.source_run(1);

logisticFit = fitLogisticInLogTime(tw, y);
row.tau_logistic_half_seconds = logisticFit.tau_half_seconds;
row.tau_logistic_sigma_decades = logisticFit.sigma_decades;
row.tau_logistic_rmse = logisticFit.rmse;
row.tau_logistic_r2 = logisticFit.r2;
row.tau_logistic_trusted = logisticFit.trusted;
row.tau_logistic_status = logisticFit.status;

stretchedFit = fitStretchedExponential(tw, y);
row.tau_stretched_half_seconds = stretchedFit.tau_half_seconds;
row.tau_stretched_char_seconds = stretchedFit.tau_char_seconds;
row.tau_stretched_beta = stretchedFit.beta;
row.tau_stretched_rmse = stretchedFit.rmse;
row.tau_stretched_r2 = stretchedFit.r2;
row.tau_stretched_trusted = stretchedFit.trusted;
row.tau_stretched_status = stretchedFit.status;

halfRange = estimateHalfRangeTime(tw, y);
row.tau_half_range_seconds = halfRange.tau_seconds;
row.tau_half_range_status = halfRange.status;

[row.tau_effective_seconds, row.tau_consensus_method_count, ...
    row.tau_consensus_methods, row.tau_method_spread_decades] = ...
    buildConsensusTau(row);
end

function fit = initFitResult(status)
if nargin < 1
    status = "not_run";
end
fit = struct( ...
    'tau_half_seconds', NaN, ...
    'tau_char_seconds', NaN, ...
    'sigma_decades', NaN, ...
    'beta', NaN, ...
    'rmse', NaN, ...
    'r2', NaN, ...
    'trusted', false, ...
    'status', string(status));
end

function fit = fitLogisticInLogTime(t, y)
fit = initFitResult("fit_failed");

if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end

x = log10(t(:));
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;

halfData = estimateHalfRangeTime(t, y);
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    muSeeds = [log10(halfData.tau_seconds), mean(x), median(x), x(1), x(end)];
else
    muSeeds = [mean(x), median(x), x(1), x(end)];
end
sigmaSeeds = [0.20, 0.40, 0.80, 1.20];
deltaSeeds = [max(rangeY / scaleY, 0.05), max(yScaled(end) - yScaled(1), 0.05), 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];

best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 4000, 'MaxFunEvals', 8000);

for y0 = y0Seeds
    for delta = deltaSeeds
        for mu = muSeeds
            for sigma = sigmaSeeds
                p0 = [y0, log(max(delta, 1e-6)), mu, log(max(sigma, 1e-6))];
                [p, sse] = fminsearch(@(pp) logisticObjective(pp, x, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end

if isempty(best)
    return;
end

params = unpackLogisticParams(best);
yHatScaled = logisticModel(params, x);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = 10.^params.mu;
rmseRel = rmse ./ max(rangeY, eps);

fit.tau_half_seconds = tauHalf;
fit.sigma_decades = params.sigma;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end

function fit = fitStretchedExponential(t, y)
fit = initFitResult("fit_failed");

if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end

t = t(:);
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;

halfData = estimateHalfRangeTime(t, y);
betaSeeds = [0.50, 0.80, 1.20, 1.60];
tauSeeds = [sqrt(t(1) * t(end)), median(t), t(end) / 2, t(1)];
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    tauSeeds(end + 1) = halfData.tau_seconds / (log(2) .^ (1 / betaSeeds(2)));
end
deltaSeeds = [max(rangeY / scaleY, 0.05), max(y(end) - y(1), 0.05) / scaleY, 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];

best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 5000, 'MaxFunEvals', 10000);

for y0 = y0Seeds
    for delta = deltaSeeds
        for tau = tauSeeds
            if ~isfinite(tau) || tau <= 0
                continue;
            end
            for beta = betaSeeds
                p0 = [y0, log(max(delta, 1e-6)), log(tau), betaToRaw(beta)];
                [p, sse] = fminsearch(@(pp) stretchedObjective(pp, t, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end

if isempty(best)
    return;
end

params = unpackStretchedParams(best);
yHatScaled = stretchedModel(params, t);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = params.tau_char .* (log(2) .^ (1 ./ params.beta));
rmseRel = rmse ./ max(rangeY, eps);

fit.tau_half_seconds = tauHalf;
fit.tau_char_seconds = params.tau_char;
fit.beta = params.beta;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end

function result = estimateHalfRangeTime(t, y)
result = struct('tau_seconds', NaN, 'status', "unresolved");

if numel(t) < 2 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    result.status = "insufficient_data";
    return;
end

t = t(:);
y = y(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    result.status = "missing_peak";
    return;
end

yStart = y(1);
if peakIdx == 1 || ~isfinite(yStart) || peakValue <= yStart
    result.status = "no_upward_crossing";
    return;
end

target = yStart + 0.5 * (peakValue - yStart);
crossIdx = find(y(1:peakIdx-1) <= target & y(2:peakIdx) >= target, 1, 'first');
if isempty(crossIdx)
    tol = eps(max(abs([target; y])));
    exactIdx = find(abs(y(1:peakIdx) - target) <= tol, 1, 'first');
    if isempty(exactIdx)
        result.status = "no_upward_crossing";
        return;
    end
    result.tau_seconds = t(exactIdx);
    result.status = "ok";
    return;
end

t1 = t(crossIdx);
t2 = t(crossIdx + 1);
y1 = y(crossIdx);
y2 = y(crossIdx + 1);
tol = eps(max(abs([y1; y2])));
if ~isfinite(y1) || ~isfinite(y2) || abs(y2 - y1) <= tol
    result.tau_seconds = sqrt(t1 * t2);
    result.status = "ok";
    return;
end

frac = (target - y1) ./ (y2 - y1);
frac = min(max(frac, 0), 1);
logTau = log10(t1) + frac .* (log10(t2) - log10(t1));
result.tau_seconds = 10.^logTau;
result.status = "ok";
end

function [tauConsensus, nMethods, methodNames, spreadDecades] = buildConsensusTau(row)
tauValues = [];
names = strings(0, 1);

if row.tau_logistic_trusted && isfinite(row.tau_logistic_half_seconds) && row.tau_logistic_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_logistic_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "logistic_log_tw"; %#ok<AGROW>
end

if row.tau_stretched_trusted && isfinite(row.tau_stretched_half_seconds) && row.tau_stretched_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_stretched_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "stretched_exp"; %#ok<AGROW>
end

if row.tau_half_range_status == "ok" && isfinite(row.tau_half_range_seconds) && row.tau_half_range_seconds > 0
    tauValues(end + 1, 1) = row.tau_half_range_seconds; %#ok<AGROW>
    names(end + 1, 1) = "half_range"; %#ok<AGROW>
end

if isempty(tauValues)
    tauConsensus = NaN;
    nMethods = 0;
    methodNames = "";
    spreadDecades = NaN;
    return;
end

logTau = log10(tauValues);
tauConsensus = 10.^median(logTau);
nMethods = numel(tauValues);
methodNames = strjoin(names.', ', ');
spreadDecades = max(logTau) - min(logTau);
end

function fig = makeDipDepthFigure(dataTbl, tauTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 8.0], 'Name', 'Dip_depth_vs_tw_by_Tp');
ax = axes(fig);
hold(ax, 'on');

tpValues = unique(dataTbl.Tp, 'sorted');
cmap = parula(256);
colormap(ax, cmap);
tpMin = min(tpValues);
tpMax = max(tpValues);
if isfinite(tpMin) && isfinite(tpMax) && (tpMax > tpMin)
    clim(ax, [tpMin, tpMax]);
end

for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = dataTbl(dataTbl.Tp == tp, :);
    sub = sortrows(sub, 'tw');
    colorValue = mapValueToColor(tp, [tpMin, tpMax], cmap);

    tauRow = tauTbl(tauTbl.Tp == tp, :);
    lineStyle = '-';
    if ~isempty(tauRow) && tauRow.fragile_low_point_count
        lineStyle = '--';
    end

    plot(ax, sub.tw, sub.Dip_depth, lineStyle, ...
        'Color', colorValue, 'LineWidth', 2.0, ...
        'HandleVisibility', 'off');
    plot(ax, sub.tw, sub.Dip_depth, 'o', ...
        'Color', colorValue, 'MarkerFaceColor', colorValue, ...
        'MarkerSize', 5.5, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
end

set(ax, 'XScale', 'log');
xlabel(ax, 'Waiting time t_w (s)');
ylabel(ax, 'Dip depth (arb.)');
title(ax, 'Dip depth vs waiting time across stopping temperatures');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

cb = colorbar(ax);
cb.Label.String = 'T_p (K)';

hSolid = plot(ax, nan, nan, '-k', 'LineWidth', 2.0, 'DisplayName', '4-point T_p');
hDashed = plot(ax, nan, nan, '--k', 'LineWidth', 2.0, 'DisplayName', '3-point T_p');
legend(ax, [hSolid, hDashed], 'Location', 'eastoutside');
end

function fig = makeTauFigure(tauTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 12.0 8.0], 'Name', 'tau_vs_Tp');
ax = axes(fig);
hold(ax, 'on');

plot(ax, tauTbl.Tp, tauTbl.tau_logistic_half_seconds, '-o', ...
    'Color', [0.00 0.45 0.74], ...
    'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Logistic fit in log(t_w)');

plot(ax, tauTbl.Tp, tauTbl.tau_stretched_half_seconds, '-s', ...
    'Color', [0.85 0.33 0.10], ...
    'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Stretched-exp half time');

plot(ax, tauTbl.Tp, tauTbl.tau_half_range_seconds, '-^', ...
    'Color', [0.00 0.62 0.45], ...
    'MarkerFaceColor', [0.00 0.62 0.45], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Direct half-range');

plot(ax, tauTbl.Tp, tauTbl.tau_effective_seconds, '-d', ...
    'Color', [0.00 0.00 0.00], ...
    'MarkerFaceColor', [0.00 0.00 0.00], ...
    'MarkerSize', 5.5, 'LineWidth', 2.4, ...
    'DisplayName', 'Consensus');

fragileMask = tauTbl.fragile_low_point_count & isfinite(tauTbl.tau_effective_seconds);
if any(fragileMask)
    plot(ax, tauTbl.Tp(fragileMask), tauTbl.tau_effective_seconds(fragileMask), 'ko', ...
        'MarkerSize', 8, 'LineWidth', 1.2, 'MarkerFaceColor', 'w', ...
        'DisplayName', 'Fragile T_p (3 points)');
end

set(ax, 'YScale', 'log');
xlabel(ax, 'Stopping temperature T_p (K)');
ylabel(ax, 'Effective aging timescale \tau (s)');
title(ax, 'Aging timescale estimates vs stopping temperature');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside');
end

function reportText = buildReportText(runOutputDir, datasetPath, dataTbl, tauTbl)
lines = strings(0, 1);

lines(end + 1) = "# Aging timescale extraction";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf("Run root: `%s`", string(runOutputDir));
lines(end + 1) = sprintf("Input dataset: `%s`", string(datasetPath));
lines(end + 1) = "";
lines(end + 1) = "## Dataset summary";
lines(end + 1) = sprintf("- Total rows: %d.", height(dataTbl));
lines(end + 1) = sprintf("- Distinct stopping temperatures: %d (`%s` K).", ...
    numel(unique(dataTbl.Tp)), strjoin(string(unique(dataTbl.Tp).'), ", "));
lines(end + 1) = sprintf("- Waiting-time window: %.3g s to %.3g s.", ...
    min(dataTbl.tw, [], 'omitnan'), max(dataTbl.tw, [], 'omitnan'));

fragileRows = tauTbl(tauTbl.fragile_low_point_count, :);
if isempty(fragileRows)
    lines(end + 1) = "- All T_p values have at least 4 waiting-time points.";
else
    lines(end + 1) = sprintf("- Fragile high-T_p cases with only 3 points: `%s` K.", ...
        strjoin(string(fragileRows.Tp.'), ", "));
end
lines(end + 1) = "";

lines(end + 1) = "## Methods";
lines(end + 1) = "- `Logistic fit in log(t_w)`: fit `Dip_depth = y_0 + \\Delta / (1 + exp(-(log_{10} t_w - \\mu)/s))` and report `\\tau = 10^{\\mu}`.";
lines(end + 1) = "- `Stretched exponential`: fit `Dip_depth = y_0 + \\Delta (1 - exp(-(t_w / \\tau_c)^{\\beta}))` and report the half-rise time `\\tau = \\tau_c (\\ln 2)^{1/\\beta}`.";
lines(end + 1) = "- `Direct half-range`: interpolate the earliest upward crossing of half the rise from the shortest-time point to the observed peak.";
lines(end + 1) = "- `Consensus`: median of the trusted method estimates in log-time. Trust requires a finite positive tau and fit RMSE <= 0.65 of the observed Dip_depth range.";
lines(end + 1) = "";

lines(end + 1) = "## Main findings";
mainFindings = buildMainFindings(tauTbl);
for i = 1:numel(mainFindings)
    lines(end + 1) = mainFindings(i);
end
lines(end + 1) = "";

lines(end + 1) = "## Per-T_p summary";
summaryLines = buildPerTpSummary(tauTbl);
for i = 1:numel(summaryLines)
    lines(end + 1) = summaryLines(i);
end
lines(end + 1) = "";

lines(end + 1) = "## Method comparison";
comparisonLines = buildMethodComparison(tauTbl);
for i = 1:numel(comparisonLines)
    lines(end + 1) = comparisonLines(i);
end
lines(end + 1) = "";

lines(end + 1) = "## Cautions";
lines(end + 1) = "- `30 K` and `34 K` are structurally fragile because only 3 waiting times are available and the shortest sampled point is already the local maximum, so the half-range method is unresolved there.";
lines(end + 1) = "- `6 K`, `10 K`, and `26 K` show late-time downturns after an earlier peak; monotone fit models still provide useful buildup timescales, but their RMSE is correspondingly larger.";
lines(end + 1) = "- These taus are effective timescales extracted from the saved Dip-depth observable only; they are not a claim of a unique microscopic relaxation law.";
lines(end + 1) = "";

lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves in `Dip_depth_vs_tw_by_Tp`: 8, so a `parula` colormap plus labeled colorbar is used; dashed lines mark 3-point fragile T_p values.";
lines(end + 1) = "- Number of curves in `tau_vs_Tp`: 4 method/summary curves, so an explicit legend is used instead of a colormap.";
lines(end + 1) = "- Colormaps: `parula` for the multi-T_p Dip-depth sweep; no colormap for the tau comparison figure.";
lines(end + 1) = "- Smoothing applied: none; all methods fit or interpolate the saved scalar Dip-depth points directly.";
lines(end + 1) = "- Justification: the figure set is meant to compare the observable growth law itself and then compare the resulting tau estimates with minimal processing.";
lines(end + 1) = "";

lines(end + 1) = "## Exported artifacts";
lines(end + 1) = "- `tables/tau_vs_Tp.csv`";
lines(end + 1) = "- `figures/Dip_depth_vs_tw_by_Tp.png`";
lines(end + 1) = "- `figures/tau_vs_Tp.png`";
lines(end + 1) = "- `reports/aging_timescale_extraction_report.md`";
lines(end + 1) = "- `review/aging_timescale_extraction.zip`";

reportText = strjoin(lines, newline);
end

function lines = buildMainFindings(tauTbl)
lines = strings(0, 1);

validConsensus = tauTbl(isfinite(tauTbl.tau_effective_seconds), :);
if isempty(validConsensus)
    lines(end + 1) = "- No trusted consensus tau could be extracted from the available Dip-depth trajectories.";
    return;
end

[~, minIdx] = min(validConsensus.tau_effective_seconds);
[~, maxIdx] = max(validConsensus.tau_effective_seconds);
[~, consistentIdx] = min(validConsensus.tau_method_spread_decades);
[~, divergentIdx] = max(validConsensus.tau_method_spread_decades);

lines(end + 1) = sprintf("- The shortest trusted consensus timescale appears at `T_p = %g K` with `\\tau \\approx %.3g s`.", ...
    validConsensus.Tp(minIdx), validConsensus.tau_effective_seconds(minIdx));
lines(end + 1) = sprintf("- The longest trusted consensus timescale appears at `T_p = %g K` with `\\tau \\approx %.3g s`.", ...
    validConsensus.Tp(maxIdx), validConsensus.tau_effective_seconds(maxIdx));
lines(end + 1) = sprintf("- Best method agreement occurs near `T_p = %g K`, where the trusted taus span only `%.3f` decades.", ...
    validConsensus.Tp(consistentIdx), validConsensus.tau_method_spread_decades(consistentIdx));
lines(end + 1) = sprintf("- The largest method spread among trusted estimates occurs near `T_p = %g K`, where the tau span is `%.3f` decades.", ...
    validConsensus.Tp(divergentIdx), validConsensus.tau_method_spread_decades(divergentIdx));

downturnRows = tauTbl(tauTbl.n_downturns > 0, :);
if ~isempty(downturnRows)
    lines(end + 1) = sprintf("- Late-time Dip-depth downturns are present at `T_p = %s K`, which is the main source of model disagreement.", ...
        strjoin(string(downturnRows.Tp.'), ", "));
end
end

function lines = buildPerTpSummary(tauTbl)
lines = strings(0, 1);

for i = 1:height(tauTbl)
    tauRow = tauTbl(i, :);
    lines(end + 1) = sprintf(['- `T_p = %g K`: logistic `%.3g s` (%s), stretched `%.3g s` (%s, ' ...
        '\\beta = %.2f), direct half-range `%.3g s` (%s), consensus `%.3g s` from `%s`.'], ...
        tauRow.Tp, ...
        tauRow.tau_logistic_half_seconds, tauRow.tau_logistic_status, ...
        tauRow.tau_stretched_half_seconds, tauRow.tau_stretched_status, tauRow.tau_stretched_beta, ...
        tauRow.tau_half_range_seconds, tauRow.tau_half_range_status, ...
        tauRow.tau_effective_seconds, tauRow.tau_consensus_methods);
end
end

function lines = buildMethodComparison(tauTbl)
lines = strings(0, 1);

logisticVsHalf = pairwiseTauStats(tauTbl.tau_logistic_half_seconds, tauTbl.tau_half_range_seconds);
stretchedVsHalf = pairwiseTauStats(tauTbl.tau_stretched_half_seconds, tauTbl.tau_half_range_seconds);
logisticVsStretched = pairwiseTauStats(tauTbl.tau_logistic_half_seconds, tauTbl.tau_stretched_half_seconds);

lines(end + 1) = sprintf("- Logistic vs direct half-range: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", ...
    logisticVsHalf.n, logisticVsHalf.median_abs_delta_decades);
lines(end + 1) = sprintf("- Stretched-exp vs direct half-range: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", ...
    stretchedVsHalf.n, stretchedVsHalf.median_abs_delta_decades);
lines(end + 1) = sprintf("- Logistic vs stretched-exp: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", ...
    logisticVsStretched.n, logisticVsStretched.median_abs_delta_decades);

untrustedLogistic = tauTbl(~tauTbl.tau_logistic_trusted, :);
if ~isempty(untrustedLogistic)
    lines(end + 1) = sprintf("- Logistic fits are least reliable at `T_p = %s K`.", ...
        strjoin(string(untrustedLogistic.Tp.'), ", "));
end

untrustedStretched = tauTbl(~tauTbl.tau_stretched_trusted, :);
if ~isempty(untrustedStretched)
    lines(end + 1) = sprintf("- Stretched-exponential fits are least reliable at `T_p = %s K`.", ...
        strjoin(string(untrustedStretched.Tp.'), ", "));
end
end

function stats = pairwiseTauStats(tauA, tauB)
mask = isfinite(tauA) & tauA > 0 & isfinite(tauB) & tauB > 0;
stats = struct('n', nnz(mask), 'median_abs_delta_decades', NaN);
if ~any(mask)
    return;
end
delta = abs(log10(tauA(mask)) - log10(tauB(mask)));
stats.median_abs_delta_decades = median(delta, 'omitnan');
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

zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function [sse, yHat] = logisticObjective(p, x, y)
params = unpackLogisticParams(p);
yHat = logisticModel(params, x);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackLogisticParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.mu = p(3);
params.sigma = exp(p(4));
end

function yHat = logisticModel(params, x)
z = -(x - params.mu) ./ max(params.sigma, eps);
yHat = params.y0 + params.delta ./ (1 + exp(z));
end

function [sse, yHat] = stretchedObjective(p, t, y)
params = unpackStretchedParams(p);
yHat = stretchedModel(params, t);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackStretchedParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.tau_char = exp(p(3));
params.beta = rawToBeta(p(4));
end

function yHat = stretchedModel(params, t)
scaledT = (t ./ max(params.tau_char, eps)) .^ params.beta;
yHat = params.y0 + params.delta .* (1 - exp(-scaledT));
end

function raw = betaToRaw(beta)
betaMax = 2.0;
beta = min(max(beta, 1e-4), betaMax - 1e-4);
raw = log(beta ./ (betaMax - beta));
end

function beta = rawToBeta(raw)
betaMax = 2.0;
beta = betaMax ./ (1 + exp(-raw));
end

function r2 = computeRsquared(y, yHat)
mask = isfinite(y) & isfinite(yHat);
if nnz(mask) < 2
    r2 = NaN;
    return;
end
ssRes = sum((y(mask) - yHat(mask)).^2);
ssTot = sum((y(mask) - mean(y(mask), 'omitnan')).^2);
if ssTot <= eps
    r2 = NaN;
else
    r2 = 1 - ssRes ./ ssTot;
end
end

function status = classifyModelStatus(rmseRel, tauHalf, t)
if ~isfinite(tauHalf) || tauHalf <= 0
    status = "fit_failed";
elseif ~isfinite(rmseRel)
    status = "fit_failed";
elseif rmseRel > 0.65
    status = "poor_match";
elseif tauHalf < min(t) || tauHalf > max(t)
    status = "extrapolated";
else
    status = "ok";
end
end

function colorValue = mapValueToColor(value, limits, cmap)
if limits(2) <= limits(1)
    idx = 1;
else
    frac = (value - limits(1)) ./ (limits(2) - limits(1));
    frac = min(max(frac, 0), 1);
    idx = 1 + round(frac .* (size(cmap, 1) - 1));
end
colorValue = cmap(idx, :);
end





