clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_map_backbone_residual_visualization';

vCanonicalValidated = 'NO';
vBackboneFound = 'NO';
vResidualComputed = 'NO';
vWidthScalingUsed = 'NO';
vLegacyAlignmentUsed = 'NO';
vBackboneResidualVisualized = 'NO';
vFiguresWritten = 'NO';
vInspectionReady = 'NO';
vPaperReady = 'NO';
vReadyStage2 = 'NO';

sLongPath = '';
metaPath = '';
figPath = '';
pngPath = '';
nPanels = 0;
hasPhy = false;
hasType = false;
columnList = '';
globalNT = 0;
globalNI = 0;
overallResidualMin = NaN;
overallResidualMax = NaN;
overallResidualRmse = NaN;
sharedSBmin = NaN;
sharedSBmax = NaN;
residualClimAbs = NaN;

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_map_backbone_residual_visualization';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7
        mkdir(runTables);
    end
    if exist(runReports, 'dir') ~= 7
        mkdir(runReports);
    end
    if exist(runFigures, 'dir') ~= 7
        mkdir(runFigures);
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

    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    if strlength(string(sLongPath)) == 0 || exist(sLongPath, 'file') ~= 2
        error('run_switching_canonical_map_backbone_residual_visualization:MissingSLong', ...
            'No switching_canonical_S_long.csv found under switching canonical runs.');
    end
    metaPath = [sLongPath '.meta.json'];

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct( ...
        'table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    vCanonicalValidated = 'YES';

    sLong = readtable(sLongPath);
    req = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    for ic = 1:numel(req)
        if ~ismember(req{ic}, sLong.Properties.VariableNames)
            if strcmp(req{ic}, 'S_model_pt_percent')
                vBackboneFound = 'NO';
                error('run_switching_canonical_map_backbone_residual_visualization:MissingBackboneColumn', ...
                    'switching_canonical_S_long.csv missing required backbone column: %s', req{ic});
            else
                error('run_switching_canonical_map_backbone_residual_visualization:MissingColumn', ...
                    'switching_canonical_S_long.csv missing required column: %s', req{ic});
            end
        end
    end
    vBackboneFound = 'YES';
    columnList = 'T_K, current_mA, S_percent, S_model_pt_percent';

    hasPhy = ismember('switching_channel_physical', sLong.Properties.VariableNames);
    hasType = ismember('channel_type', sLong.Properties.VariableNames);

    if hasPhy && hasType
        k1 = string(sLong.switching_channel_physical);
        k2 = string(sLong.channel_type);
        chanKeys = unique(strtrim(k1) + "|" + strtrim(k2), 'stable');
    elseif hasPhy
        chanKeys = unique(string(sLong.switching_channel_physical), 'stable');
    else
        chanKeys = string("ALL");
    end

    nPanels = numel(chanKeys);
    panelId = (1:nPanels)';
    panelKey = strings(nPanels, 1);
    panelRows = zeros(nPanels, 1);
    panelNT = zeros(nPanels, 1);
    panelNI = zeros(nPanels, 1);
    measuredMin = nan(nPanels, 1);
    measuredMax = nan(nPanels, 1);
    backboneMin = nan(nPanels, 1);
    backboneMax = nan(nPanels, 1);
    residualMin = nan(nPanels, 1);
    residualMax = nan(nPanels, 1);
    residualRmse = nan(nPanels, 1);
    allSharedVals = [];
    allResidualVals = [];
    axMeasured = gobjects(nPanels, 1);
    axBackbone = gobjects(nPanels, 1);
    axResidual = gobjects(nPanels, 1);

    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [80, 80, min(1600, 620), max(380, 260 * nPanels)]);
    tl = tiledlayout(nPanels, 3, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');

    for iPan = 1:nPanels
        key = chanKeys(iPan);
        if key == "ALL"
            sub = sLong;
            panelKey(iPan) = "ALL";
        else
            if hasPhy && hasType
                parts = split(key, "|");
                p1 = parts(1);
                p2 = parts(2);
                mask = string(sLong.switching_channel_physical) == p1 & string(sLong.channel_type) == p2;
            else
                mask = string(sLong.switching_channel_physical) == key;
            end
            sub = sLong(mask, :);
            panelKey(iPan) = key;
        end

        T = double(sub.T_K);
        I = double(sub.current_mA);
        Smeas = double(sub.S_percent);
        Spt = double(sub.S_model_pt_percent);
        keep = isfinite(T) & isfinite(I) & isfinite(Smeas) & isfinite(Spt);
        T = T(keep);
        I = I(keep);
        Smeas = Smeas(keep);
        Spt = Spt(keep);
        Sres = Smeas - Spt;

        if isempty(T)
            error('run_switching_canonical_map_backbone_residual_visualization:EmptyPanel', ...
                'No finite rows for channel panel %s', char(key));
        end

        TI = table(T, I, Smeas, Spt, Sres);
        TIg = groupsummary(TI, {'T', 'I'}, 'mean', {'Smeas', 'Spt', 'Sres'});
        allT = unique(double(TIg.T), 'sorted');
        allI = unique(double(TIg.I), 'sorted');
        nT = numel(allT);
        nI = numel(allI);

        M_meas = nan(nT, nI);
        M_back = nan(nT, nI);
        M_res = nan(nT, nI);
        for it = 1:nT
            for ii = 1:nI
                mm = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
                if any(mm)
                    idx = find(mm, 1);
                    M_meas(it, ii) = double(TIg.mean_Smeas(idx));
                    M_back(it, ii) = double(TIg.mean_Spt(idx));
                    M_res(it, ii) = double(TIg.mean_Sres(idx));
                end
            end
        end

        panelRows(iPan) = height(sub);
        panelNT(iPan) = nT;
        panelNI(iPan) = nI;
        measuredMin(iPan) = min(M_meas(:), [], 'omitnan');
        measuredMax(iPan) = max(M_meas(:), [], 'omitnan');
        backboneMin(iPan) = min(M_back(:), [], 'omitnan');
        backboneMax(iPan) = max(M_back(:), [], 'omitnan');
        residualMin(iPan) = min(M_res(:), [], 'omitnan');
        residualMax(iPan) = max(M_res(:), [], 'omitnan');
        residualRmse(iPan) = sqrt(mean((M_res(:)).^2, 'omitnan'));
        allSharedVals = [allSharedVals; M_meas(isfinite(M_meas)); M_back(isfinite(M_back))]; %#ok<AGROW>
        allResidualVals = [allResidualVals; M_res(isfinite(M_res))]; %#ok<AGROW>

        axMeasured(iPan) = nexttile(tl);
        imagesc(allI, allT, M_meas);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        if key == "ALL"
            title('Measured S_{percent}', 'Interpreter', 'tex');
        else
            title(char("Measured | " + key), 'Interpreter', 'none');
        end
        colorbar;

        axBackbone(iPan) = nexttile(tl);
        imagesc(allI, allT, M_back);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        if key == "ALL"
            title('Backbone S_{model,pt}', 'Interpreter', 'tex');
        else
            title(char("Backbone | " + key), 'Interpreter', 'none');
        end
        colorbar;

        axResidual(iPan) = nexttile(tl);
        imagesc(allI, allT, M_res);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        if key == "ALL"
            title('Residual S - S_{model,pt}', 'Interpreter', 'tex');
        else
            title(char("Residual | " + key), 'Interpreter', 'none');
        end
        colorbar;
    end

    if isempty(allSharedVals)
        error('run_switching_canonical_map_backbone_residual_visualization:EmptySharedScaleValues', ...
            'No finite values available to compute shared measured/backbone color limits.');
    end
    if isempty(allResidualVals)
        error('run_switching_canonical_map_backbone_residual_visualization:EmptyResidualScaleValues', ...
            'No finite values available to compute residual symmetric color limits.');
    end
    sharedSBmin = min(allSharedVals);
    sharedSBmax = max(allSharedVals);
    residualClimAbs = max(abs(allResidualVals));

    for iPan = 1:nPanels
        caxis(axMeasured(iPan), [sharedSBmin, sharedSBmax]);
        caxis(axBackbone(iPan), [sharedSBmin, sharedSBmax]);
        caxis(axResidual(iPan), [-residualClimAbs, residualClimAbs]);
    end

    sgtitle(tl, 'Canonical measured/backbone/residual maps on physical axes', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    vResidualComputed = 'YES';
    vBackboneResidualVisualized = 'YES';
    vFiguresWritten = 'YES';
    vInspectionReady = 'YES';
    vPaperReady = 'NO';
    vReadyStage2 = 'YES';

    globalNT = numel(unique(double(sLong.T_K), 'sorted'));
    globalNI = numel(unique(double(sLong.current_mA), 'sorted'));
    overallResidualMin = min(residualMin, [], 'omitnan');
    overallResidualMax = max(residualMax, [], 'omitnan');
    overallResidualRmse = sqrt(mean((residualRmse).^2, 'omitnan'));

    summaryTbl = table( ...
        panelId, panelKey, panelRows, panelNT, panelNI, ...
        measuredMin, measuredMax, backboneMin, backboneMax, ...
        residualMin, residualMax, residualRmse, ...
        repmat(string(sLongPath), nPanels, 1), repmat(string(metaPath), nPanels, 1), ...
        repmat(string(columnList), nPanels, 1), ...
        'VariableNames', {'panel_id', 'channel_key', 'n_rows_source', 'n_T', 'n_I', ...
        'S_percent_min', 'S_percent_max', 'S_model_pt_percent_min', 'S_model_pt_percent_max', ...
        'residual_min', 'residual_max', 'residual_rmse', ...
        's_long_path', 'metadata_path', 'columns_used'});

    statusTbl = table( ...
        {'CANONICAL_S_LONG_VALIDATED'; 'BACKBONE_COLUMN_FOUND'; 'RESIDUAL_COMPUTED'; ...
         'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; 'BACKBONE_RESIDUAL_VISUALIZED'; ...
         'SHARED_S_BACKBONE_CLIM'; 'SYMMETRIC_RESIDUAL_CLIM'; ...
         'FIGURES_WRITTEN'; 'INSPECTION_READY'; 'PAPER_READY_FIGURE'; ...
         'READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION'}, ...
        {vCanonicalValidated; vBackboneFound; vResidualComputed; ...
         vWidthScalingUsed; vLegacyAlignmentUsed; vBackboneResidualVisualized; ...
         'YES'; 'YES'; vFiguresWritten; vInspectionReady; vPaperReady; vReadyStage2}, ...
        {char(string(sLongPath)); ...
         'S_model_pt_percent required and verified'; ...
         'Residual computed as S_percent - S_model_pt_percent'; ...
         'NO width normalization or width coordinate used'; ...
         'NO alignment or shift-scale collapse inputs used'; ...
         char(figPath); ...
         sprintf('[%.6g, %.6g]', sharedSBmin, sharedSBmax); ...
         sprintf('[-%.6g, +%.6g]', residualClimAbs, residualClimAbs); ...
         char(pngPath); ...
         'Inspection-ready canonical physical-axis panel figure'; ...
         'NO journal typography/caption contract audit'; ...
         'Stage 1 extension complete; Stage 2 reconstruction maps next'}, ...
        'VariableNames', {'check', 'result', 'detail'});

    switchingWriteTableBothPaths(summaryTbl, repoRoot, runTables, 'switching_canonical_map_backbone_residual_summary.csv');
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_map_backbone_residual_status.csv');

    channelHandling = 'ALL rows aggregated';
    if hasPhy && hasType
        channelHandling = sprintf('Per-channel panels using switching_channel_physical + channel_type (%d panels)', nPanels);
    elseif hasPhy
        channelHandling = sprintf('Per-channel panels using switching_channel_physical (%d panels)', nPanels);
    end

    lines = {};
    lines{end+1} = '# Canonical Switching map backbone + residual visualization (gated S_long)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    lines{end+1} = sprintf('- `switching_canonical_S_long.csv`: `%s`', sLongPath);
    lines{end+1} = sprintf('- Metadata sidecar validated before `readtable`: `%s`', metaPath);
    lines{end+1} = '- Validator `required_context`: `canonical_collapse`.';
    lines{end+1} = '';
    lines{end+1} = '## Columns used';
    lines{end+1} = sprintf('- `%s`', columnList);
    lines{end+1} = '';
    lines{end+1} = '## Physical-grid coverage';
    lines{end+1} = sprintf('- Global bins: `T_K`=%d, `current_mA`=%d', globalNT, globalNI);
    lines{end+1} = sprintf('- Channel handling: %s', channelHandling);
    lines{end+1} = '';
    lines{end+1} = '## Residual summary (S_percent - S_model_pt_percent)';
    lines{end+1} = sprintf('- residual_min: %.6g', overallResidualMin);
    lines{end+1} = sprintf('- residual_max: %.6g', overallResidualMax);
    lines{end+1} = sprintf('- residual_rmse (panel aggregate): %.6g', overallResidualRmse);
    lines{end+1} = '';
    lines{end+1} = '## Color limits';
    lines{end+1} = sprintf('- shared measured/backbone clim: `[%.6g, %.6g]`', sharedSBmin, sharedSBmax);
    lines{end+1} = sprintf('- residual symmetric clim: `[-%.6g, +%.6g]`', residualClimAbs, residualClimAbs);
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_map_backbone_residual_summary.csv`';
    lines{end+1} = '- `tables/switching_canonical_map_backbone_residual_status.csv`';
    lines{end+1} = '- `reports/switching_canonical_map_backbone_residual.md`';
    lines{end+1} = '';
    lines{end+1} = '## Figure readiness';
    lines{end+1} = '- INSPECTION_READY: YES';
    lines{end+1} = '- PAPER_READY_FIGURE: NO';
    lines{end+1} = '';
    lines{end+1} = '## Final verdicts';
    lines{end+1} = sprintf('- CANONICAL_S_LONG_VALIDATED = %s', vCanonicalValidated);
    lines{end+1} = sprintf('- BACKBONE_COLUMN_FOUND = %s', vBackboneFound);
    lines{end+1} = sprintf('- RESIDUAL_COMPUTED = %s', vResidualComputed);
    lines{end+1} = sprintf('- WIDTH_SCALING_USED = %s', vWidthScalingUsed);
    lines{end+1} = sprintf('- LEGACY_ALIGNMENT_USED = %s', vLegacyAlignmentUsed);
    lines{end+1} = sprintf('- BACKBONE_RESIDUAL_VISUALIZED = %s', vBackboneResidualVisualized);
    lines{end+1} = sprintf('- FIGURES_WRITTEN = %s', vFiguresWritten);
    lines{end+1} = sprintf('- INSPECTION_READY = %s', vInspectionReady);
    lines{end+1} = sprintf('- PAPER_READY_FIGURE = %s', vPaperReady);
    lines{end+1} = sprintf('- READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION = %s', vReadyStage2);

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, ...
        'run_switching_canonical_map_backbone_residual_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_map_backbone_residual.md'), lines, ...
        'run_switching_canonical_map_backbone_residual_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nPanels, {'canonical backbone/residual map visualization completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_map_backbone_residual_visualization_failure');
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

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'CANONICAL_S_LONG_VALIDATED'; 'BACKBONE_COLUMN_FOUND'; 'RESIDUAL_COMPUTED'; ...
         'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; 'BACKBONE_RESIDUAL_VISUALIZED'; ...
         'SHARED_S_BACKBONE_CLIM'; 'SYMMETRIC_RESIDUAL_CLIM'; ...
         'FIGURES_WRITTEN'; 'INSPECTION_READY'; 'PAPER_READY_FIGURE'; ...
         'READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION'}, ...
        {vCanonicalValidated; vBackboneFound; vResidualComputed; ...
         vWidthScalingUsed; vLegacyAlignmentUsed; vBackboneResidualVisualized; ...
         'NO'; 'NO'; vFiguresWritten; vInspectionReady; vPaperReady; vReadyStage2}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check', 'result', 'detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_map_backbone_residual_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_map_backbone_residual_status.csv'));

    failLines = {};
    failLines{end+1} = '# Canonical Switching map backbone + residual visualization — FAILED';
    failLines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    failLines{end+1} = sprintf('- error_message: `%s`', ME.message);
    failLines{end+1} = sprintf('- CANONICAL_S_LONG_VALIDATED = %s', vCanonicalValidated);
    failLines{end+1} = sprintf('- BACKBONE_COLUMN_FOUND = %s', vBackboneFound);
    failLines{end+1} = sprintf('- RESIDUAL_COMPUTED = %s', vResidualComputed);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), failLines, ...
        'run_switching_canonical_map_backbone_residual_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_map_backbone_residual.md'), failLines, ...
        'run_switching_canonical_map_backbone_residual_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical backbone/residual map visualization failed'}, true);
    rethrow(ME);
end
