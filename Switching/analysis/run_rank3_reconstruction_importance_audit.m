%RUN_RANK3_RECONSTRUCTION_IMPORTANCE_AUDIT
% Canonical rank-3 reconstruction-importance audit (read-only on producer).
% Uses identity-locked successful switching_canonical artifacts only; same hierarchy
% as Stage E5 (diagnostic Phi3 = first right singular vector of R2, kappa3_diag = R2z*phi3).
% Does not invoke Phi2 replacement audit or modify canonical producers.

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'run_rank3_reconstruction_importance_audit';
transitionBandK = [28, 32];

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'rank3_reconstruction_importance_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Rank3 reconstruction importance audit initialized'}, false);

    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    if exist(idPath, 'file') ~= 2
        error('run_rank3_reconstruction_importance_audit:MissingIdentity', 'Missing %s', idPath);
    end
    if exist(ampPath, 'file') ~= 2
        error('run_rank3_reconstruction_importance_audit:MissingAmp', 'Missing %s', ampPath);
    end

    canonicalRunId = readCanonicalRunIdAudit(idPath);
    if strlength(canonicalRunId) == 0
        error('run_rank3_reconstruction_importance_audit:EmptyRunId', 'CANONICAL_RUN_ID empty in identity table.');
    end

    runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
    execPath = fullfile(runRoot, 'execution_status.csv');
    if exist(runRoot, 'dir') ~= 7
        error('run_rank3_reconstruction_importance_audit:MissingRunRoot', 'Canonical run directory missing: %s', runRoot);
    end
    execStatus = readLockedRunExecutionStatus(execPath);
    if execStatus ~= "SUCCESS"
        error('run_rank3_reconstruction_importance_audit:NotSuccessfulCanonical', ...
            'Canonical run %s execution status is %s (require SUCCESS). Path: %s', ...
            canonicalRunId, execStatus, execPath);
    end

    canonTables = fullfile(runRoot, 'tables');
    sLongPath = fullfile(canonTables, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(canonTables, 'switching_canonical_phi1.csv');
    reqCanon = {sLongPath, phi1Path, ampPath};
    for i = 1:numel(reqCanon)
        if exist(reqCanon{i}, 'file') ~= 2
            error('run_rank3_reconstruction_importance_audit:CanonicalMissing', 'Missing artifact: %s', reqCanon{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);

    data = buildCanonicalMapsAudit(sLong, phi1Tbl, ampTbl);
    hierarchy = buildHierarchyAudit(data);

    nT = size(data.Smap, 1);
    nI = size(data.Smap, 2);
    rowTrans = data.allT >= transitionBandK(1) & data.allT <= transitionBandK(2);
    maskFull = data.validMap;
    maskTrans = data.validMap & repmat(rowTrans, 1, nI);
    maskMain = data.validMap & ~repmat(rowTrans, 1, nI);
    maskTail = data.validMap & repmat(data.tailMask(:)', nT, 1);

    regionDefs = struct( ...
        'name', {'full'; 'transition_T_28_32K'; 'main_excl_transition_T_28_32K'; 'high_current_tail_cdf_ge_0p80'}, ...
        'mask', {maskFull; maskTrans; maskMain; maskTail}, ...
        'detail', { ...
        string('All valid (T,I) cells on the canonical aggregated map.'); ...
        string(sprintf('Temperature band %.1f–%.1f K (inclusive), all currents.', transitionBandK(1), transitionBandK(2))); ...
        string('Valid cells with T outside the transition band.'); ...
        string('Tail currents: mean CDF_pt >= 0.80 (Stage E5 convention), all temperatures.')});

    models = struct('label', {'backbone'; 'backbone_phi1'; 'backbone_phi1_phi2'; 'backbone_phi1_phi2_phi3_diag'}, ...
        'pred', {hierarchy.pred0; hierarchy.pred1; hierarchy.pred2; hierarchy.pred3});

    rowsH = table();
    prevPred = [];
    for im = 1:numel(models)
        pred = models(im).pred;
        for ir = 1:numel(regionDefs)
            m = computeGridMetricAudit(data.Smap, hierarchy.pred0, pred, prevPred, regionDefs(ir).mask);
            rowsH = [rowsH; table( ...
                string(regionDefs(ir).name), string(models(im).label), m.nPoints, m.rmseGlobal, m.meanRowRmse, m.residualEnergy, ...
                m.residualEnergyFractionVsBackbone, m.incrementalGain, m.incrementalGainFraction, m.varianceExplainedVsBackbone, ...
                regionDefs(ir).detail, ...
                repmat(string(canonicalRunId), 1, 1), ...
                'VariableNames', {'domain_name','model_label','n_points','rmse_global','mean_row_rmse','residual_energy', ...
                'residual_energy_fraction_vs_backbone','incremental_rmse_gain_vs_prev','incremental_rmse_gain_vs_prev_fraction', ...
                'variance_explained_vs_backbone','detail','canonical_run_id'})]; %#ok<AGROW>
        end
        prevPred = pred;
    end
    switchingWriteTableBothPaths(rowsH, repoRoot, runTables, 'rank3_reconstruction_hierarchy.csv');

    rowsG = buildGainByRegionTable(regionDefs, models, data, hierarchy, canonicalRunId);
    switchingWriteTableBothPaths(rowsG, repoRoot, runTables, 'rank3_reconstruction_gain_by_region.csv');

    rowsI = buildPhi2InterferenceTable(data, hierarchy, regionDefs, canonicalRunId);
    switchingWriteTableBothPaths(rowsI, repoRoot, runTables, 'rank3_phi2_interference_check.csv');

    v = computeVerdictsAudit(rowsH, rowsG, rowsI);

    statusTbl = table( ...
        ["AUDIT_COMPLETED";"CANONICAL_RUN_ID";"EXECUTION_STATUS_GATE"; ...
         "RANK3_IMPROVES_RECONSTRUCTION";"RANK3_GAIN_TRANSITION_LOCALIZED";"RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT"; ...
         "RANK3_CHANGES_PHI2_INTERPRETATION";"RANK3_SHOULD_REMAIN_DIAGNOSTIC"], ...
        ["YES"; string(canonicalRunId); string(execStatus); ...
         v.RANK3_IMPROVES_RECONSTRUCTION; v.RANK3_GAIN_TRANSITION_LOCALIZED; v.RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT; ...
         v.RANK3_CHANGES_PHI2_INTERPRETATION; v.RANK3_SHOULD_REMAIN_DIAGNOSTIC], ...
        ["Rank-3 reconstruction importance audit completed."; ...
         "Identity-locked canonical run."; ...
         "Required SUCCESS on locked switching_canonical execution_status."; ...
         v.detail_improves; v.detail_transition_loc; v.detail_main; v.detail_phi2; ...
         "Per project boundary: rank-3 stays diagnostic only; this audit does not promote it."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'rank3_reconstruction_importance_status.csv');

    lines = buildReportMarkdownAudit(canonicalRunId, execPath, transitionBandK, rowsH, rowsG, rowsI, v);
    switchingWriteTextLinesFile(fullfile(runReports, 'rank3_reconstruction_importance_audit.md'), lines, 'run_rank3_reconstruction_importance_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'rank3_reconstruction_importance_audit.md'), lines, 'run_rank3_reconstruction_importance_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(rowsH), {'Rank3 reconstruction importance audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_rank3_reconstruction_importance_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    failLines = {'# Rank-3 reconstruction importance audit FAILED', '', sprintf('- `%s`', ME.identifier), sprintf('- %s', ME.message)};
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', 'rank3_reconstruction_importance_audit.md'), failLines, 'run_rank3_reconstruction_importance_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'rank3_reconstruction_importance_audit.md'), failLines, 'run_rank3_reconstruction_importance_audit:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Rank3 reconstruction importance audit failed'}, true);
    rethrow(ME);
end

%% --- Local helpers ---

function st = readLockedRunExecutionStatus(execPath)
st = "UNKNOWN";
if exist(execPath, 'file') ~= 2
    return;
end
try
    T = readtable(execPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    vn = string(T.Properties.VariableNames);
    if any(vn == "EXECUTION_STATUS")
        st = upper(strtrim(T.EXECUTION_STATUS(1)));
        return;
    end
    if ismember('check', T.Properties.VariableNames) && ismember('result', T.Properties.VariableNames)
        idx = find(strcmpi(strip(string(T.check)), 'EXECUTION_STATUS'), 1, 'first');
        if ~isempty(idx)
            st = upper(strtrim(T.result(idx)));
            return;
        end
    end
    % Legacy wide row used on some locked switching_canonical runs (pre schema unify).
    if any(vn == "WRITE_SUCCESS") && any(vn == "EXECUTION_STARTED") && height(T) >= 1
        ws = upper(strtrim(T.WRITE_SUCCESS(1)));
        ex = upper(strtrim(T.EXECUTION_STARTED(1)));
        if ws == "YES" && ex == "YES"
            st = "SUCCESS";
        end
        return;
    end
catch
    raw = readcell(execPath, 'Delimiter', ',');
    if size(raw, 1) >= 2 && size(raw, 2) >= 2
        h = lower(strtrim(string(raw(1, 1))));
        if h == "execution_status"
            st = upper(strtrim(string(raw{2, 1})));
        elseif size(raw, 2) >= 2 && strcmpi(strip(string(raw{1, 1})), 'EXECUTION_STARTED')
            if strcmpi(strip(string(raw{2, 1})), 'YES') && strcmpi(strip(string(raw{2, 2})), 'YES')
                st = "SUCCESS";
            end
        end
    end
end
end

function runId = readCanonicalRunIdAudit(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
runId = "";
for r = 2:size(raw, 1)
    key = strip(string(raw{r, 1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        runId = strip(string(raw{r, 2}));
        return;
    end
end
end

function data = buildCanonicalMapsAudit(sLong, phi1Tbl, ampTbl)
% Identical construction to Stage E5 / rank3_physical_classification_audit locals.
reqS = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'CDF_pt'};
for i = 1:numel(reqS)
    if ~ismember(reqS{i}, sLong.Properties.VariableNames)
        error('run_rank3_reconstruction_importance_audit:BadSLongSchema', 'switching_canonical_S_long.csv missing %s', reqS{i});
    end
end
reqP = {'current_mA', 'Phi1'};
for i = 1:numel(reqP)
    if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
        error('run_rank3_reconstruction_importance_audit:BadPhi1Schema', 'switching_canonical_phi1.csv missing %s', reqP{i});
    end
end
reqA = {'T_K', 'kappa1', 'kappa2'};
for i = 1:numel(reqA)
    if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
        error('run_rank3_reconstruction_importance_audit:BadAmpSchema', 'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
    end
end

T = double(sLong.T_K);
I = double(sLong.current_mA);
S = double(sLong.S_percent);
B = double(sLong.S_model_pt_percent);
C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
G = groupsummary(table(T(v), I(v), S(v), B(v), C(v)), {'Var1', 'Var2'}, 'mean', {'Var3', 'Var4', 'Var5'});

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
    regimeTbl = ampTbl(:, {'T_K', 'regime_label'});
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
    transitionTbl = ampTbl(:, {'T_K', 'transition_flag'});
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
    tailMask(max(nI - 1, 1):nI) = true;
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

function hierarchy = buildHierarchyAudit(data)
pred0 = data.Bmap;
pred1 = pred0 - data.kappa1(:) * data.phi1Vec(:)';
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
[~, ~, V2] = svd(R2z, 'econ');
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

hierarchy = struct();
hierarchy.pred0 = pred0;
hierarchy.pred1 = pred1;
hierarchy.pred2 = pred2;
hierarchy.pred3 = pred3;
hierarchy.R2 = R2;
hierarchy.R2z = R2z;
hierarchy.phi2Vec = phi2(:);
hierarchy.phi3Vec = phi3(:);
hierarchy.kappa3Diag = kappa3Diag(:);
end

function metric = computeGridMetricAudit(Smap, backbonePred, pred, prevPred, gridMask)
mask = gridMask & isfinite(Smap) & isfinite(pred);
residual = Smap - pred;
residual0 = Smap - backbonePred;
nPoints = sum(mask(:));
if nPoints == 0
    metric = struct('nPoints', 0, 'rmseGlobal', NaN, 'meanRowRmse', NaN, 'residualEnergy', NaN, ...
        'residualEnergyFractionVsBackbone', NaN, 'incrementalGain', NaN, 'incrementalGainFraction', NaN, ...
        'varianceExplainedVsBackbone', NaN);
    return;
end
err = residual(mask);
err0 = residual0(mask);
rmseGlobal = sqrt(mean(err .^ 2, 'omitnan'));
residualEnergy = sum(err .^ 2, 'omitnan');
backboneEnergy = sum(err0 .^ 2, 'omitnan');
if backboneEnergy <= 0
    backboneEnergy = eps;
end
rowRmse = rowRmseOnMaskAudit(residual, mask);
meanRowRmse = mean(rowRmse, 'omitnan');
if isempty(prevPred)
    incrementalGain = NaN;
    incrementalGainFraction = NaN;
else
    prevErr = Smap - prevPred;
    prevRmse = sqrt(mean(prevErr(mask) .^ 2, 'omitnan'));
    incrementalGain = prevRmse - rmseGlobal;
    if prevRmse > 0
        incrementalGainFraction = incrementalGain / prevRmse;
    else
        incrementalGainFraction = NaN;
    end
end
metric = struct();
metric.nPoints = nPoints;
metric.rmseGlobal = rmseGlobal;
metric.meanRowRmse = meanRowRmse;
metric.residualEnergy = residualEnergy;
metric.residualEnergyFractionVsBackbone = residualEnergy / backboneEnergy;
metric.incrementalGain = incrementalGain;
metric.incrementalGainFraction = incrementalGainFraction;
metric.varianceExplainedVsBackbone = 1 - residualEnergy / backboneEnergy;
end

function rowRmse = rowRmseOnMaskAudit(residual, mask)
rowRmse = NaN(size(residual, 1), 1);
for it = 1:size(residual, 1)
    m = mask(it, :);
    if any(m)
        vals = residual(it, m);
        rowRmse(it) = sqrt(mean(vals .^ 2, 'omitnan'));
    end
end
end

function tbl = buildGainByRegionTable(regionDefs, models, data, hierarchy, canonicalRunId)
labels = {models.label};
preds = {models.pred};
tbl = table();
for ir = 1:numel(regionDefs)
    g = regionDefs(ir).mask;
    rms = zeros(1, numel(preds));
    for k = 1:numel(preds)
        m = computeGridMetricAudit(data.Smap, hierarchy.pred0, preds{k}, [], g);
        rms(k) = m.rmseGlobal;
    end
    sse0 = sum((data.Smap(g) - hierarchy.pred0(g)) .^ 2, 'omitnan');
    sse2 = sum((data.Smap(g) - hierarchy.pred2(g)) .^ 2, 'omitnan');
    sse3 = sum((data.Smap(g) - hierarchy.pred3(g)) .^ 2, 'omitnan');
    dTransPhi3 = sse2 - sse3;
    fracPhi3OnPhi2 = dTransPhi3 / max(sse2, eps);

    row = table( ...
        string(regionDefs(ir).name), rms(1), rms(2), rms(3), rms(4), ...
        rms(1) - rms(2), rms(2) - rms(3), rms(3) - rms(4), ...
        switchingSafeFraction(rms(1) - rms(2), rms(1)), ...
        switchingSafeFraction(rms(2) - rms(3), rms(2)), ...
        switchingSafeFraction(rms(3) - rms(4), rms(3)), ...
        sse0, sse2, sse3, dTransPhi3, fracPhi3OnPhi2, ...
        regionDefs(ir).detail, string(canonicalRunId), ...
        'VariableNames', {'region_name', ...
        'rmse_backbone', 'rmse_backbone_phi1', 'rmse_backbone_phi1_phi2', 'rmse_backbone_phi1_phi2_phi3_diag', ...
        'rmse_drop_phi1_vs_backbone', 'rmse_drop_phi2_vs_phi1', 'rmse_drop_phi3_diag_vs_phi2', ...
        'fractional_rmse_drop_phi1_vs_backbone', 'fractional_rmse_drop_phi2_vs_phi1', 'fractional_rmse_drop_phi3_vs_phi2', ...
        'sse_vs_backbone', 'sse_after_phi2', 'sse_after_phi3_diag', 'sse_reduction_phi3', 'sse_reduction_phi3_fraction_of_sse_after_phi2', ...
        'detail', 'canonical_run_id'});
    tbl = [tbl; row]; %#ok<AGROW>
end
% attach labels for model column names reference
tbl.model_order = repmat(string(strjoin(string(labels), '|')), height(tbl), 1);
end

function tbl = buildPhi2InterferenceTable(data, hierarchy, regionDefs, canonicalRunId)
phi2 = hierarchy.phi2Vec(:);
phi3 = hierarchy.phi3Vec(:);
cos23 = abs(dot(phi2, phi3)) / max(norm(phi2) * norm(phi3), eps);
k2 = double(data.kappa2(:));
k3 = double(hierarchy.kappa3Diag(:));
rho23 = corr(k2, k3, 'Type', 'Spearman', 'Rows', 'complete');

% Share of Phi3 squared-error reduction allocated to transition vs main (fixed region order).
gF = regionDefs(1).mask;
gT = regionDefs(2).mask;
gM = regionDefs(3).mask;
sse2f = sum((data.Smap(gF) - hierarchy.pred2(gF)) .^ 2, 'omitnan');
sse3f = sum((data.Smap(gF) - hierarchy.pred3(gF)) .^ 2, 'omitnan');
dFull = sse2f - sse3f;
sse2t = sum((data.Smap(gT) - hierarchy.pred2(gT)) .^ 2, 'omitnan');
sse3t = sum((data.Smap(gT) - hierarchy.pred3(gT)) .^ 2, 'omitnan');
dT = sse2t - sse3t;
sse2m = sum((data.Smap(gM) - hierarchy.pred2(gM)) .^ 2, 'omitnan');
sse3m = sum((data.Smap(gM) - hierarchy.pred3(gM)) .^ 2, 'omitnan');
dM = sse2m - sse3m;
shareTrans = dT / max(dT + dM, eps);

% R2 parallel to phi2 vs phi3 direction energy fraction on full map
R2 = hierarchy.R2;
g = data.validMap;
fracParallelPhi2 = NaN;
fracParallelPhi3 = NaN;
if any(g(:))
    P2 = (R2 * phi2) * phi2';
    P3 = (R2 * phi3) * phi3';
    denom = sum(R2(g) .^ 2, 'omitnan');
    if denom > 0
        fracParallelPhi2 = sum(P2(g) .^ 2, 'omitnan') / denom;
        fracParallelPhi3 = sum(P3(g) .^ 2, 'omitnan') / denom;
    end
end

rows = [ ...
    table(string("abs_cos_phi2_phi3"), cos23, string("|dot(unit phi2, unit phi3)| on full current grid."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("spearman_rho_kappa2_vs_kappa3_diag"), rho23, string("Temperature Spearman between producer kappa2 and diagnostic kappa3_diag."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("phi3_sse_reduction_share_transition_of_transition_plus_main"), shareTrans, string("(SSE2-SSE3)_trans / ((SSE2-SSE3)_trans + (SSE2-SSE3)_main) on valid cells."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("phi3_sse_reduction_transition"), dT, string("SSE after Phi2 minus SSE after Phi3 in transition band."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("phi3_sse_reduction_main_excl_transition"), dM, string("SSE after Phi2 minus SSE after Phi3 outside transition band."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("phi3_sse_reduction_full_map"), dFull, string("SSE after Phi2 minus SSE after Phi3 on all valid cells."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("rank2_energy_fraction_parallel_phi2_current_mode"), fracParallelPhi2, string("Fraction of sum(R2.^2) captured by rank-1 column-space projector along phi2 (diagnostic)."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'}); ...
    table(string("rank2_energy_fraction_parallel_phi3_current_mode"), fracParallelPhi3, string("Fraction of sum(R2.^2) captured by rank-1 column-space projector along phi3 (same as mode-1 fraction)."), string(canonicalRunId), 'VariableNames', {'metric','value','detail','canonical_run_id'})];
tbl = rows;
end

function v = computeVerdictsAudit(rowsH, rowsG, rowsI)
v = struct();
pick = @(dom, lbl) rowsH(strcmpi(string(rowsH.domain_name), string(dom)) & strcmpi(string(rowsH.model_label), string(lbl)), :);

f3 = pick("full", "backbone_phi1_phi2_phi3_diag").incremental_rmse_gain_vs_prev_fraction;
if isempty(f3) || ~isfinite(f3(1))
    f3v = 0;
else
    f3v = f3(1);
end
if f3v >= 0.10
    v.RANK3_IMPROVES_RECONSTRUCTION = "YES";
    v.detail_improves = sprintf("Full-map Phi3 incremental RMSE gain fraction vs Phi2 layer = %.4f (>=0.10).", f3v);
elseif f3v >= 0.02
    v.RANK3_IMPROVES_RECONSTRUCTION = "PARTIAL";
    v.detail_improves = sprintf("Full-map Phi3 incremental RMSE gain fraction = %.4f (between 0.02 and 0.10).", f3v);
else
    v.RANK3_IMPROVES_RECONSTRUCTION = "NO";
    v.detail_improves = sprintf("Full-map Phi3 incremental RMSE gain fraction = %.4f (<0.02, negligible).", f3v);
end

gT = rowsG(strcmpi(string(rowsG.region_name), "transition_T_28_32K"), :);
gM = rowsG(strcmpi(string(rowsG.region_name), "main_excl_transition_T_28_32K"), :);
if isempty(gT) || isempty(gM)
    dT = NaN;
    dM = NaN;
else
    dT = gT.sse_reduction_phi3(1);
    dM = gM.sse_reduction_phi3(1);
end
den = dT + dM;
if den > 0
    share = dT / den;
else
    share = NaN;
end
if isfinite(share) && share >= 0.65 && dT > 0
    v.RANK3_GAIN_TRANSITION_LOCALIZED = "YES";
    v.detail_transition_loc = sprintf("Fraction of Phi3 SSE reduction in transition vs (transition+main) = %.3f.", share);
elseif isfinite(share) && share >= 0.40
    v.RANK3_GAIN_TRANSITION_LOCALIZED = "PARTIAL";
    v.detail_transition_loc = sprintf("Transition share of Phi3 SSE reduction = %.3f (mixed localization).", share);
else
    v.RANK3_GAIN_TRANSITION_LOCALIZED = "NO";
    v.detail_transition_loc = sprintf("Transition share of Phi3 SSE reduction = %.3f (not dominated by transition band).", share);
end

gMain = rowsH(strcmpi(string(rowsH.domain_name), "main_excl_transition_T_28_32K") & strcmpi(string(rowsH.model_label), "backbone_phi1_phi2_phi3_diag"), :);
gMain2 = rowsH(strcmpi(string(rowsH.domain_name), "main_excl_transition_T_28_32K") & strcmpi(string(rowsH.model_label), "backbone_phi1_phi2"), :);
if isempty(gMain) || isempty(gMain2)
    fm = NaN;
else
    prevRmse = gMain2.rmse_global(1);
    newRmse = gMain.rmse_global(1);
    if prevRmse > 0
        fm = (prevRmse - newRmse) / prevRmse;
    else
        fm = NaN;
    end
end
if isfinite(fm) && fm >= 0.10
    v.RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT = "YES";
    v.detail_main = sprintf("Main-domain (excl. transition) Phi3 fractional RMSE gain vs Phi2 layer = %.4f (>=0.10, material).", fm);
elseif isfinite(fm) && fm >= 0.02
    v.RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT = "PARTIAL";
    v.detail_main = sprintf("Main-domain Phi3 fractional RMSE gain = %.4f (between 0.02 and 0.10; modest vs transition band).", fm);
else
    v.RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT = "NO";
    v.detail_main = sprintf("Main-domain Phi3 fractional RMSE gain = %.4f (negligible).", fm);
end

cosRow = rowsI(strcmpi(string(rowsI.metric), "abs_cos_phi2_phi3"), :);
rhoRow = rowsI(strcmpi(string(rowsI.metric), "spearman_rho_kappa2_vs_kappa3_diag"), :);
cosv = 0;
rhov = NaN;
if ~isempty(cosRow), cosv = cosRow.value(1); end
if ~isempty(rhoRow), rhov = rhoRow.value(1); end
if (isfinite(cosv) && cosv > 0.50) || (isfinite(rhov) && abs(rhov) > 0.55)
    v.RANK3_CHANGES_PHI2_INTERPRETATION = "YES";
    v.detail_phi2 = sprintf("Phi2–Phi3 current alignment or kappa2–kappa3_diag coupling is high (|cos|=%.4f, Spearman=%.4f); re-read Phi2/kappa2 jointly with caution.", cosv, rhov);
elseif (isfinite(cosv) && cosv > 0.30) || (isfinite(rhov) && abs(rhov) > 0.35)
    v.RANK3_CHANGES_PHI2_INTERPRETATION = "PARTIAL";
    v.detail_phi2 = sprintf("Moderate geometric or amplitude coupling (|cos|=%.4f, Spearman=%.4f); Phi3 mostly residual but not fully orthogonal.", cosv, rhov);
else
    v.RANK3_CHANGES_PHI2_INTERPRETATION = "NO";
    v.detail_phi2 = sprintf("Low |cos| between Phi2 and Phi3 and weak kappa2–kappa3_diag Spearman (|cos|=%.4f, Spearman=%.4f); Phi3 reads as transition/residual layer without redefining Phi2.", cosv, rhov);
end
v.RANK3_SHOULD_REMAIN_DIAGNOSTIC = "YES";
end

function lines = buildReportMarkdownAudit(canonicalRunId, execPath, transitionBandK, rowsH, rowsG, rowsI, v)
lines = {};
lines{end+1} = '# Rank-3 reconstruction importance audit';
lines{end+1} = '';
lines{end+1} = sprintf('- **CANONICAL_RUN_ID:** `%s`', canonicalRunId);
lines{end+1} = sprintf('- **Execution gate:** `SUCCESS` required at `%s`', execPath);
lines{end+1} = '- If the five-column `EXECUTION_STATUS` row is absent, locked runs may still gate as **SUCCESS** when `EXECUTION_STARTED=YES` and `WRITE_SUCCESS=YES` (legacy wide row).';
lines{end+1} = sprintf('- **Transition band (rows):** %.1f–%.1f K inclusive.', transitionBandK(1), transitionBandK(2));
lines{end+1} = '- **Hierarchy:** backbone (S_model_pt); +Phi1 (`pred = backbone - kappa1*Phi1`); +Phi2 (SVD mode-1 of R1 with producer `kappa2`); +diagnostic Phi3 (SVD mode-1 of R2 with LS `kappa3_diag = R2z*phi3`). Same as Stage E5.';
lines{end+1} = '- **Phi2 replacement audit:** not used.';
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/rank3_reconstruction_hierarchy.csv`';
lines{end+1} = '- `tables/rank3_reconstruction_gain_by_region.csv`';
lines{end+1} = '- `tables/rank3_phi2_interference_check.csv`';
lines{end+1} = '- `tables/rank3_reconstruction_importance_status.csv`';
lines{end+1} = '';
lines{end+1} = '## RMSE snapshot (full map)';
lines{end+1} = localMdRmseBlock(rowsH, "full");
lines{end+1} = '';
lines{end+1} = '## RMSE snapshot (transition 28–32 K)';
lines{end+1} = localMdRmseBlock(rowsH, "transition_T_28_32K");
lines{end+1} = '';
lines{end+1} = '## Gain by region (Phi3 vs Phi2)';
lines{end+1} = localMdGainBlock(rowsG);
lines{end+1} = '';
lines{end+1} = '## Phi2 / Phi3 interference scalars';
lines{end+1} = localMdInterferenceBlock(rowsI);
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- **RANK3_IMPROVES_RECONSTRUCTION:** %s', v.RANK3_IMPROVES_RECONSTRUCTION);
lines{end+1} = sprintf('- **RANK3_GAIN_TRANSITION_LOCALIZED:** %s', v.RANK3_GAIN_TRANSITION_LOCALIZED);
lines{end+1} = sprintf('- **RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT:** %s', v.RANK3_GAIN_MAIN_DOMAIN_SIGNIFICANT);
lines{end+1} = sprintf('- **RANK3_CHANGES_PHI2_INTERPRETATION:** %s', v.RANK3_CHANGES_PHI2_INTERPRETATION);
lines{end+1} = sprintf('- **RANK3_SHOULD_REMAIN_DIAGNOSTIC:** %s', v.RANK3_SHOULD_REMAIN_DIAGNOSTIC);
lines{end+1} = '';
lines{end+1} = '### Rationale';
lines{end+1} = ['- ', char(v.detail_improves)];
lines{end+1} = ['- ', char(v.detail_transition_loc)];
lines{end+1} = ['- ', char(v.detail_main)];
lines{end+1} = ['- ', char(v.detail_phi2)];
end

function blk = localMdRmseBlock(rowsH, dom)
m = rowsH(strcmpi(string(rowsH.domain_name), string(dom)), {'model_label', 'rmse_global', 'incremental_rmse_gain_vs_prev_fraction'});
blk = '';
for i = 1:height(m)
    g = m.incremental_rmse_gain_vs_prev_fraction(i);
    if ismissing(g) || ~isfinite(g)
        gf = '—';
    else
        gf = sprintf('%.4f', g);
    end
    blk = [blk, sprintf('- `%s`: RMSE=%.6g, incremental gain fraction vs prev=%s', m.model_label(i), m.rmse_global(i), gf), newline]; %#ok<AGROW>
end
if isempty(blk), blk = '- (no rows)'; end
blk = strip(blk);
end

function blk = localMdGainBlock(rowsG)
blk = '';
for i = 1:height(rowsG)
    blk = [blk, sprintf('- **%s:** frac RMSE drop (Phi3 vs Phi2)=%.5g; SSE reduction=%.5g; SSE red. / SSE(post-Phi2)=%.5g.', ...
        rowsG.region_name(i), rowsG.fractional_rmse_drop_phi3_vs_phi2(i), rowsG.sse_reduction_phi3(i), rowsG.sse_reduction_phi3_fraction_of_sse_after_phi2(i)), newline]; %#ok<AGROW>
end
if isempty(blk), blk = '- (empty)'; end
blk = strip(blk);
end

function blk = localMdInterferenceBlock(rowsI)
blk = '';
for i = 1:height(rowsI)
    blk = [blk, sprintf('- `%s` = %.6g', rowsI.metric(i), rowsI.value(i)), newline]; %#ok<AGROW>
end
blk = strip(blk);
end
