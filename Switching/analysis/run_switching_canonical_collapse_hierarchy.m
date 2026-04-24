clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = 'switching_canonical_collapse_hierarchy';
    cfg.dataset = 'canonical_collapse_hierarchy';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Clean canonical inputs only.
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    rankGlobalPath = fullfile(repoRoot, 'tables', 'switching_residual_global_rank_structure.csv');
    rankRegPath = fullfile(repoRoot, 'tables', 'switching_residual_rank_structure_by_regime.csv');

    reqPaths = {sLongPath, phi1Path, ampPath, rankGlobalPath, rankRegPath};
    reqNames = {'switching_canonical_S_long.csv','switching_canonical_phi1.csv', ...
        'switching_mode_amplitudes_vs_T.csv','switching_residual_global_rank_structure.csv', ...
        'switching_residual_rank_structure_by_regime.csv'};
    for i = 1:numel(reqPaths)
        if exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_canonical_collapse_hierarchy:MissingInput', ...
                'Missing required canonical input: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    try
        validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'PASS', '', '', [sLongPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [sLongPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'PASS', '', '', [phi1Path '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [phi1Path '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'PASS', '', '', [ampPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [ampPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(rankGlobalPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_global_rank_structure.csv', 'expected_role', 'rank_global')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_global_rank_structure.csv', rankGlobalPath, 'PASS', '', '', [rankGlobalPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_global_rank_structure.csv', rankGlobalPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [rankGlobalPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(rankRegPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_rank_structure_by_regime.csv', 'expected_role', 'rank_by_regime')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_rank_structure_by_regime.csv', rankRegPath, 'PASS', '', '', [rankRegPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_rank_structure_by_regime.csv', rankRegPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [rankRegPath '.meta.json']);
        rethrow(MEv);
    end

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    rankGlobalTbl = readtable(rankGlobalPath);
    rankRegTbl = readtable(rankRegPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_canonical_collapse_hierarchy:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing %s', reqS{i});
        end
    end
    reqP = {'current_mA','Phi1'};
    for i = 1:numel(reqP)
        if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
            error('run_switching_canonical_collapse_hierarchy:BadPhi1Schema', ...
                'switching_canonical_phi1.csv missing %s', reqP{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_canonical_collapse_hierarchy:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
        end
    end

    % Aggregate to (T, I) map to avoid channel duplication.
    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    B = double(sLong.S_model_pt_percent);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B);
    T = T(v); I = I(v); S = S(v); B = B(v);
    TI = table(T, I, S, B);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT); nI = numel(allI);
    Smap = NaN(nT, nI); Bmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
            if any(m)
                Smap(it, ii) = double(TIg.mean_S(find(m,1)));
                Bmap(it, ii) = double(TIg.mean_B(find(m,1)));
            end
        end
    end

    % Phi1 on same current grid.
    pI = double(phi1Tbl.current_mA);
    pV = double(phi1Tbl.Phi1);
    pv = isfinite(pI) & isfinite(pV);
    pI = pI(pv); pV = pV(pv);
    P = table(pI, pV);
    Pg = groupsummary(P, {'pI'}, 'mean', {'pV'});
    phi1Vec = interp1(double(Pg.pI), double(Pg.mean_pV), allI, 'linear', NaN)';
    if all(isnan(phi1Vec))
        error('run_switching_canonical_collapse_hierarchy:Phi1InterpolationFailed', ...
            'Phi1 could not be mapped onto canonical current grid.');
    end
    phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
    nrm1 = norm(phi1Vec);
    if nrm1 > 0, phi1Vec = phi1Vec / nrm1; end

    % kappa vectors mapped to T.
    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    % Level 0: backbone.
    pred0 = Bmap;
    % Level 1: backbone + kappa1*phi1.
    pred1 = pred0 + kappa1(:) * phi1Vec(:)';
    % Level 2: derive phi2 from residual SVD and apply kappa2 amplitude.
    R1 = Smap - pred1;
    R1z = R1;
    R1z(~isfinite(R1z)) = 0;
    [~, ~, V] = svd(R1z, 'econ');
    if size(V,2) >= 1
        phi2Vec = V(:,1);
    else
        phi2Vec = zeros(nI,1);
    end
    nrm2 = norm(phi2Vec);
    if nrm2 > 0, phi2Vec = phi2Vec / nrm2; end
    pred2 = pred1 + kappa2(:) * phi2Vec(:)';

    rmse0 = switchingRowRmse(Smap, pred0);
    rmse1 = switchingRowRmse(Smap, pred1);
    rmse2 = switchingRowRmse(Smap, pred2);
    gain1 = rmse0 - rmse1;
    gain2 = rmse1 - rmse2;
    gain1_frac = switchingSafeFraction(gain1, rmse0);
    gain2_frac = switchingSafeFraction(gain2, rmse1);

    errorVsT = table( ...
        allT(:), rmse0(:), rmse1(:), rmse2(:), gain1(:), gain2(:), gain1_frac(:), gain2_frac(:), ...
        repmat(string(strjoin(string(reqPaths), '; ')), nT, 1), ...
        repmat(string('PASS'), nT, 1), ...
        repmat(string('NO'), nT, 1), ...
        repmat(string('canonical_collapse'), nT, 1), ...
        'VariableNames', {'T_K','rmse_backbone','rmse_backbone_phi1','rmse_backbone_phi1_phi2', ...
        'gain_phi1','gain_phi2','gain_phi1_fraction','gain_phi2_fraction', ...
        'input_path','input_validation_status','used_width_scaling','canonical_context'});

    g0 = sqrt(mean(rmse0.^2, 'omitnan'));
    g1 = sqrt(mean(rmse1.^2, 'omitnan'));
    g2 = sqrt(mean(rmse2.^2, 'omitnan'));
    frac1 = switchingSafeFraction(g0 - g1, g0);
    frac2 = switchingSafeFraction(g1 - g2, g1);
    r1Energy = NaN; r2Inc = NaN; r2Cum = NaN;
    if ~isempty(rankGlobalTbl)
        if ismember('rank1_energy_global', rankGlobalTbl.Properties.VariableNames), r1Energy = double(rankGlobalTbl.rank1_energy_global(1)); end
        if ismember('rank2_increment_global', rankGlobalTbl.Properties.VariableNames), r2Inc = double(rankGlobalTbl.rank2_increment_global(1)); end
        if ismember('cumulative_rank2_energy_global', rankGlobalTbl.Properties.VariableNames), r2Cum = double(rankGlobalTbl.cumulative_rank2_energy_global(1)); end
    end
    dominance = table( ...
        g0, g1, g2, frac1, frac2, r1Energy, r2Inc, r2Cum, ...
        string(strjoin(string(reqPaths), '; ')), string('PASS'), string('NO'), string('canonical_collapse'), ...
        'VariableNames', {'rmse_backbone_global','rmse_backbone_phi1_global','rmse_backbone_phi1_phi2_global', ...
        'fractional_gain_phi1','fractional_gain_phi2','rank1_energy_global','rank2_increment_global','cumulative_rank2_energy_global', ...
        'input_path','input_validation_status','used_width_scaling','canonical_context'});

    status = table( ...
        string('SUCCESS'), string('YES'), nT, ...
        string(sprintf('level0=%.6g; level1=%.6g; level2=%.6g; frac1=%.6g; frac2=%.6g', g0, g1, g2, frac1, frac2)), ...
        string('NO'), string('canonical_collapse'), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_T','execution_notes','used_width_scaling','canonical_context'});

    gateTbl = switchingInputGateRowsToTable(gateRows);
    switchingWriteTableBothPaths(errorVsT, repoRoot, runTables, 'switching_canonical_collapse_hierarchy_error_vs_T.csv');
    switchingWriteTableBothPaths(dominance, repoRoot, runTables, 'switching_canonical_collapse_hierarchy_dominance.csv');
    switchingWriteTableBothPaths(status, repoRoot, runTables, 'switching_canonical_collapse_hierarchy_status.csv');
    switchingWriteTableBothPaths(gateTbl, repoRoot, runTables, 'switching_canonical_input_gate_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching Collapse Hierarchy';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = '';
    lines{end+1} = '## Dominance Metrics';
    lines{end+1} = sprintf('- rmse_backbone_global = %.6g', g0);
    lines{end+1} = sprintf('- rmse_backbone_phi1_global = %.6g', g1);
    lines{end+1} = sprintf('- rmse_backbone_phi1_phi2_global = %.6g', g2);
    lines{end+1} = sprintf('- fractional_gain_phi1 = %.6g', frac1);
    lines{end+1} = sprintf('- fractional_gain_phi2 = %.6g', frac2);
    lines{end+1} = '';
    lines{end+1} = '## Safety';
    lines{end+1} = '- used_width_scaling = NO';
    lines{end+1} = '- canonical_context = canonical_collapse';
    lines{end+1} = '- old width-based collapse table excluded.';
    lines{end+1} = '';
    lines{end+1} = '## Final Verdicts';
    lines{end+1} = '- NEW_SCRIPT_CREATED = YES';
    lines{end+1} = '- OLD_WIDTH_COLLAPSE_EXCLUDED = YES';
    lines{end+1} = '- VALIDATED_CANONICAL_INPUTS_ONLY = YES';
    lines{end+1} = '- BACKBONE_COLLAPSE_COMPUTED = YES';
    lines{end+1} = '- PHI1_COLLAPSE_COMPUTED = YES';
    lines{end+1} = '- PHI2_COLLAPSE_COMPUTED = YES';
    lines{end+1} = '- DOMINANCE_METRICS_COMPUTED = YES';
    lines{end+1} = '- WIDTH_SCALING_USED = NO';
    lines{end+1} = '- NO_REFACTOR_PERFORMED = YES';
    switchingWriteTextLinesFile(fullfile(runReports, 'switching_canonical_collapse_hierarchy.md'), lines, 'run_switching_canonical_collapse_hierarchy:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_collapse_hierarchy.md'), lines, 'run_switching_canonical_collapse_hierarchy:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'canonical collapse hierarchy completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_collapse_hierarchy_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    errTbl = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'T_K','rmse_backbone','rmse_backbone_phi1','rmse_backbone_phi1_phi2','gain_phi1','gain_phi2','gain_phi1_fraction','gain_phi2_fraction','input_path','input_validation_status','used_width_scaling','canonical_context'});
    domTbl = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        string(''), string('FAIL'), string('NO'), string('canonical_collapse'), ...
        'VariableNames', {'rmse_backbone_global','rmse_backbone_phi1_global','rmse_backbone_phi1_phi2_global','fractional_gain_phi1','fractional_gain_phi2','rank1_energy_global','rank2_increment_global','cumulative_rank2_energy_global','input_path','input_validation_status','used_width_scaling','canonical_context'});
    statusTbl = table(string('FAILED'), string('NO'), 0, string(ME.message), string('NO'), string('canonical_collapse'), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_T','execution_notes','used_width_scaling','canonical_context'});
    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), char(string(ME.message)), '');
    end
    gateTbl = switchingInputGateRowsToTable(gateRows);

    writetable(errTbl, fullfile(runDir, 'tables', 'switching_canonical_collapse_hierarchy_error_vs_T.csv'));
    writetable(errTbl, fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_error_vs_T.csv'));
    writetable(domTbl, fullfile(runDir, 'tables', 'switching_canonical_collapse_hierarchy_dominance.csv'));
    writetable(domTbl, fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_dominance.csv'));
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_collapse_hierarchy_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_status.csv'));
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_canonical_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_canonical_input_gate_status.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching Collapse Hierarchy FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', 'switching_canonical_collapse_hierarchy.md'), lines, 'run_switching_canonical_collapse_hierarchy:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_collapse_hierarchy.md'), lines, 'run_switching_canonical_collapse_hierarchy:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical collapse hierarchy failed'}, true);
    rethrow(ME);
end
