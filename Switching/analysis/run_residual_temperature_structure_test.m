function out = run_residual_temperature_structure_test()
% run_residual_temperature_structure_test
% Kappa/Phi temperature-structure test: rank-1 vs mode drift on the residual stack.
% Replays switching_residual_decomposition_analysis on the canonical source chain,
% writes a NEW switching run (does not modify existing runs).

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';

runCtx = createSwitchingRunContext(repoRoot, struct('runLabel', 'kappa_phi_temperature_structure_test'));
runDir = runCtx.run_dir;
fprintf('Kappa/Phi temperature-structure test run directory:\n%s\n', runDir);

decCfg = struct();
decCfg.run = runCtx;
decCfg.runLabel = 'kappa_phi_temperature_structure_test';
decCfg.alignmentRunId = alignmentRunId;
decCfg.fullScalingRunId = fullScalingRunId;
decCfg.ptRunId = ptRunId;
decCfg.canonicalMaxTemperatureK = 30;
decCfg.nXGrid = 220;
decCfg.fallbackSmoothWindow = 5;

dec = switching_residual_decomposition_analysis(decCfg);

paramsPath = fullfile(switchingCanonicalRunRoot(repoRoot), fullScalingRunId, ...
    'tables', 'switching_full_scaling_parameters.csv');
paramsTbl = readtable(paramsPath);

phi = dec.phi(:);
xGrid = dec.xGrid(:);
Rall = dec.Rall;
Tall = dec.temperaturesK(:);
kap = dec.kappaAll(:);
lowMask = dec.lowTemperatureMask;

Rlow = Rall(lowMask, :);
Tlow = Tall(lowMask);

subsets = struct( ...
    'id', {'T_le_30', 'no_22K', 'T_le_24'}, ...
    'mask', {lowMask, lowMask & abs(Tall - 22) > 0.5, lowMask & (Tall <= 24)});

nSub = numel(subsets);
rankSummary = [];
modeStabRows = struct([]);
rankStructRows = struct([]);

maxDriftAll = -Inf;
strongestCorr = struct('name', "", 'value', NaN);

for si = 1:nSub
    sid = string(subsets(si).id);
    sm = subsets(si).mask;
    R = Rall(sm, :);
    Tv = Tall(sm);
    kv = kap(sm);

    if size(R, 1) < 5
        warning('Subset %s has fewer than 5 rows; skipping.', sid);
        continue;
    end

    [phiSub, ~, ~] = localPhiSvd(R);
    R0 = R;
    R0(~isfinite(R0)) = 0;
    [U, S, V] = svd(R0, 'econ');
    sdiag = diag(S);
    R1 = sdiag(1) * U(:, 1) * V(:, 1)';
    if numel(sdiag) >= 2
        R2 = R1 + sdiag(2) * U(:, 2) * V(:, 2)';
    else
        R2 = R1;
    end
    froR = norm(R0, 'fro');
    rel1 = norm(R0 - R1, 'fro') / max(froR, eps);
    rel2 = norm(R0 - R2, 'fro') / max(froR, eps);
    gain = rel1 - rel2;
    ef1 = sdiag(1)^2 / sum(sdiag.^2);
    if numel(sdiag) >= 2
        ef12 = (sdiag(1)^2 + sdiag(2)^2) / sum(sdiag.^2);
        dom12 = sdiag(1) / max(sdiag(2), eps);
    else
        ef12 = ef1;
        dom12 = Inf;
    end

    newRow = table(sid, size(R, 1), rel1, rel2, gain, ef1, ef12, dom12, ...
        'VariableNames', {'subset', 'n_rows', 'rel_fro_err_rank1', 'rel_fro_err_rank2', ...
        'rel_fro_err_gain_rank2_over_rank1', 'energy_frac_mode1', 'energy_frac_modes12', ...
        'sigma1_over_sigma2'});
    if isempty(rankSummary)
        rankSummary = newRow;
    else
        rankSummary = [rankSummary; newRow]; %#ok<AGROW>
    end

    % Leave-one-T-out: subset leading mode vs stack with one row removed
    nT = size(R, 1);
    looCos = NaN(nT, 1);
    for ii = 1:nT
        idx = true(nT, 1);
        idx(ii) = false;
        if nnz(idx) < 4
            continue;
        end
        [phiLoo, ~] = localPhiSvd(R(idx, :));
        looCos(ii) = alignedCosSim(phiLoo, phiSub);
    end
    drift = min(looCos, [], 'omitnan');
    if isfinite(drift)
        maxDriftAll = max(maxDriftAll, 1 - drift);
    end

    for ii = 1:nT
        modeStabRows(end + 1).subset = char(sid); %#ok<AGROW>
        modeStabRows(end).T_K = Tv(ii);
        modeStabRows(end).loo_cosine_phi_vs_subset_ref = looCos(ii);
        modeStabRows(end).loo_angle_deg = acos(min(1, max(-1, looCos(ii)))) * 180 / pi;
    end

    % Per-temperature: orthogonal residual vs canonical Phi(x) from replayed decomposition
    IpLoc = lookupParamPerTScaling(paramsTbl, Tv, 'Ipeak_mA');
    SpLoc = lookupParamPerTScaling(paramsTbl, Tv, 'S_peak');
    Xloc = lookupParamPerTScaling(paramsTbl, Tv, 'X');

    pairCos = pairwiseCosineNormRows(R);
    phican = phi(:);
    for ii = 1:nT
        rvec = R(ii, :);
        m = isfinite(rvec(:)) & isfinite(phican(:));
        ph = reshape(phican(m), [], 1);
        rn = reshape(rvec(m), [], 1);
        relOrth = NaN;
        cosShape = NaN;
        if numel(rn) >= 3
            denomPhi = dot(ph, ph);
            if denomPhi > eps
                a = dot(rn, ph) / denomPhi;
                resid = rn - a .* ph;
                relOrth = norm(resid) / max(norm(rn), eps);
                cosShape = dot(rn, ph) / (norm(rn) * norm(ph));
            end
        end
        others = true(nT, 1);
        others(ii) = false;
        pc = pairCos(ii, others);
        rankStructRows(end + 1).subset = char(sid); %#ok<AGROW>
        rankStructRows(end).T_K = Tv(ii);
        rankStructRows(end).kappa = kv(ii);
        rankStructRows(end).I_peak_mA = IpLoc(ii);
        rankStructRows(end).S_peak = SpLoc(ii);
        rankStructRows(end).X = Xloc(ii);
        rankStructRows(end).rel_orth_leftover_norm = relOrth;
        rankStructRows(end).cos_slice_vs_mode1 = cosShape;
        rankStructRows(end).mean_pairwise_cos_norm = mean(pc, 'omitnan');
        rankStructRows(end).min_pairwise_cos_norm = min(pc, [], 'omitnan');
    end
end

modeStabTbl = struct2table(modeStabRows);
rankStructTbl = struct2table(rankStructRows);

predNames = {'T_K', 'X', 'kappa', 'I_peak_mA', 'S_peak'};
mask30 = strcmp(rankStructTbl.subset, 'T_le_30');
for pj = 1:numel(predNames)
    x = rankStructTbl.(predNames{pj})(mask30);
    y = rankStructTbl.rel_orth_leftover_norm(mask30);
    c = corr(x, y, 'rows', 'pairwise');
    if isfinite(c) && (~isfinite(strongestCorr.value) || abs(c) > abs(strongestCorr.value))
        strongestCorr.name = predNames{pj};
        strongestCorr.value = c;
    end
end

save_run_table(rankStructTbl, 'residual_rank_structure_vs_T.csv', runDir);
save_run_table(modeStabTbl, 'residual_mode_stability.csv', runDir);
save_run_table(rankSummary, 'rank1_vs_rank2_summary.csv', runDir);

makeFigNormalizedSlices(Tlow, xGrid, Rlow, runDir);
makeFigModeStability(modeStabTbl, runDir);
makeFigRankCompare(rankSummary, runDir);

rank2GainFull = NaN;
rs = rankSummary(strcmp(rankSummary.subset, 'T_le_30'), :);
if height(rs) == 1
    rank2GainFull = rs.rel_fro_err_gain_rank2_over_rank1;
end

isAmpOnly = classifyAmpOnly(rankSummary, rankStructTbl, maxDriftAll, strongestCorr);

reportLines = strings(0, 1);
reportLines(end + 1) = "# Residual sector: temperature–structure test (kappa / Phi)";
reportLines(end + 1) = "";
reportLines(end + 1) = "## Canonical decomposition sources";
reportLines(end + 1) = "- Alignment: `" + alignmentRunId + "`.";
reportLines(end + 1) = "- Full scaling: `" + fullScalingRunId + "`.";
reportLines(end + 1) = "- PT matrix: `" + ptRunId + "`.";
reportLines(end + 1) = "- Reference saved run: `run_2026_03_24_220314_residual_decomposition` (replay via this script’s pipeline).";
reportLines(end + 1) = "";
reportLines(end + 1) = "## Executive readout";
reportLines(end + 1) = sprintf("- **Amplitude-only rank-1 (shape drift) classification:** %s", isAmpOnly);
reportLines(end + 1) = sprintf("- **Rank-2 Frobenius gain over rank-1** (full low-T window `T_le_30`): %.6f", rank2GainFull);
reportLines(end + 1) = sprintf("- **Max mode-drift metric** (1 - min LOO cosine vs subset Phi, across subsets): %.6f", maxDriftAll);
reportLines(end + 1) = sprintf("- **Strongest |correlation|** of per-row orthogonal leftover norm vs {T, X, kappa, I_peak, S_peak}: `%s` = %.6f", ...
    strongestCorr.name, strongestCorr.value);
reportLines(end + 1) = "";
reportLines(end + 1) = "## Methods";
reportLines(end + 1) = "- Residual stack `R(T,x)` reconstructed on the canonical x-grid exactly as `switching_residual_decomposition_analysis` (CDF subtraction, normalization, interpolation).";
reportLines(end + 1) = "- **LOO mode stability:** for each subset, drop one temperature row, re-extract the leading SVD mode on the remaining stack, measure cosine similarity to the mode from the full subset (sign-aligned).";
reportLines(end + 1) = "- **Pairwise cosine:** amplitude-normalized rows (L2 on overlapping finite samples), mean/min over other temperatures in the same subset.";
reportLines(end + 1) = "- **Orthogonal leftover:** `|| r - (r·Phi/Phi·Phi) Phi || / ||r||` using the **canonical** `Phi(x)` from the replayed low-T SVD (`dec.phi`).";
reportLines(end + 1) = "- **X coordinate:** `X = I_peak / (width_chosen_mA * S_peak)` from the full-scaling table.";
reportLines(end + 1) = "";
reportLines(end + 1) = "## Tables";
reportLines(end + 1) = "- `tables/residual_rank_structure_vs_T.csv`";
reportLines(end + 1) = "- `tables/residual_mode_stability.csv`";
reportLines(end + 1) = "- `tables/rank1_vs_rank2_summary.csv`";
reportLines(end + 1) = "";
reportLines(end + 1) = "## Figures";
reportLines(end + 1) = "- `figures/normalized_residual_slices.png`";
reportLines(end + 1) = "- `figures/mode_stability_vs_T.png`";
reportLines(end + 1) = "- `figures/rank1_rank2_comparison.png`";

save_run_report(strjoin(reportLines, newline), 'residual_temperature_structure_report.md', runDir);

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'kappa_phi_temperature_structure_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);

out = struct();
out.runDir = runDir;
out.rankSummary = rankSummary;
out.rankStructTbl = rankStructTbl;
out.modeStabTbl = modeStabTbl;
out.isAmpOnly = isAmpOnly;
out.rank2GainFullWindow = rank2GainFull;
out.maxModeDriftMetric = maxDriftAll;
out.strongestCorr = strongestCorr;
fprintf('\n=== Kappa/Phi temperature-structure test complete ===\n');
fprintf('Run dir: %s\n', runDir);
end

function v = lookupParamPerTScaling(paramsTbl, Tlist, fieldName)
n = numel(Tlist);
v = NaN(n, 1);
tAll = paramsTbl.T_K;
for i = 1:n
    row = find(abs(tAll - Tlist(i)) < 0.25, 1, 'first');
    if isempty(row)
        continue;
    end
    if strcmp(fieldName, 'X')
        w = paramsTbl.width_chosen_mA(row);
        Ip = paramsTbl.Ipeak_mA(row);
        Sp = paramsTbl.S_peak(row);
        v(i) = Ip / max(w * Sp, eps);
    else
        v(i) = paramsTbl.(fieldName)(row);
    end
end
end

function [phi, s, phi2] = localPhiSvd(R)
R0 = R;
R0(~isfinite(R0)) = 0;
[U, S, V] = svd(R0, 'econ');
s = diag(S);
phi = V(:, 1);
kappaRaw = U(:, 1) * s(1);
if median(kappaRaw, 'omitnan') < 0
    phi = -phi;
end
sc = max(abs(phi), [], 'omitnan');
if ~(isfinite(sc) && sc > 0)
    sc = 1;
end
phi = phi / sc;
phi2 = [];
if size(V, 2) >= 2
    phi2 = V(:, 2);
end
end

function c = alignedCosSim(a, b)
a = a(:);
b = b(:);
m = isfinite(a) & isfinite(b);
if nnz(m) < 3
    c = NaN;
    return;
end
a = a(m);
b = b(m);
a = a / norm(a);
b = b / norm(b);
c = dot(a, b);
if c < 0
    c = -c;
end
c = min(1, max(-1, c));
end

function C = pairwiseCosineNormRows(R)
[n, ~] = size(R);
C = NaN(n, n);
for i = 1:n
    for j = 1:n
        if i == j
            C(i, j) = 1;
            continue;
        end
        m = isfinite(R(i, :)) & isfinite(R(j, :));
        if nnz(m) < 3
            continue;
        end
        a = R(i, m)';
        b = R(j, m)';
        C(i, j) = dot(a / norm(a), b / norm(b));
    end
end
end

function makeFigNormalizedSlices(Tlow, xGrid, Rlow, runDir)
baseName = 'normalized_residual_slices';
n = size(Rlow, 1);
Z = NaN(size(Rlow));
for i = 1:n
    r = Rlow(i, :);
    m = isfinite(r);
    if nnz(m) < 3
        continue;
    end
    rn = r(m);
    nf = norm(rn);
    if nf > eps
        Z(i, m) = rn / nf;
    end
end
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
cmap = parula(n);
for i = 1:n
    plot(ax, xGrid, Z(i, :), '-', 'LineWidth', 1.8, 'Color', cmap(i, :));
end
hold(ax, 'off');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
clim(ax, [min(Tlow), max(Tlow)]);
xlabel(ax, 'x = (I - I_{peak}) / w');
ylabel(ax, 'Normalized \deltaS (unit L2 per slice)');
title(ax, 'Amplitude-normalized residual slices on canonical x grid');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
save_run_figure(fig, baseName, runDir);
close(fig);
end

function makeFigModeStability(modeStabTbl, runDir)
baseName = 'mode_stability_vs_T';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
subs = unique(string(modeStabTbl.subset), 'stable');
markers = {'-o', '-s', '-^'};
for k = 1:numel(subs)
    rows = strcmp(modeStabTbl.subset, subs(k));
    plot(ax, modeStabTbl.T_K(rows), modeStabTbl.loo_cosine_phi_vs_subset_ref(rows), ...
        markers{min(k, numel(markers))}, 'LineWidth', 2.0, 'MarkerFaceColor', 'auto', ...
        'DisplayName', char(subs(k)));
end
hold(ax, 'off');
xlabel(ax, 'Held-out T (K)');
ylabel(ax, 'LOO cosine vs full-subset \Phi_1');
title(ax, 'Leave-one-temperature-out mode stability');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
ylim(ax, [0 1.05]);
save_run_figure(fig, baseName, runDir);
close(fig);
end

function makeFigRankCompare(rankSummary, runDir)
baseName = 'rank1_rank2_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 8]);
ax = axes(fig);
x = categorical(rankSummary.subset);
b = bar(ax, x, [rankSummary.rel_fro_err_rank1, rankSummary.rel_fro_err_rank2], 'BarWidth', 0.9);
b(1).DisplayName = 'rank-1';
b(2).DisplayName = 'rank-(1+2)';
ylabel(ax, 'Relative Frobenius error');
title(ax, 'Truncated SVD reconstruction of residual stack');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
save_run_figure(fig, baseName, runDir);
close(fig);
end

function s = classifyAmpOnly(rankSummary, rankStructTbl, maxDrift, strongestCorr)
rs = rankSummary(strcmp(rankSummary.subset, 'T_le_30'), :);
ef1 = NaN;
if height(rs) == 1
    ef1 = rs.energy_frac_mode1;
end
tbl = rankStructTbl(strcmp(rankStructTbl.subset, 'T_le_30'), :);
medCos = median(tbl.cos_slice_vs_mode1, 'omitnan');
p10Orth = prctile(tbl.rel_orth_leftover_norm, 90);

s = "NO";
if isfinite(ef1) && ef1 >= 0.94 && maxDrift <= 0.02 && medCos >= 0.99
    s = "YES";
elseif isfinite(ef1) && ef1 >= 0.90 && maxDrift <= 0.06 && abs(strongestCorr.value) < 0.75
    s = "APPROXIMATELY";
end
% Heuristic override: visible drift / correlation structure
if isfinite(strongestCorr.value) && abs(strongestCorr.value) >= 0.85 && strcmp(s, "YES")
    s = "APPROXIMATELY";
end
if medCos < 0.97 || p10Orth > 0.12
    if strcmp(s, "YES")
        s = "APPROXIMATELY";
    end
end
end
