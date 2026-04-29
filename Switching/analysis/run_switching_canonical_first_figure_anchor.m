% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: CANON_FIGURE_REPLAY / ANCHOR — layout/anchor for figures from resolved canonical run tables
% EVIDENCE_STATUS: FIGURE_PRODUCTION — not new physics; uses locked anchorRunId for reproducibility
% UNSAFE_USE: treating anchor as proof of CORRECTED_CANONICAL_OLD_ANALYSIS without authoritative CSV package
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

anchorRunId = 'run_2026_04_03_000147_switching_canonical';
anchorRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', anchorRunId);
anchorTablesDir = fullfile(anchorRunDir, 'tables');

baseFigureName = 'switching_canonical_first_figure_anchor';

try
    cfg = struct();
    cfg.runLabel = baseFigureName;
    cfg.dataset = anchorRunId;
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    tablesDir = fullfile(runDir, 'tables');
    reportsDir = fullfile(runDir, 'reports');
    figuresDir = fullfile(runDir, 'figures');
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end

    fidTopProbe = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTopProbe >= 0
        fprintf(fidTopProbe, 'SCRIPT_ENTERED\n');
        fclose(fidTopProbe);
    end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    sLongPath = fullfile(anchorTablesDir, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(anchorTablesDir, 'switching_canonical_phi1.csv');
    obsPath = fullfile(anchorTablesDir, 'switching_canonical_observables.csv');
    validationPath = fullfile(anchorTablesDir, 'switching_canonical_validation.csv');

    requiredFiles = {sLongPath, phi1Path, obsPath, validationPath};
    for iReq = 1:numel(requiredFiles)
        if exist(requiredFiles{iReq}, 'file') ~= 2
            error('run_switching_canonical_first_figure_anchor:MissingInput', ...
                'Missing required anchor canonical input: %s', requiredFiles{iReq});
        end
    end

    sLongTbl = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    obsTbl = readtable(obsPath);
    validationTbl = readtable(validationPath);

    requiredSLongCols = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    requiredPhiCols = {'current_mA', 'Phi1'};
    requiredObsCols = {'T_K', 'kappa1'};
    for iCol = 1:numel(requiredSLongCols)
        if ~ismember(requiredSLongCols{iCol}, sLongTbl.Properties.VariableNames)
            error('run_switching_canonical_first_figure_anchor:MissingColumn', ...
                'switching_canonical_S_long.csv missing column: %s', requiredSLongCols{iCol});
        end
    end
    for iCol = 1:numel(requiredPhiCols)
        if ~ismember(requiredPhiCols{iCol}, phi1Tbl.Properties.VariableNames)
            error('run_switching_canonical_first_figure_anchor:MissingColumn', ...
                'switching_canonical_phi1.csv missing column: %s', requiredPhiCols{iCol});
        end
    end
    for iCol = 1:numel(requiredObsCols)
        if ~ismember(requiredObsCols{iCol}, obsTbl.Properties.VariableNames)
            error('run_switching_canonical_first_figure_anchor:MissingColumn', ...
                'switching_canonical_observables.csv missing column: %s', requiredObsCols{iCol});
        end
    end

    temperatures = unique(double(sLongTbl.T_K(:)));
    temperatures = temperatures(isfinite(temperatures));
    currents = unique(double(sLongTbl.current_mA(:)));
    currents = currents(isfinite(currents));
    nT = numel(temperatures);
    nI = numel(currents);

    mapObserved = nan(nT, nI);
    mapBackbone = nan(nT, nI);
    mapResidualDirect = nan(nT, nI);
    mapFullDirect = nan(nT, nI);

    hasResidualDirect = ismember('residual_percent', sLongTbl.Properties.VariableNames);
    hasFullDirect = ismember('S_model_full_percent', sLongTbl.Properties.VariableNames);

    for iRow = 1:height(sLongTbl)
        tVal = double(sLongTbl.T_K(iRow));
        iVal = double(sLongTbl.current_mA(iRow));
        if ~isfinite(tVal) || ~isfinite(iVal)
            continue;
        end
        idxT = find(abs(temperatures - tVal) < 1e-12, 1);
        idxI = find(abs(currents - iVal) < 1e-12, 1);
        if isempty(idxT) || isempty(idxI)
            continue;
        end
        mapObserved(idxT, idxI) = double(sLongTbl.S_percent(iRow));
        mapBackbone(idxT, idxI) = double(sLongTbl.S_model_pt_percent(iRow));
        if hasResidualDirect
            mapResidualDirect(idxT, idxI) = double(sLongTbl.residual_percent(iRow));
        end
        if hasFullDirect
            mapFullDirect(idxT, idxI) = double(sLongTbl.S_model_full_percent(iRow));
        end
    end

    mapResidual = mapObserved - mapBackbone;

    phiVec = nan(1, nI);
    for iI = 1:nI
        iVal = currents(iI);
        idxPhi = find(double(phi1Tbl.current_mA(:)) == iVal, 1);
        if ~isempty(idxPhi)
            phiVec(iI) = double(phi1Tbl.Phi1(idxPhi));
        end
    end

    kappaVec = nan(nT, 1);
    for iT = 1:nT
        tVal = temperatures(iT);
        idxKappa = find(double(obsTbl.T_K(:)) == tVal, 1);
        if ~isempty(idxKappa)
            kappaVec(iT) = double(obsTbl.kappa1(idxKappa));
        end
    end

    panelObservedAvailable = any(isfinite(mapObserved(:)));
    panelBackboneAvailable = any(isfinite(mapBackbone(:)));
    panelResidualAvailable = panelObservedAvailable && panelBackboneAvailable;
    panelFullAvailable = panelBackboneAvailable && all(~isnan(kappaVec)) && all(~isnan(phiVec));

    mapFullReconstruction = nan(nT, nI);
    if panelFullAvailable
        mapFullReconstruction = mapBackbone + (kappaVec * phiVec);
    end

    residualParityRmse = NaN;
    if hasResidualDirect
        residualDelta = mapResidual - mapResidualDirect;
        residualParityRmse = sqrt(mean(residualDelta(:).^2, 'omitnan'));
    end

    fullParityRmse = NaN;
    if panelFullAvailable && hasFullDirect
        fullDelta = mapFullReconstruction - mapFullDirect;
        fullParityRmse = sqrt(mean(fullDelta(:).^2, 'omitnan'));
    end

    panelNames = { ...
        'Observed switching map S(I,T)', ...
        'Canonical backbone map Scdf(I,T)', ...
        'Residual map S-Scdf', ...
        'Rank-1 reconstruction Scdf + kappa1*phi1'''};
    panelKinds = { ...
        'DIRECT_FROM_CANONICAL_TABLES', ...
        'DIRECT_FROM_CANONICAL_TABLES', ...
        'DERIVED_FROM_CANONICAL_TABLE_COLUMNS', ...
        'DERIVED_FROM_CANONICAL_TABLE_COLUMNS'};
    panelAvailability = [panelObservedAvailable, panelBackboneAvailable, panelResidualAvailable, panelFullAvailable];
    panelOmitReason = repmat({''}, 1, 4);
    if ~panelObservedAvailable
        panelOmitReason{1} = 'Observed map has missing cells in anchor canonical S_long.';
    end
    if ~panelBackboneAvailable
        panelOmitReason{2} = 'Backbone map has missing cells in anchor canonical S_long.';
    end
    if ~panelResidualAvailable
        panelOmitReason{3} = 'Residual requires observed and backbone maps.';
    end
    if ~panelFullAvailable
        panelOmitReason{4} = 'Rank-1 reconstruction requires complete kappa1(T) and phi1(I).';
    end

    nPanelsIncluded = sum(panelAvailability);
    if nPanelsIncluded <= 0
        error('run_switching_canonical_first_figure_anchor:NoPanels', ...
            'No panel could be produced from anchor canonical tables.');
    end

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1500, 950]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    if panelAvailability(1)
        nexttile;
        imagesc(currents, temperatures, mapObserved);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        title('Observed S(I,T)');
        colorbar;
    end

    if panelAvailability(2)
        nexttile;
        imagesc(currents, temperatures, mapBackbone);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        title('Backbone Scdf(I,T) from S\_model\_pt');
        colorbar;
    end

    if panelAvailability(3)
        nexttile;
        imagesc(currents, temperatures, mapResidual);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        title('Residual S - Scdf');
        colorbar;
    end

    if panelAvailability(4)
        nexttile;
        imagesc(currents, temperatures, mapFullReconstruction);
        set(gca, 'YDir', 'normal');
        xlabel('Current (mA)');
        ylabel('Temperature (K)');
        title('Full reconstruction Scdf + kappa1*phi1''');
        colorbar;
    end

    sgtitle(sprintf('Canonical Switching First Figure (%s)', anchorRunId), 'Interpreter', 'none');

    figPath = fullfile(figuresDir, [baseFigureName '.fig']);
    pngPath = fullfile(figuresDir, [baseFigureName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    panelId = (1:4)';
    panelStatus = strings(4, 1);
    for iP = 1:4
        if panelAvailability(iP)
            panelStatus(iP) = "INCLUDED";
        else
            panelStatus(iP) = "OMITTED";
        end
    end
    panelStatusTbl = table(panelId, string(panelNames(:)), panelStatus, string(panelKinds(:)), string(panelOmitReason(:)), ...
        'VariableNames', {'panel_id', 'panel_name', 'panel_status', 'panel_source_type', 'omitted_reason'});
    panelStatusPath = fullfile(tablesDir, [baseFigureName '_status.csv']);
    writetable(panelStatusTbl, panelStatusPath);

    consistencyTbl = table(residualParityRmse, fullParityRmse, ...
        'VariableNames', {'rmse_residual_vs_residual_percent', 'rmse_full_reconstruction_vs_s_model_full'});
    consistencyPath = fullfile(tablesDir, [baseFigureName '_consistency.csv']);
    writetable(consistencyTbl, consistencyPath);

    reportPath = fullfile(reportsDir, [baseFigureName '_report.md']);
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('run_switching_canonical_first_figure_anchor:ReportWriteFailed', ...
            'Failed to write report: %s', reportPath);
    end
    fprintf(fidReport, '# Canonical Switching First Figure (Anchor-Only, Tables-Only)\n\n');
    fprintf(fidReport, '- anchor_run_id: `%s`\n', anchorRunId);
    fprintf(fidReport, '- figure_fig: `%s`\n', figPath);
    fprintf(fidReport, '- figure_png: `%s`\n', pngPath);
    fprintf(fidReport, '- panel_status_table: `%s`\n', panelStatusPath);
    fprintf(fidReport, '- consistency_table: `%s`\n\n', consistencyPath);

    fprintf(fidReport, '## Canonical Inputs Used\n\n');
    fprintf(fidReport, '1. `%s`\n', sLongPath);
    fprintf(fidReport, '2. `%s`\n', phi1Path);
    fprintf(fidReport, '3. `%s`\n', obsPath);
    fprintf(fidReport, '4. `%s`\n\n', validationPath);

    fprintf(fidReport, '## Panel Provenance\n\n');
    fprintf(fidReport, '| panel | source_type | status |\n');
    fprintf(fidReport, '|---|---|---|\n');
    for iP = 1:4
        fprintf(fidReport, '| %s | %s | %s |\n', panelNames{iP}, panelKinds{iP}, panelStatus(iP));
    end
    fprintf(fidReport, '\n');

    omittedCount = sum(~panelAvailability);
    fprintf(fidReport, '## Omitted Panels\n\n');
    if omittedCount == 0
        fprintf(fidReport, '- None. All required panels were produced from canonical anchor tables.\n\n');
    else
        for iP = 1:4
            if ~panelAvailability(iP)
                fprintf(fidReport, '- %s: %s\n', panelNames{iP}, panelOmitReason{iP});
            end
        end
        fprintf(fidReport, '\n');
    end

    fprintf(fidReport, '## Constraint Compliance\n\n');
    fprintf(fidReport, '- ANCHOR_ONLY: YES\n');
    fprintf(fidReport, '- TABLES_ONLY: YES\n');
    fprintf(fidReport, '- NON_CANONICAL_SOURCE_USED: NO\n');
    fprintf(fidReport, '- WIDTH_OR_RIDGE_LOGIC_USED: NO\n');
    fprintf(fidReport, '- NON_ANCHOR_RUN_USED: NO\n');
    fprintf(fidReport, '- FIGURE_CREATED: YES\n\n');

    fprintf(fidReport, '## Notes\n\n');
    fprintf(fidReport, '- residual parity RMSE (derived residual vs residual_percent): `%0.12g`\n', residualParityRmse);
    fprintf(fidReport, '- full-model parity RMSE (Scdf + kappa1*phi1'' vs S_model_full_percent): `%0.12g`\n', fullParityRmse);
    fprintf(fidReport, '- validation rows loaded from switching_canonical_validation.csv: `%d`\n', height(validationTbl));
    fclose(fidReport);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, ...
        {sprintf('Created %s with %d/%d panels from anchor canonical tables.', baseFigureName, nPanelsIncluded, 4)}, true);

    fidBottomProbe = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottomProbe >= 0
        fprintf(fidBottomProbe, 'SCRIPT_COMPLETED\n');
        fclose(fidBottomProbe);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_first_figure_anchor_failure');
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

    failureStatusPath = fullfile(runDir, 'tables', [baseFigureName '_status.csv']);
    failureTbl = table((1:4)', ...
        ["Observed switching map S(I,T)"; "Canonical backbone map Scdf(I,T)"; "Residual map S-Scdf"; "Rank-1 reconstruction Scdf + kappa1*phi1'"], ...
        repmat("OMITTED", 4, 1), ...
        repmat("NOT_AVAILABLE_DUE_TO_FAILURE", 4, 1), ...
        repmat(string(ME.message), 4, 1), ...
        'VariableNames', {'panel_id', 'panel_name', 'panel_status', 'panel_source_type', 'omitted_reason'});
    writetable(failureTbl, failureStatusPath);

    failureReportPath = fullfile(runDir, 'reports', [baseFigureName '_report.md']);
    fidFail = fopen(failureReportPath, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# Canonical Switching First Figure - FAILED\n\n');
        fprintf(fidFail, '- error_id: `%s`\n', ME.identifier);
        fprintf(fidFail, '- error_message: `%s`\n', ME.message);
        fclose(fidFail);
    end

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, ...
        {'canonical first figure generation failed'}, true);
    rethrow(ME);
end
