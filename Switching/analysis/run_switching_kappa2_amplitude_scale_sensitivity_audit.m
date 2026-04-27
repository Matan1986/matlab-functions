clear; clc;

% Canonical kappa2 amplitude-scale sensitivity audit (Switching only).
% Tests whether kappa2 interpretation survives explicit scale controls.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outSens = fullfile(repoRoot, 'tables', 'switching_kappa2_amplitude_scale_sensitivity.csv');
outPart = fullfile(repoRoot, 'tables', 'switching_kappa2_scale_partial_correlations.csv');
outModels = fullfile(repoRoot, 'tables', 'switching_kappa2_scale_control_models.csv');
outStatus = fullfile(repoRoot, 'tables', 'switching_kappa2_scale_sensitivity_status.csv');
outRep = fullfile(repoRoot, 'reports', 'switching_kappa2_amplitude_scale_sensitivity.md');

% ------------------------ Evidence gate ------------------------
gatePath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification_status.csv');
if exist(gatePath, 'file') ~= 2
    error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingGate', ...
        'Missing switching_mode_evidence_certification_status.csv.');
end
g = readtable(gatePath, 'TextType', 'string');
checks = { ...
    'MODE_EVIDENCE_CERTIFICATION_COMPLETE', ...
    'FAILED_PHI2_REPLACEMENT_EXCLUDED', ...
    'CRITICAL_MODE_AUDITS_CERTIFIED', ...
    'CANONICAL_ONLY_NEXT_AUDIT_EVIDENCE_AVAILABLE' ...
    };
for i = 1:numel(checks)
    ix = find(strcmpi(strtrim(g.check), checks{i}), 1);
    if isempty(ix) || upper(strtrim(g.result(ix))) ~= "YES"
        error('run_switching_kappa2_amplitude_scale_sensitivity_audit:GateFailed', ...
            'Evidence gate failed at %s.', checks{i});
    end
end

reqPrior = { ...
    fullfile(repoRoot, 'tables', 'switching_phi2_deformation_geometry.csv'), ...
    fullfile(repoRoot, 'tables', 'switching_kappa2_observable_correlation_matrix.csv'), ...
    fullfile(repoRoot, 'tables', 'switching_kappa2_partial_correlations.csv') ...
    };
for i = 1:numel(reqPrior)
    if exist(reqPrior{i}, 'file') ~= 2
        error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingPriorAudit', ...
            'Missing required certified audit output: %s', reqPrior{i});
    end
end

% --------------------- Canonical lock + inputs ---------------------
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
if exist(idPath, 'file') ~= 2 || exist(ampPath, 'file') ~= 2
    error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingIdentityAmp', ...
        'Missing canonical identity or amplitudes table.');
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
    error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingRunId', ...
        'CANONICAL_RUN_ID missing.');
end

runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
sLongPath = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
phi1Path = fullfile(runRoot, 'tables', 'switching_canonical_phi1.csv');
obsPath = fullfile(runRoot, 'tables', 'switching_canonical_observables.csv');
if exist(sLongPath, 'file') ~= 2 || exist(phi1Path, 'file') ~= 2 || exist(obsPath, 'file') ~= 2
    error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingCanonicalInputs', ...
        'Missing canonical S_long, phi1, or observables table.');
end

statusPath = fullfile(runRoot, 'execution_status.csv');
if exist(statusPath, 'file') ~= 2
    error('run_switching_kappa2_amplitude_scale_sensitivity_audit:MissingExecStatus', ...
        'Missing execution_status.csv for canonical run.');
end
st = readtable(statusPath, 'VariableNamingRule', 'preserve', 'TextType', 'string');
vns = lower(string(st.Properties.VariableNames));
iW = find(vns == "write_success", 1);
if ~isempty(iW)
    if upper(strtrim(string(st{1, iW}))) ~= "YES"
        error('run_switching_kappa2_amplitude_scale_sensitivity_audit:CanonicalNotSuccessful', ...
            'Canonical execution_status WRITE_SUCCESS is not YES.');
    end
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);
obsTbl = readtable(obsPath);

% --------------------- Locked hierarchy + features ---------------------
T = double(sLong.T_K);
I = double(sLong.current_mA);
S = double(sLong.S_percent);
B = double(sLong.S_model_pt_percent);
C = double(sLong.CDF_pt);
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

phiVars = string(phi1Tbl.Properties.VariableNames);
iPhi1 = find(strcmpi(phiVars, "phi1") | strcmpi(phiVars, "Phi1"), 1);
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi1}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

pred1 = Bmap - kappa1(:) * phi1(:)';
R1 = Smap - pred1;
R1z = R1;
R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if isempty(V1)
    phi2 = zeros(nI, 1);
else
    phi2 = V1(:, 1);
end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end

% Phi2/kappa2 locked hierarchy: R2 after adding kappa2*phi2 from R1.
pred2 = pred1 + kappa2(:) * phi2(:)';
R2 = Smap - pred2;

S_peak = max(Smap, [], 2, 'omitnan');
S_peak_z = (S_peak - mean(S_peak, 'omitnan')) / max(std(S_peak, 'omitnan'), eps);
medS = median(S_peak, 'omitnan');
madS = median(abs(S_peak - medS), 'omitnan');
S_peak_robust_z = (S_peak - medS) / max(1.4826 * madS, eps);

total_S_row_norm = sqrt(sum(Smap.^2, 2, 'omitnan'));
pt_backbone_row_norm = sqrt(sum(Bmap.^2, 2, 'omitnan'));
R1_row_norm = sqrt(sum(R1.^2, 2, 'omitnan'));
R1_over_S_energy_ratio = (R1_row_norm.^2) ./ max(total_S_row_norm.^2, eps);

cdfAxis = mean(Cmap, 1, 'omitnan');
if any(~isfinite(cdfAxis))
    cdfAxis = fillmissing(cdfAxis, 'linear', 'EndValues', 'nearest');
end
midMaskI = cdfAxis > 0.40 & cdfAxis < 0.60;
tailMaskI = cdfAxis >= 0.80;
R0 = Smap - Bmap;
tail_burden_ratio = mean(R0(:, tailMaskI) .^ 2, 2, 'omitnan') ./ max(mean(R0(:, midMaskI) .^ 2, 2, 'omitnan'), eps);

high_CDF_tail_weight = NaN(nT, 1);
symmetry_cdf_mirror = NaN(nT, 1);
for it = 1:nT
    y = Smap(it, :);
    xI = allI(:)';
    xC = Cmap(it, :);
    m = isfinite(y) & isfinite(xI) & isfinite(xC);
    y = y(m); xI = xI(m); xC = xC(m);
    if numel(y) < 4
        continue;
    end
    [xI, ord] = sort(xI, 'ascend');
    y = y(ord); xC = xC(ord);
    cGrid = linspace(0.1, 0.9, 9);
    symVals = NaN(size(cGrid));
    for ic = 1:numel(cGrid)
        c1 = cGrid(ic);
        c2 = 1 - c1;
        [d1, i1] = min(abs(xC - c1));
        [d2, i2] = min(abs(xC - c2));
        if isfinite(d1) && isfinite(d2) && d1 < 0.15 && d2 < 0.15
            symVals(ic) = y(i2) - y(i1);
        end
    end
    symmetry_cdf_mirror(it) = mean(abs(symVals), 'omitnan');
    hiMask = xC >= 0.8;
    if sum(hiMask) >= 2
        high_CDF_tail_weight(it) = trapz(xI(hiMask), y(hiMask));
    end
end

distance_to_31p5K = abs(allT(:) - 31.5);
transition_flag_28_32K = double(allT(:) >= 28 & allT(:) <= 32);
edge_flag = double(allT(:) == min(allT(:)) | allT(:) == max(allT(:)));

% Tail/asymmetry composite index for partial/model tests explicitly requiring this pair.
tail_asymmetry = rowMeanZ([high_CDF_tail_weight(:), symmetry_cdf_mirror(:)]);

% Try to reuse canonical S_peak from observables table when exact temperature exists.
if ismember('T_K', obsTbl.Properties.VariableNames) && ismember('S_peak', obsTbl.Properties.VariableNames)
    sPeakCanon = interp1(double(obsTbl.T_K), double(obsTbl.S_peak), allT, 'linear', NaN);
    mCanon = isfinite(sPeakCanon);
    S_peak(mCanon) = sPeakCanon(mCanon);
    S_peak_z = (S_peak - mean(S_peak, 'omitnan')) / max(std(S_peak, 'omitnan'), eps);
    medS = median(S_peak, 'omitnan');
    madS = median(abs(S_peak - medS), 'omitnan');
    S_peak_robust_z = (S_peak - medS) / max(1.4826 * madS, eps);
end

F = table();
F.T_K = allT(:);
F.kappa2 = kappa2(:);
F.abs_kappa2 = abs(kappa2(:));
F.S_peak = S_peak(:);
F.S_peak_z = S_peak_z(:);
F.S_peak_robust_z = S_peak_robust_z(:);
F.kappa1 = kappa1(:);
F.abs_kappa1 = abs(kappa1(:));
F.total_S_row_norm = total_S_row_norm(:);
F.PT_backbone_row_norm = pt_backbone_row_norm(:);
F.R1_row_norm = R1_row_norm(:);
F.R1_over_S_energy_ratio = R1_over_S_energy_ratio(:);
F.tail_burden_ratio = tail_burden_ratio(:);
F.high_CDF_tail_weight = high_CDF_tail_weight(:);
F.symmetry_cdf_mirror = symmetry_cdf_mirror(:);
F.distance_to_31p5K = distance_to_31p5K(:);
F.transition_flag_28_32K = transition_flag_28_32K(:);
F.edge_flag = edge_flag(:);
F.tail_asymmetry = tail_asymmetry(:);

% ------------------- Pairwise sensitivity table -------------------
featList = [ ...
    "kappa2","abs_kappa2","S_peak","S_peak_z","S_peak_robust_z","kappa1","abs_kappa1", ...
    "total_S_row_norm","PT_backbone_row_norm","R1_row_norm","R1_over_S_energy_ratio", ...
    "tail_burden_ratio","high_CDF_tail_weight","symmetry_cdf_mirror", ...
    "distance_to_31p5K","transition_flag_28_32K","edge_flag","T_K" ...
    ];

domains = { ...
    "full_domain", true(height(F), 1); ...
    "main_domain_excluding_28_32K", ~(F.T_K >= 28 & F.T_K <= 32) ...
    };

rowsSens = table();
for di = 1:size(domains, 1)
    dName = string(domains{di, 1});
    dMask = domains{di, 2};
    for fi = 1:numel(featList)
        xName = featList(fi);
        x = F.(xName);
        [rpS, rsS, nS] = corrPair(F.kappa2, x, dMask);
        [rpA, rsA, nA] = corrPair(F.abs_kappa2, x, dMask);
        rowsSens = [rowsSens; table( ...
            dName, xName, ...
            rpS, rsS, nS, ...
            rpA, rsA, nA, ...
            'VariableNames', {'domain','feature','pearson_kappa2','spearman_kappa2','n_kappa2','pearson_abs_kappa2','spearman_abs_kappa2','n_abs_kappa2'})]; %#ok<AGROW>
    end
end
writetable(rowsSens, outSens);

% ---------------------- Critical partial correlations ----------------------
rowsPart = table();
rowsPart = [rowsPart; partialRow(F, "kappa2", "high_CDF_tail_weight", ["S_peak"], "corr(kappa2, high_CDF_tail_weight | S_peak)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "symmetry_cdf_mirror", ["S_peak"], "corr(kappa2, symmetry_cdf_mirror | S_peak)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "S_peak", ["high_CDF_tail_weight","symmetry_cdf_mirror"], "corr(kappa2, S_peak | high_CDF_tail_weight, symmetry_cdf_mirror)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "tail_asymmetry", ["kappa1"], "corr(kappa2, tail/asymmetry | kappa1)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "S_peak", ["kappa1"], "corr(kappa2, S_peak | kappa1)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "tail_asymmetry", ["R1_over_S_energy_ratio"], "corr(kappa2, tail/asymmetry | residual energy)")];
rowsPart = [rowsPart; partialRow(F, "kappa2", "R1_over_S_energy_ratio", ["tail_asymmetry","S_peak"], "corr(kappa2, residual energy | tail/asymmetry, S_peak)")];

% Include abs(kappa2) variants to satisfy signed and magnitude view.
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "high_CDF_tail_weight", ["S_peak"], "corr(abs(kappa2), high_CDF_tail_weight | S_peak)")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "symmetry_cdf_mirror", ["S_peak"], "corr(abs(kappa2), symmetry_cdf_mirror | S_peak)")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "S_peak", ["high_CDF_tail_weight","symmetry_cdf_mirror"], "corr(abs(kappa2), S_peak | high_CDF_tail_weight, symmetry_cdf_mirror)")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "tail_asymmetry", ["abs_kappa1"], "corr(abs(kappa2), tail/asymmetry | abs(kappa1))")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "S_peak", ["abs_kappa1"], "corr(abs(kappa2), S_peak | abs(kappa1))")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "tail_asymmetry", ["R1_over_S_energy_ratio"], "corr(abs(kappa2), tail/asymmetry | residual energy)")];
rowsPart = [rowsPart; partialRow(F, "abs_kappa2", "R1_over_S_energy_ratio", ["tail_asymmetry","S_peak"], "corr(abs(kappa2), residual energy | tail/asymmetry, S_peak)")];
writetable(rowsPart, outPart);

% ------------------------- LOOCV explanatory models -------------------------
modelDefs = { ...
    'kappa2~S_peak', 'kappa2', {'S_peak'}; ...
    'kappa2~kappa1', 'kappa2', {'kappa1'}; ...
    'kappa2~high_CDF_tail_weight', 'kappa2', {'high_CDF_tail_weight'}; ...
    'kappa2~symmetry_cdf_mirror', 'kappa2', {'symmetry_cdf_mirror'}; ...
    'kappa2~high_CDF_tail_weight+symmetry_cdf_mirror', 'kappa2', {'high_CDF_tail_weight','symmetry_cdf_mirror'}; ...
    'kappa2~S_peak+high_CDF_tail_weight', 'kappa2', {'S_peak','high_CDF_tail_weight'}; ...
    'kappa2~S_peak+symmetry_cdf_mirror', 'kappa2', {'S_peak','symmetry_cdf_mirror'}; ...
    'kappa2~S_peak+high_CDF_tail_weight+symmetry_cdf_mirror', 'kappa2', {'S_peak','high_CDF_tail_weight','symmetry_cdf_mirror'}; ...
    'kappa2~residual_energy', 'kappa2', {'R1_over_S_energy_ratio'}; ...
    'kappa2~residual_energy+tail_asymmetry', 'kappa2', {'R1_over_S_energy_ratio','tail_asymmetry'} ...
    };
rowsModels = table();
for i = 1:size(modelDefs, 1)
    modelId = string(modelDefs{i, 1});
    yName = string(modelDefs{i, 2});
    xNames = string(modelDefs{i, 3});
    [fitR2, fitRmse, loocvRmse, n] = fitAndLoocv(F, yName, xNames);
    rowsModels = [rowsModels; table(modelId, yName, strjoin(xNames, '+'), fitR2, fitRmse, loocvRmse, n, ...
        'VariableNames', {'model_id','target','predictors','fit_r2','fit_rmse','loocv_rmse','n'})]; %#ok<AGROW>
end
writetable(rowsModels, outModels);

% ------------------------------ Verdicts ------------------------------
pTail = getPart(rowsPart, "kappa2", "tail_asymmetry");
pTailAbs = getPart(rowsPart, "abs_kappa2", "tail_asymmetry");
pSpeak = getPart(rowsPart, "kappa2", "S_peak");
pSpeakAbs = getPart(rowsPart, "abs_kappa2", "S_peak");
pRes = getPart(rowsPart, "kappa2", "R1_over_S_energy_ratio");
pResAbs = getPart(rowsPart, "abs_kappa2", "R1_over_S_energy_ratio");

rSpeak = getModel(rowsModels, "kappa2~S_peak", "fit_r2");
rK1 = getModel(rowsModels, "kappa2~kappa1", "fit_r2");
rTailPair = getModel(rowsModels, "kappa2~high_CDF_tail_weight+symmetry_cdf_mirror", "fit_r2");
rSpeakTail = getModel(rowsModels, "kappa2~S_peak+high_CDF_tail_weight+symmetry_cdf_mirror", "fit_r2");
rRes = getModel(rowsModels, "kappa2~residual_energy", "fit_r2");
rResTail = getModel(rowsModels, "kappa2~residual_energy+tail_asymmetry", "fit_r2");

KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE = ynp(abs(pTail) >= 0.35 || abs(pTailAbs) >= 0.35, abs(pTail) >= 0.20 || abs(pTailAbs) >= 0.20);
KAPPA2_SPEAK_DRIVER_STABLE = ynp(abs(pSpeak) >= 0.35 || abs(pSpeakAbs) >= 0.35, abs(pSpeak) >= 0.20 || abs(pSpeakAbs) >= 0.20);
KAPPA2_DRIVER_IS_GENERIC_SCALE = ynp((rK1 >= rTailPair + 0.10) || (rSpeak >= rTailPair + 0.10), (rK1 >= rTailPair) || (rSpeak >= rTailPair));
KAPPA2_DRIVER_IS_RESIDUAL_ENERGY = ynp((rRes >= rTailPair + 0.10) && (abs(pRes) >= abs(pTail) - 0.05), (rRes >= rTailPair) || (abs(pRes) >= 0.20 || abs(pResAbs) >= 0.20));
if KAPPA2_DRIVER_IS_GENERIC_SCALE == "YES" || KAPPA2_DRIVER_IS_RESIDUAL_ENERGY == "YES"
    KAPPA2_SCALE_LEAKAGE_RISK = "YES";
elseif KAPPA2_DRIVER_IS_GENERIC_SCALE == "PARTIAL" || KAPPA2_DRIVER_IS_RESIDUAL_ENERGY == "PARTIAL"
    KAPPA2_SCALE_LEAKAGE_RISK = "PARTIAL";
else
    KAPPA2_SCALE_LEAKAGE_RISK = "NO";
end

KAPPA2_REDUCIBLE_TO_SCALE = ynp((KAPPA2_DRIVER_IS_GENERIC_SCALE == "YES" || KAPPA2_DRIVER_IS_RESIDUAL_ENERGY == "YES") && KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE ~= "YES", ...
    KAPPA2_SCALE_LEAKAGE_RISK == "PARTIAL");

if KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE == "YES" && KAPPA2_SCALE_LEAKAGE_RISK == "NO"
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = "tail_asymmetry";
elseif KAPPA2_DRIVER_IS_GENERIC_SCALE == "YES" && KAPPA2_DRIVER_IS_RESIDUAL_ENERGY ~= "YES"
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = "generic_scale";
elseif KAPPA2_DRIVER_IS_RESIDUAL_ENERGY == "YES"
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = "residual_energy";
elseif KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE ~= "NO" && KAPPA2_SCALE_LEAKAGE_RISK ~= "NO"
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = "mixed";
else
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = "unresolved";
end

PHI2_INTERPRETATION_REMAINS_VALID = ynp( ...
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST == "tail_asymmetry", ...
    KAPPA2_INTERPRETATION_AFTER_SCALE_TEST == "mixed");

% Compare to previous anatomy verdicts (stability statement).
priorRep = fullfile(repoRoot, 'reports', 'switching_kappa2_observable_anatomy_audit.md');
priorTxt = "";
if exist(priorRep, 'file') == 2
    priorTxt = string(fileread(priorRep));
end
priorTailYes = contains(priorTxt, "KAPPA2_HAS_INDEPENDENT_TAIL_INFORMATION** = YES");
priorAsymYes = contains(priorTxt, "KAPPA2_HAS_INDEPENDENT_ASYMMETRY_INFORMATION** = YES");
if priorTailYes && priorAsymYes
    if KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE == "YES"
        PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS = "YES";
    elseif KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE == "PARTIAL"
        PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS = "PARTIAL";
    else
        PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS = "NO";
    end
else
    PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS = "PARTIAL";
end

statusRows = { ...
    "KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE", KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE; ...
    "KAPPA2_SPEAK_DRIVER_STABLE", KAPPA2_SPEAK_DRIVER_STABLE; ...
    "KAPPA2_DRIVER_IS_GENERIC_SCALE", KAPPA2_DRIVER_IS_GENERIC_SCALE; ...
    "KAPPA2_DRIVER_IS_RESIDUAL_ENERGY", KAPPA2_DRIVER_IS_RESIDUAL_ENERGY; ...
    "KAPPA2_SCALE_LEAKAGE_RISK", KAPPA2_SCALE_LEAKAGE_RISK; ...
    "KAPPA2_REDUCIBLE_TO_SCALE", KAPPA2_REDUCIBLE_TO_SCALE; ...
    "KAPPA2_INTERPRETATION_AFTER_SCALE_TEST", KAPPA2_INTERPRETATION_AFTER_SCALE_TEST; ...
    "PHI2_INTERPRETATION_REMAINS_VALID", PHI2_INTERPRETATION_REMAINS_VALID; ...
    "PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS", PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS ...
    };
statusTbl = cell2table(statusRows, 'VariableNames', {'check','result'});
writetable(statusTbl, outStatus);

% ------------------------------ Report ------------------------------
lines = {};
lines{end+1} = '# Switching canonical kappa2 amplitude-scale sensitivity audit';
lines{end+1} = '';
lines{end+1} = '## Scope and lock';
lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
lines{end+1} = '- Switching only. Uses certified outputs from mode evidence certification, Phi2 deformation geometry, and kappa2 observable anatomy.';
lines{end+1} = '- Failed Phi2 replacement audit excluded. Canonical decomposition/producers unchanged.';
lines{end+1} = '';
lines{end+1} = sprintf('## Feature matrix size');
lines{end+1} = sprintf('- Per-temperature rows: **%d**', height(F));
lines{end+1} = '- Features include kappa2 variants, S_peak scale terms, kappa1 scale terms, backbone/residual norms, tail/asymmetry metrics, transition/edge flags, and temperature.';
lines{end+1} = '';
lines{end+1} = '## Critical partial correlations';
for i = 1:height(rowsPart)
    lines{end+1} = sprintf('- `%s`: partial=%.4f (n=%d)', rowsPart.query(i), rowsPart.partial_corr(i), rowsPart.n(i));
end
lines{end+1} = '';
lines{end+1} = '## LOOCV model summary';
for i = 1:height(rowsModels)
    lines{end+1} = sprintf('- `%s`: R2=%.4f, fit RMSE=%.4f, LOOCV RMSE=%.4f, n=%d', ...
        rowsModels.model_id(i), rowsModels.fit_r2(i), rowsModels.fit_rmse(i), rowsModels.loocv_rmse(i), rowsModels.n(i));
end
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE = %s', KAPPA2_TAIL_ASYMMETRY_DRIVER_STABLE);
lines{end+1} = sprintf('- KAPPA2_SPEAK_DRIVER_STABLE = %s', KAPPA2_SPEAK_DRIVER_STABLE);
lines{end+1} = sprintf('- KAPPA2_DRIVER_IS_GENERIC_SCALE = %s', KAPPA2_DRIVER_IS_GENERIC_SCALE);
lines{end+1} = sprintf('- KAPPA2_DRIVER_IS_RESIDUAL_ENERGY = %s', KAPPA2_DRIVER_IS_RESIDUAL_ENERGY);
lines{end+1} = sprintf('- KAPPA2_SCALE_LEAKAGE_RISK = %s', KAPPA2_SCALE_LEAKAGE_RISK);
lines{end+1} = sprintf('- KAPPA2_REDUCIBLE_TO_SCALE = %s', KAPPA2_REDUCIBLE_TO_SCALE);
lines{end+1} = sprintf('- KAPPA2_INTERPRETATION_AFTER_SCALE_TEST = %s', KAPPA2_INTERPRETATION_AFTER_SCALE_TEST);
lines{end+1} = sprintf('- PHI2_INTERPRETATION_REMAINS_VALID = %s', PHI2_INTERPRETATION_REMAINS_VALID);
lines{end+1} = sprintf('- PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS = %s', PREVIOUS_KAPPA2_ANATOMY_VERDICTS_STABLE_AFTER_SCALE_CONTROLS);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_kappa2_amplitude_scale_sensitivity.csv`';
lines{end+1} = '- `tables/switching_kappa2_scale_partial_correlations.csv`';
lines{end+1} = '- `tables/switching_kappa2_scale_control_models.csv`';
lines{end+1} = '- `tables/switching_kappa2_scale_sensitivity_status.csv`';

switchingWriteTextLinesFile(outRep, lines, 'run_switching_kappa2_amplitude_scale_sensitivity_audit:WriteFail');
fprintf('[DONE] switching kappa2 amplitude-scale sensitivity audit -> %s\n', outRep);

function [rp, rs, n] = corrPair(a, b, mask)
m = mask & isfinite(a) & isfinite(b);
n = sum(m);
if n >= 3
    rp = corr(a(m), b(m), 'Type', 'Pearson');
    rs = corr(a(m), b(m), 'Type', 'Spearman');
else
    rp = NaN; rs = NaN;
end
end

function row = partialRow(F, target, feature, controls, query)
y = F.(target);
x = F.(feature);
Z = ones(height(F), 1);
for i = 1:numel(controls)
    Z = [Z, F.(controls(i))]; %#ok<AGROW>
end
m = isfinite(y) & isfinite(x) & all(isfinite(Z), 2);
n = sum(m);
if n < size(Z, 2) + 2 || std(y(m)) == 0 || std(x(m)) == 0
    p = NaN;
else
    ym = y(m) - Z(m, :) * (Z(m, :) \ y(m));
    xm = x(m) - Z(m, :) * (Z(m, :) \ x(m));
    if std(ym) == 0 || std(xm) == 0
        p = NaN;
    else
        p = corr(ym, xm, 'Type', 'Pearson');
    end
end
row = table(string(query), string(target), string(feature), strjoin(string(controls), '+'), p, n, ...
    'VariableNames', {'query','target','feature','controls','partial_corr','n'});
end

function [r2, rmse, loocv, n] = fitAndLoocv(F, yName, xNames)
y = F.(yName);
X = [];
for i = 1:numel(xNames)
    X = [X, F.(xNames(i))]; %#ok<AGROW>
end
m = isfinite(y) & all(isfinite(X), 2);
y = y(m); X = X(m, :); n = numel(y);
if n < size(X, 2) + 2
    r2 = NaN; rmse = NaN; loocv = NaN; return;
end
X1 = [ones(n, 1), X];
b = X1 \ y;
yhat = X1 * b;
sse = sum((y - yhat).^2);
sst = sum((y - mean(y)).^2);
r2 = 1 - sse / max(sst, eps);
rmse = sqrt(mean((y - yhat).^2));
e = NaN(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    if sum(tr) < size(X1, 2)
        continue;
    end
    bi = X1(tr, :) \ y(tr);
    e(i) = y(i) - X1(i, :) * bi;
end
loocv = sqrt(mean(e.^2, 'omitnan'));
end

function v = getPart(tbl, target, feat)
m = tbl.target == string(target) & tbl.feature == string(feat);
if any(m), v = tbl.partial_corr(find(m, 1)); else, v = NaN; end
end

function v = getModel(tbl, modelId, col)
m = tbl.model_id == string(modelId);
if any(m), v = tbl.(col)(find(m, 1)); else, v = NaN; end
end

function out = ynp(condYes, condPartial)
if condYes
    out = "YES";
elseif condPartial
    out = "PARTIAL";
else
    out = "NO";
end
end

function z = robustZ(x)
medx = median(x, 'omitnan');
madx = median(abs(x - medx), 'omitnan');
z = (x - medx) / max(1.4826 * madx, eps);
end

function m = rowMeanZ(X)
if isempty(X)
    m = [];
    return;
end
Z = NaN(size(X));
for c = 1:size(X, 2)
    col = X(:, c);
    zc = robustZ(col);
    Z(:, c) = zc;
end
m = mean(Z, 2, 'omitnan');
end
