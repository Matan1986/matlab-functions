function run_asymmetric_spread_analysis()
% run_asymmetric_spread_analysis
% Asymmetric spread / width decomposition on existing PT_matrix.csv variants
% from run_2026_03_25_013346_pt_energy_robustness_audit (no PT regeneration).

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingDir = fileparts(analysisDir);
repoRoot = fileparts(switchingDir);

addpath(genpath(fullfile(repoRoot, 'Aging', 'utils')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
set(0, 'DefaultFigureVisible', 'off');

auditRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_25_013346_pt_energy_robustness_audit');
childMapPath = fullfile(auditRunDir, 'tables', 'pt_variant_child_runs.csv');
assert(exist(childMapPath, 'file') == 2, 'Missing %s', childMapPath);

runCfg = struct('runLabel', 'asymmetric_spread_analysis', ...
    'dataset', 'pt_robustness_audit_child_runs');
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
fprintf('Asymmetric spread analysis run directory:\n%s\n', runDir);

for d = {'figures', 'tables', 'reports', 'review'}
    sd = fullfile(runDir, d{1});
    if exist(sd, 'dir') ~= 7
        mkdir(sd);
    end
end

opts = delimitedTextImportOptions('NumVariables', 4, 'VariableNamingRule', 'preserve');
opts.VariableNames = {'variant_key', 'variant_label', 'child_run_id', 'child_run_dir'};
opts.VariableTypes = {'string', 'string', 'string', 'string'};
opts.DataLines = [2, Inf];
opts.ExtraColumnsRule = 'ignore';
opts.EmptyLineRule = 'skip';
vm = readtable(childMapPath, opts);
nV = height(vm);
variantKeys = vm.variant_key;
variantLabels = vm.variant_label;
childDirs = vm.child_run_dir;

compRows = [];
for k = 1:nV
    [tempsK, currentsK, PTK] = loadPTMatrixSpread(fullfile(char(childDirs(k)), 'tables', 'PT_matrix.csv'));
    smPath = fullfile(char(childDirs(k)), 'tables', 'PT_summary.csv');
    sm = readtable(smPath, 'VariableNamingRule', 'preserve');
    smT = double(sm.T_K(:));
    smMean = double(sm.mean_threshold_mA(:));
    smStd = double(sm.std_threshold_mA(:));
    for it = 1:numel(tempsK)
        TK = tempsK(it);
        pRow = PTK(it, :).';
        [mth, sth] = lookupSummary(smT, smMean, smStd, TK);
        obs = computeAsymmetricObservables(currentsK(:), pRow);
        r = struct2table(mergeStruct(struct('variant_key', variantKeys(k), ...
            'variant_label', variantLabels(k), 'T_K', TK, ...
            'mean_threshold_mA', mth, 'std_threshold_mA', sth), obs), 'AsArray', true);
        compRows = [compRows; r]; %#ok<AGROW>
    end
end

cmpPath = save_run_table(compRows, 'asymmetric_spread_comparison.csv', runDir);

refKey = 'canonical';
isRef = strcmp(string(compRows.variant_key), refKey);
refTbl = compRows(isRef, :);
varTbl = compRows(~isRef, :);

obsNames = {'w_left_halfmax_mA', 'w_right_halfmax_mA', 'asym_ratio_halfmax', ...
    'asym_diff_halfmax_mA', 'halfwidth_diff_norm_halfmax', ...
    'w_left_iqr_mA', 'w_right_iqr_mA', 'asym_ratio_iqr', 'asym_diff_iqr_mA', ...
    'iqr_mA', 'std_threshold_mA'};

rob = buildRobustnessTable(refTbl, varTbl, obsNames);
robPath = save_run_table(rob, 'asymmetric_spread_robustness_metrics.csv', runDir);

% Figures
colors = lines(nV);
base1 = 'asymmetric_spread_vs_T';
fig1 = create_figure('Name', base1, 'NumberTitle', 'off');
hold on;
for k = 1:nV
    tk = compRows.T_K(strcmp(string(compRows.variant_key), variantKeys(k)));
    yk = compRows.asym_ratio_halfmax(strcmp(string(compRows.variant_key), variantKeys(k)));
    plot(tk, yk, 'LineWidth', 2, 'Color', colors(k, :), ...
        'DisplayName', char(variantKeys(k)));
end
hold off;
grid on;
xlabel('Temperature (K)');
ylabel('Asymmetry ratio (half-max)');
legend('Location', 'best');
save_run_figure(fig1, base1, runDir);

base2 = 'asymmetry_vs_variants';
fig2 = create_figure('Name', base2, 'NumberTitle', 'off');
vkU = unique(string(varTbl.variant_key), 'stable');
maxDev = zeros(numel(vkU), 1);
Tref = refTbl.T_K;
a0ref = refTbl.asym_ratio_halfmax;
for i = 1:numel(vkU)
    sub = varTbl(strcmp(string(varTbl.variant_key), vkU(i)), :);
    [~, ia, ib] = intersect(Tref, sub.T_K, 'stable');
    x0 = a0ref(ia);
    x1 = sub.asym_ratio_halfmax(ib);
    ok = isfinite(x0) & isfinite(x1);
    x0 = x0(ok);
    x1 = x1(ok);
    if numel(x0) < 2
        maxDev(i) = NaN;
    else
        den = max(abs(x0), relScaleForRobustness('asym_ratio_halfmax'));
        maxDev(i) = max(abs(x1 - x0) ./ den);
    end
end
bar(categorical(vkU), maxDev, 'FaceColor', [0.25 0.45 0.75]);
xlabel('Extraction variant');
ylabel('max_T rel. dev. vs canonical');
grid on;
set(gca, 'XTickLabelRotation', 30);
save_run_figure(fig2, base2, runDir);

[grade, oneLiner, reportLines] = gradeAsymmetry(rob, auditRunDir);
reportBody = strjoin(reportLines, newline);
repPath = save_run_report(reportBody, 'asymmetric_spread_analysis_report.md', runDir);

% Log + notes
fid = fopen(fullfile(runDir, 'log.txt'), 'a');
if fid > 0
    fprintf(fid, '%s asymmetric spread analysis complete. grade=%s\n', datestr(now, 31), grade);
    fprintf(fid, 'comparison: %s\nrobustness: %s\nreport: %s\n', cmpPath, robPath, repPath);
    fclose(fid);
end
nf = fopen(run.notes_path, 'a');
if nf > 0
    fprintf(nf, '%s\n%s\n', oneLiner, ...
        'Source: run_2026_03_25_013346_pt_energy_robustness_audit child PT_matrix.csv files.');
    fclose(nf);
end

zipReviewBundle(runDir);

fprintf('Done. Classification %s\n', grade);
end

function s = mergeStruct(a, b)
f = fieldnames(b);
s = a;
for i = 1:numel(f)
    s.(f{i}) = b.(f{i});
end
end

function [mth, sth] = lookupSummary(smT, smMean, smStd, TK)
idx = find(abs(smT - TK) < 1e-9, 1);
if isempty(idx)
    mth = NaN;
    sth = NaN;
else
    mth = smMean(idx);
    sth = smStd(idx);
end
end

function obs = computeAsymmetricObservables(I, p)
p = double(p(:));
I = double(I(:));
obs = struct();
obs.w_left_halfmax_mA = NaN;
obs.w_right_halfmax_mA = NaN;
obs.asym_ratio_halfmax = NaN;
obs.asym_diff_halfmax_mA = NaN;
obs.halfwidth_diff_norm_halfmax = NaN;
obs.w_left_iqr_mA = NaN;
obs.w_right_iqr_mA = NaN;
obs.asym_ratio_iqr = NaN;
obs.asym_diff_iqr_mA = NaN;
obs.iqr_mA = NaN;

s = sum(p);
if ~(s > 0) || all(~isfinite(p))
    return
end
pn = p / s;
if all(pn == 0)
    return
end

% Half-max on PMF: support where p >= 0.5 max(p); widths from mean(mu), not mode
% (mode at the left grid edge otherwise yields w_left=0 while physics still has spread).
[pmax, ~] = max(pn);
thr = 0.5 * pmax;
mask = pn >= thr;
Ileft = min(I(mask));
Iright = max(I(mask));
mu = sum(I .* pn);
wL = mu - Ileft;
wR = Iright - mu;
obs.w_left_halfmax_mA = wL;
obs.w_right_halfmax_mA = wR;
obs.asym_diff_halfmax_mA = wR - wL;
epsW = 1e-6;
if wL > epsW
    obs.asym_ratio_halfmax = wR / wL;
else
    obs.asym_ratio_halfmax = NaN;
end
den = wL + wR;
if den > epsW
    obs.halfwidth_diff_norm_halfmax = (wR - wL) / den;
else
    obs.halfwidth_diff_norm_halfmax = NaN;
end

% Quantiles (linear interpolation on CDF)
q25 = discreteQuantile(I, pn, 0.25);
q50 = discreteQuantile(I, pn, 0.50);
q75 = discreteQuantile(I, pn, 0.75);
wl = q50 - q25;
wr = q75 - q50;
obs.w_left_iqr_mA = wl;
obs.w_right_iqr_mA = wr;
obs.iqr_mA = q75 - q25;
obs.asym_diff_iqr_mA = wr - wl;
if wl > epsW
    obs.asym_ratio_iqr = wr / wl;
else
    obs.asym_ratio_iqr = NaN;
end
end

function q = discreteQuantile(I, p, u)
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

function [temps, currents, PT] = loadPTMatrixSpread(ptMatrixPath)
tbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
assert(ismember('T_K', tbl.Properties.VariableNames), 'T_K missing');
vn = tbl.Properties.VariableNames;
ptNames = setdiff(vn, {'T_K'}, 'stable');
temps = double(tbl.T_K(:));
PT = double(table2array(tbl(:, ptNames)));
currents = parseCurrentsSpread(ptNames);
[currents, io] = sort(currents(:), 'ascend');
PT = PT(:, io);
[temps, it] = sort(temps(:), 'ascend');
PT = PT(it, :);
end

function currents = parseCurrentsSpread(varNames)
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

function rob = buildRobustnessTable(refTbl, varTbl, obsNames)
vk = unique(string(varTbl.variant_key), 'stable');
rows = table();
for oi = 1:numel(obsNames)
    on = obsNames{oi};
    if ~ismember(on, refTbl.Properties.VariableNames)
        continue
    end
    spears = [];
    pears = [];
    maxRelT = [];
    medRelT = [];
    rel22 = [];
    relHi = [];
    for vi = 1:numel(vk)
        sub = varTbl(strcmp(string(varTbl.variant_key), vk(vi)), :);
        Tref = refTbl.T_K;
        xref = refTbl.(on);
        [~, ia, ib] = intersect(Tref, sub.T_K, 'stable');
        Tcom = Tref(ia);
        x0 = xref(ia);
        x1 = sub.(on)(ib);
        ok = isfinite(x0) & isfinite(x1);
        Tcom = Tcom(ok);
        x0 = x0(ok);
        x1 = x1(ok);
        if numel(x0) < 3
            continue
        end
        spears(end+1) = corr(x0, x1, 'type', 'Spearman', 'rows', 'complete'); %#ok<AGROW>
        pears(end+1) = corr(x0, x1, 'type', 'Pearson', 'rows', 'complete'); %#ok<AGROW>
        den = max(abs(x0), relScaleForRobustness(on));
        rd = abs(x1 - x0) ./ den;
        maxRelT(end+1) = max(rd); %#ok<AGROW>
        medRelT(end+1) = median(rd); %#ok<AGROW>
        i22 = find(abs(Tcom - 22) < 0.51, 1);
        if isempty(i22)
            rel22(end+1) = NaN; %#ok<AGROW>
        else
            rel22(end+1) = rd(i22); %#ok<AGROW>
        end
        hiMask = Tcom >= 27.99 & Tcom <= 30.01;
        if any(hiMask)
            relHi(end+1) = max(rd(hiMask)); %#ok<AGROW>
        else
            relHi(end+1) = NaN; %#ok<AGROW>
        end
    end
    if isempty(spears)
        continue
    end
    row = table(string(on), min(spears), median(spears), min(pears), median(pears), ...
        max(maxRelT), median(maxRelT), max(medRelT), median(medRelT), ...
        max(rel22, [], 'omitnan'), max(relHi, [], 'omitnan'), ...
        'VariableNames', {'observable', 'spearman_min_across_variants', ...
        'spearman_median_across_variants', 'pearson_min_across_variants', ...
        'pearson_median_across_variants', 'max_of_variant_max_rel_dev', ...
        'median_of_variant_max_rel_dev', 'max_of_variant_median_rel_dev', ...
        'median_of_variant_median_rel_dev', 'max_rel_dev_at_22K_across_variants', ...
        'max_rel_dev_highT_28_30_across_variants'});
    rows = [rows; row]; %#ok<AGROW>
end
rob = rows;
end

function [grade, oneLiner, lines] = gradeAsymmetry(rob, auditRunDir)
lines = strings(0, 1);
lines(end+1) = "# Asymmetric spread vs PT extraction variants";
lines(end+1) = "";
lines(end+1) = sprintf("Parent audit: `%s`", auditRunDir);
lines(end+1) = "";
lines(end+1) = "## Existing asymmetry-related observables (codebase)";
lines(end+1) = "- `Switching/analysis/switching_alignment_audit.m`: `halfwidth_diff_norm` on ridge, `asym` = area_right/area_left around I_peak.";
lines(end+1) = "- `Switching/analysis/switching_effective_observables.m`: `asym` = (wRight-wLeft)/width from half-max crossings (collapse width).";
lines(end+1) = "";
lines(end+1) = "## Definitions used here (P_T on discrete I grid)";
lines(end+1) = "- **Half-max**: support where normalized P_T \geq 0.5 max(P_T); w_left/w_right measured from distribution mean \mu=\sum I\,P_T(I) to min/max I in that support.";
lines(end+1) = "- **IQR split**: q25,q50,q75 from piecewise-linear inverse CDF; w_left=q50-q25, w_right=q75-q50.";
lines(end+1) = "- **Reference width**: `std_threshold_mA` from each run's `PT_summary.csv` (symmetric; audit cross-check in `pt_robustness_metrics_by_variant.csv`).";
lines(end+1) = "- **Relative deviations**: |x-x_{ref}|/\max(|x_{ref}|, s) with s=1 mA for mA-scale observables and s=0.2 for ratios / normalized halfwidth.";
lines(end+1) = "";

stdRow = rob(strcmp(rob.observable, 'std_threshold_mA'), :);
symSpan = strcmp(rob.observable, 'std_threshold_mA') | strcmp(rob.observable, 'iqr_mA');
asymRows = rob(~symSpan, :);

if isempty(asymRows) || isempty(stdRow)
    grade = 'C';
    oneLiner = 'An asymmetric spread description does not resolve the PT width instability.';
    lines(end+1) = "Insufficient metrics for grading.";
    return
end

medStd = stdRow.spearman_median_across_variants;
maxStdDev = stdRow.max_of_variant_max_rel_dev;
bestMedAll = max(asymRows.spearman_median_across_variants);
cand = asymRows(asymRows.spearman_median_across_variants == bestMedAll, :);
[~, im] = min(cand.max_of_variant_max_rel_dev);
bestRow = cand(im, :);
bestName = char(bestRow.observable);
bestMed = bestRow.spearman_median_across_variants;
bestMax = bestRow.max_of_variant_max_rel_dev;

lines(end+1) = "## Robustness summary (non-canonical vs canonical)";
lines(end+1) = "| observable | Spearman median | Spearman min | max variant max-rel-dev |";
lines(end+1) = "| --- | --- | --- | --- |";
for i = 1:height(rob)
    lines(end+1) = sprintf("| %s | %.4f | %.4f | %.4f |", rob.observable(i), ...
        rob.spearman_median_across_variants(i), rob.spearman_min_across_variants(i), ...
        rob.max_of_variant_max_rel_dev(i)); %#ok<AGROW>
end
lines(end+1) = "";
lines(end+1) = sprintf("**Best asymmetric (by Spearman median):** `%s` (median %.4f).", bestName, bestMed);
lines(end+1) = sprintf("**std_threshold_mA:** Spearman median %.4f, worst-case max rel dev across T (any variant) %.4f.", medStd, maxStdDev);
lines(end+1) = "";

% Audit reference (no recomputation): max rel std from pt_robustness_metrics_by_variant.csv
auditCsv = fullfile(auditRunDir, 'tables', 'pt_robustness_metrics_by_variant.csv');
if exist(auditCsv, 'file') == 2
    au = readtable(auditCsv);
    if ismember('max_rel_std_threshold', au.Properties.VariableNames)
        mx = max(au.max_rel_std_threshold);
        lines(end+1) = sprintf("Audit `pt_robustness_metrics_by_variant.csv` `max_rel_std_threshold` max over variants = %.4f.", mx);
    end
end
lines(end+1) = "";

% Classification
ratioMax = bestMax / max(maxStdDev, 1e-12);
spearGain = bestMed - medStd;

if bestMed >= medStd + 0.02 && ratioMax < 0.55
    grade = 'A';
    oneLiner = 'An asymmetric spread description resolves much of the PT width instability.';
elseif bestMed + 0.01 >= medStd && ratioMax < 0.85
    grade = 'B';
    oneLiner = 'An asymmetric spread description partially mitigates PT width instability.';
else
    grade = 'C';
    oneLiner = 'An asymmetric spread description does not resolve the PT width instability.';
end

lines(end+1) = "## Classification";
lines(end+1) = sprintf("- **Grade %s** (A: strong, B: partial, C: insufficient).", grade);
lines(end+1) = sprintf("- Spearman median gap (best asymmetric - std): %.4f.", spearGain);
lines(end+1) = sprintf("- Ratio of best asymmetric `max_of_variant_max_rel_dev` to std's: %.3f.", ratioMax);
lines(end+1) = "";
lines(end+1) = "## Recommendation";
if grade == "A"
    lines(end+1) = sprintf("Adopt `%s` (with `w_left`/`w_right` pair) as interpretive width decomposition alongside mean threshold.", bestName);
elseif grade == "B"
    lines(end+1) = sprintf("Use `%s` as a secondary diagnostic; keep std width with caution where tails drive mass.", bestName);
else
    lines(end+1) = "Asymmetry coordinates alone do not stabilize P_T width under extraction variants; instability is not fully explained as symmetric-vs-asymmetric choice.";
end
end

function zipReviewBundle(runDir)
zpath = fullfile(runDir, 'review', 'asymmetric_spread_bundle.zip');
if exist(zpath, 'file') == 2
    delete(zpath);
end
rel = {'tables/asymmetric_spread_comparison.csv'
    'tables/asymmetric_spread_robustness_metrics.csv'
    'reports/asymmetric_spread_analysis_report.md'
    'figures/asymmetric_spread_vs_T.png'
    'figures/asymmetry_vs_variants.png'};
rel = rel(cellfun(@(r) exist(fullfile(runDir, r), 'file') == 2, rel));
if isempty(rel)
    return
end
zip(zpath, rel, runDir);
end

function s = relScaleForRobustness(obsName)
% Floor for relative deviation so near-zero baselines do not explode metrics.
on = char(string(obsName));
if endsWith(on, '_mA')
    s = 1.0;
elseif contains(on, 'ratio') || contains(on, 'halfwidth_diff_norm')
    s = 0.2;
else
    s = 1.0;
end
end
