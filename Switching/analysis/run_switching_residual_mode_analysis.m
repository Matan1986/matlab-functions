clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_residual_mode_analysis';
    cfg.dataset = 'canonical_switching_tables_with_transition_table';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    transitionPath = fullfile(repoRoot, 'tables', 'switching_transition_detection.csv');
    transitionFound = exist(transitionPath, 'file') == 2;
    if ~transitionFound
        error('run_switching_residual_mode_analysis:MissingTransitionTable', ...
            'Missing transition table: %s', transitionPath);
    end
    tTbl = readtable(transitionPath);
    if ~ismember('T_K', tTbl.Properties.VariableNames) || ~ismember('transition_flag', tTbl.Properties.VariableNames)
        error('run_switching_residual_mode_analysis:TransitionSchema', ...
            'Transition table must include T_K and transition_flag.');
    end

    runsRoot = switchingCanonicalRunRoot(repoRoot);
    sCandidates = {};
    if exist(runsRoot, 'dir') == 7
        d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
        for i = 1:numel(d)
            tDir = fullfile(runsRoot, d(i).name, 'tables');
            sPath = fullfile(tDir, 'switching_canonical_S_long.csv');
            if exist(sPath, 'file') == 2
                sCandidates{end+1, 1} = sPath; %#ok<AGROW>
            end
        end
    end
    if isempty(sCandidates)
        error('run_switching_residual_mode_analysis:NoCanonicalInput', 'No canonical S_long tables found.');
    end
    [~, idxNewest] = max(cellfun(@(p) dir(p).datenum, sCandidates));
    sPath = sCandidates{idxNewest};
    canonRunDir = fileparts(fileparts(sPath));
    [~, canonicalSourceRunId, ~] = fileparts(canonRunDir);
    sTbl = readtable(sPath);

    req = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    for i = 1:numel(req)
        if ~ismember(req{i}, sTbl.Properties.VariableNames)
            error('run_switching_residual_mode_analysis:MissingColumn', 'S_long missing column: %s', req{i});
        end
    end

    TT = double(sTbl.T_K);
    II = double(sTbl.current_mA);
    SS = double(sTbl.S_percent);
    SP = double(sTbl.S_model_pt_percent);
    allT = sort(unique(TT(isfinite(TT))));
    allI = sort(unique(II(isfinite(II))));
    nT = numel(allT);
    nI = numel(allI);

    Smap = NaN(nT, nI);
    Scdf = NaN(nT, nI);
    for it = 1:nT
        mt = abs(TT - allT(it)) < 1e-9;
        for ii = 1:nI
            mi = abs(II - allI(ii)) < 1e-9;
            m = mt & mi;
            if any(m)
                Smap(it, ii) = mean(SS(m), 'omitnan');
                Scdf(it, ii) = mean(SP(m), 'omitnan');
            end
        end
    end
    R = Smap - Scdf;

    tFromTransition = double(tTbl.T_K);
    flagFromTransition = string(tTbl.transition_flag);
    [commonT, iaR, iaTr] = intersect(allT, tFromTransition, 'stable');
    if isempty(commonT)
        error('run_switching_residual_mode_analysis:NoOverlap', 'No overlapping temperatures between residual and transition table.');
    end

    R = R(iaR, :);
    allT = commonT(:);
    nT = numel(allT);
    trFlag = false(nT, 1);
    for i = 1:nT
        trFlag(i) = strcmpi(strtrim(char(flagFromTransition(iaTr(i)))), 'YES');
    end

    [regimeLabel, preMask, transMask, postMask, boundaryText] = deriveRegimes(allT, trFlag);

    missingRows = sum(all(~isnan(Smap), 2) == 0);
    excludedRows = numel(iaR) - nT;

    Rfill = R;
    Rfill(~isfinite(Rfill)) = 0;
    [U, Sdiag, V] = svd(Rfill, 'econ');
    svals = diag(Sdiag);
    if numel(svals) < 3
        svals(end+1:3) = 0; %#ok<AGROW>
    end
    totalEnergy = sum(diag(Sdiag).^2);
    if totalEnergy <= 0
        totalEnergy = eps;
    end
    rank1_energy_global = (svals(1)^2) / totalEnergy;
    rank2_increment_global = (svals(2)^2) / totalEnergy;
    cumulative_rank2_energy_global = ((svals(1)^2) + (svals(2)^2)) / totalEnergy;

    globalTbl = table(svals(1), svals(2), svals(3), rank1_energy_global, rank2_increment_global, cumulative_rank2_energy_global, ...
        'VariableNames', {'sigma1', 'sigma2', 'sigma3', 'rank1_energy_global', 'rank2_increment_global', 'cumulative_rank2_energy_global'});

    regimeNames = {'pre-transition', 'transition', 'post-transition'};
    regimeMasks = {preMask, transMask, postMask};
    regRows = repmat(struct('regime_label', "", 'n_temperatures', 0, 'rank1_energy', NaN, ...
        'rank2_increment', NaN, 'cumulative_rank2_energy', NaN, 'mean_residual_norm', NaN), 3, 1);
    for ir = 1:3
        m = regimeMasks{ir};
        regRows(ir).regime_label = string(regimeNames{ir});
        regRows(ir).n_temperatures = sum(m);
        if sum(m) >= 1
            Rr = Rfill(m, :);
            [~, Sr, ~] = svd(Rr, 'econ');
            sv = diag(Sr);
            if numel(sv) < 2
                sv(end+1:2) = 0; %#ok<AGROW>
            end
            et = sum(sv.^2);
            if et <= 0
                et = eps;
            end
            regRows(ir).rank1_energy = (sv(1)^2) / et;
            regRows(ir).rank2_increment = (sv(2)^2) / et;
            regRows(ir).cumulative_rank2_energy = ((sv(1)^2) + (sv(2)^2)) / et;
            regRows(ir).mean_residual_norm = mean(vecnorm(Rr, 2, 2), 'omitnan');
        end
    end
    byRegimeTbl = struct2table(regRows);

    mode1 = V(:, 1);
    mode2 = zeros(nI, 1);
    mode3 = zeros(nI, 1);
    if size(V, 2) >= 2
        mode2 = V(:, 2);
    end
    if size(V, 2) >= 3
        mode3 = V(:, 3);
    end

    kappa1 = Rfill * mode1;
    kappa2 = Rfill * mode2;
    kappa3 = Rfill * mode3;

    modeAmpTbl = table(allT, kappa1, kappa2, kappa3, regimeLabel, yesnoStr(trFlag), ...
        'VariableNames', {'T_K', 'kappa1', 'kappa2', 'kappa3', 'regime_label', 'transition_flag'});

    cosine1 = NaN(nT, 1);
    cosine2 = NaN(nT, 1);
    cosPrev = NaN(nT, 1);
    for it = 1:nT
        r = Rfill(it, :)';
        nr = norm(r);
        if nr > 0
            cosine1(it) = abs(dot(r, mode1) / (nr * max(norm(mode1), eps)));
            cosine2(it) = abs(dot(r, mode2) / (nr * max(norm(mode2), eps)));
        end
        if it > 1
            rp = Rfill(it - 1, :)';
            nrp = norm(rp);
            if nr > 0 && nrp > 0
                cosPrev(it) = dot(r, rp) / (nr * nrp);
            end
        end
    end
    stabilityTbl = table(allT, regimeLabel, cosine1, cosine2, cosPrev, ...
        'VariableNames', {'T_K', 'regime_label', 'cosine_to_mode1', 'cosine_to_mode2', 'residual_cosine_prev_T'});

    ridgeMask = allI >= 35 & allI <= 45;
    if ~any(ridgeMask)
        ql = quantile(allI, [0.55, 0.80]);
        ridgeMask = allI >= ql(1) & allI <= ql(2);
    end
    modeE1 = mode1.^2;
    modeE2 = mode2.^2;
    ridgeFrac1 = sum(modeE1(ridgeMask)) / max(sum(modeE1), eps);
    ridgeFrac2 = sum(modeE2(ridgeMask)) / max(sum(modeE2), eps);
    locTbl = table( ...
        string({'mode_1'; 'mode_2'}), ...
        [ridgeFrac1; ridgeFrac2], ...
        [1 - ridgeFrac1; 1 - ridgeFrac2], ...
        string({labelLoc(ridgeFrac1); labelLoc(ridgeFrac2)}), ...
        'VariableNames', {'mode_id', 'ridge_energy_fraction', 'nonridge_energy_fraction', 'localization_label'});

    Rrank1 = kappa1 * mode1';
    Rrank2 = Rrank1 + kappa2 * mode2';
    rmse1 = NaN(nT, 1);
    expl1 = NaN(nT, 1);
    rmse2 = NaN(nT, 1);
    expl2 = NaN(nT, 1);
    rmseGain = NaN(nT, 1);
    explGain = NaN(nT, 1);
    for it = 1:nT
        r = Rfill(it, :)';
        e = sum(r.^2);
        d1 = r - Rrank1(it, :)';
        d2 = r - Rrank2(it, :)';
        rmse1(it) = sqrt(mean(d1.^2, 'omitnan'));
        rmse2(it) = sqrt(mean(d2.^2, 'omitnan'));
        if e > 0
            expl1(it) = 1 - (sum(d1.^2) / e);
            expl2(it) = 1 - (sum(d2.^2) / e);
        end
        rmseGain(it) = rmse1(it) - rmse2(it);
        explGain(it) = expl2(it) - expl1(it);
    end
    rank1Tbl = table(allT, regimeLabel, rmse1, expl1, ...
        'VariableNames', {'T_K', 'regime_label', 'RMSE_rank1', 'explained_fraction_rank1'});
    rank2Tbl = table(allT, regimeLabel, rmse2, expl2, rmseGain, explGain, ...
        'VariableNames', {'T_K', 'regime_label', 'RMSE_rank2', 'explained_fraction_rank2', 'RMSE_gain_over_rank1', 'explained_gain_over_rank1'});

    preGainBase = explGain(preMask);
    preGainMu = mean(preGainBase, 'omitnan');
    preGainSd = std(preGainBase, 'omitnan');
    if ~isfinite(preGainSd) || preGainSd <= 0
        preGainSd = max(abs(preGainMu) * 0.1, 1e-6);
    end
    preK2Base = abs(kappa2(preMask));
    preK2Mu = mean(preK2Base, 'omitnan');
    preK2Sd = std(preK2Base, 'omitnan');
    if ~isfinite(preK2Sd) || preK2Sd <= 0
        preK2Sd = max(abs(preK2Mu) * 0.1, 1e-6);
    end
    rank1DropBase = rank1_energy_global;
    rank1_drop_indicator = (expl1 < max(0, rank1DropBase - 0.15));
    coupled = (abs(kappa2) > (preK2Mu + 2 * preK2Sd)) & (explGain > (preGainMu + 2 * preGainSd));
    couplingTbl = table(allT, regimeLabel, abs(kappa2), explGain, yesnoStr(rank1_drop_indicator), yesnoStr(coupled), ...
        'VariableNames', {'T_K', 'regime_label', 'kappa2_abs', 'rank2_gain', 'rank1_drop_indicator', 'coupled_to_transition_flag'});

    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        string(yesno(transitionFound)), ...
        nT, ...
        nI, ...
        string(boundaryText), ...
        string(sprintf('source=%s;missing_rows=%d;excluded_rows=%d', sPath, missingRows, excludedRows)), ...
        'VariableNames', {'STATUS', 'INPUT_FOUND', 'TRANSITION_TABLE_FOUND', 'N_temperatures', 'N_current_points', 'regime_boundaries_used', 'execution_notes'});

    % Verdicts
    meanExpl1Pre = mean(expl1(preMask), 'omitnan');
    meanExpl1Trans = mean(expl1(transMask), 'omitnan');
    meanExpl1Post = mean(expl1(postMask), 'omitnan');
    meanGainPre = mean(explGain(preMask), 'omitnan');
    meanGainTrans = mean(explGain(transMask), 'omitnan');
    meanGainPost = mean(explGain(postMask), 'omitnan');
    mode2Stable = mean(cosine2(transMask | postMask), 'omitnan') >= 0.25;
    mode2Localized = ridgeFrac2 >= 0.55;
    k2Pre = mean(abs(kappa2(preMask)), 'omitnan');
    k2Post = mean(abs(kappa2(transMask | postMask)), 'omitnan');
    mode2Tdep = isfinite(k2Pre) && isfinite(k2Post) && (k2Post > 1.5 * max(k2Pre, eps));
    coupledFrac = mean(coupled(transMask | postMask), 'omitnan');
    mode2Coupled = isfinite(coupledFrac) && coupledFrac >= 0.5;
    mode2Exists = meanGainTrans > 0.03 || meanGainPost > 0.03;
    rank1Sufficient = ~(mode2Exists && mode2Coupled && mode2Stable);
    highTMismatchExplained = (meanGainPost > 0.05) && mode2Coupled;
    safeInterpret = mode2Exists && mode2Stable && mode2Coupled;

    report = {};
    report{end+1} = '# Switching Residual / Mode Analysis';
    report{end+1} = '';
    report{end+1} = '## 1. Data-Driven Regime Definition';
    report{end+1} = sprintf('- transition table: `%s`', transitionPath);
    report{end+1} = sprintf('- regime boundaries used: %s', boundaryText);
    report{end+1} = '- no fixed transition temperature was assumed; regimes are derived from transition flags.';
    report{end+1} = '';
    report{end+1} = '## 2. Global Rank Structure';
    report{end+1} = sprintf('- rank1_energy_global = %.6g', rank1_energy_global);
    report{end+1} = sprintf('- rank2_increment_global = %.6g', rank2_increment_global);
    report{end+1} = sprintf('- cumulative_rank2_energy_global = %.6g', cumulative_rank2_energy_global);
    report{end+1} = '';
    report{end+1} = '## 3. Regime-Split Behavior';
    report{end+1} = sprintf('- mean explained_fraction_rank1: pre=%.6g, transition=%.6g, post=%.6g', meanExpl1Pre, meanExpl1Trans, meanExpl1Post);
    report{end+1} = sprintf('- mean explained_gain_over_rank1: pre=%.6g, transition=%.6g, post=%.6g', meanGainPre, meanGainTrans, meanGainPost);
    report{end+1} = '';
    report{end+1} = '## 4. Mode Stability';
    report{end+1} = sprintf('- mode_1 stability proxy (mean cosine_to_mode1) = %.6g', mean(cosine1, 'omitnan'));
    report{end+1} = sprintf('- mode_2 stability proxy (transition+post mean cosine_to_mode2) = %.6g', mean(cosine2(transMask | postMask), 'omitnan'));
    report{end+1} = '';
    report{end+1} = '## 5. Spatial Localization';
    report{end+1} = sprintf('- ridge definition current window: [%.6g, %.6g] mA', min(allI(ridgeMask)), max(allI(ridgeMask)));
    report{end+1} = sprintf('- ridge_energy_fraction_mode1 = %.6g', ridgeFrac1);
    report{end+1} = sprintf('- ridge_energy_fraction_mode2 = %.6g', ridgeFrac2);
    report{end+1} = '';
    report{end+1} = '## 6. Transition Coupling';
    report{end+1} = sprintf('- mean |kappa2| pre=%.6g, transition+post=%.6g', k2Pre, k2Post);
    report{end+1} = sprintf('- coupled_to_transition fraction in transition+post = %.6g', coupledFrac);
    report{end+1} = '';
    report{end+1} = '## 7. Reconstruction Verdict';
    report{end+1} = sprintf('- rank1 sufficiency trend: transition/post explained_fraction_rank1 decrease = %.6g', meanExpl1Pre - mean([meanExpl1Trans, meanExpl1Post], 'omitnan'));
    report{end+1} = sprintf('- rank2 gain concentration in transition/post = %.6g', mean([meanGainTrans, meanGainPost], 'omitnan') - meanGainPre);
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- RANK1_SUFFICIENT = %s', yesno(rank1Sufficient));
    report{end+1} = sprintf('- MODE2_EXISTS_AS_STRUCTURED_COMPONENT = %s', yesno(mode2Exists));
    report{end+1} = sprintf('- MODE2_IS_STABLE = %s', yesno(mode2Stable));
    report{end+1} = sprintf('- MODE2_IS_LOCALIZED = %s', yesno(mode2Localized));
    report{end+1} = sprintf('- MODE2_HAS_CLEAR_T_DEPENDENCE = %s', yesno(mode2Tdep));
    report{end+1} = sprintf('- MODE2_IS_COUPLED_TO_TRANSITION = %s', yesno(mode2Coupled));
    report{end+1} = sprintf('- HIGH_T_MISMATCH_EXPLAINED_BY_MODE2 = %s', yesno(highTMismatchExplained));
    report{end+1} = sprintf('- SAFE_TO_PROCEED_TO_PHYSICAL_INTERPRETATION = %s', yesno(safeInterpret));

    writeBoth(globalTbl, repoRoot, runTablesDir, 'switching_residual_global_rank_structure.csv');
    writeBoth(byRegimeTbl, repoRoot, runTablesDir, 'switching_residual_rank_structure_by_regime.csv');
    writeBoth(modeAmpTbl, repoRoot, runTablesDir, 'switching_mode_amplitudes_vs_T.csv');
    fbNone = cell(1, 0);
    pRGRun = fullfile(runTablesDir, 'switching_residual_global_rank_structure.csv');
    pRGRepo = fullfile(repoRoot, 'tables', 'switching_residual_global_rank_structure.csv');
    optRG = struct();
    optRG.table_name = 'switching_residual_global_rank_structure.csv';
    optRG.expected_role = 'rank_global';
    optRG.producer_script = 'Switching/analysis/run_switching_residual_mode_analysis.m';
    optRG.source_run_id = char(string(canonicalSourceRunId));
    optRG.lineage_tags = {'svd_residual_surface', 'transition_regime_axes', 'canonical_pt_minus_scdf'};
    optRG.valid_contexts = {'canonical_collapse', 'residual_mode_analysis'};
    optRG.forbidden_transformations = fbNone;
    switchingWriteCanonicalCsvSidecar({pRGRun, pRGRepo}, repoRoot, optRG);
    pRRRun = fullfile(runTablesDir, 'switching_residual_rank_structure_by_regime.csv');
    pRRRepo = fullfile(repoRoot, 'tables', 'switching_residual_rank_structure_by_regime.csv');
    optRR = struct();
    optRR.table_name = 'switching_residual_rank_structure_by_regime.csv';
    optRR.expected_role = 'rank_by_regime';
    optRR.producer_script = 'Switching/analysis/run_switching_residual_mode_analysis.m';
    optRR.source_run_id = char(string(canonicalSourceRunId));
    optRR.lineage_tags = {'svd_residual_surface', 'regime_conditioned_metrics', 'canonical_pt_minus_scdf'};
    optRR.valid_contexts = {'canonical_collapse', 'residual_mode_analysis'};
    optRR.forbidden_transformations = fbNone;
    switchingWriteCanonicalCsvSidecar({pRRRun, pRRRepo}, repoRoot, optRR);
    pARun = fullfile(runTablesDir, 'switching_mode_amplitudes_vs_T.csv');
    pARepo = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    optA = struct();
    optA.table_name = 'switching_mode_amplitudes_vs_T.csv';
    optA.expected_role = 'mode_amplitudes';
    optA.producer_script = 'Switching/analysis/run_switching_residual_mode_analysis.m';
    optA.source_run_id = char(string(canonicalSourceRunId));
    optA.lineage_tags = {'svd_mode_amplitudes', 'canonical_pt_minus_scdf', 'transition_regime_axes'};
    optA.valid_contexts = {'canonical_collapse', 'residual_mode_analysis'};
    optA.forbidden_transformations = fbNone;
    switchingWriteCanonicalCsvSidecar({pARun, pARepo}, repoRoot, optA);
    writeBoth(stabilityTbl, repoRoot, runTablesDir, 'switching_mode_shape_stability.csv');
    writeBoth(locTbl, repoRoot, runTablesDir, 'switching_mode_localization.csv');
    writeBoth(rank1Tbl, repoRoot, runTablesDir, 'switching_rank1_sufficiency.csv');
    writeBoth(rank2Tbl, repoRoot, runTablesDir, 'switching_rank2_gain.csv');
    writeBoth(couplingTbl, repoRoot, runTablesDir, 'switching_mode_transition_coupling.csv');
    writeBoth(statusTbl, repoRoot, runTablesDir, 'switching_residual_mode_status.csv');

    writeLines(fullfile(runReportsDir, 'switching_residual_mode_analysis.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_residual_mode_analysis.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching residual mode analysis completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_residual_mode_analysis_failure');
        if exist(runDir, 'dir') ~= 7
            mkdir(runDir);
        end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'tables'));
    end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'reports'));
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end
    statusTbl = table(string('FAILED'), string('NO'), string('NO'), 0, 0, string('INCONCLUSIVE'), string(ME.message), ...
        'VariableNames', {'STATUS', 'INPUT_FOUND', 'TRANSITION_TABLE_FOUND', 'N_temperatures', 'N_current_points', 'regime_boundaries_used', 'execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_residual_mode_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_residual_mode_status.csv'));
    lines = {};
    lines{end+1} = '# Switching Residual / Mode Analysis FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_residual_mode_analysis.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_residual_mode_analysis.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching residual mode analysis failed'}, true);
    rethrow(ME);
end

function [labels, preMask, transMask, postMask, boundaryText] = deriveRegimes(T, trFlag)
n = numel(T);
labels = strings(n, 1);
labels(:) = "transition";
idx = find(trFlag);
if isempty(idx)
    q = quantile(T, [0.33, 0.66]);
    preMask = T <= q(1);
    transMask = T > q(1) & T <= q(2);
    postMask = T > q(2);
    boundaryText = sprintf('fallback_quantiles pre<=%.6g, transition(%.6g,%.6g], post>%.6g', q(1), q(1), q(2), q(2));
else
    onset = idx(1);
    % contiguous flagged block from onset
    e = onset;
    while e < n && trFlag(e + 1)
        e = e + 1;
    end
    preMask = false(n, 1); preMask(1:onset-1) = true;
    transMask = false(n, 1); transMask(onset:e) = true;
    postMask = false(n, 1); postMask(e+1:end) = true;
    if ~any(postMask) && e < n
        postMask(e:end) = true;
        transMask(e) = false;
    end
    boundaryText = sprintf('pre: T<%.6g; transition: %.6g<=T<=%.6g; post: T>%.6g', T(onset), T(onset), T(e), T(e));
end
labels(preMask) = "pre-transition";
labels(transMask) = "transition";
labels(postMask) = "post-transition";
end

function out = yesno(tf)
out = 'NO';
if tf
    out = 'YES';
end
end

function s = yesnoStr(tf)
s = strings(numel(tf), 1);
for i = 1:numel(tf)
    if tf(i)
        s(i) = "YES";
    else
        s(i) = "NO";
    end
end
end

function lbl = labelLoc(frac)
if frac >= 0.65
    lbl = 'RIDGE_LOCALIZED';
elseif frac <= 0.35
    lbl = 'NONRIDGE_DOMINANT';
else
    lbl = 'MIXED';
end
end

function writeBoth(tbl, repoRoot, runTablesDir, name)
writetable(tbl, fullfile(runTablesDir, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_residual_mode_analysis:WriteFail', 'Cannot write file: %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
