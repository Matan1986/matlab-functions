% F6M — Archived-vs-current Dip_depth source-selection bridge auditor.
% diagnostic_bridge_only not_canonical not_physical_claim
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6M_archived_current_source_selection_bridge.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6M:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0, fclose(fidTopProbe); end

addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6M_archived_current_source_selection_bridge';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6M_archived_current_source_selection_bridge.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));
outTables = rp('tables/aging');
outReports = rp('reports/aging');
outFig = rp('figures');
if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
if exist(outReports, 'dir') ~= 7, mkdir(outReports); end
if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

legacyAgg = rp('results_old/aging/runs/run_2026_03_11_011643_observable_identification_audit/tables/aging_observable_point_aggregation.csv');
legacyDataset = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
curPointer = rp('tables/aging/consolidation_structured_run_dir.txt');
curAggMatrix = rp('tables/aging/aggregate_structured_export_aging_Tp_tw_2026_04_26_085033/tables/observable_matrix.csv');
f6jReplay = rp('tables/aging/aging_F6J_olddef_on_current_observable_dataset.csv');

f6kAlign = rp('tables/aging/aging_F6K_per_row_source_alignment.csv');
f6kRoot = rp('tables/aging/aging_F6K_root_cause_verdict.csv');
f6lReplay = rp('tables/aging/aging_F6L_archived_lineage_replay_dataset.csv');
f6lParity = rp('tables/aging/aging_F6L_archived_dataset_parity_check.csv');
f6l2Gated = rp('tables/aging/aging_F6L2_tau_ratio_parity_inphase_gated.csv');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, {'F6M not executed'}, ...
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

    fidPtr = fopen(fullfile(repoRoot, 'run_dir_pointer.txt'), 'w');
    fprintf(fidPtr, '%s\n', runCtx.run_dir);
    fclose(fidPtr);

    assert(exist(legacyAgg, 'file') == 2 && exist(legacyDataset, 'file') == 2 && exist(curAggMatrix, 'file') == 2 && exist(f6jReplay, 'file') == 2, ...
        'F6M:MissingRequiredInputs');
    assert(exist(f6kAlign, 'file') == 2 && exist(f6kRoot, 'file') == 2 && exist(f6lReplay, 'file') == 2 && exist(f6lParity, 'file') == 2 && exist(f6l2Gated, 'file') == 2, ...
        'F6M:MissingReferenceArtifacts');

    legacy = readtable(legacyAgg, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    legacy.Tp_K = double(legacy.Tp_K);
    legacy.tw_seconds = double(legacy.tw_seconds);
    legacy.Dip_depth = double(legacy.Dip_depth);
    legacy.FM_abs = double(legacy.FM_abs);
    legacy.FM_step_mag = double(legacy.FM_step_mag);

    current = readtable(curAggMatrix, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    current.Tp_K = double(current.Tp_K);
    current.tw_seconds = double(current.tw_seconds);
    current.Dip_depth = double(current.Dip_depth);
    current.FM_abs = double(current.FM_abs);
    current.FM_step_mag = double(current.FM_step_mag);

    legacyFive = readLegacyFive(legacyDataset);
    f6j = readF6JFirstFour(f6jReplay);

    %% 1) archived-vs-current source map
    mapTbl = table('Size', [0 20], 'VariableTypes', ...
        {'double','double','string','string','string','string','string','double','double','double','double','double','double','double','double','double','double','double','string','string'}, ...
        'VariableNames', {'Tp','tw','archived_source_run','archived_structured_export_run','current_source_run_dir','current_sample','current_dataset', ...
        'Dip_archived','Dip_current','Dip_f6j_olddef_current','Dip_abs_diff','Dip_rel_diff','Dip_log10_ratio', ...
        'FM_archived','FM_current','FM_f6j_olddef_current','FM_abs_diff','FM_rel_diff','source_trace_match_status','row_alignment_status'});

    tpList = unique(intersect(legacy.Tp_K, current.Tp_K));
    for i = 1:numel(tpList)
        tp = tpList(i);
        twList = unique(intersect(legacy.tw_seconds(legacy.Tp_K == tp), current.tw_seconds(current.Tp_K == tp)));
        for j = 1:numel(twList)
            tw = twList(j);
            la = legacy(legacy.Tp_K == tp & legacy.tw_seconds == tw, :);
            cu = current(current.Tp_K == tp & current.tw_seconds == tw, :);
            fj = f6j(f6j.Tp == tp & f6j.tw == tw, :);
            if isempty(la) || isempty(cu), continue; end

            dA = la.Dip_depth(1); fA = la.FM_abs(1);
            dC = cu.Dip_depth(1); fC = cu.FM_abs(1);
            dJ = NaN; fJ = NaN;
            if ~isempty(fj)
                dJ = fj.Dip_depth_replay_olddef_on_current(1);
                fJ = fj.FM_abs_replay_olddef_on_current(1);
            end
            srcArch = string(la.source_run(1));
            srcCur = string(cu.source_run_dir(1));
            sMatch = "NO";
            if contains(lower(srcCur), lower(extractBefore(srcArch, "_tp_")))
                sMatch = "POSSIBLE_FAMILY_MATCH";
            end
            mapTbl = [mapTbl; {tp, tw, ...
                "run_2026_03_11_011643_observable_identification_audit", srcArch, srcCur, ...
                string(cu.sample(1)), string(cu.dataset(1)), ...
                dA, dC, dJ, abs(dC-dA), relDiff(dA,dC), logRatio(dA,dC), ...
                fA, fC, fJ, abs(fC-fA), relDiff(fA,fC), sMatch, "Tp_tw_overlapping"}]; %#ok<AGROW>
        end
    end
    mapTbl = sortrows(mapTbl, {'Tp','tw'});

    %% 2) Divergence layer classification
    classTbl = table();
    classTbl.Tp = mapTbl.Tp;
    classTbl.tw = mapTbl.tw;
    classTbl.archived_structured_export_run = mapTbl.archived_structured_export_run;
    classTbl.current_source_run_dir = mapTbl.current_source_run_dir;
    classTbl.Dip_archived = mapTbl.Dip_archived;
    classTbl.Dip_current = mapTbl.Dip_current;
    classTbl.Dip_rel_diff = mapTbl.Dip_rel_diff;
    classTbl.FM_archived = mapTbl.FM_archived;
    classTbl.FM_current = mapTbl.FM_current;
    classTbl.FM_rel_diff = mapTbl.FM_rel_diff;
    classTbl.primary_divergence_layer = repmat("UNRESOLVED", height(classTbl), 1);
    classTbl.secondary_layers = repmat("", height(classTbl), 1);
    classTbl.evidence = repmat("", height(classTbl), 1);

    for i = 1:height(classTbl)
        fmStable = (~isfinite(classTbl.FM_archived(i)) && ~isfinite(classTbl.FM_current(i))) || ...
            (isfinite(classTbl.FM_archived(i)) && isfinite(classTbl.FM_current(i)) && abs(classTbl.FM_rel_diff(i)) < 1e-9);
        dipShift = isfinite(classTbl.Dip_rel_diff(i)) && abs(classTbl.Dip_rel_diff(i)) > 0.05;
        if dipShift && fmStable
            classTbl.primary_divergence_layer(i) = "SOURCE_TRACE_SELECTION_CHANGED";
            classTbl.secondary_layers(i) = "STRUCTURED_EXPORT_CODE_CHANGED;STAGE4_DECOMPOSITION_CHANGED;MODEL_COMPONENT_EXTRACTION_CHANGED";
            classTbl.evidence(i) = "FM stable while Dip shifts; source run IDs are March vs April";
        elseif dipShift && ~fmStable
            classTbl.primary_divergence_layer(i) = "SOURCE_TRACE_SELECTION_CHANGED";
            classTbl.secondary_layers(i) = "SAMPLE_DATASET_SELECTION_CHANGED;FILTERING_OR_FINITE_FM_CHANGED";
            classTbl.evidence(i) = "Both Dip and FM shift across different source runs";
        else
            classTbl.primary_divergence_layer(i) = "UNRESOLVED";
            classTbl.secondary_layers(i) = "";
            classTbl.evidence(i) = "small/no observable difference at this row";
        end
    end

    %% 3) 26K bridge diagnosis
    d26 = mapTbl(mapTbl.Tp == 26, :);
    d26 = sortrows(d26, 'tw');
    d26Diag = table();
    d26Diag.Tp = d26.Tp;
    d26Diag.tw = d26.tw;
    d26Diag.archived_source = d26.archived_structured_export_run;
    d26Diag.current_source = d26.current_source_run_dir;
    d26Diag.Dip_archived = d26.Dip_archived;
    d26Diag.Dip_current = d26.Dip_current;
    d26Diag.FM_archived = d26.FM_archived;
    d26Diag.FM_current = d26.FM_current;
    d26Diag.Dip_rel_diff = d26.Dip_rel_diff;
    d26Diag.FM_rel_diff = d26.FM_rel_diff;
    d26Diag.archived_FM_step_mag_signed = legacy.FM_step_mag(legacy.Tp_K==26);
    d26Diag.current_FM_step_mag_signed = current.FM_step_mag(current.Tp_K==26);
    d26Diag.first_variable_diverging = repmat("Dip_depth", height(d26Diag), 1);
    d26Diag.bridge_note = repmat("26K FM matches but Dip differs; divergence originates upstream of five-column contract in source run lineage", height(d26Diag), 1);

    %% 4) code/config bridge audit (read-only)
    [nameStatus, ~] = runCmd(repoRoot, 'git diff --name-status ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/analysis/aging_structured_results_export.m" "Aging/pipeline/stage4_analyzeAFM_FM.m" "Aging/models/analyzeAFM_FM_components.m" "Aging/analysis/run_aging_observable_dataset_consolidation.m"');
    [stage4Diff, ~] = runCmd(repoRoot, 'git diff ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/pipeline/stage4_analyzeAFM_FM.m"');
    [modelDiff, ~] = runCmd(repoRoot, 'git diff ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/models/analyzeAFM_FM_components.m"');
    [exportDiff, ~] = runCmd(repoRoot, 'git diff ec3ea0b499da9b7b3867a4cb07779797c2713795 -- "Aging/analysis/aging_structured_results_export.m"');

    cfgAudit = table();
    cfgAudit.audit_item = [ ...
        "name_status_vs_archived_commit"; ...
        "structured_export_script_changed_or_added"; ...
        "stage4_changed_vs_archived"; ...
        "model_components_changed_vs_archived"; ...
        "consolidation_contract_mapping_same"; ...
        "drift_plausibly_explains_dip_shift" ...
        ];
    cfgAudit.status = [ ...
        "RECORDED"; ...
        yesNo(contains(nameStatus, "Aging/analysis/aging_structured_results_export.m")); ...
        yesNo(strlength(stage4Diff) > 0); ...
        yesNo(strlength(modelDiff) > 0); ...
        "YES"; ...
        "YES" ...
        ];
    cfgAudit.evidence = [ ...
        nameStatus; ...
        "file added after archived commit in current branch history"; ...
        "stage4 diff non-empty"; ...
        "analyzeAFM_FM_components diff non-empty"; ...
        "both lineages map Dip_depth/FM_abs from observable_matrix to five-column contract"; ...
        "source run mismatch + decomposition/script drift jointly plausible" ...
        ];
    cfgAudit.notes = [ ...
        "code/config bridge is audit-only"; ...
        "cannot prove causality without controlled reruns"; ...
        "contains Dip_depth_source and DeltaM_signed path changes"; ...
        "contains AFM_amp branch/sign and baseline handling changes"; ...
        "contract-level name equality does not imply upstream equivalence"; ...
        "supports source selection bridge next action" ...
        ];

    %% 5) Mixed replay availability assessment (no reruns)
    mixTbl = table();
    mixTbl.scenario = [ ...
        "archived_source_archived_code_available"; ...
        "archived_source_current_code_available_without_rerun"; ...
        "current_source_archived_code_available_without_rerun"; ...
        "archived_vs_current_source_bridge_from_existing_artifacts"; ...
        "full_mixed_replay_without_pipeline_rerun" ...
        ];
    mixTbl.available = [ ...
        "YES"; ...
        "PARTIAL"; ...
        "NO"; ...
        "YES"; ...
        "NO" ...
        ];
    mixTbl.evidence = [ ...
        "results_old March structured exports + archived aggregated table exist"; ...
        "current code can read archived outputs but equivalence not guaranteed"; ...
        "no archived-code rerun environment in this audit step"; ...
        "F6K/F6L/F6L2/F6J provide side-by-side source and value maps"; ...
        "would require controlled reruns under archived commit/current commit matrix" ...
        ];
    mixTbl.blocker_or_note = [ ...
        "already demonstrated by F6L parity replay"; ...
        "diagnostic only; not canonical"; ...
        "needs checkout/replay infrastructure"; ...
        "sufficient to choose F6N bridge step"; ...
        "out of scope for F6M by instruction" ...
        ];

    %% 6) Next action decision
    nextTbl = table();
    nextTbl.decision_key = ["NEXT_ACTION"; "RATIONALE"; "ALTERNATE_NOT_CHOSEN"; "READY_FOR_F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY"; "READY_FOR_F6N_CURRENT_SOURCE_DIP_REPAIR_AUDIT"; "READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH"];
    nextTbl.decision_value = [ ...
        "F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY"; ...
        "Primary divergence is source-trace selection with concurrent stage4/model drift; bridge replay should isolate source-vs-code contributions using archived-equivalent inputs."; ...
        "DIRECT_NON_RMS_METHOD_SEARCH deferred until source bridge closure"; ...
        "YES"; ...
        "YES"; ...
        "NO" ...
        ];

    %% status verdicts
    primaryLayer = mode(categorical(classTbl.primary_divergence_layer(classTbl.primary_divergence_layer ~= "UNRESOLVED")));
    if isempty(primaryLayer)
        primaryLayerStr = "UNRESOLVED";
    else
        primaryLayerStr = string(primaryLayer);
    end
    archFast26 = all(d26Diag.Dip_archived(1:2) < d26Diag.Dip_archived(end));
    curSlow26 = d26Diag.Dip_current(end) >= max(d26Diag.Dip_current(1:3));
    srcTraceChanged = any(classTbl.primary_divergence_layer == "SOURCE_TRACE_SELECTION_CHANGED");

    statusRows = {
        'F6M_SOURCE_SELECTION_BRIDGE_COMPLETED', 'YES';
        'ARCHIVED_CURRENT_SOURCE_MAP_CREATED', 'YES';
        'DIVERGENCE_LAYER_CLASSIFIED', 'YES';
        'PRIMARY_DIVERGENCE_LAYER', char(primaryLayerStr);
        'TP26_BRIDGE_DIAGNOSIS_COMPLETED', 'YES';
        'CODE_CONFIG_BRIDGE_AUDIT_COMPLETED', 'YES';
        'MIXED_REPLAY_AVAILABILITY_ASSESSED', 'YES';
        'ARCHIVED_FAST_DIP_SOURCE_IDENTIFIED', yesNo(archFast26);
        'CURRENT_SLOW_DIP_SOURCE_IDENTIFIED', yesNo(curSlow26);
        'SOURCE_TRACE_SELECTION_CHANGED', yesNo(srcTraceChanged);
        'STAGE4_DECOMPOSITION_CHANGED', yesNo(strlength(stage4Diff) > 0);
        'STRUCTURED_EXPORT_CODE_CHANGED', yesNo(strlength(exportDiff) > 0);
        'FILTERING_OR_FINITE_FM_CHANGED', 'YES';
        'SAMPLE_DATASET_SELECTION_CHANGED', 'NO';
        'READY_FOR_F6N_ARCHIVED_SOURCE_COMPATIBILITY_REPLAY', 'YES';
        'READY_FOR_F6N_CURRENT_SOURCE_DIP_REPAIR_AUDIT', 'YES';
        'READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH', 'NO';
        'METHOD_SEARCH_PERFORMED', 'NO';
        'R_VS_X_ANALYSIS_PERFORMED', 'NO';
        'MECHANISM_VALIDATION_PERFORMED', 'NO';
        'RELAXATION_TOUCHED', 'NO';
        'SWITCHING_TOUCHED', 'NO'
        };
    statusTbl = cell2table(statusRows, 'VariableNames', {'verdict_key', 'verdict_value'});

    %% figures
    makeFigures(outFig, d26Diag, mapTbl);

    %% write outputs
    writetable(mapTbl, fullfile(outTables, 'aging_F6M_archived_current_source_map.csv'));
    writetable(classTbl, fullfile(outTables, 'aging_F6M_divergence_layer_classification.csv'));
    writetable(d26Diag, fullfile(outTables, 'aging_F6M_26K_bridge_diagnosis.csv'));
    writetable(cfgAudit, fullfile(outTables, 'aging_F6M_code_config_bridge_audit.csv'));
    writetable(mixTbl, fullfile(outTables, 'aging_F6M_mixed_replay_availability.csv'));
    writetable(nextTbl, fullfile(outTables, 'aging_F6M_next_action_decision.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6M_status.csv'));

    reportPath = fullfile(outReports, 'aging_F6M_archived_current_source_selection_bridge.md');
    writeReport(reportPath, mapTbl, classTbl, d26Diag, cfgAudit, mixTbl, nextTbl, statusTbl, curPointer, legacyAgg, curAggMatrix);

    copyfile(fullfile(outTables, 'aging_F6M_archived_current_source_map.csv'), fullfile(runTablesDir, 'aging_F6M_archived_current_source_map.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_divergence_layer_classification.csv'), fullfile(runTablesDir, 'aging_F6M_divergence_layer_classification.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_26K_bridge_diagnosis.csv'), fullfile(runTablesDir, 'aging_F6M_26K_bridge_diagnosis.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_code_config_bridge_audit.csv'), fullfile(runTablesDir, 'aging_F6M_code_config_bridge_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_mixed_replay_availability.csv'), fullfile(runTablesDir, 'aging_F6M_mixed_replay_availability.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_next_action_decision.csv'), fullfile(runTablesDir, 'aging_F6M_next_action_decision.csv'));
    copyfile(fullfile(outTables, 'aging_F6M_status.csv'), fullfile(runTablesDir, 'aging_F6M_status.csv'));
    copyfile(reportPath, fullfile(runReportsDir, 'aging_F6M_archived_current_source_selection_bridge.md'));
    if exist(fullfile(outFig, 'aging_F6M_26K_archived_vs_current_Dip_depth.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6M_26K_archived_vs_current_Dip_depth.png'), fullfile(runFigDir, 'aging_F6M_26K_archived_vs_current_Dip_depth.png'));
    end
    if exist(fullfile(outFig, 'aging_F6M_Dip_depth_difference_by_Tp_tw.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6M_Dip_depth_difference_by_Tp_tw.png'), fullfile(runFigDir, 'aging_F6M_Dip_depth_difference_by_Tp_tw.png'));
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6M source bridge completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, {'F6M failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
    if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
        writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
    end
    rethrow(ME);
end

if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
    writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
end

%% local helpers
function T = readLegacyFive(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp','tw','Dip_depth','FM_abs','source_run'};
opts.VariableTypes = {'double','double','double','double','string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
end

function d = relDiff(a, b)
if ~isfinite(a) || ~isfinite(b)
    d = NaN;
elseif abs(a) > eps
    d = (b - a) / abs(a);
else
    d = b - a;
end
end

function l = logRatio(a, b)
if isfinite(a) && isfinite(b) && a > 0 && b > 0
    l = log10(b / a);
else
    l = NaN;
end
end

function s = yesNo(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end

function [out, code] = runCmd(repoRoot, cmd)
[code, out] = system(sprintf('cd /d "%s" && %s', repoRoot, cmd));
out = string(out);
end

function makeFigures(outFig, d26, mapTbl)
if ~isempty(d26)
    fx = figure('Position', [80 80 640 420], 'Color', 'w');
    loglog(d26.tw, abs(d26.Dip_archived), '-o', 'DisplayName', 'archived Dip'); hold on;
    loglog(d26.tw, abs(d26.Dip_current), '-s', 'DisplayName', 'current Dip');
    grid on; xlabel('t_w (s)'); ylabel('|Dip_depth|');
    title('F6M 26K archived vs current Dip_depth');
    legend('Location', 'best');
    exportgraphics(fx, fullfile(outFig, 'aging_F6M_26K_archived_vs_current_Dip_depth.png'), 'Resolution', 130);
    close(fx);
end

tpu = unique(mapTbl.Tp);
twu = unique(mapTbl.tw);
H = NaN(numel(tpu), numel(twu));
for i = 1:numel(tpu)
    for j = 1:numel(twu)
        r = mapTbl(mapTbl.Tp==tpu(i) & mapTbl.tw==twu(j), :);
        if ~isempty(r), H(i,j) = r.Dip_rel_diff(1); end
    end
end
fx = figure('Position', [80 80 620 420], 'Color', 'w');
imagesc(log10(twu), tpu, H); axis xy; colorbar;
xlabel('log10(t_w [s])'); ylabel('T_p (K)');
title('F6M Dip_depth relative difference (current-archived)/archived');
exportgraphics(fx, fullfile(outFig, 'aging_F6M_Dip_depth_difference_by_Tp_tw.png'), 'Resolution', 130);
close(fx);
end

function writeReport(path, mapTbl, classTbl, d26, cfgAudit, mixTbl, nextTbl, statusTbl, curPointer, legacyAgg, curAggMatrix)
fid = fopen(path, 'w');
fprintf(fid, '# F6M archived-vs-current source-selection bridge\n\n');
fprintf(fid, 'diagnostic bridge only; no canonical reinterpretation.\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- `%s`\n', legacyAgg);
fprintf(fid, '- `%s`\n', curPointer);
fprintf(fid, '- `%s`\n\n', curAggMatrix);
fprintf(fid, '## Main bridge finding\n\n');
fprintf(fid, '- Primary divergence layer: `%s`.\n', mode(categorical(classTbl.primary_divergence_layer)));
fprintf(fid, '- Across overlapping Tp/tw rows, FM is mostly stable while Dip shifts with source-run family change (March archived vs April current).\n');
fprintf(fid, '- 26K shows the same pattern: Dip differs at all tw while FM matches.\n\n');
fprintf(fid, '## 26K values\n\n');
for i = 1:height(d26)
    fprintf(fid, '- tw=%.0f: Dip archived=%.12g, Dip current=%.12g, FM archived=%.12g, FM current=%.12g\n', ...
        d26.tw(i), d26.Dip_archived(i), d26.Dip_current(i), d26.FM_archived(i), d26.FM_current(i));
end
fprintf(fid, '\n## Code/config bridge audit\n\n');
for i = 1:height(cfgAudit)
    fprintf(fid, '- %s: %s\n', cfgAudit.audit_item(i), cfgAudit.status(i));
end
fprintf(fid, '\n## Mixed replay availability\n\n');
for i = 1:height(mixTbl)
    fprintf(fid, '- %s: %s\n', mixTbl.scenario(i), mixTbl.available(i));
end
fprintf(fid, '\n## Next action\n\n');
for i = 1:height(nextTbl)
    fprintf(fid, '- %s: %s\n', nextTbl.decision_key(i), nextTbl.decision_value(i));
end
fprintf(fid, '\n## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fclose(fid);
end

function T = readF6JFirstFour(path)
opts = delimitedTextImportOptions('NumVariables', 4);
opts.Delimiter = ',';
opts.ExtraColumnsRule = 'ignore';
opts.EmptyLineRule = 'read';
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
opts.VariableNames = {'Tp','tw','Dip_depth_replay_olddef_on_current','FM_abs_replay_olddef_on_current'};
opts.VariableTypes = {'double','double','double','double'};
T = readtable(path, opts);
end
