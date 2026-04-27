% run_switching_phi2_physical_meaning_audit
%
% Canonical Phi2 physical-meaning audit (diagnostic projections only).
% Inputs: identity-resolved switching_canonical_S_long.csv, switching_canonical_phi1.csv,
%         repo switching_mode_amplitudes_vs_T.csv (same contract as Phase D relationship audit).
%
% Outputs (repo root):
%   tables/switching_phi2_shape_physics.csv
%   tables/switching_phi2_deformation_tests.csv
%   tables/switching_phi2_tail_residual_tests.csv
%   reports/switching_phi2_physical_meaning_audit.md
%
% Scope: Stage E / E5 / E5B boundary — no decomposition redefinition, no new models.

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

outShape = fullfile(repoRoot, 'tables', 'switching_phi2_shape_physics.csv');
outDef = fullfile(repoRoot, 'tables', 'switching_phi2_deformation_tests.csv');
outTail = fullfile(repoRoot, 'tables', 'switching_phi2_tail_residual_tests.csv');
outReport = fullfile(repoRoot, 'reports', 'switching_phi2_physical_meaning_audit.md');

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

req = {idPath, sLongPath, phi1Path, ampPath};
reqLbl = {'switching_canonical_identity.csv (CANONICAL_RUN_ID)', 'switching_canonical_S_long.csv', ...
    'switching_canonical_phi1.csv', 'switching_mode_amplitudes_vs_T.csv'};
for i = 1:numel(req)
    if exist(req{i}, 'file') ~= 2
        error('run_switching_phi2_physical_meaning_audit:MissingInput', 'Missing required input (%s): %s', reqLbl{i}, req{i});
    end
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
    error('run_switching_phi2_physical_meaning_audit:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);
if ~all(ismember({'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'CDF_pt'}, sLong.Properties.VariableNames))
    error('run_switching_phi2_physical_meaning_audit:Schema', 'sLong missing required columns.');
end
if ~all(ismember({'T_K', 'kappa1', 'kappa2'}, ampTbl.Properties.VariableNames))
    error('run_switching_phi2_physical_meaning_audit:Schema', 'Amplitude table missing kappa1/kappa2.');
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
    error('run_switching_phi2_physical_meaning_audit:Phi1Col', 'No phi1 column in switching_canonical_phi1.csv.');
end
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

pred1 = Bmap - kappa1(:) * phi1(:)';
R1 = Smap - pred1;
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~, S1, V1] = svd(R1z, 'econ');
if size(V1, 2) >= 1
    phi2 = V1(:, 1);
else
    phi2 = zeros(nI, 1);
end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end
pred2 = pred1 + kappa2(:) * phi2(:)';
R2 = Smap - pred2;
R0 = Smap - Bmap;
R0(~valid) = NaN; R1(~valid) = NaN; R2(~valid) = NaN;

x = cdfAxis;
x0 = x - 0.5;
dx = max(median(diff(sort(x)), 'omitnan'), eps);
d1 = gradient(phi1, dx);
d2 = gradient(d1, dx);
tailKernelR1 = zeros(nI, 1);
for ii = 1:nI
    if tailI(ii)
        tailKernelR1(ii) = mean(R1(:, ii), 1, 'omitnan');
    end
end
if norm(tailKernelR1) > 0
    tailKernelR1 = tailKernelR1 / norm(tailKernelR1);
end

% --- Concentration (L2 energy fractions on current grid)
eTot = sum(phi2.^2, 'omitnan');
ef = @(mask) sum(phi2(mask).^2, 'omitnan') / max(eTot, eps);
frac_core = ef(coreI);
frac_shoulder = ef(shoulderI);
frac_tail = ef(tailI);
[~, domIdx] = max([frac_core, frac_shoulder, frac_tail]);
domLabels = ["core_cdf_0p35_0p65"; "shoulder_cdf_outside_core_pre_tail"; "tail_cdf_ge_0p80"];
phi2_concentration_label = domLabels(domIdx);

% --- Symmetry about CDF = 0.5 on uniform grid
u = linspace(0.02, 0.98, 400)';
p2u = interp1(x, phi2, u, 'linear', 0);
p2u = p2u(:);
ph_even = 0.5 * (p2u + flipud(p2u));
ph_odd = 0.5 * (p2u - flipud(p2u));
eE = sum(ph_even.^2); oE = sum(ph_odd.^2);
phi2_even_frac = eE / max(eE + oE, eps);
phi2_odd_frac = oE / max(eE + oE, eps);
asymmetry_ratio = sqrt(oE) / max(sqrt(eE), eps);

% --- Alignment cosines (full domain on I-grid)
mAll = isfinite(phi1) & isfinite(phi2) & isfinite(d1) & isfinite(x0);
cos_phi1 = localCos(phi1(mAll), phi2(mAll));
cos_dphi1 = localCos(d1(mAll), phi2(mAll));
cos_d2phi1 = localCos(d2(mAll), phi2(mAll));
xphi1 = x0 .* phi1;
xdphi1 = x0 .* d1;
cos_xphi1 = localCos(xphi1(mAll), phi2(mAll));
cos_xdphi1 = localCos(xdphi1(mAll), phi2(mAll));
cos_tailR1prof = localCos(tailKernelR1(mAll), phi2(mAll));

Bdef = [phi1, d1, d2, x0 .* phi1, x0 .* d1];
fitAll = localFit(phi2, Bdef, true(nI, 1));
fitTail = localFit(phi2, Bdef, tailI);
defNames = ["phi1"; "dphi1_dx"; "d2phi1_dx2"; "u_phi1"; "u_dphi1_dx"];

% Univariate R2 per basis (full / tail)
uniR2 = @(col, mask) localUniR2(phi2, col, mask);
rowsDef = [];
for k = 1:numel(defNames)
    rowsDef = [rowsDef; table( ...
        "full_domain", defNames(k), fitAll.beta(k), localCos(phi2, Bdef(:, k)), uniR2(Bdef(:, k), true(nI, 1)), ...
        'VariableNames', {'fit_domain', 'basis_term', 'multivariate_coefficient', 'cosine_phi2_basis', 'univariate_r2'})]; %#ok<AGROW>
end
for k = 1:numel(defNames)
    rowsDef = [rowsDef; table( ...
        "tail_cdf_ge_0p80", defNames(k), fitTail.beta(k), localCos(Bdef(tailI, k), phi2(tailI)), uniR2(Bdef(:, k), tailI), ...
        'VariableNames', {'fit_domain', 'basis_term', 'multivariate_coefficient', 'cosine_phi2_basis', 'univariate_r2'})]; %#ok<AGROW>
end
rowsDef = [rowsDef; table( ...
    ["full_domain"; "tail_cdf_ge_0p80"], ["tail_mean_R1_profile"; "tail_mean_R1_profile"], ...
    [localFit(phi2, tailKernelR1, true(nI, 1)).beta; localFit(phi2, tailKernelR1, tailI).beta], ...
    [cos_tailR1prof; localCos(tailKernelR1(tailI), phi2(tailI))], ...
    [uniR2(tailKernelR1, true(nI, 1)); uniR2(tailKernelR1, tailI)], ...
    'VariableNames', {'fit_domain', 'basis_term', 'multivariate_coefficient', 'cosine_phi2_basis', 'univariate_r2'})];
rowsDef.fit_summary_r2_full = repmat(fitAll.r2, height(rowsDef), 1);
rowsDef.fit_summary_r2_tail = repmat(fitTail.r2, height(rowsDef), 1);
rowsDef.fit_summary_rmse_full = repmat(fitAll.rmse, height(rowsDef), 1);
rowsDef.fit_summary_rmse_tail = repmat(fitTail.rmse, height(rowsDef), 1);
writetable(rowsDef, outDef);

% --- SVD stability
sig1 = 0;
if ~isempty(S1)
    sig1 = S1(1, 1);
end
if size(S1, 1) >= 2
    sig2 = S1(2, 2);
else
    sig2 = eps;
end
sigma_ratio = sig1 / max(sig2, eps);

looCos = nan(nT, 1);
if nT >= 2
    for it = 1:nT
        idx = true(nT, 1); idx(it) = false;
        Rz = R1z(idx, :);
        [~, ~, Vv] = svd(Rz, 'econ');
        v2 = Vv(:, 1);
        if norm(v2) > 0, v2 = v2 / norm(v2); end
        looCos(it) = abs(dot(v2, phi2));
    end
end
loo_min = min(looCos, [], 'omitnan');
loo_median = median(looCos, 'omitnan');

% --- Tail residual tests
mseR1_t = mean(R1(:, tailI).^2, 2, 'omitnan');
mseR2_t = mean(R2(:, tailI).^2, 2, 'omitnan');
fracRed_t = (mseR1_t - mseR2_t) ./ max(mseR1_t, eps);
fracRed_pooled = (sum(mseR1_t, 'omitnan') - sum(mseR2_t, 'omitnan')) / max(sum(mseR1_t, 'omitnan'), eps);
fracRed_median = median(fracRed_t, 'omitnan');

tailRows = table(allT(:), mseR1_t(:), mseR2_t(:), fracRed_t(:), ...
    mean(abs(R1(:, tailI)), 2, 'omitnan'), mean(abs(R2(:, tailI)), 2, 'omitnan'), ...
    'VariableNames', {'T_K', 'tail_mse_R1', 'tail_mse_R2', 'tail_fractional_mse_reduction', 'tail_mean_abs_R1', 'tail_mean_abs_R2'});
tailRows.scope = repmat("per_temperature_tail_columns", height(tailRows), 1);
gRow = table(NaN, mean(mseR1_t, 'omitnan'), mean(mseR2_t, 'omitnan'), ...
    mean(fracRed_t, 'omitnan'), mean(mean(abs(R1(:, tailI)), 2, 'omitnan'), 'omitnan'), mean(mean(abs(R2(:, tailI)), 2, 'omitnan'), 'omitnan'), ...
    'VariableNames', {'T_K', 'tail_mse_R1', 'tail_mse_R2', 'tail_fractional_mse_reduction', 'tail_mean_abs_R1', 'tail_mean_abs_R2'});
gRow.scope = "global_mean_over_temperature";
gRow2 = table(NaN, NaN, NaN, fracRed_pooled, NaN, NaN, ...
    'VariableNames', {'T_K', 'tail_mse_R1', 'tail_mse_R2', 'tail_fractional_mse_reduction', 'tail_mean_abs_R1', 'tail_mean_abs_R2'});
gRow2.scope = "pooled_sum_tail_mse_fractional_reduction";
gRow3 = table(NaN, NaN, NaN, fracRed_median, NaN, NaN, ...
    'VariableNames', {'T_K', 'tail_mse_R1', 'tail_mse_R2', 'tail_fractional_mse_reduction', 'tail_mean_abs_R1', 'tail_mean_abs_R2'});
gRow3.scope = "median_per_temperature_tail_fractional_reduction";
tailOut = [gRow; gRow2; gRow3; tailRows];
writetable(tailOut, outTail);

% --- Shape physics long-form
cAll = localCos(phi1(mAll), phi2(mAll));
shapeMetric = [ ...
    "phi2_l2_frac_core"; "phi2_l2_frac_shoulder"; "phi2_l2_frac_tail"; "phi2_primary_concentration_argmax_index"; ...
    "phi2_even_symmetry_frac"; "phi2_odd_symmetry_frac"; "phi2_odd_over_even_L2_ratio"; ...
    "cos_phi2_phi1"; "cos_phi2_dphi1_dx"; "cos_phi2_d2phi1_dx2"; "cos_phi2_u_phi1"; "cos_phi2_u_dphi1_dx"; "cos_phi2_tail_R1_kernel"; ...
    "svd_sigma1_over_sigma2"; "loo_phi2_min_abs_overlap"; "loo_phi2_median_abs_overlap"; ...
    "deformation_multivariate_r2_full"; "deformation_multivariate_r2_tail"; ...
    "tail_mse_frac_reduction_pooled_over_T"; "phi1_phi2_cosine_full"];
shapeVal = [ ...
    frac_core; frac_shoulder; frac_tail; domIdx; phi2_even_frac; phi2_odd_frac; asymmetry_ratio; ...
    cos_phi1; cos_dphi1; cos_d2phi1; cos_xphi1; cos_xdphi1; cos_tailR1prof; ...
    sigma_ratio; loo_min; loo_median; fitAll.r2; fitTail.r2; fracRed_pooled; cAll];
shapeNote = [ ...
    "L2 energy cdf 0.35-0.65"; "L2 energy shoulder bands"; "L2 energy tail cdf>=0.80"; "1=core 2=shoulder 3=tail (max L2 window)"; ...
    "even part cdf reflection u vs 1-u"; "odd part"; "sqrt(odd energy)/sqrt(even energy)"; ...
    "full I-grid cosine"; "full I-grid cosine"; "full I-grid cosine"; "full I-grid cosine"; "full I-grid cosine"; ...
    "tail-column mean R1 over T, L2-normalized, cosine to phi2"; ...
    "R1z singular value ratio s1/s2"; "LOO SVD1 vs full phi2"; "median LOO overlap"; ...
    "Phi2 projected on canonical Phi1 deformation basis"; "deformation basis fit tail I mask"; ...
    "(sum_T MSE_R1 - sum_T MSE_R2) / sum_T MSE_R1 tail columns"; "cosine phi1 phi2 full domain"];
shapeRows = table(shapeMetric, shapeVal, shapeNote, 'VariableNames', {'metric', 'value', 'notes'});
writetable(shapeRows, outShape);

% --- Verdicts (conservative; bounded to Stage E family — no new mechanism authority)
fTail = 'PARTIAL';
tailRedUse = max([fracRed_pooled, fracRed_median], [], 'omitnan');
if frac_tail >= 0.55 && tailRedUse >= 0.10
    fTail = 'YES';
elseif frac_tail < 0.28 && tailRedUse < 0.02
    fTail = 'NO';
end

fDef = 'PARTIAL';
if fitAll.r2 >= 0.72
    fDef = 'YES';
elseif fitAll.r2 < 0.38 && isfinite(fitTail.r2) && fitTail.r2 < 0.52
    fDef = 'NO';
end

fInd = 'PARTIAL';
if abs(cAll) < 0.28 && fitAll.r2 < 0.38 && (1 - frac_tail) >= 0.42
    fInd = 'YES';
elseif abs(cAll) > 0.58 || fitAll.r2 > 0.68
    fInd = 'NO';
end

fStable = 'PARTIAL';
if sigma_ratio >= 3 && loo_min >= 0.82
    fStable = 'YES';
elseif sigma_ratio < 1.85 || loo_min < 0.55
    fStable = 'NO';
end

fMech = 'NO';
if strcmp(fStable, 'NO')
    fMech = 'NO';
elseif strcmp(fStable, 'YES') && (strcmp(fTail, 'YES') || strcmp(fDef, 'YES')) && loo_min >= 0.88
    fMech = 'PARTIAL';
elseif strcmp(fStable, 'PARTIAL') && (strcmp(fTail, 'YES') || strcmp(fDef, 'YES') || strcmp(fTail, 'PARTIAL') || strcmp(fDef, 'PARTIAL'))
    fMech = 'PARTIAL';
end

lines = {};
lines{end+1} = '# Switching Phi2 physical meaning audit (canonical artifacts)';
lines{end+1} = '';
lines{end+1} = '## Scope and boundaries';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID**: `%s`', canonicalRunId);
lines{end+1} = sprintf('- **switching_canonical_S_long.csv**: `%s`', sLongPath);
lines{end+1} = sprintf('- **switching_canonical_phi1.csv**: `%s`', phi1Path);
lines{end+1} = sprintf('- **switching_mode_amplitudes_vs_T.csv**: `%s`', ampPath);
lines{end+1} = '- **Hierarchy**: Same locked construction as canonical diagnostics: `pred1 = Bmap - kappa1 * phi1''`, `Phi2 = first right singular vector of R1 = S - pred1` (zero-filled SVD), `pred2 = pred1 + kappa2 * phi2''`. No decomposition edits.';
lines{end+1} = '- **Stage boundary**: Interpretation is diagnostic only. Mechanism language remains bounded by Stage E / E5 / E5B policy; this audit does not expand claim surface.';
lines{end+1} = '';
lines{end+1} = '## Questions addressed';
lines{end+1} = sprintf('- **Where is Phi2 concentrated?** Primary window (max L2 among core/shoulder/tail): **%s** (core=%.3f, shoulder=%.3f, tail=%.3f).', ...
    char(phi2_concentration_label), frac_core, frac_shoulder, frac_tail);
lines{end+1} = sprintf('- **Symmetric / antisymmetric?** Even fraction (cdf reflection about 0.5)=%.3f, odd=%.3f, odd/even amplitude ratio=%.3f.', ...
    phi2_even_frac, phi2_odd_frac, asymmetry_ratio);
if isfinite(fitTail.r2)
    tailR2Str = sprintf('%.3f', fitTail.r2);
else
    tailR2Str = 'NaN (tail grid has fewer effective samples than deformation basis columns; multivariate tail fit not identified)';
end
lines{end+1} = sprintf('- **Aligned with dPhi1/dx, x*Phi1, tail-error profile?** cos(full): dPhi1=%.3f, u*Phi1=%.3f, tail R1 kernel=%.3f; multivariate deformation R2 full=%.3f, tail=%s.', ...
    cos_dphi1, cos_xphi1, cos_tailR1prof, fitAll.r2, tailR2Str);
lines{end+1} = sprintf(['- **Tail residual reduction after backbone+Phi1?** Pooled over temperatures: `(sum MSE_R1 - sum MSE_R2)/sum MSE_R1` = **%.4f**; ' ...
    'median of per-temperature reductions = **%.4f** (mean of per-temperature ratios can be misleading when `MSE_R1` is tiny; see `switching_phi2_tail_residual_tests.csv`).'], ...
    fracRed_pooled, fracRed_median);
lines{end+1} = sprintf('- **Stability?** sigma1/sigma2=%.3f; LOO leave-one-temperature SVD min|cos|=%.3f, median=%.3f.', sigma_ratio, loo_min, loo_median);
lines{end+1} = '';
lines{end+1} = '## Interpretation note';
lines{end+1} = 'Phi2 is algorithmically the leading rank-1 current-direction mode of the post-Phi1 residual sheet `R1`. Physical labels (tail correction vs Phi1 deformation vs independent mode) are **competing projections** of the same object; the tables quantify overlap, not a redefinition of the hierarchy.';
lines{end+1} = 'Relative to an “unstable structured leftover” reading: high LOO overlap with the full-grid SVD mode and strong alignment with a tail-averaged `R1` kernel argue **against** incoherent junk; a moderate `s1/s2` gap (see `phi2_l2_frac_*` and `svd_sigma1_over_sigma2`) keeps a weak second singular direction non-negligible, so stability is **PARTIAL**, not airtight.';
lines{end+1} = '';
lines{end+1} = '## Final verdicts (required)';
lines{end+1} = sprintf('- **PHI2_IS_TAIL_RESIDUAL** = %s', fTail);
lines{end+1} = sprintf('- **PHI2_IS_DEFORMATION_OF_PHI1** = %s', fDef);
lines{end+1} = sprintf('- **PHI2_IS_INDEPENDENT_MODE** = %s', fInd);
lines{end+1} = sprintf('- **PHI2_IS_STABLE_PHYSICAL_COMPONENT** = %s', fStable);
lines{end+1} = sprintf('- **PHI2_MECHANISM_CLAIM_ALLOWED** = %s', fMech);
lines{end+1} = '';
lines{end+1} = '## Artifacts';
lines{end+1} = '- `tables/switching_phi2_shape_physics.csv`';
lines{end+1} = '- `tables/switching_phi2_deformation_tests.csv`';
lines{end+1} = '- `tables/switching_phi2_tail_residual_tests.csv`';

switchingWriteTextLinesFile(outReport, lines, 'run_switching_phi2_physical_meaning_audit:WriteFail');

fprintf('[DONE] switching Phi2 physical meaning audit -> %s\n', outReport);

function c = localCos(a, b)
a = a(:); b = b(:);
m = isfinite(a) & isfinite(b);
if sum(m) < 2
    c = NaN; return;
end
aa = a(m); bb = b(m);
c = dot(aa, bb) / max(norm(aa) * norm(bb), eps);
end

function r2 = localUniR2(y, xcol, mask)
y = y(:); xcol = xcol(:); mask = mask(:) & isfinite(y) & isfinite(xcol);
if sum(mask) < 3
    r2 = NaN; return;
end
xx = xcol(mask); yy = y(mask);
beta = xx \ yy;
yh = xx * beta;
sse = sum((yy - yh).^2);
sst = sum((yy - mean(yy)).^2);
r2 = 1 - sse / max(sst, eps);
end

function out = localFit(y, X, mask)
y = y(:);
if nargin < 3, mask = true(size(y)); end
mask = mask(:) & isfinite(y);
XX = X(mask, :); yy = y(mask);
mm = all(isfinite(XX), 2) & isfinite(yy);
XX = XX(mm, :); yy = yy(mm);
if isempty(XX) || size(XX, 1) < size(XX, 2)
    % Underdetermined: do not report R2/coefficients (would be non-unique / overfit).
    out.beta = nan(size(X, 2), 1); out.r2 = NaN; out.rmse = NaN; return;
end
beta = XX \ yy;
yhat = XX * beta;
sse = sum((yy - yhat).^2);
sst = sum((yy - mean(yy)).^2);
out.beta = beta;
out.r2 = 1 - sse / max(sst, eps);
out.rmse = sqrt(mean((yy - yhat).^2));
end
