function run_alpha_decomposition_agent21a()
%RUN_ALPHA_DECOMPOSITION_AGENT21A  Agent 21A — alpha = alpha_geom + alpha_res (PT geometry)
%
% Read-only: tables/alpha_structure.csv, canonical PT_matrix.csv.
% Writes: tables/alpha_decomposition.csv, figures/alpha_res_vs_T.png,
%         reports/alpha_decomposition_report.md
%
% Geometry law (OLS on full PT-valid rows):
%   alpha_geom = beta0 + beta1*spread90_50 + beta2*asymmetry

repoRoot = fileparts(fileparts(mfilename('fullpath')));
alphaPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
ptRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_25_013356_pt_robust_canonical');
ptMatrixPath = fullfile(ptRunDir, 'tables', 'PT_matrix.csv');
outCsv = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
outFig = fullfile(repoRoot, 'figures', 'alpha_res_vs_T.png');
outRep = fullfile(repoRoot, 'reports', 'alpha_decomposition_report.md');

assert(exist(alphaPath, 'file') == 2, 'Missing %s', alphaPath);
assert(exist(ptMatrixPath, 'file') == 2, 'Missing %s', ptMatrixPath);

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'figures'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

aTbl = readtable(alphaPath, 'VariableNamingRule', 'preserve');
[temps, currents, PT] = localLoadPTMatrix(ptMatrixPath);

nA = height(aTbl);
spread90_50 = NaN(nA, 1);
asymmetry = NaN(nA, 1);

for it = 1:nA
    TK = double(aTbl.T_K(it));
    [~, ip] = ismember(TK, temps);
    if ip < 1
        continue
    end
    pRow = PT(ip, :);
    if ~localRowValidPT(pRow)
        continue
    end
    obs = localPTGeometryObservables(currents(:), pRow(:));
    spread90_50(it) = obs.spread90_50;
    asymmetry(it) = obs.asymmetry;
end

alpha = double(aTbl.alpha(:));
T_K = double(aTbl.T_K(:));

mFit = isfinite(alpha) & isfinite(spread90_50) & isfinite(asymmetry);
Xf = [ones(nnz(mFit), 1), spread90_50(mFit), asymmetry(mFit)];
yf = alpha(mFit);
beta = Xf \ yf;

alpha_geom = NaN(nA, 1);
alpha_geom(mFit) = [ones(nnz(mFit), 1), spread90_50(mFit), asymmetry(mFit)] * beta;
alpha_res = alpha - alpha_geom;

% Variance explained (R^2) on fit rows
yhat_f = Xf * beta;
ss_res = sum((yf - yhat_f).^2);
ss_tot = sum((yf - mean(yf)).^2);
if ss_tot > 0
    r2 = 1 - ss_res / ss_tot;
else
    r2 = NaN;
end

mean_res = mean(alpha_res(mFit), 'omitnan');
std_res = std(alpha_res(mFit), 0, 'omitnan');
std_alpha_fit = std(yf, 0, 'omitnan');

% 22–24 K band characterization (PT-valid rows)
bandT = (T_K >= 22) & (T_K <= 24) & mFit;
outsideT = mFit & ~bandT;
abs_in = abs(alpha_res(bandT));
abs_out = abs(alpha_res(outsideT));
rms_band = sqrt(mean(alpha_res(bandT).^2, 'omitnan'));
rms_out = sqrt(mean(alpha_res(outsideT).^2, 'omitnan'));
T_valid = T_K(mFit);
ar_fit = alpha_res(mFit);
[~, imax] = max(abs(ar_fit));
peak_T = T_valid(imax);

% Local anomaly: band mean |res| vs outside
mean_abs_in = mean(abs_in, 'omitnan');
mean_abs_out = mean(abs_out, 'omitnan');

% Flags (documented thresholds in report)
ALPHA_HAS_GEOM_COMPONENT = 'NO';
if isfinite(r2) && r2 >= 0.15
    ALPHA_HAS_GEOM_COMPONENT = 'YES';
end

ALPHA_HAS_RESIDUAL_COMPONENT = 'NO';
if isfinite(std_res) && (std_res >= 0.12 * std_alpha_fit || std_res >= 0.08)
    ALPHA_HAS_RESIDUAL_COMPONENT = 'YES';
end

RESIDUAL_CONCENTRATED_AT_22K = 'NO';
if nnz(bandT) >= 1 && nnz(outsideT) >= 1
    if mean_abs_in > 1.25 * mean_abs_out || rms_band > 1.35 * rms_out
        RESIDUAL_CONCENTRATED_AT_22K = 'YES';
    end
end
% Peak |residual| in the 22–24 K window (or adjacent 21–25 K band)
if peak_T >= 21 && peak_T <= 25
    RESIDUAL_CONCENTRATED_AT_22K = 'YES';
end

outTbl = table(T_K, alpha, spread90_50, asymmetry, alpha_geom, alpha_res, mFit, ...
    'VariableNames', {'T_K', 'alpha', 'spread90_50', 'asymmetry', 'alpha_geom', 'alpha_res', 'PT_geometry_valid'});
writetable(outTbl, outCsv);

% Figure: alpha_res vs T (PT-valid rows)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 640 420]);
ax = axes(fig);
yl = max(1e-6, max(abs(ar_fit)) * 1.15);
hold(ax, 'on');
fill(ax, [22 24 24 22], [-yl -yl yl yl], [1 0.88 0.88], ...
    'FaceAlpha', 0.35, 'EdgeColor', 'none');
scatter(ax, T_K(mFit), ar_fit, 40, [0.12 0.32 0.62], 'filled');
plot(ax, [min(T_K(mFit)) max(T_K(mFit))], [0 0], 'k:', 'LineWidth', 0.8);
ylim(ax, [-yl yl]);
xlabel(ax, 'T (K)');
ylabel(ax, '\alpha_{res}');
title(ax, 'Alpha residual vs temperature (shaded: 22–24 K)');
grid(ax, 'on');
hold(ax, 'off');
try
    exportgraphics(fig, outFig, 'Resolution', 150);
catch
    saveas(fig, outFig);
end
close(fig);

formulaStr = sprintf('alpha_{geom} = %.6g + %.6g*spread90_50 + %.6g*asymmetry', ...
    beta(1), beta(2), beta(3));

fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Alpha decomposition — geometry + residual (Agent 21A)\n\n');
fprintf(fid, '**Goal:** `alpha = alpha_geom + alpha_res` with `alpha_geom` from PT geometry.\n\n');
fprintf(fid, '- **alpha:** `%s`\n', strrep(alphaPath, '\', '/'));
fprintf(fid, '- **PT_matrix:** `%s`\n\n', strrep(ptMatrixPath, '\', '/'));
fprintf(fid, '**Note:** `spread90_50` and `asymmetry` are computed from normalized PMF rows of `PT_matrix` (same discrete-quantile construction as `analysis/run_alpha_from_pt_agent20b.m`). If `tables/alpha_from_PT.csv` was built from an older PT export, its feature columns may not match; this decomposition always uses the canonical `PT_matrix.csv` above.\n\n');

fprintf(fid, '## Geometry model (OLS on full PT-valid dataset)\n\n');
fprintf(fid, '- **Formula:** %s\n', formulaStr);
fprintf(fid, '- **Fit rows (n):** %d\n', nnz(mFit));
fprintf(fid, '- **Coefficients:** beta0 = %.8g, beta1 = %.8g, beta2 = %.8g\n', beta(1), beta(2), beta(3));

fprintf(fid, '\n## Residual characterization (PT-valid rows)\n\n');
fprintf(fid, '- **mean(alpha_res):** %.8g\n', mean_res);
fprintf(fid, '- **std(alpha_res):** %.8g\n', std_res);
fprintf(fid, '- **Fraction of variance explained by alpha_geom (R^2):** %.8g\n', r2);
fprintf(fid, '- **std(alpha) on same rows:** %.8g\n', std_alpha_fit);

fprintf(fid, '\n## Temperature structure (22–24 K)\n\n');
fprintf(fid, '- **RMS(alpha_res) in [22,24] K (PT-valid):** %.8g\n', rms_band);
fprintf(fid, '- **RMS(alpha_res) outside [22,24] K (PT-valid):** %.8g\n', rms_out);
fprintf(fid, '- **mean(|alpha_res|) in band:** %.8g; **outside:** %.8g\n', mean_abs_in, mean_abs_out);
fprintf(fid, '- **T at max |alpha_res| (PT-valid):** %.4g K\n', peak_T);

fprintf(fid, '\n## Artifacts\n\n');
fprintf(fid, '- Table: `tables/alpha_decomposition.csv`\n');
fprintf(fid, '- Figure: `figures/alpha_res_vs_T.png`\n\n');

fprintf(fid, '## Final flags\n\n');
fprintf(fid, '- **ALPHA_HAS_GEOM_COMPONENT** = **%s**\n', ALPHA_HAS_GEOM_COMPONENT);
fprintf(fid, '- **ALPHA_HAS_RESIDUAL_COMPONENT** = **%s**\n', ALPHA_HAS_RESIDUAL_COMPONENT);
fprintf(fid, '- **RESIDUAL_CONCENTRATED_AT_22K** = **%s**\n', RESIDUAL_CONCENTRATED_AT_22K);
fprintf(fid, '\n*Auto-generated by `analysis/run_alpha_decomposition_agent21a.m`.*\n');
fclose(fid);

fprintf('Wrote:\n  %s\n  %s\n  %s\n', outCsv, outFig, outRep);
end

%% --- local copies (match run_alpha_from_pt_agent20b) ---

function obs = localPTGeometryObservables(I, p)
p = double(p(:));
I = double(I(:));
obs = struct('spread90_50', NaN, 'spread75_25', NaN, 'asymmetry', NaN, ...
    'skew_weighted', NaN, 'mean_minus_median', NaN, 'I_peak_mA', NaN);
s = sum(p);
if ~(s > 0) || all(~isfinite(p))
    return
end
pn = p / s;
mu = sum(I .* pn);
q25 = localDiscreteQuantile(I, pn, 0.25);
q50 = localDiscreteQuantile(I, pn, 0.50);
q75 = localDiscreteQuantile(I, pn, 0.75);
q90 = localDiscreteQuantile(I, pn, 0.90);
v2 = sum(pn .* (I - mu).^2);
v3 = sum(pn .* (I - mu).^3);
sig = sqrt(max(v2, 0));
obs.spread90_50 = q90 - q50;
obs.spread75_25 = q75 - q25;
obs.asymmetry = (q90 - q50) - (q50 - q25);
obs.mean_minus_median = mu - q50;
if sig > 1e-12
    obs.skew_weighted = v3 / (sig^3);
else
    obs.skew_weighted = NaN;
end
[~, imx] = max(pn);
obs.I_peak_mA = I(imx);
end

function q = localDiscreteQuantile(I, p, u)
c = cumsum(p);
if u <= c(1)
    q = I(1);
    return
end
if u >= c(end)
    q = I(end);
    return
end
idx = find(c >= u, 1, 'first');
if idx <= 1
    q = I(1);
    return
end
c0 = c(idx - 1);
c1 = c(idx);
if c1 <= c0
    q = I(idx);
    return
end
t = (u - c0) / (c1 - c0);
q = I(idx - 1) + t * (I(idx) - I(idx - 1));
end

function ok = localRowValidPT(pRow)
pRow = double(pRow(:));
ok = all(isfinite(pRow)) && sum(pRow) > 1e-12;
end

function [temps, currents, PT] = localLoadPTMatrix(ptMatrixPath)
tbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
assert(ismember('T_K', tbl.Properties.VariableNames), 'T_K missing');
vn = tbl.Properties.VariableNames;
ptNames = setdiff(vn, {'T_K'}, 'stable');
temps = double(tbl.T_K(:));
PT = double(table2array(tbl(:, ptNames)));
currents = localParseCurrents(ptNames);
[currents, io] = sort(currents(:), 'ascend');
PT = PT(:, io);
[temps, it] = sort(temps(:), 'ascend');
PT = PT(it, :);
end

function currents = localParseCurrents(varNames)
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
    for kk = 1:numel(candidates)
        val = str2double(candidates(kk));
        if isfinite(val)
            break
        end
    end
    assert(isfinite(val), 'Parse fail %s', vName);
    currents(i) = val;
end
end
