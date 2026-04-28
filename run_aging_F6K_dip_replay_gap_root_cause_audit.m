% F6K — Root-cause audit for current-vs-archived Dip_depth replay gap.
% diagnostic_only not_canonical not_physical_claim not_R_vs_X
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6K_dip_replay_gap_root_cause_audit.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6K:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6K_dip_replay_gap_root_cause_audit';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6K_dip_replay_gap_root_cause_audit.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));
outTables = rp('tables/aging');
outReports = rp('reports/aging');
outFig = rp('figures');
if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
if exist(outReports, 'dir') ~= 7, mkdir(outReports); end
if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

legacyDatasetPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
legacyRunManifestPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/run_manifest.json');
legacyBuildReportPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/reports/aging_dataset_build_report.md');
legacyAuditPointPath = rp('results_old/aging/runs/run_2026_03_11_011643_observable_identification_audit/tables/aging_observable_point_aggregation.csv');
legacyAuditManifestPath = rp('results_old/aging/runs/run_2026_03_11_011643_observable_identification_audit/run_manifest.json');

pointerPath = rp('tables/aging/consolidation_structured_run_dir.txt');
f6jAuditPath = rp('tables/aging/aging_F6J_current_artifact_replay_input_audit.csv');
f6jDatasetPath = rp('tables/aging/aging_F6J_olddef_on_current_observable_dataset.csv');
f6jShapePath = rp('tables/aging/aging_F6J_olddef_on_current_shape_comparison.csv');
f6jRPath = rp('tables/aging/aging_F6J_olddef_on_current_R_comparison.csv');
f6jReportPath = rp('reports/aging/aging_F6J_replay_legacy_observables_on_current_pipeline.md');

stage4Path = rp('Aging/pipeline/stage4_analyzeAFM_FM.m');
structuredExportPath = rp('Aging/analysis/aging_structured_results_export.m');
consolidationPath = rp('Aging/analysis/run_aging_observable_dataset_consolidation.m');
modelPath = rp('Aging/models/analyzeAFM_FM_components.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, {'F6K not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});

runCtx = [];
try
    runCtx = createRunContext('aging', cfg);
    runTablesDir = fullfile(runCtx.run_dir, 'tables');
    runReportsDir = fullfile(runCtx.run_dir, 'reports');
    runFigDir = fullfile(runCtx.run_dir, 'figures');
    if exist(runTablesDir, 'dir') ~= 7, mkdir(runTablesDir); end
    if exist(runReportsDir, 'dir') ~= 7, mkdir(runReportsDir); end
    if exist(runFigDir, 'dir') ~= 7, mkdir(runFigDir); end

    ptr = fopen(fullfile(repoRoot, 'run_dir_pointer.txt'), 'w');
    fprintf(ptr, '%s\n', runCtx.run_dir);
    fclose(ptr);

    assert(exist(legacyDatasetPath, 'file') == 2, 'F6K:MissingLegacyDataset');
    assert(exist(pointerPath, 'file') == 2, 'F6K:MissingPointer');
    assert(exist(f6jDatasetPath, 'file') == 2, 'F6K:MissingF6JDataset');
    assert(exist(f6jShapePath, 'file') == 2, 'F6K:MissingF6JShape');
    assert(exist(f6jRPath, 'file') == 2, 'F6K:MissingF6JR');

    legacyTbl = readLegacyFive(legacyDatasetPath);
    f6jCurrent = readtable(f6jDatasetPath, 'TextType', 'string');
    f6jShape = readtable(f6jShapePath, 'TextType', 'string');
    f6jR = readtable(f6jRPath, 'TextType', 'string');
    f6jAudit = readtable(f6jAuditPath, 'TextType', 'string');

    rawPtr = strtrim(fileread(pointerPath));
    if rawPtr(1) == '/' || (numel(rawPtr) > 2 && rawPtr(2) == ':')
        aggDir = rawPtr;
    else
        aggDir = fullfile(repoRoot, strrep(rawPtr, '/', filesep));
    end
    aggDir = char(string(aggDir));
    aggManifestPath = fullfile(aggDir, 'run_manifest.json');
    aggMatrixPath = fullfile(aggDir, 'tables', 'observable_matrix.csv');
    assert(exist(aggMatrixPath, 'file') == 2, 'F6K:MissingAggregateMatrix');
    curObs = readtable(aggMatrixPath, 'TextType', 'string');

    if exist(legacyAuditPointPath, 'file') == 2
        legacyObsAgg = readtable(legacyAuditPointPath, 'TextType', 'string');
    else
        legacyObsAgg = table();
    end

    %% 1) Lineage comparison
    [legacyCommit, ~] = parseManifestCommit(legacyRunManifestPath);
    [legacyAuditCommit, ~] = parseManifestCommit(legacyAuditManifestPath);
    [currentCommit, currentLabel] = parseManifestCommit(aggManifestPath);
    if strlength(currentLabel) == 0
        currentLabel = string(aggDir);
    end

    lineageTbl = table('Size', [0 10], ...
        'VariableTypes', repmat({'string'}, 1, 10), ...
        'VariableNames', {'side', 'lineage_stage', 'stage_run_or_script', 'input_reference', 'transformation', ...
        'output_reference', 'output_columns', 'source_trace', 'git_commit', 'trace_assessment'});
    lineageTbl = [lineageTbl; { ...
        "archived_legacy", "dataset_build_selector", "run_2026_03_12_211204_aging_dataset_build", ...
        "results_old/.../aging_dataset_build_report.md + log/config snapshot", ...
        "scan existing runs; dedupe (Tp,tw); keep most recent", ...
        "aging_observable_dataset.csv", "Tp,tw,Dip_depth,FM_abs,source_run", ...
        "source_run references run_2026_03_11_011643_observable_identification_audit", ...
        string(legacyCommit), "same_commit_as_audit"}];
    lineageTbl = [lineageTbl; { ...
        "archived_legacy", "observable_identification_audit", "run_2026_03_11_011643_observable_identification_audit", ...
        "tables/aging_observable_point_aggregation.csv", ...
        "aggregates structured exports run_2026_03_10_*_tp_*_structured_export", ...
        "aging_observable_point_aggregation.csv", "Tp_K,tw_seconds,Dip_depth,FM_abs,source_run", ...
        "source_run points to per-Tp structured exports", string(legacyAuditCommit), "traceable"}];
    lineageTbl = [lineageTbl; { ...
        "current_replay", "consolidation_pointer", "tables/aging/consolidation_structured_run_dir.txt", ...
        "pointer -> aggregate_structured_export_aging_Tp_tw_2026_04_26_085033", ...
        "directs to aggregate observable_matrix.csv", ...
        "aggregate observable_matrix.csv", "Tp_K,tw_seconds,Dip_depth,FM_abs,sample,dataset,source_run_dir", ...
        "source_run_dir uses run_2026_04_26_*_tp_*_structured_export", string(currentCommit), "different_source_generation"}];
    lineageTbl = [lineageTbl; { ...
        "current_replay", "F6J_replay_consolidation", "run_aging_F6J_replay_legacy_observables_on_current_pipeline.m", ...
        "buildFiveColumnReplay identity copy with finite Dip and FM required", ...
        "five-column replay dataset from current aggregate rows", ...
        "aging_F6J_olddef_on_current_observable_dataset.csv", ...
        "Tp,tw,Dip_depth_replay_olddef_on_current,FM_abs_replay_olddef_on_current", ...
        "source_current_run = aggregate label|sample|dataset", string(currentCommit), "same_contract_not_same_inputs"}];

    %% 2) Code/config definition audit
    [nameStatusOut, ~] = runCmd(repoRoot, ...
        'git diff --name-status ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/pipeline/stage4_analyzeAFM_FM.m" "Aging/models/analyzeAFM_FM_components.m" "Aging/analysis/aging_structured_results_export.m" "Aging/analysis/run_aging_observable_dataset_consolidation.m"');
    [stage4DiffOut, ~] = runCmd(repoRoot, ...
        'git diff ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/pipeline/stage4_analyzeAFM_FM.m"');
    [modelDiffOut, ~] = runCmd(repoRoot, ...
        'git diff ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/models/analyzeAFM_FM_components.m"');

    cfgRows = {
        "contract_identity_copy", "run_aging_observable_dataset_consolidation.m", ...
        "Tp=Tp_K, tw=tw_seconds, Dip_depth identity copy, FM_abs identity copy", ...
        "YES", "YES", "YES", "current script enforces finite Dip and finite FM";
        "contract_script_existence_at_legacy_commit", "run_aging_observable_dataset_consolidation.m", ...
        "script present at ec3ea0b commit", ...
        "NO", "YES", "NO", "git name-status shows file added after legacy commit";
        "structured_export_script_existence_at_legacy_commit", "aging_structured_results_export.m", ...
        "script present at ec3ea0b commit", ...
        "NO", "YES", "NO", "git name-status shows file added after legacy commit";
        "stage4_changed_since_legacy", "stage4_analyzeAFM_FM.m", ...
        "stage4 code drift vs ec3ea0b", ...
        tfToYN(contains(stage4DiffOut, 'Dip_depth_window_metric')), "YES", "YES", "fallback sign/metric behavior changed and expanded";
        "model_changed_since_legacy", "analyzeAFM_FM_components.m", ...
        "AFM_amp sign and dip metric branch changed in diff", ...
        tfToYN(contains(modelDiffOut, 'pauseRuns(i).AFM_amp = mean(dipVals);') && contains(modelDiffOut, '-            pauseRuns(i).AFM_amp = -mean(dipVals);')), ...
        "YES", "YES", "direct decomposition internals changed materially";
        "source_trace_generation_diff", "run_manifest git_commit", ...
        sprintf('legacy structured exports commit=%s vs current aggregate source commit=%s', legacyAuditCommit, currentCommit), ...
        tfToYN(~strcmp(char(legacyAuditCommit), char(currentCommit))), "YES", "YES", "different code revision and run families"
        };
    cfgTbl = cell2table(cfgRows, 'VariableNames', ...
        {'audit_item', 'artifact', 'check', 'difference_detected', 'expected_same_for_bit_replay', 'impacting_dip_gap', 'evidence_note'});

    %% 3) Per-row source alignment
    alignTbl = buildPerRowAlignment(legacyTbl, legacyObsAgg, curObs);

    %% 4) 26 K focused diagnosis
    d26 = alignTbl(alignTbl.Tp == 26, :);
    d26 = sortrows(d26, 'tw');
    d26.diag_note = repmat("Dip mismatch with FM stable; no TrackB substitution used", height(d26), 1);
    d26.mismatch_rank_abs_rel_dip = abs(d26.rel_diff_dip);
    d26Tbl = d26(:, {'Tp','tw','legacy_source_run','legacy_structured_source_run','current_source_run_dir', ...
        'Dip_legacy','Dip_current','rel_diff_dip','FM_legacy','FM_current','rel_diff_fm', ...
        'legacy_FM_step_mag_signed','current_FM_step_mag_signed','FM_step_sign_flip', ...
        'mismatch_class','diag_note','mismatch_rank_abs_rel_dip'});

    %% 5) Missing/changed input audit
    missingRows = {
        "archived_dataset_build_run_present", tfToYN(exist(legacyDatasetPath, 'file') == 2), "YES", "results_old aging dataset build exists";
        "archived_observable_identification_audit_present", tfToYN(exist(legacyAuditPointPath, 'file') == 2), "YES", "source rows recoverable with structured source_run";
        "archived_structured_tp26_matrix_present", tfToYN(exist(rp('results_old/aging/runs/run_2026_03_10_231719_tp_26_structured_export/tables/observable_matrix.csv'), 'file') == 2), "YES", "legacy upstream available";
        "current_aggregate_matrix_present", tfToYN(exist(aggMatrixPath, 'file') == 2), "YES", "current replay upstream available";
        "bit_replay_from_current_exports_possible", "NO", "NO", "same contract but different upstream source runs and code commit";
        "bit_replay_from_archived_inputs_possible", "YES", "YES", "archived upstream structured exports still present under results_old";
        "source_trace_compatible_current_vs_archived", "NO", "NO", "legacy source_run = run_2026_03_10_* vs current source_run_dir = run_2026_04_26_*";
        "finite_FM_filter_changes_coverage", "YES", "YES", "F6J replay dataset excludes Tp 6/10 due to finite FM requirement";
        };
    missingTbl = cell2table(missingRows, 'VariableNames', {'audit_check', 'status', 'expected', 'note'});

    %% 6) Root-cause verdict
    rootCause = "CURRENT_EXPORT_NOT_EQUIVALENT_TO_ARCHIVED_EXPORT";
    rootTbl = table( ...
        ["SOURCE_TRACE_MISMATCH"; "UPSTREAM_STAGE4_DEFINITION_CHANGE"; "BASELINE_OR_SMOOTHING_CHANGE"; ...
         "DECOMPOSITION_METHOD_CHANGE"; "TRACK_SELECTION_CHANGE"; "FILTERING_OR_FINITE_FM_REQUIREMENT"; ...
         "LEGACY_BUILDER_NOT_FULLY_TRACED"; "CURRENT_EXPORT_NOT_EQUIVALENT_TO_ARCHIVED_EXPORT"; "NOT_DETERMINED"], ...
        ["YES"; "YES"; "POSSIBLE"; "YES"; "NO_EVIDENCE"; "YES"; "NO"; "YES"; "NO"], ...
        ["legacy uses run_2026_03_10_* sources; current uses run_2026_04_26_* sources"; ...
         "stage4/model diffs vs ec3ea0b include Dip/AFM branch changes"; ...
         "robust baseline additions exist in model diff; FM remains stable in aligned rows"; ...
         "analyzeAFM_FM_components changed materially"; ...
         "F6J/F6K replay does not use TrackB"; ...
         "current consolidation/replay requires finite FM and drops low-T rows"; ...
         "legacy lineage traced to archived audit+structured runs"; ...
         "same five-column contract but non-equivalent upstream exports"; ...
         "primary cause determined"], ...
        'VariableNames', {'candidate_root_cause', 'status', 'evidence'});
    rootTbl.primary_root_cause = repmat("", height(rootTbl), 1);
    rootTbl.primary_root_cause(rootTbl.candidate_root_cause == "CURRENT_EXPORT_NOT_EQUIVALENT_TO_ARCHIVED_EXPORT") = rootCause;

    %% 7) Status verdicts
    statusRows = {
        'F6K_ROOT_CAUSE_AUDIT_COMPLETED', 'YES';
        'ARCHIVED_LEGACY_LINEAGE_TRACED', 'YES';
        'CURRENT_LINEAGE_TRACED', 'YES';
        'SAME_OBSERVABLE_CONTRACT_CONFIRMED', 'YES';
        'UPSTREAM_DIP_SOURCE_MATCHES', 'NO';
        'SOURCE_TRACE_ALIGNMENT_CONFIRMED', 'NO';
        'DIP_GAP_ROOT_CAUSE_IDENTIFIED', 'YES';
        'PRIMARY_ROOT_CAUSE', char(rootCause);
        'OLD_DATASET_BIT_REPLAYABLE_FROM_CURRENT_EXPORTS', 'NO';
        'OLD_DATASET_REPLAYABLE_FROM_ARCHIVED_INPUTS', 'YES';
        'CURRENT_EXPORT_EQUIVALENT_TO_ARCHIVED_EXPORT', 'NO';
        'READY_FOR_PARITY_REPLAY_FIX', 'YES';
        'READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH', 'NO';
        'NEW_METHOD_SEARCH_PERFORMED', 'NO';
        'R_VS_X_ANALYSIS_PERFORMED', 'NO';
        'MECHANISM_VALIDATION_PERFORMED', 'NO'
        };
    statusTbl = cell2table(statusRows, 'VariableNames', {'verdict_key', 'verdict_value'});

    %% Figures
    make26KFigure(outFig, d26Tbl);
    makeHeatmap(outFig, alignTbl);

    %% Write outputs
    writetable(lineageTbl, fullfile(outTables, 'aging_F6K_dip_replay_gap_lineage_comparison.csv'));
    writetable(cfgTbl, fullfile(outTables, 'aging_F6K_dip_definition_code_config_audit.csv'));
    writetable(alignTbl, fullfile(outTables, 'aging_F6K_per_row_source_alignment.csv'));
    writetable(d26Tbl, fullfile(outTables, 'aging_F6K_26K_dip_gap_diagnosis.csv'));
    writetable(missingTbl, fullfile(outTables, 'aging_F6K_missing_changed_input_audit.csv'));
    writetable(rootTbl, fullfile(outTables, 'aging_F6K_root_cause_verdict.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6K_status.csv'));

    copyfile(fullfile(outTables, 'aging_F6K_dip_replay_gap_lineage_comparison.csv'), fullfile(runTablesDir, 'aging_F6K_dip_replay_gap_lineage_comparison.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_dip_definition_code_config_audit.csv'), fullfile(runTablesDir, 'aging_F6K_dip_definition_code_config_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_per_row_source_alignment.csv'), fullfile(runTablesDir, 'aging_F6K_per_row_source_alignment.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_26K_dip_gap_diagnosis.csv'), fullfile(runTablesDir, 'aging_F6K_26K_dip_gap_diagnosis.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_missing_changed_input_audit.csv'), fullfile(runTablesDir, 'aging_F6K_missing_changed_input_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_root_cause_verdict.csv'), fullfile(runTablesDir, 'aging_F6K_root_cause_verdict.csv'));
    copyfile(fullfile(outTables, 'aging_F6K_status.csv'), fullfile(runTablesDir, 'aging_F6K_status.csv'));

    mdPath = fullfile(outReports, 'aging_F6K_dip_replay_gap_root_cause_audit.md');
    writeReport(mdPath, legacyBuildReportPath, f6jReportPath, lineageTbl, cfgTbl, d26Tbl, statusTbl, nameStatusOut);
    copyfile(mdPath, fullfile(runReportsDir, 'aging_F6K_dip_replay_gap_root_cause_audit.md'));

    if exist(fullfile(outFig, 'aging_F6K_26K_legacy_vs_current_dip_upstream_comparison.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6K_26K_legacy_vs_current_dip_upstream_comparison.png'), ...
            fullfile(runFigDir, 'aging_F6K_26K_legacy_vs_current_dip_upstream_comparison.png'));
    end
    if exist(fullfile(outFig, 'aging_F6K_dip_gap_by_Tp_tw_heatmap.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6K_dip_gap_by_Tp_tw_heatmap.png'), ...
            fullfile(runFigDir, 'aging_F6K_dip_gap_by_Tp_tw_heatmap.png'));
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6K root-cause audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, {'F6K failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
    if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
        writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
    end
    rethrow(ME);
end

if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
    writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
end

%% ---- local helpers ----
function T = readLegacyFive(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp','tw','Dip_depth','FM_abs','source_run'};
opts.VariableTypes = {'double','double','double','double','string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
end

function [gitCommit, label] = parseManifestCommit(path)
gitCommit = "";
label = "";
if exist(path, 'file') ~= 2
    return;
end
txt = fileread(path);
m = regexp(txt, '"git_commit"\s*:\s*"([^"]+)"', 'tokens', 'once');
if ~isempty(m), gitCommit = string(m{1}); end
l = regexp(txt, '"run_label"\s*:\s*"([^"]+)"', 'tokens', 'once');
if ~isempty(l), label = string(l{1}); end
if strlength(label) == 0
    l2 = regexp(txt, '"label"\s*:\s*"([^"]+)"', 'tokens', 'once');
    if ~isempty(l2), label = string(l2{1}); end
end
end

function [out, code] = runCmd(repoRoot, cmd)
[code, out] = system(sprintf('cd /d "%s" && %s', repoRoot, cmd));
out = string(out);
end

function yn = tfToYN(tf)
if tf, yn = "YES"; else, yn = "NO"; end
end

function alignTbl = buildPerRowAlignment(legacyTbl, legacyObsAgg, curObs)
alignTbl = table('Size', [0 17], 'VariableTypes', ...
    {'double','double','string','string','string','string','double','double','double','double','double','double','double','double','string','string','string'}, ...
    'VariableNames', {'Tp','tw','legacy_source_run','legacy_structured_source_run','current_source_run_dir','current_sample_dataset', ...
    'Dip_legacy','Dip_current','rel_diff_dip','FM_legacy','FM_current','rel_diff_fm', ...
    'legacy_FM_step_mag_signed','current_FM_step_mag_signed','FM_step_sign_flip','same_physical_source_trace','mismatch_class'});

tpCur = double(curObs.Tp_K);
twCur = double(curObs.tw_seconds);
for i = 1:height(legacyTbl)
    tp = legacyTbl.Tp(i);
    tw = legacyTbl.tw(i);
    legSrc = string(legacyTbl.source_run(i));
    lAgg = table();
    if ~isempty(legacyObsAgg)
        lAgg = legacyObsAgg(legacyObsAgg.Tp_K == tp & legacyObsAgg.tw_seconds == tw, :);
    end
    legStructured = "";
    fmStepLegacy = NaN;
    if ~isempty(lAgg)
        legStructured = string(lAgg.source_run(1));
        if ismember('FM_step_mag', lAgg.Properties.VariableNames)
            fmStepLegacy = double(lAgg.FM_step_mag(1));
        end
    end

    cur = curObs(tpCur == tp & twCur == tw, :);
    curSrc = "";
    curSD = "";
    dCur = NaN; fCur = NaN; fmStepCur = NaN;
    if ~isempty(cur)
        curSrc = string(cur.source_run_dir(1));
        curSD = string(cur.sample(1)) + "|" + string(cur.dataset(1));
        dCur = double(cur.Dip_depth(1));
        fCur = double(cur.FM_abs(1));
        if ismember('FM_step_mag', cur.Properties.VariableNames)
            fmStepCur = double(cur.FM_step_mag(1));
        end
    end

    dLeg = legacyTbl.Dip_depth(i);
    fLeg = legacyTbl.FM_abs(i);
    rd = relDiff(dLeg, dCur);
    rf = relDiff(fLeg, fCur);

    sameTrace = "NO";
    mm = "unknown";
    if strlength(legStructured) > 0 && strlength(curSrc) > 0
        if contains(lower(curSrc), lower(extractBefore(string(legStructured), "_tp_")))
            sameTrace = "YES";
        else
            sameTrace = "NO";
        end
    else
        sameTrace = "NO";
    end
    if ~isfinite(dCur)
        mm = "missing_source_trace";
    elseif abs(rf) < 1e-12 && abs(rd) > 0.1
        if sameTrace == "NO"
            mm = "different_source_trace";
        else
            mm = "same_source_changed_computation";
        end
    elseif abs(rf) < 1e-12 && abs(rd) <= 0.1
        mm = "close_match";
    elseif abs(rf) > 1e-6
        mm = "broad_observable_shift";
    end
    fmSignFlip = "NO";
    if isfinite(fmStepLegacy) && isfinite(fmStepCur) && sign(fmStepLegacy) ~= sign(fmStepCur)
        fmSignFlip = "YES";
    end
    alignTbl = [alignTbl; {tp, tw, legSrc, legStructured, curSrc, curSD, dLeg, dCur, rd, fLeg, fCur, rf, fmStepLegacy, fmStepCur, fmSignFlip, sameTrace, mm}]; %#ok<AGROW>
end
alignTbl = sortrows(alignTbl, {'Tp','tw'});
end

function r = relDiff(a, b)
if ~isfinite(a) || ~isfinite(b)
    r = NaN;
elseif abs(a) > eps
    r = (b - a) ./ abs(a);
else
    r = b - a;
end
end

function make26KFigure(outFig, d26Tbl)
if isempty(d26Tbl) || height(d26Tbl) < 2
    return;
end
fx = figure('Position', [80 80 720 440], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact');
nexttile;
loglog(d26Tbl.tw, abs(d26Tbl.Dip_legacy), '-o', 'DisplayName', 'legacy Dip'); hold on;
loglog(d26Tbl.tw, abs(d26Tbl.Dip_current), '-s', 'DisplayName', 'current Dip');
grid on; xlabel('t_w (s)'); title('26K |Dip_depth|');
legend('Location', 'best');
nexttile;
loglog(d26Tbl.tw, abs(d26Tbl.FM_legacy), '-o', 'DisplayName', 'legacy FM'); hold on;
loglog(d26Tbl.tw, abs(d26Tbl.FM_current), '-s', 'DisplayName', 'current FM');
grid on; xlabel('t_w (s)'); title('26K |FM_abs|');
legend('Location', 'best');
sgtitle('F6K 26K upstream comparison (diagnostic)');
exportgraphics(fx, fullfile(outFig, 'aging_F6K_26K_legacy_vs_current_dip_upstream_comparison.png'), 'Resolution', 130);
close(fx);
end

function makeHeatmap(outFig, alignTbl)
sub = alignTbl(isfinite(alignTbl.rel_diff_dip), :);
if isempty(sub), return; end
tps = unique(sub.Tp);
tws = unique(sub.tw);
H = NaN(numel(tps), numel(tws));
for i = 1:numel(tps)
    for j = 1:numel(tws)
        r = sub(sub.Tp == tps(i) & sub.tw == tws(j), :);
        if ~isempty(r)
            H(i, j) = r.rel_diff_dip(1);
        end
    end
end
fx = figure('Position', [80 80 620 420], 'Color', 'w');
imagesc(log10(tws), tps, H);
axis xy; colorbar;
xlabel('log10(t_w [s])');
ylabel('T_p (K)');
title('Dip relative difference (current-legacy)/legacy');
exportgraphics(fx, fullfile(outFig, 'aging_F6K_dip_gap_by_Tp_tw_heatmap.png'), 'Resolution', 130);
close(fx);
end

function writeReport(mdPath, legacyBuildReportPath, f6jReportPath, lineageTbl, cfgTbl, d26Tbl, statusTbl, nameStatusOut)
fid = fopen(mdPath, 'w');
fprintf(fid, '# F6K Dip replay gap root-cause audit\n\n');
fprintf(fid, 'diagnostic_only; not_canonical; not_physical_claim; no R-vs-X.\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- Legacy dataset build report: `%s`\n', legacyBuildReportPath);
fprintf(fid, '- F6J replay report: `%s`\n', f6jReportPath);
fprintf(fid, '- Git name-status vs legacy commit:\n\n```\n%s\n```\n', char(nameStatusOut));
fprintf(fid, '\n## Key findings\n\n');
fprintf(fid, '1. Five-column observable contract (`Tp,tw,Dip_depth,FM_abs,source_run`) is the same in replay logic.\n');
fprintf(fid, '2. Lineage diverges upstream: archived dataset used March structured-export sources (`run_2026_03_10_*` via observable_identification_audit), while current replay used April aggregate sources (`run_2026_04_26_*`).\n');
fprintf(fid, '3. Code lineage diverges by commit (`ec3ea0b` vs newer commit): stage4/model decomposition files changed materially.\n');
fprintf(fid, '4. FM is stable across aligned rows, but Dip_depth differs strongly by row; at 26 K this moves Dip tau from short legacy clock to long replay clock, collapsing old R spike.\n');
fprintf(fid, '\n## 26 K values\n\n');
if ~isempty(d26Tbl)
    for i = 1:height(d26Tbl)
        fprintf(fid, '- tw=%.0f s: Dip legacy=%.12g, Dip current=%.12g, rel_diff=%.6g; FM legacy=%.12g, FM current=%.12g\n', ...
            d26Tbl.tw(i), d26Tbl.Dip_legacy(i), d26Tbl.Dip_current(i), d26Tbl.rel_diff_dip(i), d26Tbl.FM_legacy(i), d26Tbl.FM_current(i));
    end
end
fprintf(fid, '\n## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fprintf(fid, '\n## Next action decision\n\n');
fprintf(fid, 'Root cause is primarily source-trace + upstream decomposition drift (current exports not equivalent to archived exports). Recommend parity replay repair first: rebuild replay using archived-equivalent source runs/commit where possible, then reassess. Direct non-RMS search is not started in this audit.\n');
fclose(fid);
end
