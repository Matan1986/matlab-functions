clear; clc;

% Canonical rank-3 residual physical classification audit.
% Uses the same identity-locked canonical artifacts and the same rank-2 / diagnostic-Phi3
% construction as Stage E5 (S ~ backbone - kappa1*Phi1; Phi2 from level-1 residual; Phi3 = first
% right singular vector of the level-2 residual map). No new decomposition methods.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'run_switching_rank3_physical_classification_audit';
transitionBandK = [28, 32];
nPermNull = 500;
nBoot = 400;
rng(7, 'twister');

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_rank3_physical_classification_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Rank-3 physical classification audit initialized'}, false);

    d4Path = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    ePath = fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv');
    e5Path = fullfile(repoRoot, 'tables', 'switching_stage_e5_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    e5bPath = fullfile(repoRoot, 'tables', 'switching_stage_e5b_claim_boundary_review.csv');
    obsRootPath = fullfile(repoRoot, 'results', 'switching');
    agingRPath = fullfile(repoRoot, 'tables', 'R_vs_state.csv');

    req = {d4Path, ePath, e5Path, idPath, ampPath, obsRootPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2 && exist(req{i}, 'dir') ~= 7
            error('run_switching_rank3_physical_classification_audit:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    d4 = readStatusCsvLocal(d4Path);
    e = readStatusCsvLocal(ePath);
    e5 = readStatusCsvLocal(e5Path);
    if getStatusCheckLocal(d4, "D4_COMPLETED") ~= "YES" || getStatusCheckLocal(d4, "READY_FOR_STAGE_E_FROM_D4") ~= "YES"
        error('run_switching_rank3_physical_classification_audit:D4Gate', 'Audit blocked: D4 completion/readiness flags not satisfied.');
    end
    if getStatusCheckLocal(e, "STAGE_E_COMPLETED") ~= "YES"
        error('run_switching_rank3_physical_classification_audit:EGate', 'Audit blocked: Stage E is not complete.');
    end
    if getStatusCheckLocal(e5, "STAGE_E5_COMPLETED") ~= "YES"
        error('run_switching_rank3_physical_classification_audit:E5Gate', 'Audit blocked: Stage E5 is not complete.');
    end
    if getStatusCheckLocal(d4, "CLAIMS_UPDATE_ALLOWED") ~= "NO" || getStatusCheckLocal(e, "READY_FOR_CLAIMS_UPDATE") ~= "NO"
        error('run_switching_rank3_physical_classification_audit:ClaimsEmbargo', 'Claims embargo violated: expected claims update flags to remain NO.');
    end

    canonicalRunId = readCanonicalRunIdLocal(idPath);
    canonicalRunIdD4 = getStatusCheckLocal(d4, "CANONICAL_RUN_ID");
    canonicalRunIdE = getStatusCheckLocal(e, "CANONICAL_RUN_ID");
    canonicalRunIdE5 = getStatusCheckLocal(e5, "CANONICAL_RUN_ID");
    if strlength(canonicalRunId) == 0 || canonicalRunId ~= canonicalRunIdD4 || canonicalRunId ~= canonicalRunIdE || canonicalRunId ~= canonicalRunIdE5
        error('run_switching_rank3_physical_classification_audit:IdentityMismatch', ...
            'Canonical run mismatch across identity/D4/Stage E/E5 tables.');
    end

    canonTables = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables');
    sLongPath = fullfile(canonTables, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(canonTables, 'switching_canonical_phi1.csv');
    obsPath = fullfile(canonTables, 'switching_canonical_observables.csv');
    reqCanon = {sLongPath, phi1Path, obsPath, ampPath};
    for i = 1:numel(reqCanon)
        if exist(reqCanon{i}, 'file') ~= 2
            error('run_switching_rank3_physical_classification_audit:CanonicalMissing', ...
                'Identity-locked canonical artifact missing: %s', reqCanon{i});
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

    data = buildCanonicalMapsLocal(sLong, phi1Tbl, ampTbl);
    hierarchy = buildHierarchyLocal(data);
    observableTbl = buildObservableJoinLocal(obsTbl, hierarchy, data);

    amp3 = hierarchy.kappa3Diag(:);
    nrm = max(abs(amp3), [], 'omitnan');
    if ~isfinite(nrm) || nrm <= 0
        nrm = 1;
    end
    amp3n = abs(amp3) / nrm;
    [mxAmp, ixPeak] = max(abs(amp3), [], 'omitnan');
    peakT = data.allT(ixPeak);
    energyNearPeak = localBandEnergy(abs(amp3), data.allT(:), peakT, 2);

    ampTblOut = table(data.allT(:), amp3(:), amp3n(:), ...
        'VariableNames', {'T_K','amp3_abs','amp3_abs_normalized'});
    switchingWriteTableBothPaths(ampTblOut, repoRoot, runTables, 'rank3_amplitude_vs_T.csv');

    shapeLong = localShapeStabilityMatrix(data, hierarchy);
    switchingWriteTableBothPaths(shapeLong, repoRoot, runTables, 'rank3_shape_stability.csv');

    corrTbl = localCorrelationTable(observableTbl, data, amp3);
    agingRows = localAgingLinkageRows(agingRPath, data.allT(:), amp3);
    if ~isempty(agingRows)
        corrTbl = [corrTbl; agingRows]; %#ok<AGROW>
    end
    switchingWriteTableBothPaths(corrTbl, repoRoot, runTables, 'rank3_correlations.csv');

    transTbl = localTransitionExclusion(data, hierarchy, transitionBandK);
    switchingWriteTableBothPaths(transTbl, repoRoot, runTables, 'rank3_transition_exclusion.csv');

    nullTbl = localNullTests(hierarchy, data, amp3, nPermNull, nBoot);
    switchingWriteTableBothPaths(nullTbl, repoRoot, runTables, 'rank3_null_test.csv');

    e5bPromotion = "UNKNOWN";
    e5bClass = "UNKNOWN";
    if exist(e5bPath, 'file') == 2
        e5bTbl = readtable(e5bPath, 'TextType', 'string');
        e5bPromotion = localPickReviewItem(e5bTbl, "RANK3_PROMOTION_ALLOWED");
        e5bClass = localPickReviewItem(e5bTbl, "RANK3_CLASSIFICATION");
    end

    phi3LotoMed = localMedianLotoCos(data, hierarchy);
    transBin = data.allT >= transitionBandK(1) & data.allT <= transitionBandK(2);
    fracAmpInBand = sum(abs(amp3(transBin))) / max(sum(abs(amp3)), eps);
    mStr = string(transTbl.metric);
    ixR = mStr == "sigma1_after_phi2_ratio_excluded_over_full";
    sigmaRatio = NaN;
    if any(ixR)
        sigmaRatio = transTbl.value(find(ixR, 1));
    end

    transFlagNum = double(strcmpi(string(observableTbl.transition_flag), "YES"));
    rhoTrans = safeSpearmanLocal(abs(amp3), transFlagNum);

    verdicts = localVerdicts( ...
        peakT, transitionBandK, fracAmpInBand, sigmaRatio, rhoTrans, phi3LotoMed, ...
        nullTbl, agingRows, e5bPromotion);

    statusTbl = table( ...
        ["AUDIT_COMPLETED";"CANONICAL_RUN_ID";"E5B_RANK3_PROMOTION_ALLOWED";"E5B_RANK3_CLASSIFICATION"; ...
         "RANK3_IS_TRANSITION_MODE";"RANK3_IS_AGING_LINKED";"RANK3_IS_STRUCTURED_NOISE";"RANK3_PROMOTION_JUSTIFIED"], ...
        ["YES"; string(canonicalRunId); e5bPromotion; e5bClass; ...
         verdicts.RANK3_IS_TRANSITION_MODE; verdicts.RANK3_IS_AGING_LINKED; verdicts.RANK3_IS_STRUCTURED_NOISE; verdicts.RANK3_PROMOTION_JUSTIFIED], ...
        ["Canonical rank-3 physical classification audit completed."; ...
         "Identity-locked canonical run used for all computations."; ...
         "Read from switching_stage_e5b_claim_boundary_review.csv when present."; ...
         "Read from E5B review CSV when present."; ...
         verdicts.detail_transition; verdicts.detail_aging; verdicts.detail_noise; verdicts.detail_promotion], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'rank3_classification_status.csv');

    lines = localBuildReportMarkdown(canonicalRunId, transitionBandK, verdicts, e5bPromotion, e5bClass, ~isempty(agingRows), ...
        peakT, mxAmp, phi3LotoMed, sigmaRatio, fracAmpInBand, energyNearPeak);
    switchingWriteTextLinesFile(fullfile(runReports, 'rank3_physical_classification.md'), lines, 'run_switching_rank3_physical_classification_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'rank3_physical_classification.md'), lines, 'run_switching_rank3_physical_classification_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(statusTbl), {'Rank-3 physical classification audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_rank3_physical_classification_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    failStatus = table( ...
        ["AUDIT_COMPLETED";"ERROR"], ...
        ["NO"; string(ME.message)], ...
        [string(ME.identifier); ""], ...
        'VariableNames', {'check','result','detail'});
    writetable(failStatus, fullfile(runDir, 'tables', 'rank3_classification_status.csv'));
    writetable(failStatus, fullfile(repoRoot, 'tables', 'rank3_classification_status.csv'));
    failLines = {'# Rank-3 physical classification audit FAILED', '', sprintf('- `%s`', ME.identifier), sprintf('- %s', ME.message)};
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', 'rank3_physical_classification.md'), failLines, 'run_switching_rank3_physical_classification_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'rank3_physical_classification.md'), failLines, 'run_switching_rank3_physical_classification_audit:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Rank-3 physical classification audit failed'}, true);
    rethrow(ME);
end

%% --- Local helpers (mirror Stage E5 construction; no pipeline edits) ---

function e = localBandEnergy(amp, allT, centerT, halfWidth)
m = abs(allT - centerT) <= halfWidth;
e = sum(abs(amp(m))) / max(sum(abs(amp)), eps);
end

function shapeLong = localShapeStabilityMatrix(data, hierarchy)
holds = buildHoldoutsLocal(data);
labels = strings(numel(holds) + 1, 1);
Phi = zeros(numel(data.allI), numel(holds) + 1);
labels(1) = "full_reference";
Phi(:, 1) = hierarchy.phi3Vec(:);
for ih = 1:numel(holds)
    labels(ih+1) = holds(ih).label;
    Rsub = hierarchy.R2(holds(ih).keepMask, :);
    Rsubz = fillResidualLocal(Rsub);
    [~, ~, Vsub] = svd(Rsubz, 'econ');
    if isempty(Vsub)
        v = zeros(size(Phi, 1), 1);
    else
        v = Vsub(:, 1);
    end
    if norm(v) > 0
        v = v / norm(v);
    end
    c0 = dot(hierarchy.phi3Vec(:), v);
    if isfinite(c0) && c0 < 0
        v = -v;
    end
    Phi(:, ih + 1) = v;
end
cosBlock = abs(Phi' * Phi);
n = size(cosBlock, 1);
rowA = strings(n * n, 1);
rowB = strings(n * n, 1);
rowC = zeros(n * n, 1);
k = 0;
for i = 1:n
    for j = 1:n
        k = k + 1;
        rowA(k) = labels(i);
        rowB(k) = labels(j);
        rowC(k) = cosBlock(i, j);
    end
end
shapeLong = table(rowA, rowB, rowC, 'VariableNames', {'scenario_a','scenario_b','cosine_similarity'});
end

function phi3Med = localMedianLotoCos(data, hierarchy)
holds = buildHoldoutsLocal(data);
vals = [];
for ih = 1:numel(holds)
    if holds(ih).type ~= "leave_one_temperature_out"
        continue;
    end
    Rsub = hierarchy.R2(holds(ih).keepMask, :);
    Rsubz = fillResidualLocal(Rsub);
    [~, ~, Vsub] = svd(Rsubz, 'econ');
    if isempty(Vsub)
        v = zeros(size(hierarchy.phi3Vec));
    else
        v = Vsub(:, 1);
    end
    if norm(v) > 0
        v = v / norm(v);
    end
    vals(end+1) = abs(dot(hierarchy.phi3Vec(:), v)); %#ok<AGROW>
end
phi3Med = median(vals, 'omitnan');
end

function tbl = localCorrelationTable(observableTbl, data, amp3)
rows = table();
[y1, y2] = deal(double(data.kappa1(:)), double(data.kappa2(:)));
[r1, p1] = localSpearmanWithShuffleP(amp3(:), y1, 500);
[r2, p2] = localSpearmanWithShuffleP(amp3(:), y2, 500);
rows = [rows; table([string("kappa1");string("kappa2")], [r1;r2], [p1;p2], 'VariableNames', {'variable','spearman_rho','shuffle_p_value'})]; %#ok<AGROW>
vars = { ...
    'pt_spread_cdf_I', 'pt_spread'; ...
    'peak_asymmetry_S_I', 'peak_asymmetry'; ...
    'tail_burden_after_phi2', 'tail_burden_after_phi2'; ...
    'global_residual_after_phi2', 'global_residual_after_phi2'; ...
    'peak_residual_after_phi2', 'peak_residual_after_phi2'};
for i = 1:size(vars, 1)
    name = vars{i, 1};
    y = pickColumnLocal(observableTbl, vars{i, 2});
    [rho, pVal] = localSpearmanWithShuffleP(amp3(:), double(y(:)), 500);
    rows = [rows; table(string(name), rho, pVal, 'VariableNames', {'variable','spearman_rho','shuffle_p_value'})]; %#ok<AGROW>
end
tbl = rows;
end

function tbl = localTransitionExclusion(data, hierarchy, bandK)
R2z = hierarchy.R2z;
[~, Sfull, ~] = svd(R2z, 'econ');
if isempty(Sfull)
    sigmaFull = NaN;
else
    sigmaFull = Sfull(1);
end
mask = ~(data.allT >= bandK(1) & data.allT <= bandK(2));
Rex = R2z(mask, :);
[~, Sex, ~] = svd(fillResidualLocal(Rex), 'econ');
if isempty(Sex)
    sigmaEx = NaN;
else
    sigmaEx = Sex(1);
end
ratio = sigmaEx / max(sigmaFull, eps);

ampFull = abs(hierarchy.kappa3Diag(:));
ampExModel = NaN(size(ampFull));
if sum(mask) >= 4
    Rexz = fillResidualLocal(Rex);
    [~, ~, Vex] = svd(Rexz, 'econ');
    if isempty(Vex)
        phiEx = zeros(size(hierarchy.phi3Vec));
    else
        phiEx = Vex(:, 1);
    end
    if norm(phiEx) > 0
        phiEx = phiEx / norm(phiEx);
    end
    kEx = Rexz * phiEx;
    ampExModel(mask) = abs(kEx(:));
end

tbl = table( ...
    [string("sigma1_after_phi2_full");string("sigma1_after_phi2_excluded_band_rows");string("sigma1_after_phi2_ratio_excluded_over_full"); ...
     string("mean_abs_amp3_full");string("mean_abs_amp3_on_remaining_rows_only")], ...
    [sigmaFull; sigmaEx; ratio; mean(ampFull, 'omitnan'); mean(ampExModel(mask), 'omitnan')], ...
    'VariableNames', {'metric','value'});
end

function rows = localAgingLinkageRows(pathR, allT, amp3)
rows = table();
if exist(pathR, 'file') ~= 2
    return;
end
Rt = readtable(pathR, 'TextType', 'string');
tCol = localFirstPresent(Rt, {'T_K','T','Tk'});
rCol = localFirstPresent(Rt, {'R','R_T','R_TK'});
if isempty(tCol) || isempty(rCol)
    return;
end
Ta = double(Rt.(tCol));
Ra = double(Rt.(rCol));
ampI = interp1(allT, amp3, Ta, 'linear', NaN);
mask = isfinite(ampI) & isfinite(Ra);
if sum(mask) < 5
    return;
end
[rho, pVal] = localSpearmanWithShuffleP(ampI(mask), Ra(mask), 500);
rows = table(string("R_T"), rho, pVal, 'VariableNames', {'variable','spearman_rho','shuffle_p_value'});
end

function tbl = localNullTests(hierarchy, data, amp3, nPerm, nBoot)
rows = table();

nullCos = zeros(nPerm, 1);
for ip = 1:nPerm
    Rp = zeros(size(hierarchy.R2z));
    for it = 1:size(Rp, 1)
        Rp(it, :) = hierarchy.R2z(it, randperm(size(Rp, 2)));
    end
    [~, ~, Vp] = svd(Rp, 'econ');
    if isempty(Vp)
        v = zeros(size(hierarchy.phi3Vec));
    else
        v = Vp(:, 1);
    end
    if norm(v) > 0
        v = v / norm(v);
    end
    nullCos(ip) = abs(dot(hierarchy.phi3Vec(:), v));
end
obsAlign = 1;
pCos = (1 + sum(nullCos >= obsAlign)) / (numel(nullCos) + 1);
rows = [rows; table( ...
    string("column_shuffled_R2z_phi3_alignment"), obsAlign, mean(nullCos, 'omitnan'), prctile(nullCos, 5), prctile(nullCos, 95), pCos, ...
    string("Alignment of true Phi3 with first mode of column-shuffled null R2z (per-row permutations)."), ...
    'VariableNames', {'test_name','observed','null_median','null_p05','null_p95','p_value','detail'})]; %#ok<AGROW>

y = double(data.kappa1(:));
[rObs, pSh] = localSpearmanWithShuffleP(amp3(:), y, nPerm);
rows = [rows; table( ...
    string("shuffle_T_labels_amp3_vs_kappa1_spearman"), abs(rObs), NaN, NaN, NaN, pSh, ...
    string("Permutation null for |Spearman| between amp3 and kappa1 (labels shuffled on paired canonical rows)."), ...
    'VariableNames', {'test_name','observed','null_median','null_p05','null_p95','p_value','detail'})]; %#ok<AGROW>

bootMed = zeros(nBoot, 1);
nT = numel(amp3);
for ib = 1:nBoot
    idx = randi(nT, nT, 1);
    bootMed(ib) = median(abs(amp3(idx)), 'omitnan');
end
obsMed = median(abs(amp3), 'omitnan');
pBoot = (1 + sum(bootMed >= obsMed)) / (numel(bootMed) + 1);
rows = [rows; table( ...
    string("bootstrap_abs_amp3_median"), obsMed, median(bootMed, 'omitnan'), prctile(bootMed, 5), prctile(bootMed, 95), pBoot, ...
    string("Bootstrap resampling of temperature rows (with replacement) for |amp3| median; null tests marginal stability only."), ...
    'VariableNames', {'test_name','observed','null_median','null_p05','null_p95','p_value','detail'})]; %#ok<AGROW>

tbl = rows;
end

function v = localVerdicts(peakT, band, fracBand, sigmaRatio, rhoTrans, phi3LotoMed, nullTbl, agingRows, e5bProm)
v = struct();
inBand = peakT >= band(1) & peakT <= band(2);
sigDrop = isfinite(sigmaRatio) && sigmaRatio < 0.85;
transStrong = (inBand && fracBand >= 0.35) || (sigDrop && abs(rhoTrans) >= 0.35);
transWeak = (inBand && fracBand >= 0.20) || sigDrop || (isfinite(rhoTrans) && abs(rhoTrans) >= 0.25);
if transStrong
    v.RANK3_IS_TRANSITION_MODE = "YES";
    v.detail_transition = "Peak |amp3| lies in or near the audited transition band and/or excluding 28-32K materially reduces the leading after-phi2 singular value; transition-flag linkage is non-trivial.";
elseif transWeak
    v.RANK3_IS_TRANSITION_MODE = "PARTIAL";
    v.detail_transition = "Some transition-adjacent localization or band sensitivity is present but not decisive alone.";
else
    v.RANK3_IS_TRANSITION_MODE = "NO";
    v.detail_transition = "No strong evidence that rank-3 is primarily a localized transition mode under the tested band and observables.";
end

if ~isempty(agingRows) && height(agingRows) >= 1 && isfinite(agingRows.spearman_rho(1))
    ar = abs(agingRows.spearman_rho(1));
    ap = agingRows.shuffle_p_value(1);
    if ar >= 0.55 && ap <= 0.05
        v.RANK3_IS_AGING_LINKED = "YES";
        v.detail_aging = sprintf("|rho|=%.3f vs R(T) with shuffle p=%.4f.", ar, ap);
    elseif ar >= 0.35 && ap <= 0.15
        v.RANK3_IS_AGING_LINKED = "PARTIAL";
        v.detail_aging = sprintf("Moderate |rho|=%.3f vs R(T), p=%.4f.", ar, ap);
    else
        v.RANK3_IS_AGING_LINKED = "NO";
        v.detail_aging = "Aging R(T) join did not show a robust monotonic association with diagnostic rank-3 amplitude.";
    end
else
    v.RANK3_IS_AGING_LINKED = "NO";
    v.detail_aging = "Aging linkage not scored (R_vs_state.csv missing or insufficient overlap).";
end

tn = string(nullTbl.test_name);
pCol = nullTbl.p_value(tn == "column_shuffled_R2z_phi3_alignment");
if isempty(pCol), pCol = NaN; else, pCol = pCol(1); end
lowShape = isfinite(phi3LotoMed) && phi3LotoMed < 0.55;
noiseStrong = isfinite(pCol) && pCol > 0.20 && lowShape;
noiseWeak = (isfinite(pCol) && pCol > 0.10) || lowShape;
if noiseStrong
    v.RANK3_IS_STRUCTURED_NOISE = "YES";
    v.detail_noise = "Phi3 aligns with column-shuffled residual controls and/or leave-one-T shape coherence is limited; consistent with structured noise / non-coherent residual.";
elseif noiseWeak
    v.RANK3_IS_STRUCTURED_NOISE = "PARTIAL";
    v.detail_noise = "Mixed null-test and stability evidence; keep weak_structured_residual framing.";
else
    v.RANK3_IS_STRUCTURED_NOISE = "NO";
    v.detail_noise = "Column-shuffle nulls for Phi3 alignment are not permissive relative to the observed mode, and/or leave-one-T shape coherence is high; this argues against labeling rank-3 as primarily unstructured/stochastic noise.";
end

v.RANK3_PROMOTION_JUSTIFIED = "NO";
if e5bProm ~= "YES"
    v.detail_promotion = "Stage E5B does not allow rank-3 promotion; this audit is descriptive only and does not override E5/E5B boundaries.";
else
    v.detail_promotion = "Even if E5B flags were permissive (unexpected), this audit does not justify promoting rank-3 beyond the documented weak_structured_residual branch.";
end
end

function lines = localBuildReportMarkdown(runId, band, verdicts, e5bProm, e5bClass, agingOk, peakT, mxAmp, phi3Med, sigmaRatio, fracBand, energyNearPeak)
lines = {};
lines{end+1} = '# Rank-3 residual physical classification audit';
lines{end+1} = '';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID:** `%s`', runId);
lines{end+1} = '- **Model context:** `S ≈ S_backbone + kappa1*Phi1 + kappa2*Phi2`; rank-3 is the first SVD mode of the **existing** after-Phi2 residual (diagnostic Phi3), identical construction to Stage E5.';
lines{end+1} = sprintf('- **Transition band tested:** %.1f–%.1f K (row exclusion before SVD).', band(1), band(2));
lines{end+1} = '';
lines{end+1} = '## Mandatory outputs';
lines{end+1} = '- `tables/rank3_amplitude_vs_T.csv`';
lines{end+1} = '- `tables/rank3_shape_stability.csv` (pairwise |cos| between full Phi3 and leave-one-T / subset refits)';
lines{end+1} = '- `tables/rank3_correlations.csv` (Spearman vs canonical observables; adds `R_T` when `tables/R_vs_state.csv` exists)';
lines{end+1} = '- `tables/rank3_transition_exclusion.csv`';
lines{end+1} = '- `tables/rank3_null_test.csv`';
lines{end+1} = '- `tables/rank3_classification_status.csv`';
lines{end+1} = '- `reports/rank3_physical_classification.md`';
lines{end+1} = '';
lines{end+1} = '## Evidence summary';
lines{end+1} = sprintf('- Peak |amp3| at **T = %.4g K** (max = %.6g).', peakT, mxAmp);
lines{end+1} = sprintf('- Fraction of |amp3| mass inside [%.1f, %.1f] K ~ **%.3f**; localized +/-2K around peak ~ **%.3f**.', band(1), band(2), fracBand, energyNearPeak);
lines{end+1} = sprintf('- Median leave-one-T |cos| between Phi3 and refit mode: **%.4f**.', phi3Med);
lines{end+1} = sprintf('- Singular-value ratio (excluded-band rows / full): **%.4f**.', sigmaRatio);
lines{end+1} = '';
lines{end+1} = '## Verdicts (bounded; consistent with Stage E5 / E5B)';
lines{end+1} = sprintf('- **RANK3_IS_TRANSITION_MODE:** %s', verdicts.RANK3_IS_TRANSITION_MODE);
lines{end+1} = sprintf('- **RANK3_IS_AGING_LINKED:** %s', verdicts.RANK3_IS_AGING_LINKED);
lines{end+1} = sprintf('- **RANK3_IS_STRUCTURED_NOISE:** %s', verdicts.RANK3_IS_STRUCTURED_NOISE);
lines{end+1} = sprintf('- **RANK3_PROMOTION_JUSTIFIED:** %s', verdicts.RANK3_PROMOTION_JUSTIFIED);
lines{end+1} = '';
lines{end+1} = '### Interpretation notes';
lines{end+1} = ['- Transition: ', char(verdicts.detail_transition)];
lines{end+1} = ['- Aging: ', char(verdicts.detail_aging)];
lines{end+1} = ['- Structured noise: ', char(verdicts.detail_noise)];
lines{end+1} = ['- Promotion: ', char(verdicts.detail_promotion)];
lines{end+1} = '';
lines{end+1} = '## E5B boundary context';
lines{end+1} = sprintf('- **E5B RANK3_PROMOTION_ALLOWED (if file present):** `%s`', e5bProm);
lines{end+1} = sprintf('- **E5B RANK3_CLASSIFICATION (if file present):** `%s`', e5bClass);
lines{end+1} = '- This audit does **not** redefine observables, change preprocessing, or add new decomposition families beyond the Stage-E5 diagnostic SVD on `R2`.';
if agingOk
    lines{end+1} = '- **Aging:** `R(T)` correlation row present in `rank3_correlations.csv` (joined on temperature).';
else
    lines{end+1} = '- **Aging:** `tables/R_vs_state.csv` not available or insufficient overlap; linkage left unscored.';
end
end

function name = localFirstPresent(tbl, cands)
name = '';
for i = 1:numel(cands)
    if ismember(cands{i}, tbl.Properties.VariableNames)
        name = cands{i};
        return;
    end
end
end

function val = localPickReviewItem(tbl, key)
val = "UNKNOWN";
if ~ismember('item', tbl.Properties.VariableNames) || ~ismember('result', tbl.Properties.VariableNames)
    return;
end
m = strcmpi(strip(string(tbl.item)), strip(string(key)));
if any(m)
    val = strip(string(tbl.result(find(m, 1))));
end
end

function [rho, pVal] = localSpearmanWithShuffleP(x, y, nPerm)
rho = safeSpearmanLocal(double(x(:)), double(y(:)));
nullAbs = zeros(nPerm, 1);
for ip = 1:nPerm
    idx = randperm(numel(y));
    nullAbs(ip) = abs(safeSpearmanLocal(double(x(:)), double(y(idx))));
end
if isfinite(rho)
    pVal = (1 + sum(nullAbs >= abs(rho))) / (numel(nullAbs) + 1);
else
    pVal = NaN;
end
end

function out = readStatusCsvLocal(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
if size(raw,1) < 2 || size(raw,2) < 2
    error('run_switching_rank3_physical_classification_audit:BadStatusSchema', 'Status table is empty or malformed: %s', pathIn);
end
headers = strings(1, size(raw,2));
for i = 1:size(raw,2)
    headers(i) = lower(strip(string(raw{1,i})));
    headers(i) = regexprep(headers(i), "^\xFEFF", "");
end
iCheck = find(headers == "check", 1);
iResult = find(headers == "result", 1);
iDetail = find(headers == "detail", 1);
if isempty(iCheck) || isempty(iResult)
    error('run_switching_rank3_physical_classification_audit:BadStatusSchema', 'Status table missing check/result columns: %s', pathIn);
end
n = size(raw,1) - 1;
detail = strings(n,1);
if ~isempty(iDetail)
    detail = string(raw(2:end, iDetail));
end
out = table(strip(string(raw(2:end, iCheck))), strip(string(raw(2:end, iResult))), detail, ...
    'VariableNames', {'check','result','detail'});
end

function value = getStatusCheckLocal(tbl, key)
idx = find(strcmpi(strip(string(tbl.check)), strip(string(key))), 1);
if isempty(idx)
    value = "";
else
    value = strip(string(tbl.result(idx)));
end
end

function runId = readCanonicalRunIdLocal(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
runId = "";
for r = 2:size(raw,1)
    key = strip(string(raw{r,1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        runId = strip(string(raw{r,2}));
        return;
    end
end
end

function data = buildCanonicalMapsLocal(sLong, phi1Tbl, ampTbl)
reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
for i = 1:numel(reqS)
    if ~ismember(reqS{i}, sLong.Properties.VariableNames)
        error('run_switching_rank3_physical_classification_audit:BadSLongSchema', 'switching_canonical_S_long.csv missing %s', reqS{i});
    end
end
reqP = {'current_mA','Phi1'};
for i = 1:numel(reqP)
    if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
        error('run_switching_rank3_physical_classification_audit:BadPhi1Schema', 'switching_canonical_phi1.csv missing %s', reqP{i});
    end
end
reqA = {'T_K','kappa1','kappa2'};
for i = 1:numel(reqA)
    if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
        error('run_switching_rank3_physical_classification_audit:BadAmpSchema', 'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
    end
end

T = double(sLong.T_K);
I = double(sLong.current_mA);
S = double(sLong.S_percent);
B = double(sLong.S_model_pt_percent);
C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
G = groupsummary(table(T(v), I(v), S(v), B(v), C(v)), {'Var1','Var2'}, 'mean', {'Var3','Var4','Var5'});

allT = unique(double(G.Var1), 'sorted');
allI = unique(double(G.Var2), 'sorted');
nT = numel(allT);
nI = numel(allI);
Smap = NaN(nT, nI);
Bmap = NaN(nT, nI);
Cmap = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.Var1) - allT(it)) < 1e-9 & abs(double(G.Var2) - allI(ii)) < 1e-9;
        if any(m)
            j = find(m, 1);
            Smap(it, ii) = double(G.mean_Var3(j));
            Bmap(it, ii) = double(G.mean_Var4(j));
            Cmap(it, ii) = double(G.mean_Var5(j));
        end
    end
end

phiI = double(phi1Tbl.current_mA);
phiV = double(phi1Tbl.Phi1);
pv = isfinite(phiI) & isfinite(phiV);
Pg = groupsummary(table(phiI(pv), phiV(pv)), {'Var1'}, 'mean', {'Var2'});
phi1Vec = interp1(double(Pg.Var1), double(Pg.mean_Var2), allI, 'linear', NaN)';
phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
if norm(phi1Vec) > 0
    phi1Vec = phi1Vec / norm(phi1Vec);
end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');
if ismember('kappa3', ampTbl.Properties.VariableNames)
    kappa3Producer = interp1(double(ampTbl.T_K), double(ampTbl.kappa3), allT, 'linear', NaN);
    kappa3Producer = fillmissing(kappa3Producer, 'linear', 'EndValues', 'nearest');
else
    kappa3Producer = NaN(size(allT));
end
if ismember('regime_label', ampTbl.Properties.VariableNames)
    regimeTbl = ampTbl(:, {'T_K','regime_label'});
    regimeTbl = sortrows(regimeTbl, 'T_K');
    regimeLabel = strings(nT, 1);
    for it = 1:nT
        idx = find(abs(double(regimeTbl.T_K) - allT(it)) < 1e-9, 1);
        if isempty(idx)
            regimeLabel(it) = "unlabeled";
        else
            regimeLabel(it) = string(regimeTbl.regime_label(idx));
        end
    end
else
    regimeLabel = repmat("unlabeled", nT, 1);
end
if ismember('transition_flag', ampTbl.Properties.VariableNames)
    transitionTbl = ampTbl(:, {'T_K','transition_flag'});
    transitionTbl = sortrows(transitionTbl, 'T_K');
    transitionFlag = strings(nT, 1);
    for it = 1:nT
        idx = find(abs(double(transitionTbl.T_K) - allT(it)) < 1e-9, 1);
        if isempty(idx)
            transitionFlag(it) = "NO";
        else
            transitionFlag(it) = string(transitionTbl.transition_flag(idx));
        end
    end
else
    transitionFlag = repmat("NO", nT, 1);
end

validMap = isfinite(Smap) & isfinite(Bmap);
cdfAxis = mean(Cmap, 1, 'omitnan');
tailMask = cdfAxis >= 0.80;
if ~any(tailMask)
    tailMask = false(1, nI);
    tailMask(max(nI-1,1):nI) = true;
end

data = struct();
data.allT = allT(:);
data.allI = allI(:);
data.Smap = Smap;
data.Bmap = Bmap;
data.Cmap = Cmap;
data.validMap = validMap;
data.cdfAxis = cdfAxis(:)';
data.tailMask = logical(tailMask(:)');
data.phi1Vec = phi1Vec(:);
data.kappa1 = kappa1(:);
data.kappa2 = kappa2(:);
data.kappa3Producer = kappa3Producer(:);
data.regimeLabel = regimeLabel(:);
data.transitionFlag = transitionFlag(:);
end

function hierarchy = buildHierarchyLocal(data)
pred0 = data.Bmap;
pred1 = pred0 - data.kappa1(:) * data.phi1Vec(:)';
R0 = data.Smap - pred0;
R1 = data.Smap - pred1;
R1z = R1;
R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if isempty(V1)
    phi2 = zeros(numel(data.allI), 1);
else
    phi2 = V1(:, 1);
end
if norm(phi2) > 0
    phi2 = phi2 / norm(phi2);
end
pred2 = pred1 + data.kappa2(:) * phi2(:)';
R2 = data.Smap - pred2;
R2z = R2;
R2z(~isfinite(R2z)) = 0;
[~, S2, V2] = svd(R2z, 'econ');
if isempty(V2)
    phi3 = zeros(numel(data.allI), 1);
else
    phi3 = V2(:, 1);
end
if norm(phi3) > 0
    phi3 = phi3 / norm(phi3);
end
kappa3Diag = R2z * phi3;
pred3 = pred2 + kappa3Diag(:) * phi3(:)';
R3 = data.Smap - pred3;

hierarchy = struct();
hierarchy.pred0 = pred0;
hierarchy.pred1 = pred1;
hierarchy.pred2 = pred2;
hierarchy.pred3 = pred3;
hierarchy.R0 = R0;
hierarchy.R1 = R1;
hierarchy.R2 = R2;
hierarchy.R3 = R3;
hierarchy.R2z = R2z;
hierarchy.R3z = fillResidualLocal(R3);
hierarchy.phi2Vec = phi2(:);
hierarchy.phi3Vec = phi3(:);
hierarchy.kappa3Diag = kappa3Diag(:);
hierarchy.svd2 = diag(S2);
end

function out = fillResidualLocal(R)
out = R;
out(~isfinite(out)) = 0;
end

function tbl = buildObservableJoinLocal(obsTbl, hierarchy, data)
reqObs = {'T_K','S_peak','I_peak'};
for i = 1:numel(reqObs)
    if ~ismember(reqObs{i}, obsTbl.Properties.VariableNames)
        error('run_switching_rank3_physical_classification_audit:BadObservableSchema', 'switching_canonical_observables.csv missing %s', reqObs{i});
    end
end

midMask = data.cdfAxis > 0.40 & data.cdfAxis < 0.60;
if ~any(midMask)
    midMask = ismember(1:numel(data.allI), [3 4 5]);
end
tailBurden0 = mean(hierarchy.R0(:, data.tailMask).^2, 2, 'omitnan') ./ max(mean(hierarchy.R0(:, midMask).^2, 2, 'omitnan'), eps);
tailBurden2 = mean(hierarchy.R2(:, data.tailMask).^2, 2, 'omitnan') ./ max(mean(hierarchy.R2(:, midMask).^2, 2, 'omitnan'), eps);
globalResidual2 = mean(hierarchy.R2.^2, 2, 'omitnan');
peakResidual2 = max(abs(hierarchy.R2), [], 2, 'omitnan');
ptSpread = std(data.Cmap, 0, 2, 'omitnan');
Sp = double(obsTbl.S_peak);
Ip = double(obsTbl.I_peak);
asym = abs(Sp - Ip) ./ max(max(abs(Sp), abs(Ip)), eps);

J = table(data.allT(:), tailBurden0(:), tailBurden2(:), globalResidual2(:), peakResidual2(:), ...
    hierarchy.kappa3Diag(:), data.kappa3Producer(:), data.kappa1(:), data.kappa2(:), ...
    data.regimeLabel(:), data.transitionFlag(:), ptSpread(:), asym(:), ...
    'VariableNames', {'T_K','tail_burden_backbone','tail_burden_after_phi2','global_residual_after_phi2','peak_residual_after_phi2', ...
    'kappa3_diag','kappa3_producer','kappa1','kappa2','regime_label','transition_flag','pt_spread','peak_asymmetry'});
O = groupsummary(obsTbl, 'T_K', 'mean', setdiff(obsTbl.Properties.VariableNames, {'T_K'}));
O.Properties.VariableNames = strrep(O.Properties.VariableNames, 'mean_', '');
tbl = outerjoin(J, O, 'Keys', 'T_K', 'MergeKeys', true);
tbl = sortrows(tbl, 'T_K');
end

function value = pickColumnLocal(tbl, name)
if ismember(name, tbl.Properties.VariableNames)
    value = tbl.(name);
else
    value = NaN(height(tbl), 1);
end
end

function holdouts = buildHoldoutsLocal(data)
nT = numel(data.allT);
holdouts = struct('type', {}, 'label', {}, 'keepMask', {}, 'detail', {});
for i = 1:nT
    keep = true(nT, 1);
    keep(i) = false;
    holdouts(end+1) = struct( ...
        'type', "leave_one_temperature_out", ...
        'label', string(sprintf('omit_%gK', data.allT(i))), ...
        'keepMask', keep, ...
        'detail', string(sprintf('Leave-one-temperature-out excluding T=%.6g K.', data.allT(i))));
end
preMask = data.transitionFlag ~= "YES";
if sum(preMask) >= 4
    holdouts(end+1) = struct( ...
        'type', "subset_exclusion", ...
        'label', "exclude_transition", ...
        'keepMask', preMask, ...
        'detail', "Subset fit excluding transition-flagged temperatures.");
end
transMask = data.transitionFlag == "YES";
if sum(transMask) >= 4
    holdouts(end+1) = struct( ...
        'type', "subset_exclusion", ...
        'label', "exclude_pretransition", ...
        'keepMask', transMask, ...
        'detail', "Subset fit using transition-flagged temperatures only.");
end
end

function c = safeSpearmanLocal(x, y)
mask = isfinite(x) & isfinite(y);
if sum(mask) < 4
    c = NaN;
    return;
end
c = corr(x(mask), y(mask), 'Type', 'Spearman', 'Rows', 'complete');
end
