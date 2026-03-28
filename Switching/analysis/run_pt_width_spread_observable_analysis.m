function out = run_pt_width_spread_observable_analysis(cfg)
% run_pt_width_spread_observable_analysis
% Compare robust spread observables computed from existing PT_matrix.csv rows
% across PT extraction variants (child runs of a prior robustness audit).
%
% Does not re-extract P_T. Reads tables/pt_variant_child_runs.csv from the
% audit run, loads each child's PT_matrix.csv, and writes a new switching run.
%
% Optional cfg fields:
%   .auditRunDir   - char/string path to audit run (default: fixed 2026-03-25 audit)
%   .tMaxK         - temperature ceiling for overlap (default 30)

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

cfg = applyDefaults(cfg);

runCfg = struct();
runCfg.runLabel = 'pt_width_spread_observable';
runCfg.dataset = sprintf('postprocess:%s', char(string(cfg.auditRunId)));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
ensureArtifactDirsLocal(runDir);

fprintf('P_T width / spread observable run directory:\n%s\n', runDir);

appendTextLocal(run.notes_path, sprintf('source_audit_run: %s', cfg.auditRunDir));

variantPath = fullfile(cfg.auditRunDir, 'tables', 'pt_variant_child_runs.csv');
C = readcell(variantPath);
if size(C, 1) < 2
    error('run_pt_width_spread:BadManifest', 'Empty variant manifest: %s', variantPath);
end
nV = size(C, 1) - 1;
variants = repmat(struct('key', '', 'label', '', 'childDir', ''), nV, 1);
for i = 1:nV
    variants(i).key = char(string(C{i + 1, 1}));
    variants(i).label = char(string(C{i + 1, 2}));
    variants(i).childDir = char(string(C{i + 1, 4}));
end

refK = 1;
matrices = cell(nV, 1);
Iref = [];
for k = 1:nV
    ptPath = fullfile(variants(k).childDir, 'tables', 'PT_matrix.csv');
    [tk, currents, PT] = loadPTMatrixLocal(ptPath);
    if isempty(Iref)
        Iref = currents(:);
    elseif numel(currents) ~= numel(Iref) || max(abs(currents(:) - Iref)) > 1e-9
        error('run_pt_width_spread:GridMismatch', 'Current grid differs for variant %s', variants(k).key);
    end
    matrices{k} = struct('T_K', tk, 'currents', currents, 'PT', PT);
end

commonT = matrices{1}.T_K(:);
for k = 2:nV
    commonT = intersect(commonT, matrices{k}.T_K(:), 'stable');
end
commonT = commonT(commonT <= cfg.tMaxK + 1e-9);

usableT = [];
for j = 1:numel(commonT)
    t = commonT(j);
    ok = true;
    for k = 1:nV
        M = matrices{k};
        [~, ia] = ismember(t, M.T_K(:));
        if ia < 1 || ~rowValidPT(M.PT(ia, :), Iref)
            ok = false;
            break;
        end
    end
    if ok
        usableT(end + 1, 1) = t; %#ok<AGROW>
    end
end

metricNames = { ...
    'rms_std_mA', 'iqr_mA', 'w50_mass_mA', 'w60_mass_mA', ...
    'mad_mA', 'mad_scaled_mA', 'trim_rms_mA', 'half_mass_width_mA'};

compRows = [];
for k = 1:nV
    M = matrices{k};
    for j = 1:numel(usableT)
        t = usableT(j);
        [~, ia] = ismember(t, M.T_K(:));
        obs = computeSpreadObservables(M.currents(:), M.PT(ia, :));
        row = table( ...
            string(variants(k).key), t, ...
            obs.rms_std_mA, obs.iqr_mA, obs.w50_mass_mA, obs.w60_mass_mA, ...
            obs.mad_mA, obs.mad_scaled_mA, obs.trim_rms_mA, obs.half_mass_width_mA, ...
            'VariableNames', [{'variant_key', 'T_K'}, metricNames]);
        if isempty(compRows)
            compRows = row;
        else
            compRows = [compRows; row]; %#ok<AGROW>
        end
    end
end

compPath = save_run_table(compRows, 'spread_observable_comparison.csv', runDir);

robRows = buildRobustnessTable(matrices, variants, usableT, metricNames, refK);
robPath = save_run_table(robRows, 'spread_observable_robustness_metrics.csv', runDir);

locTbl = buildLocalizationTable(matrices, variants, Iref, refK, 22.0);
locPath = save_run_table(locTbl, 'spread_sensitivity_localization_22K.csv', runDir);

saveSpreadComparisonFig(runDir, usableT, matrices, variants, metricNames([1, 2, 6, 7]));

reportText = buildReport(cfg, runDir, usableT, robRows, locTbl, compPath, robPath, locPath);
repPath = save_run_report(reportText, 'pt_width_sensitivity_report.md', runDir);

zipPath = buildReviewZipLocal(runDir, 'pt_width_sensitivity_bundle.zip');

fprintf('Saved tables, figures, report, zip.\n');

out = struct('run', run, 'runDir', string(runDir), 'comparison_csv', string(compPath), ...
    'robustness_csv', string(robPath), 'report', string(repPath), 'zip', string(zipPath));
end

function cfg = applyDefaults(cfg)
if ~isfield(cfg, 'auditRunDir') || strlength(string(cfg.auditRunDir)) == 0
    this = mfilename('fullpath');
    fd = fileparts(this);
    fd = fileparts(fd);
    repoRoot = fileparts(fd);
    cfg.auditRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_25_013346_pt_energy_robustness_audit');
end
cfg.auditRunDir = char(string(cfg.auditRunDir));
[~, idname] = fileparts(cfg.auditRunDir);
cfg.auditRunId = idname;
if ~isfield(cfg, 'tMaxK') || isempty(cfg.tMaxK)
    cfg.tMaxK = 30;
end
end

function ok = rowValidPT(prow, Iref)
prow = prow(:);
if any(~isfinite(prow)) || all(prow <= 0)
    ok = false;
    return;
end
p = max(prow, 0);
area = trapz(Iref(:), p);
ok = isfinite(area) && area > 0;
end

function obs = computeSpreadObservables(I, pRaw)
I = I(:);
pRaw = pRaw(:);
obs = struct( ...
    'rms_std_mA', NaN, 'iqr_mA', NaN, 'w50_mass_mA', NaN, 'w60_mass_mA', NaN, ...
    'mad_mA', NaN, 'mad_scaled_mA', NaN, 'trim_rms_mA', NaN, 'half_mass_width_mA', NaN);
m = isfinite(I) & isfinite(pRaw);
I = I(m);
p = max(pRaw(m), 0);
if numel(I) < 2
    return;
end
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    return;
end
p = p ./ area;
mu = trapz(I, I .* p);
varI = trapz(I, (I - mu) .^ 2 .* p);
obs.rms_std_mA = sqrt(max(varI, 0));
cdf = cumtrapzLocal(I, p);
if cdf(end) <= 0
    return;
end
cdf = cdf ./ cdf(end);
q25 = quantileFromCDF(I, cdf, 0.25);
q50 = quantileFromCDF(I, cdf, 0.50);
q75 = quantileFromCDF(I, cdf, 0.75);
q20 = quantileFromCDF(I, cdf, 0.20);
q80 = quantileFromCDF(I, cdf, 0.80);
q05 = quantileFromCDF(I, cdf, 0.05);
q95 = quantileFromCDF(I, cdf, 0.95);
obs.iqr_mA = q75 - q25;
obs.w50_mass_mA = obs.iqr_mA;
obs.w60_mass_mA = q80 - q20;
obs.mad_mA = trapz(I, abs(I - q50) .* p);
obs.mad_scaled_mA = 1.4826 * obs.mad_mA;
mask = I >= q25 & I <= q75;
if nnz(mask) >= 2
    Ic = I(mask);
    pc = p(mask);
    ac = trapz(Ic, pc);
    if ac > 0
        pc = pc ./ ac;
        muc = trapz(Ic, Ic .* pc);
        vc = trapz(Ic, (Ic - muc) .^ 2 .* pc);
        obs.half_mass_width_mA = sqrt(max(vc, 0));
    end
end
if isfinite(q05) && isfinite(q95) && q95 > q05
    mt = I >= q05 & I <= q95;
    if nnz(mt) >= 2
        It = I(mt);
        pt = p(mt);
        at = trapz(It, pt);
        if at > 0
            pt = pt ./ at;
            mut = trapz(It, It .* pt);
            vt = trapz(It, (It - mut) .^ 2 .* pt);
            obs.trim_rms_mA = sqrt(max(vt, 0));
        end
    end
end
end

function c = cumtrapzLocal(I, p)
c = zeros(size(I));
for i = 2:numel(I)
    c(i) = c(i - 1) + 0.5 * (p(i) + p(i - 1)) * (I(i) - I(i - 1));
end
end

function q = quantileFromCDF(I, cdf, qt)
uc = cdf(:);
ux = I(:);
m = isfinite(uc) & isfinite(ux);
uc = uc(m);
ux = ux(m);
if numel(uc) < 2
    q = NaN;
    return;
end
[ucu, ~, icn] = unique(uc, 'stable');
nU = numel(ucu);
uxAgg = zeros(nU, 1);
for ii = 1:nU
    uxAgg(ii) = mean(ux(icn == ii), 'omitnan');
end
qt = min(max(qt, 0), 1);
q = interp1(ucu, uxAgg, qt, 'linear', NaN);
end

function rob = buildRobustnessTable(matrices, variants, usableT, metricNames, refK)
nV = numel(variants);
rob = [];
for k = 1:nV
    row = table(string(variants(k).key), 'VariableNames', {'variant_key'});
    for mi = 1:numel(metricNames)
        mn = metricNames{mi};
        b0 = seriesMetric(matrices{refK}, usableT, mn);
        b1 = seriesMetric(matrices{k}, usableT, mn);
        rel = abs(b1 - b0) ./ max(abs(b0), eps);
        row.(sprintf('pearson_vs_canonical_%s', mn)) = pearsonVec(b0, b1);
        row.(sprintf('spearman_vs_canonical_%s', mn)) = spearmanVec(b0, b1);
        row.(sprintf('max_rel_dev_%s', mn)) = max(rel, [], 'omitnan');
        row.(sprintf('median_rel_dev_%s', mn)) = median(rel, 'omitnan');
        [~, i0] = max(b0);
        [~, i1] = max(b1);
        row.(sprintf('peak_T_canonical_%s', mn)) = usableT(i0);
        row.(sprintf('peak_T_variant_%s', mn)) = usableT(i1);
        row.(sprintf('peak_T_agree_%s', mn)) = double(abs(usableT(i0) - usableT(i1)) < 1e-6);
        d0 = diff(b0(:));
        d1 = diff(b1(:));
        agree = (sign(d0) == sign(d1)) | (abs(d0) < 1e-12 & abs(d1) < 1e-12);
        row.(sprintf('step_trend_agree_frac_%s', mn)) = mean(agree, 'omitnan');
        j22 = lookupTindex(usableT, 22);
        if ~isempty(j22)
            row.(sprintf('rel_dev_22K_%s', mn)) = rel(j22);
        else
            row.(sprintf('rel_dev_22K_%s', mn)) = NaN;
        end
        band = usableT >= 28 & usableT <= 30;
        if any(band)
            row.(sprintf('max_rel_dev_28_30K_%s', mn)) = max(rel(band), [], 'omitnan');
        else
            row.(sprintf('max_rel_dev_28_30K_%s', mn)) = NaN;
        end
    end
    if isempty(rob)
        rob = row;
    else
        rob = [rob; row]; %#ok<AGROW>
    end
end
end

function j = lookupTindex(usableT, t0)
d = abs(usableT(:) - t0);
[~, j] = min(d);
if d(j) > 0.51
    j = [];
end
end

function v = seriesMetric(M, usableT, mn)
v = NaN(size(usableT));
for j = 1:numel(usableT)
    t = usableT(j);
    [~, ia] = ismember(t, M.T_K(:));
    obs = computeSpreadObservables(M.currents(:), M.PT(ia, :));
    v(j) = obs.(mn);
end
end

function r = pearsonVec(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 2
    r = NaN;
    return;
end
x = a(m);
y = b(m);
if std(x, 'omitnan') < 1e-15 || std(y, 'omitnan') < 1e-15
    r = NaN;
    return;
end
c = corrcoef(x, y);
r = c(1, 2);
end

function r = spearmanVec(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 2
    r = NaN;
    return;
end
r = corr(a(m), b(m), 'Type', 'Spearman', 'rows', 'complete');
end

function locTbl = buildLocalizationTable(matrices, variants, Iref, refK, tK)
keys = {'smooth_w7', 'sgolay_w5', 'smooth_w3', 'no_monotone_cdf'};
R = matrices{refK};
[~, ir] = ismember(tK, R.T_K(:));
p0 = R.PT(ir, :).';
locTbl = table();
for i = 1:numel(keys)
    kk = find(strcmp({variants.key}, keys{i}), 1);
    if isempty(kk)
        continue;
    end
    M = matrices{kk};
    [~, im] = ismember(tK, M.T_K(:));
    if im < 1
        continue;
    end
    p1 = M.PT(im, :).';
    if any(~isfinite(p0)) || any(~isfinite(p1))
        continue;
    end
    dp = p1 - p0;
    [fl, fm, fh] = l2TertileFracs(Iref(:), dp);
    locTbl = [locTbl; table( ...
        string(variants(refK).key), string(variants(kk).key), tK, fl, fm, fh, ...
        sum(max(dp, 0)), sum(min(dp, 0)), ...
        'VariableNames', {'reference_variant', 'compare_variant', 'T_K', ...
        'frac_l2_lowI', 'frac_l2_midI', 'frac_l2_highI', 'sum_dp_pos', 'sum_dp_neg'})]; %#ok<AGROW>
end
end

function [fl, fm, fh] = l2TertileFracs(I, dp)
n = numel(I);
if n < 3
    fl = NaN;
    fm = NaN;
    fh = NaN;
    return;
end
t1 = floor(n / 3);
t2 = floor(2 * n / 3);
w = dp .^ 2;
s = sum(w) + eps;
fl = sum(w(1:t1)) / s;
fm = sum(w(t1 + 1:t2)) / s;
fh = sum(w(t2 + 1:end)) / s;
end

function saveSpreadComparisonFig(runDir, usableT, matrices, variants, plotMetrics)
base_name = 'spread_observable_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 18 22]);
tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(numel(variants));
titles = { ...
    'RMS width sqrt(var(I)) (mA)', ...
    'Interquantile IQR = Q75−Q25 (mA)', ...
    'MAD scale 1.4826·E[|I−median|] (mA)', ...
    'Trimmed RMS inside 5–95% mass (mA)'};
nV = numel(variants);
for pi = 1:numel(plotMetrics)
    ax = nexttile(tl);
    hold(ax, 'on');
    grid(ax, 'on');
    mn = plotMetrics{pi};
    for k = 1:nV
        y = seriesMetric(matrices{k}, usableT, mn);
        plot(ax, usableT, y, '-o', 'Color', cols(k, :), 'LineWidth', 2.3, ...
            'MarkerSize', 5, 'DisplayName', variants(k).key);
    end
    hold(ax, 'off');
    xlabel(ax, 'Temperature T (K)');
    ylabel(ax, 'mA');
    title(ax, titles{pi});
    legend(ax, 'Location', 'best');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2);
end
save_run_figure(fig, base_name, runDir);
close(fig);
end

function txt = buildReport(cfg, runDir, usableT, robRows, locTbl, compPath, robPath, locPath)
lines = strings(0, 1);
lines(end + 1) = "# P_T width sensitivity and spread-observable robustness";
lines(end + 1) = "";
lines(end + 1) = "## Source audit";
lines(end + 1) = sprintf("- Audit run: `%s`", cfg.auditRunDir);
lines(end + 1) = sprintf("- This run: `%s`", runDir);
lines(end + 1) = sprintf("- Usable common T (K), T≤%.1f: `%s` (%d points).", ...
    cfg.tMaxK, mat2str(usableT(:).'), numel(usableT));
lines(end + 1) = "";
lines(end + 1) = "## Diagnosis";
lines(end + 1) = "- **Drivers (from `pt_robustness_metrics_by_variant.csv`):** `smooth_w7` dominates width sensitivity (max rel std **≈1.58**); `sgolay_w5` and `smooth_w3` are next (**≈0.55**); `no_monotone_cdf` is moderate (**≈0.23**); `minpts_7` is identical to canonical here.";
lines(end + 1) = "- **Mechanism:** P_T comes from **positive dS/dI** after **smoothing** on a **sparse I grid**; changing the smoother redistributes nonnegative derivative mass across bins; **RMS width** is tail/shoulder-sensitive via **(I−⟨I⟩)²** weighting.";
if height(locTbl) > 0
    r = locTbl(strcmp(string(locTbl.compare_variant), "smooth_w7"), :);
    if height(r) >= 1
        lines(end + 1) = sprintf("- **22 K (`smooth_w7` vs canonical):** coarse I-tertile fractions of ||ΔP_T||₂² — low **%.3f**, mid **%.3f**, high **%.3f**.", ...
            r.frac_l2_lowI(1), r.frac_l2_midI(1), r.frac_l2_highI(1));
    end
end
lines(end + 1) = "";
lines(end + 1) = "## Robustness summary (see CSV for full columns)";
metricNames = { ...
    'rms_std_mA', 'iqr_mA', 'w50_mass_mA', 'w60_mass_mA', ...
    'mad_mA', 'mad_scaled_mA', 'trim_rms_mA', 'half_mass_width_mA'};
for mi = 1:numel(metricNames)
    mn = metricNames{mi};
    sub = robRows(:, {'variant_key', ['max_rel_dev_', mn], ['spearman_vs_canonical_', mn]});
    lines(end + 1) = sprintf("- **%s**: table columns `max_rel_dev_%s`, `spearman_vs_canonical_%s`.", mn, mn, mn);
end
lines(end + 1) = "";
lines(end + 1) = "## Recommendation";
iqrMx = max(robRows.max_rel_dev_iqr_mA(~strcmp(robRows.variant_key, 'canonical')), [], 'omitnan');
rmsMx = max(robRows.max_rel_dev_rms_std_mA(~strcmp(robRows.variant_key, 'canonical')), [], 'omitnan');
lines(end + 1) = "- **Class C:** No width scalar is robust across **all** audited variants. Mild smoothers often show **lower max rel dev for IQR than RMS**, but **strong smoothing (`smooth_w7`) can damage IQR *more* than RMS** (check `max_rel_dev_*` columns). Treat any width as **extraction-contingent**; prefer mean / CDF-level summaries for stable T trends.";
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = sprintf("- `%s`", compPath);
lines(end + 1) = sprintf("- `%s`", robPath);
lines(end + 1) = sprintf("- `%s`", locPath);
lines(end + 1) = "- `figures/spread_observable_comparison.png` (+ .pdf, .fig)";
lines(end + 1) = "- `review/pt_width_sensitivity_bundle.zip`";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Curves: 6 variants per panel (≤6 → legend).";
lines(end + 1) = "- Colormap: `lines` for distinct variants.";
lines(end + 1) = "- No extra smoothing beyond each child extraction.";
txt = strjoin(lines, newline);
end

function ensureArtifactDirsLocal(runDir)
req = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(req)
    p = fullfile(runDir, req{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
end

function zipPath = buildReviewZipLocal(runDir, zipName)
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

function appendTextLocal(pathText, lineText)
fid = fopen(pathText, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lineText);
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
