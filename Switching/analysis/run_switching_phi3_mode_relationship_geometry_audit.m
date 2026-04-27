clear; clc;

% Canonical Phi3 mode-relationship geometry audit.
% Scope guards:
% - Switching only
% - Uses certified canonical evidence gate
% - No decomposition redefinition
% - No producer modification
% - Excludes failed Phi2 replacement audit evidence

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outGeom = fullfile(repoRoot, 'tables', 'switching_phi3_mode_relationship_geometry.csv');
outFits = fullfile(repoRoot, 'tables', 'switching_phi3_projection_family_fits.csv');
outRes = fullfile(repoRoot, 'tables', 'switching_phi3_projection_residuals.csv');
outReport = fullfile(repoRoot, 'reports', 'switching_phi3_mode_relationship_geometry.md');

% -------------------------- Evidence gate ---------------------------
gateStatusPath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification_status.csv');
gateCertPath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification.csv');
if exist(gateStatusPath, 'file') ~= 2 || exist(gateCertPath, 'file') ~= 2
    error('run_switching_phi3_mode_relationship_geometry_audit:MissingCertification', ...
        'Missing required certification files.');
end

gateStatus = readtable(gateStatusPath, 'TextType', 'string');
reqChecks = { ...
    'MODE_EVIDENCE_CERTIFICATION_COMPLETE', ...
    'FAILED_PHI2_REPLACEMENT_EXCLUDED', ...
    'CRITICAL_MODE_AUDITS_CERTIFIED', ...
    'CANONICAL_ONLY_NEXT_AUDIT_EVIDENCE_AVAILABLE', ...
    'SAFE_TO_RUN_PHI3_RELATIONSHIP_AUDITS'};
for i = 1:numel(reqChecks)
    idx = find(strcmpi(strtrim(string(gateStatus.check)), reqChecks{i}), 1);
    if isempty(idx) || upper(strtrim(string(gateStatus.result(idx)))) ~= "YES"
        error('run_switching_phi3_mode_relationship_geometry_audit:EvidenceGate', ...
            'Evidence gate failed at %s.', reqChecks{i});
    end
end

gateCert = readtable(gateCertPath, 'TextType', 'string');
if any(strcmpi(strtrim(gateCert.audit_name), "Failed artifact (exclude)"))
    error('run_switching_phi3_mode_relationship_geometry_audit:BadCertificationShape', ...
        'Unexpected failed artifact rows in certification table.');
end
if any(upper(strtrim(gateCert.evidence_allowed_for_next_audit)) ~= "YES")
    error('run_switching_phi3_mode_relationship_geometry_audit:CertificationNotAllowed', ...
        'Certification table contains non-allowed evidence rows.');
end
if any(upper(strtrim(gateCert.uses_failed_phi2_replacement_audit)) == "YES")
    error('run_switching_phi3_mode_relationship_geometry_audit:FailedPhi2Dependency', ...
        'Certification contains dependency on failed Phi2 replacement audit.');
end

% ----------------------- Canonical lock + load -----------------------
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
if exist(idPath, 'file') ~= 2 || exist(ampPath, 'file') ~= 2
    error('run_switching_phi3_mode_relationship_geometry_audit:MissingIdentityOrAmp', ...
        'Missing switching canonical identity or amplitudes table.');
end

idRaw = readcell(idPath, 'Delimiter', ',');
canonicalRunId = "";
for r = 2:size(idRaw, 1)
    key = strtrim(string(idRaw{r, 1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        canonicalRunId = strtrim(string(idRaw{r, 2}));
        break;
    end
end
if strlength(canonicalRunId) == 0
    error('run_switching_phi3_mode_relationship_geometry_audit:EmptyCanonicalRunId', ...
        'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
end

runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
sLongPath = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
phi1Path = fullfile(runRoot, 'tables', 'switching_canonical_phi1.csv');
if exist(runRoot, 'dir') ~= 7 || exist(sLongPath, 'file') ~= 2 || exist(phi1Path, 'file') ~= 2
    error('run_switching_phi3_mode_relationship_geometry_audit:MissingCanonicalArtifacts', ...
        'Identity-locked canonical run artifacts are missing.');
end

execPath = fullfile(runRoot, 'execution_status.csv');
if exist(execPath, 'file') == 2
    ex = readtable(execPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    vn = string(ex.Properties.VariableNames);
    if any(vn == "EXECUTION_STATUS")
        if upper(strtrim(ex.EXECUTION_STATUS(1))) ~= "SUCCESS"
            error('run_switching_phi3_mode_relationship_geometry_audit:CanonicalExecNotSuccess', ...
                'Canonical run execution status is not SUCCESS.');
        end
    elseif any(vn == "WRITE_SUCCESS")
        if upper(strtrim(ex.WRITE_SUCCESS(1))) ~= "YES"
            error('run_switching_phi3_mode_relationship_geometry_audit:CanonicalWriteFail', ...
                'Canonical run WRITE_SUCCESS is not YES.');
        end
    end
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);

% --------------------- Locked canonical hierarchy --------------------
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
dx = max(median(diff(allI), 'omitnan'), eps);

phiVars = string(phi1Tbl.Properties.VariableNames);
iPhi1 = find(strcmpi(phiVars, "phi1") | strcmpi(phiVars, "Phi1"), 1);
if isempty(iPhi1)
    error('run_switching_phi3_mode_relationship_geometry_audit:Phi1Missing', 'Phi1 column not found.');
end
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi1}), allI, 'linear', 'extrap');
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
if isempty(V1), phi2 = zeros(nI, 1); else, phi2 = V1(:, 1); end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end

pred2 = pred1 + kappa2(:) * phi2(:)';
R2 = Smap - pred2;
R2z = R2; R2z(~isfinite(R2z)) = 0;
[~, ~, V2] = svd(R2z, 'econ');
if isempty(V2), phi3 = zeros(nI, 1); else, phi3 = V2(:, 1); end
if norm(phi3) > 0, phi3 = phi3 / norm(phi3); end

% ---------------------------- Kernels -------------------------------
tailMask = cdfAxis >= 0.80;
coreMask = cdfAxis >= 0.35 & cdfAxis <= 0.65;
shoulderMask = (cdfAxis > 0.20 & cdfAxis < 0.35) | (cdfAxis > 0.65 & cdfAxis < 0.80);

dphi1 = gradient(phi1, dx);
d2phi1 = gradient(dphi1, dx);
dphi2 = gradient(phi2, dx);
d2phi2 = gradient(dphi2, dx);

tailPhi1 = zeros(nI, 1); tailPhi1(tailMask) = phi1(tailMask);
tailPhi2 = zeros(nI, 1); tailPhi2(tailMask) = phi2(tailMask);

r2MeanFull = mean(R2, 1, 'omitnan')';
transBand = allT >= 28 & allT <= 32;
if any(transBand)
    r2MeanTrans = mean(R2(transBand, :), 1, 'omitnan')';
else
    r2MeanTrans = zeros(nI, 1);
end
mainBand = ~transBand;
if any(mainBand)
    r2MeanMain = mean(R2(mainBand, :), 1, 'omitnan')';
else
    r2MeanMain = zeros(nI, 1);
end
r2Tail = zeros(nI, 1); r2Tail(tailMask) = r2MeanFull(tailMask);
r2Shoulder = zeros(nI, 1); r2Shoulder(shoulderMask) = r2MeanFull(shoulderMask);
r2Core = zeros(nI, 1); r2Core(coreMask) = r2MeanFull(coreMask);

ker = struct('name', {}, 'family', {}, 'v', {});
ker(end+1) = struct('name', "phi1", 'family', "phi1_family", 'v', phi1);
ker(end+1) = struct('name', "dphi1_dI", 'family', "phi1_family", 'v', dphi1);
ker(end+1) = struct('name', "d2phi1_dI2", 'family', "phi1_family", 'v', d2phi1);
ker(end+1) = struct('name', "(cdf-0.5)*phi1", 'family', "phi1_family", 'v', x0 .* phi1);
ker(end+1) = struct('name', "(cdf-0.5)*dphi1_dI", 'family', "phi1_family", 'v', x0 .* dphi1);
ker(end+1) = struct('name', "tail_restricted_phi1", 'family', "phi1_family", 'v', tailPhi1);

ker(end+1) = struct('name', "phi2", 'family', "phi2_family", 'v', phi2);
ker(end+1) = struct('name', "dphi2_dI", 'family', "phi2_family", 'v', dphi2);
ker(end+1) = struct('name', "d2phi2_dI2", 'family', "phi2_family", 'v', d2phi2);
ker(end+1) = struct('name', "(cdf-0.5)*phi2", 'family', "phi2_family", 'v', x0 .* phi2);
ker(end+1) = struct('name', "(cdf-0.5)*dphi2_dI", 'family', "phi2_family", 'v', x0 .* dphi2);
ker(end+1) = struct('name', "tail_restricted_phi2", 'family', "phi2_family", 'v', tailPhi2);

ker(end+1) = struct('name', "mean_R2_full", 'family', "residual_family", 'v', r2MeanFull);
ker(end+1) = struct('name', "mean_R2_transition_28_32K", 'family', "residual_family", 'v', r2MeanTrans);
ker(end+1) = struct('name', "mean_R2_main_excl_28_32K", 'family', "residual_family", 'v', r2MeanMain);
ker(end+1) = struct('name', "R2_tail_kernel", 'family', "residual_family", 'v', r2Tail);
ker(end+1) = struct('name', "R2_shoulder_kernel", 'family', "residual_family", 'v', r2Shoulder);
ker(end+1) = struct('name', "R2_core_kernel", 'family', "residual_family", 'v', r2Core);

rowsGeom = table();
residualCols = table(allI(:), cdfAxis(:), phi3(:), 'VariableNames', {'current_mA', 'cdf_pt', 'phi3_unit'});
for i = 1:numel(ker)
    [ku, cosv, signed, frac, resNorm, resVec] = projectKernel(phi3, ker(i).v);
    rowsGeom = [rowsGeom; table(ker(i).name, ker(i).family, cosv, signed, frac, resNorm, ...
        'VariableNames', {'kernel_name','kernel_family','cosine_similarity','signed_alignment','cos2_explained_fraction','projection_residual_norm'})]; %#ok<AGROW>
    residualCols.(matlab.lang.makeValidName("res_" + ker(i).name)) = resVec;
end
writetable(rowsGeom, outGeom);

% -------------------------- Family fits -----------------------------
familyDefs = {
    "phi1_family_only", rowsGeom.kernel_name(rowsGeom.kernel_family=="phi1_family");
    "phi2_family_only", rowsGeom.kernel_name(rowsGeom.kernel_family=="phi2_family");
    "phi1_phi2_families", rowsGeom.kernel_name(rowsGeom.kernel_family=="phi1_family" | rowsGeom.kernel_family=="phi2_family");
    "residual_kernels_only", rowsGeom.kernel_name(rowsGeom.kernel_family=="residual_family");
    "transition_kernel_only", "mean_R2_transition_28_32K";
    "all_kernels_together", rowsGeom.kernel_name
    };

rowsFit = table();
for i = 1:size(familyDefs, 1)
    famName = string(familyDefs{i, 1});
    names = string(familyDefs{i, 2});
    X = [];
    usedNames = strings(0, 1);
    for j = 1:numel(names)
        idx = find(rowsGeom.kernel_name == names(j), 1);
        if isempty(idx), continue; end
        kv = ker(idx).v(:);
        kv(~isfinite(kv)) = 0;
        if norm(kv) <= eps, continue; end
        X = [X, kv]; %#ok<AGROW>
        usedNames(end+1, 1) = names(j); %#ok<AGROW>
    end
    [beta, r2, rmse, residualVec] = fitFamily(phi3, X);
    rowsFit = [rowsFit; table(famName, numel(usedNames), strjoin(usedNames, ';'), r2, rmse, norm(beta), ...
        'VariableNames', {'projection_family','n_kernels_used','kernel_names','fit_r2','fit_rmse','beta_l2_norm'})]; %#ok<AGROW>
    residualCols.(matlab.lang.makeValidName("res_family_" + famName)) = residualVec;
end
writetable(rowsFit, outFits);
writetable(residualCols, outRes);

% -------------------------- Classification --------------------------
bestPhi1 = max(rowsGeom.cos2_explained_fraction(rowsGeom.kernel_family=="phi1_family"), [], 'omitnan');
bestPhi2 = max(rowsGeom.cos2_explained_fraction(rowsGeom.kernel_family=="phi2_family"), [], 'omitnan');
bestResidual = max(rowsGeom.cos2_explained_fraction(rowsGeom.kernel_family=="residual_family"), [], 'omitnan');
transCos2 = rowsGeom.cos2_explained_fraction(rowsGeom.kernel_name=="mean_R2_transition_28_32K");
tailCos2 = rowsGeom.cos2_explained_fraction(rowsGeom.kernel_name=="R2_tail_kernel");
if isempty(transCos2), transCos2 = NaN; else, transCos2 = transCos2(1); end
if isempty(tailCos2), tailCos2 = NaN; else, tailCos2 = tailCos2(1); end

r2Phi1 = pickFamilyR2(rowsFit, "phi1_family_only");
r2Phi2 = pickFamilyR2(rowsFit, "phi2_family_only");
r2Low = pickFamilyR2(rowsFit, "phi1_phi2_families");
r2Res = pickFamilyR2(rowsFit, "residual_kernels_only");
r2Trans = pickFamilyR2(rowsFit, "transition_kernel_only");
r2All = pickFamilyR2(rowsFit, "all_kernels_together");

PHI3_RELATED_TO_PHI1_FAMILY = ternaryYNP(bestPhi1 >= 0.40 || r2Phi1 >= 0.40, bestPhi1 >= 0.20 || r2Phi1 >= 0.20);
PHI3_RELATED_TO_PHI2_FAMILY = ternaryYNP(bestPhi2 >= 0.40 || r2Phi2 >= 0.40, bestPhi2 >= 0.20 || r2Phi2 >= 0.20);
PHI3_IS_TRANSITION_KERNEL_LIKE = ternaryYNP(transCos2 >= 0.45 || r2Trans >= 0.45, transCos2 >= 0.25 || r2Trans >= 0.25);
PHI3_IS_TAIL_KERNEL_LIKE = ternaryYNP(tailCos2 >= 0.45, tailCos2 >= 0.25);
PHI3_IS_LOW_MODE_DEFORMATION = ternaryYNP(r2Low >= 0.55 && bestResidual < 0.35, r2Low >= 0.35);
PHI3_IS_INDEPENDENT_SHAPE = ternaryYNP((r2All < 0.35) || (bestResidual < 0.25 && bestPhi1 < 0.25 && bestPhi2 < 0.25), ...
                                       (r2All < 0.50) && (bestResidual < 0.35));

% Conservative policy: remain diagnostic unless strong low-mode deformation evidence dominates.
if PHI3_IS_LOW_MODE_DEFORMATION == "YES" && PHI3_IS_TRANSITION_KERNEL_LIKE == "NO" && PHI3_IS_INDEPENDENT_SHAPE == "NO"
    PHI3_SHOULD_REMAIN_DIAGNOSTIC = "PARTIAL";
else
    PHI3_SHOULD_REMAIN_DIAGNOSTIC = "YES";
end

% ---------------------------- Report -------------------------------
lines = {};
lines{end+1} = '# Switching canonical Phi3 mode-relationship geometry audit';
lines{end+1} = '';
lines{end+1} = '## Scope and gate';
lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
lines{end+1} = '- Evidence gate passed from switching_mode_evidence_certification status table.';
lines{end+1} = '- Decomposition preserved: backbone -> Phi1 -> Phi2 -> diagnostic Phi3 from R2.';
lines{end+1} = '- Failed Phi2 replacement audit not used.';
lines{end+1} = '';
lines{end+1} = '## Projection family fit summary';
for i = 1:height(rowsFit)
    lines{end+1} = sprintf('- `%s`: R2=%.4f, RMSE=%.4f, kernels=%d', rowsFit.projection_family(i), rowsFit.fit_r2(i), rowsFit.fit_rmse(i), rowsFit.n_kernels_used(i));
end
lines{end+1} = '';
lines{end+1} = '## Classification';
lines{end+1} = sprintf('- PHI3_RELATED_TO_PHI1_FAMILY = %s', PHI3_RELATED_TO_PHI1_FAMILY);
lines{end+1} = sprintf('- PHI3_RELATED_TO_PHI2_FAMILY = %s', PHI3_RELATED_TO_PHI2_FAMILY);
lines{end+1} = sprintf('- PHI3_IS_TRANSITION_KERNEL_LIKE = %s', PHI3_IS_TRANSITION_KERNEL_LIKE);
lines{end+1} = sprintf('- PHI3_IS_TAIL_KERNEL_LIKE = %s', PHI3_IS_TAIL_KERNEL_LIKE);
lines{end+1} = sprintf('- PHI3_IS_LOW_MODE_DEFORMATION = %s', PHI3_IS_LOW_MODE_DEFORMATION);
lines{end+1} = sprintf('- PHI3_IS_INDEPENDENT_SHAPE = %s', PHI3_IS_INDEPENDENT_SHAPE);
lines{end+1} = sprintf('- PHI3_SHOULD_REMAIN_DIAGNOSTIC = %s', PHI3_SHOULD_REMAIN_DIAGNOSTIC);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_phi3_mode_relationship_geometry.csv`';
lines{end+1} = '- `tables/switching_phi3_projection_family_fits.csv`';
lines{end+1} = '- `tables/switching_phi3_projection_residuals.csv`';

switchingWriteTextLinesFile(outReport, lines, 'run_switching_phi3_mode_relationship_geometry_audit:WriteFail');

fprintf('[DONE] switching Phi3 mode-relationship geometry audit -> %s\n', outReport);

function [ku, cosv, signed, frac, resNorm, resVec] = projectKernel(phi3, raw)
phi3 = phi3(:);
raw = raw(:);
m = isfinite(phi3) & isfinite(raw);
ku = zeros(size(raw));
if sum(m) < 3 || norm(raw(m)) <= eps
    cosv = NaN; signed = NaN; frac = NaN;
    resVec = phi3;
    resNorm = sqrt(sum(resVec.^2, 'omitnan'));
    return;
end
ku(m) = raw(m) / norm(raw(m));
cosv = dot(phi3(m), ku(m)) / max(norm(phi3(m)), eps);
signed = cosv;
frac = cosv.^2;
resVec = phi3 - dot(phi3, ku) * ku;
resNorm = sqrt(sum(resVec.^2, 'omitnan'));
end

function [beta, r2, rmse, residualVec] = fitFamily(y, X)
y = y(:);
residualVec = y;
if isempty(X)
    beta = zeros(0,1); r2 = NaN; rmse = NaN; return;
end
mask = isfinite(y) & all(isfinite(X), 2);
yy = y(mask);
XX = X(mask, :);
if size(XX,1) < 3
    beta = zeros(size(XX,2),1); r2 = NaN; rmse = NaN; return;
end
% Use least-norm solution so underdetermined kernel families are still evaluable.
beta = pinv(XX) * yy;
yhat = XX * beta;
sse = sum((yy - yhat).^2);
sst = sum((yy - mean(yy)).^2);
r2 = 1 - sse / max(sst, eps);
rmse = sqrt(mean((yy - yhat).^2));
residualVec(mask) = yy - yhat;
end

function v = pickFamilyR2(tbl, fam)
m = tbl.projection_family == string(fam);
if any(m)
    v = tbl.fit_r2(find(m, 1));
else
    v = NaN;
end
end

function out = ternaryYNP(condYes, condPartial)
if condYes
    out = "YES";
elseif condPartial
    out = "PARTIAL";
else
    out = "NO";
end
end
