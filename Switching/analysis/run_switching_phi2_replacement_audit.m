% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — compares proxy observables to hierarchy Phi2 increment; not authoritative corrected-old Phi2
% EVIDENCE_STATUS: AUDIT_ONLY — "Canonical" in comments refers to CANON_COLLAPSE / Stage E5 semantics; not CORRECTED_CANONICAL_OLD_ANALYSIS CSV package
% UNSAFE_USE: treating audit as proof of manuscript Phi2 without claim boundary B07/B08 review
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

% Phi2 replacement audit using physical observables (naming: canonical increment vs proxies — see docs/switching_analysis_map.md).
% Tests whether a linear combination of tail_burden_ratio, symmetry_cdf_mirror, and rmse_full_row
% can approximate the level-2 residual R2 (same construction as Stage E5), compared to the
% canonical Phi2 increment (pred2 - pred1). Does not change preprocessing or the canonical producer.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'run_switching_phi2_replacement_audit';
bandK = [28, 32];

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_phi2_replacement_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Phi2 replacement audit initialized'}, false);

    d4Path = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    ePath = fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv');
    e5Path = fullfile(repoRoot, 'tables', 'switching_stage_e5_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    obsRootPath = fullfile(repoRoot, 'results', 'switching');
    req = {d4Path, ePath, e5Path, idPath, ampPath, obsRootPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2 && exist(req{i}, 'dir') ~= 7
            error('run_switching_phi2_replacement_audit:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    d4 = readStatusPhi(d4Path);
    e = readStatusPhi(ePath);
    e5 = readStatusPhi(e5Path);
    if getCheckPhi(d4, "D4_COMPLETED") ~= "YES" || getCheckPhi(d4, "READY_FOR_STAGE_E_FROM_D4") ~= "YES"
        error('run_switching_phi2_replacement_audit:D4Gate', 'Audit blocked: D4 flags not satisfied.');
    end
    if getCheckPhi(e, "STAGE_E_COMPLETED") ~= "YES"
        error('run_switching_phi2_replacement_audit:EGate', 'Audit blocked: Stage E not complete.');
    end
    if getCheckPhi(e5, "STAGE_E5_COMPLETED") ~= "YES"
        error('run_switching_phi2_replacement_audit:E5Gate', 'Audit blocked: Stage E5 not complete.');
    end
    if getCheckPhi(d4, "CLAIMS_UPDATE_ALLOWED") ~= "NO" || getCheckPhi(e, "READY_FOR_CLAIMS_UPDATE") ~= "NO"
        error('run_switching_phi2_replacement_audit:ClaimsEmbargo', 'Claims embargo violated.');
    end

    canonicalRunId = readCanonRunPhi(idPath);
    if canonicalRunId ~= getCheckPhi(d4, "CANONICAL_RUN_ID") || canonicalRunId ~= getCheckPhi(e, "CANONICAL_RUN_ID") || canonicalRunId ~= getCheckPhi(e5, "CANONICAL_RUN_ID")
        error('run_switching_phi2_replacement_audit:IdentityMismatch', 'Canonical run ID mismatch across gates.');
    end

    canonTables = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables');
    sLongPath = fullfile(canonTables, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(canonTables, 'switching_canonical_phi1.csv');
    obsPath = fullfile(canonTables, 'switching_canonical_observables.csv');
    for p = {sLongPath, phi1Path, obsPath, ampPath}
        if exist(p{1}, 'file') ~= 2
            error('run_switching_phi2_replacement_audit:CanonicalMissing', 'Missing %s', p{1});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    obsTbl = readtable(obsPath);

    data = buildCanonicalMapsPhi(sLong, phi1Tbl, ampTbl);
    hierarchy = buildHierarchyPhi(data);
    obsJoin = buildObservableJoinPhi(obsTbl, hierarchy, data);

    [feat, featNames] = buildPhi2ObservableFeatures(data, hierarchy, obsJoin);
    Delta2 = hierarchy.pred2 - hierarchy.pred1;
    R2 = hierarchy.R2;
    valid = data.validMap;

    yR2 = R2(valid);
    Xfull = [feat.tail(valid), feat.sym(valid), feat.rmseRow(valid)];
    allTgrid = repmat(data.allT, 1, numel(data.allI));
    tVec = allTgrid(valid);
    [~, rmseInObs, yhatVec] = localFitOLS(yR2, Xfull);
    rmseR2 = sqrt(mean(yR2.^2, 'omitnan'));
    yDeltaV = Delta2(valid);
    [pPearR2, pSpearR2] = localCorrPred(yR2, yhatVec);
    [pPearD2, pSpearD2] = localCorrPred(yDeltaV, yhatVec);

    loocvObs = localLOOCVLinear(yR2, Xfull, tVec, true(numel(yR2), 1));

    perfRows = table();
    perfRows = [perfRows; localPerfRow("observable_linear_R2", rmseInObs, loocvObs, pPearR2, pSpearR2, ...
        "Predict R2 with z-scored tail_burden_ratio, symmetry_cdf_mirror, rmse_full_row.")]; %#ok<AGROW>
    perfRows = [perfRows; localPerfRow("baseline_R2_energy", rmseR2, rmseR2, NaN, NaN, ...
        "sqrt(mean(R2^2)) on valid cells (intrinsic rank-2 residual energy).")]; %#ok<AGROW>
    perfRows = [perfRows; localPerfRow("observable_vs_Phi2_increment", NaN, NaN, pPearD2, pSpearD2, ...
        "Correlation of observable R2-hat with canonical Phi2 increment (Delta2) on valid cells.")]; %#ok<AGROW>
    ratioRmse = rmseInObs / max(rmseR2, eps);
    perfRows = [perfRows; localPerfRow("ratio_observable_RMSE_over_R2", ratioRmse, NaN, NaN, NaN, ...
        "In-sample RMSE(obs model) / RMSE(R2 alone).")]; %#ok<AGROW>

    switchingWriteTableBothPaths(perfRows, repoRoot, runTables, 'phi2_replacement_model_performance.csv');

    subsetTbl = localMinimalBasisSearch(yR2, Xfull, tVec, true(numel(yR2), 1), featNames);
    switchingWriteTableBothPaths(subsetTbl, repoRoot, runTables, 'phi2_minimal_basis.csv');

    stabTbl = localStabilityExcludeBand(yR2, Xfull, tVec, bandK, featNames);
    switchingWriteTableBothPaths(stabTbl, repoRoot, runTables, 'phi2_replacement_stability.csv');

    Smap = data.Smap;
    pred2 = hierarchy.pred2;
    validS = valid;
    Svec = Smap(validS);
    pred2vec = pred2(validS);
    R2hat = zeros(size(R2));
    R2hat(valid) = reshape(yhatVec, size(R2(valid)));
    S_rec_obs = hierarchy.pred1 + R2hat;
    S_rec_obs_vec = S_rec_obs(validS);
    corrS = corr(Svec(:), S_rec_obs_vec(:), 'Type', 'Pearson', 'Rows', 'complete');
    spearS = corr(Svec(:), S_rec_obs_vec(:), 'Type', 'Spearman', 'Rows', 'complete');
    corrSphi2 = corr(Svec(:), pred2vec(:), 'Type', 'Pearson', 'Rows', 'complete');

    verdict = localVerdictsPhi(loocvObs, rmseR2, pSpearR2, subsetTbl, ratioRmse);

    lines = localReportPhi(canonicalRunId, verdict, perfRows, subsetTbl, stabTbl, corrS, spearS, corrSphi2, bandK);
    switchingWriteTextLinesFile(fullfile(runReports, 'phi2_replacement_audit.md'), lines, 'run_switching_phi2_replacement_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'phi2_replacement_audit.md'), lines, 'run_switching_phi2_replacement_audit:WriteFail');

    statusTbl = table( ...
        ["PHI2_REPLACEMENT_SUCCESS";"MINIMAL_OBSERVABLE_SET_FOUND";"PHI2_REQUIRED_FOR_RECONSTRUCTION";"PHYSICAL_CLOSURE_IMPROVED";"CANONICAL_RUN_ID"], ...
        [verdict.PHI2_REPLACEMENT_SUCCESS; verdict.MINIMAL_OBSERVABLE_SET_FOUND; verdict.PHI2_REQUIRED_FOR_RECONSTRUCTION; ...
         verdict.PHYSICAL_CLOSURE_IMPROVED; canonicalRunId], ...
        [verdict.detail_rep; verdict.detail_min; verdict.detail_req; verdict.detail_clos; "Identity-locked canonical run."], ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runTables, 'phi2_replacement_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'phi2_replacement_status.csv'));

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(perfRows), {'Phi2 replacement audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_phi2_replacement_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    failLines = {'# Phi2 replacement audit FAILED', '', sprintf('- `%s`', ME.identifier), sprintf('- %s', ME.message)};
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', 'phi2_replacement_audit.md'), failLines, 'run_switching_phi2_replacement_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'phi2_replacement_audit.md'), failLines, 'run_switching_phi2_replacement_audit:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Phi2 replacement audit failed'}, true);
    rethrow(ME);
end

%% --- helpers ---

function row = localPerfRow(name, rmseIn, rmseLoo, pear, spear, detail)
row = table(string(name), rmseIn, rmseLoo, pear, spear, string(detail), ...
    'VariableNames', {'model','rmse_in_sample','rmse_loocv','pearson_y_yhat','spearman_y_yhat','detail'});
end

function [beta, rmse, yhat] = localFitOLS(y, X)
n = numel(y);
y = y(:);
X = reshape(X, numel(y), size(X, 2));
mask = isfinite(y) & all(isfinite(X), 2);
yy = y(mask);
XX = X(mask, :);
Xz = localZscore(XX);
beta = Xz \ yy;
yh = Xz * beta;
res = yy - yh;
rmse = sqrt(mean(res.^2, 'omitnan'));
yhat = NaN(n, 1);
yhat(mask) = yh;
beta = beta(:);
end

function Xz = localZscore(X)
Xz = zeros(size(X));
for j = 1:size(X, 2)
    c = X(:, j);
    m = mean(c, 'omitnan');
    s = std(c, 0, 'omitnan');
    if ~isfinite(s) || s <= 0
        Xz(:, j) = c - m;
    else
        Xz(:, j) = (c - m) / s;
    end
end
end

function cv = localLOOCVLinear(yVec, XMat, tVec, ~)
yVec = yVec(:);
tVec = tVec(:);
XMat = reshape(XMat, numel(yVec), size(XMat, 2));
uT = unique(tVec);
errs = [];
for k = 1:numel(uT)
    th = uT(k);
    trainM = tVec ~= th;
    testM = tVec == th;
    yt = yVec(trainM);
    Xt = XMat(trainM, :);
    ye = yVec(testM);
    Xe = XMat(testM, :);
    if numel(yt) < 12 || numel(ye) < 1 || rank(Xt) < 1
        continue;
    end
    Xtz = localZscore(Xt);
    Xez = localZscoreApply(Xe, Xt);
    b = Xtz \ yt;
    pred = Xez * b;
    errs(end+1) = sqrt(mean((ye - pred).^2, 'omitnan')); %#ok<AGROW>
end
if isempty(errs)
    cv = NaN;
else
    cv = mean(errs, 'omitnan');
end
end

function Xe = localZscoreApply(Xe, Xref)
Xe = zeros(size(Xe));
for j = 1:size(Xe, 2)
    m = mean(Xref(:, j), 'omitnan');
    s = std(Xref(:, j), 0, 'omitnan');
    if ~isfinite(s) || s <= 0
        Xe(:, j) = Xe(:, j) - m;
    else
        Xe(:, j) = (Xe(:, j) - m) / s;
    end
end
end

function [pp, sp] = localCorrPred(y, yhat)
m = isfinite(y) & isfinite(yhat);
if sum(m) < 5
    pp = NaN;
    sp = NaN;
else
    pp = corr(y(m), yhat(m), 'Type', 'Pearson', 'Rows', 'complete');
    sp = corr(y(m), yhat(m), 'Type', 'Spearman', 'Rows', 'complete');
end
end

function subsetTbl = localMinimalBasisSearch(y, X, allT, valid, featNames)
sets = { ...
    [1], "tail_only"; ...
    [2], "symmetry_only"; ...
    [3], "rmse_row_only"; ...
    [1 2], "tail_sym"; ...
    [1 3], "tail_rmse"; ...
    [2 3], "sym_rmse"; ...
    [1 2 3], "full_triplet"};
rows = table();
for i = 1:size(sets, 1)
    cols = sets{i, 1};
    Xi = X(:, cols);
    [~, rmseIn, ~] = localFitOLS(y, Xi);
    loocv = localLOOCVLinear(y, Xi, allT, valid);
    fn = featNames(cols);
    if iscell(fn)
        fstr = strjoin(cellfun(@char, fn, 'UniformOutput', false), '+');
    else
        fstr = char(strjoin(string(fn), '+'));
    end
    rows = [rows; table(string(sets{i,2}), string(fstr), rmseIn, loocv, ...
        'VariableNames', {'subset_label','features','rmse_in_sample','rmse_loocv'})]; %#ok<AGROW>
end
subsetTbl = sortrows(rows, 'rmse_loocv');
end

function stab = localStabilityExcludeBand(y, X, tVec, band, featNames)
y = y(:);
X = reshape(X, numel(y), size(X, 2));
tVec = tVec(:);
trainM = ~(tVec >= band(1) & tVec <= band(2));
[bf, ~, ~] = localFitOLS(y(trainM), X(trainM, :));
[bg, ~, ~] = localFitOLS(y, X);
n = numel(featNames);
fn = string(featNames(:));
stab = table( ...
    [fn; fn], ...
    [bf(:); bg(:)], ...
    [repmat(string("exclude_28_32K"), n, 1); repmat(string("full_sample"), n, 1)], ...
    'VariableNames', {'feature','coefficient_zscaled','fit_scope'});
end

function v = localVerdictsPhi(loocvObs, rmseR2, spearObs, subsetTbl, ratioRmse)
v = struct();
sl = string(subsetTbl.subset_label);
best3 = subsetTbl.rmse_loocv(sl == "full_triplet");
if isempty(best3), best3 = NaN; else, best3 = best3(1); end
best1 = min(subsetTbl.rmse_loocv(sl ~= "full_triplet"), [], 'omitnan');

if isfinite(loocvObs) && isfinite(rmseR2) && loocvObs <= rmseR2 * 1.05 && isfinite(spearObs) && spearObs >= 0.85
    v.PHI2_REPLACEMENT_SUCCESS = "YES";
    v.detail_rep = "LOOCV observable RMSE is within 5% of ||R2|| and Spearman(y,yhat) is high.";
elseif isfinite(loocvObs) && loocvObs <= rmseR2 * 1.2 && isfinite(spearObs) && spearObs >= 0.65
    v.PHI2_REPLACEMENT_SUCCESS = "PARTIAL";
    v.detail_rep = "Observable surface tracks R2 moderately under LOOCV; not a full substitute for the rank-1 Phi2 increment.";
else
    v.PHI2_REPLACEMENT_SUCCESS = "NO";
    v.detail_rep = "Observable linear model does not match R2 to the requested tolerance under LOOCV.";
end

if isfinite(best1) && isfinite(best3) && best1 <= best3 * 1.08
    v.MINIMAL_OBSERVABLE_SET_FOUND = "YES";
    v.detail_min = "A strict subset achieves LOOCV within ~8% of the full triplet.";
elseif isfinite(best1) && best1 <= best3 * 1.2
    v.MINIMAL_OBSERVABLE_SET_FOUND = "PARTIAL";
    v.detail_min = "Some subsets are competitive but not clearly minimal.";
else
    v.MINIMAL_OBSERVABLE_SET_FOUND = "NO";
    v.detail_min = "Full triplet is needed under LOOCV among the tested subsets.";
end

if v.PHI2_REPLACEMENT_SUCCESS == "YES"
    v.PHI2_REQUIRED_FOR_RECONSTRUCTION = "NO";
    v.detail_req = "Observable replacement reaches the YES threshold vs ||R2|| benchmark.";
elseif v.PHI2_REPLACEMENT_SUCCESS == "PARTIAL"
    v.PHI2_REQUIRED_FOR_RECONSTRUCTION = "PARTIAL";
    v.detail_req = "Phi2 increment still preferred for tight reconstruction; observables are auxiliary.";
else
    v.PHI2_REQUIRED_FOR_RECONSTRUCTION = "YES";
    v.detail_req = "Canonical Phi2 increment remains necessary relative to the tested observables.";
end

if v.PHI2_REPLACEMENT_SUCCESS == "YES" && isfinite(ratioRmse) && ratioRmse < 0.95
    v.PHYSICAL_CLOSURE_IMPROVED = "YES";
    v.detail_clos = "Observable linear surface reduces in-sample R2 RMSE below raw ||R2|| with strong LOOCV/Spearman gates.";
elseif v.PHI2_REPLACEMENT_SUCCESS ~= "NO" && isfinite(ratioRmse) && ratioRmse < 1.05
    v.PHYSICAL_CLOSURE_IMPROVED = "PARTIAL";
    v.detail_clos = "Some in-sample compression of R2 with bounded LOOCV; linear diagnostic only, not a new closure claim.";
else
    v.PHYSICAL_CLOSURE_IMPROVED = "NO";
    v.detail_clos = "No evidence that this observable triplet improves physical closure versus canonical Phi2.";
end
end

function lines = localReportPhi(runId, verdict, perf, subset, stab, corrS, spearS, corrP2, bandK)
lines = {};
lines{end+1} = '# Canonical Phi2 replacement audit (physical observables)';
lines{end+1} = '';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID:** `%s`', runId);
lines{end+1} = '- **Target:** `R2 = S - pred2` (level-2 residual, Stage E5 construction).';
lines{end+1} = '- **Observable model:** `R2 ~ a * tail_burden_ratio + b * symmetry_cdf_mirror + c * rmse_full_row` (entries z-scored per column for OLS).';
lines{end+1} = sprintf('- **Stability band excluded:** %.1f–%.1f K.', bandK(1), bandK(2));
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/phi2_replacement_model_performance.csv`';
lines{end+1} = '- `tables/phi2_minimal_basis.csv`';
lines{end+1} = '- `tables/phi2_replacement_stability.csv`';
lines{end+1} = '- `tables/phi2_replacement_status.csv` (verdict rows)';
lines{end+1} = '- `reports/phi2_replacement_audit.md`';
lines{end+1} = '';
lines{end+1} = '## Verdicts';
lines{end+1} = sprintf('- **PHI2_REPLACEMENT_SUCCESS:** %s', verdict.PHI2_REPLACEMENT_SUCCESS);
lines{end+1} = sprintf('- **MINIMAL_OBSERVABLE_SET_FOUND:** %s', verdict.MINIMAL_OBSERVABLE_SET_FOUND);
lines{end+1} = sprintf('- **PHI2_REQUIRED_FOR_RECONSTRUCTION:** %s', verdict.PHI2_REQUIRED_FOR_RECONSTRUCTION);
lines{end+1} = sprintf('- **PHYSICAL_CLOSURE_IMPROVED:** %s', verdict.PHYSICAL_CLOSURE_IMPROVED);
lines{end+1} = '';
lines{end+1} = '## S vs reconstructed S (observable-adjusted pred1)';
lines{end+1} = sprintf('- Pearson(S, S_rec_obs): **%.4f**', corrS);
lines{end+1} = sprintf('- Spearman(S, S_rec_obs): **%.4f**', spearS);
lines{end+1} = sprintf('- Pearson(S, pred2_canonical): **%.4f** (reference)', corrP2);
lines{end+1} = '';
lines{end+1} = '### Notes';
lines{end+1} = char(verdict.detail_rep);
lines{end+1} = char(verdict.detail_min);
lines{end+1} = char(verdict.detail_req);
lines{end+1} = char(verdict.detail_clos);
end

function [feat, names] = buildPhi2ObservableFeatures(data, hierarchy, obsJoin)
nT = size(data.Smap, 1);
nI = size(data.Smap, 2);
tailRatio = obsJoin.tail_burden_after_phi2;
if ~isnumeric(tailRatio), tailRatio = double(tailRatio); end
tailMat = repmat(tailRatio(:), 1, nI);
rmseRow = sqrt(mean((data.Smap - hierarchy.pred0).^2, 2, 'omitnan'));
rmseMat = repmat(rmseRow(:), 1, nI);
cdf = data.cdfAxis(:)';
symMat = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        if ~data.validMap(it, ii)
            continue;
        end
        ci = cdf(ii);
        target = 1 - ci;
        [~, jj] = min(abs(cdf - target));
        symMat(it, ii) = data.Smap(it, ii) - data.Smap(it, jj);
    end
end
feat = struct('tail', tailMat, 'sym', symMat, 'rmseRow', rmseMat);
names = {'tail_burden_ratio', 'symmetry_cdf_mirror', 'rmse_full_row'};
end

function tbl = readStatusPhi(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
headers = strings(1, size(raw,2));
for i = 1:size(raw,2)
    headers(i) = lower(strip(string(raw{1,i})));
    headers(i) = regexprep(headers(i), "^\xFEFF", "");
end
ic = find(headers == "check", 1);
ir = find(headers == "result", 1);
id = find(headers == "detail", 1);
n = size(raw,1)-1;
det = strings(n,1);
if ~isempty(id), det = string(raw(2:end, id)); end
tbl = table(strip(string(raw(2:end,ic))), strip(string(raw(2:end,ir))), det, 'VariableNames', {'check','result','detail'});
end

function v = getCheckPhi(tbl, key)
ix = find(strcmpi(strip(string(tbl.check)), strip(string(key))), 1);
if isempty(ix), v = ""; else, v = strip(string(tbl.result(ix))); end
end

function runId = readCanonRunPhi(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
runId = "";
for r = 2:size(raw,1)
    k = strip(string(raw{r,1}));
    k = regexprep(k, "^\xFEFF", "");
    if strcmpi(k, "CANONICAL_RUN_ID")
        runId = strip(string(raw{r,2}));
        return;
    end
end
end

function data = buildCanonicalMapsPhi(sLong, phi1Tbl, ampTbl)
reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
for i = 1:numel(reqS)
    assert(ismember(reqS{i}, sLong.Properties.VariableNames));
end
T = double(sLong.T_K); I = double(sLong.current_mA);
S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
G = groupsummary(table(T(v), I(v), S(v), B(v), C(v)), {'Var1','Var2'}, 'mean', {'Var3','Var4','Var5'});
allT = unique(double(G.Var1), 'sorted');
allI = unique(double(G.Var2), 'sorted');
nT = numel(allT); nI = numel(allI);
Smap = NaN(nT,nI); Bmap = NaN(nT,nI); Cmap = NaN(nT,nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.Var1)-allT(it))<1e-9 & abs(double(G.Var2)-allI(ii))<1e-9;
        if any(m)
            j = find(m,1);
            Smap(it,ii) = double(G.mean_Var3(j));
            Bmap(it,ii) = double(G.mean_Var4(j));
            Cmap(it,ii) = double(G.mean_Var5(j));
        end
    end
end
phiI = double(phi1Tbl.current_mA); phiV = double(phi1Tbl.Phi1);
pv = isfinite(phiI) & isfinite(phiV);
Pg = groupsummary(table(phiI(pv), phiV(pv)), {'Var1'}, 'mean', {'Var2'});
phi1Vec = interp1(double(Pg.Var1), double(Pg.mean_Var2), allI, 'linear', NaN)';
phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
if norm(phi1Vec)>0, phi1Vec = phi1Vec/norm(phi1Vec); end
kappa1 = fillmissing(interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT,'linear',NaN),'linear','EndValues','nearest');
kappa2 = fillmissing(interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT,'linear',NaN),'linear','EndValues','nearest');
validMap = isfinite(Smap) & isfinite(Bmap);
cdfAxis = mean(Cmap,1,'omitnan');
tailMask = cdfAxis >= 0.80;
if ~any(tailMask), tailMask = false(1,nI); tailMask(max(nI-1,1):nI) = true; end
data = struct('allT',allT(:),'allI',allI(:),'Smap',Smap,'Bmap',Bmap,'Cmap',Cmap,'validMap',validMap, ...
    'cdfAxis',cdfAxis(:)','tailMask',logical(tailMask(:)'),'phi1Vec',phi1Vec(:),'kappa1',kappa1(:),'kappa2',kappa2(:));
end

function hierarchy = buildHierarchyPhi(data)
pred0 = data.Bmap;
pred1 = pred0 - data.kappa1(:)*data.phi1Vec(:)';
R1 = data.Smap - pred1;
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~,~,V1] = svd(R1z,'econ');
if isempty(V1)
    phi2 = zeros(numel(data.allI), 1);
else
    phi2 = V1(:, 1);
end
if norm(phi2)>0, phi2 = phi2/norm(phi2); end
pred2 = pred1 + data.kappa2(:)*phi2(:)';
R2 = data.Smap - pred2;
hierarchy = struct('pred0',pred0,'pred1',pred1,'pred2',pred2,'R1',R1,'R2',R2,'phi2Vec',phi2(:));
end

function tbl = buildObservableJoinPhi(obsTbl, hierarchy, data)
reqObs = {'T_K','S_peak','I_peak'};
for i = 1:numel(reqObs), assert(ismember(reqObs{i}, obsTbl.Properties.VariableNames)); end
midMask = data.cdfAxis > 0.40 & data.cdfAxis < 0.60;
if ~any(midMask), midMask = ismember(1:numel(data.allI), [3 4 5]); end
tailB2 = mean(hierarchy.R2(:, data.tailMask).^2, 2, 'omitnan') ./ max(mean(hierarchy.R2(:, midMask).^2, 2, 'omitnan'), eps);
J = table(data.allT(:), tailB2(:), 'VariableNames', {'T_K','tail_burden_after_phi2'});
O = groupsummary(obsTbl, 'T_K', 'mean', setdiff(obsTbl.Properties.VariableNames, {'T_K'}));
O.Properties.VariableNames = strrep(O.Properties.VariableNames, 'mean_', '');
tbl = outerjoin(J, O, 'Keys', 'T_K', 'MergeKeys', true);
tbl = sortrows(tbl, 'T_K');
end
