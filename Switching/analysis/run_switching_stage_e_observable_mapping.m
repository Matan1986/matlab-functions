clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_stage_e_observable_mapping';

% Required flags defaults
fStageECompleted = 'NO';
fKappa1Found = 'NO';
fKappa1Speak = 'NO';
fKappa2Found = 'NO';
fKappa2Tail = 'NO';
fPhi1Sig = 'NO';
fPhi2Sig = 'NO';
fReadyClaims = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_stage_e_observable_mapping';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Stage E mapping initialized'}, false);

    % Stage-E gate + D4 completion checks.
    gatePath = fullfile(repoRoot, 'tables', 'switching_pre_stage_e_gate_review.csv');
    d4Path = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    obsPath = '';
    req = {gatePath, d4Path, idPath, ampPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_stage_e_observable_mapping:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    g = readKeyValueCsv(gatePath);
    if getCheck(g, "READY_FOR_STAGE_E") ~= "YES" || getCheck(g, "STAGE_E_SCOPE_LOCKED") ~= "YES" || getCheck(g, "NONCANONICAL_KAPPA1_SHORTCUT_BLOCKED") ~= "YES"
        error('run_switching_stage_e_observable_mapping:GateBlocked', ...
            'Stage-E gate blocked by pre-stage-e review flags.');
    end
    d4 = readKeyValueCsv(d4Path);
    if getCheck(d4, "D4_COMPLETED") ~= "YES" || getCheck(d4, "READY_FOR_STAGE_E_FROM_D4") ~= "YES"
        error('run_switching_stage_e_observable_mapping:D4Blocked', ...
            'Stage-E blocked: D4 completion/readiness flags not satisfied.');
    end
    if getCheck(d4, "CLAIMS_UPDATE_ALLOWED") ~= "NO"
        error('run_switching_stage_e_observable_mapping:ClaimsPolicy', ...
            'Claims embargo violated: expected CLAIMS_UPDATE_ALLOWED=NO.');
    end

    % Identity-locked canonical inputs only.
    canonicalRunId = readCanonicalRunId(idPath);
    if strlength(canonicalRunId) == 0
        error('run_switching_stage_e_observable_mapping:Identity', 'CANONICAL_RUN_ID missing in identity table.');
    end
    sLongPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_S_long.csv');
    phi1Path = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_phi1.csv');
    obsPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_observables.csv');
    reqC = {sLongPath, phi1Path, obsPath};
    for i = 1:numel(reqC)
        if exist(reqC{i}, 'file') ~= 2
            error('run_switching_stage_e_observable_mapping:IdentityAnchorMissing', ...
                'Identity-anchored canonical artifact missing: %s', reqC{i});
        end
    end
    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    amp = readtable(ampPath);
    obs = readtable(obsPath);

    % Build canonical static candidate observables per temperature.
    % Tail burden from canonical S_long only (no dynamic/legacy input).
    T = double(sLong.T_K); I = double(sLong.current_mA);
    S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    G = groupsummary(table(T,I,S,B,C), {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(G.T), 'sorted');
    allI = unique(double(G.I), 'sorted');
    nT = numel(allT); nI = numel(allI);
    Smap = NaN(nT,nI); Bmap = NaN(nT,nI); Cmap = NaN(nT,nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(G.T)-allT(it)) < 1e-9 & abs(double(G.I)-allI(ii)) < 1e-9;
            if any(m)
                j = find(m,1);
                Smap(it,ii) = double(G.mean_S(j));
                Bmap(it,ii) = double(G.mean_B(j));
                Cmap(it,ii) = double(G.mean_C(j));
            end
        end
    end
    validMap = isfinite(Smap) & isfinite(Bmap) & isfinite(Cmap);
    cdfAxis = mean(Cmap,1,'omitnan');
    midMask = cdfAxis > 0.40 & cdfAxis < 0.60;
    tailMask = cdfAxis >= 0.80;
    R0 = Smap - Bmap;
    tailBurden = mean(R0(:,tailMask).^2,2,'omitnan') ./ max(mean(R0(:,midMask).^2,2,'omitnan'), eps);
    globalBurden = mean(R0.^2,2,'omitnan');
    peakResidual = max(abs(R0), [], 2, 'omitnan');

    % Join canonical observable table + amplitudes by T
    J = table(allT(:), tailBurden(:), globalBurden(:), peakResidual(:), ...
        'VariableNames', {'T_K','tail_burden_ratio','global_residual_energy','peak_residual_abs'});
    O = groupsummary(obs, 'T_K', 'mean', {'S_peak','I_peak','kappa1','rmse_pt_row','rmse_full_row','phi_cosine_row'});
    O.Properties.VariableNames = strrep(O.Properties.VariableNames, 'mean_', '');
    A = amp(:, {'T_K','kappa1','kappa2'});
    M = outerjoin(J, O(:, {'T_K','S_peak','I_peak','kappa1','rmse_pt_row','rmse_full_row','phi_cosine_row'}), 'Keys', 'T_K', 'MergeKeys', true);
    M = outerjoin(M, A, 'Keys', 'T_K', 'MergeKeys', true);
    M.Properties.VariableNames = matlab.lang.makeUniqueStrings(M.Properties.VariableNames);
    % normalize duplicate names
    if any(strcmp(M.Properties.VariableNames, 'kappa1_A'))
        M.kappa1 = M.kappa1_A;
    end
    if any(strcmp(M.Properties.VariableNames, 'kappa2_A'))
        M.kappa2 = M.kappa2_A;
    end
    if any(strcmp(M.Properties.VariableNames, 'kappa1_M'))
        M.kappa1_obs = M.kappa1_M;
    elseif any(strcmp(M.Properties.VariableNames, 'kappa1'))
        M.kappa1_obs = M.kappa1;
    else
        M.kappa1_obs = NaN(height(M),1);
    end
    M = sortrows(M, 'T_K');

    % Candidate mapping table.
    candRows = table();
    candRows = [candRows; buildCandidate("kappa1","S_peak", M.kappa1, M.S_peak, "canonical_observables", "YES")];
    candRows = [candRows; buildCandidate("kappa1","I_peak", M.kappa1, M.I_peak, "canonical_observables", "YES")];
    candRows = [candRows; buildCandidate("kappa1","rmse_full_row", M.kappa1, M.rmse_full_row, "canonical_observables", "YES")];
    candRows = [candRows; buildCandidate("kappa2","tail_burden_ratio", M.kappa2, M.tail_burden_ratio, "canonical_s_long_derived", "YES")];
    candRows = [candRows; buildCandidate("kappa2","global_residual_energy", M.kappa2, M.global_residual_energy, "canonical_s_long_derived", "YES")];
    candRows = [candRows; buildCandidate("kappa2","peak_residual_abs", M.kappa2, M.peak_residual_abs, "canonical_s_long_derived", "YES")];
    candRows = [candRows; buildCandidate("phi1_signature","tail_burden_ratio", abs(M.kappa1), M.tail_burden_ratio, "canonical_s_long_derived", "YES")];
    candRows = [candRows; buildCandidate("phi2_signature","tail_burden_ratio", abs(M.kappa2), M.tail_burden_ratio, "canonical_s_long_derived", "YES")];
    candRows = [candRows; buildCandidate("phi2_signature","global_residual_energy", abs(M.kappa2), M.global_residual_energy, "canonical_s_long_derived", "YES")];
    switchingWriteTableBothPaths(candRows, repoRoot, runTables, 'switching_stage_e_observable_mapping_candidates.csv');

    % Simple canonical static models (linear fits), no dynamics.
    modelRows = table();
    modelRows = [modelRows; buildModel("kappa1_from_S_peak", M.kappa1, M.S_peak)];
    modelRows = [modelRows; buildModel("kappa1_from_I_peak", M.kappa1, M.I_peak)];
    modelRows = [modelRows; buildModel("kappa2_from_tail_burden", M.kappa2, M.tail_burden_ratio)];
    modelRows = [modelRows; buildModel("kappa2_from_global_residual_energy", M.kappa2, M.global_residual_energy)];
    switchingWriteTableBothPaths(modelRows, repoRoot, runTables, 'switching_stage_e_observable_mapping_models.csv');

    % Flags from canonical-only evidence.
    cK1Speak = pickCorr(candRows, "kappa1", "S_peak");
    cK2Tail = pickCorr(candRows, "kappa2", "tail_burden_ratio");
    cPhi1Sig = pickCorr(candRows, "phi1_signature", "tail_burden_ratio");
    cPhi2Sig = pickCorr(candRows, "phi2_signature", "tail_burden_ratio");

    if any(candRows.target=="kappa1" & candRows.validity=="YES" & abs(candRows.spearman_r) >= 0.70)
        fKappa1Found = 'YES';
    elseif any(candRows.target=="kappa1" & candRows.validity=="YES" & abs(candRows.spearman_r) >= 0.50)
        fKappa1Found = 'PARTIAL';
    else
        fKappa1Found = 'NO';
    end
    if abs(cK1Speak) >= 0.85
        fKappa1Speak = 'YES';
    elseif abs(cK1Speak) >= 0.70
        fKappa1Speak = 'PARTIAL';
    else
        fKappa1Speak = 'NO';
    end

    if any(candRows.target=="kappa2" & candRows.validity=="YES" & abs(candRows.spearman_r) >= 0.60)
        fKappa2Found = 'YES';
    elseif any(candRows.target=="kappa2" & candRows.validity=="YES" & abs(candRows.spearman_r) >= 0.40)
        fKappa2Found = 'PARTIAL';
    else
        fKappa2Found = 'NO';
    end
    if abs(cK2Tail) >= 0.50
        fKappa2Tail = 'YES';
    elseif abs(cK2Tail) >= 0.35
        fKappa2Tail = 'PARTIAL';
    else
        fKappa2Tail = 'NO';
    end

    if abs(cPhi1Sig) >= 0.50
        fPhi1Sig = 'YES';
    elseif abs(cPhi1Sig) >= 0.35
        fPhi1Sig = 'PARTIAL';
    else
        fPhi1Sig = 'NO';
    end
    if abs(cPhi2Sig) >= 0.50
        fPhi2Sig = 'YES';
    elseif abs(cPhi2Sig) >= 0.35
        fPhi2Sig = 'PARTIAL';
    else
        fPhi2Sig = 'NO';
    end

    statusTbl = table( ...
        ["STAGE_E_COMPLETED";"KAPPA1_CANONICAL_OBSERVABLE_FOUND";"KAPPA1_SPEAK_REVALIDATED"; ...
         "KAPPA2_CANONICAL_OBSERVABLE_FOUND";"KAPPA2_TAIL_BURDEN_VALIDATED"; ...
         "PHI1_OBSERVABLE_SIGNATURE_FOUND";"PHI2_OBSERVABLE_SIGNATURE_FOUND"; ...
         "READY_FOR_CLAIMS_UPDATE";"CANONICAL_RUN_ID"], ...
        [string('YES');string(fKappa1Found);string(fKappa1Speak); ...
         string(fKappa2Found);string(fKappa2Tail);string(fPhi1Sig);string(fPhi2Sig); ...
         string('NO');string(canonicalRunId)], ...
        ["Stage E canonical static observable mapping completed."; ...
         "kappa1 mapping based on canonical static candidate correlations."; ...
         sprintf("kappa1 vs S_peak revalidation (canonical-only) spearman=%.4f", cK1Speak); ...
         "kappa2 mapping based on canonical static candidate correlations."; ...
         sprintf("kappa2 tail-burden validation (canonical-only) spearman=%.4f", cK2Tail); ...
         sprintf("Phi1 observable signature proxy (|kappa1| vs tail burden) spearman=%.4f", cPhi1Sig); ...
         sprintf("Phi2 observable signature proxy (|kappa2| vs tail burden) spearman=%.4f", cPhi2Sig); ...
         "Claims/context/snapshot/query updates remain forbidden."; ...
         "Identity-locked canonical run used."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_stage_e_observable_mapping_status.csv');

    lines = {};
    lines{end+1} = '# Stage E official canonical static observable mapping';
    lines{end+1} = '';
    lines{end+1} = sprintf('- Canonical lock: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    lines{end+1} = '- Scope: static canonical observables only (no dynamics, no producer changes).';
    lines{end+1} = '- Claims embargo: READY_FOR_CLAIMS_UPDATE=NO.';
    lines{end+1} = '';
    lines{end+1} = '## 1) kappa1 mapping';
    lines{end+1} = sprintf('- KAPPA1_CANONICAL_OBSERVABLE_FOUND = %s', fKappa1Found);
    lines{end+1} = sprintf('- KAPPA1_SPEAK_REVALIDATED = %s (spearman=%.4f)', fKappa1Speak, cK1Speak);
    lines{end+1} = '';
    lines{end+1} = '## 2) kappa2 mapping';
    lines{end+1} = sprintf('- KAPPA2_CANONICAL_OBSERVABLE_FOUND = %s', fKappa2Found);
    lines{end+1} = sprintf('- KAPPA2_TAIL_BURDEN_VALIDATED = %s (spearman=%.4f)', fKappa2Tail, cK2Tail);
    lines{end+1} = '';
    lines{end+1} = '## 3) Phi1/Phi2 observable signatures';
    lines{end+1} = sprintf('- PHI1_OBSERVABLE_SIGNATURE_FOUND = %s', fPhi1Sig);
    lines{end+1} = sprintf('- PHI2_OBSERVABLE_SIGNATURE_FOUND = %s', fPhi2Sig);
    lines{end+1} = '';
    lines{end+1} = '## 4) canonical vs rejected/noncanonical';
    lines{end+1} = '- Canonical used: locked run `switching_canonical_S_long.csv`, `switching_canonical_observables.csv`, `switching_mode_amplitudes_vs_T.csv`, D4 status/classification.';
    lines{end+1} = '- Rejected: legacy/noncanonical mapping artifacts; dynamic/aging/relaxation inputs; any untested kappa1 shortcut assumptions.';
    lines{end+1} = '- READY_FOR_CLAIMS_UPDATE = NO';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_stage_e_observable_mapping:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_stage_e_observable_mapping.md'), lines, 'run_switching_stage_e_observable_mapping:WriteFail');

    fStageECompleted = 'YES'; %#ok<NASGU>
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(candRows), {'Stage E observable mapping completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_stage_e_observable_mapping_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["STAGE_E_COMPLETED";"KAPPA1_CANONICAL_OBSERVABLE_FOUND";"KAPPA1_SPEAK_REVALIDATED"; ...
         "KAPPA2_CANONICAL_OBSERVABLE_FOUND";"KAPPA2_TAIL_BURDEN_VALIDATED"; ...
         "PHI1_OBSERVABLE_SIGNATURE_FOUND";"PHI2_OBSERVABLE_SIGNATURE_FOUND";"READY_FOR_CLAIMS_UPDATE"], ...
        ["NO";"NO";"NO";"NO";"NO";"NO";"NO";"NO"], ...
        repmat(string(ME.message), 8, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_stage_e_observable_mapping_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv'));

    lines = {};
    lines{end+1} = '# Stage E observable mapping — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_stage_e_observable_mapping:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_stage_e_observable_mapping.md'), lines, 'run_switching_stage_e_observable_mapping:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Stage E observable mapping failed'}, true);
    rethrow(ME);
end

function v = getCheck(tbl, key)
ck = string(tbl.check);
rv = string(tbl.result);
ckn = normalizeToken(ck);
keyn = normalizeToken(string(key));
idx = find(ckn == keyn, 1, 'first');
if isempty(idx)
    idx = find(contains(ckn, keyn) | contains(keyn, ckn), 1, 'first');
end
if isempty(idx), v = ""; else, v = upper(strtrim(rv(idx))); end
end

function t = normalizeToken(s)
t = upper(strtrim(string(s)));
t = regexprep(t, "^\xFEFF", "");
t = regexprep(t, "[^A-Z0-9_]+", "_");
t = regexprep(t, "_+", "_");
t = regexprep(t, "^_|_$", "");
end

function out = readKeyValueCsv(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
n = size(raw,1);
ck = strings(0,1); rv = strings(0,1);
for i = 2:n
    if size(raw,2) < 2, continue; end
    c1 = string(raw{i,1}); c2 = string(raw{i,2});
    c1 = strtrim(c1); c2 = strtrim(c2);
    if strlength(c1)==0, continue; end
    ck(end+1,1) = c1; %#ok<AGROW>
    rv(end+1,1) = c2; %#ok<AGROW>
end
out = table(ck, rv, 'VariableNames', {'check','result'});
end

function out = readCanonicalRunId(identityPath)
out = "";
idRaw = readcell(identityPath, 'Delimiter', ',');
for r = 2:size(idRaw,1)
    k = strtrim(string(idRaw{r,1}));
    k = regexprep(k, "^\xFEFF", "");
    if strcmpi(k, "CANONICAL_RUN_ID")
        out = strtrim(string(idRaw{r,2}));
        return;
    end
end
end

function row = buildCandidate(target, observable, x, y, sourceKind, canonicalOnly)
[pr, sr, n] = corrPair(x, y);
validity = "NO";
if n >= 5 && isfinite(pr) && isfinite(sr), validity = "YES"; end
row = table(string(target), string(observable), pr, sr, n, string(validity), string(sourceKind), string(canonicalOnly), ...
    'VariableNames', {'target','observable','pearson_r','spearman_r','n_points','validity','source_kind','canonical_only'});
end

function row = buildModel(modelName, y, x)
m = isfinite(x) & isfinite(y);
xx = x(m); yy = y(m);
n = numel(xx);
if n < 5
    row = table(string(modelName), string("linear"), NaN, NaN, NaN, NaN, n, string("INSUFFICIENT_POINTS"), ...
        'VariableNames', {'model_name','model_type','beta0','beta1','r2','rmse','n_points','model_status'});
    return;
end
X = [ones(n,1), xx(:)];
b = X \ yy(:);
yhat = X * b;
sse = sum((yy(:)-yhat).^2);
sst = sum((yy(:)-mean(yy)).^2);
r2 = 1 - sse / max(sst, eps);
rmse = sqrt(mean((yy(:)-yhat).^2));
row = table(string(modelName), string("linear"), b(1), b(2), r2, rmse, n, string("OK"), ...
    'VariableNames', {'model_name','model_type','beta0','beta1','r2','rmse','n_points','model_status'});
end

function c = pickCorr(tbl, target, observable)
m = tbl.target==target & tbl.observable==observable & tbl.validity=="YES";
if any(m), c = tbl.spearman_r(find(m,1,'first')); else, c = NaN; end
end

function [pr, sr, n] = corrPair(x, y)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
n = sum(m);
if n < 3
    pr = NaN; sr = NaN; return;
end
r = corrcoef(x(m), y(m)); pr = r(1,2);
sr = corr(x(m), y(m), 'Type', 'Spearman', 'Rows', 'complete');
end
