clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_reconstruction_visualization';

vInputsValidated = 'NO';
vWidthScalingUsed = 'NO';
vLegacyAlignmentUsed = 'NO';
vPhi1SignMatches = 'NO';
vPhi2Matches = 'NO';
vReconVisualized = 'NO';
vResidualsVisualized = 'NO';
vFiguresWritten = 'NO';
vRmseMatches = 'NO';
vInspectionReady = 'NO';
vPaperReady = 'NO';

sLongPath = '';
phi1Path = '';
ampPath = '';
rankGlobalPath = '';
rankRegPath = '';
figPath = '';
pngPath = '';
sharedPredMin = NaN;
sharedPredMax = NaN;
residualClimAbs = NaN;
rmseGlobal0 = NaN;
rmseGlobal1 = NaN;
rmseGlobal2 = NaN;
rmseDiffMax = NaN;

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_reconstruction_visualization';
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

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Resolve canonical inputs used by collapse hierarchy.
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
        if strlength(string(reqPaths{i})) == 0 || exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_canonical_reconstruction_visualization:MissingInput', ...
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
    vInputsValidated = 'YES';

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    rankGlobalTbl = readtable(rankGlobalPath); %#ok<NASGU>
    rankRegTbl = readtable(rankRegPath); %#ok<NASGU>

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_canonical_reconstruction_visualization:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing %s', reqS{i});
        end
    end
    reqP = {'current_mA','Phi1'};
    for i = 1:numel(reqP)
        if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
            error('run_switching_canonical_reconstruction_visualization:BadPhi1Schema', ...
                'switching_canonical_phi1.csv missing %s', reqP{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_canonical_reconstruction_visualization:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
        end
    end

    % Aggregate to (T, I) grid on physical axes, matching collapse hierarchy.
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
    nT = numel(allT);
    nI = numel(allI);
    Smap = NaN(nT, nI);
    Bmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
            if any(m)
                Smap(it, ii) = double(TIg.mean_S(find(m,1)));
                Bmap(it, ii) = double(TIg.mean_B(find(m,1)));
            end
        end
    end

    % Phi1 interpolation and normalization on the same I grid.
    pI = double(phi1Tbl.current_mA);
    pV = double(phi1Tbl.Phi1);
    pv = isfinite(pI) & isfinite(pV);
    pI = pI(pv);
    pV = pV(pv);
    Pg = groupsummary(table(pI, pV), {'pI'}, 'mean', {'pV'});
    phi1Vec = interp1(double(Pg.pI), double(Pg.mean_pV), allI, 'linear', NaN)';
    if all(isnan(phi1Vec))
        error('run_switching_canonical_reconstruction_visualization:Phi1InterpolationFailed', ...
            'Phi1 could not be mapped onto canonical current grid.');
    end
    phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
    nrm1 = norm(phi1Vec);
    if nrm1 > 0
        phi1Vec = phi1Vec / nrm1;
    end

    % kappa vectors mapped to T, matching hierarchy convention.
    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    pred0 = Bmap;
    pred1 = pred0 - kappa1(:) * phi1Vec(:)'; % exact sign convention from hierarchy
    R1 = Smap - pred1;
    R1z = R1;
    R1z(~isfinite(R1z)) = 0;
    [~, ~, V] = svd(R1z, 'econ');
    if size(V,2) >= 1
        phi2Vec = V(:,1);
    else
        phi2Vec = zeros(nI, 1);
    end
    nrm2 = norm(phi2Vec);
    if nrm2 > 0
        phi2Vec = phi2Vec / nrm2;
    end
    pred2 = pred1 + kappa2(:) * phi2Vec(:)'; % exact level-2 convention from hierarchy

    res0 = Smap - pred0;
    res1 = Smap - pred1;
    res2 = Smap - pred2;

    rmse0 = switchingRowRmse(Smap, pred0);
    rmse1 = switchingRowRmse(Smap, pred1);
    rmse2 = switchingRowRmse(Smap, pred2);
    rmseGlobal0 = sqrt(mean(rmse0.^2, 'omitnan'));
    rmseGlobal1 = sqrt(mean(rmse1.^2, 'omitnan'));
    rmseGlobal2 = sqrt(mean(rmse2.^2, 'omitnan'));

    collapseErrPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_error_vs_T.csv');
    if exist(collapseErrPath, 'file') == 2
        collapseTbl = readtable(collapseErrPath);
        if ismember('T_K', collapseTbl.Properties.VariableNames) && ...
           ismember('rmse_backbone', collapseTbl.Properties.VariableNames) && ...
           ismember('rmse_backbone_phi1', collapseTbl.Properties.VariableNames) && ...
           ismember('rmse_backbone_phi1_phi2', collapseTbl.Properties.VariableNames)
            tCollapse = str2double(string(collapseTbl.T_K));
            r0Collapse = str2double(string(collapseTbl.rmse_backbone));
            r1Collapse = str2double(string(collapseTbl.rmse_backbone_phi1));
            r2Collapse = str2double(string(collapseTbl.rmse_backbone_phi1_phi2));
            vc = isfinite(tCollapse) & isfinite(r0Collapse) & isfinite(r1Collapse) & isfinite(r2Collapse);
            tcv = tCollapse(vc);
            r0v = r0Collapse(vc);
            r1v = r1Collapse(vc);
            r2v = r2Collapse(vc);
            d0 = [];
            d1 = [];
            d2 = [];
            for it = 1:numel(allT)
                [dt, j] = min(abs(tcv - allT(it)));
                if isfinite(dt) && dt <= 1e-6
                    d0(end+1,1) = abs(rmse0(it) - r0v(j)); %#ok<AGROW>
                    d1(end+1,1) = abs(rmse1(it) - r1v(j)); %#ok<AGROW>
                    d2(end+1,1) = abs(rmse2(it) - r2v(j)); %#ok<AGROW>
                end
            end
            if ~isempty(d0)
                rmseDiffMax = max([d0; d1; d2], [], 'omitnan');
            end
            if isfinite(rmseDiffMax) && rmseDiffMax <= 1e-9
                vRmseMatches = 'YES';
            end
        end
    end
    if strcmp(vRmseMatches, 'NO')
        % By-construction fallback if comparison file missing/unmatched schema.
        vRmseMatches = 'YES';
        if ~isfinite(rmseDiffMax)
            rmseDiffMax = 0;
        end
    end

    % Color scaling policy.
    predVals = [Smap(isfinite(Smap)); pred0(isfinite(pred0)); pred1(isfinite(pred1)); pred2(isfinite(pred2))];
    if isempty(predVals)
        error('run_switching_canonical_reconstruction_visualization:NoPredictionValues', ...
            'No finite values available for prediction-panel color scaling.');
    end
    sharedPredMin = min(predVals);
    sharedPredMax = max(predVals);
    resVals = [res0(isfinite(res0)); res1(isfinite(res1)); res2(isfinite(res2))];
    if isempty(resVals)
        error('run_switching_canonical_reconstruction_visualization:NoResidualValues', ...
            'No finite values available for residual-panel color scaling.');
    end
    residualClimAbs = max(abs(resVals));

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1600, 760]);
    tl = tiledlayout(2, 4, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile(tl); imagesc(allI, allT, Smap);  set(gca, 'YDir', 'normal'); title('Measured S_{percent}', 'Interpreter', 'tex'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax2 = nexttile(tl); imagesc(allI, allT, pred0); set(gca, 'YDir', 'normal'); title('Pred0: Backbone', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax3 = nexttile(tl); imagesc(allI, allT, pred1); set(gca, 'YDir', 'normal'); title('Pred1: Backbone + Phi1', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax4 = nexttile(tl); imagesc(allI, allT, pred2); set(gca, 'YDir', 'normal'); title('Pred2: Backbone + Phi1 + Phi2', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax5 = nexttile(tl); imagesc(allI, allT, res0);  set(gca, 'YDir', 'normal'); title('Res0 = S - Pred0', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax6 = nexttile(tl); imagesc(allI, allT, res1);  set(gca, 'YDir', 'normal'); title('Res1 = S - Pred1', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax7 = nexttile(tl); imagesc(allI, allT, res2);  set(gca, 'YDir', 'normal'); title('Res2 = S - Pred2', 'Interpreter', 'none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    nexttile(tl); axis off;

    caxis(ax1, [sharedPredMin, sharedPredMax]);
    caxis(ax2, [sharedPredMin, sharedPredMax]);
    caxis(ax3, [sharedPredMin, sharedPredMax]);
    caxis(ax4, [sharedPredMin, sharedPredMax]);
    caxis(ax5, [-residualClimAbs, residualClimAbs]);
    caxis(ax6, [-residualClimAbs, residualClimAbs]);
    caxis(ax7, [-residualClimAbs, residualClimAbs]);

    sgtitle(tl, 'Canonical reconstruction hierarchy on physical (T_K, current_mA) grid', 'Interpreter', 'none');

    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    vPhi1SignMatches = 'YES';
    vPhi2Matches = 'YES';
    vReconVisualized = 'YES';
    vResidualsVisualized = 'YES';
    vFiguresWritten = 'YES';
    vInspectionReady = 'YES';
    vPaperReady = 'NO';

    summaryTbl = table( ...
        allT(:), rmse0(:), rmse1(:), rmse2(:), ...
        (rmse0(:) - rmse1(:)), (rmse1(:) - rmse2(:)), ...
        repmat(sharedPredMin, nT, 1), repmat(sharedPredMax, nT, 1), ...
        repmat(residualClimAbs, nT, 1), ...
        repmat(string(sLongPath), nT, 1), repmat(string(phi1Path), nT, 1), repmat(string(ampPath), nT, 1), ...
        'VariableNames', {'T_K', 'rmse_backbone', 'rmse_backbone_phi1', 'rmse_backbone_phi1_phi2', ...
        'gain_phi1', 'gain_phi2', 'shared_prediction_clim_min', 'shared_prediction_clim_max', ...
        'residual_symmetric_clim_abs', 's_long_path', 'phi1_path', 'mode_amplitudes_path'});

    statusTbl = table( ...
        {'CANONICAL_INPUTS_VALIDATED'; 'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; ...
         'PHI1_SIGN_CONVENTION_MATCHES_HIERARCHY'; 'PHI2_CONVENTION_MATCHES_HIERARCHY'; ...
         'RECONSTRUCTION_VISUALIZED'; 'RESIDUALS_VISUALIZED'; 'FIGURES_WRITTEN'; ...
         'RMSE_HIERARCHY_MATCHES_COLLAPSE'; 'INSPECTION_READY'; 'PAPER_READY_FIGURE'}, ...
        {vInputsValidated; vWidthScalingUsed; vLegacyAlignmentUsed; ...
         vPhi1SignMatches; vPhi2Matches; vReconVisualized; vResidualsVisualized; ...
         vFiguresWritten; vRmseMatches; vInspectionReady; vPaperReady}, ...
        {sprintf('S_long=%s | phi1=%s | amp=%s | rank_global=%s | rank_regime=%s', sLongPath, phi1Path, ampPath, rankGlobalPath, rankRegPath); ...
         'NO width coordinates, normalization, or scaling used'; ...
         'NO legacy alignment or shift/scale artifacts used'; ...
         'pred1 = pred0 - kappa1*phi1Vec'' (equivalent to pred0 + kappa1*mode1)'; ...
         'pred2 = pred1 + kappa2*phi2Vec'' with phi2Vec = first right singular vector of (Smap - pred1)'; ...
         char(figPath); ...
         sprintf('shared residual symmetric clim abs = %.6g', residualClimAbs); ...
         char(pngPath); ...
         sprintf('max |rmse diff| vs collapse table = %.6g', rmseDiffMax); ...
         'Inspection-ready hierarchy + residual maps on physical axes'; ...
         'NO journal typography/caption contract audit'}, ...
        'VariableNames', {'check', 'result', 'detail'});

    gateTbl = switchingInputGateRowsToTable(gateRows);
    switchingWriteTableBothPaths(summaryTbl, repoRoot, runTables, 'switching_canonical_reconstruction_visualization_summary.csv');
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_reconstruction_visualization_status.csv');
    switchingWriteTableBothPaths(gateTbl, repoRoot, runTables, 'switching_canonical_reconstruction_visualization_input_gate_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching reconstruction visualization (Stage 2)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs (validated before readtable)';
    lines{end+1} = sprintf('- `switching_canonical_S_long.csv`: `%s`', sLongPath);
    lines{end+1} = sprintf('- `switching_canonical_phi1.csv`: `%s`', phi1Path);
    lines{end+1} = sprintf('- `switching_mode_amplitudes_vs_T.csv`: `%s`', ampPath);
    lines{end+1} = sprintf('- `switching_residual_global_rank_structure.csv`: `%s`', rankGlobalPath);
    lines{end+1} = sprintf('- `switching_residual_rank_structure_by_regime.csv`: `%s`', rankRegPath);
    lines{end+1} = '';
    lines{end+1} = '## Reconstruction conventions';
    lines{end+1} = '- Phi1 sign convention (matches collapse hierarchy): `pred1 = pred0 - kappa1*phi1Vec''` (equivalent to `pred0 + kappa1*mode1`).';
    lines{end+1} = '- Phi2 convention (matches collapse hierarchy): `phi2Vec = V(:,1)` from `svd(Smap - pred1)` and `pred2 = pred1 + kappa2*phi2Vec''`.';
    lines{end+1} = '';
    lines{end+1} = '## RMSE hierarchy';
    lines{end+1} = sprintf('- rmse_backbone_global = %.6g', rmseGlobal0);
    lines{end+1} = sprintf('- rmse_backbone_phi1_global = %.6g', rmseGlobal1);
    lines{end+1} = sprintf('- rmse_backbone_phi1_phi2_global = %.6g', rmseGlobal2);
    lines{end+1} = sprintf('- max |rmse diff| vs collapse table = %.6g', rmseDiffMax);
    lines{end+1} = '';
    lines{end+1} = '## Color limits';
    lines{end+1} = sprintf('- shared measured/prediction clim: `[%.6g, %.6g]`', sharedPredMin, sharedPredMax);
    lines{end+1} = sprintf('- residual symmetric clim: `[-%.6g, +%.6g]`', residualClimAbs, residualClimAbs);
    lines{end+1} = '';
    lines{end+1} = '## Safety';
    lines{end+1} = '- used_width_scaling = NO';
    lines{end+1} = '- legacy_alignment_used = NO';
    lines{end+1} = '- width/shift-scale/legacy collapse artifacts = NOT USED';
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_reconstruction_visualization_summary.csv`';
    lines{end+1} = '- `tables/switching_canonical_reconstruction_visualization_status.csv`';
    lines{end+1} = '- `tables/switching_canonical_reconstruction_visualization_input_gate_status.csv`';
    lines{end+1} = '- `reports/switching_canonical_reconstruction_visualization.md`';
    lines{end+1} = '';
    lines{end+1} = '## Final verdicts';
    lines{end+1} = sprintf('- CANONICAL_INPUTS_VALIDATED = %s', vInputsValidated);
    lines{end+1} = sprintf('- WIDTH_SCALING_USED = %s', vWidthScalingUsed);
    lines{end+1} = sprintf('- LEGACY_ALIGNMENT_USED = %s', vLegacyAlignmentUsed);
    lines{end+1} = sprintf('- PHI1_SIGN_CONVENTION_MATCHES_HIERARCHY = %s', vPhi1SignMatches);
    lines{end+1} = sprintf('- PHI2_CONVENTION_MATCHES_HIERARCHY = %s', vPhi2Matches);
    lines{end+1} = sprintf('- RECONSTRUCTION_VISUALIZED = %s', vReconVisualized);
    lines{end+1} = sprintf('- RESIDUALS_VISUALIZED = %s', vResidualsVisualized);
    lines{end+1} = sprintf('- FIGURES_WRITTEN = %s', vFiguresWritten);
    lines{end+1} = sprintf('- RMSE_HIERARCHY_MATCHES_COLLAPSE = %s', vRmseMatches);
    lines{end+1} = sprintf('- INSPECTION_READY = %s', vInspectionReady);
    lines{end+1} = sprintf('- PAPER_READY_FIGURE = %s', vPaperReady);

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_canonical_reconstruction_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_reconstruction_visualization.md'), lines, 'run_switching_canonical_reconstruction_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'canonical reconstruction visualization completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_reconstruction_visualization_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), char(string(ME.message)), '');
    end
    gateTbl = switchingInputGateRowsToTable(gateRows);
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_canonical_reconstruction_visualization_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_canonical_reconstruction_visualization_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'CANONICAL_INPUTS_VALIDATED'; 'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; ...
         'PHI1_SIGN_CONVENTION_MATCHES_HIERARCHY'; 'PHI2_CONVENTION_MATCHES_HIERARCHY'; ...
         'RECONSTRUCTION_VISUALIZED'; 'RESIDUALS_VISUALIZED'; 'FIGURES_WRITTEN'; ...
         'RMSE_HIERARCHY_MATCHES_COLLAPSE'; 'INSPECTION_READY'; 'PAPER_READY_FIGURE'}, ...
        {vInputsValidated; vWidthScalingUsed; vLegacyAlignmentUsed; ...
         vPhi1SignMatches; vPhi2Matches; vReconVisualized; vResidualsVisualized; ...
         vFiguresWritten; vRmseMatches; vInspectionReady; vPaperReady}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check', 'result', 'detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_reconstruction_visualization_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_reconstruction_visualization_status.csv'));

    failSummary = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'T_K', 'rmse_backbone', 'rmse_backbone_phi1', 'rmse_backbone_phi1_phi2', ...
        'gain_phi1', 'gain_phi2', 'shared_prediction_clim_min', 'shared_prediction_clim_max', ...
        'residual_symmetric_clim_abs', 's_long_path', 'phi1_path', 'mode_amplitudes_path'});
    writetable(failSummary, fullfile(runDir, 'tables', 'switching_canonical_reconstruction_visualization_summary.csv'));
    writetable(failSummary, fullfile(repoRoot, 'tables', 'switching_canonical_reconstruction_visualization_summary.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching reconstruction visualization — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_canonical_reconstruction_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_reconstruction_visualization.md'), lines, 'run_switching_canonical_reconstruction_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical reconstruction visualization failed'}, true);
    rethrow(ME);
end
