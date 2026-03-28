function out = switching_width_roughness_competition_test(cfg)
% switching_width_roughness_competition_test
% Test whether width_I(T) behaves as a roughness/competition width using
% saved switching outputs only (no raw reprocessing).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSource(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('alignment:%s', char(source.runName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] switching width roughness competition test started', stampNow()));
appendText(run.log_path, sprintf('Source run: %s', char(source.runName)));
appendText(run.log_path, sprintf('Observables table: %s', source.observablesPath));
appendText(run.log_path, sprintf('Samples table: %s', source.samplesPath));

obsTbl = readtable(source.observablesPath);
samplesTbl = readtable(source.samplesPath);

profiles = buildNormalizedProfiles(obsTbl, samplesTbl, cfg);
analysis = computeDiagnostics(profiles, cfg);

perTempTbl = buildPerTemperatureTable(analysis);
corrTbl = buildCorrelationTable(analysis.perTemp);
summaryTbl = buildSummaryTable(analysis, corrTbl, source, cfg);
manifestTbl = buildSourceManifestTable(source);

perTempPath = save_run_table(perTempTbl, 'width_roughness_per_temperature.csv', runDir);
corrPath = save_run_table(corrTbl, 'width_roughness_correlations.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'width_roughness_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

fig1 = saveWidthVsTFigure(analysis, runDir, 'width_I_vs_temperature');
fig2 = saveCollapseFigure(analysis, runDir, 'normalized_collapse_profiles');
fig3 = saveDiagnosticOverlayFigure(analysis, runDir, 'diagnostics_vs_temperature');
fig4 = saveScatterFigure(analysis, runDir, 'width_vs_midpoint_sharpness', ...
    analysis.perTemp.midpoint_slope, 'Midpoint slope at S_{norm}=0.5 (1/u)', 'Midpoint sharpness');
fig5 = saveScatterFigure(analysis, runDir, 'width_vs_collapse_rmse', ...
    analysis.perTemp.collapse_rmse, 'Collapse RMSE to mean shape', 'Collapse residual');

reportText = buildReportText(analysis, corrTbl, source, cfg);
reportPath = save_run_report(reportText, 'switching_width_roughness_competition_report.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_width_roughness_competition_bundle.zip');

appendText(run.notes_path, sprintf('T range analyzed: %.2f to %.2f K', min(analysis.perTemp.T_K), max(analysis.perTemp.T_K)));
appendText(run.notes_path, sprintf('n temperatures: %d', numel(analysis.perTemp.T_K)));
appendText(run.notes_path, sprintf('width peak T: %.3f K', analysis.summary.width_peak_T_K));
appendText(run.notes_path, sprintf('crossover T: %.3f K', analysis.summary.crossover_T_K));
appendText(run.notes_path, sprintf('peak-crossover delta: %.3f K', analysis.summary.delta_peak_to_crossover_K));
appendText(run.notes_path, sprintf('corr(width, broadness_inv_slope) Pearson: %.6g', analysis.summary.corr_width_vs_broadness_pearson));
appendText(run.notes_path, sprintf('corr(width, collapse_rmse) Pearson: %.6g', analysis.summary.corr_width_vs_collapse_rmse_pearson));

appendText(run.log_path, sprintf('Saved per-temperature table: %s', perTempPath));
appendText(run.log_path, sprintf('Saved correlation table: %s', corrPath));
appendText(run.log_path, sprintf('Saved summary table: %s', summaryPath));
appendText(run.log_path, sprintf('Saved source manifest table: %s', manifestPath));
appendText(run.log_path, sprintf('Saved report: %s', reportPath));
appendText(run.log_path, sprintf('Saved zip: %s', zipPath));
appendText(run.log_path, sprintf('[%s] switching width roughness competition test complete', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.analysis = analysis;
out.tables = struct( ...
    'per_temperature', string(perTempPath), ...
    'correlations', string(corrPath), ...
    'summary', string(summaryPath), ...
    'manifest', string(manifestPath));
out.figures = struct( ...
    'width_vs_T', string(fig1.png), ...
    'collapse', string(fig2.png), ...
    'diagnostics_overlay', string(fig3.png), ...
    'width_vs_sharpness', string(fig4.png), ...
    'width_vs_collapse_rmse', string(fig5.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching width roughness competition test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('width peak T = %.3f K, crossover T = %.3f K, delta = %.3f K\n', ...
    analysis.summary.width_peak_T_K, analysis.summary.crossover_T_K, analysis.summary.delta_peak_to_crossover_K);
fprintf('corr(width, broadness_inv_slope) = %.4f\n', analysis.summary.corr_width_vs_broadness_pearson);
fprintf('corr(width, collapse_rmse) = %.4f\n', analysis.summary.corr_width_vs_collapse_rmse_pearson);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_width_roughness_competition_test');
cfg = setDefault(cfg, 'sourceRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'sampleTemperatureToleranceK', 0.35);
cfg = setDefault(cfg, 'uGridMin', -3.0);
cfg = setDefault(cfg, 'uGridMax', 3.0);
cfg = setDefault(cfg, 'uGridCount', 181);
cfg = setDefault(cfg, 'smoothWindow', 3);
cfg = setDefault(cfg, 'crossoverWindowK', 4.0);
end

function cfg = setDefault(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end

function source = resolveSource(repoRoot, cfg)
source = struct();
source.runName = string(cfg.sourceRunName);
source.runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.runName));
source.observablesPath = fullfile(source.runDir, 'alignment_audit', 'switching_alignment_observables_vs_T.csv');
source.samplesPath = fullfile(source.runDir, 'alignment_audit', 'switching_alignment_samples.csv');

if exist(source.runDir, 'dir') ~= 7
    error('Source run directory does not exist: %s', source.runDir);
end
if exist(source.observablesPath, 'file') ~= 2
    error('Missing source observables table: %s', source.observablesPath);
end
if exist(source.samplesPath, 'file') ~= 2
    error('Missing source samples table: %s', source.samplesPath);
end
end

function profiles = buildNormalizedProfiles(obsTbl, samplesTbl, cfg)
colObs = resolveObsColumns(obsTbl);
colSamp = resolveSampleColumns(samplesTbl);

T_obs = double(obsTbl.(colObs.T));
I_peak = double(obsTbl.(colObs.I_peak));
S_peak = double(obsTbl.(colObs.S_peak));
width_I = double(obsTbl.(colObs.width));
halfwidth_asym = double(obsTbl.(colObs.halfwidth_asym));
asym_existing = double(obsTbl.(colObs.asym));

validObs = isfinite(T_obs) & isfinite(I_peak) & isfinite(S_peak) & isfinite(width_I) & ...
    T_obs >= cfg.temperatureMinK & T_obs <= cfg.temperatureMaxK & ...
    S_peak > 0 & width_I > 0;

T_obs = T_obs(validObs);
I_peak = I_peak(validObs);
S_peak = S_peak(validObs);
width_I = width_I(validObs);
halfwidth_asym = halfwidth_asym(validObs);
asym_existing = asym_existing(validObs);

[T_obs, order] = sort(T_obs);
I_peak = I_peak(order);
S_peak = S_peak(order);
width_I = width_I(order);
halfwidth_asym = halfwidth_asym(order);
asym_existing = asym_existing(order);

uCommon = linspace(cfg.uGridMin, cfg.uGridMax, cfg.uGridCount).';
nT = numel(T_obs);
profileMatrix = NaN(nT, numel(uCommon));
curveMeta = repmat(struct('u', [], 'y', [], 'n_points', 0), nT, 1);

T_samples = double(samplesTbl.(colSamp.T));
I_samples = double(samplesTbl.(colSamp.I));
S_samples = double(samplesTbl.(colSamp.S));

for i = 1:nT
    t = T_obs(i);
    mask = isfinite(T_samples) & isfinite(I_samples) & isfinite(S_samples) & ...
        abs(T_samples - t) <= cfg.sampleTemperatureToleranceK;

    I_t = I_samples(mask);
    S_t = S_samples(mask);

    if numel(I_t) < 4
        continue;
    end

    [I_t, orderI] = sort(I_t);
    S_t = S_t(orderI);

    u = (I_t - I_peak(i)) ./ width_I(i);
    y = S_t ./ S_peak(i);

    validCurve = isfinite(u) & isfinite(y);
    u = u(validCurve);
    y = y(validCurve);

    if numel(u) < 4
        continue;
    end

    [u, uniqIdx] = unique(u, 'stable');
    y = y(uniqIdx);

    if numel(u) < 4
        continue;
    end

    curveMeta(i).u = u;
    curveMeta(i).y = y;
    curveMeta(i).n_points = numel(u);

    yInterp = interp1(u, y, uCommon, 'linear', NaN);
    profileMatrix(i, :) = yInterp.';
end

validCurveMask = false(nT, 1);
for i = 1:nT
    validCurveMask(i) = ~isempty(curveMeta(i).u);
end

T = T_obs(validCurveMask);
I_peak = I_peak(validCurveMask);
S_peak = S_peak(validCurveMask);
width_I = width_I(validCurveMask);
halfwidth_asym = halfwidth_asym(validCurveMask);
asym_existing = asym_existing(validCurveMask);
curveMeta = curveMeta(validCurveMask);
profileMatrix = profileMatrix(validCurveMask, :);

profiles = struct();
profiles.T = T(:);
profiles.I_peak = I_peak(:);
profiles.S_peak = S_peak(:);
profiles.width_I = width_I(:);
profiles.halfwidth_asym_existing = halfwidth_asym(:);
profiles.asym_existing = asym_existing(:);
profiles.u_common = uCommon(:);
profiles.profile_matrix = profileMatrix;
profiles.curves = curveMeta;
end

function cols = resolveObsColumns(tbl)
vars = string(tbl.Properties.VariableNames);
cols = struct();
cols.T = pickAlias(vars, ["T_K", "T", "temperature", "temperature_K"]);
cols.I_peak = pickAlias(vars, ["Ipeak", "I_peak", "Ipeak_mA"]);
cols.S_peak = pickAlias(vars, ["S_peak", "Speak"]);
cols.width = pickAlias(vars, ["width_I", "width", "widthI", "width_mA"]);
cols.halfwidth_asym = pickAlias(vars, ["halfwidth_diff_norm", "halfwidth_diff_norm_existing"]);
cols.asym = pickAlias(vars, ["asym", "asym_area_ratio"]);

required = {'T','I_peak','S_peak','width'};
for i = 1:numel(required)
    if isempty(cols.(required{i}))
        error('Missing required column "%s" in observables table.', required{i});
    end
end
if isempty(cols.halfwidth_asym)
    cols.halfwidth_asym = cols.width;
end
if isempty(cols.asym)
    cols.asym = cols.width;
end

cols = mapToChar(cols);
end

function cols = resolveSampleColumns(tbl)
vars = string(tbl.Properties.VariableNames);
cols = struct();
cols.I = pickAlias(vars, ["current_mA", "I_mA", "I", "current"]);
cols.T = pickAlias(vars, ["T_K", "T", "temperature"]);
cols.S = pickAlias(vars, ["S_percent", "S", "response", "P2P_percent"]);

required = {'I','T','S'};
for i = 1:numel(required)
    if isempty(cols.(required{i}))
        error('Missing required column "%s" in samples table.', required{i});
    end
end

cols = mapToChar(cols);
end

function out = mapToChar(in)
keys = fieldnames(in);
out = in;
for i = 1:numel(keys)
    key = keys{i};
    out.(key) = char(in.(key));
end
end

function name = pickAlias(varNames, aliases)
name = "";
for i = 1:numel(aliases)
    idx = find(strcmpi(varNames, aliases(i)), 1, 'first');
    if ~isempty(idx)
        name = varNames(idx);
        return;
    end
end
end

function analysis = computeDiagnostics(profiles, cfg)
T = profiles.T(:);
width = profiles.width_I(:);
I_peak = profiles.I_peak(:);
S_peak = profiles.S_peak(:);

uCommon = profiles.u_common(:);
P = profiles.profile_matrix;

meanProfile = mean(P, 1, 'omitnan');
stdProfile = std(P, 0, 1, 'omitnan');

nT = numel(T);
midSlope = NaN(nT, 1);
invSlope = NaN(nT, 1);
span2575 = NaN(nT, 1);
halfAsym = NaN(nT, 1);
collapseRMSE = NaN(nT, 1);
collapseVar = NaN(nT, 1);
collapseMAE = NaN(nT, 1);

for i = 1:nT
    u = profiles.curves(i).u;
    y = profiles.curves(i).y;

    [midSlope(i), invSlope(i), span2575(i), halfAsym(i)] = shapeMetrics(u, y);

    yi = P(i, :);
    valid = isfinite(yi) & isfinite(meanProfile);
    if nnz(valid) >= 5
        resid = yi(valid) - meanProfile(valid);
        collapseRMSE(i) = sqrt(mean(resid .^ 2));
        collapseVar(i) = var(resid, 0);
        collapseMAE(i) = mean(abs(resid));
    end
end

if cfg.smoothWindow >= 2
    widthSmooth = smoothdata(width, 'movmean', min(cfg.smoothWindow, numel(width)));
    IpeakSmooth = smoothdata(I_peak, 'movmean', min(cfg.smoothWindow, numel(I_peak)));
else
    widthSmooth = width;
    IpeakSmooth = I_peak;
end

dWidthdT = gradient(widthSmooth, T);
dIpeakdT = gradient(IpeakSmooth, T);

[~, idxWidthPeak] = max(width);
widthPeakT = T(idxWidthPeak);

[~, idxCross] = max(abs(dIpeakdT));
crossoverT = T(idxCross);

windowMask = abs(T - crossoverT) <= cfg.crossoverWindowK;
outsideMask = ~windowMask;

widthMeanWin = mean(width(windowMask), 'omitnan');
widthMeanOut = mean(width(outsideMask), 'omitnan');
widthWindowRatio = widthMeanWin ./ widthMeanOut;

broadeningMask = dWidthdT > 0;
fracBroadeningWin = mean(double(broadeningMask(windowMask)), 'omitnan');
fracBroadeningOut = mean(double(broadeningMask(outsideMask)), 'omitnan');

corrBroadnessPearson = corrPair(width, invSlope, 'Pearson');
corrBroadnessSpearman = corrPair(width, invSlope, 'Spearman');
corrSharpnessPearson = corrPair(width, midSlope, 'Pearson');
corrSharpnessSpearman = corrPair(width, midSlope, 'Spearman');
corrCollapsePearson = corrPair(width, collapseRMSE, 'Pearson');
corrCollapseSpearman = corrPair(width, collapseRMSE, 'Spearman');
corrVarPearson = corrPair(width, collapseVar, 'Pearson');
corrVarSpearman = corrPair(width, collapseVar, 'Spearman');

pointwiseCollapseVariance = var(P, 0, 1, 'omitnan');
globalCollapseVar = mean(pointwiseCollapseVariance(isfinite(pointwiseCollapseVariance)), 'omitnan');

perTemp = struct();
perTemp.T_K = T;
perTemp.width_I = width;
perTemp.I_peak = I_peak;
perTemp.S_peak = S_peak;
perTemp.midpoint_slope = midSlope;
perTemp.broadness_inv_slope = invSlope;
perTemp.transition_span_25_75 = span2575;
perTemp.halfwidth_asymmetry = halfAsym;
perTemp.collapse_rmse = collapseRMSE;
perTemp.collapse_var = collapseVar;
perTemp.collapse_mae = collapseMAE;
perTemp.dwidth_dT = dWidthdT;
perTemp.dIpeak_dT = dIpeakdT;
perTemp.broadening_flag = broadeningMask;
perTemp.halfwidth_diff_norm_existing = profiles.halfwidth_asym_existing(:);
perTemp.asym_existing = profiles.asym_existing(:);

summary = struct();
summary.width_peak_T_K = widthPeakT;
summary.crossover_T_K = crossoverT;
summary.delta_peak_to_crossover_K = widthPeakT - crossoverT;
summary.width_window_ratio = widthWindowRatio;
summary.frac_broadening_in_window = fracBroadeningWin;
summary.frac_broadening_outside_window = fracBroadeningOut;
summary.corr_width_vs_broadness_pearson = corrBroadnessPearson;
summary.corr_width_vs_broadness_spearman = corrBroadnessSpearman;
summary.corr_width_vs_sharpness_pearson = corrSharpnessPearson;
summary.corr_width_vs_sharpness_spearman = corrSharpnessSpearman;
summary.corr_width_vs_collapse_rmse_pearson = corrCollapsePearson;
summary.corr_width_vs_collapse_rmse_spearman = corrCollapseSpearman;
summary.corr_width_vs_collapse_var_pearson = corrVarPearson;
summary.corr_width_vs_collapse_var_spearman = corrVarSpearman;
summary.global_collapse_variance = globalCollapseVar;
summary.n_temperatures = numel(T);

analysis = struct();
analysis.perTemp = perTemp;
analysis.summary = summary;
analysis.u_common = uCommon;
analysis.mean_profile = meanProfile(:);
analysis.std_profile = stdProfile(:);
analysis.profile_matrix = P;
analysis.crossover_window_mask = windowMask;
end

function [slopeMid, invSlope, span2575, asym2575] = shapeMetrics(u, y)
slopeMid = NaN;
invSlope = NaN;
span2575 = NaN;
asym2575 = NaN;

if numel(u) < 5 || numel(y) < 5
    return;
end

uFine = linspace(min(u), max(u), 500).';
yFine = interp1(u, y, uFine, 'pchip', NaN);
valid = isfinite(uFine) & isfinite(yFine);
if nnz(valid) < 20
    return;
end
uFine = uFine(valid);
yFine = yFine(valid);

[~, idx50] = min(abs(yFine - 0.5));
[~, idx25] = min(abs(yFine - 0.25));
[~, idx75] = min(abs(yFine - 0.75));

u50 = uFine(idx50);
u25 = uFine(idx25);
u75 = uFine(idx75);

dydu = gradient(yFine, uFine);
slopeMid = dydu(idx50);

if isfinite(slopeMid) && abs(slopeMid) > 0
    invSlope = 1 ./ abs(slopeMid);
end

if isfinite(u75) && isfinite(u25)
    span2575 = u75 - u25;
end

leftHalf = u50 - u25;
rightHalf = u75 - u50;
den = leftHalf + rightHalf;
if isfinite(den) && abs(den) > 0
    asym2575 = (rightHalf - leftHalf) ./ den;
end
end

function tbl = buildPerTemperatureTable(analysis)
p = analysis.perTemp;

n = numel(p.T_K);
windowFlag = false(n, 1);
windowFlag(analysis.crossover_window_mask) = true;

tbl = table( ...
    p.T_K(:), p.width_I(:), p.I_peak(:), p.S_peak(:), ...
    p.midpoint_slope(:), p.broadness_inv_slope(:), p.transition_span_25_75(:), ...
    p.halfwidth_asymmetry(:), p.collapse_rmse(:), p.collapse_var(:), p.collapse_mae(:), ...
    p.halfwidth_diff_norm_existing(:), p.asym_existing(:), p.dwidth_dT(:), p.dIpeak_dT(:), ...
    logical(p.broadening_flag(:)), logical(windowFlag), ...
    'VariableNames', { ...
    'T_K', 'width_I', 'I_peak', 'S_peak', ...
    'midpoint_slope', 'broadness_inv_slope', 'transition_span_25_75', ...
    'halfwidth_asymmetry', 'collapse_rmse', 'collapse_var', 'collapse_mae', ...
    'halfwidth_diff_norm_existing', 'asym_existing', 'dwidth_dT', 'dIpeak_dT', ...
    'broadening_flag', 'crossover_window_flag'});
end

function corrTbl = buildCorrelationTable(perTemp)
metrics = { ...
    'midpoint_slope', perTemp.midpoint_slope; ...
    'broadness_inv_slope', perTemp.broadness_inv_slope; ...
    'transition_span_25_75', perTemp.transition_span_25_75; ...
    'halfwidth_asymmetry_abs', abs(perTemp.halfwidth_asymmetry); ...
    'collapse_rmse', perTemp.collapse_rmse; ...
    'collapse_var', perTemp.collapse_var; ...
    'collapse_mae', perTemp.collapse_mae; ...
    'halfwidth_diff_norm_existing_abs', abs(perTemp.halfwidth_diff_norm_existing); ...
    'asym_existing_abs', abs(perTemp.asym_existing)};

rows = cell(size(metrics, 1), 7);
for i = 1:size(metrics, 1)
    name = metrics{i, 1};
    y = metrics{i, 2};
    x = perTemp.width_I;
    mask = isfinite(x) & isfinite(y);

    rows{i, 1} = string(name);
    rows{i, 2} = nnz(mask);
    rows{i, 3} = corrPair(x, y, 'Pearson');
    rows{i, 4} = corrPair(x, y, 'Spearman');

    slope = NaN;
    intercept = NaN;
    if nnz(mask) >= 3
        p = polyfit(x(mask), y(mask), 1);
        slope = p(1);
        intercept = p(2);
    end
    rows{i, 5} = slope;
    rows{i, 6} = intercept;

    if strcmp(name, 'midpoint_slope')
        rows{i, 7} = "larger width -> lower sharpness expected";
    elseif strcmp(name, 'broadness_inv_slope') || strcmp(name, 'transition_span_25_75')
        rows{i, 7} = "larger width -> broader transition expected";
    elseif strcmp(name, 'collapse_rmse') || strcmp(name, 'collapse_var')
        rows{i, 7} = "larger width -> worse collapse expected";
    else
        rows{i, 7} = "shape/asymmetry auxiliary check";
    end
end

corrTbl = cell2table(rows, 'VariableNames', { ...
    'metric', 'n_points', 'pearson_r', 'spearman_rho', ...
    'linear_slope', 'linear_intercept', 'interpretation_target'});
end

function tbl = buildSummaryTable(analysis, corrTbl, source, cfg)
s = analysis.summary;

metric = strings(0,1);
value = [];
units = strings(0,1);
notes = strings(0,1);

[metric, value, units, notes] = addSummary(metric, value, units, notes, 'n_temperatures', s.n_temperatures, 'count', 'temperatures with valid width and normalized curves');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'width_peak_T_K', s.width_peak_T_K, 'K', 'maximum width_I temperature');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'crossover_T_K', s.crossover_T_K, 'K', 'from max |dI_peak/dT| on analyzed window');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'delta_peak_to_crossover_K', s.delta_peak_to_crossover_K, 'K', 'positive if width peak is above crossover T');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'width_mean_ratio_window_vs_outside', s.width_window_ratio, 'unitless', sprintf('window = +/- %.1f K around crossover', cfg.crossoverWindowK));
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'fraction_broadening_in_window', s.frac_broadening_in_window, 'fraction', 'fraction of dwidth/dT > 0 inside crossover window');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'fraction_broadening_outside_window', s.frac_broadening_outside_window, 'fraction', 'fraction of dwidth/dT > 0 outside crossover window');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'corr_width_vs_sharpness_pearson', s.corr_width_vs_sharpness_pearson, 'unitless', 'sharpness = midpoint slope at S_norm=0.5');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'corr_width_vs_broadness_pearson', s.corr_width_vs_broadness_pearson, 'unitless', 'broadness = 1/|midpoint slope|');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'corr_width_vs_collapse_rmse_pearson', s.corr_width_vs_collapse_rmse_pearson, 'unitless', 'collapse residual to best mean shape');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'corr_width_vs_collapse_var_pearson', s.corr_width_vs_collapse_var_pearson, 'unitless', 'residual variance to best mean shape');
[metric, value, units, notes] = addSummary(metric, value, units, notes, 'global_collapse_variance', s.global_collapse_variance, 'unitless^2', 'mean pointwise variance across normalized collapse grid');

row = corrTbl(strcmp(corrTbl.metric, "collapse_rmse"), :);
if ~isempty(row)
    [metric, value, units, notes] = addSummary(metric, value, units, notes, ...
        'corr_width_vs_collapse_rmse_spearman', row.spearman_rho(1), 'unitless', 'rank-based association');
end

tbl = table(metric, value(:), units, notes, ...
    repmat(source.runName, numel(value), 1), ...
    'VariableNames', {'metric', 'value', 'units', 'notes', 'source_run'});
end

function [metric, value, units, notes] = addSummary(metric, value, units, notes, m, v, u, n)
metric(end+1,1) = string(m);
value(end+1,1) = v;
units(end+1,1) = string(u);
notes(end+1,1) = string(n);
end

function tbl = buildSourceManifestTable(source)
role = ["switching_observables"; "switching_samples"];
sourceRun = [source.runName; source.runName];
sourceFile = string({source.observablesPath; source.samplesPath});
tbl = table(role, sourceRun, sourceFile, ...
    'VariableNames', {'role', 'source_run', 'source_file'});
end

function figOut = saveWidthVsTFigure(analysis, runDir, baseName)
p = analysis.perTemp;

fig = figure('Visible', 'off', 'Color', 'w', 'Name', baseName, 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');

plot(ax, p.T_K, p.width_I, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'Color', [0.1 0.1 0.1], 'MarkerFaceColor', [0.1 0.1 0.1], 'DisplayName', 'width_I(T)');

plot(ax, p.T_K, smoothdata(p.width_I, 'movmean', min(3, numel(p.width_I))), '--', ...
    'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], 'DisplayName', 'smoothed width_I');

xline(ax, analysis.summary.crossover_T_K, ':', 'LineWidth', 2.0, ...
    'Color', [0.0 0.45 0.74], 'DisplayName', 'crossover T');
xline(ax, analysis.summary.width_peak_T_K, '--', 'LineWidth', 1.8, ...
    'Color', [0.47 0.67 0.19], 'DisplayName', 'width peak T');

xlabel(ax, 'Temperature (K)');
ylabel(ax, 'width_I (mA)');
title(ax, 'width_I(T) with crossover markers');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
legend(ax, 'Location', 'best', 'Box', 'off');

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figOut = saveCollapseFigure(analysis, runDir, baseName)
T = analysis.perTemp.T_K;
u = analysis.u_common;
P = analysis.profile_matrix;

fig = figure('Visible', 'off', 'Color', 'w', 'Name', baseName, 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');

n = numel(T);
cmap = parula(max(n, 2));
for i = 1:n
    yi = P(i, :);
    mask = isfinite(yi) & isfinite(u.');
    if nnz(mask) < 4
        continue;
    end
    plot(ax, u(mask), yi(mask), '-', 'LineWidth', 1.9, ...
        'Color', cmap(i, :), 'HandleVisibility', 'off');
end

mu = analysis.mean_profile;
sd = analysis.std_profile;
valid = isfinite(mu) & isfinite(sd) & isfinite(u);
ux = u(valid);
lo = mu(valid) - sd(valid);
hi = mu(valid) + sd(valid);
patch(ax, [ux; flipud(ux)], [lo; flipud(hi)], [0.6 0.6 0.6], ...
    'FaceAlpha', 0.2, 'EdgeColor', 'none', 'DisplayName', 'mean +/- std');
plot(ax, ux, mu(valid), '-', 'Color', [0 0 0], 'LineWidth', 2.8, 'DisplayName', 'mean normalized shape');

xlabel(ax, 'u = (I - I_peak) / width_I');
ylabel(ax, 'S_{norm} = S / S_peak');
title(ax, 'Normalized switching collapse and residual spread');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

cb = colorbar(ax);
colormap(ax, cmap);
cb.Label.String = 'Temperature (K)';
cb.Ticks = linspace(0, 1, min(6, n));
cb.TickLabels = compose('%.0f', linspace(min(T), max(T), min(6, n)));

legend(ax, 'Location', 'northwest', 'Box', 'off');

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figOut = saveDiagnosticOverlayFigure(analysis, runDir, baseName)
p = analysis.perTemp;

wN = normalize01(p.width_I);
bN = normalize01(p.broadness_inv_slope);
rN = normalize01(p.collapse_rmse);
aN = normalize01(abs(p.halfwidth_asymmetry));

fig = figure('Visible', 'off', 'Color', 'w', 'Name', baseName, 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');

plot(ax, p.T_K, wN, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, ...
    'Color', [0.05 0.05 0.05], 'MarkerFaceColor', [0.05 0.05 0.05], 'DisplayName', 'width_I (norm)');
plot(ax, p.T_K, bN, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', 'broadness 1/|slope| (norm)');
plot(ax, p.T_K, rN, '-^', 'LineWidth', 2.0, 'MarkerSize', 5, ...
    'Color', [0.0 0.45 0.74], 'MarkerFaceColor', [0.0 0.45 0.74], 'DisplayName', 'collapse RMSE (norm)');
plot(ax, p.T_K, aN, '--', 'LineWidth', 1.8, ...
    'Color', [0.47 0.67 0.19], 'DisplayName', '|half-width asymmetry| (norm)');

xline(ax, analysis.summary.crossover_T_K, ':', 'LineWidth', 1.8, ...
    'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');

xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized diagnostics (arb. units)');
title(ax, 'Width, broadness, collapse residual, and asymmetry vs T');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
legend(ax, 'Location', 'best', 'Box', 'off');

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figOut = saveScatterFigure(analysis, runDir, baseName, y, yLabel, panelLabel)
x = analysis.perTemp.width_I;
T = analysis.perTemp.T_K;

mask = isfinite(x) & isfinite(y) & isfinite(T);
if nnz(mask) < 3
    yhat = NaN(size(x(mask)));
    p = [NaN NaN];
    pearson = NaN;
    spearman = NaN;
else
    p = polyfit(x(mask), y(mask), 1);
    yhat = polyval(p, x(mask));
    pearson = corrPair(x(mask), y(mask), 'Pearson');
    spearman = corrPair(x(mask), y(mask), 'Spearman');
end

fig = figure('Visible', 'off', 'Color', 'w', 'Name', baseName, 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');

scatter(ax, x(mask), y(mask), 70, T(mask), 'filled', ...
    'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.7);
if nnz(mask) >= 3
    [xs, ord] = sort(x(mask));
    plot(ax, xs, yhat(ord), '--', 'LineWidth', 2.0, 'Color', [0.1 0.1 0.1]);
end

xlabel(ax, 'width_I (mA)');
ylabel(ax, yLabel);
title(ax, sprintf('%s vs width_I', panelLabel));
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
cb = colorbar(ax);
colormap(ax, parula(256));
cb.Label.String = 'Temperature (K)';
text(ax, 0.04, 0.95, sprintf('Pearson = %.3f\nSpearman = %.3f', pearson, spearman), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 12, ...
    'BackgroundColor', [1 1 1], 'Margin', 5);

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildReportText(analysis, corrTbl, source, cfg)
s = analysis.summary;

lines = strings(0, 1);
lines(end+1) = '# Switching width roughness competition test';
lines(end+1) = '';
lines(end+1) = '## Scope';
lines(end+1) = '- Goal: test whether larger width_I(T) behaves like roughness/frustration/competition width rather than purely geometric width.';
lines(end+1) = '- Constraint respected: analysis uses saved run outputs only (no historical run edits, no new raw imports).';
lines(end+1) = sprintf('- Source run reused: `%s`.', source.runName);
lines(end+1) = sprintf('- Temperature window: %.1f to %.1f K.', min(analysis.perTemp.T_K), max(analysis.perTemp.T_K));
lines(end+1) = '';
lines(end+1) = '## Required checks';
lines(end+1) = sprintf('- width_I peak temperature = %.3f K.', s.width_peak_T_K);
lines(end+1) = sprintf('- Main crossover temperature (from |dI_peak/dT| max) = %.3f K.', s.crossover_T_K);
lines(end+1) = sprintf('- Peak-to-crossover offset = %.3f K.', s.delta_peak_to_crossover_K);
lines(end+1) = sprintf('- Mean width in crossover window (+/- %.1f K) / outside = %.3f.', cfg.crossoverWindowK, s.width_window_ratio);
lines(end+1) = sprintf('- Broadening fraction inside crossover window = %.3f, outside = %.3f.', ...
    s.frac_broadening_in_window, s.frac_broadening_outside_window);
lines(end+1) = '';
lines(end+1) = '## Width versus shape diagnostics';
lines(end+1) = sprintf('- corr(width_I, midpoint slope): Pearson %.3f, Spearman %.3f.', ...
    s.corr_width_vs_sharpness_pearson, s.corr_width_vs_sharpness_spearman);
lines(end+1) = sprintf('- corr(width_I, broadness = 1/|slope|): Pearson %.3f, Spearman %.3f.', ...
    s.corr_width_vs_broadness_pearson, s.corr_width_vs_broadness_spearman);
lines(end+1) = sprintf('- corr(width_I, collapse RMSE): Pearson %.3f, Spearman %.3f.', ...
    s.corr_width_vs_collapse_rmse_pearson, s.corr_width_vs_collapse_rmse_spearman);
lines(end+1) = sprintf('- corr(width_I, collapse variance): Pearson %.3f, Spearman %.3f.', ...
    s.corr_width_vs_collapse_var_pearson, s.corr_width_vs_collapse_var_spearman);
lines(end+1) = sprintf('- Global collapse variance across u-grid = %.6g.', s.global_collapse_variance);
lines(end+1) = '';
lines(end+1) = '## Correlation table usage';
lines(end+1) = '- `tables/width_roughness_correlations.csv` reports all width-vs-diagnostic associations, including asymmetry and existing half-width metrics from the source observable table.';
lines(end+1) = '';
lines(end+1) = '## Physical interpretation';
if isfinite(s.corr_width_vs_broadness_pearson) && s.corr_width_vs_broadness_pearson > 0
    lines(end+1) = '- Larger width_I is positively associated with broader normalized transitions, supporting a roughness/competition component beyond pure geometric scaling.';
else
    lines(end+1) = '- Larger width_I is not positively associated with broadness in this dataset, so width behaves mainly as a geometric scaling width in the tested range.';
end
if isfinite(s.corr_width_vs_collapse_rmse_pearson) && s.corr_width_vs_collapse_rmse_pearson > 0
    lines(end+1) = '- Larger width_I tends to worsen collapse residuals, consistent with stronger disorder/competition-induced shape variability.';
else
    lines(end+1) = '- Collapse residuals do not increase with width_I, which weakens a direct roughness interpretation from collapse quality alone.';
end
if abs(s.delta_peak_to_crossover_K) <= cfg.crossoverWindowK
    lines(end+1) = '- width_I peak is near the crossover scale, supporting crossover-linked competition broadening.';
else
    lines(end+1) = '- width_I peak is offset from the inferred crossover scale, so broadening is not centered on the main crossover marker.';
end
lines(end+1) = '- Final model interpretation should combine these width-shape tests with the existing X(T) coordinate evidence rather than replacing it.';
lines(end+1) = '';
lines(end+1) = '## Output artifacts';
lines(end+1) = '- `figures/width_I_vs_temperature.png`';
lines(end+1) = '- `figures/normalized_collapse_profiles.png`';
lines(end+1) = '- `figures/diagnostics_vs_temperature.png`';
lines(end+1) = '- `figures/width_vs_midpoint_sharpness.png`';
lines(end+1) = '- `figures/width_vs_collapse_rmse.png`';
lines(end+1) = '- `tables/width_roughness_per_temperature.csv`';
lines(end+1) = '- `tables/width_roughness_correlations.csv`';
lines(end+1) = '- `tables/width_roughness_summary.csv`';
lines(end+1) = '- `reports/switching_width_roughness_competition_report.md`';
lines(end+1) = '- `review/switching_width_roughness_competition_bundle.zip`';
lines(end+1) = '';
lines(end+1) = '## Visualization choices';
lines(end+1) = '- number of curves: 2 to 4 curves per line panel; >6 profile curves in collapse panel.';
lines(end+1) = '- legend vs colormap: legends for <=6 curves; colormap + colorbar for multi-temperature collapse panel.';
lines(end+1) = '- colormap used: parula.';
lines(end+1) = '- smoothing applied: 3-point moving mean on width_I(T) and I_peak(T) only for derivative/crossover diagnostics.';
lines(end+1) = '- justification: direct visibility of broadening, sharpness, and collapse-quality links against width_I(T).';

reportText = strjoin(lines, newline);
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);

cand = { ...
    fullfile(runDir, 'reports', 'switching_width_roughness_competition_report.md'), ...
    fullfile(runDir, 'tables', 'width_roughness_per_temperature.csv'), ...
    fullfile(runDir, 'tables', 'width_roughness_correlations.csv'), ...
    fullfile(runDir, 'tables', 'width_roughness_summary.csv'), ...
    fullfile(runDir, 'tables', 'source_run_manifest.csv'), ...
    fullfile(runDir, 'figures', 'width_I_vs_temperature.png'), ...
    fullfile(runDir, 'figures', 'normalized_collapse_profiles.png'), ...
    fullfile(runDir, 'figures', 'diagnostics_vs_temperature.png'), ...
    fullfile(runDir, 'figures', 'width_vs_midpoint_sharpness.png'), ...
    fullfile(runDir, 'figures', 'width_vs_collapse_rmse.png')};

files = {};
for i = 1:numel(cand)
    if exist(cand{i}, 'file') == 2
        files{end+1} = cand{i}; %#ok<AGROW>
    end
end

if exist(zipPath, 'file') == 2
    delete(zipPath);
end
if ~isempty(files)
    zip(zipPath, files, runDir);
end
end

function c = corrPair(x, y, typeName)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    c = NaN;
    return;
end
c = corr(x(mask), y(mask), 'Type', typeName, 'Rows', 'complete');
end

function y = normalize01(x)
y = NaN(size(x));
mask = isfinite(x);
if nnz(mask) < 1
    return;
end
xmin = min(x(mask));
xmax = max(x(mask));
if xmax <= xmin
    y(mask) = 0;
    return;
end
y(mask) = (x(mask) - xmin) ./ (xmax - xmin);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
clean = strrep(txt, sprintf('\r\n'), sprintf('\n'));
fprintf(fid, '%s', clean);
if ~endsWith(clean, newline)
    fprintf(fid, '\n');
end
fclose(fid);
end

function s = stampNow()
s = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
