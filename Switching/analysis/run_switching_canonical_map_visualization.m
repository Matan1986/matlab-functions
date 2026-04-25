clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_map_visualization';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_map_visualization';
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
        error('run_switching_canonical_map_visualization:MissingSLong', ...
            'No switching_canonical_S_long.csv found under switching canonical runs.');
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct( ...
        'table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));

    sLong = readtable(sLongPath);
    req = {'T_K', 'current_mA', 'S_percent'};
    for ic = 1:numel(req)
        if ~ismember(req{ic}, sLong.Properties.VariableNames)
            error('run_switching_canonical_map_visualization:MissingColumn', ...
                'switching_canonical_S_long.csv missing column: %s', req{ic});
        end
    end

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

    nPan = numel(chanKeys);
    panelNames = strings(nPan, 1);
    panelNRows = zeros(nPan, 1);
    panelNT = zeros(nPan, 1);
    panelNI = zeros(nPan, 1);
    panelSMin = nan(nPan, 1);
    panelSMax = nan(nPan, 1);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, min(420 + 380 * nPan, 1800), 520]);
    if nPan == 1
        tl = tiledlayout(1, 1, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    elseif nPan <= 2
        tl = tiledlayout(1, nPan, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    elseif nPan <= 4
        tl = tiledlayout(2, 2, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    else
        tl = tiledlayout(ceil(nPan / 2), 2, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    for iPan = 1:nPan
        key = chanKeys(iPan);
        if key == "ALL"
            sub = sLong;
            panelNames(iPan) = "Measured S_percent (all rows)";
        else
            if hasPhy && hasType
                parts = split(key, "|");
                p1 = parts(1);
                p2 = parts(2);
                m = string(sLong.switching_channel_physical) == p1 & string(sLong.channel_type) == p2;
            else
                m = string(sLong.switching_channel_physical) == key;
            end
            sub = sLong(m, :);
            panelNames(iPan) = "Measured S_percent | " + key;
        end
        T = double(sub.T_K);
        I = double(sub.current_mA);
        S = double(sub.S_percent);
        v = isfinite(T) & isfinite(I) & isfinite(S);
        T = T(v);
        I = I(v);
        S = S(v);
        if isempty(T)
            error('run_switching_canonical_map_visualization:EmptyChannel', 'No finite rows for panel %s', char(key));
        end
        TI = table(T, I, S);
        TIg = groupsummary(TI, {'T', 'I'}, 'mean', {'S'});
        allT = unique(double(TIg.T), 'sorted');
        allI = unique(double(TIg.I), 'sorted');
        nT = numel(allT);
        nI = numel(allI);
        M = nan(nT, nI);
        for it = 1:nT
            for ii = 1:nI
                mm = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
                if any(mm)
                    M(it, ii) = double(TIg.mean_S(find(mm, 1)));
                end
            end
        end
        panelNRows(iPan) = height(sub);
        panelNT(iPan) = nT;
        panelNI(iPan) = nI;
        panelSMin(iPan) = min(M(:), [], 'omitnan');
        panelSMax(iPan) = max(M(:), [], 'omitnan');

        nexttile(tl);
        imagesc(allI, allT, M);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        title(char(panelNames(iPan)), 'Interpreter', 'none');
        colorbar;
    end

    sgtitle(tl, sprintf('Canonical measured map S(I,T) — %s', baseName), 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    metaPath = [sLongPath '.meta.json'];
    gateCross = '';
    gatePath = fullfile(repoRoot, 'tables', 'switching_canonical_input_gate_status.csv');
    if exist(gatePath, 'file') == 2
        gateCross = 'switching_canonical_input_gate_status.csv present in repo tables for cross-reference only.';
    end

    summaryTbl = table((1:nPan)', panelNames, chanKeys, panelNRows, panelNT, panelNI, panelSMin, panelSMax, ...
        repmat(string(sLongPath), nPan, 1), repmat(string(metaPath), nPan, 1), ...
        'VariableNames', {'panel_id', 'panel_title', 'channel_key', 'n_rows_source', 'n_T', 'n_I', ...
        'S_percent_min', 'S_percent_max', 's_long_path', 'metadata_path'});

    chHandled = 'NO';
    if hasPhy || hasType || nPan > 1
        chHandled = 'YES';
    end
    statusTbl = table( ...
        {'CANONICAL_S_LONG_VALIDATED'; 'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; ...
        'CANONICAL_MAP_VISUALIZED'; 'CHANNELS_HANDLED'; 'FIGURES_WRITTEN'; ...
        'PAPER_READY_FIGURE'; 'INSPECTION_READY'; 'READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION'}, ...
        {'YES'; 'NO'; 'NO'; 'YES'; chHandled; 'YES'; 'NO'; 'YES'; 'YES'}, ...
        {char(string(sLongPath)); 'NO width axis or width normalization in this script'; ...
        'NO alignment or shift-scale collapse inputs'; ...
        'Measured S_percent heatmaps only'; ...
        sprintf('%d panel(s); channel columns present phy=%d type=%d', nPan, hasPhy, hasType); ...
        char(figPath); ...
        'NO typography or journal caption contract audited'; ...
        'YES human inspection heatmaps with physical T and I axes'; ...
        'YES optional backbone/residual panels deferred to Stage 2'}, ...
        'VariableNames', {'check', 'result', 'detail'});

    switchingWriteTableBothPaths(summaryTbl, repoRoot, runTables, 'switching_canonical_map_visualization_summary.csv');
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_map_visualization_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching map visualization (gated S_long)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    lines{end+1} = sprintf('- `switching_canonical_S_long.csv`: `%s`', sLongPath);
    lines{end+1} = sprintf('- Metadata sidecar validated before `readtable`: `%s`', metaPath);
    lines{end+1} = sprintf('- Validator `required_context`: `canonical_collapse` (matches existing sidecar `valid_contexts`; not a producer change).');
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_map_visualization_summary.csv`';
    lines{end+1} = '- `tables/switching_canonical_map_visualization_status.csv`';
    lines{end+1} = '';
    lines{end+1} = '## Constraints';
    lines{end+1} = '- Gated: YES (`validateCanonicalInputTable` on resolved S_long).';
    lines{end+1} = '- Width-free: YES (physical `T_K` and `current_mA` only).';
    lines{end+1} = '- Measured-only: YES (only `S_percent` plotted; no backbone/residual in this stage).';
    lines{end+1} = '- Legacy alignment / shift-scale collapse: NOT USED.';
    lines{end+1} = '- `switching_scaling_canonical_test.csv`: NOT USED.';
    lines{end+1} = '';
    lines{end+1} = '## Figure readiness';
    lines{end+1} = '- INSPECTION_READY: YES';
    lines{end+1} = '- PAPER_READY_FIGURE: NO (single-run exploratory layout; no journal caption contract).';
    lines{end+1} = '';
    if strlength(string(gateCross)) > 0
        lines{end+1} = '## Cross-reference';
        lines{end+1} = sprintf('- %s', gateCross);
        lines{end+1} = '';
    end
    lines{end+1} = '## Final verdicts';
    lines{end+1} = '- CANONICAL_S_LONG_VALIDATED = YES';
    lines{end+1} = '- WIDTH_SCALING_USED = NO';
    lines{end+1} = '- LEGACY_ALIGNMENT_USED = NO';
    lines{end+1} = '- CANONICAL_MAP_VISUALIZED = YES';
    lines{end+1} = sprintf('- CHANNELS_HANDLED = %s', chHandled);
    lines{end+1} = '- FIGURES_WRITTEN = YES';
    lines{end+1} = '- PAPER_READY_FIGURE = NO';
    lines{end+1} = '- INSPECTION_READY = YES';
    lines{end+1} = '- READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION = YES';

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_canonical_map_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_map_visualization.md'), lines, 'run_switching_canonical_map_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nPan, {'canonical map visualization completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_map_visualization_failure');
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
    failStatus = table( ...
        {'CANONICAL_S_LONG_VALIDATED'; 'WIDTH_SCALING_USED'; 'LEGACY_ALIGNMENT_USED'; ...
        'CANONICAL_MAP_VISUALIZED'; 'CHANNELS_HANDLED'; 'FIGURES_WRITTEN'; ...
        'PAPER_READY_FIGURE'; 'INSPECTION_READY'; 'READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check', 'result', 'detail'});
    writetable(failStatus, fullfile(runDir, 'tables', 'switching_canonical_map_visualization_status.csv'));
    writetable(failStatus, fullfile(repoRoot, 'tables', 'switching_canonical_map_visualization_status.csv'));

    failLines = {};
    failLines{end+1} = '# Canonical Switching map visualization — FAILED';
    failLines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    failLines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), failLines, 'run_switching_canonical_map_visualization:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_map_visualization.md'), failLines, 'run_switching_canonical_map_visualization:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical map visualization failed'}, true);
    rethrow(ME);
end
