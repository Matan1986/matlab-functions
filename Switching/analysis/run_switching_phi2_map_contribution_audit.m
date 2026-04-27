% run_switching_phi2_map_contribution_audit
%
% Map-level audit: DeltaS2(T,I) = kappa2(T)*Phi2(I) from canonical Phi2/kappa2
% (pred2 - pred1 under the locked Stage-E hierarchy). Uses successful canonical
% Switching artifacts only; does not read phi2 replacement audit outputs.
%
% Outputs (repo root):
%   tables/switching_phi2_map_contribution_by_T.csv
%   tables/switching_phi2_map_contribution_by_I.csv
%   tables/switching_phi2_reconstruction_gain_by_region.csv
%   reports/switching_phi2_map_contribution_audit.md
%
% Scope: diagnostic reconstruction / localization only — no decomposition edits.

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

outByT = fullfile(repoRoot, 'tables', 'switching_phi2_map_contribution_by_T.csv');
outByI = fullfile(repoRoot, 'tables', 'switching_phi2_map_contribution_by_I.csv');
outGain = fullfile(repoRoot, 'tables', 'switching_phi2_reconstruction_gain_by_region.csv');
outReport = fullfile(repoRoot, 'reports', 'switching_phi2_map_contribution_audit.md');

transitionBandK = [28, 32];

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

s1Path = fullfile(repoRoot, 'tables', 'switching_backbone_selection_run_status.csv');
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

req = {s1Path, idPath, sLongPath, phi1Path, ampPath};
reqLbl = {'switching_backbone_selection_run_status.csv', 'switching_canonical_identity.csv', ...
    'switching_canonical_S_long.csv', 'switching_canonical_phi1.csv', 'switching_mode_amplitudes_vs_T.csv'};
for i = 1:numel(req)
    if exist(req{i}, 'file') ~= 2
        error('run_switching_phi2_map_contribution_audit:MissingInput', 'Missing required input (%s): %s', reqLbl{i}, req{i});
    end
end

s1 = readtable(s1Path, 'TextType', 'string');
idxCurr = find(strcmpi(strtrim(s1.check), 'CURRENT_PTCDF_BACKBONE_SELECTED'), 1);
idxAllow = find(strcmpi(strtrim(s1.check), 'PHASE_D_ALLOWED_AFTER_SELECTION'), 1);
if isempty(idxCurr) || isempty(idxAllow)
    error('run_switching_phi2_map_contribution_audit:S1Schema', 'S1 status table missing required checks.');
end
if upper(strtrim(s1.result(idxCurr))) ~= "YES" || upper(strtrim(s1.result(idxAllow))) ~= "YES"
    error('run_switching_phi2_map_contribution_audit:S1Gate', 'Canonical pipeline blocked by S1 selection gate.');
end

idRaw = readcell(idPath, 'Delimiter', ',');
canonicalRunId = "";
for r = 2:size(idRaw, 1)
    if strcmpi(strtrim(string(idRaw{r, 1})), "CANONICAL_RUN_ID")
        canonicalRunId = string(idRaw{r, 2});
        break;
    end
end
if strlength(strtrim(canonicalRunId)) == 0
    error('run_switching_phi2_map_contribution_audit:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);
if ~all(ismember({'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'CDF_pt'}, sLong.Properties.VariableNames))
    error('run_switching_phi2_map_contribution_audit:Schema', 'sLong missing required columns.');
end
if ~all(ismember({'T_K', 'kappa1', 'kappa2'}, ampTbl.Properties.VariableNames))
    error('run_switching_phi2_map_contribution_audit:Schema', 'Amplitude table missing kappa1/kappa2.');
end

T = double(sLong.T_K); I = double(sLong.current_mA);
S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
G = groupsummary(table(T, I, S, B, C), {'T', 'I'}, 'mean', {'S', 'B', 'C'});
allT = unique(double(G.T), 'sorted');
allI = unique(double(G.I), 'sorted');
nT = numel(allT); nI = numel(allI);
Smap = NaN(nT, nI); Bmap = NaN(nT, nI); Cmap = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.T) - allT(it)) < 1e-9 & abs(double(G.I) - allI(ii)) < 1e-9;
        if any(m)
            j = find(m, 1);
            Smap(it, ii) = double(G.mean_S(j));
            Bmap(it, ii) = double(G.mean_B(j));
            Cmap(it, ii) = double(G.mean_C(j));
        end
    end
end
valid = isfinite(Smap) & isfinite(Bmap) & isfinite(Cmap);
cdfAxis = mean(Cmap, 1, 'omitnan');
if any(~isfinite(cdfAxis))
    cdfAxis = fillmissing(cdfAxis, 'linear', 'EndValues', 'nearest');
end
cdfAxis = cdfAxis(:);

tailI = cdfAxis >= 0.80;
coreI = cdfAxis >= 0.35 & cdfAxis <= 0.65;
shoulderI = isfinite(cdfAxis) & ((cdfAxis < 0.35) | ((cdfAxis > 0.65) & (cdfAxis < 0.80)));
shoulderI = shoulderI & ~tailI & ~coreI;

phiVars = string(phi1Tbl.Properties.VariableNames);
iPhi = find(strcmpi(phiVars, "phi1"), 1);
if isempty(iPhi)
    error('run_switching_phi2_map_contribution_audit:Phi1Col', 'No phi1 column in switching_canonical_phi1.csv.');
end
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

pred0 = Bmap;
pred1 = pred0 - kappa1(:) * phi1(:)';
R1 = Smap - pred1;
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if size(V1, 2) >= 1
    phi2 = V1(:, 1);
else
    phi2 = zeros(nI, 1);
end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end
pred2 = pred1 + kappa2(:) * phi2(:)';

DeltaS2 = kappa2(:) * phi2(:)';
chk = max(abs(DeltaS2(valid) - (pred2(valid) - pred1(valid))), [], 'omitnan');
if chk > 1e-9 * max(1, max(abs(DeltaS2(valid)), [], 'omitnan'))
    warning('run_switching_phi2_map_contribution_audit:DeltaCheck', ...
        'DeltaS2 differs from pred2-pred1 by max abs=%.3g (numerical).', chk);
end

absD = abs(DeltaS2);
absD(~valid) = NaN;
sumAbsFull = sum(absD(valid), 'omitnan');

% --- By T
nValidI = zeros(nT, 1); meanAbsT = nan(nT, 1); rmsT = nan(nT, 1); maxAbsT = nan(nT, 1); fracT = nan(nT, 1);
for it = 1:nT
    m = valid(it, :);
    d = DeltaS2(it, m);
    if isempty(d)
        continue;
    end
    nValidI(it) = sum(m);
    meanAbsT(it) = mean(abs(d));
    rmsT(it) = sqrt(mean(d.^2));
    maxAbsT(it) = max(abs(d));
    fracT(it) = sum(abs(d)) / max(sumAbsFull, eps);
end
rowsT = table(allT(:), nValidI, meanAbsT, rmsT, maxAbsT, fracT, ...
    'VariableNames', {'T_K', 'n_valid_I', 'mean_abs_deltaS2', 'rms_deltaS2', 'max_abs_deltaS2', 'frac_of_global_sum_abs_deltaS2'});
rowsT = rowsT(rowsT.n_valid_I > 0, :);

% --- By I
cdfRegion = strings(nI, 1);
cdfRegion(tailI) = "tail_cdf_ge_0p80";
cdfRegion(coreI) = "core_cdf_0p35_0p65";
cdfRegion(shoulderI) = "shoulder_cdf_outside_core_pre_tail";
cdfRegion(cdfRegion == "") = "unclassified";

nValidT = zeros(nI, 1); meanAbsI = nan(nI, 1); rmsI = nan(nI, 1); maxAbsI = nan(nI, 1); fracI = nan(nI, 1);
for ii = 1:nI
    m = valid(:, ii);
    d = DeltaS2(m, ii);
    if isempty(d)
        continue;
    end
    nValidT(ii) = sum(m);
    meanAbsI(ii) = mean(abs(d));
    rmsI(ii) = sqrt(mean(d.^2));
    maxAbsI(ii) = max(abs(d));
    fracI(ii) = sum(abs(d)) / max(sumAbsFull, eps);
end
rowsI = table(allI(:), cdfAxis(:), cdfRegion(:), nValidT, meanAbsI, rmsI, maxAbsI, fracI, ...
    'VariableNames', {'current_mA', 'cdf_axis_mean_down_columns', 'cdf_region', 'n_valid_T', ...
    'mean_abs_deltaS2', 'rms_deltaS2', 'max_abs_deltaS2', 'frac_of_global_sum_abs_deltaS2'});
rowsI = rowsI(rowsI.n_valid_T > 0, :);

% --- Regional masks (cells)
tailMat = repmat(tailI(:)', nT, 1);
coreMat = repmat(coreI(:)', nT, 1);
shoulderMat = repmat(shoulderI(:)', nT, 1);
transRow = allT >= transitionBandK(1) & allT <= transitionBandK(2);
transMat = repmat(transRow(:), 1, nI);
mainRowMat = repmat(~transRow(:), 1, nI);

regionDefs = { ...
    'full_map', valid; ...
    'high_current_tail_cdf_ge_0p80', valid & tailMat; ...
    'cdf_shoulder_outside_core_pre_tail', valid & shoulderMat; ...
    'cdf_core_0p35_0p65', valid & coreMat; ...
    'transition_band_T_28_32K', valid & transMat; ...
    'main_inphase_excluding_transition_band', valid & mainRowMat};

nReg = size(regionDefs, 1);
rmse0 = zeros(nReg, 1); rmse1 = zeros(nReg, 1); rmse2 = zeros(nReg, 1);
meanAbsD = zeros(nReg, 1); fracAbsD = zeros(nReg, 1);
for r = 1:nReg
    M = regionDefs{r, 2};
    rmse0(r) = localRmse(Smap, pred0, M);
    rmse1(r) = localRmse(Smap, pred1, M);
    rmse2(r) = localRmse(Smap, pred2, M);
    meanAbsD(r) = mean(absD(M), 'omitnan');
    fracAbsD(r) = sum(absD(M), 'omitnan') / max(sumAbsFull, eps);
end

gainPhi1 = rmse0 - rmse1;
gainPhi2 = rmse1 - rmse2;
relGainPhi1 = gainPhi1 ./ max(rmse0, eps);
relGainPhi2 = gainPhi2 ./ max(rmse1, eps);

gainRows = table(string(regionDefs(:, 1)), rmse0, rmse1, rmse2, gainPhi1, gainPhi2, relGainPhi1, relGainPhi2, ...
    meanAbsD, fracAbsD, ...
    'VariableNames', {'region', 'rmse_backbone', 'rmse_backbone_phi1', 'rmse_backbone_phi1_phi2', ...
    'rmse_drop_backbone_to_phi1', 'rmse_drop_phi1_to_phi2', 'relative_rmse_drop_phi1', 'relative_rmse_drop_phi2', ...
    'mean_abs_deltaS2', 'fraction_of_global_sum_abs_deltaS2'});

writetable(rowsT, outByT);
writetable(rowsI, outByI);
writetable(gainRows, outGain);

% --- Rank T / I for report narrative
[~, ordT] = sort(rowsT.mean_abs_deltaS2, 'descend');
topT = rowsT.T_K(ordT(1:min(5, height(rowsT))));
[~, ordI] = sort(rowsI.mean_abs_deltaS2, 'descend');
topI = rowsI.current_mA(ordI(1:min(5, height(rowsI))));

% --- Verdict heuristics (documented thresholds)
ixFull = find(gainRows.region == "full_map", 1);
g2_full = gainRows.relative_rmse_drop_phi2(ixFull);
g2_tail = localPick(gainRows, "high_current_tail_cdf_ge_0p80", 'relative_rmse_drop_phi2');
g2_shoulder = localPick(gainRows, "cdf_shoulder_outside_core_pre_tail", 'relative_rmse_drop_phi2');
g2_core = localPick(gainRows, "cdf_core_0p35_0p65", 'relative_rmse_drop_phi2');
g2_trans = localPick(gainRows, "transition_band_T_28_32K", 'relative_rmse_drop_phi2');
g2_main = localPick(gainRows, "main_inphase_excluding_transition_band", 'relative_rmse_drop_phi2');

PHI2_MATTERS_FOR_RECONSTRUCTION = char(localTri(g2_full, 0.008, 0.025));
PHI2_GAIN_LOCALIZED_TO_TAIL = char(localCompareLocalized(g2_tail, g2_main, 0.012, 0.004));
PHI2_GAIN_LOCALIZED_TO_TRANSITION = char(localCompareLocalized(g2_trans, g2_main, 0.012, 0.004));
PHI2_GAIN_PRESENT_IN_MAIN_DOMAIN = char(localTri(g2_main, 0.004, 0.015));
fracTail = localPick(gainRows, "high_current_tail_cdf_ge_0p80", 'fraction_of_global_sum_abs_deltaS2');
fracSh = localPick(gainRows, "cdf_shoulder_outside_core_pre_tail", 'fraction_of_global_sum_abs_deltaS2');
fracCore = localPick(gainRows, "cdf_core_0p35_0p65", 'fraction_of_global_sum_abs_deltaS2');
mxFrac = max([fracTail, fracSh, fracCore], [], 'omitnan');
if mxFrac < 1e-9
    PHI2_IS_MAP_IMPORTANT = 'NO';
else
    dom = max([fracTail, fracSh, fracCore], [], 'omitnan');
    if strcmp(PHI2_MATTERS_FOR_RECONSTRUCTION, 'YES') || (isfinite(g2_full) && g2_full >= 0.015 && dom >= 0.25)
        PHI2_IS_MAP_IMPORTANT = 'YES';
    elseif strcmp(PHI2_MATTERS_FOR_RECONSTRUCTION, 'NO') && dom < 0.18 && isfinite(g2_full) && g2_full < 0.01
        PHI2_IS_MAP_IMPORTANT = 'NO';
    else
        PHI2_IS_MAP_IMPORTANT = 'PARTIAL';
    end
end

lines = {};
lines{end+1} = '# Switching Phi2 map-level contribution audit (canonical)';
lines{end+1} = '';
lines{end+1} = '## Scope';
lines{end+1} = '- **Inputs:** Identity-locked `switching_canonical_S_long.csv`, `switching_canonical_phi1.csv`, `switching_mode_amplitudes_vs_T.csv`, with S1 backbone gate `YES`.';
lines{end+1} = '- **Not used:** Phi2 replacement audit artifacts or any alternate Phi2 construction.';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID:** `%s`', canonicalRunId);
lines{end+1} = sprintf('- **Artifact paths:** S_long=`%s`, phi1=`%s`, amplitudes=`%s`.', sLongPath, phi1Path, ampPath);
lines{end+1} = '';
lines{end+1} = '## Locked map construction (no redefinition)';
lines{end+1} = '- `pred0 = S_model_pt_percent` (backbone map on the canonical grid).';
lines{end+1} = '- `pred1 = pred0 - kappa1(T) * Phi1(I)''` with `Phi1` normalized on `current_mA`.';
lines{end+1} = '- `R1 = S - pred1`; `Phi2` = first right singular vector of zero-filled `R1` (same as Stage E / physical-meaning audit).';
lines{end+1} = '- `pred2 = pred1 + kappa2(T) * Phi2(I)''`; **`DeltaS2 = pred2 - pred1 = kappa2(T) * Phi2(I)`** elementwise on the map.';
lines{end+1} = '';
lines{end+1} = '## Where |DeltaS2| is largest';
lines{end+1} = '### By temperature (see `tables/switching_phi2_map_contribution_by_T.csv`)';
lines{end+1} = sprintf('- Top mean-|DeltaS2| rows (K): **%s**', localJoinNum(topT));
lines{end+1} = '### By current (see `tables/switching_phi2_map_contribution_by_I.csv`)';
lines{end+1} = sprintf('- Top mean-|DeltaS2| columns (mA): **%s**', localJoinNum(topI));
lines{end+1} = '### By CDF region (column axis pooled over all T)';
lines{end+1} = sprintf(['- **Tail** (CDF_pt >= 0.80): share of sum|DeltaS2| = **%.4f**; relative RMSE drop Phi1→Phi2 in tail mask = **%.4f**.\n' ...
    '- **Shoulder** (outside core, pre-tail): **%.4f**; rel drop = **%.4f**.\n' ...
    '- **Core** (0.35 <= CDF <= 0.65): **%.4f**; rel drop = **%.4f**.'], ...
    fracTail, g2_tail, fracSh, g2_shoulder, fracCore, g2_core);
lines{end+1} = '';
lines{end+1} = '## Reconstruction RMSE by region';
lines{end+1} = '- `rmse_backbone`: sqrt(mean((S - pred0)^2)) on valid cells in the region.';
lines{end+1} = '- `rmse_backbone_phi1`: sqrt(mean((S - pred1)^2)).';
lines{end+1} = '- `rmse_backbone_phi1_phi2`: sqrt(mean((S - pred2)^2)).';
lines{end+1} = sprintf('- **Transition band:** %.1f–%.1f K (all currents where valid).', transitionBandK(1), transitionBandK(2));
lines{end+1} = '- **Main in-phase excluding transition:** all valid cells with T outside the transition band.';
lines{end+1} = '- Full numeric table: `tables/switching_phi2_reconstruction_gain_by_region.csv`.';
lines{end+1} = '';
lines{end+1} = '## Where Phi2 most helps (read from regional relative drops and |DeltaS2| mass)';
lines{end+1} = sprintf('- **High-current tail:** rel Phi2 drop = **%.4f** (fraction of |DeltaS2| mass **%.4f**).', g2_tail, fracTail);
lines{end+1} = sprintf('- **Asymmetric shoulder (CDF shoulder band):** rel drop **%.4f**, |DeltaS2| mass **%.4f**.', g2_shoulder, fracSh);
lines{end+1} = sprintf('- **Transition-adjacent rows (%.1f–%.1f K):** rel drop **%.4f** vs main-domain **%.4f**.', ...
    transitionBandK(1), transitionBandK(2), g2_trans, g2_main);
lines{end+1} = sprintf('- **Global residual amplitude:** full-map rel Phi2 drop **%.4f**; Phi1-stage RMSE **%.6f** → Phi2-stage **%.6f**.', ...
    g2_full, gainRows.rmse_backbone_phi1(ixFull), gainRows.rmse_backbone_phi1_phi2(ixFull));
lines{end+1} = '';
lines{end+1} = '## Final verdicts (automated thresholds; see table notes in this folder''s audits)';
lines{end+1} = sprintf('- **PHI2_MATTERS_FOR_RECONSTRUCTION** = **%s**  (full-map relative RMSE drop Phi1→Phi2: %.5f; YES if >= 0.025, NO if < 0.008).', ...
    PHI2_MATTERS_FOR_RECONSTRUCTION, g2_full);
lines{end+1} = sprintf('- **PHI2_GAIN_LOCALIZED_TO_TAIL** = **%s**  (tail vs main rel drops: %.5f vs %.5f).', ...
    PHI2_GAIN_LOCALIZED_TO_TAIL, g2_tail, g2_main);
lines{end+1} = sprintf('- **PHI2_GAIN_LOCALIZED_TO_TRANSITION** = **%s**  (transition band vs main: %.5f vs %.5f).', ...
    PHI2_GAIN_LOCALIZED_TO_TRANSITION, g2_trans, g2_main);
lines{end+1} = sprintf('- **PHI2_GAIN_PRESENT_IN_MAIN_DOMAIN** = **%s**  (main excluding transition rel drop: %.5f).', ...
    PHI2_GAIN_PRESENT_IN_MAIN_DOMAIN, g2_main);
lines{end+1} = sprintf('- **PHI2_IS_MAP_IMPORTANT** = **%s**  (combines reconstruction gain and pooled |DeltaS2| mass across CDF windows).', PHI2_IS_MAP_IMPORTANT);
lines{end+1} = '';

fid = fopen(outReport, 'w');
if fid < 0
    error('run_switching_phi2_map_contribution_audit:WriteReport', 'Cannot write %s', outReport);
end
fprintf(fid, '%s\n', lines{:});
fclose(fid);

fprintf('[OK] run_switching_phi2_map_contribution_audit\n');
fprintf('  %s\n', outByT);
fprintf('  %s\n', outByI);
fprintf('  %s\n', outGain);
fprintf('  %s\n', outReport);

function r = localRmse(S, P, M)
d = S(M) - P(M);
r = sqrt(mean(d.^2, 'omitnan'));
end

function v = localPick(tbl, key, col)
ix = find(tbl.region == string(key), 1);
if isempty(ix), v = NaN; else, v = tbl.(col)(ix); end
end

function s = localTri(x, noTh, yesTh)
if ~isfinite(x), s = 'PARTIAL'; return; end
if x >= yesTh
    s = 'YES';
elseif x < noTh
    s = 'NO';
else
    s = 'PARTIAL';
end
end

function s = localCompareLocalized(xLoc, xMain, strongTh, weakTh)
if ~isfinite(xLoc) || ~isfinite(xMain)
    s = 'PARTIAL';
    return;
end
if xLoc >= strongTh && (xLoc - xMain) >= weakTh
    s = 'YES';
elseif xLoc < weakTh && xMain >= xLoc
    s = 'NO';
else
    s = 'PARTIAL';
end
end

function s = localJoinNum(v)
v = v(:);
p = arrayfun(@(x) sprintf('%.4g', x), v, 'UniformOutput', false);
s = strjoin(p, ', ');
end
