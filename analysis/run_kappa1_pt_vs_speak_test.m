function run_kappa1_pt_vs_speak_test()
% run_kappa1_pt_vs_speak_test
% Focused closure test:
%   Is kappa1 predictable from PT observables alone, or does adding S_peak
%   provide meaningful out-of-sample information?

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

set(0, 'DefaultFigureVisible', 'off');

% Canonical aligned sources (same chain used by aligned Agent 20A fix).
kappaRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition');
srcPath = fullfile(kappaRunDir, 'tables', 'residual_decomposition_sources.csv');
src = readtable(srcPath, 'VariableNamingRule', 'preserve');

ptRow = src(strcmp(src.source_role, 'pt_matrix'), :);
assert(~isempty(ptRow), 'Missing pt_matrix source row in residual_decomposition_sources.csv');
ptPath = char(ptRow.source_file{1});
ptRunId = char(ptRow.source_run_id{1});

scRow = src(strcmp(src.source_role, 'full_scaling_parameters'), :);
assert(~isempty(scRow), 'Missing full_scaling_parameters row in residual_decomposition_sources.csv');
speakPath = char(scRow.source_file{1});
speakRunId = char(scRow.source_run_id{1});

kappaPath = fullfile(kappaRunDir, 'tables', 'kappa_vs_T.csv');
kappaRunId = 'run_2026_03_24_220314_residual_decomposition';

runCfg = struct( ...
    'runLabel', 'kappa1_pt_vs_speak_test', ...
    'dataset', sprintf('kappa:%s | PT:%s | scaling:%s', kappaRunId, ptRunId, speakRunId), ...
    'kappa_path', kappaPath, ...
    'pt_path', ptPath, ...
    'speak_path', speakPath);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
for s = ["figures","tables","reports","review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end
fprintf('Run directory:\n%s\n', runDir);

% Load data and build joined table.
PT = readtable(ptPath, 'VariableNamingRule', 'preserve');
K = readtable(kappaPath, 'VariableNamingRule', 'preserve');
S = readtable(speakPath, 'VariableNamingRule', 'preserve');

assert(all(ismember({'T','kappa'}, K.Properties.VariableNames)), 'kappa table missing T/kappa');
assert(all(ismember({'T_K','S_peak'}, S.Properties.VariableNames)), 'scaling table missing T_K/S_peak');

[Ivals, pCols] = localParsePtColumns(PT.Properties.VariableNames);
Tpt = double(PT.T_K);
nPt = numel(Tpt);

feat = table('Size', [nPt, 10], ...
    'VariableTypes', repmat({'double'}, 1, 10), ...
    'VariableNames', {'T_K','q90_minus_q50','q75_minus_q50','q50_minus_q10', ...
    'asymmetry','width_central','q90_I','q75_I','q50_I','q10_I'});

for i = 1:nPt
    prow = nan(1, numel(Ivals));
    for j = 1:numel(Ivals)
        v = PT{i, pCols(j)};
        prow(j) = localToFiniteDouble(v);
    end
    f = localTailFeatures(Ivals, prow);
    feat.T_K(i) = Tpt(i);
    if ~isempty(f)
        feat.q90_minus_q50(i) = f.q90 - f.q50;
        feat.q75_minus_q50(i) = f.q75 - f.q50;
        feat.q50_minus_q10(i) = f.q50 - f.q10;
        feat.asymmetry(i) = (f.q90 - f.q50) - (f.q50 - f.q10);
        feat.width_central(i) = f.q75 - f.q25;
        feat.q90_I(i) = f.q90;
        feat.q75_I(i) = f.q75;
        feat.q50_I(i) = f.q50;
        feat.q10_I(i) = f.q10;
    end
end

Kj = table(double(K.T), double(K.kappa), 'VariableNames', {'T_K','kappa1'});
Sj = table(double(S.T_K), double(S.S_peak), 'VariableNames', {'T_K','S_peak'});
joined = innerjoin(innerjoin(Kj, Sj, 'Keys', 'T_K'), feat, 'Keys', 'T_K');
joined = sortrows(joined, 'T_K');

req = {'kappa1','S_peak','q90_minus_q50','q75_minus_q50','q50_minus_q10','asymmetry','width_central'};
m = true(height(joined), 1);
for i = 1:numel(req)
    m = m & isfinite(joined.(req{i}));
end
joined = joined(m, :);

assert(height(joined) >= 6, 'Too few finite overlapping rows (n=%d)', height(joined));
save_run_table(joined, 'kappa1_joined_analysis_table.csv', runDir);

% Controlled model family.
y = joined.kappa1;
Xtail = joined.q90_minus_q50;
Xasym = joined.asymmetry;
Xwid = joined.width_central;
Xs = joined.S_peak;
Xq75 = joined.q75_minus_q50;
Xq50q10 = joined.q50_minus_q10;
T_K = joined.T_K;
n = numel(y);

models = struct('name', {}, 'family', {}, 'X', {}, 'pred', {}, 'metrics', {});
models(end+1) = localEvalModel('kappa1 ~ q90_minus_q50', 'PT-only', y, [Xtail], []);
models(end+1) = localEvalModel('kappa1 ~ q90_minus_q50 + asymmetry', 'PT-only', y, [Xtail Xasym], []);
models(end+1) = localEvalModel('kappa1 ~ q90_minus_q50 + width_central', 'PT-only', y, [Xtail Xwid], []);

ptCandidates = {
    'kappa1 ~ q90_minus_q50 + q75_minus_q50', [Xtail Xq75];
    'kappa1 ~ q90_minus_q50 + q50_minus_q10', [Xtail Xq50q10];
    'kappa1 ~ q90_minus_q50 + asymmetry', [Xtail Xasym];
    'kappa1 ~ q90_minus_q50 + width_central', [Xtail Xwid];
    'kappa1 ~ q75_minus_q50 + q50_minus_q10', [Xq75 Xq50q10];
    'kappa1 ~ asymmetry + width_central', [Xasym Xwid];
    };

ptBestIdx = NaN;
ptBestRmse = inf;
for i = 1:size(ptCandidates,1)
    m0 = localEvalModel(ptCandidates{i,1}, 'PT-only', y, ptCandidates{i,2}, []);
    if isfinite(m0.metrics.loocv_rmse) && m0.metrics.loocv_rmse < ptBestRmse
        ptBestRmse = m0.metrics.loocv_rmse;
        ptBestIdx = i;
    end
end
bestPt2 = localEvalModel([ptCandidates{ptBestIdx,1} ' (best-2var PT)'], 'PT-only', y, ptCandidates{ptBestIdx,2}, []);
models(end+1) = bestPt2;

models(end+1) = localEvalModel('kappa1 ~ q90_minus_q50 + S_peak', 'PT+S_peak', y, [Xtail Xs], []);
bestPtPlusS = localEvalModel([bestPt2.name ' + S_peak'], 'PT+S_peak', y, [bestPt2.X Xs], []);
models(end+1) = bestPtPlusS;

meanRmse = sqrt(mean((y - mean(y)).^2, 'omitnan'));
allRows = table();
bestPtOnlyRmse = min(arrayfun(@(z) z.metrics.loocv_rmse, models(strcmp({models.family}, 'PT-only'))));
for i = 1:numel(models)
    mm = models(i).metrics;
    allRows = [allRows; table({models(i).name}, {models(i).family}, n, ...
        mm.loocv_rmse, mm.pearson, mm.spearman, ...
        meanRmse - mm.loocv_rmse, ...
        bestPtOnlyRmse - mm.loocv_rmse, ...
        'VariableNames', {'model','family','n','loocv_rmse','pearson_y_yhat', ...
        'spearman_y_yhat','delta_rmse_vs_mean','delta_rmse_vs_best_pt_only'})]; %#ok<AGROW>
end
save_run_table(allRows, 'kappa1_pt_vs_speak_models.csv', runDir);

% Partial correlation tests and residual test.
mainPT = Xtail;
partial_speak = localPartialCorr(y, Xs, mainPT);
partial_pt = localPartialCorr(y, mainPT, Xs);

[~, bestPtOnlyIdx] = min(arrayfun(@(z) z.metrics.loocv_rmse, models(strcmp({models.family}, 'PT-only'))));
ptOnlyModels = models(strcmp({models.family}, 'PT-only'));
bestPtOnly = ptOnlyModels(bestPtOnlyIdx);
resid = y - bestPtOnly.pred;
residPear = corr(resid, Xs, 'rows', 'complete', 'type', 'Pearson');
residSpea = corr(resid, Xs, 'rows', 'complete', 'type', 'Spearman');

partTbl = table( ...
    ["partial_corr(kappa1,S_peak|q90_minus_q50)"; ...
     "partial_corr(kappa1,q90_minus_q50|S_peak)"; ...
     "residual_corr(best_PT_only_residual,S_peak)"], ...
    [partial_speak.pearson; partial_pt.pearson; residPear], ...
    [partial_speak.spearman; partial_pt.spearman; residSpea], ...
    'VariableNames', {'test','pearson','spearman'});
save_run_table(partTbl, 'kappa1_partial_correlation_tests.csv', runDir);

% Figure.
baseName = 'kappa1_pt_vs_speak_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off');
tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
scatter(y, bestPtOnly.pred, 80, T_K, 'filled'); hold on;
lims = [min([y; bestPtOnly.pred]), max([y; bestPtOnly.pred])];
plot(lims, lims, 'k--', 'LineWidth', 2); hold off; grid on;
xlabel('kappa1 measured'); ylabel('kappa1 LOOCV prediction');
title(sprintf('Best PT-only: %.4f RMSE', bestPtOnly.metrics.loocv_rmse), 'Interpreter', 'none');
set(gca, 'FontSize', 14); colormap(parula); cb1 = colorbar; cb1.Label.String = 'T (K)';

nexttile;
scatter(y, bestPtPlusS.pred, 80, T_K, 'filled'); hold on;
lims2 = [min([y; bestPtPlusS.pred]), max([y; bestPtPlusS.pred])];
plot(lims2, lims2, 'k--', 'LineWidth', 2); hold off; grid on;
xlabel('kappa1 measured'); ylabel('kappa1 LOOCV prediction');
title(sprintf('Best PT+S_{peak}: %.4f RMSE', bestPtPlusS.metrics.loocv_rmse), 'Interpreter', 'tex');
set(gca, 'FontSize', 14); colormap(parula); cb2 = colorbar; cb2.Label.String = 'T (K)';

save_run_figure(fig, baseName, runDir);
close(fig);

% Verdict rule.
dRmse = bestPtOnly.metrics.loocv_rmse - bestPtPlusS.metrics.loocv_rmse;
pctGain = 100 * dRmse / max(bestPtOnly.metrics.loocv_rmse, eps);
robustGain = dRmse > 0.003 && pctGain > 8;
strongResidual = abs(residPear) > 0.35;

v_pt_only = "NO";
v_dom_plus = "NO";
v_requires = "NO";

if dRmse <= 0.0015 && abs(partial_speak.pearson) < 0.2 && ~strongResidual
    v_pt_only = "YES";
elseif robustGain || (dRmse > 0.0015 && abs(partial_speak.pearson) >= 0.2) || strongResidual
    v_dom_plus = "YES";
else
    v_pt_only = "YES";
end

if bestPtOnly.metrics.loocv_rmse > 0.05 && robustGain && abs(partial_speak.pearson) >= 0.35
    v_dom_plus = "NO";
    v_requires = "YES";
end

report = localBuildReport(runDir, ptRunId, kappaRunId, speakRunId, ...
    ptPath, kappaPath, speakPath, joined, bestPtOnly, bestPtPlusS, ...
    allRows, partTbl, dRmse, pctGain, robustGain, v_pt_only, v_dom_plus, v_requires);
save_run_report(report, 'kappa1_pt_vs_speak_report.md', runDir);

zipPath = fullfile(runDir, 'review', 'kappa1_pt_vs_speak_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);

fprintf('Completed kappa1 PT-only vs PT+S_peak test.\n');
fprintf('Run: %s\n', runDir);
end

function [Ivals, pCols] = localParsePtColumns(varNames)
pCols = find(startsWith(varNames, 'Ith_'));
assert(~isempty(pCols), 'No Ith_* columns found in PT table');
Ivals = nan(1, numel(pCols));
for j = 1:numel(pCols)
    name = varNames{pCols(j)};
    s = erase(name, 'Ith_');
    s = erase(s, '_mA');
    s = strrep(s, '_', '.');
    Ivals(j) = str2double(s);
end
[Ivals, ord] = sort(Ivals, 'ascend');
pCols = pCols(ord);
end

function x = localToFiniteDouble(v)
if iscell(v), v = v{1}; end
x = double(v);
if isempty(x) || ~isfinite(x), x = NaN; end
end

function feat = localTailFeatures(I, p)
mask = isfinite(I) & isfinite(p);
I = I(mask);
p = p(mask);
if numel(I) < 2 || all(p <= 0), feat = []; return; end
p = max(p, 0);
area = trapz(I, p);
if ~isfinite(area) || area <= 0, feat = []; return; end
pn = p / area;
cdf = cumtrapz(I, pn);
cdf = cdf / cdf(end);
feat = struct();
feat.q10 = localQuantileFromCdf(I, cdf, 0.10);
feat.q25 = localQuantileFromCdf(I, cdf, 0.25);
feat.q50 = localQuantileFromCdf(I, cdf, 0.50);
feat.q75 = localQuantileFromCdf(I, cdf, 0.75);
feat.q90 = localQuantileFromCdf(I, cdf, 0.90);
end

function q = localQuantileFromCdf(I, cdf, qt)
if numel(I) < 2 || numel(cdf) < 2
    q = NaN; return;
end
[u, ia] = unique(cdf, 'stable');
iu = I(ia);
if numel(u) < 2
    q = NaN; return;
end
q = interp1(u, iu, max(0,min(1,qt)), 'linear', 'extrap');
end

function out = localEvalModel(name, family, y, X, mask)
if nargin < 5 || isempty(mask), mask = true(size(y)); end
y = y(mask); X = X(mask, :);
m = all(isfinite([y, X]), 2);
y = y(m); X = X(m, :);

[rmse, pred] = localLoocvOls(y, X);
p = corr(y, pred, 'rows', 'complete', 'type', 'Pearson');
s = corr(y, pred, 'rows', 'complete', 'type', 'Spearman');

out = struct();
out.name = name;
out.family = family;
out.X = X;
out.pred = pred;
out.metrics = struct('loocv_rmse', rmse, 'pearson', p, 'spearman', s);
end

function [rmse, yhat] = localLoocvOls(y, X)
n = numel(y);
yhat = nan(n,1);
for i = 1:n
    idx = true(n,1); idx(i) = false;
    Xt = X(idx,:); yt = y(idx);
    Zt = [ones(size(Xt,1),1), Xt];
    if rank(Zt) < size(Zt,2)
        yhat(i) = NaN;
        continue;
    end
    b = Zt \ yt;
    yhat(i) = [1, X(i,:)] * b;
end
rmse = sqrt(mean((y - yhat).^2, 'omitnan'));
end

function out = localPartialCorr(y, x, z)
y = y(:); x = x(:); z = z(:);
m = isfinite(y) & isfinite(x) & isfinite(z);
y = y(m); x = x(m); z = z(m);
if numel(y) < 4
    out = struct('pearson', NaN, 'spearman', NaN);
    return;
end
Z = [ones(numel(z),1), z];
ry = y - Z*(Z\y);
rx = x - Z*(Z\x);
out = struct();
out.pearson = corr(ry, rx, 'type', 'Pearson', 'rows', 'complete');
out.spearman = corr(ry, rx, 'type', 'Spearman', 'rows', 'complete');
end

function txt = localBuildReport(runDir, ptRunId, kappaRunId, speakRunId, ...
    ptPath, kappaPath, speakPath, joined, bestPtOnly, bestPtPlusS, ...
    modelRows, partTbl, dRmse, pctGain, robustGain, v1, v2, v3)

lines = {};
lines{end+1} = '# kappa1 PT-only vs PT+S_peak closure test';
lines{end+1} = '';
lines{end+1} = '## 1. Question';
lines{end+1} = 'Does kappa1 close from PT alone, or does S_peak add genuine predictive information?';
lines{end+1} = '';
lines{end+1} = '## 2. Data used';
lines{end+1} = sprintf('- PT run ID: `%s`', ptRunId);
lines{end+1} = sprintf('- kappa1 run ID: `%s`', kappaRunId);
lines{end+1} = sprintf('- S_peak run ID: `%s`', speakRunId);
lines{end+1} = sprintf('- PT file: `%s`', strrep(ptPath, '\', '/'));
lines{end+1} = sprintf('- kappa1 file: `%s`', strrep(kappaPath, '\', '/'));
lines{end+1} = sprintf('- S_peak file: `%s`', strrep(speakPath, '\', '/'));
lines{end+1} = sprintf('- Overlapping finite temperatures: **n = %d** (`T_K`: %s)', ...
    height(joined), mat2str(joined.T_K(:)', 4));
lines{end+1} = '';

lines{end+1} = '## 3. Best PT-only model';
lines{end+1} = sprintf('- Formula: `%s`', bestPtOnly.name);
lines{end+1} = sprintf('- LOOCV RMSE: `%.6g`', bestPtOnly.metrics.loocv_rmse);
lines{end+1} = sprintf('- Pearson(y,yhat): `%.4f`', bestPtOnly.metrics.pearson);
lines{end+1} = sprintf('- Spearman(y,yhat): `%.4f`', bestPtOnly.metrics.spearman);
lines{end+1} = '';

lines{end+1} = '## 4. Best PT+S_peak model';
lines{end+1} = sprintf('- Formula: `%s`', bestPtPlusS.name);
lines{end+1} = sprintf('- LOOCV RMSE: `%.6g`', bestPtPlusS.metrics.loocv_rmse);
lines{end+1} = sprintf('- Pearson(y,yhat): `%.4f`', bestPtPlusS.metrics.pearson);
lines{end+1} = sprintf('- Spearman(y,yhat): `%.4f`', bestPtPlusS.metrics.spearman);
lines{end+1} = '';

lines{end+1} = '## 5. Comparison';
lines{end+1} = sprintf('- Absolute LOOCV improvement (best PT-only - best PT+S_peak): `%.6g`', dRmse);
lines{end+1} = sprintf('- Percentage LOOCV improvement: `%.2f%%`', pctGain);
if robustGain
    lines{end+1} = '- Improvement robustness: **meaningful at current sample size**, but still limited by small n.';
else
    lines{end+1} = '- Improvement robustness: **marginal/uncertain** at current sample size.';
end
lines{end+1} = '';

lines{end+1} = '## 6. Partial-correlation interpretation';
for i = 1:height(partTbl)
    lines{end+1} = sprintf('- `%s`: Pearson=`%.4f`, Spearman=`%.4f`', ...
        partTbl.test(i), partTbl.pearson(i), partTbl.spearman(i));
end
lines{end+1} = '- Interpretation discipline: these tests support incremental predictive association, not standalone independence claims.';
lines{end+1} = '';

lines{end+1} = '## 7. Final verdict block';
lines{end+1} = sprintf('KAPPA1_PT_ONLY: %s', v1);
lines{end+1} = sprintf('KAPPA1_PT_DOMINANT_BUT_SPEAK_ADDS: %s', v2);
lines{end+1} = sprintf('KAPPA1_REQUIRES_SPEAK: %s', v3);
lines{end+1} = '';

lines{end+1} = '## 8. Plain-language conclusion';
if strcmp(v1, "YES")
    lines{end+1} = 'kappa1 is effectively PT-closed at current resolution';
elseif strcmp(v2, "YES")
    lines{end+1} = 'kappa1 is mainly PT-controlled but S_peak carries additional predictive information';
else
    lines{end+1} = 'kappa1 cannot be compressed to PT summaries alone in the current data';
end
lines{end+1} = '';

lines{end+1} = '## Visualization choices';
lines{end+1} = '- Number of curves: 2 scatter panels (no dense multitrace stack).';
lines{end+1} = '- Legend vs colormap: colormap + colorbar by temperature for point encoding.';
lines{end+1} = '- Colormap: parula.';
lines{end+1} = '- Smoothing: none applied.';
lines{end+1} = '- Justification: direct side-by-side LOOCV comparison of PT-only and PT+S_peak best models.';
lines{end+1} = '';

lines{end+1} = '## Model table';
lines{end+1} = '| model | family | n | LOOCV RMSE | Pearson | Spearman | ΔRMSE vs mean | ΔRMSE vs best PT-only |';
lines{end+1} = '|---|---|---:|---:|---:|---:|---:|---:|';
for i = 1:height(modelRows)
    lines{end+1} = sprintf('| %s | %s | %d | %.6g | %.4f | %.4f | %.6g | %.6g |', ...
        modelRows.model{i}, modelRows.family{i}, modelRows.n(i), modelRows.loocv_rmse(i), ...
        modelRows.pearson_y_yhat(i), modelRows.spearman_y_yhat(i), ...
        modelRows.delta_rmse_vs_mean(i), modelRows.delta_rmse_vs_best_pt_only(i));
end
lines{end+1} = '';
lines{end+1} = sprintf('*Run dir:* `%s`', strrep(runDir, '\', '/'));

txt = strjoin(lines, newline);
end
