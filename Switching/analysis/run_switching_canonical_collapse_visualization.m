clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_collapse_visualization';

vWidthScalingUsed = 'NO';
vLegacyCollapseUsed = 'NO';
vInputGatePassed = 'NO';
vCollapseCoordinateDefined = 'NO';
vFigureReady = 'NO';
vReadyObservableMapping = 'NO';

sLongPath = '';
phi1Path = '';
ampPath = '';
rankGlobalPath = '';
rankRegPath = '';
figPath = '';
pngPath = '';
collapseXName = '';
collapseXAxisDesc = '';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_collapse_visualization';
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
            error('run_switching_canonical_collapse_visualization:MissingInput', ...
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
    vInputGatePassed = 'YES';

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_canonical_collapse_visualization:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing %s', reqS{i});
        end
    end
    reqP = {'current_mA','Phi1'};
    for i = 1:numel(reqP)
        if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
            error('run_switching_canonical_collapse_visualization:BadPhi1Schema', ...
                'switching_canonical_phi1.csv missing %s', reqP{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_canonical_collapse_visualization:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
        end
    end

    % Physical-grid reconstruction exactly as hierarchy script.
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

    pI = double(phi1Tbl.current_mA);
    pV = double(phi1Tbl.Phi1);
    pv = isfinite(pI) & isfinite(pV);
    pI = pI(pv);
    pV = pV(pv);
    Pg = groupsummary(table(pI, pV), {'pI'}, 'mean', {'pV'});
    phi1Vec = interp1(double(Pg.pI), double(Pg.mean_pV), allI, 'linear', NaN)';
    if all(isnan(phi1Vec))
        error('run_switching_canonical_collapse_visualization:Phi1InterpolationFailed', ...
            'Phi1 could not be mapped to canonical physical current grid.');
    end
    phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
    nrm1 = norm(phi1Vec);
    if nrm1 > 0, phi1Vec = phi1Vec / nrm1; end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    pred0 = Bmap;
    pred1 = pred0 - kappa1(:) * phi1Vec(:)'; % hierarchy sign convention
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

    res0 = Smap - pred0;
    res1 = Smap - pred1;
    res2 = Smap - pred2;

    predVals = [Smap(isfinite(Smap)); pred0(isfinite(pred0)); pred1(isfinite(pred1)); pred2(isfinite(pred2))];
    if isempty(predVals)
        error('run_switching_canonical_collapse_visualization:NoPredictionValues', ...
            'No finite measured/prediction values for color scaling.');
    end
    predMin = min(predVals);
    predMax = max(predVals);
    resVals = [res0(isfinite(res0)); res1(isfinite(res1)); res2(isfinite(res2))];
    if isempty(resVals)
        error('run_switching_canonical_collapse_visualization:NoResidualValues', ...
            'No finite residual values for color scaling.');
    end
    resAbs = max(abs(resVals));

    % Detect canonical collapse coordinate (if present) without inventing one.
    candCollapseCols = {'current_model_norm','I_model_norm','I_norm','current_norm','current_normalized', ...
        'collapse_x','x_canonical','x_model','canonical_collapse_x'};
    xCol = '';
    for i = 1:numel(candCollapseCols)
        if ismember(candCollapseCols{i}, sLong.Properties.VariableNames)
            xCol = candCollapseCols{i};
            break;
        end
    end
    hasCollapseCoord = ~isempty(xCol);
    if hasCollapseCoord
        xVals = double(sLong.(xCol));
        if any(isfinite(xVals))
            vCollapseCoordinateDefined = 'YES';
            collapseXName = xCol;
            collapseXAxisDesc = sprintf('%s (canonical normalized current coordinate from gated S_long)', xCol);
        else
            hasCollapseCoord = false;
        end
    end
    if ~hasCollapseCoord
        vCollapseCoordinateDefined = 'NO';
        collapseXName = 'N_A';
        collapseXAxisDesc = 'No canonical collapse-coordinate column found in gated inputs.';
    end

    % Build figure
    if hasCollapseCoord
        fig = figure('Visible', 'off', 'Color', 'w', 'Position', [70, 70, 1680, 900]);
        tl = tiledlayout(2, 4, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    else
        fig = figure('Visible', 'off', 'Color', 'w', 'Position', [70, 70, 1500, 860]);
        tl = tiledlayout(2, 4, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    ax1 = nexttile(tl); imagesc(allI, allT, Smap);  set(gca,'YDir','normal'); title('Measured S_{percent}','Interpreter','tex'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax2 = nexttile(tl); imagesc(allI, allT, pred0); set(gca,'YDir','normal'); title('Backbone prediction','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax3 = nexttile(tl); imagesc(allI, allT, pred1); set(gca,'YDir','normal'); title('Backbone + Phi1','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax4 = nexttile(tl); imagesc(allI, allT, pred2); set(gca,'YDir','normal'); title('Backbone + Phi1 + Phi2','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax5 = nexttile(tl); imagesc(allI, allT, res0);  set(gca,'YDir','normal'); title('Residual after backbone','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax6 = nexttile(tl); imagesc(allI, allT, res1);  set(gca,'YDir','normal'); title('Residual after +Phi1','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;
    ax7 = nexttile(tl); imagesc(allI, allT, res2);  set(gca,'YDir','normal'); title('Residual after +Phi1+Phi2','Interpreter','none'); xlabel('Current (mA)'); ylabel('Temperature (K)'); colorbar;

    caxis(ax1, [predMin, predMax]); caxis(ax2, [predMin, predMax]); caxis(ax3, [predMin, predMax]); caxis(ax4, [predMin, predMax]);
    caxis(ax5, [-resAbs, resAbs]); caxis(ax6, [-resAbs, resAbs]); caxis(ax7, [-resAbs, resAbs]);

    ax8 = nexttile(tl);
    if hasCollapseCoord
        % Overlay measured and hierarchy predictions vs canonical collapse x-coordinate.
        Tfull = double(sLong.T_K);
        Ifull = double(sLong.current_mA);
        Xfull = double(sLong.(xCol));
        Sfull = double(sLong.S_percent);
        keep = isfinite(Tfull) & isfinite(Ifull) & isfinite(Xfull) & isfinite(Sfull);
        Tfull = Tfull(keep);
        Ifull = Ifull(keep);
        Xfull = Xfull(keep);
        Sfull = Sfull(keep);

        pred0Row = NaN(size(Tfull));
        pred1Row = NaN(size(Tfull));
        pred2Row = NaN(size(Tfull));
        for ir = 1:numel(Tfull)
            [dt, it] = min(abs(allT - Tfull(ir)));
            [di, ii] = min(abs(allI - Ifull(ir)));
            if isfinite(dt) && isfinite(di) && dt <= 1e-9 && di <= 1e-9
                pred0Row(ir) = pred0(it, ii);
                pred1Row(ir) = pred1(it, ii);
                pred2Row(ir) = pred2(it, ii);
            end
        end
        mrow = isfinite(pred0Row) & isfinite(pred1Row) & isfinite(pred2Row);
        TX = table(Tfull(mrow), Xfull(mrow), Sfull(mrow), pred0Row(mrow), pred1Row(mrow), pred2Row(mrow), ...
            'VariableNames', {'T_K','X','Smeas','P0','P1','P2'});
        TXg = groupsummary(TX, {'T_K','X'}, 'mean', {'Smeas','P0','P1','P2'});
        tUnique = unique(double(TXg.T_K), 'sorted');
        cmap = lines(max(numel(tUnique), 1));
        hold on;
        for it = 1:numel(tUnique)
            m = abs(double(TXg.T_K) - tUnique(it)) < 1e-9;
            [xSort, ordx] = sort(double(TXg.X(m)), 'ascend');
            yS = double(TXg.mean_Smeas(m)); yS = yS(ordx);
            y0 = double(TXg.mean_P0(m)); y0 = y0(ordx);
            y1 = double(TXg.mean_P1(m)); y1 = y1(ordx);
            y2 = double(TXg.mean_P2(m)); y2 = y2(ordx);
            plot(xSort, yS, '-', 'Color', cmap(it,:), 'LineWidth', 1.2);
            plot(xSort, y0, '--', 'Color', cmap(it,:), 'LineWidth', 0.8);
            plot(xSort, y1, ':', 'Color', cmap(it,:), 'LineWidth', 0.8);
            plot(xSort, y2, '-.', 'Color', cmap(it,:), 'LineWidth', 0.8);
        end
        hold off;
        xlabel(collapseXName, 'Interpreter', 'none');
        ylabel('S_{percent}');
        title('Canonical collapse-style overlay', 'Interpreter', 'none');
        grid on;
    else
        axis off;
        text(0.02, 0.65, 'Collapse overlay not generated.', 'FontSize', 11, 'Interpreter', 'none');
        text(0.02, 0.45, 'COLLAPSE_COORDINATE_DEFINED=NO', 'FontSize', 11, 'Interpreter', 'none');
        text(0.02, 0.25, 'No valid canonical collapse coordinate in gated inputs.', 'FontSize', 10, 'Interpreter', 'none');
    end

    sgtitle(tl, 'Canonical collapse visualization (inspection-first)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    vFigureReady = 'YES';
    if strcmp(vInputGatePassed, 'YES') && strcmp(vFigureReady, 'YES') && strcmp(vWidthScalingUsed, 'NO') && strcmp(vLegacyCollapseUsed, 'NO')
        vReadyObservableMapping = 'YES';
    end

    statusTbl = table( ...
        {'WIDTH_SCALING_USED'; 'LEGACY_COLLAPSE_USED'; 'INPUT_GATE_PASSED'; ...
         'COLLAPSE_COORDINATE_DEFINED'; 'FIGURE_READY_FOR_INTERPRETATION'; 'READY_FOR_OBSERVABLE_MAPPING'}, ...
        {vWidthScalingUsed; vLegacyCollapseUsed; vInputGatePassed; ...
         vCollapseCoordinateDefined; vFigureReady; vReadyObservableMapping}, ...
        {'NO width normalization, width coordinate, or scaling table used'; ...
         'NO legacy alignment-backed/old scaling collapse artifacts used'; ...
         sprintf('Canonical metadata gate PASS on: %s', strjoin(reqNames, ', ')); ...
         collapseXAxisDesc; ...
         char(figPath); ...
         sprintf('Inspection-first figure written; collapse_x_axis=%s', collapseXName)}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_collapse_visualization_status.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_canonical_collapse_visualization_input_gate_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching collapse visualization (inspection-first)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs (metadata-gated canonical only)';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = '';
    lines{end+1} = '## Reconstruction/sign conventions';
    lines{end+1} = '- Level 0: `pred0 = Bmap`.';
    lines{end+1} = '- Level 1: `pred1 = pred0 - kappa1*phi1Vec''` (same sign convention as collapse hierarchy).';
    lines{end+1} = '- Level 2: `pred2 = pred1 + kappa2*phi2Vec''`, where `phi2Vec = V(:,1)` from `svd(Smap - pred1)`.';
    lines{end+1} = '';
    lines{end+1} = '## Collapse overlay axis';
    lines{end+1} = sprintf('- COLLAPSE_COORDINATE_DEFINED = %s', vCollapseCoordinateDefined);
    lines{end+1} = sprintf('- x-axis used for collapse overlay: %s', collapseXAxisDesc);
    if strcmp(vCollapseCoordinateDefined, 'NO')
        lines{end+1} = '- No canonical collapse coordinate was found; only reconstruction visualization panels were produced.';
    end
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_collapse_visualization_status.csv`';
    lines{end+1} = '- `reports/switching_canonical_collapse_visualization.md`';
    lines{end+1} = '';
    lines{end+1} = '## Status flags';
    lines{end+1} = sprintf('- WIDTH_SCALING_USED = %s', vWidthScalingUsed);
    lines{end+1} = sprintf('- LEGACY_COLLAPSE_USED = %s', vLegacyCollapseUsed);
    lines{end+1} = sprintf('- INPUT_GATE_PASSED = %s', vInputGatePassed);
    lines{end+1} = sprintf('- COLLAPSE_COORDINATE_DEFINED = %s', vCollapseCoordinateDefined);
    lines{end+1} = sprintf('- FIGURE_READY_FOR_INTERPRETATION = %s', vFigureReady);
    lines{end+1} = sprintf('- READY_FOR_OBSERVABLE_MAPPING = %s', vReadyObservableMapping);
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_canonical_collapse_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_collapse_visualization.md'), lines, 'run_switching_canonical_collapse_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'canonical collapse visualization completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_collapse_visualization_failure');
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
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_canonical_collapse_visualization_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_canonical_collapse_visualization_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'WIDTH_SCALING_USED'; 'LEGACY_COLLAPSE_USED'; 'INPUT_GATE_PASSED'; ...
         'COLLAPSE_COORDINATE_DEFINED'; 'FIGURE_READY_FOR_INTERPRETATION'; 'READY_FOR_OBSERVABLE_MAPPING'}, ...
        {vWidthScalingUsed; vLegacyCollapseUsed; vInputGatePassed; ...
         vCollapseCoordinateDefined; vFigureReady; vReadyObservableMapping}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_collapse_visualization_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_collapse_visualization_status.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching collapse visualization — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_canonical_collapse_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_collapse_visualization.md'), lines, 'run_switching_canonical_collapse_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical collapse visualization failed'}, true);
    rethrow(ME);
end
