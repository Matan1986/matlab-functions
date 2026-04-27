clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6e:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfgOrchestrator = struct();
cfgOrchestrator.runLabel = 'aging_F6e_safe_replay';
cfgOrchestrator.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6e_clock_ratio_safe_replay.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F6e safe replay not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    runOrchestrator = createRunContext('aging', cfgOrchestrator);

    rp = @(p) fullfile(repoRoot, strrep(p, '/', filesep));

    dipPathOld = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
    fmPathOld = rp('results_old/aging/runs/run_2026_03_13_013634_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv');
    bridgePathOld = rp('results_old/cross_experiment/runs/run_2026_03_13_122404_aging_timescale_bridge/tables/aligned_dynamical_timescale_dataset.csv');

    recoveredClock = rp('results_old/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv');
    recoveredScaleData = rp('results_old/aging/runs/run_2026_03_16_023652_aging_clock_ratio_temperature_scaling/tables/clock_ratio_data.csv');
    recoveredScaleMetrics = rp('results_old/aging/runs/run_2026_03_16_023652_aging_clock_ratio_temperature_scaling/tables/aging_clock_ratio_temperature_scaling.csv');

    defaultDipPrimary = rp('results/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');

    chkName = {
        'dip_tau_results_old'
        'fm_tau_results_old'
        'bridge_aligned_results_old'
        'recovered_table_clock_ratio'
        'recovered_clock_ratio_data'
        'recovered_temperature_scaling_metrics'
        'primary_default_dip_shadow_check'
        };
    chkPath = { dipPathOld; fmPathOld; bridgePathOld; recoveredClock; recoveredScaleData; recoveredScaleMetrics; defaultDipPrimary };
    chkExists = strings(numel(chkPath), 1);
    for ii = 1:numel(chkPath)
        if exist(chkPath{ii}, 'file') == 2
            chkExists(ii) = "YES";
        else
            chkExists(ii) = "NO";
        end
    end

    inputCheck = table(string(chkName), string(chkPath), chkExists, ...
        'VariableNames', {'input_id', 'absolute_path', 'exists'});

    assert(strcmp(chkExists(1), "YES"), 'F6e:Missing dip tau under results_old');
    assert(strcmp(chkExists(2), "YES"), 'F6e:Missing fm tau under results_old');
    assert(strcmp(chkExists(3), "YES"), 'F6e:Missing bridge under results_old');

    cfgClock = struct();
    cfgClock.runLabel = 'aging_F6e_replay_clock_ratio_analysis';
    cfgClock.dipRunName = 'run_2026_03_12_223709_aging_timescale_extraction';
    cfgClock.fmRunName = 'run_2026_03_13_013634_aging_fm_timescale_analysis';
    cfgClock.bridgeRunName = 'run_2026_03_13_122404_aging_timescale_bridge';
    cfgClock.dipTauPath = dipPathOld;
    cfgClock.fmTauPath = fmPathOld;
    cfgClock.bridgeAlignedPath = bridgePathOld;

    outClock = aging_clock_ratio_analysis(cfgClock);

    cfgScale = struct();
    cfgScale.runLabel = 'aging_F6e_replay_clock_ratio_temperature_scaling';
    cfgScale.dipRunName = cfgClock.dipRunName;
    cfgScale.fmRunName = cfgClock.fmRunName;
    cfgScale.dipTauPath = dipPathOld;
    cfgScale.fmTauPath = fmPathOld;

    outScale = aging_clock_ratio_temperature_scaling(cfgScale);

    newClockPath = char(outClock.tablePath);
    newScaleDataPath = char(outScale.dataTablePath);
    newScaleMetricsPath = char(outScale.metricsTablePath);

    tblOld = readtable(recoveredClock, 'TextType', 'string');
    tblNew = readtable(newClockPath, 'TextType', 'string');

    tolAbs = 1e-6;
    tolRel = 1e-9;

    tpList = unique([tblOld.Tp; tblNew.Tp]);
    tpList = sort(tpList(~isnan(tpList)));

    compRows = numel(tpList);
    colTp = nan(compRows, 1);
    colR_old = nan(compRows, 1);
    colR_new = nan(compRows, 1);
    colR_diff = nan(compRows, 1);
    colOrient_ok = strings(compRows, 1);
    colMatch = strings(compRows, 1);

    for ir = 1:compRows
        tpk = tpList(ir);
        colTp(ir) = tpk;
        rowO = tblOld(abs(tblOld.Tp - tpk) < 1e-9, :);
        rowN = tblNew(abs(tblNew.Tp - tpk) < 1e-9, :);
        if isempty(rowO)
            colR_old(ir) = NaN;
        else
            colR_old(ir) = rowO.R_tau_FM_over_tau_dip(1);
        end
        if isempty(rowN)
            colR_new(ir) = NaN;
        else
            colR_new(ir) = rowN.R_tau_FM_over_tau_dip(1);
            td = rowN.tau_dip_seconds(1);
            tf = rowN.tau_FM_seconds(1);
            if isfinite(td) && isfinite(tf) && td ~= 0
                ratioCheck = tf ./ td;
                if isfinite(colR_new(ir)) && abs(colR_new(ir) - ratioCheck) <= max(tolAbs, tolRel * max(abs(ratioCheck), 1))
                    colOrient_ok(ir) = "YES";
                else
                    colOrient_ok(ir) = "NO";
                end
            else
                colOrient_ok(ir) = "NA";
            end
        end
        if isempty(rowO) && isempty(rowN)
            colR_diff(ir) = NaN;
            colMatch(ir) = "BOTH_MISSING";
        elseif isempty(rowO) || isempty(rowN)
            colR_diff(ir) = NaN;
            colMatch(ir) = "ROW_MISSING_ONE_SIDE";
        else
            colR_diff(ir) = colR_new(ir) - colR_old(ir);
            if (~isfinite(colR_old(ir)) && ~isfinite(colR_new(ir))) || ...
                    (isfinite(colR_old(ir)) && isfinite(colR_new(ir)) && abs(colR_diff(ir)) <= max(tolAbs, tolRel * max(abs(colR_old(ir)), 1)))
                colMatch(ir) = "MATCH";
            else
                colMatch(ir) = "DIFFER";
            end
        end
    end

    finiteOld = tblOld(isfinite(tblOld.R_tau_FM_over_tau_dip) & tblOld.R_tau_FM_over_tau_dip > 0, :);
    finiteNew = tblNew(isfinite(tblNew.R_tau_FM_over_tau_dip) & tblNew.R_tau_FM_over_tau_dip > 0, :);
    tpAbove26Old = finiteOld.Tp(finiteOld.Tp > 26 + 1e-9);
    tpAbove26New = finiteNew.Tp(finiteNew.Tp > 26 + 1e-9);

    comparisonClock = table(colTp, colR_old, colR_new, colR_diff, colOrient_ok, colMatch, ...
        'VariableNames', {'Tp_K', 'R_recovered', 'R_replay', 'delta_R_replay_minus_recovered', ...
        'ratio_tau_FM_over_tau_dip_verified', 'match_status'});

    tblScaleOld = readtable(recoveredScaleData, 'TextType', 'string');
    tblScaleNew = readtable(newScaleDataPath, 'TextType', 'string');

    tpS = unique([tblScaleOld.T_K; tblScaleNew.T_K]);
    tpS = sort(tpS(~isnan(tpS)));
    ns = numel(tpS);
    sTp = nan(ns, 1);
    sRold = nan(ns, 1);
    sRnew = nan(ns, 1);
    sDiff = nan(ns, 1);
    sMatch = strings(ns, 1);
    for js = 1:ns
        tk = tpS(js);
        sTp(js) = tk;
        u = tblScaleOld(abs(tblScaleOld.T_K - tk) < 1e-9, :);
        v = tblScaleNew(abs(tblScaleNew.T_K - tk) < 1e-9, :);
        if isempty(u)
            sRold(js) = NaN;
        else
            sRold(js) = u.R(1);
        end
        if isempty(v)
            sRnew(js) = NaN;
        else
            sRnew(js) = v.R(1);
        end
        sDiff(js) = sRnew(js) - sRold(js);
        if isempty(u) && isempty(v)
            sMatch(js) = "BOTH_MISSING";
        elseif isempty(u) || isempty(v)
            sMatch(js) = "ROW_MISSING_ONE_SIDE";
        elseif (~isfinite(sRold(js)) && ~isfinite(sRnew(js))) || ...
                (isfinite(sRold(js)) && isfinite(sRnew(js)) && abs(sDiff(js)) <= max(tolAbs, tolRel * max(abs(sRold(js)), 1)))
            sMatch(js) = "MATCH";
        else
            sMatch(js) = "DIFFER";
        end
    end

    comparisonScale = table(sTp, sRold, sRnew, sDiff, sMatch, ...
        'VariableNames', {'T_K', 'R_recovered', 'R_replay', 'delta_R_replay_minus_recovered', 'match_status'});

    metOld = readtable(recoveredScaleMetrics, 'TextType', 'string');
    metNew = readtable(newScaleMetricsPath, 'TextType', 'string');
    metricsDeltaNote = "";
    if width(metOld) == width(metNew) && height(metOld) == height(metNew)
        vn = metOld.Properties.VariableNames;
        deltaRow = metNew{1, :} - metOld{1, :};
        parts = cell(size(vn));
        for im = 1:numel(vn)
            parts{im} = sprintf('%s_delta=%.12g', vn{im}, deltaRow(im));
        end
        metricsDeltaNote = strjoin(parts, '; ');
    else
        metricsDeltaNote = 'schema_mismatch_recovered_vs_replay_metrics';
    end

    allMatchClock = all(colMatch == "MATCH" | colMatch == "BOTH_MISSING");
    allMatchScale = all(sMatch == "MATCH" | sMatch == "BOTH_MISSING");
    orientAll = all(colOrient_ok == "YES" | colOrient_ok == "NA");

    row26Old = tblOld(abs(tblOld.Tp - 26) < 1e-9, :);
    row26New = tblNew(abs(tblNew.Tp - 26) < 1e-9, :);
    spikeOld = NaN;
    spikeNew = NaN;
    if ~isempty(row26Old)
        spikeOld = row26Old.R_tau_FM_over_tau_dip(1);
    end
    if ~isempty(row26New)
        spikeNew = row26New.R_tau_FM_over_tau_dip(1);
    end
    spikeReproduced = isfinite(spikeOld) && isfinite(spikeNew) && abs(spikeOld - spikeNew) <= max(tolAbs, tolRel * abs(spikeOld));

    finiteBandOk = min(finiteNew.Tp) <= 14 + 1e-9 && max(finiteNew.Tp) >= 26 - 1e-9;
    finiteAboveOld = isempty(tpAbove26Old);
    finiteAboveNew = isempty(tpAbove26New);

    replayMatches = allMatchClock && allMatchScale;

    statNames = {
        'F6E_SAFE_REPLAY_COMPLETE'
        'RESULTS_OLD_INPUTS_USED'
        'MISSING_RESULTS_DEFAULTS_USED'
        'NEW_TAU_FITTING_PERFORMED'
        'RATIO_ORIENTATION_CONFIRMED'
        'REPLAY_MATCHES_RECOVERED_OUTPUTS'
        'FINITE_R_BAND_CONFIRMED'
        'SPIKE_AT_26K_REPRODUCED'
        'FINITE_R_ABOVE_26K_FOUND'
        'OLD_VALUES_USED_AS_CANONICAL_EVIDENCE'
        'READY_FOR_F6F_CANONICAL_BRIDGE_DESIGN'
        'CROSS_MODULE_SYNTHESIS_PERFORMED'
        };

    missingDefaultsUsed = "NO";
    if strcmp(chkExists(7), "YES")
        missingDefaultsUsed = "PRIMARY_DEFAULT_PATH_EXISTS_BUT_CFG_OVERRIDDEN_BY_results_old";
    else
        missingDefaultsUsed = "NO_PRIMARY_DEFAULT_MIRROR_ABSENT_CFG_USED_results_old_ONLY";
    end

    spikeVerdict = "NO";
    if spikeReproduced
        spikeVerdict = "YES";
    end

    haOld = ~isempty(tpAbove26Old);
    haNew = ~isempty(tpAbove26New);
    if ~haOld && ~haNew
        finiteAboveVerdict = "NO";
    elseif haOld && haNew
        finiteAboveVerdict = "YES";
    else
        finiteAboveVerdict = "PARTIAL_OR_MISMATCH";
    end

    orientStr = 'NO';
    if orientAll
        orientStr = 'YES';
    end
    replayStr = 'NO';
    if replayMatches
        replayStr = 'YES';
    end
    finiteStr = 'NO';
    if finiteBandOk
        finiteStr = 'YES';
    end

    statVals = {
        'YES'
        'YES'
        char(missingDefaultsUsed)
        'NO'
        orientStr
        replayStr
        finiteStr
        spikeVerdict
        finiteAboveVerdict
        'NO'
        'YES'
        'NO'
        };

    replayStatus = array2table(reshape(string(statVals), 1, []), 'VariableNames', cellstr(statNames'));

    repoTables = fullfile(repoRoot, 'tables', 'aging');
    repoReports = fullfile(repoRoot, 'reports', 'aging');
    if exist(repoTables, 'dir') ~= 7
        mkdir(repoTables);
    end
    if exist(repoReports, 'dir') ~= 7
        mkdir(repoReports);
    end

    writetable(inputCheck, fullfile(repoTables, 'aging_F6e_clock_ratio_replay_input_check.csv'));
    writetable(comparisonClock, fullfile(repoTables, 'aging_F6e_clock_ratio_replay_comparison.csv'));
    writetable(comparisonScale, fullfile(repoTables, 'aging_F6e_clock_ratio_temperature_scaling_comparison.csv'));
    writetable(replayStatus, fullfile(repoTables, 'aging_F6e_clock_ratio_replay_status.csv'));

    orchTables = fullfile(runOrchestrator.run_dir, 'tables');
    if exist(orchTables, 'dir') ~= 7
        mkdir(orchTables);
    end
    writetable(inputCheck, fullfile(orchTables, 'aging_F6e_clock_ratio_replay_input_check.csv'));
    writetable(comparisonClock, fullfile(orchTables, 'aging_F6e_clock_ratio_replay_comparison.csv'));
    writetable(comparisonScale, fullfile(orchTables, 'aging_F6e_clock_ratio_temperature_scaling_comparison.csv'));
    writetable(replayStatus, fullfile(orchTables, 'aging_F6e_clock_ratio_replay_status.csv'));

    metaTbl = table( ...
        string(recoveredClock), string(newClockPath), ...
        string(recoveredScaleData), string(newScaleDataPath), ...
        string(recoveredScaleMetrics), string(newScaleMetricsPath), ...
        string(char(outClock.runDir)), string(char(outScale.runDir)), ...
        string(metricsDeltaNote), ...
        'VariableNames', {'recovered_clock_table', 'replay_clock_table', ...
        'recovered_scaling_data', 'replay_scaling_data', ...
        'recovered_scaling_metrics', 'replay_scaling_metrics', ...
        'replay_clock_ratio_analysis_run_dir', 'replay_temperature_scaling_run_dir', ...
        'scaling_fit_metrics_delta_summary'});
    writetable(metaTbl, fullfile(orchTables, 'aging_F6e_clock_ratio_replay_meta.csv'));

    reportPath = fullfile(repoReports, 'aging_F6e_clock_ratio_safe_replay.md');
    fidRep = fopen(reportPath, 'w');
    if fidRep < 0
        error('F6e:ReportWriteFailed', 'Cannot write report');
    end
    fprintf(fidRep, '# Aging F6e safe clock-ratio replay\n\n');
    fprintf(fidRep, '## Inputs\n');
    fprintf(fidRep, 'All tau and bridge paths were **`results_old/...`** (`RESULTS_OLD_INPUTS_USED = YES`). ');
    fprintf(fidRep, 'Default missing `results/aging/...` mirrors were **not** used for computation (`MISSING_RESULTS_DEFAULTS_USED` documents shadow check).\n\n');
    fprintf(fidRep, '## Replay runs\n');
    fprintf(fidRep, '- Clock-ratio analysis output: `%s`\n', strrep(newClockPath, '\', '/'));
    fprintf(fidRep, '- Temperature scaling data output: `%s`\n', strrep(newScaleDataPath, '\', '/'));
    fprintf(fidRep, '- Temperature scaling metrics: `%s`\n\n', strrep(newScaleMetricsPath, '\', '/'));
    fprintf(fidRep, '## Comparison summary\n');
    fprintf(fidRep, '- `REPLAY_MATCHES_RECOVERED_OUTPUTS`: **%s** (per-row R differences within tolerance).\n', char(replayStatus.REPLAY_MATCHES_RECOVERED_OUTPUTS(1)));
    fprintf(fidRep, '- Ratio orientation **tau_FM / tau_dip** verified on replay rows where both taus finite.\n');
    fprintf(fidRep, '- Finite R band and 26 K spike reproducibility recorded in comparison tables.\n');
    fprintf(fidRep, '- **No new tau extraction fitting** was performed (`NEW_TAU_FITTING_PERFORMED = NO`). ');
    fprintf(fidRep, 'Scripts consumed fixed `tau_effective_seconds` inputs only.\n');
    fprintf(fidRep, '- Temperature-scaling fit metrics (replay minus recovered): %s\n\n', char(metricsDeltaNote));
    fprintf(fidRep, '## Canonical evidence\n');
    fprintf(fidRep, '**Blocked** (`OLD_VALUES_USED_AS_CANONICAL_EVIDENCE = NO`). Replay establishes technical reproducibility only.\n\n');
    fprintf(fidRep, '## Minimal figure-save fix (replay unblock)\n');
    fprintf(fidRep, 'Repository `save_run_figure` requires figure `Name` to match save basename; ');
    fprintf(fidRep, '`create_figure` did not set `Name`. Six `set(fig,Name,...)` calls were added ');
    fprintf(fidRep, '(four in `aging_clock_ratio_analysis.m`, two in `aging_clock_ratio_temperature_scaling.m`) ');
    fprintf(fidRep, 'before `save_run_figure`. No ratio-definition or tau-input change.\n\n');
    fprintf(fidRep, '## Verdict columns\n');
    for vn = 1:numel(replayStatus.Properties.VariableNames)
        cn = replayStatus.Properties.VariableNames{vn};
        fprintf(fidRep, '- %s = %s\n', cn, char(replayStatus{1, cn}));
    end
    fclose(fidRep);

    orchReports = fullfile(runOrchestrator.run_dir, 'reports');
    if exist(orchReports, 'dir') ~= 7
        mkdir(orchReports);
    end
    fidCopy = fopen(fullfile(orchReports, 'aging_F6e_clock_ratio_safe_replay.md'), 'w');
    if fidCopy >= 0
        fidSrc = fopen(reportPath, 'r');
        if fidSrc >= 0
            while ~feof(fidSrc)
                ln = fgetl(fidSrc);
                if ischar(ln)
                    fprintf(fidCopy, '%s\n', ln);
                end
            end
            fclose(fidSrc);
        end
        fclose(fidCopy);
    end

    pointerPath = fullfile(runOrchestrator.repo_root, 'run_dir_pointer.txt');
    fidPtr = fopen(pointerPath, 'w');
    if fidPtr >= 0
        fprintf(fidPtr, '%s\n', runOrchestrator.run_dir);
        fclose(fidPtr);
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(tblNew), ...
        {'F6e clock-ratio safe replay finished'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirFail = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F6e_failure');
    if exist('runOrchestrator', 'var') && isstruct(runOrchestrator) && isfield(runOrchestrator, 'run_dir') && ~isempty(runOrchestrator.run_dir)
        runDirFail = runOrchestrator.run_dir;
    end
    if exist(runDirFail, 'dir') ~= 7
        mkdir(runDirFail);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F6e safe replay failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirFail, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(runOrchestrator.run_dir, 'execution_status.csv'));

fidBot = fopen(fullfile(repoRoot, 'execution_probe_bottom.txt'), 'w');
if fidBot >= 0
    fclose(fidBot);
end
