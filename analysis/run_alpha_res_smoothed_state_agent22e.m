function run_alpha_res_smoothed_state_agent22e(repoRootIn)
%RUN_ALPHA_RES_SMOOTHED_STATE_AGENT22E  Agent 22E — smoothed kappa state → predict alpha_res
%
% Inputs (read-only): tables/alpha_structure.csv, tables/alpha_decomposition.csv
% Outputs:
%   tables/alpha_res_smoothed_models.csv
%   figures/alpha_res_smoothed_fit.png
%   reports/alpha_res_smoothed_report.md
%
% Smoothing: moving average and Savitzky–Golay on kappa1(T), kappa2(T); then
% theta_smooth = atan2(k2s,k1s), delta_theta_smooth = diff(unwrap(theta_smooth)).

if nargin < 1 || isempty(repoRootIn)
    thisFile = mfilename('fullpath');
    analysisDir = fileparts(thisFile);
    repoRoot = fileparts(analysisDir);
else
    repoRoot = char(string(repoRootIn));
end

alphaStructPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
alphaDecPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
outCsv = fullfile(repoRoot, 'tables', 'alpha_res_smoothed_models.csv');
outFig = fullfile(repoRoot, 'figures', 'alpha_res_smoothed_fit.png');
outRep = fullfile(repoRoot, 'reports', 'alpha_res_smoothed_report.md');

assert(exist(alphaStructPath, 'file') == 2, 'Missing %s', alphaStructPath);
assert(exist(alphaDecPath, 'file') == 2, 'Missing %s', alphaDecPath);

if ~local_alpha_structure_csv_ok(alphaStructPath)
    error('run_alpha_res_smoothed_state_agent22e:InvalidAlphaStructure', 'alpha_structure.csv failed precondition: %s', alphaStructPath);
end
if ~local_alpha_decomposition_csv_ok(alphaDecPath)
    error('run_alpha_res_smoothed_state_agent22e:InvalidAlphaDecomposition', 'alpha_decomposition.csv failed precondition: %s', alphaDecPath);
end

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'figures'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

aS = readtable(alphaStructPath, 'VariableNamingRule', 'preserve');
aD = readtable(alphaDecPath, 'VariableNamingRule', 'preserve');
decCols = intersect({'T_K', 'alpha_res', 'PT_geometry_valid'}, aD.Properties.VariableNames, 'stable');
aD2 = aD(:, decCols);

merged = innerjoin(aS, aD2, 'Keys', 'T_K');
merged = merged(isfinite(merged.alpha_res), :);
merged = sortrows(merged, 'T_K');
n = height(merged);
assert(n >= 5, 'Need at least 5 rows with finite alpha_res for smoothing + LOOCV.');

T_K = double(merged.T_K(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
ares = double(merged.alpha_res(:));

% --- Raw state (same as Agent 22B) ---
theta_raw = atan2(k2, k1);
thu_raw = unwrap(theta_raw(:));
dtheta_raw = NaN(n, 1);
if n >= 2
    dtheta_raw(2:end) = diff(thu_raw);
end

% --- Smooth kappa tracks (sorted T assumed) ---
maWindow = min(5, max(3, 2 * floor(n / 6) + 1)); % odd, adaptive for short series
if mod(maWindow, 2) == 0
    maWindow = maWindow + 1;
end
k1_ma = movmean(k1, maWindow, 'Endpoints', 'shrink');
k2_ma = movmean(k2, maWindow, 'Endpoints', 'shrink');

[sgLen, sgOrd] = localSgParams(n);
k1_sg = sgolayfilt(k1, sgOrd, sgLen);
k2_sg = sgolayfilt(k2, sgOrd, sgLen);

[theta_ma, dtheta_ma] = localThetaDthetaFromKappa(k1_ma, k2_ma);
[theta_sg, dtheta_sg] = localThetaDthetaFromKappa(k1_sg, k2_sg);

loocv_naive = localLoocvNaiveMean(ares);
sig_y = std(ares, 0, 'omitnan');

% --- Build model rows ---
rows = table();
modelSpecs = {
    'raw', theta_raw, dtheta_raw;
    'kappa_ma', theta_ma, dtheta_ma;
    'kappa_sg', theta_sg, dtheta_sg
    };

for ms = 1:size(modelSpecs, 1)
    tag = modelSpecs{ms, 1};
    th = modelSpecs{ms, 2};
    dth = modelSpecs{ms, 3};
    % rV = modelSpecs{ms, 4}; % reserved if extended

    row1 = localOlsLoocvReport(sprintf('alpha_res ~ theta (%s)', tag), ares, [ones(n, 1), th(:)]);
    row1.smoothing = repmat({tag}, height(row1), 1);
    row1.predictors = repmat({'theta'}, height(row1), 1);

    if n >= 3
        md = isfinite(dth);
        Xd = [ones(nnz(md), 1), dth(md)];
        row2 = localOlsLoocvReport(sprintf('alpha_res ~ delta_theta (%s)', tag), ares(md), Xd);
        row2.smoothing = repmat({tag}, height(row2), 1);
        row2.predictors = repmat({'delta_theta'}, height(row2), 1);
    else
        row2 = table();
    end

    if n >= 3
        m3 = isfinite(th) & isfinite(dth);
        X3 = [ones(nnz(m3), 1), th(m3), dth(m3)];
        row3 = localOlsLoocvReport(sprintf('alpha_res ~ theta + delta_theta (%s)', tag), ares(m3), X3);
        row3.smoothing = repmat({tag}, height(row3), 1);
        row3.predictors = repmat({'theta+delta_theta'}, height(row3), 1);
    else
        row3 = table();
    end

    rows = [rows; row1]; %#ok<AGROW>
    if ~isempty(row2)
        rows = [rows; row2]; %#ok<AGROW>
    end
    if ~isempty(row3)
        rows = [rows; row3]; %#ok<AGROW>
    end
end

% Flatten for CSV: ensure columns model, smoothing, predictors, n, loocv_rmse, ...
if ~ismember('smoothing', rows.Properties.VariableNames)
    rows.smoothing = repmat({'unknown'}, height(rows), 1);
end
if ~ismember('predictors', rows.Properties.VariableNames)
    rows.predictors = repmat({''}, height(rows), 1);
end

rows.improvement_over_naive_mean = loocv_naive - rows.loocv_rmse;
rows.loocv_naive_mean_bench = repmat(loocv_naive, height(rows), 1);
rows.std_alpha_res = repmat(sig_y, height(rows), 1);

writetable(rows, outCsv);

% --- Best models ---
valid = isfinite(rows.loocv_rmse);
rawMask = valid & strcmp(rows.smoothing, 'raw');
smMask = valid & (strcmp(rows.smoothing, 'kappa_ma') | strcmp(rows.smoothing, 'kappa_sg'));

bestRawRmse = min(rows.loocv_rmse(rawMask), [], 'omitnan');
bestSmoothRmse = min(rows.loocv_rmse(smMask), [], 'omitnan');
[~, ir] = min(rows.loocv_rmse(rawMask), [], 'omitnan');
idxRaw = find(rawMask);
bestRawName = rows.model{idxRaw(ir)};
[~, ism] = min(rows.loocv_rmse(smMask), [], 'omitnan');
idxSm = find(smMask);
bestSmoothName = rows.model{idxSm(ism)};

if isfinite(bestSmoothRmse) && isfinite(bestRawRmse) && (bestSmoothRmse < bestRawRmse - 1e-12)
    flagImprove = 'YES';
else
    flagImprove = 'NO';
end

BEST_SMOOTH_MODEL = bestSmoothName;

% --- Figure: LOOCV parity for best raw vs best smoothed angular model ---
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 900 420]);

ax1 = subplot(1, 2, 1);
localParityPlot(ax1, ares, theta_raw, dtheta_raw, 'raw', bestRawName);
title(ax1, 'Best raw angular model (LOOCV)', 'FontSize', 12);

ax2 = subplot(1, 2, 2);
if contains(bestSmoothName, 'kappa_ma', 'IgnoreCase', true)
    localParityPlot(ax2, ares, theta_ma, dtheta_ma, 'kappa_ma', bestSmoothName);
    st = 'moving average';
else
    localParityPlot(ax2, ares, theta_sg, dtheta_sg, 'kappa_sg', bestSmoothName);
    st = 'Savitzky-Golay';
end
title(ax2, sprintf('Best smoothed model (%s)', st), 'FontSize', 12);

try
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, outFig, 'Resolution', 150);
    else
        print(fig, outFig, '-dpng', '-r150');
    end
catch
    try
        saveas(fig, outFig);
    catch ME2
        warning('Figure export failed: %s', ME2.message);
    end
end
close(fig);

% --- Report ---
fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Smoothed collective state vs alpha_res (Agent 22E)\n\n');
fprintf(fid, '**Goal:** Test whether smoothing `kappa1(T)`, `kappa2(T)` improves linear prediction of `alpha_res` from angular state variables.\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- `tables/alpha_structure.csv`\n');
fprintf(fid, '- `tables/alpha_decomposition.csv`\n\n');
fprintf(fid, '## Construction\n\n');
fprintf(fid, '- Join on `T_K`, keep rows with finite `alpha_res` (same spirit as Agent 22B).\n');
fprintf(fid, '- **Raw:** `theta = atan2(kappa2, kappa1)`, `delta_theta` = forward difference of `unwrap(theta)` along sorted `T_K`.\n');
fprintf(fid, '- **Moving average:** `movmean` on `kappa1`, `kappa2` with window **%d** (odd, endpoints shrink).\n', maWindow);
fprintf(fid, '- **Savitzky–Golay:** `sgolayfilt` with frame length **%d**, polynomial order **%d**.\n', sgLen, sgOrd);
fprintf(fid, '- Recompute `theta_smooth`, `delta_theta_smooth` from smoothed kappas (same atan2 / unwrap / diff recipe).\n\n');

fprintf(fid, '## Models (OLS + LOOCV RMSE)\n\n');
fprintf(fid, '| model | n | LOOCV RMSE | vs naive mean | Pearson(y,yhat) | Spearman | max lev |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(rows)
    fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g |\n', ...
        rows.model{k}, rows.n(k), rows.loocv_rmse(k), rows.improvement_over_naive_mean(k), ...
        rows.pearson_y_yhat(k), rows.spearman_y_yhat(k), rows.max_leverage(k));
end
fprintf(fid, '\n**Smoothing parameters:** movmean window = %d; sgolay framelen = %d, polyorder = %d.\n', ...
    maWindow, sgLen, sgOrd);
fprintf(fid, '\n- **LOOCV naive mean benchmark:** %.6g\n', loocv_naive);
fprintf(fid, '- **std(alpha_res):** %.6g\n', sig_y);
fprintf(fid, '- **CSV `improvement_over_naive_mean`:** naive RMSE minus model LOOCV RMSE (positive means better than naive mean).\n\n');

fprintf(fid, '## Comparison (angular family)\n\n');
fprintf(fid, '- **Best raw LOOCV RMSE:** %.6g (`%s`)\n', bestRawRmse, bestRawName);
fprintf(fid, '- **Best smoothed LOOCV RMSE:** %.6g (`%s`)\n\n', bestSmoothRmse, bestSmoothName);

fprintf(fid, '## Final flags\n\n');
if strcmp(flagImprove, 'YES')
    flagExpl = 'lowest LOOCV RMSE among {MA, SG} angular models is strictly below the best raw angular model';
else
    flagExpl = 'best smoothed LOOCV RMSE is not strictly below the best raw angular model';
end
fprintf(fid, '- **SMOOTHING_IMPROVES_PREDICTION** = **%s** (%s)\n', flagImprove, flagExpl);
fprintf(fid, '- **BEST_SMOOTH_MODEL** = **%s**\n\n', BEST_SMOOTH_MODEL);
fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `tables/alpha_res_smoothed_models.csv`\n');
fprintf(fid, '- `figures/alpha_res_smoothed_fit.png`\n\n');
fprintf(fid, '*Auto-generated by `analysis/run_alpha_res_smoothed_state_agent22e.m`.*\n');
fclose(fid);

fprintf('Wrote:\n  %s\n  %s\n  %s\n', outCsv, outFig, outRep);
fprintf('SMOOTHING_IMPROVES_PREDICTION = %s\nBEST_SMOOTH_MODEL = %s\n', flagImprove, BEST_SMOOTH_MODEL);
end

%% --- helpers ---

function [theta, dtheta] = localThetaDthetaFromKappa(k1, k2)
k1 = double(k1(:));
k2 = double(k2(:));
n = numel(k1);
theta = atan2(k2, k1);
thu = unwrap(theta);
dtheta = NaN(n, 1);
if n >= 2
    dtheta(2:end) = diff(thu);
end
end

function [framelen, polyorder] = localSgParams(n)
polyorder = 2;
candidates = [7, 5, 3];
framelen = 3;
for c = candidates
    if c <= n && mod(c, 2) == 1 && c >= polyorder + 2
        framelen = c;
        break
    end
end
if framelen > n
    framelen = max(3, 2 * floor(n / 2) - 1);
end
if mod(framelen, 2) == 0
    framelen = framelen - 1;
end
framelen = max(3, min(framelen, n));
if polyorder >= framelen
    polyorder = max(1, framelen - 2);
end
end

function row = localOlsLoocvReport(name, y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
if n < p || rank(X) < p
    row = table({char(name)}, n, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', 'max_leverage'});
    return
end
beta = X \ y;
yhat = X * beta;
e = y - yhat;
Hmat = X * ((X' * X) \ X');
h = diag(Hmat);
loo_e = e ./ max(1 - h, 1e-12);
loocv_rmse = sqrt(mean(loo_e.^2, 'omitnan'));
pear = corr(y, yhat, 'rows', 'complete');
spear = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
maxlev = max(h);
row = table({char(name)}, n, loocv_rmse, pear, spear, maxlev, ...
    'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', 'max_leverage'});
end

function v = localLoocvNaiveMean(y)
y = double(y(:));
n = numel(y);
if n < 2
    v = NaN;
    return
end
err = NaN(n, 1);
for i = 1:n
    mu = mean(y(setdiff(1:n, i)));
    err(i) = y(i) - mu;
end
v = sqrt(mean(err.^2));
end

function yhat_loo = localLoocvYhat(y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
if n < p || rank(X) < p
    yhat_loo = NaN(n, 1);
    return
end
beta = X \ y;
yhat = X * beta;
e = y - yhat;
Hmat = X * ((X' * X) \ X');
h = diag(Hmat);
loo_e = e ./ max(1 - h, 1e-12);
yhat_loo = y - loo_e;
end

function localParityPlot(ax, ares, theta_v, dtheta_v, ~, modelName)
% LOOCV parity: actual vs leave-one-out prediction
ares = double(ares(:));
yhat = NaN(size(ares));
if contains(modelName, 'theta + delta_theta')
    m = isfinite(theta_v) & isfinite(dtheta_v);
    X = [ones(nnz(m), 1), theta_v(m), dtheta_v(m)];
    yhat(m) = localLoocvYhat(ares(m), X);
elseif contains(modelName, 'delta_theta')
    m = isfinite(dtheta_v);
    X = [ones(nnz(m), 1), dtheta_v(m)];
    yhat(m) = localLoocvYhat(ares(m), X);
else
    m = isfinite(theta_v);
    X = [ones(nnz(m), 1), theta_v(m)];
    yhat(m) = localLoocvYhat(ares(m), X);
end
hold(ax, 'on');
scatter(ax, ares, yhat, 50, 'filled', 'MarkerFaceAlpha', 0.75);
mn = min([ares; yhat], [], 'omitnan');
mx = max([ares; yhat], [], 'omitnan');
if ~(isfinite(mn) && isfinite(mx))
    mn = -1;
    mx = 1;
end
pad = 0.05 * (mx - mn + eps);
plot(ax, [mn - pad, mx + pad], [mn - pad, mx + pad], 'k--', 'LineWidth', 1);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, '\alpha_{res} (actual)');
ylabel(ax, '\alpha_{res} (LOOCV pred.)');
subtitle(ax, strrep(modelName, '_', '\_'), 'FontSize', 9);
axis(ax, 'equal');
lims = [mn - pad, mx + pad];
xlim(ax, lims);
ylim(ax, lims);
end

function tf = local_alpha_structure_csv_ok(path)
tf = false;
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve');
    req = {'T_K', 'kappa1', 'kappa2'};
    if ~all(ismember(req, tbl.Properties.VariableNames))
        return;
    end
    tf = height(tbl) >= 5;
catch
    tf = false;
end
end

function tf = local_alpha_decomposition_csv_ok(path)
tf = false;
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve');
    req = {'T_K', 'alpha_res', 'PT_geometry_valid'};
    if ~all(ismember(req, tbl.Properties.VariableNames))
        return;
    end
    tf = height(tbl) >= 5;
catch
    tf = false;
end
end
