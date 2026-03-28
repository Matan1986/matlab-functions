function run_aging_hermetic_closure_agent24i(varargin)
%RUN_AGING_HERMETIC_CLOSURE_AGENT24I  Agent 24I — hermetic closure: interaction / transition / |α_res| (LOOCV)
%
% Same aligned merge as Agents 24B / 24G (barrier + energy_stats + alpha_structure + alpha_decomposition).
% Tests at most three extensions beyond baseline R ~ spread90_50 + kappa1 + alpha.
%
% Outputs: results/cross_experiment/runs/<run_id>/ plus mirror to repo tables/, figures/, reports/
%   tables/aging_hermetic_closure_models.csv
%   tables/aging_hermetic_closure_residuals.csv
%   figures/aging_hermetic_predictions.png|pdf|fig
%   figures/aging_hermetic_residuals_vs_T.png|pdf|fig
%   reports/aging_hermetic_closure_report.md
%
% Name-value: 'repoRoot', 'barrierPath', 'energyStatsPath', 'clockRatioPath',
%             'alphaStructurePath', 'decompPath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

runCfg = struct('runLabel', 'aging_hermetic_closure_agent24i', ...
    'dataset', 'R(T) LOOCV: hermetic closure extensions (Agent 24I)');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

fprintf(1, 'Agent 24I run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] run_aging_hermetic_closure_agent24i started\n', datestr(now, 31)));

%% Load (same lineage as 24G)
clkPath = opts.clockRatioPath;
assert(isfile(clkPath), 'Missing clock ratio table: %s', clkPath);

bar = readtable(opts.barrierPath, 'VariableNamingRule', 'preserve');
en = readtable(opts.energyStatsPath, 'VariableNamingRule', 'preserve');
if ismember('T', en.Properties.VariableNames) && ~ismember('T_K', en.Properties.VariableNames)
    en.Properties.VariableNames{'T'} = 'T_K';
end
assert(ismember('T_K', en.Properties.VariableNames), 'energy_stats needs T_K or T column');
en = en(:, intersect({'T_K', 'mean_E', 'std_E'}, en.Properties.VariableNames, 'stable'));

bar = innerjoin(bar, en, 'Keys', 'T_K');
bar.spread90_50 = double(bar.q90_I_mA) - double(bar.q50_I_mA);

reqB = {'T_K', 'row_valid', 'R_T_interp', 'spread90_50', 'q90_I_mA', 'q50_I_mA'};
for k = 1:numel(reqB)
    assert(ismember(reqB{k}, bar.Properties.VariableNames), 'barrier_descriptors missing %s', reqB{k});
end

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
aD = readtable(opts.decompPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, aS.Properties.VariableNames)), ...
    'alpha_structure missing kappa/alpha columns');
assert(all(ismember({'T_K', 'PT_geometry_valid'}, aD.Properties.VariableNames)), ...
    'alpha_decomposition missing PT_geometry_valid');

decompCols = {'T_K', 'PT_geometry_valid'};
if ismember('alpha_res', aD.Properties.VariableNames)
    decompCols{end + 1} = 'alpha_res'; %#ok<AGROW>
end
merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    aD(:, decompCols), 'Keys', 'T_K');

bCols = intersect(reqB, bar.Properties.VariableNames, 'stable');
merged = innerjoin(merged, bar(:, bCols), 'Keys', 'T_K');

merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
merged = merged(double(merged.row_valid) ~= 0, :);
merged = sortrows(merged, 'T_K');

T_K = double(merged.T_K(:));
R = double(merged.R_T_interp(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
spread90_50 = double(merged.spread90_50(:));
if ismember('alpha_res', merged.Properties.VariableNames)
    ares = double(merged.alpha_res(:));
else
    ares = nan(size(T_K));
end

sigmaG = 1.5;
T0g = 23;
g23 = exp(-((T_K - T0g).^2) ./ (2 * sigmaG^2));

mOverlap = isfinite(R) & isfinite(spread90_50) & isfinite(k1) & isfinite(k2) & isfinite(alp);
nOverlap = nnz(mOverlap);
assert(nOverlap >= 5, 'Agent24I: insufficient finite overlap rows (n=%d).', nOverlap);

absAres = abs(ares);
modelC_ok = ismember('alpha_res', merged.Properties.VariableNames) && all(isfinite(ares(mOverlap)));

master = table(T_K, R, spread90_50, k1, k2, alp, g23, ares, absAres, ...
    'VariableNames', {'T_K', 'R', 'spread90_50', 'kappa1', 'kappa2', 'alpha', 'g23_transition', ...
    'alpha_res', 'abs_alpha_res'});

masterOut = master(mOverlap, :);
save_run_table(masterOut, 'aging_hermetic_master_table.csv', runDir);

y = R(mOverlap);
Tplot = T_K(mOverlap);
n = numel(y);

%% Models: reference + up to 3 extensions
pred = struct('id', {}, 'cols', {}, 'is_extension', {});
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha'}}, 'is_extension', false); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha + kappa1*alpha', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha', 'local__k1a'}}, 'is_extension', true); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha + g23(T)', ...
    'cols', {{'spread90_50', 'kappa1', 'alpha', 'g23_transition'}}, 'is_extension', true); %#ok<AGROW>
if modelC_ok
    pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + alpha + abs(alpha_res)', ...
        'cols', {{'spread90_50', 'kappa1', 'alpha', 'abs_alpha_res'}}, 'is_extension', true); %#ok<AGROW>
end

k1col = masterOut.kappa1(:);
acol = masterOut.alpha(:);
k1a = k1col .* acol;

rows = table();
yhatStore = struct();

for k = 1:numel(pred)
    pcols = pred(k).cols;
    X = zeros(n, numel(pcols));
    ok = true(n, 1);
    for c = 1:numel(pcols)
        nm = pcols{c};
        if strcmp(nm, 'local__k1a')
            v = k1a;
        else
            v = masterOut.(nm);
        end
        X(:, c) = v(:);
        ok = ok & isfinite(X(:, c));
    end
    if ~all(ok)
        rmse = NaN; rP = NaN; yhat = nan(n, 1);
    else
        [rmse, rP, yhat] = localLoocvOls(y, X);
    end
    rows = [rows; table({pred(k).id}, n, rmse, rP, logical(pred(k).is_extension), ...
        'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_y_yhat', 'is_extension'})]; %#ok<AGROW>
    yhatStore.(localModelFieldName(pred(k).id)) = yhat;
end

idRef = 'R ~ spread90_50 + kappa1 + alpha';
idxRef = strcmp(rows.model, idRef);
assert(any(idxRef), 'missing reference row');
rmseRef = rows.loocv_rmse(idxRef, 1);
assert(isfinite(rmseRef), 'Reference baseline failed LOOCV (rank/n check).');

yhatRef = yhatStore.(localModelFieldName(idRef));
maeRef22 = localMeanAbsRes(Tplot, y, yhatRef, @(t) t >= 22 & t <= 24);
maeRefOut = localMeanAbsRes(Tplot, y, yhatRef, @(t) ~(t >= 22 & t <= 24));

%% Residuals long: all fitted models
fittedMask = isfinite(rows.loocv_rmse);
modelList = rows.model(fittedMask);
residualsLong = localResidualsLong(Tplot, y, cellstr(modelList), yhatStore);
save_run_table(residualsLong, 'aging_hermetic_closure_residuals.csv', runDir);

%% Per-model transition metrics + improvement vs baseline
nModels = height(rows);
meanAbs22 = nan(nModels, 1);
meanAbsOut = nan(nModels, 1);
pctRmseVsRef = nan(nModels, 1);
pctTransVsRef = nan(nModels, 1);
for i = 1:nModels
    mid = rows.model{i};
    yh = yhatStore.(localModelFieldName(mid));
    if ~isfinite(rows.loocv_rmse(i))
        continue
    end
    meanAbs22(i) = localMeanAbsRes(Tplot, y, yh, @(t) t >= 22 & t <= 24);
    meanAbsOut(i) = localMeanAbsRes(Tplot, y, yh, @(t) ~(t >= 22 & t <= 24));
    pctRmseVsRef(i) = 100 * (rows.loocv_rmse(i) - rmseRef) / max(rmseRef, eps);
    pctTransVsRef(i) = 100 * (meanAbs22(i) - maeRef22) / max(maeRef22, eps);
end
aux = table(meanAbs22, meanAbsOut, pctRmseVsRef, pctTransVsRef, ...
    'VariableNames', {'mean_abs_res_22_24K', 'mean_abs_res_outside_22_24K', ...
    'pct_loocv_rmse_vs_reference', 'pct_transition_mean_abs_res_vs_reference'});
rowsOut = [rows, aux];
save_run_table(rowsOut, 'aging_hermetic_closure_models.csv', runDir);

%% Best model (lowest LOOCV among reference + extensions only; reference always valid)
extMask = rows.is_extension & isfinite(rows.loocv_rmse);
if any(extMask)
    [bestRmseExt, jExt] = min(rows.loocv_rmse(extMask));
    extIdx = find(extMask);
    jBestExt = extIdx(jExt);
    bestExtId = rows.model{jBestExt};
    yhatBest = yhatStore.(localModelFieldName(bestExtId));
else
    bestRmseExt = inf;
    bestExtId = '';
    yhatBest = yhatRef;
end
if bestRmseExt < rmseRef - 1e-12
    bestOverallId = bestExtId;
    bestOverallRmse = bestRmseExt;
    yhatOverall = yhatBest;
else
    bestOverallId = idRef;
    bestOverallRmse = rmseRef;
    yhatOverall = yhatRef;
end

%% Verdicts
idA = 'R ~ spread90_50 + kappa1 + alpha + kappa1*alpha';
idB = 'R ~ spread90_50 + kappa1 + alpha + g23(T)';
idC = 'R ~ spread90_50 + kappa1 + alpha + abs(alpha_res)';

verd = localVerdicts(rowsOut, idRef, idA, idB, idC, modelC_ok, rmseRef, maeRef22, yhatStore, Tplot, y);

rmseA = localGetRmse(rows, idA);
rmseB = localGetRmse(rows, idB);
maeA22 = localMae22(yhatStore, Tplot, y, idA);
maeB22 = localMae22(yhatStore, Tplot, y, idB);

fprintf(1, 'Agent 24I verdicts:\n');
fprintf(1, '  INTERACTION_TERM_SUPPORTED: %s\n', char(verd.INTERACTION_TERM_SUPPORTED));
fprintf(1, '  LOCAL_TRANSITION_TERM_SUPPORTED: %s\n', char(verd.LOCAL_TRANSITION_TERM_SUPPORTED));
fprintf(1, '  RESIDUAL_DEFORMATION_TERM_SUPPORTED: %s\n', char(verd.RESIDUAL_DEFORMATION_TERM_SUPPORTED));
fprintf(1, '  HERMETIC_CLOSURE_ACHIEVED: %s\n', char(verd.HERMETIC_CLOSURE_ACHIEVED));
fprintf(1, '  Best model: %s  LOOCV RMSE=%.6g\n', bestOverallId, bestOverallRmse);

%% Figures
fig1 = create_figure('Name', 'aging_hermetic_predictions', 'NumberTitle', 'off');
ax = axes(fig1);
scatter(ax, y, yhatOverall, 90, Tplot, 'filled', 'LineWidth', 1.5);
hold(ax, 'on');
lim = [min([y; yhatOverall], [], 'omitnan'), max([y; yhatOverall], [], 'omitnan')];
if isfinite(lim(1)) && isfinite(lim(2)) && lim(2) > lim(1)
    plot(ax, lim, lim, 'k--', 'LineWidth', 2);
end
hold(ax, 'off');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
grid(ax, 'on');
xlabel(ax, 'R measured (clock ratio, interp)', 'FontSize', 14);
ylabel(ax, 'R LOOCV prediction (best hermetic model)', 'FontSize', 14);
set(ax, 'FontSize', 14);
figPath1 = localTrySaveRunFigure(fig1, 'aging_hermetic_predictions', runDir);
close(fig1);

resBest = y - yhatOverall;
resRef = y - yhatRef;
fig2 = create_figure('Name', 'aging_hermetic_residuals_vs_T', 'NumberTitle', 'off');
ax2 = axes(fig2);
hold(ax2, 'on');
plot(ax2, Tplot, resRef, 's-', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', 'baseline LOOCV res');
plot(ax2, Tplot, resBest, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'best model LOOCV res');
yline(ax2, 0, 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xl = [22, 24];
yr = max(abs([resRef; resBest]), [], 'omitnan');
if ~isfinite(yr) || yr <= 0, yr = 1; end
patch(ax2, [xl(1) xl(2) xl(2) xl(1)], yr * [1 1 -1 -1], [1 0.85 0.85], ...
    'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
hold(ax2, 'off');
xlabel(ax2, 'T (K)', 'FontSize', 14);
ylabel(ax2, 'Residual R (meas - LOOCV pred)', 'FontSize', 14);
legend(ax2, 'Location', 'best', 'Interpreter', 'none');
grid(ax2, 'on');
set(ax2, 'FontSize', 14);
figPath2 = localTrySaveRunFigure(fig2, 'aging_hermetic_residuals_vs_T', runDir);
close(fig2);

%% Report
pctGlobal = 100 * (bestOverallRmse - rmseRef) / max(rmseRef, eps);
pctBestRmse = 100 * (rmseRef - bestOverallRmse) / max(rmseRef, eps);
maeBest22 = localMeanAbsRes(Tplot, y, yhatOverall, @(t) t >= 22 & t <= 24);
transRedPct = 100 * (maeRef22 - maeBest22) / max(maeRef22, eps);
rmseC = localGetRmse(rowsOut, idC);
maeC22 = localMae22(yhatStore, Tplot, y, idC);
rep = localBuildReport(runDir, opts, clkPath, masterOut, rowsOut, idRef, bestOverallId, ...
    rmseRef, bestOverallRmse, pctGlobal, pctBestRmse, maeRef22, maeBest22, transRedPct, verd, ...
    modelC_ok, Tplot, resRef, resBest, figPath1, figPath2, rmseA, rmseB, maeA22, maeB22, rmseC, maeC22);
save_run_report(rep, 'aging_hermetic_closure_report.md', runDir);

zipPath = localBuildZip(runDir);
appendText(run.log_path, sprintf('[%s] complete; zip=%s\n', datestr(now, 31), zipPath));

%% Mirror to repo root (exact output names requested)
mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end
try
    copyfile(fullfile(runDir, 'tables', 'aging_hermetic_closure_models.csv'), ...
        fullfile(mirrorTables, 'aging_hermetic_closure_models.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_hermetic_closure_residuals.csv'), ...
        fullfile(mirrorTables, 'aging_hermetic_closure_residuals.csv'));
    copyfile(fullfile(runDir, 'reports', 'aging_hermetic_closure_report.md'), ...
        fullfile(mirrorRep, 'aging_hermetic_closure_report.md'));
    localMirrorIfExists(figPath1.png, fullfile(mirrorFigs, 'aging_hermetic_predictions.png'));
    localMirrorIfExists(figPath2.png, fullfile(mirrorFigs, 'aging_hermetic_residuals_vs_T.png'));
catch ME
    fprintf(2, 'Mirror copy skipped: %s\n', ME.message);
end

fprintf(1, 'Agent 24I complete. Report: %s\n', fullfile(runDir, 'reports', 'aging_hermetic_closure_report.md'));
end

%% ------------------------------------------------------------------------
function fn = localModelFieldName(modelId)
fn = matlab.lang.makeValidName(['m_' char(strrep(modelId, ' ', '_'))]);
end

function tbl = localResidualsLong(T_K, y, modelIds, yhatStore)
blocks = {};
for i = 1:numel(modelIds)
    mid = modelIds{i};
    yh = yhatStore.(localModelFieldName(mid));
    blocks{end + 1} = table(repmat({mid}, numel(T_K), 1), T_K(:), y(:), yh(:), y(:) - yh(:), ...
        'VariableNames', {'model', 'T_K', 'R', 'yhat_loocv', 'residual'}); %#ok<AGROW>
end
tbl = vertcat(blocks{:});
end

function m = localMeanAbsRes(T, y, yhat, maskFn)
msk = maskFn(T) & isfinite(T(:)) & isfinite(y(:)) & isfinite(yhat(:));
if ~any(msk)
    m = NaN;
else
    m = mean(abs(y(msk) - yhat(msk)), 'omitnan');
end
end

function rm = localGetRmse(rows, id)
idx = strcmp(rows.model, id);
if ~any(idx) || ~isfinite(rows.loocv_rmse(idx, 1))
    rm = NaN;
else
    rm = rows.loocv_rmse(idx, 1);
end
end

function m = localMae22(yhatStore, T, y, id)
if ~isfield(yhatStore, localModelFieldName(id))
    m = NaN;
    return
end
yh = yhatStore.(localModelFieldName(id));
m = localMeanAbsRes(T, y, yh, @(t) t >= 22 & t <= 24);
end

function v = localVerdicts(rows, idRef, idA, idB, idC, modelC_ok, rmseRef, maeRef22, yhatStore, Tplot, y)
v = struct();
thrRmseRel = 3;
thrTransRel = 10;

maeA22 = localMae22(yhatStore, Tplot, y, idA);
maeB22 = localMae22(yhatStore, Tplot, y, idB);
rmseA = localGetRmse(rows, idA);
rmseB = localGetRmse(rows, idB);

v.INTERACTION_TERM_SUPPORTED = localSupportLabel(rmseA, rmseRef, maeA22, maeRef22, thrRmseRel, thrTransRel);
v.LOCAL_TRANSITION_TERM_SUPPORTED = localSupportLabel(rmseB, rmseRef, maeB22, maeRef22, thrRmseRel, thrTransRel);

if modelC_ok && any(strcmp(rows.model, idC)) && isfinite(localGetRmse(rows, idC))
    rmseC = localGetRmse(rows, idC);
    maeC22 = localMae22(yhatStore, Tplot, y, idC);
    v.RESIDUAL_DEFORMATION_TERM_SUPPORTED = localSupportLabel(rmseC, rmseRef, maeC22, maeRef22, thrRmseRel, thrTransRel);
else
    v.RESIDUAL_DEFORMATION_TERM_SUPPORTED = "SKIPPED (alpha_res not available on all overlap rows)";
end

% Global best LOOCV among all fitted models in this run
fin = isfinite(rows.loocv_rmse);
[~, jMin] = min(rows.loocv_rmse(fin));
idxAll = find(fin);
jBest = idxAll(jMin);
bestExtRmse = rows.loocv_rmse(jBest);
bestIdLoocv = rows.model{jBest};
maeBest22 = localMae22(yhatStore, Tplot, y, bestIdLoocv);

improveRmsePct = 100 * (rmseRef - bestExtRmse) / max(rmseRef, eps);
transDropPct = 100 * (maeRef22 - maeBest22) / max(maeRef22, eps);

loocvOk = isfinite(bestExtRmse) && bestExtRmse < rmseRef - 1e-9;
transOk = isfinite(maeBest22) && isfinite(maeRef22) && maeRef22 > 0 && transDropPct >= thrTransRel;
globalOk = improveRmsePct >= thrRmseRel;

anyHerm = false;
for k = 1:height(rows)
    if ~rows.is_extension(k) || ~isfinite(rows.loocv_rmse(k)), continue, end
    pr = 100 * (rmseRef - rows.loocv_rmse(k)) / max(rmseRef, eps);
    pt = 100 * (maeRef22 - rows.mean_abs_res_22_24K(k)) / max(maeRef22, eps);
    if pr >= thrRmseRel && pt >= thrTransRel
        anyHerm = true;
        break
    end
end

if anyHerm
    v.HERMETIC_CLOSURE_ACHIEVED = "YES";
elseif loocvOk && (transOk || globalOk)
    v.HERMETIC_CLOSURE_ACHIEVED = "PARTIAL";
else
    v.HERMETIC_CLOSURE_ACHIEVED = "NO";
end
end

function s = localSupportLabel(rmseNew, rmseRef, mae22New, mae22Ref, thrRmseRel, thrTransRel)
if ~isfinite(rmseNew) || ~isfinite(mae22New)
    s = "NO (model not fitted)";
    return
end
pctRmse = 100 * (rmseRef - rmseNew) / max(rmseRef, eps);
pctTrans = 100 * (mae22Ref - mae22New) / max(mae22Ref, eps);
g = pctRmse >= thrRmseRel;
t = isfinite(mae22Ref) && mae22Ref > 0 && pctTrans >= thrTransRel;
if g && t
    s = "YES";
elseif g || t
    s = "PARTIAL";
else
    s = "NO";
end
end

function txt = localBuildReport(runDir, opts, clkPath, masterOut, rows, idRef, bestId, ...
    rmseRef, bestRmse, pctGlobal, pctBestRmse, maeRef22, maeBest22, transRedPct, verd, ...
    modelC_ok, Tplot, resRef, resBest, figPath1, figPath2, rmseA, rmseB, maeA22, maeB22, rmseC, maeC22)

lines = {};
lines{end + 1} = '# Aging hermetic closure (Agent 24I)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## 1. Question';
lines{end + 1} = 'Does a **single minimal** extension to `R ~ spread90_50 + kappa1 + alpha` close LOOCV error globally and in **22–24 K**, without ad-hoc feature search?';
lines{end + 1} = '';
lines{end + 1} = '## 2. Data (same merge as Agents 24B / 24G)';
lines{end + 1} = sprintf('- **R(T):** `R_T_interp`; clock lineage: `%s`', strrep(clkPath, '\', '/'));
lines{end + 1} = sprintf('- **PT:** `%s`', strrep(opts.barrierPath, '\', '/'));
lines{end + 1} = sprintf('- **Energy join:** `%s`', strrep(opts.energyStatsPath, '\', '/'));
lines{end + 1} = sprintf('- **State / gates:** `%s`, `%s` (`PT_geometry_valid`, `row_valid`)', ...
    strrep(opts.alphaStructurePath, '\', '/'), strrep(opts.decompPath, '\', '/'));
lines{end + 1} = sprintf('- **Overlap:** n = **%d**; finite `R`, `spread90_50`, `kappa1`, `kappa2`, `alpha` (same row set as κ2/α comparisons in 24G).', height(masterOut));
if modelC_ok
    lines{end + 1} = '- **Model C:** `alpha_res` from `alpha_decomposition.csv` present and finite on all overlap rows.';
else
    lines{end + 1} = '- **Model C:** skipped (`alpha_res` missing or not finite on overlap).';
end
lines{end + 1} = sprintf('- **T grid:** `%s`', mat2str(Tplot(:)', 4));
lines{end + 1} = '';
lines{end + 1} = '## 3. Models (LOOCV OLS, intercept)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson(y,ŷ) | mean|res| 22–24 K | mean|res| outside | ΔRMSE vs ref (%) | Δtransition |res| vs ref (%) |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|---:|---:|';
for k = 1:height(rows)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |', ...
        rows.model{k}, rows.n(k), rows.loocv_rmse(k), rows.pearson_y_yhat(k), ...
        rows.mean_abs_res_22_24K(k), rows.mean_abs_res_outside_22_24K(k), ...
        rows.pct_loocv_rmse_vs_reference(k), rows.pct_transition_mean_abs_res_vs_reference(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '**Model B note:** `g(T) = exp(-(T-23)^2/(2·1.5^2))` K; σ = 1.5 K fixed (not fitted).';
lines{end + 1} = '';
lines{end + 1} = '## 4. Global vs transition';
lines{end + 1} = sprintf('- **Reference LOOCV RMSE:** %.6g', rmseRef);
lines{end + 1} = sprintf('- **Best LOOCV model (lowest RMSE):** `%s` (LOOCV RMSE = %.6g)', bestId, bestRmse);
lines{end + 1} = sprintf('- **RMSE_IMPROVED_OVER_BASELINE (best LOOCV vs ref):** %.6g%% reduction', pctBestRmse);
lines{end + 1} = sprintf('- **RMSE change vs reference (signed):** %.6g%% (negative = improvement)', pctGlobal);
lines{end + 1} = sprintf('- **Mean |residual| 22–24 K (for best LOOCV model):** reference = %.6g; best = %.6g (reduction %.6g%% of reference)', ...
    maeRef22, maeBest22, transRedPct);
if modelC_ok && isfinite(rmseC) && isfinite(maeC22)
    pctRmseC = 100 * (rmseRef - rmseC) / max(rmseRef, eps);
    pctTrC = 100 * (maeRef22 - maeC22) / max(maeRef22, eps);
    lines{end + 1} = sprintf(['- **Model C (|alpha_res|):** LOOCV RMSE = %.6g; mean |res| 22–24 K = %.6g ' ...
        '=> **%.6g%%** RMSE gain vs ref, **%.6g%%** transition residual reduction vs ref.'], ...
        rmseC, maeC22, pctRmseC, pctTrC);
end
lines{end + 1} = '';
lines{end + 1} = '## 5. Mechanism readout (22–24 K)';
lines{end + 1} = sprintf('- **Interaction (A):** LOOCV RMSE = %.6g; mean|res| 22–24 = %.6g', rmseA, maeA22);
lines{end + 1} = sprintf('- **Transition bump g(T) (B):** LOOCV RMSE = %.6g; mean|res| 22–24 = %.6g', rmseB, maeB22);
lines{end + 1} = '- **Structured vs random:** compare residual vs T plots (baseline vs best). Systematic curvature or banding in 22–24 K → structured; flat noise → less structured.';
lines{end + 1} = '';
lines{end + 1} = '## 6. Verdicts';
lines{end + 1} = sprintf('- **INTERACTION_TERM_SUPPORTED:** **%s**', char(verd.INTERACTION_TERM_SUPPORTED));
lines{end + 1} = sprintf('- **LOCAL_TRANSITION_TERM_SUPPORTED:** **%s**', char(verd.LOCAL_TRANSITION_TERM_SUPPORTED));
lines{end + 1} = sprintf('- **RESIDUAL_DEFORMATION_TERM_SUPPORTED:** **%s**', char(verd.RESIDUAL_DEFORMATION_TERM_SUPPORTED));
lines{end + 1} = sprintf('- **HERMETIC_CLOSURE_ACHIEVED:** **%s**', char(verd.HERMETIC_CLOSURE_ACHIEVED));
lines{end + 1} = '';
lines{end + 1} = 'Support rule (per term A/B/C): **YES** if LOOCV RMSE improves by ≥3%% *and* mean|res| in 22–24 K drops by ≥10%% vs reference; **PARTIAL** if only one holds; **NO** otherwise.';
lines{end + 1} = '**HERMETIC_CLOSURE_ACHIEVED:** **YES** if *any* extension satisfies both thresholds simultaneously (not necessarily the lowest LOOCV model overall).';
lines{end + 1} = '';
lines{end + 1} = '## Figures';
lines{end + 1} = localFigLine(figPath1, 'aging_hermetic_predictions');
lines{end + 1} = localFigLine(figPath2, 'aging_hermetic_residuals_vs_T');
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_hermetic_closure_agent24i.m`.*';

txt = strjoin(lines, newline);
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'aging_hermetic_closure_agent24i_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0, fwrite(fid, txt); fclose(fid); end
end

function paths = localTrySaveRunFigure(fig, baseName, runDir)
paths = struct('png', '', 'pdf', '', 'fig', '');
try
    paths = save_run_figure(fig, baseName, runDir);
catch ME
    fprintf(2, 'save_run_figure failed for %s: %s\n', baseName, ME.message);
end
end

function localMirrorIfExists(src, dst)
if (ischar(src) || isstring(src)) && strlength(string(src)) > 0 && exist(char(string(src)), 'file') == 2
    copyfile(char(string(src)), dst);
end
end

function s = localFigLine(figPathStruct, label)
p = '';
if isstruct(figPathStruct) && isfield(figPathStruct, 'png')
    p = char(string(figPathStruct.png));
end
if ~isempty(p) && exist(p, 'file') == 2
    s = sprintf('- `%s`', strrep(p, '\', '/'));
else
    s = sprintf('- **%s:** (PNG not written)', label);
end
end

function [rmse, rP, yhat] = localLoocvOls(y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);
rmse = NaN;
rP = NaN;
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
