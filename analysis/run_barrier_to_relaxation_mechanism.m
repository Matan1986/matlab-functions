function out = run_barrier_to_relaxation_mechanism(cfg)
%RUN_BARRIER_TO_RELAXATION_MECHANISM
% Mechanism test: P_T(I) barrier-distribution descriptors vs Relaxation A(T)
% and Aging clock ratio R(T). Reuses saved runs only (no duplicate pipelines).

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

cfg = applyDefaults(cfg);
source = resolveSources(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('pt:%s | relax:%s | aging:%s | switch:%s', ...
    source.ptRunName, source.relaxRunName, source.agingRunName, source.switchRunName);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
ensureRunSubdirs(runDir);

fprintf('Barrier-to-relaxation mechanism run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_barrier_to_relaxation_mechanism started\n', stampNow()));
appendText(run.log_path, sprintf('PT source: %s\n', char(source.ptRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Aging clock source: %s\n', char(source.agingRunName)));
appendText(run.log_path, sprintf('Switching observables: %s\n', char(source.switchRunName)));

[ptT, I_mA, Pmat] = loadPTMatrix(source.ptMatrixPath);
descTbl = buildBarrierDescriptorTable(ptT, I_mA, Pmat);
relax = loadRelaxationSeries(source.relaxTempPath);
aging = loadAgingRatioSeries(source.agingClockPath);
switchObs = loadSwitchingPeaks(source.switchMatrixPath);
[Tcanon, Xcanon] = get_canonical_X('repoRoot', repoRoot, 'runName', char(cfg.canonicalXRunName));

aligned = alignOnTemperatureGrid(descTbl, relax, aging, switchObs, Tcanon, Xcanon, cfg);

mergedDesc = aligned.descriptorTable;
mergedDesc.A_T_interp = aligned.A;
mergedDesc.R_T_interp = aligned.R;
mergedDesc.X_T_interp = aligned.X;
mergedDesc.I_peak_mA = aligned.I_peak_mA;
mergedDesc.S_peak = aligned.S_peak;

descPath = save_run_table(mergedDesc, 'barrier_descriptors.csv', runDir);
manifestPath = save_run_table(source.manifestTbl, 'source_run_manifest.csv', runDir);

[metricsA, metricsR, featImp] = evaluatePredictions(aligned, cfg);
pathA = save_run_table(metricsA, 'A_prediction_metrics.csv', runDir);
pathR = save_run_table(metricsR, 'R_prediction_metrics.csv', runDir);
pathImp = save_run_table(featImp, 'feature_importance_summary.csv', runDir);

fig1 = saveFigATopDescriptors(aligned, runDir);
fig2 = saveFigRTopDescriptors(aligned, runDir);
fig3 = saveFigAvsXComparison(aligned, metricsA, runDir);
fig4 = saveFigPredictionResiduals(aligned, metricsA, metricsR, runDir);
fig5 = saveFigDescriptorsVsT(aligned, runDir);

reportText = buildMechanismReport(source, aligned, metricsA, metricsR, featImp, cfg, thisFile);
reportPath = save_run_report(reportText, 'barrier_to_relaxation_mechanism_report.md', runDir);
zipPath = buildReviewZip(runDir, 'barrier_to_relaxation_mechanism_bundle.zip');

appendText(run.log_path, sprintf('[%s] complete\n', stampNow()));
appendText(run.log_path, sprintf('Descriptors: %s\n', descPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.tables = struct('descriptors', string(descPath), 'metricsA', string(pathA), ...
    'metricsR', string(pathR), 'importance', string(pathImp), 'manifest', string(manifestPath));
out.figures = struct('A_descriptors', string(fig1.png), 'R_descriptors', string(fig2.png), ...
    'A_vs_X', string(fig3.png), 'residuals', string(fig4.png), 'descriptors_vs_T', string(fig5.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== run_barrier_to_relaxation_mechanism complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
end

%% ------------------------------------------------------------------------
function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'barrier_to_relaxation_mechanism');
cfg = setDefaultField(cfg, 'ptLabelHint', 'pt_robust');
cfg = setDefaultField(cfg, 'relaxLabelHint', 'relaxation_observable');
cfg = setDefaultField(cfg, 'agingLabelHint', 'aging_clock_ratio');
cfg = setDefaultField(cfg, 'switchLabelHint', 'alignment_audit');
cfg = setDefaultField(cfg, 'canonicalXRunName', 'run_2026_03_22_013049_x_observable_export_corrected');
cfg = setDefaultField(cfg, 'ridgeLambda', 1e-6);
cfg = setDefaultField(cfg, 'maxMultiFeatures', 4);
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
end

function source = resolveSources(repoRoot, cfg)
source = struct();

[ptDir, ptName] = findLatestRunWithFiles(repoRoot, 'switching', ...
    {'tables\PT_matrix.csv'}, cfg.ptLabelHint);
source.ptRunDir = ptDir;
source.ptRunName = ptName;
source.ptMatrixPath = fullfile(char(ptDir), 'tables', 'PT_matrix.csv');

[rxDir, rxName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\temperature_observables.csv', 'tables\observables_relaxation.csv'}, cfg.relaxLabelHint);
source.relaxRunDir = rxDir;
source.relaxRunName = rxName;
source.relaxTempPath = fullfile(char(rxDir), 'tables', 'temperature_observables.csv');

[agDir, agName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\table_clock_ratio.csv'}, cfg.agingLabelHint);
source.agingRunDir = agDir;
source.agingRunName = agName;
source.agingClockPath = fullfile(char(agDir), 'tables', 'table_clock_ratio.csv');

[swDir, swName] = findLatestRunWithFiles(repoRoot, 'switching', ...
    {'observable_matrix.csv', 'switching_alignment_core_data.mat'}, cfg.switchLabelHint);
source.switchRunDir = swDir;
source.switchRunName = swName;
source.switchMatrixPath = fullfile(char(swDir), 'observable_matrix.csv');

alignedOptional = findOptionalAlignedTable(repoRoot);
source.optionalAlignedPath = alignedOptional;

source.manifestTbl = table( ...
    ["pt_matrix"; "relaxation"; "aging_clock"; "switching_observables"; "canonical_X"; "optional_aligned"], ...
    [string(source.ptRunName); string(source.relaxRunName); string(source.agingRunName); ...
    string(source.switchRunName); string(cfg.canonicalXRunName); ternary(strlength(alignedOptional) > 0, alignedOptional, "none")], ...
    'VariableNames', {'role', 'run_id_or_path'});
end

function p = findOptionalAlignedTable(repoRoot)
p = "";
pattern = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', 'run_*', 'tables', '*aligned*.csv');
files = dir(pattern);
if isempty(files)
    return;
end
[~, ord] = sort({files.name});
files = files(ord);
% Prefer AX_aligned_data if present
for k = 1:numel(files)
    fk = fullfile(files(k).folder, files(k).name);
    if contains(lower(files(k).name), 'ax_aligned')
        p = string(fk);
        return;
    end
end
p = string(fullfile(files(end).folder, files(end).name));
end

function ensureRunSubdirs(runDir)
sub = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(sub)
    d = fullfile(runDir, sub{i});
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
end

function [T_K, I_mA, P] = loadPTMatrix(pathStr)
raw = readtable(pathStr, 'VariableNamingRule', 'preserve');
T_K = double(raw.(raw.Properties.VariableNames{1}));
varNames = raw.Properties.VariableNames(2:end);
nI = numel(varNames);
I_mA = nan(1, nI);
for j = 1:nI
    I_mA(j) = parseCurrentHeader(varNames{j});
end
P = nan(numel(T_K), nI);
for j = 1:nI
    P(:, j) = double(raw.(varNames{j}));
end
end

function iMa = parseCurrentHeader(h)
s = lower(string(h));
tok = regexp(s, '(\d+\.?\d*)', 'once', 'match');
if isempty(tok)
    iMa = NaN;
else
    iMa = str2double(tok);
end
end

function descTbl = buildBarrierDescriptorTable(T_K, I_mA, Pmat)
nT = numel(T_K);
nI = numel(I_mA);
Pcent = nan(nT, nI);
validRow = false(nT, 1);
muRow = nan(nT, 1);
for i = 1:nT
    p = Pmat(i, :);
    p = fillmissing(p(:)', 'constant', 0);
    s = sum(p);
    if s > 0
        p = p / s;
    else
        p = nan(1, nI);
    end
    Pcent(i, :) = p;
    validRow(i) = s > 0 && sum(isfinite(p)) >= 3;
    if validRow(i)
        muRow(i) = sum(p .* I_mA, 'omitnan');
    end
end

muGlobal = mean(muRow(validRow), 'omitnan');
v1 = nan(nI, 1);
v2 = nan(nI, 1);
vr = validRow(:);
if sum(vr) >= 2
    Psub = Pcent(vr, :) - mean(Pcent(vr, :), 1);
    [~, ~, V] = svd(Psub, 'econ');
    v1 = V(:, 1);
    if size(V, 2) >= 2
        v2 = V(:, 2);
    end
end

rows = cell(nT, 1);
for i = 1:nT
    rows{i} = computeOneRowDescriptors(T_K(i), I_mA, Pcent(i, :), validRow(i), v1, v2, muGlobal);
end
descTbl = vertcat(rows{:});
end

function row = computeOneRowDescriptors(Tk, I_mA, p, ok, v1, v2, muGlobal)
z = (I_mA - min(I_mA)) ./ max(eps, (max(I_mA) - min(I_mA)));
z = 2 * z - 1;
z = max(-1, min(1, z));

row = table();
row.T_K = Tk;
row.row_valid = ok;

if ~ok
    fn = {'mean_I_mA','median_I_mA','mode_I_mA','q10_I_mA','q25_I_mA','q50_I_mA','q75_I_mA','q90_I_mA', ...
        'iq75_25_mA','iq90_10_mA','asym_q75_50_minus_q50_25','tail_ratio_high_over_low', ...
        'cheb_m2_z','cheb_m4_z','moment_I2_weighted','pt_svd_score1','pt_svd_score2', ...
        'skewness_quantile','mass_upper_half'};
    for k = 1:numel(fn)
        row.(fn{k}) = NaN;
    end
    return;
end

p = p(:)';
w = p / sum(p);
I = I_mA(:)';

row.mean_I_mA = sum(w .* I);
row.median_I_mA = weightedQuantile(I, w, 0.5);
row.mode_I_mA = I(p == max(p));
row.mode_I_mA = row.mode_I_mA(1);

row.q10_I_mA = weightedQuantile(I, w, 0.10);
row.q25_I_mA = weightedQuantile(I, w, 0.25);
row.q50_I_mA = weightedQuantile(I, w, 0.50);
row.q75_I_mA = weightedQuantile(I, w, 0.75);
row.q90_I_mA = weightedQuantile(I, w, 0.90);

row.iq75_25_mA = row.q75_I_mA - row.q25_I_mA;
row.iq90_10_mA = row.q90_I_mA - row.q10_I_mA;
row.asym_q75_50_minus_q50_25 = (row.q75_I_mA - row.q50_I_mA) - (row.q50_I_mA - row.q25_I_mA);
denLow = max(eps, row.q50_I_mA - row.q10_I_mA);
denHigh = max(eps, row.q90_I_mA - row.q50_I_mA);
row.tail_ratio_high_over_low = denHigh / denLow;
row.skewness_quantile = row.asym_q75_50_minus_q50_25 / max(eps, row.iq75_25_mA);

row.cheb_m2_z = sum(w .* z.^2);
row.cheb_m4_z = sum(w .* z.^4);
row.moment_I2_weighted = sum(w .* I.^2);

pc = p(:);
if all(isfinite(v1)) && numel(v1) == numel(pc)
    row.pt_svd_score1 = dot(pc - mean(pc), v1);
else
    row.pt_svd_score1 = NaN;
end
if all(isfinite(v2)) && numel(v2) == numel(pc)
    row.pt_svd_score2 = dot(pc - mean(pc), v2);
else
    row.pt_svd_score2 = NaN;
end

med = row.median_I_mA;
row.mass_upper_half = sum(w(I >= med));
end

function q = weightedQuantile(I, w, alpha)
I = I(:);
w = w(:);
w = w / sum(w);
[sI, ord] = sort(I);
sw = w(ord);
cdf = cumsum(sw);
if alpha <= cdf(1)
    q = sI(1);
    return;
end
if alpha >= cdf(end)
    q = sI(end);
    return;
end
k = find(cdf >= alpha, 1, 'first');
if k == 1
    q = sI(1);
    return;
end
c0 = cdf(k - 1);
c1 = cdf(k);
t = (alpha - c0) / max(eps, (c1 - c0));
q = sI(k - 1) + t * (sI(k) - sI(k - 1));
end

function relax = loadRelaxationSeries(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'T', 'T_K', 'temperature'});
acol = firstMatchingName(tbl.Properties.VariableNames, {'A_T', 'A', 'Relax_tau_T'});
relax.T = double(tbl.(tcol)(:));
relax.A = double(tbl.(acol)(:));
end

function aging = loadAgingRatioSeries(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'Tp', 'T_K', 'T', 'temperature'});
rcol = firstMatchingName(tbl.Properties.VariableNames, {'R_tau_FM_over_tau_dip', 'R', 'ratio'});
aging.T = double(tbl.(tcol)(:));
aging.R = double(tbl.(rcol)(:));
end

function sw = loadSwitchingPeaks(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'T', 'T_K', 'temperature'});
sw.T = double(tbl.(tcol)(:));
sw.I_peak = double(tbl.I_peak(:));
sw.S_peak = double(tbl.S_peak(:));
end

function aligned = alignOnTemperatureGrid(descTbl, relax, aging, switchObs, TX, XX, cfg)
T = descTbl.T_K(:);
mask = descTbl.row_valid & isfinite(T);
T = T(mask);
descTbl = descTbl(mask, :);

A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
R = interp1(aging.T, aging.R, T, cfg.interpMethod, NaN);
Ipeak = interp1(switchObs.T, switchObs.I_peak, T, cfg.interpMethod, NaN);
Speak = interp1(switchObs.T, switchObs.S_peak, T, cfg.interpMethod, NaN);
Xx = interp1(TX, XX, T, cfg.interpMethod, NaN);

use = isfinite(A) & isfinite(R) & isfinite(Xx) & isfinite(Ipeak) & isfinite(Speak);
for k = 1:width(descTbl)
    vn = descTbl.Properties.VariableNames{k};
    if vn == "T_K" || vn == "row_valid"
        continue;
    end
    use = use & isfinite(descTbl.(vn)(:));
end

aligned = struct();
aligned.T_K = T(use);
aligned.descriptorTable = descTbl(use, :);
aligned.A = A(use);
aligned.R = R(use);
aligned.I_peak_mA = Ipeak(use);
aligned.S_peak = Speak(use);
aligned.X = Xx(use);
aligned.n = numel(aligned.T_K);
end

function [metricsA, metricsR, featImp] = evaluatePredictions(aligned, cfg)
predNames = aligned.descriptorTable.Properties.VariableNames;
drop = ismember(predNames, {'T_K', 'row_valid'});
predNames = predNames(~drop);

if isempty(predNames)
    error('No descriptor columns available after excluding T_K / row_valid.');
end

rowsA = scoreOne(predNames{1}, aligned.A, aligned.descriptorTable.(predNames{1})(:));
rowsR = scoreOne(predNames{1}, aligned.R, aligned.descriptorTable.(predNames{1})(:));
for k = 2:numel(predNames)
    name = predNames{k};
    x = aligned.descriptorTable.(name)(:);
    rowsA = [rowsA; scoreOne(name, aligned.A, x)]; %#ok<AGROW>
    rowsR = [rowsR; scoreOne(name, aligned.R, x)]; %#ok<AGROW>
end

rowsA = [rowsA; scoreOne('baseline_X', aligned.A, aligned.X)];
rowsR = [rowsR; scoreOne('baseline_X', aligned.R, aligned.X)];
rowsA = [rowsA; scoreOne('baseline_I_peak', aligned.A, aligned.I_peak_mA)];
rowsR = [rowsR; scoreOne('baseline_I_peak', aligned.R, aligned.I_peak_mA)];

% Low-dimensional combined models (no width)
Xmat = table2array(aligned.descriptorTable(:, predNames));
Xmat = double(Xmat);
multiA = appendMultiMetrics(rowsA, 'A', aligned.A, Xmat, predNames, aligned.X, cfg);
multiR = appendMultiMetrics(rowsR, 'R', aligned.R, Xmat, predNames, aligned.X, cfg);
if isempty(multiA)
    metricsA = struct2table(rowsA);
else
    metricsA = struct2table([rowsA; multiA(:)]);
end
if isempty(multiR)
    metricsR = struct2table(rowsR);
else
    metricsR = struct2table([rowsR; multiR(:)]);
end

featImp = buildFeatureImportanceSummary(metricsA, metricsR, predNames);
end

function row = scoreOne(feature, y, x)
row = struct();
row.feature = string(feature);
mask = isfinite(y) & isfinite(x);
row.n = sum(mask);
yy = y(mask);
xx = x(mask);
row.pearson_r = pearsonSafe(yy, xx);
row.spearman_r = spearmanSafe(yy, xx);
if row.n >= 3 && std(xx) > eps && std(yy) > eps
    b = [ones(row.n, 1), xx] \ yy;
    yhat = b(1) + b(2) * xx;
    row.rmse_linear = sqrt(mean((yy - yhat).^2));
    row.r2_linear = r2safe(yy, yhat);
else
    row.rmse_linear = NaN;
    row.r2_linear = NaN;
end
row.monotonicity_abs_spearman = abs(row.spearman_r);
end

function multiRows = appendMultiMetrics(rows, targetName, y, Xmat, predNames, baselineX, cfg)
multiRows = [];
mask = isfinite(y) & all(isfinite(Xmat), 2);
yy = y(mask);
XX = Xmat(mask, :);
bx = baselineX(mask);
if numel(yy) < 5
    return;
end

% Rank single-feature |Spearman| to pick low-dim set
Ttbl = struct2table(rows);
Ttbl = Ttbl(ismember(string(Ttbl.feature), string(predNames)), :);
if height(Ttbl) < 1
    return;
end
[~, ord] = sort(abs(Ttbl.spearman_r), 'descend');
nPick = min(cfg.maxMultiFeatures, numel(ord));
idx = ord(1:nPick);
Xsub = XX(:, idx);

bOLS = [ones(size(Xsub, 1), 1), Xsub] \ yy;
yhatOLS = [ones(size(Xsub, 1), 1), Xsub] * bOLS;
mr = struct();
mr.feature = string(sprintf('multi_ols_top%d_%s', nPick, targetName));
mr.n = numel(yy);
mr.pearson_r = pearsonSafe(yy, yhatOLS);
mr.spearman_r = spearmanSafe(yy, yhatOLS);
mr.rmse_linear = sqrt(mean((yy - yhatOLS).^2));
mr.r2_linear = r2safe(yy, yhatOLS);
mr.monotonicity_abs_spearman = abs(mr.spearman_r);
multiRows = mr;

Xn = (Xsub - mean(Xsub, 1)) ./ max(std(Xsub, 0, 1), eps);
lambda = cfg.ridgeLambda;
d = size(Xn, 2);
bR = (Xn' * Xn + lambda * eye(d)) \ (Xn' * (yy - mean(yy)));
yhatR = mean(yy) + Xn * bR;
mr2 = struct();
mr2.feature = string(sprintf('multi_ridge_top%d_%s', nPick, targetName));
mr2.n = numel(yy);
mr2.pearson_r = pearsonSafe(yy, yhatR);
mr2.spearman_r = spearmanSafe(yy, yhatR);
mr2.rmse_linear = sqrt(mean((yy - yhatR).^2));
mr2.r2_linear = r2safe(yy, yhatR);
mr2.monotonicity_abs_spearman = abs(mr2.spearman_r);
multiRows = [multiRows; mr2];

% X + top-1 barrier descriptor (compression test)
[~, ord2] = sort(abs(Ttbl.spearman_r), 'descend');
x1 = XX(:, ord2(1));
Xc = [bx, x1];
if all(isfinite(Xc(:)))
    bc = [ones(size(Xc, 1), 1), Xc] \ yy;
    yhatC = [ones(size(Xc, 1), 1), Xc] * bc;
    mr3 = struct();
    mr3.feature = "combo_X_plus_top_barrier_" + string(predNames(ord2(1)));
    mr3.n = numel(yy);
    mr3.pearson_r = pearsonSafe(yy, yhatC);
    mr3.spearman_r = spearmanSafe(yy, yhatC);
    mr3.rmse_linear = sqrt(mean((yy - yhatC).^2));
    mr3.r2_linear = r2safe(yy, yhatC);
    mr3.monotonicity_abs_spearman = abs(mr3.spearman_r);
    multiRows = [multiRows; mr3];
end
end

function tbl = buildFeatureImportanceSummary(metricsA, metricsR, predNames)
tbl = table(string(predNames(:)), 'VariableNames', {'descriptor'});
n = height(tbl);
tbl.A_abs_spearman = nan(n, 1);
tbl.R_abs_spearman = nan(n, 1);
for i = 1:n
    d = tbl.descriptor(i);
    ia = metricsA.feature == d;
    ir = metricsR.feature == d;
    if any(ia)
        tbl.A_abs_spearman(i) = abs(metricsA.spearman_r(find(ia, 1)));
    end
    if any(ir)
        tbl.R_abs_spearman(i) = abs(metricsR.spearman_r(find(ir, 1)));
    end
end
tbl.mean_abs_spearman = mean([tbl.A_abs_spearman, tbl.R_abs_spearman], 2, 'omitnan');
end

function figPaths = saveFigATopDescriptors(aligned, runDir)
featImp = aligned.descriptorTable.Properties.VariableNames;
featImp = featImp(~ismember(featImp, {'T_K', 'row_valid'}));
scores = zeros(numel(featImp), 1);
for k = 1:numel(featImp)
    scores(k) = abs(spearmanSafe(aligned.A, aligned.descriptorTable.(featImp{k})(:)));
end
[~, ord] = sort(scores, 'descend');
pick = ord(1:min(4, numel(ord)));

base_name = 'barrier_A_vs_top_descriptors';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 16 12]);
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:numel(pick)
    nexttile;
    name = featImp{pick(i)};
    x = aligned.descriptorTable.(name)(:);
    scatter(x, aligned.A, 36, aligned.T_K, 'filled');
    colormap(gca, parula);
    cb = colorbar;
    cb.Label.String = 'T (K)';
    xlabel(sprintf('%s', prettyLabel(name)), 'FontSize', 14);
    ylabel('A(T)', 'FontSize', 14);
    set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
end
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveFigRTopDescriptors(aligned, runDir)
featImp = aligned.descriptorTable.Properties.VariableNames;
featImp = featImp(~ismember(featImp, {'T_K', 'row_valid'}));
scores = zeros(numel(featImp), 1);
for k = 1:numel(featImp)
    scores(k) = abs(spearmanSafe(aligned.R, aligned.descriptorTable.(featImp{k})(:)));
end
[~, ord] = sort(scores, 'descend');
pick = ord(1:min(4, numel(ord)));

base_name = 'barrier_R_vs_top_descriptors';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 16 12]);
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:numel(pick)
    nexttile;
    name = featImp{pick(i)};
    x = aligned.descriptorTable.(name)(:);
    scatter(x, aligned.R, 36, aligned.T_K, 'filled');
    colormap(gca, parula);
    cb = colorbar;
    cb.Label.String = 'T (K)';
    xlabel(sprintf('%s', prettyLabel(name)), 'FontSize', 14);
    ylabel('R(T)', 'FontSize', 14);
    set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
end
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveFigAvsXComparison(aligned, metricsA, runDir)
base_name = 'barrier_A_vs_X_and_best_descriptor';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 14 6]);
tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
scatter(aligned.X, aligned.A, 48, aligned.T_K, 'filled');
colormap(gca, parula);
colorbar;
xlabel('X(T)', 'FontSize', 14);
ylabel('A(T)', 'FontSize', 14);
title('A vs baseline X(T)', 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

predNames = aligned.descriptorTable.Properties.VariableNames;
predNames = predNames(~ismember(predNames, {'T_K', 'row_valid'}));
bestName = predNames{1};
bestAbs = -1;
for k = 1:numel(predNames)
    row = metricsA(strcmp(string(metricsA.feature), string(predNames{k})), :);
    if isempty(row)
        continue;
    end
    v = abs(row.spearman_r(1));
    if v > bestAbs
        bestAbs = v;
        bestName = predNames{k};
    end
end

nexttile;
xb = aligned.descriptorTable.(bestName)(:);
scatter(xb, aligned.A, 48, aligned.T_K, 'filled');
colormap(gca, parula);
colorbar;
xlabel(prettyLabel(bestName), 'FontSize', 14);
ylabel('A(T)', 'FontSize', 14);
title(sprintf('A vs best P_T descriptor (%s)', bestName), 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveFigPredictionResiduals(aligned, metricsA, metricsR, runDir)
base_name = 'barrier_prediction_residuals_vs_T';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 14 10]);
tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

% A: best single descriptor linear fit
predNames = aligned.descriptorTable.Properties.VariableNames;
predNames = predNames(~ismember(predNames, {'T_K', 'row_valid'}));
subA = metricsA(ismember(metricsA.feature, predNames), :);
[~, ia] = max(abs(subA.spearman_r));
featA = char(subA.feature(ia));
xA = aligned.descriptorTable.(featA)(:);
bA = [ones(aligned.n, 1), xA] \ aligned.A;
resA = aligned.A - (bA(1) + bA(2) * xA);

nexttile;
plot(aligned.T_K, resA, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.45 0.7]);
xlabel('T (K)', 'FontSize', 14);
ylabel(sprintf('Residual A (fit: %s)', featA), 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

subR = metricsR(ismember(metricsR.feature, predNames), :);
[~, ir] = max(abs(subR.spearman_r));
featR = char(subR.feature(ir));
xR = aligned.descriptorTable.(featR)(:);
bR = [ones(aligned.n, 1), xR] \ aligned.R;
resR = aligned.R - (bR(1) + bR(2) * xR);

nexttile;
plot(aligned.T_K, resR, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.65 0.35 0.2]);
xlabel('T (K)', 'FontSize', 14);
ylabel(sprintf('Residual R (fit: %s)', featR), 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveFigDescriptorsVsT(aligned, runDir)
predNames = aligned.descriptorTable.Properties.VariableNames;
predNames = predNames(~ismember(predNames, {'T_K', 'row_valid'}));
n = min(6, numel(predNames));

base_name = 'barrier_descriptors_vs_temperature';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 14 10]);
hold on;
cols = lines(n);
for k = 1:n
    y = aligned.descriptorTable.(predNames{k})(:);
    y = (y - mean(y)) ./ max(std(y, 0), eps);
    plot(aligned.T_K, y, 'o-', 'Color', cols(k, :), 'LineWidth', 2, 'DisplayName', prettyLabel(predNames{k}));
end
xlabel('T (K)', 'FontSize', 14);
ylabel('z-scored descriptor', 'FontSize', 14);
legend('Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
hold off;
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function s = prettyLabel(name)
s = strrep(name, '_', ' ');
end

function txt = buildMechanismReport(source, aligned, metricsA, metricsR, featImp, cfg, thisFile)
lines = strings(0, 1);
lines(end + 1) = "# Barrier landscape to relaxation / aging — mechanism test";
lines(end + 1) = "";
lines(end + 1) = "## 1. Question";
lines(end + 1) = "Can **P_T(I)**-derived shape descriptors quantitatively explain **Relaxation A(T)** and **Aging clock ratio R(T)** on a shared temperature grid, and how do they compare to **X(T)**?";
lines(end + 1) = "";
lines(end + 1) = "## 2. Descriptor construction (robust, width not primary)";
lines(end + 1) = "- **Location**: weighted mean / median / mode of current axis using normalized row of `PT_matrix`.";
lines(end + 1) = "- **Quantiles**: q10–q90 with linear interpolation on the cumulative mass; spans iq75−25, iq90−10.";
lines(end + 1) = "- **Asymmetry**: (q75−q50)−(q50−q25), skewness_quantile = asym / iq75−25, tail_ratio (high/low tail lengths).";
lines(end + 1) = "- **Shape moments**: z maps I to [−1,1] on the fixed grid; report cheb_m2_z, cheb_m4_z; **moment_I2_weighted** is the consistent I² energy proxy (alongside mean_I_mA as I-linear proxy).";
lines(end + 1) = "- **Low-rank**: each row projected onto the first two right singular vectors of **row-valid** P_T after removing the global mean (scores `pt_svd_score1/2`).";
lines(end + 1) = "- **width_I** from switching ridge fits is **not** used as a predictor.";
lines(end + 1) = "";
lines(end + 1) = "## 3. Data alignment";
lines(end + 1) = sprintf("- Master grid: **T_K** from `%s` (`PT_matrix`).", source.ptRunName);
lines(end + 1) = sprintf("- Interpolation onto that grid: `A` from `%s`, `R` from `%s`, `I_peak`/`S_peak` from `%s`, `X` from canonical run `%s`.", ...
    source.relaxRunName, source.agingRunName, source.switchRunName, cfg.canonicalXRunName);
lines(end + 1) = sprintf("- Valid aligned samples: **n = %d**.", aligned.n);
if strlength(source.optionalAlignedPath) > 0
    lines(end + 1) = sprintf("- Optional aligned table found: `%s` (not required for this run).", source.optionalAlignedPath);
end
lines(end + 1) = "";
lines(end + 1) = "## 4. Results";
lines(end + 1) = "### A(T) — correlations and baselines";
lines = [lines; splitlines(formatMetricsBlock(metricsA))];
lines(end + 1) = "### R(T) — correlations and baselines";
lines = [lines; splitlines(formatMetricsBlock(metricsR))];
lines(end + 1) = "### Descriptor ranking (mean |Spearman| across A and R)";
lines = [lines; splitlines(formatTableMarkdown(featImp))];
lines(end + 1) = "";
lines(end + 1) = "## 5. Interpretation";
[verdict, notes] = mechanismVerdict(metricsA, metricsR, featImp, aligned.n);
lines = [lines; notes(:)];
lines(end + 1) = "";
lines(end + 1) = "## 6. Conclusion";
lines(end + 1) = verdict;
lines(end + 1) = "";
lines(end + 1) = "## Provenance";
lines(end + 1) = sprintf("- Script: `%s`", thisFile);
lines(end + 1) = "- Outputs: `tables/barrier_descriptors.csv` (includes aligned `A_T_interp`, `R_T_interp`, `X_T_interp`, `I_peak_mA`, `S_peak`), `A_prediction_metrics.csv`, `R_prediction_metrics.csv`, `feature_importance_summary.csv`, figures under `figures/`.";
txt = join(lines, newline);
end

function block = formatMetricsBlock(T)
block = "";
for i = 1:height(T)
    block = block + sprintf("- **%s**: n=%d, Pearson=%.4f, Spearman=%.4f, RMSE_lin=%.4g, R2_lin=%.4f, |Spearman| (mono proxy)=%.4f\n", ...
        char(T.feature(i)), T.n(i), T.pearson_r(i), T.spearman_r(i), T.rmse_linear(i), T.r2_linear(i), T.monotonicity_abs_spearman(i));
end
end

function md = formatTableMarkdown(T)
md = "";
vars = T.Properties.VariableNames;
md = md + "| " + strjoin(string(vars), " | ") + " |\n";
md = md + "|" + repmat(" --- |", 1, numel(vars)) + "\n";
for i = 1:height(T)
    row = strings(1, numel(vars));
    for j = 1:numel(vars)
        v = T{i, j};
        if isnumeric(v)
            row(j) = sprintf('%.4g', v);
        else
            row(j) = string(v);
        end
    end
    md = md + "| " + strjoin(row, " | ") + " |\n";
end
end

function [verdict, notes] = mechanismVerdict(metricsA, metricsR, featImp, n)
notes = strings(0, 1);
pred = featImp.descriptor;
mA = metricsA(ismember(metricsA.feature, pred), :);
mR = metricsR(ismember(metricsR.feature, pred), :);
bestA = max(abs(mA.spearman_r), [], 'omitnan');
bestR = max(abs(mR.spearman_r), [], 'omitnan');
baseA = metricsA(metricsA.feature == "baseline_X", :);
baseR = metricsR(metricsR.feature == "baseline_X", :);
sxA = NaN;
sxR = NaN;
if ~isempty(baseA)
    sxA = abs(baseA.spearman_r(1));
end
if ~isempty(baseR)
    sxR = abs(baseR.spearman_r(1));
end
notes(end + 1) = sprintf("- Best |Spearman| (A) among P_T descriptors: **%.3f**; baseline X: **%.3f**.", bestA, sxA);
notes(end + 1) = sprintf("- Best |Spearman| (R) among P_T descriptors: **%.3f**; baseline X: **%.3f**.", bestR, sxR);

strong = bestA >= 0.8 && bestR >= 0.8 && n >= 8;
partial = (bestA >= 0.5 || bestR >= 0.5) && n >= 5;

if strong
    verdict = "**✅ Mechanism supported** (descriptive): a small P_T shape family tracks both A and R with |Spearman| ≥ 0.8 at n ≥ 8. Treat as consistency check, not a unique causal identification.";
elseif partial
    verdict = "**⚠️ Partial**: some P_T descriptors align with A and/or R, but correlations are moderate or sample-limited. X may still compress overlapping information.";
else
    verdict = "**❌ Not supported** at the stated strong threshold: P_T descriptors do not reach |Spearman| ≥ 0.8 for both A and R on this aligned subset.";
end
end

function r = pearsonSafe(x, y)
x = x(:);
y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 2
    r = NaN;
    return;
end
r = corr(x(m), y(m), 'rows', 'complete', 'type', 'Pearson');
end

function r = spearmanSafe(x, y)
x = x(:);
y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 3
    r = NaN;
    return;
end
r = corr(x(m), y(m), 'rows', 'complete', 'type', 'Spearman');
end

function r2 = r2safe(y, yhat)
m = isfinite(y) & isfinite(yhat);
if sum(m) < 2
    r2 = NaN;
    return;
end
yy = y(m);
yh = yhat(m);
ssRes = sum((yy - yh).^2);
ssTot = sum((yy - mean(yy)).^2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function name = firstMatchingName(names, candidates)
for i = 1:numel(candidates)
    if any(strcmp(names, candidates{i}))
        name = candidates{i};
        return;
    end
end
error('No matching column in table (candidates: %s).', strjoin(candidates, ', '));
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No %s run matched label hint "%s" with required files.', experiment, labelHint);
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

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
