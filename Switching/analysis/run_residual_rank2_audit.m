function run_residual_rank2_audit()
% run_residual_rank2_audit
% Determine whether residual sector is truly rank-1 or has a structured rank-2 component.
%
% Produces (in the new run folder):
%   tables/residual_rank_spectrum.csv
%   tables/mode2_correlation_summary.csv
%   figures/singular_values.png
%   figures/mode1_vs_mode2.png
%
% Key idea:
%   - Re-run switching_residual_decomposition_analysis for the baseline sources.
%   - Compute SVD of Rlow (residual matrix on x-grid for T<=30K).
%   - Evaluate mode-2 strength and correlations, with stability checks
%     excluding 22K and splitting by temperature regimes.

clearvars;
clc;

repoRoot = fileparts(fileparts(mfilename('fullpath'))); % .../Switching/analysis -> repo root
addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

% ---- Select baseline decomposition sources (the run we treat as "ground truth inputs") ----
% This run contains a residual_decomposition_sources.csv pointing to:
%   - alignment core map (.mat)
%   - full scaling parameters (.csv)
%   - PT matrix (.csv)
baseRunId = "run_2026_03_25_012517_rsr_child_baseline";
baseRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(baseRunId));
srcPath = fullfile(baseRunDir, 'tables', 'residual_decomposition_sources.csv');
assert(exist(srcPath, 'file') == 2, 'Missing sources: %s', srcPath);

src = readtable(srcPath);

alignmentRunId = pickSourceRunId(src, "alignment_core_map");
fullScalingRunId = pickSourceRunId(src, "full_scaling_parameters");
ptRunId = pickSourceRunId(src, "pt_matrix");

alignmentCorePath = pickSourceFile(src, "alignment_core_map");
fullScalingParamsPath = pickSourceFile(src, "full_scaling_parameters");
ptMatrixPath = pickSourceFile(src, "pt_matrix");

% ---- Audit configuration ----
canonicalMaxTemperatureK = 30;
nXGrid = 220;
fallbackSmoothWindow = 5;
maxModes = 2; %#ok<NASGU>
speakFloorFraction = 1e-3;

% Regimes (as used elsewhere in Switching structural analyses)
% NOTE: we still exclude 22K explicitly below.
regimeNames = ["global", "low_4_12K", "transition_14_20K", "high_22_30K"];
regimeRanges = [-inf inf; 4 12; 14 20; 22 30];

% Exclude 22K tolerance
exclude22KTolK = 0.25;

% ---- Run core decomposition (this returns residual matrix Rall, xGrid, temperatures, etc.) ----
auditRunLabel = sprintf('residual_rank2_audit_%s_%s', char(baseRunId), datestr(now, 'yyyymmdd_HHMMSS'));

decCfg = struct();
decCfg.runLabel = auditRunLabel;
decCfg.alignmentRunId = string(alignmentRunId);
decCfg.fullScalingRunId = string(fullScalingRunId);
decCfg.ptRunId = string(ptRunId);
decCfg.canonicalMaxTemperatureK = canonicalMaxTemperatureK;
decCfg.nXGrid = nXGrid;
decCfg.fallbackSmoothWindow = fallbackSmoothWindow;
decCfg.maxModes = 2;
decCfg.speakFloorFraction = speakFloorFraction;

fprintf('Running switching_residual_decomposition_analysis for audit run...\n');
outDec = switching_residual_decomposition_analysis(decCfg);
runDir = char(outDec.runDir);

% Output directories
tablesDir = fullfile(runDir, 'tables');
figuresDir = fullfile(runDir, 'figures');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(figuresDir, 'dir') ~= 7, mkdir(figuresDir); end

% ---- Recompute SVD on residual matrix (canonical low-T window) ----
tempsK = outDec.temperaturesK(:);
Ipeak_mA = outDec.Ipeak_mA(:);
kappaAll = outDec.kappaAll(:);
lowMask = outDec.lowTemperatureMask(:);
assert(numel(lowMask) == numel(tempsK), 'lowTemperatureMask size mismatch.');

Rall = outDec.Rall; % size: nT x nX
xGrid = outDec.xGrid(:);

% Build the canonical residual matrix used for rank-1/2 decision
Tlow = tempsK(lowMask);
IpeakLow = Ipeak_mA(lowMask);
kappaLow = kappaAll(lowMask);
Rlow = Rall(lowMask, :);

% SVD for a general subset is implemented via a helper.
subsetDefs = buildSubsetDefs(Tlow, exclude22KTolK, regimeNames, regimeRanges);
% The helper handles selection masks for each subset name.

rankRows = {};
corrRows = {};

% For plotting singular values and mode shapes, use the "all low (incl 22K)" subset.
baselineSubsetName = "T_le_30K_including22K";

svBaseline = computeSvdAndModeMetrics(Rlow, Tlow, IpeakLow, kappaLow, xGrid, baselineSubsetName);

% Plot singular values
plotSingularValues(svBaseline, figuresDir);
plotMode1VsMode2(svBaseline, figuresDir);

for si = 1:numel(subsetDefs)
    sd = subsetDefs(si);
    name = sd.name;
    m = sd.mask;

    if sum(m) < 2
        sv = struct();
        sv.subset_name = name;
        sv.n_rows = sum(m);
        sv.sigma1 = NaN;
        sv.sigma2 = NaN;
        sv.sigma1_over_sigma2 = NaN;
        sv.var_mode1 = NaN;
        sv.var_mode1_2 = NaN;
        sv.improvement_mode2 = NaN;
        sv.mode2_sym_odd_power_frac = NaN;
        sv.mode2_sym_even_power = NaN;
        sv.mode2_sym_odd_power = NaN;
        sv.mode2_even_odd_label = "n/a";
        sv.mode2_coeff = NaN(size(Tlow));
        sv.mode2_vec = NaN(size(xGrid));
        sv.mode1_vec = NaN(size(xGrid));
    else
        Rsub = Rlow(m, :);
        Tsub = Tlow(m);
        IpeakSub = IpeakLow(m);
        kappaSub = kappaLow(m);
        sv = computeSvdAndModeMetrics(Rsub, Tsub, IpeakSub, kappaSub, xGrid, name);
    end

    rankRows{end+1, 1} = formatRankRow(sv); %#ok<AGROW>

    % Correlations of mode-2 coefficients with scalar descriptors
    corr = computeMode2Correlations(sv, Tlow, IpeakLow, kappaLow, m, ptMatrixPath);
    corrRows{end+1, 1} = corr; %#ok<AGROW>
end

rankTbl = vertcat(rankRows{:});
corrTbl = vertcat(corrRows{:});

writetable(rankTbl, fullfile(tablesDir, 'residual_rank_spectrum.csv'));
writetable(corrTbl, fullfile(tablesDir, 'mode2_correlation_summary.csv'));

fprintf('\n=== Residual rank-2 audit complete ===\n');
fprintf('Run folder: %s\n', runDir);

% ---- Final verdict (heuristic thresholds; based on dominance + correlation + symmetry) ----
[condHighLow, condCorr] = makeConditionalShapeMetrics(Rlow, Tlow, IpeakLow, kappaLow, exclude22KTolK);
[verdictText, verdictRow] = makeFinalVerdict(rankTbl, corrTbl, baselineSubsetName, condHighLow, condCorr);
fprintf('\nFINAL VERDICT:\n%s\n', verdictText);

% Also export a one-row "verdict" table for easy tracking (not required by user, but helpful).
try
    verdictTbl = verdictRow;
    writetable(verdictTbl, fullfile(tablesDir, 'residual_rank2_audit_verdict.csv'));
catch
    % ignore
end

end

%% ======================================================================
% Helpers
%% ======================================================================

function sid = pickSourceRunId(srcTbl, roleName)
idx = find(strcmp(string(srcTbl.source_role), string(roleName)), 1, 'first');
assert(~isempty(idx), 'Missing source role: %s', roleName);
sid = string(srcTbl.source_run_id(idx));
end

function f = pickSourceFile(srcTbl, roleName)
idx = find(strcmp(string(srcTbl.source_role), string(roleName)), 1, 'first');
assert(~isempty(idx), 'Missing source role: %s', roleName);
f = char(srcTbl.source_file(idx));
end

function subsetDefs = buildSubsetDefs(Tlow, exclude22KTolK, regimeNames, regimeRanges)
% Returns struct array: name + mask (over the canonical low-temperature rows).
isFiniteT = isfinite(Tlow);

baseMaskAll = isFiniteT;
subsetDefs = [];
subsetDefs(end+1) = struct('name', "T_le_30K_including22K", 'mask', baseMaskAll); %#ok<AGROW>

exclude22Mask = isFiniteT & ~(abs(Tlow - 22) <= exclude22KTolK);
subsetDefs(end+1) = struct('name', "exclude_22K", 'mask', exclude22Mask); %#ok<AGROW>

for rr = 1:numel(regimeNames)
    rmin = regimeRanges(rr, 1);
    rmax = regimeRanges(rr, 2);
    if rr == 1
        mReg = exclude22Mask;
    else
        mReg = exclude22Mask & (Tlow >= rmin) & (Tlow <= rmax);
    end
    subsetDefs(end+1) = struct('name', regimeNames(rr), 'mask', mReg); %#ok<AGROW>
end
end

function sv = computeSvdAndModeMetrics(Rsub, Tsub, IpeakSub, kappaSub, xGrid, subsetName) %#ok<INUSL>
% Rsub is residual matrix for a subset, with rows=temperatures and cols=xGrid.
% Any non-finite values are set to 0 before SVD.

R0 = double(Rsub);
R0(~isfinite(R0)) = 0;

[U, S, V] = svd(R0, 'econ');
s = diag(S);
energy = s.^2;
totalE = max(sum(energy, 'omitnan'), eps);
ef = energy ./ totalE;

nRows = size(R0, 1);

sv.subset_name = subsetName;
sv.n_rows = nRows;
sv.singular_values = s;

if numel(s) >= 1
    sv.sigma1 = s(1);
    sv.var_mode1 = ef(1);
else
    sv.sigma1 = NaN;
    sv.var_mode1 = NaN;
end

if numel(s) >= 2
    sv.sigma2 = s(2);
    sv.sigma1_over_sigma2 = s(1) / max(s(2), eps);
    sv.var_mode1_2 = ef(1) + ef(2);
    sv.improvement_mode2 = ef(2);
else
    sv.sigma2 = NaN;
    sv.sigma1_over_sigma2 = NaN;
    sv.var_mode1_2 = NaN;
    sv.improvement_mode2 = NaN;
end

% Mode vectors (V are orthonormal)
if size(V, 2) >= 2
    sv.mode1_vec = V(:, 1);
    sv.mode2_vec = V(:, 2);
    sv.mode2_coeff = U(:, 2) * s(2); % row amplitudes along mode2
    sv.mode1_coeff = U(:, 1) * s(1);
else
    sv.mode1_vec = V(:, 1);
    sv.mode2_vec = NaN(size(V,1), 1);
    sv.mode2_coeff = NaN(size(U,1), 1);
    sv.mode1_coeff = U(:, 1) * s(1);
end

% Symmetry analysis of mode2 vector via even/odd decomposition under flipud.
if all(isfinite(sv.mode2_vec))
    psi2 = sv.mode2_vec(:);
    psi2_flip = flipud(psi2);
    oddPart = 0.5 * (psi2 - psi2_flip);
    evenPart = 0.5 * (psi2 + psi2_flip);
    oddPower = sum(oddPart .^ 2, 'omitnan');
    evenPower = sum(evenPart .^ 2, 'omitnan');
    denom = max(oddPower + evenPower, eps);
    sv.mode2_sym_odd_power_frac = oddPower / denom;
    sv.mode2_sym_even_power = evenPower;
    sv.mode2_sym_odd_power = oddPower;
    if oddPower > 1.2 * evenPower
        sv.mode2_even_odd_label = "odd-dominated";
    elseif evenPower > 1.2 * oddPower
        sv.mode2_even_odd_label = "even-dominated";
    else
        sv.mode2_even_odd_label = "mixed";
    end
else
    sv.mode2_sym_odd_power_frac = NaN;
    sv.mode2_sym_even_power = NaN;
    sv.mode2_sym_odd_power = NaN;
    sv.mode2_even_odd_label = "n/a";
end

% Keep subset scalars for possible debugging/conditioning.
sv.Tsub = Tsub;
sv.IpeakSub = IpeakSub;
sv.kappaSub = kappaSub;
sv.xGrid = xGrid;
end

function rankRow = formatRankRow(sv)
rankRow = table( ...
    string(sv.subset_name), sv.n_rows, sv.sigma1, sv.sigma2, sv.sigma1_over_sigma2, ...
    sv.var_mode1, sv.var_mode1_2, sv.improvement_mode2, sv.mode2_sym_even_odd_label, ...
    sv.mode2_sym_odd_power_frac, sv.mode2_sym_odd_power, sv.mode2_sym_even_power, ...
    'VariableNames', { ...
        'subset', 'n_rows', 'sigma1', 'sigma2', 'sigma1_over_sigma2', ...
        'variance_mode1', 'variance_mode1_2', 'improvement_mode2', ...
        'mode2_symmetry_label', 'mode2_sym_odd_power_frac', ...
        'mode2_sym_odd_power', 'mode2_sym_even_power' ...
    });
end

function sv = computeMode2Correlations(sv, Tlow, IpeakLow, kappaLow, mask, ptMatrixPath) %#ok<INUSD>
% Returns updated sv (augmented with correlation results) as a table row struct.

% Only compute when we have finite mode2 coefficients.
if ~all(isfinite(sv.mode2_coeff)) && isempty(sv.mode2_coeff)
    % keep NaNs
end

Tsub = Tlow(mask);
IpeakSub = IpeakLow(mask);
kappaSub = kappaLow(mask);

coeff2 = sv.mode2_coeff(:);

% Correlations require matching lengths
N = min([numel(coeff2), numel(Tsub), numel(IpeakSub), numel(kappaSub)]);
coeff2 = coeff2(1:N);
Tsub = Tsub(1:N);
IpeakSub = IpeakSub(1:N);
kappaSub = kappaSub(1:N);

ptDesc = computePtSvdScores(ptMatrixPath, Tsub); % returns pt_svd_score1/2 aligned by T
pt1 = ptDesc.pt_svd_score1(:);
pt2 = ptDesc.pt_svd_score2(:);

c1 = safeCorr(coeff2, IpeakSub);
cK = safeCorr(coeff2, kappaSub);
cT = safeCorr(coeff2, Tsub);
cpt1 = safeCorr(coeff2, pt1);
cpt2 = safeCorr(coeff2, pt2);

% Select best absolute correlation among provided descriptors.
[bestAbs, bestIdx] = max(abs([c1, cpt2, cK, cT, cpt1]));
predNames = ["I_peak", "pt_svd_score2", "kappa", "temperature", "pt_svd_score1"];
bestName = predNames(bestIdx);
bestCorr = [c1, cpt2, cK, cT, cpt1];
bestCorrVal = bestCorr(bestIdx);

sv_corr = table( ...
    string(sv.subset_name), sv.n_rows, ...
    safeFiniteCount(coeff2, IpeakSub), safeFiniteCount(coeff2, pt2), safeFiniteCount(coeff2, kappaSub), safeFiniteCount(coeff2, Tsub), ...
    c1, cpt1, cpt2, cK, cT, ...
    bestName, bestCorrVal, bestAbs, ...
    string(sv.mode2_even_odd_label), sv.mode2_sym_odd_power_frac, ...
    'VariableNames', { ...
        'subset', 'n_rows', 'n_corr_pairs_Ipeak', 'n_corr_pairs_pt_svd2', 'n_corr_pairs_kappa', 'n_corr_pairs_T', ...
        'corr_mode2_I_peak', 'corr_mode2_pt_svd_score1', 'corr_mode2_pt_svd_score2', ...
        'corr_mode2_kappa', 'corr_mode2_temperature', ...
        'best_corr_predictor', 'best_corr_value', 'best_abs_corr', ...
        'mode2_symmetry_label', 'mode2_sym_odd_power_frac' ...
    });

% Return in-place as a struct-like table.
sv = sv_corr; %#ok<NASGU>
end

function ptDesc = computePtSvdScores(ptMatrixPath, Tsub)
% Reproduce pt_svd_score1/2 calculation from run_barrier_to_relaxation_mechanism.m:
%   - normalize each PT row to sum=1
%   - compute v1,v2 from row-valid subset by SVD of row-centered PT
%   - pt_svd_scoreK = dot(pc - mean(pc), vK)
%
% Output:
%   ptDesc has fields pt_svd_score1, pt_svd_score2 aligned to Tsub.

raw = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
T_K_all = double(raw.(raw.Properties.VariableNames{1}));
varNames = raw.Properties.VariableNames(2:end);
nI = numel(varNames);
I_mA = nan(nI, 1);
for j = 1:nI
    I_mA(j) = parseCurrentHeader(varNames{j});
end
Praw = nan(numel(T_K_all), nI);
for j = 1:nI
    Praw(:, j) = double(raw.(varNames{j}));
end

% Sort by I
[I_mA, ordI] = sort(I_mA, 'ascend');
Praw = Praw(:, ordI);

nT = numel(T_K_all);
Pcent = nan(nT, nI);
validRow = false(nT, 1);
muRow = nan(nT, 1);

for i = 1:nT
    p = Praw(i, :);
    p = fillmissing(p(:)', 'constant', 0);
    s = sum(p, 'omitnan');
    if s > 0
        p = p ./ s;
    else
        p = nan(1, nI);
    end
    Pcent(i, :) = p;
    validRow(i) = s > 0 && sum(isfinite(p)) >= 3;
    if validRow(i)
        muRow(i) = sum(p .* I_mA, 'omitnan');
    end
end

% v1,v2 from row-valid subset
vr = validRow(:);
v1 = nan(nI, 1);
v2 = nan(nI, 1);
if sum(vr) >= 2
    Psub = Pcent(vr, :) - mean(Pcent(vr, :), 1);
    [~, ~, V] = svd(Psub, 'econ');
    v1 = V(:, 1);
    if size(V, 2) >= 2
        v2 = V(:, 2);
    end
end

muGlobal = mean(muRow(validRow), 'omitnan'); %#ok<NASGU>

% Compute scores for all T rows, then pick Tsub
pt1_all = nan(nT, 1);
pt2_all = nan(nT, 1);
for i = 1:nT
    ok = validRow(i);
    if ~ok
        continue;
    end
    pc = Pcent(i, :);
    pt1_all(i) = dot(pc(:) - mean(pc(:)), v1);
    if all(isfinite(v2))
        pt2_all(i) = dot(pc(:) - mean(pc(:)), v2);
    end
end

% Align to Tsub by nearest temperature.
pt_svd_score1 = nan(size(Tsub));
pt_svd_score2 = nan(size(Tsub));
for k = 1:numel(Tsub)
    t = Tsub(k);
    [~, idx] = min(abs(T_K_all - t));
    if abs(T_K_all(idx) - t) <= 1e-6
        pt_svd_score1(k) = pt1_all(idx);
        pt_svd_score2(k) = pt2_all(idx);
    else
        % if no exact match, allow small tolerance
        if abs(T_K_all(idx) - t) <= 0.25
            pt_svd_score1(k) = pt1_all(idx);
            pt_svd_score2(k) = pt2_all(idx);
        end
    end
end

ptDesc = struct();
ptDesc.pt_svd_score1 = pt_svd_score1;
ptDesc.pt_svd_score2 = pt_svd_score2;
end

function r = safeCorr(x, y)
v = isfinite(x) & isfinite(y);
x = x(v);
y = y(v);
if numel(x) < 3
    r = NaN;
    return;
end
C = corrcoef(x, y);
r = C(1, 2);
end

function n = safeFiniteCount(x, y)
v = isfinite(x) & isfinite(y);
n = nnz(v);
end

function plotSingularValues(sv, figuresDir)
% singular_values.png: plot normalized singular values (top modes).
if isempty(sv) || ~isfield(sv, 'singular_values') || isempty(sv.singular_values)
    return;
end

s = sv.singular_values(:);
s1 = s(1);
if ~isfinite(s1) || s1 == 0
    return;
end

maxShow = min(12, numel(s));
kk = (1:maxShow)';
ratio = s(1:maxShow) ./ max(s1, eps);

fig = figure('Color', 'w', 'Visible', 'off');
plot(kk, log10(max(ratio, eps)), 'o-', 'LineWidth', 2);
grid on;
xlabel('Mode index k');
ylabel('log_{10}(\sigma_k / \sigma_1)');
title('Residual sector singular spectrum (top modes)');
saveas(fig, fullfile(figuresDir, 'singular_values.png'));
close(fig);
end

function plotMode1VsMode2(sv, figuresDir)
if ~isfinite(sv.sigma2) || ~all(isfinite(sv.mode2_vec))
    return;
end

phi1 = sv.mode1_vec(:);
psi2 = sv.mode2_vec(:);

% Normalize both to max abs = 1 for visual comparison.
phi1 = phi1 ./ max(abs(phi1), eps);
psi2 = psi2 ./ max(abs(psi2), eps);

fig = figure('Color', 'w', 'Visible', 'off');
plot(sv.xGrid, phi1, 'LineWidth', 2.2, 'DisplayName', 'Mode 1 (phi)');
hold on;
plot(sv.xGrid, psi2, '--', 'LineWidth', 2.2, 'DisplayName', 'Mode 2 (psi_2)');
grid on;
xlabel('x = (I - I_{peak}) / w');
ylabel('Normalized mode amplitude');
title(sprintf('Mode shapes: %s', char(sv.subset_name)));
legend('Location', 'best');
saveas(fig, fullfile(figuresDir, 'mode1_vs_mode2.png'));
close(fig);
end

function [condHighLow, condCorr] = makeConditionalShapeMetrics(Rlow, Tlow, IpeakLow, kappaLow, exclude22KTolK)
% Conditional shape analysis:
%   - residual normalized by kappa proxy (mode-1 SVD amplitude)
%   - group by I_peak high/low (median split)

excludeMask = isfinite(Tlow) & ~(abs(Tlow - 22) <= exclude22KTolK);
Tsub = Tlow(excludeMask);
Isub = IpeakLow(excludeMask);
Rsub = Rlow(excludeMask, :);

condHighLow = table();
condCorr = struct();
condCorr.corr_ampRatio_vs_Ipeak = NaN;

if sum(excludeMask) < 3
    return;
end

R0 = double(Rsub);
R0(~isfinite(R0)) = 0;
[U, S, ~] = svd(R0, 'econ');
s = diag(S);
if numel(s) < 2
    return;
end

coeff1 = U(:, 1) * s(1);
coeff2 = U(:, 2) * s(2);
ampRatio = coeff2 ./ max(abs(coeff1), eps);

medI = median(Isub, 'omitnan');
highMask = isfinite(Isub) & Isub >= medI;
lowMask = isfinite(Isub) & Isub < medI;

ampHigh = ampRatio(highMask);
ampLow = ampRatio(lowMask);

condHighLow = table( ...
    sum(highMask), sum(lowMask), ...
    mean(abs(ampHigh), 'omitnan'), mean(abs(ampLow), 'omitnan'), ...
    median(Isub, 'omitnan'), ...
    'VariableNames', {'n_high_Ipeak', 'n_low_Ipeak', 'mean_abs_ampRatio_high', 'mean_abs_ampRatio_low', 'median_Ipeak'} );

v = isfinite(ampRatio) & isfinite(Isub);
if nnz(v) >= 3
    condCorr.corr_ampRatio_vs_Ipeak = corr(ampRatio(v), Isub(v), 'type', 'Pearson');
end

end

function [txt, row] = makeFinalVerdict(rankTbl, corrTbl, baselineSubsetName, condHighLow, condCorr)
% Heuristic thresholds to translate quantitative metrics into:
%   RESIDUAL_RANK1: EXACT / APPROXIMATE / INSUFFICIENT
%   RANK2_STRUCTURE: NONE / WEAK / STRUCTURED

% Prefer excluding 22K + "global" regime row if present.
preferSubsetOrder = ["exclude_22K", "global", "T_le_30K_including22K"];
chosenSubset = "";
for i = 1:numel(preferSubsetOrder)
    if any(rankTbl.subset == preferSubsetOrder(i))
        chosenSubset = preferSubsetOrder(i);
        break;
    end
end
if strlength(chosenSubset) == 0
    chosenSubset = baselineSubsetName;
end

rowR = rankTbl(rankTbl.subset == chosenSubset, :);
if isempty(rowR)
    rowR = rankTbl(1, :);
end

sigmaRatio = rowR.sigma1_over_sigma2(1);
var1 = rowR.variance_mode1(1);
var1_2 = rowR.variance_mode1_2(1);
impr = rowR.improvement_mode2(1);

% Use best correlation magnitude in the same subset (if available)
rowC = corrTbl(corrTbl.subset == chosenSubset, :);
if isempty(rowC)
    rowC = corrTbl(1, :);
end
bestAbsCorr = rowC.best_abs_corr(1);
bestPred = rowC.best_corr_predictor(1);
bestCorrVal = rowC.best_corr_value(1);
symLabel = rowR.mode2_symmetry_label(1);
oddFrac = rowR.mode2_sym_odd_power_frac(1);

condMeanAbsHigh = NaN;
condMeanAbsLow = NaN;
condCorrVal = NaN;
if ~isempty(condHighLow) && height(condHighLow) >= 1
    if ismember('mean_abs_ampRatio_high', condHighLow.Properties.VariableNames)
        condMeanAbsHigh = condHighLow.mean_abs_ampRatio_high(1);
    end
    if ismember('mean_abs_ampRatio_low', condHighLow.Properties.VariableNames)
        condMeanAbsLow = condHighLow.mean_abs_ampRatio_low(1);
    end
end
if ~isempty(condCorr) && isfield(condCorr, 'corr_ampRatio_vs_Ipeak')
    condCorrVal = condCorr.corr_ampRatio_vs_Ipeak;
end

% Translate to rank-1 verdict
if isfinite(sigmaRatio) && sigmaRatio >= 10 && isfinite(var1) && var1 >= 0.98 && (impr <= 0.01 || ~isfinite(impr))
    rank1Verdict = "EXACT";
elseif isfinite(sigmaRatio) && sigmaRatio >= 4 && isfinite(var1) && var1 >= 0.9
    rank1Verdict = "APPROXIMATE";
else
    rank1Verdict = "INSUFFICIENT";
end

% Translate to rank-2 structure verdict
if (isfinite(impr) && impr >= 0.03) && bestAbsCorr >= 0.35
    rank2Verdict = "STRUCTURED";
elseif (isfinite(impr) && impr >= 0.015) || bestAbsCorr >= 0.25
    rank2Verdict = "WEAK";
else
    rank2Verdict = "NONE";
end

txt = sprintf([ ...
    'RESIDUAL_RANK1: %s\\n' ...
    'RANK2_STRUCTURE: %s\\n' ...
    'Chosen subset: %s\\n' ...
    'Variance explained: mode1=%.4f, mode1+2=%.4f (mode2 improvement=%.4f)\\n' ...
    'Dominance: sigma1/sigma2=%.4f\\n' ...
    'Strongest correlation for mode2: %s (corr=%.4f)\\n' ...
    'Mode2 symmetry: %s (odd_power_frac=%.3f)\\n' ...
    'Conditional shape (exclude22K): mean|coeff2/coeff1| high=%.4f, low=%.4f; corr(ampRatio,Ipeak)=%.4f'], ...
    rank1Verdict, rank2Verdict, chosenSubset, var1, var1_2, impr, sigmaRatio, ...
    char(bestPred), bestCorrVal, char(symLabel), oddFrac, ...
    condMeanAbsHigh, ...
    condMeanAbsLow, ...
    condCorrVal);

row = table( ...
    string(rank1Verdict), string(rank2Verdict), string(chosenSubset), ...
    var1, var1_2, impr, sigmaRatio, ...
    bestPred, bestCorrVal, bestAbsCorr, ...
    string(symLabel), oddFrac, ...
    'VariableNames', { ...
        'RESIDUAL_RANK1', 'RANK2_STRUCTURE', 'chosen_subset', ...
        'variance_mode1', 'variance_mode1_2', 'improvement_mode2', 'sigma1_over_sigma2', ...
        'best_corr_predictor', 'best_corr_value', 'best_abs_corr', ...
        'mode2_symmetry_label', 'mode2_sym_odd_power_frac' ...
    });
end

function iMa = parseCurrentHeader(h)
% Parse numeric current value from PT/descriptor column headers.
% Example: "Ith_15_mA" -> 15
s = lower(string(h));
tok = regexp(s, '(\d+\.?\d*)', 'once', 'match');
if isempty(tok)
    iMa = NaN;
else
    iMa = str2double(tok);
end
end

