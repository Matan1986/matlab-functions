function out = run_tail_ablation_test(cfg)
% run_tail_ablation_test
% Tail ablation audit: test whether high-barrier PT tail controls kappa and R.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingDir = fileparts(analysisDir);
repoRoot = fileparts(switchingDir);

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);

runCfg = struct();
runCfg.runLabel = 'tail_ablation_test';
runCfg.dataset = 'derived:PT-kappa-R';
run = createSwitchingRunContext(repoRoot, runCfg);
runDir = run.run_dir;
ensureArtifactDirs(runDir);

[Tpt, I, PT] = loadPTMatrixLocal(cfg.ptMatrixPath);
[Tk, kappa] = loadKappaLocal(cfg.kappaPath);
[Tr, R] = loadRLocal(cfg.rPath);

Tcommon = intersect(intersect(Tpt(:), Tk(:), 'stable'), Tr(:), 'stable');
Tcommon = Tcommon(isfinite(Tcommon));
nT = numel(Tcommon);
if nT < 5
    error('run_tail_ablation_test:TooFewPoints', 'Need at least 5 common temperatures.');
end

variants = {'original', 'remove_top5', 'remove_top10', 'cap_tail'};
nV = numel(variants);
obsRows = table();

for vi = 1:nV
    key = variants{vi};
    for ti = 1:nT
        t = Tcommon(ti);
        [~, ip] = ismember(t, Tpt);
        p0 = PT(ip, :).';
        p1 = modifyTailVariant(I, p0, key, cfg);
        obs = computePTObservables(I, p1);
        obsRows = [obsRows; table( ...
            string(key), t, obs.q10_mA, obs.q25_mA, obs.q50_mA, obs.q75_mA, obs.q90_mA, ...
            obs.iq75_25_mA, obs.iq90_10_mA, obs.mean_I_mA, obs.std_I_mA, obs.tail_mass_top10, ...
            'VariableNames', {'variant', 'T_K', 'q10_mA', 'q25_mA', 'q50_mA', 'q75_mA', 'q90_mA', ...
            'iq75_25_mA', 'iq90_10_mA', 'mean_I_mA', 'std_I_mA', 'tail_mass_top10'})]; %#ok<AGROW>
    end
end

obsOrig = obsRows(obsRows.variant == "original", :);
obsOrig = sortrows(obsOrig, 'T_K');
[~, ik] = ismember(obsOrig.T_K, Tk);
[~, ir] = ismember(obsOrig.T_K, Tr);
yK = kappa(ik);
yR = R(ir);

Xk = [ones(height(obsOrig), 1), obsOrig.q90_mA, obsOrig.iq90_10_mA, obsOrig.std_I_mA, obsOrig.tail_mass_top10];
bK = Xk \ yK;
kappaFitOrig = Xk * bK;
rmseKOrig = sqrt(mean((yK - kappaFitOrig).^2, 'omitnan'));

XR = [ones(height(obsOrig), 1), yK];
bR = XR \ yR;
RFitOrig = XR * bR;
rmseROrig = sqrt(mean((yR - RFitOrig).^2, 'omitnan'));

predRows = table();
summaryRows = table();
for vi = 1:nV
    key = string(variants{vi});
    sub = obsRows(obsRows.variant == key, :);
    sub = sortrows(sub, 'T_K');
    Xmod = [ones(height(sub), 1), sub.q90_mA, sub.iq90_10_mA, sub.std_I_mA, sub.tail_mass_top10];
    kappaPred = Xmod * bK;
    RPred = [ones(height(sub), 1), kappaPred] * bR;
    sub.kappa_pred = kappaPred;
    sub.R_pred = RPred;
    sub.kappa_actual = yK;
    sub.R_actual = yR;
    predRows = [predRows; sub]; %#ok<AGROW>

    rmseK = sqrt(mean((yK - kappaPred).^2, 'omitnan'));
    rmseR = sqrt(mean((yR - RPred).^2, 'omitnan'));
    corrK = safeCorr(yK, kappaPred);
    corrR = safeCorr(yR, RPred);
    deltaK = mean(abs(kappaPred - kappaFitOrig), 'omitnan');
    deltaR = mean(abs(RPred - RFitOrig), 'omitnan');
    summaryRows = [summaryRows; table(key, rmseK, corrK, deltaK, rmseR, corrR, deltaR, ...
        'VariableNames', {'variant', 'kappa_rmse_vs_actual', 'kappa_corr_vs_actual', ...
        'mean_abs_delta_kappa_vs_original_fit', 'R_rmse_vs_actual', 'R_corr_vs_actual', ...
        'mean_abs_delta_R_vs_original_fit'})]; %#ok<AGROW>
end

summaryRows.kappa_rmse_ratio_to_original = summaryRows.kappa_rmse_vs_actual ./ max(rmseKOrig, eps);
summaryRows.R_rmse_ratio_to_original = summaryRows.R_rmse_vs_actual ./ max(rmseROrig, eps);

metricsPath = fullfile(runDir, 'tables', 'tail_ablation_metrics.csv');
writetable(joinMetrics(predRows, summaryRows), metricsPath);

fig = create_figure('Name', 'kappa_vs_tail_ablation', 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 18 11]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
plot(ax, obsOrig.T_K, yK, 'k-o', 'LineWidth', 2.8, 'MarkerSize', 6, 'DisplayName', 'kappa actual');
cmap = lines(nV);
for vi = 1:nV
    key = string(variants{vi});
    sub = predRows(predRows.variant == key, :);
    sub = sortrows(sub, 'T_K');
    plot(ax, sub.T_K, sub.kappa_pred, '-o', 'Color', cmap(vi, :), 'LineWidth', 2.0, ...
        'MarkerSize', 5, 'DisplayName', sprintf('kappa pred (%s)', key));
end
xlabel(ax, 'Temperature T (K)');
ylabel(ax, '\kappa');
title(ax, 'Kappa prediction under PT tail ablation');
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 12, 'LineWidth', 1.1);
saveas(fig, fullfile(runDir, 'figures', 'kappa_vs_tail_ablation.png'));
close(fig);

verdict = buildVerdict(summaryRows);
reportPath = fullfile(runDir, 'reports', 'tail_ablation_report.md');
writeReport(reportPath, cfg, runDir, summaryRows, rmseKOrig, rmseROrig, verdict);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.metrics_csv = string(metricsPath);
out.figure_png = string(fullfile(runDir, 'figures', 'kappa_vs_tail_ablation.png'));
out.report_md = string(reportPath);
out.verdict = verdict;

fprintf('tail_ablation_test complete\n%s\n', runDir);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'ptMatrixPath', fullfile(switchingCanonicalRunRoot(repoRoot), ...
    'run_2026_03_25_013356_pt_robust_canonical', 'tables', 'PT_matrix.csv'));
cfg = setDefault(cfg, 'kappaPath', fullfile(switchingCanonicalRunRoot(repoRoot), ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition', 'tables', 'kappa_vs_T.csv'));
cfg = setDefault(cfg, 'rPath', fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv'));
cfg = setDefault(cfg, 'tailCapQuantile', 0.90);
end

function [temps, currents, PT] = loadPTMatrixLocal(pathCsv)
tbl = readtable(pathCsv, 'VariableNamingRule', 'preserve');
vn = tbl.Properties.VariableNames;
assert(ismember('T_K', vn), 'PT_matrix must include T_K.');
ptCols = setdiff(vn, {'T_K'}, 'stable');
temps = double(tbl.T_K(:));
PT = double(table2array(tbl(:, ptCols)));
currents = parseCurrentGridLocal(ptCols);
[currents, io] = sort(currents(:), 'ascend');
PT = PT(:, io);
[temps, it] = sort(temps(:), 'ascend');
PT = PT(it, :);
end

function [T, kappa] = loadKappaLocal(pathCsv)
tbl = readtable(pathCsv, 'VariableNamingRule', 'preserve');
if ismember('T', tbl.Properties.VariableNames) && ~ismember('T_K', tbl.Properties.VariableNames)
    tbl.Properties.VariableNames{'T'} = 'T_K';
end
assert(all(ismember({'T_K', 'kappa'}, tbl.Properties.VariableNames)), 'kappa file needs T_K and kappa.');
T = double(tbl.T_K(:));
kappa = double(tbl.kappa(:));
[T, i] = sort(T);
kappa = kappa(i);
end

function [T, R] = loadRLocal(pathCsv)
tbl = readtable(pathCsv, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'R_T_interp'}, tbl.Properties.VariableNames)), 'R file needs T_K and R_T_interp.');
T = double(tbl.T_K(:));
R = double(tbl.R_T_interp(:));
[T, i] = sort(T);
R = R(i);
end

function p = modifyTailVariant(I, pRaw, key, cfg)
I = I(:);
pRaw = pRaw(:);
m = isfinite(I) & isfinite(pRaw);
I = I(m);
p = max(pRaw(m), 0);
if numel(I) < 3
    p = pRaw;
    return;
end
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    return;
end
p = p ./ area;
cdf = cumtrapz(I, p);
cdf = cdf ./ max(cdf(end), eps);
q95 = quantileFromCDF(I, cdf, 0.95);
q90 = quantileFromCDF(I, cdf, 0.90);
switch char(key)
    case 'remove_top5'
        p(I >= q95) = 0;
    case 'remove_top10'
        p(I >= q90) = 0;
    case 'cap_tail'
        capQ = quantileFromCDF(I, cdf, cfg.tailCapQuantile);
        capVal = interp1(I, p, capQ, 'linear', 'extrap');
        p(I >= capQ) = min(p(I >= capQ), capVal);
    otherwise
        % original
end
a2 = trapz(I, p);
if isfinite(a2) && a2 > 0
    p = p ./ a2;
end

% lift back to full grid length
pFull = zeros(size(pRaw));
pFull(m) = p;
p = pFull;
end

function obs = computePTObservables(I, pRaw)
I = I(:);
pRaw = pRaw(:);
obs = struct('q10_mA', NaN, 'q25_mA', NaN, 'q50_mA', NaN, 'q75_mA', NaN, 'q90_mA', NaN, ...
    'iq75_25_mA', NaN, 'iq90_10_mA', NaN, 'mean_I_mA', NaN, 'std_I_mA', NaN, 'tail_mass_top10', NaN);
m = isfinite(I) & isfinite(pRaw);
I = I(m);
p = max(pRaw(m), 0);
if numel(I) < 3
    return;
end
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    return;
end
p = p ./ area;
cdf = cumtrapz(I, p);
cdf = cdf ./ max(cdf(end), eps);
obs.q10_mA = quantileFromCDF(I, cdf, 0.10);
obs.q25_mA = quantileFromCDF(I, cdf, 0.25);
obs.q50_mA = quantileFromCDF(I, cdf, 0.50);
obs.q75_mA = quantileFromCDF(I, cdf, 0.75);
obs.q90_mA = quantileFromCDF(I, cdf, 0.90);
obs.iq75_25_mA = obs.q75_mA - obs.q25_mA;
obs.iq90_10_mA = obs.q90_mA - obs.q10_mA;
mu = trapz(I, I .* p);
obs.mean_I_mA = mu;
obs.std_I_mA = sqrt(max(trapz(I, ((I - mu) .^ 2) .* p), 0));
q90 = obs.q90_mA;
it = I >= q90;
if any(it)
    obs.tail_mass_top10 = trapz(I(it), p(it));
else
    obs.tail_mass_top10 = 0;
end
end

function q = quantileFromCDF(I, cdf, qt)
u = cdf(:);
x = I(:);
m = isfinite(u) & isfinite(x);
u = u(m);
x = x(m);
if numel(u) < 2
    q = NaN;
    return;
end
[uu, ~, idx] = unique(u, 'stable');
xa = zeros(numel(uu), 1);
for i = 1:numel(uu)
    xa(i) = mean(x(idx == i), 'omitnan');
end
qt = min(max(qt, 0), 1);
q = interp1(uu, xa, qt, 'linear', NaN);
end

function c = safeCorr(x, y)
m = isfinite(x) & isfinite(y);
if nnz(m) < 3
    c = NaN;
    return;
end
c = corr(x(m), y(m), 'rows', 'complete');
end

function tbl = joinMetrics(predRows, summaryRows)
predRows = sortrows(predRows, {'variant', 'T_K'});
tbl = predRows;
tbl.kappa_rmse_vs_actual = NaN(height(tbl), 1);
tbl.kappa_corr_vs_actual = NaN(height(tbl), 1);
tbl.mean_abs_delta_kappa_vs_original_fit = NaN(height(tbl), 1);
tbl.R_rmse_vs_actual = NaN(height(tbl), 1);
tbl.R_corr_vs_actual = NaN(height(tbl), 1);
tbl.mean_abs_delta_R_vs_original_fit = NaN(height(tbl), 1);
tbl.kappa_rmse_ratio_to_original = NaN(height(tbl), 1);
tbl.R_rmse_ratio_to_original = NaN(height(tbl), 1);
for i = 1:height(summaryRows)
    mk = tbl.variant == summaryRows.variant(i);
    tbl.kappa_rmse_vs_actual(mk) = summaryRows.kappa_rmse_vs_actual(i);
    tbl.kappa_corr_vs_actual(mk) = summaryRows.kappa_corr_vs_actual(i);
    tbl.mean_abs_delta_kappa_vs_original_fit(mk) = summaryRows.mean_abs_delta_kappa_vs_original_fit(i);
    tbl.R_rmse_vs_actual(mk) = summaryRows.R_rmse_vs_actual(i);
    tbl.R_corr_vs_actual(mk) = summaryRows.R_corr_vs_actual(i);
    tbl.mean_abs_delta_R_vs_original_fit(mk) = summaryRows.mean_abs_delta_R_vs_original_fit(i);
    tbl.kappa_rmse_ratio_to_original(mk) = summaryRows.kappa_rmse_ratio_to_original(i);
    tbl.R_rmse_ratio_to_original(mk) = summaryRows.R_rmse_ratio_to_original(i);
end
end

function verdict = buildVerdict(summaryRows)
sub = summaryRows(summaryRows.variant ~= "original", :);
if isempty(sub)
    verdict = struct('TAIL_CONTROLS_KAPPA', "NO", 'TAIL_CRITICAL_FOR_R', "NO", 'NONTAIL_STRUCTURE_SUFFICIENT', "YES");
    return;
end
maxKR = max(sub.kappa_rmse_ratio_to_original, [], 'omitnan');
maxRR = max(sub.R_rmse_ratio_to_original, [], 'omitnan');
bestNonTailCorr = max(sub.kappa_corr_vs_actual, [], 'omitnan');

tailControlsKappa = "NO";
if isfinite(maxKR) && maxKR >= 1.25
    tailControlsKappa = "YES";
end
tailCriticalR = "NO";
if isfinite(maxRR) && maxRR >= 1.25
    tailCriticalR = "YES";
end
nonTailSufficient = "NO";
if isfinite(bestNonTailCorr) && bestNonTailCorr >= 0.90 && isfinite(maxKR) && maxKR < 1.15
    nonTailSufficient = "YES";
end
verdict = struct('TAIL_CONTROLS_KAPPA', tailControlsKappa, ...
    'TAIL_CRITICAL_FOR_R', tailCriticalR, ...
    'NONTAIL_STRUCTURE_SUFFICIENT', nonTailSufficient);
end

function writeReport(pathMd, cfg, runDir, summaryRows, rmseKOrig, rmseROrig, verdict)
fid = fopen(pathMd, 'w');
if fid < 0
    error('run_tail_ablation_test:ReportWriteFail', 'Cannot write report: %s', pathMd);
end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# Tail ablation test\n\n');
fprintf(fid, '## Goal\n\n');
fprintf(fid, 'Test whether high-barrier tail controls kappa and whether tail effects propagate to R(T).\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- PT_matrix: `%s`\n', cfg.ptMatrixPath);
fprintf(fid, '- kappa(T): `%s`\n', cfg.kappaPath);
fprintf(fid, '- R(T): `%s`\n\n', cfg.rPath);
fprintf(fid, '## Variants\n\n');
fprintf(fid, '- `remove_top5`: zero mass above q95, renormalize.\n');
fprintf(fid, '- `remove_top10`: zero mass above q90, renormalize.\n');
fprintf(fid, '- `cap_tail`: cap density above q90 to value at q90, renormalize.\n\n');
fprintf(fid, '## Baseline fits\n\n');
fprintf(fid, '- kappa proxy baseline RMSE: **%.6g**\n', rmseKOrig);
fprintf(fid, '- R proxy baseline RMSE: **%.6g**\n\n', rmseROrig);
fprintf(fid, '## Tail-ablation metrics by variant\n\n');
fprintf(fid, '%s\n\n', evalc('disp(summaryRows)'));
fprintf(fid, '## Final verdict\n\n');
fprintf(fid, '- **TAIL_CONTROLS_KAPPA: %s**\n', verdict.TAIL_CONTROLS_KAPPA);
fprintf(fid, '- **TAIL_CRITICAL_FOR_R: %s**\n', verdict.TAIL_CRITICAL_FOR_R);
fprintf(fid, '- **NONTAIL_STRUCTURE_SUFFICIENT: %s**\n\n', verdict.NONTAIL_STRUCTURE_SUFFICIENT);
fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `%s`\n', fullfile(runDir, 'tables', 'tail_ablation_metrics.csv'));
fprintf(fid, '- `%s`\n', fullfile(runDir, 'figures', 'kappa_vs_tail_ablation.png'));
fprintf(fid, '- `%s`\n', fullfile(runDir, 'reports', 'tail_ablation_report.md'));
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

function value = setDefault(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
else
    s.(fieldName) = defaultValue;
    value = s;
end
end

function currents = parseCurrentGridLocal(varNames)
n = numel(varNames);
currents = NaN(n, 1);
for i = 1:n
    vName = string(varNames{i});
    token = regexp(vName, '^Ith_(.*)_mA$', 'tokens', 'once');
    assert(~isempty(token), 'Bad PT column name: %s', vName);
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
    assert(isfinite(val), 'Cannot parse current from %s', vName);
    currents(i) = val;
end
end
