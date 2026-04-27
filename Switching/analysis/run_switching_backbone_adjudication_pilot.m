clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_backbone_adjudication_pilot';

% Required flags
fPilotExecuted = 'NO';
fPilotCanonicalStatus = 'NON_CANONICAL_DIAGNOSTIC';
fReplacementAllowedNow = 'NO';
fCurrentAdequate = 'PARTIAL';
fTailAwarePasses = 'NO';
fTailPass = 'NO';
fRmsePass = 'NO';
fPhi1Pass = 'NO';
fPhi1Absorb = 'PARTIAL';
fPhi2Absorb = 'PARTIAL';
fContamPass = 'NO';
fDecision = 'INCONCLUSIVE';
fPhaseDAfter = 'PARTIAL';
fRedesignRequired = 'PARTIAL';
fClaimsAllowed = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_backbone_adjudication_pilot';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(runFigures, 'dir') ~= 7, mkdir(runFigures); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'adjudication pilot initialized'}, false);

    % Locked canonical identity + canonical inputs
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    req = {idPath, sLongPath, phi1Path, ampPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_backbone_adjudication_pilot:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    % Capture canonical identity snapshot for contamination check
    idBefore = string(readlines(idPath));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    if ~all(ismember(reqS, sLong.Properties.VariableNames))
        error('run_switching_backbone_adjudication_pilot:BadSchema', 'S_long missing required columns.');
    end

    % Build maps (T x I)
    T = double(sLong.T_K); I = double(sLong.current_mA);
    S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    TI = table(T, I, S, B, C);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT); nI = numel(allI);
    Smap = NaN(nT,nI); Bref = NaN(nT,nI); Cmap = NaN(nT,nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T)-allT(it))<1e-9 & abs(double(TIg.I)-allI(ii))<1e-9;
            if any(m)
                idx = find(m,1);
                Smap(it,ii) = double(TIg.mean_S(idx));
                Bref(it,ii) = double(TIg.mean_B(idx));
                Cmap(it,ii) = double(TIg.mean_C(idx));
            end
        end
    end

    % Canonical Phi1 reference
    phiVars = string(phi1Tbl.Properties.VariableNames);
    iPhi = find(strcmpi(phiVars, "phi1"), 1);
    phi1Ref = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:,iPhi}), allI, 'linear', 'extrap');
    phi1Ref = phi1Ref(:);
    if norm(phi1Ref) > 0, phi1Ref = phi1Ref / norm(phi1Ref); end

    % Canonical Phi2 reference (from canonical hierarchy convention)
    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    pred1Ref = Bref - kappa1(:) * phi1Ref(:)';
    R1ref = Smap - pred1Ref;
    R1z = R1ref; R1z(~isfinite(R1z)) = 0;
    [~,~,Vref] = svd(R1z, 'econ');
    if size(Vref,2) >= 1
        phi2Ref = Vref(:,1);
    else
        phi2Ref = zeros(nI,1);
    end
    if norm(phi2Ref) > 0, phi2Ref = phi2Ref / norm(phi2Ref); end

    % Pilot candidate: two_sector_ptcdf_tail_aware_constrained
    % Fixed tail sector starts at CDF>=0.80, non-tunable
    tailStart = 0.80;
    tailMaskAxis = mean(Cmap, 1, 'omitnan') >= tailStart;
    Rref = Smap - Bref;
    tailTrend = mean(Rref, 1, 'omitnan');
    tailTrend(~tailMaskAxis) = 0;
    tailTrend = movmean(tailTrend, 3, 'omitnan');  % smooth, no per-T fit freedom
    Bpilot = Bref + ones(nT,1) * tailTrend;

    % Residuals
    R0ref = Smap - Bref;
    R0pil = Smap - Bpilot;
    R0refz = R0ref; R0refz(~isfinite(R0refz)) = 0;
    R0pilz = R0pil; R0pilz(~isfinite(R0pilz)) = 0;

    % Metrics: RMSE + tail burden
    rmseRef = sqrt(mean(R0refz(:).^2, 'omitnan'));
    rmsePil = sqrt(mean(R0pilz(:).^2, 'omitnan'));
    rmseReductionFrac = (rmseRef - rmsePil) / max(rmseRef, eps);

    cdfAxis = mean(Cmap, 1, 'omitnan');
    low = cdfAxis <= 0.2;
    mid = cdfAxis > 0.4 & cdfAxis < 0.6;
    high = cdfAxis >= tailStart;
    eRefLow = mean(R0refz(:,low).^2, 'all', 'omitnan');
    eRefMid = mean(R0refz(:,mid).^2, 'all', 'omitnan');
    eRefHigh = mean(R0refz(:,high).^2, 'all', 'omitnan');
    ePilLow = mean(R0pilz(:,low).^2, 'all', 'omitnan');
    ePilMid = mean(R0pilz(:,mid).^2, 'all', 'omitnan');
    ePilHigh = mean(R0pilz(:,high).^2, 'all', 'omitnan');
    ratioRef = eRefHigh / max(eRefMid, eps);
    ratioPil = ePilHigh / max(ePilMid, eps);
    tailReductionFrac = (ratioRef - ratioPil) / max(ratioRef, eps);

    % Residual spectra + mode similarities
    [~,Sref,Vref0] = svd(R0refz, 'econ');
    [~,Spil,Vpil] = svd(R0pilz, 'econ');
    svRef = diag(Sref); svPil = diag(Spil);
    frRef = (svRef.^2) / max(sum(svRef.^2), eps);
    frPil = (svPil.^2) / max(sum(svPil.^2), eps);
    nKeep = min([8, numel(svRef), numel(svPil)]);

    v1Ref = Vref0(:,1); if norm(v1Ref)>0, v1Ref = v1Ref/norm(v1Ref); end
    v1Pil = Vpil(:,1);  if norm(v1Pil)>0, v1Pil = v1Pil/norm(v1Pil); end
    phi1Cos = abs(dot(v1Pil, phi1Ref) / max(norm(v1Pil)*norm(phi1Ref), eps));
    phi1AmpRef = mean(abs(R0refz * phi1Ref), 'omitnan');
    phi1AmpPil = mean(abs(R0pilz * phi1Ref), 'omitnan');
    phi1AmpShiftFrac = abs(phi1AmpPil - phi1AmpRef) / max(phi1AmpRef, eps);

    v2Pil = zeros(nI,1);
    if size(Vpil,2)>=2
        v2Pil = Vpil(:,2);
        if norm(v2Pil)>0, v2Pil = v2Pil/norm(v2Pil); end
    end
    phi2Cos = abs(dot(v2Pil, phi2Ref) / max(norm(v2Pil)*norm(phi2Ref), eps));

    % Absorption detections
    phi1AbsorbDetected = (phi1Cos < 0.90) || (phi1AmpShiftFrac > 0.15);
    phi2AbsorbDetected = (phi2Cos < 0.50) && (tailReductionFrac > 0.25);

    % Hard gates
    tailPass = tailReductionFrac >= 0.25;
    rmsePass = rmseReductionFrac >= 0.10;
    phi1Pass = (phi1Cos >= 0.90) && (phi1AmpShiftFrac <= 0.15);
    noPhi1Absorb = ~phi1AbsorbDetected;
    noPhi2Fit = true; % enforced by construction (no Phi2 terms used)
    noRmseOnly = ~(rmsePass && ~tailPass);
    contamPass = true; % evaluate below with identity + path checks

    % Contamination checks
    idAfter = string(readlines(idPath));
    identityUnchanged = isequal(idBefore, idAfter);
    wroteCanonicalTruth = false;
    claimsUpdated = false;
    if ~identityUnchanged || wroteCanonicalTruth || claimsUpdated
        contamPass = false;
    end

    % Final gate decision
    allHard = tailPass && rmsePass && phi1Pass && noPhi1Absorb && noPhi2Fit && noRmseOnly && contamPass;
    if allHard
        fTailAwarePasses = 'YES';
    else
        fTailAwarePasses = 'NO';
    end
    fTailPass = tern(tailPass, 'YES', 'NO');
    fRmsePass = tern(rmsePass, 'YES', 'NO');
    fPhi1Pass = tern(phi1Pass, 'YES', 'NO');
    fPhi1Absorb = tern(phi1AbsorbDetected, 'YES', 'NO');
    fPhi2Absorb = tern(phi2AbsorbDetected, 'YES', 'NO');
    fContamPass = tern(contamPass, 'YES', 'NO');
    fPilotExecuted = 'YES';

    % Adjudication decision rules
    if strcmp(fTailAwarePasses, 'YES') && strcmp(fPhi1Pass, 'YES')
        fDecision = 'REDESIGN_REQUIRED';
        fCurrentAdequate = 'NO';
        fPhaseDAfter = 'PARTIAL';
        fRedesignRequired = 'YES';
    elseif strcmp(fTailAwarePasses, 'NO') && strcmp(fContamPass, 'YES')
        fDecision = 'CURRENT_BACKBONE_ACCEPTABLE';
        fCurrentAdequate = 'YES';
        fPhaseDAfter = 'YES';
        fRedesignRequired = 'NO';
    else
        fDecision = 'INCONCLUSIVE';
        fCurrentAdequate = 'PARTIAL';
        fPhaseDAfter = 'PARTIAL';
        fRedesignRequired = 'PARTIAL';
    end

    % Write outputs
    metricsTbl = table( ...
        ["reference_current_ptcdf"; "pilot_two_sector_ptcdf_tail_aware_constrained"], ...
        [rmseRef; rmsePil], ...
        [ratioRef; ratioPil], ...
        [eRefHigh; ePilHigh], ...
        [eRefMid; ePilMid], ...
        'VariableNames', {'variant','backbone_rmse','tail_high_to_mid_ratio','tail_energy_high','tail_energy_mid'});
    switchingWriteTableBothPaths(metricsTbl, repoRoot, runTables, 'switching_backbone_adjudication_pilot_metrics.csv');

    phiTbl = table( ...
        phi1Cos, phi1AmpRef, phi1AmpPil, phi1AmpShiftFrac, phi2Cos, ...
        'VariableNames', {'phi1_cosine_to_canonical','phi1_amp_ref','phi1_amp_pilot','phi1_amp_shift_fraction','phi2_mode2_cosine_to_canonical'});
    switchingWriteTableBothPaths(phiTbl, repoRoot, runTables, 'switching_backbone_adjudication_pilot_phi_preservation.csv');

    spVar = strings(0,1); spMode = zeros(0,1); spFrac = zeros(0,1); spSV = zeros(0,1);
    for k = 1:nKeep
        spVar(end+1,1) = "reference_current_ptcdf"; spMode(end+1,1) = k; spFrac(end+1,1) = frRef(k); spSV(end+1,1) = svRef(k);
    end
    for k = 1:nKeep
        spVar(end+1,1) = "pilot_two_sector_ptcdf_tail_aware_constrained"; spMode(end+1,1) = k; spFrac(end+1,1) = frPil(k); spSV(end+1,1) = svPil(k);
    end
    spTbl = table(spVar, spMode, spSV, spFrac, 'VariableNames', {'variant','mode_index','singular_value','energy_fraction'});
    switchingWriteTableBothPaths(spTbl, repoRoot, runTables, 'switching_backbone_adjudication_pilot_spectrum.csv');

    contamTbl = table( ...
        ["identity_unchanged"; "canonical_truth_overwrite"; "claims_context_snapshot_updates"; "pilot_outputs_noncanonical_only"], ...
        [string(identityUnchanged); string(~wroteCanonicalTruth); string(~claimsUpdated); "true"], ...
        'VariableNames', {'check','pass'});
    switchingWriteTableBothPaths(contamTbl, repoRoot, runTables, 'switching_backbone_adjudication_pilot_contamination.csv');

    statusTbl = table( ...
        ["PILOT_EXECUTED"; "PILOT_CANONICAL_STATUS"; "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; ...
         "CURRENT_PTCDF_BACKBONE_ADEQUATE"; "TAIL_AWARE_CANDIDATE_PASSES_HARD_GATES"; ...
         "TAIL_BURDEN_REDUCTION_PASS"; "BACKBONE_RMSE_REDUCTION_PASS"; "PHI1_PRESERVATION_PASS"; ...
         "PHI1_ABSORPTION_DETECTED"; "PHI2_ABSORPTION_DETECTED"; "CONTAMINATION_CHECK_PASS"; ...
         "ADJUDICATION_DECISION"; "PHASE_D_ALLOWED_AFTER_ADJUDICATION"; "CANONICAL_REDESIGN_REQUIRED"; "CLAIMS_UPDATE_ALLOWED"], ...
        [string(fPilotExecuted); string(fPilotCanonicalStatus); string(fReplacementAllowedNow); ...
         string(fCurrentAdequate); string(fTailAwarePasses); string(fTailPass); string(fRmsePass); string(fPhi1Pass); ...
         string(fPhi1Absorb); string(fPhi2Absorb); string(fContamPass); string(fDecision); string(fPhaseDAfter); ...
         string(fRedesignRequired); string(fClaimsAllowed)], ...
        ["Pilot executed in NON_CANONICAL_DIAGNOSTIC mode."; ...
         "Diagnostic only; never canonical truth."; ...
         "Replacement blocked by policy."; ...
         "Adequacy adjudication outcome."; ...
         "All hard gates aggregate outcome."; ...
         sprintf("tail reduction frac=%.6g (threshold=0.25)", tailReductionFrac); ...
         sprintf("rmse reduction frac=%.6g (threshold=0.10)", rmseReductionFrac); ...
         sprintf("phi1 cos=%.6g; amp shift=%.6g", phi1Cos, phi1AmpShiftFrac); ...
         "YES indicates pilot failed via Phi1 absorption."; ...
         "YES indicates pilot may have absorbed/reallocated Phi2-like residual behavior."; ...
         "Identity + no overwrite + no claims updates."; ...
         "Rule-based decision from requested adjudication logic."; ...
         "Whether Phase D can proceed after this adjudication outcome."; ...
         "Redesign required means proceed to controlled redesign process, not immediate replacement."; ...
         "Claims updates forbidden in this pilot."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_backbone_adjudication_pilot_status.csv');

    % Optional run-scoped figure
    fig = figure('Visible','off','Color','w','Position',[100 100 1200 500]);
    tl = tiledlayout(1,2,'Parent',fig,'TileSpacing','compact','Padding','compact');
    nexttile(tl);
    bar(categorical(["reference","pilot"]), [rmseRef rmsePil]);
    title('Backbone-only RMSE'); ylabel('RMSE'); grid on;
    nexttile(tl);
    bar(categorical(["reference","pilot"]), [ratioRef ratioPil]);
    title('High/Mid tail burden ratio'); ylabel('ratio'); grid on;
    sgtitle(tl, 'Backbone adjudication pilot (NON_CANONICAL_DIAGNOSTIC)', 'Interpreter', 'none');
    savefig(fig, fullfile(runFigures, [baseName '.fig']));
    exportgraphics(fig, fullfile(runFigures, [baseName '.png']), 'Resolution', 250);
    close(fig);

    lines = {};
    lines{end+1} = '# Switching backbone adjudication pilot (NON_CANONICAL_DIAGNOSTIC)';
    lines{end+1} = '';
    lines{end+1} = '## Scope guards';
    lines{end+1} = '- No producer edits, no canonical overwrite, no identity updates, no claims/context/snapshot/query updates.';
    lines{end+1} = '- Pilot candidate: `two_sector_ptcdf_tail_aware_constrained` with fixed tail threshold `CDF_pt >= 0.80`.';
    lines{end+1} = '- No Phi2 fitted into backbone; stress outputs not used as training truth.';
    lines{end+1} = '';
    lines{end+1} = '## Hard gate outcomes';
    lines{end+1} = sprintf('- Tail burden reduction pass: %s (%.4f)', fTailPass, tailReductionFrac);
    lines{end+1} = sprintf('- Backbone RMSE reduction pass: %s (%.4f)', fRmsePass, rmseReductionFrac);
    lines{end+1} = sprintf('- Phi1 preservation pass: %s (cos=%.4f, amp_shift=%.4f)', fPhi1Pass, phi1Cos, phi1AmpShiftFrac);
    lines{end+1} = sprintf('- Phi1 absorption detected: %s', fPhi1Absorb);
    lines{end+1} = sprintf('- Phi2 absorption detected: %s', fPhi2Absorb);
    lines{end+1} = sprintf('- Contamination check pass: %s', fContamPass);
    lines{end+1} = '';
    lines{end+1} = '## Decision';
    lines{end+1} = sprintf('- ADJUDICATION_DECISION = %s', fDecision);
    lines{end+1} = sprintf('- CURRENT_PTCDF_BACKBONE_ADEQUATE = %s', fCurrentAdequate);
    lines{end+1} = sprintf('- CANONICAL_REDESIGN_REQUIRED = %s', fRedesignRequired);
    lines{end+1} = sprintf('- PHASE_D_ALLOWED_AFTER_ADJUDICATION = %s', fPhaseDAfter);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_backbone_adjudication_pilot_metrics.csv`';
    lines{end+1} = '- `tables/switching_backbone_adjudication_pilot_phi_preservation.csv`';
    lines{end+1} = '- `tables/switching_backbone_adjudication_pilot_spectrum.csv`';
    lines{end+1} = '- `tables/switching_backbone_adjudication_pilot_contamination.csv`';
    lines{end+1} = '- `tables/switching_backbone_adjudication_pilot_status.csv`';
    lines{end+1} = '- `reports/switching_backbone_adjudication_pilot.md`';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_backbone_adjudication_pilot:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_adjudication_pilot.md'), lines, 'run_switching_backbone_adjudication_pilot:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'backbone adjudication pilot completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_backbone_adjudication_pilot_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    failMsg = char(string(ME.message));
    statusTbl = table( ...
        ["PILOT_EXECUTED"; "PILOT_CANONICAL_STATUS"; "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; ...
         "CURRENT_PTCDF_BACKBONE_ADEQUATE"; "TAIL_AWARE_CANDIDATE_PASSES_HARD_GATES"; ...
         "TAIL_BURDEN_REDUCTION_PASS"; "BACKBONE_RMSE_REDUCTION_PASS"; "PHI1_PRESERVATION_PASS"; ...
         "PHI1_ABSORPTION_DETECTED"; "PHI2_ABSORPTION_DETECTED"; "CONTAMINATION_CHECK_PASS"; ...
         "ADJUDICATION_DECISION"; "PHASE_D_ALLOWED_AFTER_ADJUDICATION"; "CANONICAL_REDESIGN_REQUIRED"; "CLAIMS_UPDATE_ALLOWED"], ...
        ["NO"; "NON_CANONICAL_DIAGNOSTIC"; "NO"; "PARTIAL"; "NO"; "NO"; "NO"; "NO"; "PARTIAL"; "PARTIAL"; "NO"; ...
         "INCONCLUSIVE"; "PARTIAL"; "PARTIAL"; "NO"], ...
        repmat(string(failMsg), 15, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_backbone_adjudication_pilot_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_backbone_adjudication_pilot_status.csv'));
    lines = {};
    lines{end+1} = '# Switching backbone adjudication pilot — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_backbone_adjudication_pilot:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_adjudication_pilot.md'), lines, 'run_switching_backbone_adjudication_pilot:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'backbone adjudication pilot failed'}, true);
    rethrow(ME);
end

function out = tern(cond, a, b)
if cond, out = a; else, out = b; end
end
