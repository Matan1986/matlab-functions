% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — collapse breakdown audit on canonical/legacy inputs per script configuration
% EVIDENCE_STATUS: AUDIT_ONLY — not OLD_FULL_SCALING parameters export unless labeled
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
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
    cfg.runLabel = 'switching_collapse_breakdown_analysis';
    cfg.dataset = 'canonical_collapse_failure_analysis';
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

    scalingPath = fullfile(repoRoot, 'tables', 'switching_scaling_canonical_test.csv');
    transitionPath = fullfile(repoRoot, 'tables', 'switching_transition_detection.csv');
    if exist(scalingPath, 'file') ~= 2 || exist(transitionPath, 'file') ~= 2
        error('run_switching_collapse_breakdown_analysis:MissingInput', ...
            'Missing required input tables: switching_scaling_canonical_test.csv and/or switching_transition_detection.csv');
    end
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    if exist(sLongPath, 'file') ~= 2
        error('run_switching_collapse_breakdown_analysis:MissingSLong', 'Missing canonical S_long table.');
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    try
        mScale = validateCanonicalInputTable(scalingPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_scaling_canonical_test.csv', 'expected_role', 'collapse_scaling_input')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_scaling_canonical_test.csv', scalingPath, 'PASS', '', '', char(mScale.metadata_path));
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_scaling_canonical_test.csv', scalingPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [scalingPath '.meta.json']);
        rethrow(MEv);
    end
    try
        mTr = validateCanonicalInputTable(transitionPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_transition_detection.csv', 'expected_role', 'transition_derived')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_transition_detection.csv', transitionPath, 'PASS', '', '', char(mTr.metadata_path));
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_transition_detection.csv', transitionPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [transitionPath '.meta.json']);
        rethrow(MEv);
    end
    try
        mS = validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'PASS', '', '', char(mS.metadata_path));
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [sLongPath '.meta.json']);
        rethrow(MEv);
    end

    scaleTbl = readtable(scalingPath);
    trTbl = readtable(transitionPath);
    sLong = readtable(sLongPath);

    reqScale = {'T_K','width_used','I_peak','S_peak','rmse_to_mean'};
    for i = 1:numel(reqScale)
        if ~ismember(reqScale{i}, scaleTbl.Properties.VariableNames)
            error('run_switching_collapse_breakdown_analysis:BadScaleSchema', ...
                'switching_scaling_canonical_test.csv missing %s', reqScale{i});
        end
    end
    reqTr = {'T_K','rank1_energy','rank2_increment','kappa2','transition_flag'};
    for i = 1:numel(reqTr)
        if ~ismember(reqTr{i}, trTbl.Properties.VariableNames)
            error('run_switching_collapse_breakdown_analysis:BadTransitionSchema', ...
                'switching_transition_detection.csv missing %s', reqTr{i});
        end
    end
    reqS = {'T_K','current_mA','S_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_collapse_breakdown_analysis:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing %s', reqS{i});
        end
    end

    Tscale = double(scaleTbl.T_K);
    widthUsed = double(scaleTbl.width_used);
    Ipeak = double(scaleTbl.I_peak);
    Speak = double(scaleTbl.S_peak);
    collapseErrMetric = double(scaleTbl.rmse_to_mean);

    Ttr = double(trTbl.T_K);
    rank1E = double(trTbl.rank1_energy);
    rank2Inc = double(trTbl.rank2_increment);
    kappa2 = double(trTbl.kappa2);
    trFlag = string(trTbl.transition_flag);

    commonT = intersect(Tscale, Ttr);
    commonT = sort(commonT(:));
    nT = numel(commonT);
    if nT < 4
        error('run_switching_collapse_breakdown_analysis:TooFewTemps', 'Not enough overlapping temperatures for analysis.');
    end

    % Build normalized collapse curves using existing scaling parameters.
    xGrid = linspace(-3, 3, 241)';
    Y = NaN(nT, numel(xGrid));
    for it = 1:nT
        t = commonT(it);
        isIdx = find(abs(Tscale - t) < 1e-9, 1);
        if isempty(isIdx), continue; end
        w = widthUsed(isIdx);
        ip = Ipeak(isIdx);
        sp = Speak(isIdx);
        if ~(isfinite(w) && w > 0 && isfinite(ip) && isfinite(sp) && sp > 0)
            continue;
        end

        m = abs(double(sLong.T_K) - t) < 1e-9;
        cur = double(sLong.current_mA(m));
        sig = double(sLong.S_percent(m));
        v = isfinite(cur) & isfinite(sig);
        if nnz(v) < 4, continue; end
        cur = cur(v); sig = sig(v);

        x = (cur - ip) ./ w;
        y = sig ./ sp;
        [x, iu] = unique(x(:), 'stable');
        y = y(iu);
        if numel(x) < 3, continue; end
        Y(it, :) = interp1(x, y, xGrid, 'linear', NaN);
    end

    meanCurve = mean(Y, 1, 'omitnan');
    devMap = Y - meanCurve;

    totalErr = NaN(nT, 1);
    centerErr = NaN(nT, 1);
    tailErr = NaN(nT, 1);
    centerMask = abs(xGrid) <= 0.6;
    tailMask = abs(xGrid) >= 1.0;
    for it = 1:nT
        d = devMap(it, :);
        totalErr(it) = sqrt(mean(d.^2, 'omitnan'));
        centerErr(it) = sqrt(mean(d(centerMask).^2, 'omitnan'));
        tailErr(it) = sqrt(mean(d(tailMask).^2, 'omitnan'));
    end

    % Step 1 table: global collapse quality vs T.
    globalRMSE = sqrt(mean(totalErr.^2, 'omitnan'));
    errVsTTbl = table(commonT, totalErr, repmat(globalRMSE, nT, 1), ...
        'VariableNames', {'T_K','collapse_error_metric','global_collapse_RMSE'});

    % Step 2 local breakdown table.
    localTbl = table(commonT, totalErr, centerErr, tailErr, ...
        'VariableNames', {'T_K','total_error','center_error','tail_error'});

    % Step 3 + 4 linkage analysis.
    trIdx = zeros(nT,1);
    rank1Local = NaN(nT,1);
    rank2Local = NaN(nT,1);
    kappa2Local = NaN(nT,1);
    flagLocal = strings(nT,1);
    for it = 1:nT
        j = find(abs(Ttr - commonT(it)) < 1e-9, 1);
        if isempty(j), continue; end
        trIdx(it) = j;
        rank1Local(it) = rank1E(j);
        rank2Local(it) = rank2Inc(j);
        kappa2Local(it) = kappa2(j);
        flagLocal(it) = trFlag(j);
    end

    vLink = isfinite(totalErr) & isfinite(rank1Local) & isfinite(rank2Local) & isfinite(kappa2Local);
    corrErrRank1 = NaN; corrErrRank2 = NaN; corrErrK2 = NaN;
    if nnz(vLink) >= 4
        corrErrRank1 = corr(totalErr(vLink), rank1Local(vLink), 'Type', 'Spearman', 'Rows', 'complete');
        corrErrRank2 = corr(totalErr(vLink), rank2Local(vLink), 'Type', 'Spearman', 'Rows', 'complete');
        corrErrK2 = corr(totalErr(vLink), abs(kappa2Local(vLink)), 'Type', 'Spearman', 'Rows', 'complete');
    end

    preMask = commonT < 24;
    transMask = commonT >= 24 & commonT < 31.5;
    postMask = commonT >= 31.5;
    preMean = mean(totalErr(preMask), 'omitnan');
    transMean = mean(totalErr(transMask), 'omitnan');
    postMean = mean(totalErr(postMask), 'omitnan');

    breaksAtTransition = transMean > 1.2 * max(preMean, eps);
    fullyBrokenPost = postMean > 1.5 * max(preMean, eps);

    centerTailLabel = "BOTH";
    if mean(centerErr, 'omitnan') > 1.2 * mean(tailErr, 'omitnan')
        centerTailLabel = "CENTER";
    elseif mean(tailErr, 'omitnan') > 1.2 * mean(centerErr, 'omitnan')
        centerTailLabel = "TAIL";
    end

    failExplainedMode2 = "NO";
    if isfinite(corrErrRank2) && isfinite(corrErrK2)
        if corrErrRank2 >= 0.6 && corrErrK2 >= 0.6
            failExplainedMode2 = "YES";
        elseif corrErrRank2 >= 0.35 || corrErrK2 >= 0.35
            failExplainedMode2 = "PARTIAL";
        else
            failExplainedMode2 = "NO";
        end
    end

    collapseValidGlobal = globalRMSE < 0.12;
    supportsLowDim = "PARTIAL";
    if collapseValidGlobal && strcmp(failExplainedMode2, "NO")
        supportsLowDim = "YES";
    elseif ~collapseValidGlobal && strcmp(failExplainedMode2, "YES")
        supportsLowDim = "PARTIAL";
    elseif ~collapseValidGlobal
        supportsLowDim = "NO";
    end

    % Optional linkage table for traceability.
    linkTbl = table(commonT, totalErr, rank1Local, rank2Local, kappa2Local, flagLocal, ...
        'VariableNames', {'T_K','collapse_error','rank1_energy','rank2_increment','kappa2','transition_flag'});

    % Figures (mandatory).
    fig1 = fullfile(runFigures, 'switching_collapse_curves_allT.png');
    h1 = figure('Visible','off','Color','w','Position',[100 100 1200 700]);
    hold on;
    for it = 1:nT
        plot(xGrid, Y(it,:), 'LineWidth', 1.0);
    end
    plot(xGrid, meanCurve, 'k-', 'LineWidth', 2.4);
    grid on;
    xlabel('(I - I_{peak}) / width');
    ylabel('S / S_{peak}');
    title('Collapsed Curves Across Temperatures');
    exportgraphics(h1, fig1, 'Resolution', 300);
    close(h1);

    fig2 = fullfile(runFigures, 'switching_collapse_deviation_map.png');
    h2 = figure('Visible','off','Color','w','Position',[100 100 1200 600]);
    imagesc(xGrid, commonT, devMap);
    set(gca, 'YDir', 'normal');
    colorbar;
    xlabel('(I - I_{peak}) / width');
    ylabel('T (K)');
    title('Collapse Deviation Map (curve - mean collapsed curve)');
    exportgraphics(h2, fig2, 'Resolution', 300);
    close(h2);

    fig3 = fullfile(runFigures, 'switching_collapse_error_vs_mode_metrics.png');
    h3 = figure('Visible','off','Color','w','Position',[100 100 1200 700]);
    plot(commonT, switchingZscoreSafe(totalErr), '-o', 'LineWidth', 1.8); hold on;
    plot(commonT, switchingZscoreSafe(abs(kappa2Local)), '-s', 'LineWidth', 1.8);
    plot(commonT, switchingZscoreSafe(rank1Local), '-^', 'LineWidth', 1.8);
    grid on;
    xlabel('T (K)');
    ylabel('z-score');
    title('Collapse Error vs kappa2 and rank1\_energy');
    legend({'collapse error','|kappa2|','rank1\_energy'}, 'Location', 'best');
    exportgraphics(h3, fig3, 'Resolution', 300);
    close(h3);

    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        nT, ...
        string(sprintf('globalRMSE=%.6g;corrErrRank1=%.3f;corrErrRank2=%.3f;corrErrK2=%.3f', ...
            globalRMSE, corrErrRank1, corrErrRank2, corrErrK2)), ...
        string(strjoin(string({fig1, fig2, fig3}), '; ')), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures_used','execution_notes','figures_written'});

    report = {};
    report{end+1} = '# Canonical Collapse Breakdown Analysis';
    report{end+1} = '';
    report{end+1} = '## Global Collapse Quality';
    report{end+1} = sprintf('- global collapse RMSE: %.6g', globalRMSE);
    report{end+1} = '';
    report{end+1} = '## Local Breakdown';
    report{end+1} = sprintf('- mean center error: %.6g', mean(centerErr, 'omitnan'));
    report{end+1} = sprintf('- mean tail error: %.6g', mean(tailErr, 'omitnan'));
    report{end+1} = sprintf('- dominant breakdown region: %s', centerTailLabel);
    report{end+1} = '';
    report{end+1} = '## Transition Alignment';
    report{end+1} = sprintf('- pre-transition mean error: %.6g', preMean);
    report{end+1} = sprintf('- transition-window mean error: %.6g', transMean);
    report{end+1} = sprintf('- post-31.5 mean error: %.6g', postMean);
    report{end+1} = '';
    report{end+1} = '## Rank Connection';
    report{end+1} = sprintf('- Spearman(collapse_error, rank1_energy) = %.6g', corrErrRank1);
    report{end+1} = sprintf('- Spearman(collapse_error, rank2_increment) = %.6g', corrErrRank2);
    report{end+1} = sprintf('- Spearman(collapse_error, |kappa2|) = %.6g', corrErrK2);
    report{end+1} = '';
    report{end+1} = '## Figures';
    report{end+1} = sprintf('- `%s`', fig1);
    report{end+1} = sprintf('- `%s`', fig2);
    report{end+1} = sprintf('- `%s`', fig3);
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- COLLAPSE_VALID_GLOBALLY = %s', switchingYesNoLabel(collapseValidGlobal));
    report{end+1} = sprintf('- COLLAPSE_BREAKS_AT_TRANSITION = %s', switchingYesNoLabel(breaksAtTransition));
    report{end+1} = sprintf('- COLLAPSE_BREAKS_IN_TAILS_OR_CENTER = %s', centerTailLabel);
    report{end+1} = sprintf('- COLLAPSE_FAILURE_EXPLAINED_BY_MODE2 = %s', failExplainedMode2);
    report{end+1} = sprintf('- COLLAPSE_SUPPORTS_LOW_DIMENSIONAL_MODEL = %s', supportsLowDim);
    report{end+1} = sprintf('- post31_5_fully_broken_indicator = %s', switchingYesNoLabel(fullyBrokenPost));

    switchingWriteTableBothPaths(errVsTTbl, repoRoot, runTables, 'switching_collapse_error_vs_T.csv');
    switchingWriteTableBothPaths(localTbl, repoRoot, runTables, 'switching_collapse_local_breakdown.csv');
    switchingWriteTableBothPaths(linkTbl, repoRoot, runTables, 'switching_collapse_rank_connection.csv');
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_collapse_breakdown_status.csv');
    gateTbl = switchingInputGateRowsToTable(gateRows);
    switchingWriteTableBothPaths(gateTbl, repoRoot, runTables, 'switching_canonical_input_gate_status.csv');
    switchingWriteTextLinesFile(fullfile(runReports, 'switching_collapse_breakdown_analysis.md'), report, 'run_switching_collapse_breakdown_analysis:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_collapse_breakdown_analysis.md'), report, 'run_switching_collapse_breakdown_analysis:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching collapse breakdown analysis completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_collapse_breakdown_analysis_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), string('NO'), 0, string(ME.message), string(''), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures_used','execution_notes','figures_written'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_collapse_breakdown_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_collapse_breakdown_status.csv'));
    failCode = string(ME.identifier);
    if strlength(failCode) == 0
        failCode = "UNSPECIFIED_ERROR";
    end
    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(failCode), char(string(ME.message)), '');
    else
        if ~any(gateRows.validation_status == "FAIL")
            gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(failCode), char(string(ME.message)), '');
        end
    end
    gateTbl = switchingInputGateRowsToTable(gateRows);
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_canonical_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_canonical_input_gate_status.csv'));
    lines = {};
    lines{end+1} = '# Canonical Collapse Breakdown Analysis FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', 'switching_collapse_breakdown_analysis.md'), lines, 'run_switching_collapse_breakdown_analysis:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_collapse_breakdown_analysis.md'), lines, 'run_switching_collapse_breakdown_analysis:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching collapse breakdown analysis failed'}, true);
    rethrow(ME);
end
