% run_switching_phi2_deformation_geometry_audit
%
% Canonical Phi2 deformation-geometry audit (projection diagnostics only).
% Compares Phi2 to fixed interpretable deformation kernels on the current axis.
%
% Inputs (identity-anchored, same contract as run_switching_phi2_physical_meaning_audit):
%   tables/switching_canonical_identity.csv
%   switching_canonical_S_long.csv, switching_canonical_phi1.csv (identity-resolved)
%   tables/switching_mode_amplitudes_vs_T.csv
%
% Gates: canonical run directory must exist; execution_status.csv (if present) must
% indicate WRITE_SUCCESS=YES (successful canonical artifact generation).
%
% Outputs (repo root):
%   tables/switching_phi2_deformation_geometry.csv
%   tables/switching_phi2_projection_residuals.csv
%   reports/switching_phi2_deformation_geometry_audit.md
%
% Scope: no decomposition redefinition, no producer edits, no dependency on
% run_switching_phi2_replacement_audit.

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

outGeom = fullfile(repoRoot, 'tables', 'switching_phi2_deformation_geometry.csv');
outRes = fullfile(repoRoot, 'tables', 'switching_phi2_projection_residuals.csv');
outReport = fullfile(repoRoot, 'reports', 'switching_phi2_deformation_geometry_audit.md');

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

req = {idPath, sLongPath, phi1Path, ampPath};
reqLbl = {'switching_canonical_identity.csv', 'switching_canonical_S_long.csv', ...
    'switching_canonical_phi1.csv', 'switching_mode_amplitudes_vs_T.csv'};
for i = 1:numel(req)
    if exist(req{i}, 'file') ~= 2
        error('run_switching_phi2_deformation_geometry_audit:MissingInput', ...
            'Missing required input (%s): %s', reqLbl{i}, req{i});
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
    error('run_switching_phi2_deformation_geometry_audit:Identity', ...
        'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
end

runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
if exist(runRoot, 'dir') ~= 7
    error('run_switching_phi2_deformation_geometry_audit:RunRootMissing', ...
        'Canonical run directory missing: %s', runRoot);
end
expectedLong = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
if ~strcmpi(strrep(sLongPath, '\', '/'), strrep(expectedLong, '\', '/'))
    error('run_switching_phi2_deformation_geometry_audit:IdentityPathMismatch', ...
        ['Resolved S_long path does not match CANONICAL_RUN_ID anchor.\n' ...
        '  identity: %s\n  resolved: %s'], expectedLong, sLongPath);
end

statusPath = fullfile(runRoot, 'execution_status.csv');
if exist(statusPath, 'file') == 2
    st = readtable(statusPath, 'VariableNamingRule', 'preserve', 'TextType', 'string');
    vn = lower(string(st.Properties.VariableNames));
    iW = find(vn == "write_success", 1);
    if ~isempty(iW)
        val = upper(strtrim(string(st{1, iW})));
        if val ~= "YES"
            error('run_switching_phi2_deformation_geometry_audit:CanonicalNotSuccessful', ...
                'execution_status.csv WRITE_SUCCESS is not YES: %s', statusPath);
        end
    end
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);
if ~all(ismember({'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'CDF_pt'}, sLong.Properties.VariableNames))
    error('run_switching_phi2_deformation_geometry_audit:Schema', 'sLong missing required columns.');
end
if ~all(ismember({'T_K', 'kappa1', 'kappa2'}, ampTbl.Properties.VariableNames))
    error('run_switching_phi2_deformation_geometry_audit:Schema', 'Amplitude table missing kappa1/kappa2.');
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
x0 = cdfAxis - 0.5;

phiVars = string(phi1Tbl.Properties.VariableNames);
iPhi = find(strcmpi(phiVars, "phi1"), 1);
if isempty(iPhi)
    error('run_switching_phi2_deformation_geometry_audit:Phi1Col', 'No phi1 column in switching_canonical_phi1.csv.');
end
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

% Derivatives w.r.t. current (mA), same phi1 as in pred1.
dphi1_dI = gradient(phi1(:), allI(:));
d2phi1_dI2 = gradient(dphi1_dI(:), allI(:));

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');

pred1 = Bmap - kappa1(:) * phi1(:)';
R1 = Smap - pred1;
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if size(V1, 2) >= 1
    phi2 = V1(:, 1);
else
    phi2 = zeros(nI, 1);
end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end

tailI = cdfAxis >= 0.80;
if ~any(tailI)
    tailI = false(nI, 1); tailI(max(nI - 1, 1):nI) = true;
end
tailKernel = zeros(nI, 1);
for ii = 1:nI
    if tailI(ii)
        tailKernel(ii) = mean(R1(:, ii), 1, 'omitnan');
    end
end

kShift = dphi1_dI;
kCurv = d2phi1_dI2;
kSkewAmp = x0 .* phi1;
kSkewShift = x0 .* dphi1_dI;
kTail = tailKernel;

kernelIds = [ ...
    "dphi1_dI_shift_like"; ...
    "d2phi1_dI2_curvature_broadening_like"; ...
    "cdf_minus_half_times_phi1_skew_amp_gradient"; ...
    "cdf_minus_half_times_dphi1_dI_skewed_shift"; ...
    "high_cdf_tail_mean_R1_residual_kernel"];
kernels = {kShift; kCurv; kSkewAmp; kSkewShift; kTail};
kernelLabels = { ...
    'dPhi1/dI (shift-like)'; ...
    'd2Phi1/dI2 (curvature / broadening-like)'; ...
    '(CDF-0.5)*Phi1 (skew / amplitude-gradient)'; ...
    '(CDF-0.5)*dPhi1/dI (skewed-shift)'; ...
    'high-CDF tail mean R1 profile (tail lift/suppression diagnostic)'};

rows = table( ...
    'Size', [0 6], ...
    'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'kernel_id', 'kernel_description', 'cosine_similarity', ...
    'signed_alignment', 'fraction_phi2_variance_along_kernel', 'residual_l2_norm'});

residualBlock = table(allI(:), cdfAxis(:), phi1(:), phi2(:), ...
    'VariableNames', {'current_mA', 'cdf_pt', 'phi1_unit', 'phi2_unit'});

for k = 1:numel(kernels)
    raw = kernels{k};
    raw = raw(:);
    m = isfinite(raw) & isfinite(phi2);
    nk = norm(raw(m));
    if nk <= 0 || sum(m) < 3
        ku = nan(nI, 1);
        cosSim = NaN;
        signedAlign = NaN;
        fracExpl = NaN;
        res = phi2;
    else
        ku = raw / nk;
        cosSim = dot(phi2(m), ku(m)) / max(norm(phi2(m)), eps);
        signedAlign = cosSim;
        fracExpl = cosSim^2;
        res = phi2 - (dot(phi2, ku)) * ku;
    end
    colName = matlab.lang.makeValidName(char(kernelIds(k)));
    residualBlock.(colName) = res;
    noteResidualL2 = sqrt(sum(res.^2, 'omitnan'));
    rows = [rows; table( ...
        kernelIds(k), string(kernelLabels{k}), cosSim, signedAlign, fracExpl, noteResidualL2, ...
        'VariableNames', {'kernel_id', 'kernel_description', 'cosine_similarity', ...
        'signed_alignment', 'fraction_phi2_variance_along_kernel', 'residual_l2_norm'})]; %#ok<AGROW>
end

writetable(rows, outGeom);

writetable(residualBlock, outRes);

% --- Group scores for classification (use squared cosines).
ixShift = 1; ixCurv = 2; ixSkewAmp = 3; ixSkewSh = 4; ixTail = 5;
f2 = rows.fraction_phi2_variance_along_kernel;
skewScore = max(f2(ixSkewAmp), f2(ixSkewSh));
scores = struct( ...
    'shift', f2(ixShift), ...
    'broadening', f2(ixCurv), ...
    'skew', skewScore, ...
    'tail', f2(ixTail));
nameOrder = {'shift', 'broadening', 'skew', 'tail'};
vals = [scores.shift, scores.broadening, scores.skew, scores.tail];
[mx, jx] = max(vals);
second = max(vals(setdiff(1:4, jx)));
ratio = mx / max(second, eps);
sortedScores = sort(vals, 'descend');

if ~isfinite(mx) || mx < 0.08
    domType = 'mixed';
elseif ratio < 1.35 && mx < 0.42
    domType = 'mixed';
elseif numel(sortedScores) >= 2 && sortedScores(2) > 0.50 && (sortedScores(1) - sortedScores(2)) <= 0.02
    % Near-tie among strong modes (e.g. tail R1 kernel vs d2Phi1/dI2).
    domType = 'mixed';
else
    domType = nameOrder{jx};
end

ynp = @(x) iif(x >= 0.40, 'YES', x <= 0.10, 'NO', 'PARTIAL');
PHI2_IS_SHIFT_LIKE = ynp(f2(ixShift));
PHI2_IS_CURVATURE_LIKE = ynp(f2(ixCurv));
PHI2_IS_SKEW_LIKE = ynp(skewScore);
PHI2_IS_TAIL_LIFT_OR_SUPPRESSION = ynp(f2(ixTail));

PHI2_DOMINANT_DEFORMATION_TYPE = domType;
if strcmp(domType, 'shift')
    PHI2_DOMINANT_DEFORMATION_TYPE = 'shift';
elseif strcmp(domType, 'broadening')
    PHI2_DOMINANT_DEFORMATION_TYPE = 'broadening';
elseif strcmp(domType, 'skew')
    PHI2_DOMINANT_DEFORMATION_TYPE = 'skew';
elseif strcmp(domType, 'tail')
    PHI2_DOMINANT_DEFORMATION_TYPE = 'tail';
else
    PHI2_DOMINANT_DEFORMATION_TYPE = 'mixed';
end

readyScores = sum(strcmp({PHI2_IS_SHIFT_LIKE, PHI2_IS_CURVATURE_LIKE, PHI2_IS_SKEW_LIKE, PHI2_IS_TAIL_LIFT_OR_SUPPRESSION}, 'NO'));
if readyScores >= 3 && mx < 0.15
    PHI2_GEOMETRY_INTERPRETATION_READY = 'NO';
elseif mx >= 0.35 && ratio >= 1.25
    PHI2_GEOMETRY_INTERPRETATION_READY = 'YES';
else
    PHI2_GEOMETRY_INTERPRETATION_READY = 'PARTIAL';
end

% --- Current-axis sign / tail narrative
lowI = cdfAxis <= 0.20 & isfinite(cdfAxis);
hiI = cdfAxis >= 0.80;
midI = ~lowI & ~hiI & isfinite(cdfAxis);
meanLow = mean(phi2(lowI), 'omitnan');
meanMid = mean(phi2(midI), 'omitnan');
meanHi = mean(phi2(hiI), 'omitnan');
wpos = sum(phi2 > 0 & isfinite(phi2)); wneg = sum(phi2 < 0 & isfinite(phi2));
fracPos = wpos / max(wpos + wneg, 1);

tailMeanPhi1 = mean(phi1(hiI), 'omitnan');
tailMeanPhi2 = mean(phi2(hiI), 'omitnan');
coreI = cdfAxis >= 0.35 & cdfAxis <= 0.65;
coreMeanPhi2 = mean(phi2(coreI), 'omitnan');

% Signed alignment shift: positive => Phi2 aligns with +dPhi1/dI direction.
ixS = find(strcmp(char(rows.kernel_id), char(kernelIds(1))), 1);
if isempty(ixS), shiftSign = NaN; else, shiftSign = rows.signed_alignment(ixS); end

if tailMeanPhi2 * tailMeanPhi1 > 0
    tailVsPhi1 = 'Phi2 is on average the same sign as Phi1 in the high-CDF tail, so the second mode tends to reinforce the local Phi1 correction direction there (amplitude stacks rather than opposes).';
else
    tailVsPhi1 = 'Phi2 is on average opposite in sign to Phi1 in the high-CDF tail, so the second mode opposes the local Phi1 correction direction there (net tail correction can be damped or reversed vs Phi1-only).';
end

if isfinite(shiftSign) && shiftSign > 0.15
    shiftInterp = 'Positive alignment with dPhi1/dI: Phi2 resembles a deformation shifted toward higher current where dPhi1/dI is positive (and the reverse where dPhi1/dI is negative).';
elseif isfinite(shiftSign) && shiftSign < -0.15
    shiftInterp = 'Negative alignment with dPhi1/dI: Phi2 resembles a deformation shifted toward lower current versus the +dPhi1/dI orientation.';
else
    shiftInterp = 'Weak alignment with dPhi1/dI: no clean shift-like current direction from this kernel alone.';
end

lines = {};
lines{end+1} = '# Switching Phi2 deformation–geometry audit (canonical)';
lines{end+1} = '';
lines{end+1} = '## Scope';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID**: `%s`', canonicalRunId);
lines{end+1} = sprintf('- **switching_canonical_S_long.csv**: `%s`', sLongPath);
lines{end+1} = sprintf('- **switching_canonical_phi1.csv**: `%s`', phi1Path);
lines{end+1} = '- **Phi2 construction**: first right singular vector of `R1 = S - (B - kappa1*phi1'')`, L2-normalized on the current grid (unchanged canonical hierarchy).';
lines{end+1} = '- **Kernels**: built from the same unit-norm `Phi1(I)` used in `pred1`; derivatives use `gradient(phi1, allI)` on the canonical current grid.';
lines{end+1} = '';
lines{end+1} = '## Kernel metrics';
lines{end+1} = '| kernel_id | cos | signed | frac explained | residual L2 |';
lines{end+1} = '|---|---:|---:|---:|---:|';
for r = 1:height(rows)
    lines{end+1} = sprintf('| %s | %.4f | %.4f | %.4f | %.4f |', ...
        char(rows.kernel_id(r)), rows.cosine_similarity(r), rows.signed_alignment(r), ...
        rows.fraction_phi2_variance_along_kernel(r), rows.residual_l2_norm(r));
end
lines{end+1} = '';
lines{end+1} = '**Notes**: `fraction_phi2_variance_along_kernel` is cos² between unit `Phi2` and the L2-unit kernel (single-direction variance captured). `residual_l2_norm` is `||Phi2 - (Phi2''*k) k||` with unit `k`.';
lines{end+1} = '';
lines{end+1} = '## Dominant deformation (cos² scores)';
lines{end+1} = sprintf('- shift (dPhi1/dI): **%.4f**', scores.shift);
lines{end+1} = sprintf('- broadening/curvature (d2Phi1/dI2): **%.4f**', scores.broadening);
lines{end+1} = sprintf('- skew family (max of (CDF-0.5)*Phi1 and (CDF-0.5)*dPhi1/dI): **%.4f**', scores.skew);
lines{end+1} = sprintf('- tail mean R1 kernel: **%.4f**', scores.tail);
lines{end+1} = sprintf(['- classification rule: largest cos² among four groups; **mixed** if max<0.08, or (max<0.42 and max/second<1.35), ' ...
    'or (second>0.50 and top-two cos² differ by ≤0.02).']);
lines{end+1} = '';
lines{end+1} = '## Current-axis interpretation';
lines{end+1} = sprintf('- **Sign on grid**: positive fraction ≈ **%.2f** (count-based on finite samples).', fracPos);
lines{end+1} = sprintf('- **Means by CDF band**: low (CDF≤0.20) mean(Phi2)=%.4f; mid mean=%.4f; high-tail (CDF≥0.80) mean=%.4f.', meanLow, meanMid, meanHi);
lines{end+1} = sprintf('- **Tail vs Phi1**: %s', tailVsPhi1);
lines{end+1} = sprintf('- **Shift direction (kernel 1)**: %s', shiftInterp);
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- **PHI2_DOMINANT_DEFORMATION_TYPE** = %s', PHI2_DOMINANT_DEFORMATION_TYPE);
lines{end+1} = sprintf('- **PHI2_IS_SHIFT_LIKE** = %s', PHI2_IS_SHIFT_LIKE);
lines{end+1} = sprintf('- **PHI2_IS_CURVATURE_LIKE** = %s', PHI2_IS_CURVATURE_LIKE);
lines{end+1} = sprintf('- **PHI2_IS_SKEW_LIKE** = %s', PHI2_IS_SKEW_LIKE);
lines{end+1} = sprintf('- **PHI2_IS_TAIL_LIFT_OR_SUPPRESSION** = %s', PHI2_IS_TAIL_LIFT_OR_SUPPRESSION);
lines{end+1} = sprintf('- **PHI2_GEOMETRY_INTERPRETATION_READY** = %s', PHI2_GEOMETRY_INTERPRETATION_READY);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_phi2_deformation_geometry.csv`';
lines{end+1} = '- `tables/switching_phi2_projection_residuals.csv`';
lines{end+1} = '';

switchingWriteTextLinesFile(outReport, lines, 'run_switching_phi2_deformation_geometry_audit:WriteFail');

fprintf('[DONE] switching Phi2 deformation geometry audit -> %s\n', outReport);

function out = iif(cond, a, cond2, b, c)
if cond
    out = a;
elseif cond2
    out = b;
else
    out = c;
end
end
