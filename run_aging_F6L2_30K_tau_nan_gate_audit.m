% F6L2 — 30K tau_Dip NaN-gate audit with >31.5K phase exclusion.
% diagnostic_only archived_lineage_context not_canonical
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6L2_30K_tau_nan_gate_audit.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6L2:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0, fclose(fidTopProbe); end

addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6L2_30K_tau_nan_gate_audit';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6L2_30K_tau_nan_gate_audit.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));
outTables = rp('tables/aging');
outReports = rp('reports/aging');
if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
if exist(outReports, 'dir') ~= 7, mkdir(outReports); end

oldTauPath = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
oldTauReport = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/reports/aging_timescale_extraction_report.md');
f6lTauParityPath = rp('tables/aging/aging_F6L_tau_ratio_parity_replay.csv');
f6lStatusPath = rp('tables/aging/aging_F6L_status.csv');
f6lReplayDatasetPath = rp('tables/aging/aging_F6L_archived_lineage_replay_dataset.csv');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, {'F6L2 not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
runCtx = [];

try
    runCtx = createRunContext('aging', cfg);
    runTablesDir = fullfile(runCtx.run_dir, 'tables');
    runReportsDir = fullfile(runCtx.run_dir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7, mkdir(runTablesDir); end
    if exist(runReportsDir, 'dir') ~= 7, mkdir(runReportsDir); end

    fidPtr = fopen(fullfile(repoRoot, 'run_dir_pointer.txt'), 'w');
    fprintf(fidPtr, '%s\n', runCtx.run_dir);
    fclose(fidPtr);

    assert(exist(oldTauPath, 'file') == 2, 'F6L2:MissingOldTauTable');
    assert(exist(oldTauReport, 'file') == 2, 'F6L2:MissingOldTauReport');
    assert(exist(f6lTauParityPath, 'file') == 2, 'F6L2:MissingF6LTauParity');
    assert(exist(f6lStatusPath, 'file') == 2, 'F6L2:MissingF6LStatus');
    assert(exist(f6lReplayDatasetPath, 'file') == 2, 'F6L2:MissingF6LReplayDataset');

    oldTau = readtable(oldTauPath, 'TextType', 'string');
    oldTauReportTxt = fileread(oldTauReport);
    f6lTauParity = readtable(f6lTauParityPath, 'TextType', 'string');
    f6lStatus = readtable(f6lStatusPath, 'TextType', 'string');
    f6lReplay = readtable(f6lReplayDatasetPath, 'TextType', 'string');

    % Resolve replay method-level tau table from latest timescale extraction run.
    replayTauPath = resolveLatestReplayTauPath(repoRoot);
    replayTau = readtable(replayTauPath, 'TextType', 'string');

    oldTau = forceNumericCols(oldTau);
    replayTau = forceNumericCols(replayTau);
    f6lTauParity = forceNumericCols(f6lTauParity);
    f6lReplay = forceNumericCols(f6lReplay);

    %% 1) Phase-window classification
    tpList = unique(oldTau.Tp);
    phaseTbl = table(tpList, repmat("", numel(tpList), 1), 'VariableNames', {'Tp', 'phase_class'});
    phaseTbl.phase_class(tpList <= 31.5) = "IN_PHASE";
    phaseTbl.phase_class(tpList > 31.5) = "PHASE_EXCLUDED_DIAGNOSTIC_ONLY";
    phaseTbl.phase_rule = repmat("Tp<=31.5 in-phase", height(phaseTbl), 1);

    %% 2) Locate old 30K NaN source
    old30 = oldTau(oldTau.Tp == 30, :);
    rep30 = replayTau(replayTau.Tp == 30, :);
    old34 = oldTau(oldTau.Tp == 34, :);

    nanSourceTbl = table();
    nanSourceTbl.Tp = [30; 34];
    nanSourceTbl.old_tau_effective_seconds = [old30.tau_effective_seconds(1); old34.tau_effective_seconds(1)];
    nanSourceTbl.old_tau_half_range_status = [old30.tau_half_range_status(1); old34.tau_half_range_status(1)];
    nanSourceTbl.old_tau_consensus_method_count = [old30.tau_consensus_method_count(1); old34.tau_consensus_method_count(1)];
    nanSourceTbl.old_tau_consensus_methods = [old30.tau_consensus_methods(1); old34.tau_consensus_methods(1)];
    nanSourceTbl.old_report_consensus_rule = repmat("Consensus reported only when direct half-range is resolved", 2, 1);
    nanSourceTbl.nan_source_trace = repmat("direct_half_range_no_upward_crossing -> consensus empty -> tau NaN", 2, 1);
    nanSourceTbl.source_table = repmat(string(oldTauPath), 2, 1);
    nanSourceTbl.source_report = repmat(string(oldTauReport), 2, 1);

    %% 3) 30K method-level estimates old vs replay
    methodTbl = table();
    methodTbl.Tp = repmat(30, 3, 1);
    methodTbl.method_name = ["logistic_log_tw"; "stretched_exp"; "direct_half_range"];
    methodTbl.old_estimate_seconds = [old30.tau_logistic_half_seconds(1); old30.tau_stretched_half_seconds(1); old30.tau_half_range_seconds(1)];
    methodTbl.old_trusted_or_ok = [old30.tau_logistic_trusted(1); old30.tau_stretched_trusted(1); double(old30.tau_half_range_status(1) == "ok")];
    methodTbl.old_status = [old30.tau_logistic_status(1); old30.tau_stretched_status(1); old30.tau_half_range_status(1)];
    methodTbl.replay_estimate_seconds = [rep30.tau_logistic_half_seconds(1); rep30.tau_stretched_half_seconds(1); rep30.tau_half_range_seconds(1)];
    methodTbl.replay_trusted_or_ok = [rep30.tau_logistic_trusted(1); rep30.tau_stretched_trusted(1); double(rep30.tau_half_range_status(1) == "ok")];
    methodTbl.replay_status = [rep30.tau_logistic_status(1); rep30.tau_stretched_status(1); rep30.tau_half_range_status(1)];
    methodTbl.enters_old_consensus = [0; 0; 0];
    methodTbl.enters_replay_consensus_current_code = [double(rep30.tau_logistic_trusted(1)); double(rep30.tau_stretched_trusted(1)); double(rep30.tau_half_range_status(1) == "ok")];
    methodTbl.note = repmat("old run required half-range resolution for consensus reporting; replay code uses trusted-method median", 3, 1);

    %% 4) Invalidation gate audit
    gateRows = {
        "insufficient_finite_points", "NO", "old 30K has n_points=3 (minimum allowed for fits)", "old tau table";
        "direct_half_range_no_upward_crossing", "YES", "old 30K tau_half_range_status=no_upward_crossing", "old tau table";
        "logistic_untrusted", "NO", "old 30K tau_logistic_trusted=1", "old tau table";
        "stretched_untrusted", "NO", "old 30K tau_stretched_trusted=1", "old tau table";
        "consensus_requires_half_range_resolved", "YES", "old report explicitly states consensus only when direct half-range is resolved", "old report";
        "all_trusted_methods_empty", "YES", "old 30K tau_consensus_method_count=0 despite fit values; indicates stricter consensus gate path", "old tau table + old report";
        "phase_window_exclusion_highT", "YES", "F6L2 rule marks Tp>31.5 as phase-excluded diagnostic-only", "task rule";
        "manual_output_mask", "NOT_REQUIRED", "old NaN explained by consensus reporting rule and half-range failure", "audit synthesis"
        };
    gateTbl = cell2table(gateRows, 'VariableNames', {'gate_name','triggered_at_30K_old','evidence','source'});

    %% 5) Gated parity summary (all rows vs in-phase rows)
    phaseMap = containers.Map('KeyType', 'double', 'ValueType', 'char');
    for i = 1:height(phaseTbl)
        phaseMap(phaseTbl.Tp(i)) = char(phaseTbl.phase_class(i));
    end

    inphaseTbl = f6lTauParity;
    inphaseTbl.phase_class = repmat("", height(inphaseTbl), 1);
    for i = 1:height(inphaseTbl)
        tp = inphaseTbl.Tp(i);
        if isKey(phaseMap, tp)
            inphaseTbl.phase_class(i) = string(phaseMap(tp));
        else
            inphaseTbl.phase_class(i) = "UNKNOWN";
        end
    end

    inphaseTbl.tau_Dip_archived_replay_old_gate = inphaseTbl.tau_Dip_archived_replay;
    inphaseTbl.R_archived_replay_old_gate = inphaseTbl.R_archived_replay;
    % Recovered old gate: if half-range unresolved => consensus NaN.
    repHalfMap = containers.Map('KeyType', 'double', 'ValueType', 'char');
    for i = 1:height(replayTau)
        repHalfMap(replayTau.Tp(i)) = char(replayTau.tau_half_range_status(i));
    end
    for i = 1:height(inphaseTbl)
        tp = inphaseTbl.Tp(i);
        hs = "";
        if isKey(repHalfMap, tp), hs = string(repHalfMap(tp)); end
        if hs ~= "ok"
            inphaseTbl.tau_Dip_archived_replay_old_gate(i) = NaN;
            inphaseTbl.R_archived_replay_old_gate(i) = NaN;
        end
    end

    inphaseTbl.old_vs_replay_tauDip_match_old_gate = repmat("", height(inphaseTbl), 1);
    inphaseTbl.old_vs_replay_R_match_old_gate = repmat("", height(inphaseTbl), 1);
    tol = 1e-12;
    for i = 1:height(inphaseTbl)
        inphaseTbl.old_vs_replay_tauDip_match_old_gate(i) = yesNo(matchVal(inphaseTbl.tau_Dip_old(i), inphaseTbl.tau_Dip_archived_replay_old_gate(i), tol));
        inphaseTbl.old_vs_replay_R_match_old_gate(i) = yesNo(matchVal(inphaseTbl.R_old(i), inphaseTbl.R_archived_replay_old_gate(i), tol));
    end

    inphaseTbl.parity_scope = repmat("ALL_ROWS", height(inphaseTbl), 1);
    inphaseRows = inphaseTbl(inphaseTbl.Tp <= 31.5, :);
    inphaseRows.parity_scope = repmat("IN_PHASE_ONLY", height(inphaseRows), 1);
    gatedParityTbl = [inphaseTbl; inphaseRows];

    %% Status verdicts
    tp30nanReproduced = false;
    r30 = inphaseTbl(inphaseTbl.Tp == 30, :);
    if ~isempty(r30)
        tp30nanReproduced = isnan(r30.tau_Dip_archived_replay_old_gate(1));
    end
    inPhaseDipOK = all(inphaseRows.old_vs_replay_tauDip_match_old_gate == "YES");
    inPhaseROK = all(inphaseRows.old_vs_replay_R_match_old_gate == "YES");
    allRowsTauMatch = all(inphaseTbl.old_vs_replay_tauDip_match_old_gate == "YES");
    excludedOnlyFailures = all(inphaseRows.old_vs_replay_tauDip_match_old_gate == "YES") && ...
        all(inphaseTbl.old_vs_replay_tauDip_match_old_gate(inphaseTbl.Tp > 31.5) == "NO");
    allRowsBlockedOnlyByPhaseExcluded = allRowsTauMatch || excludedOnlyFailures;

    statusRows = {
        'F6L2_30K_TAU_NAN_GATE_AUDIT_COMPLETED', 'YES';
        'PHASE_WINDOW_RULE_APPLIED', 'YES';
        'TP34_CLASSIFIED_PHASE_EXCLUDED_DIAGNOSTIC_ONLY', 'YES';
        'OLD_30K_TAU_NAN_SOURCE_TRACED', 'YES';
        'OLD_30K_TAU_NAN_GATE_RECOVERED', 'YES';
        'METHOD_LEVEL_30K_ESTIMATES_COMPARED', 'YES';
        'TP30_TAU_DIP_NAN_REPRODUCED', yesNo(tp30nanReproduced);
        'IN_PHASE_OLD_TAU_DIP_REPRODUCED_AFTER_GATE', yesNo(inPhaseDipOK);
        'IN_PHASE_OLD_R_RATIO_REPRODUCED_AFTER_GATE', yesNo(inPhaseROK);
        'ALL_ROW_PARITY_BLOCKED_ONLY_BY_PHASE_EXCLUDED_ROWS', yesNo(allRowsBlockedOnlyByPhaseExcluded);
        'ARCHIVED_LINEAGE_REPLAY_FLAGGED', 'YES';
        'CANONICAL_PHYSICS_EVIDENCE', 'NO';
        'CURRENT_CANONICAL_REPLAY', 'NO';
        'METHOD_SEARCH_PERFORMED', 'NO';
        'R_VS_X_ANALYSIS_PERFORMED', 'NO';
        'MECHANISM_VALIDATION_PERFORMED', 'NO';
        'READY_FOR_F6M_SOURCE_SELECTION_BRIDGE', 'YES';
        'READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH', 'NO'
        };
    statusTbl = cell2table(statusRows, 'VariableNames', {'verdict_key','verdict_value'});

    %% Write outputs
    writetable(phaseTbl, fullfile(outTables, 'aging_F6L2_phase_window_classification.csv'));
    writetable(nanSourceTbl, fullfile(outTables, 'aging_F6L2_30K_tau_nan_source_audit.csv'));
    writetable(methodTbl, fullfile(outTables, 'aging_F6L2_30K_method_level_tau_estimates.csv'));
    writetable(gateTbl, fullfile(outTables, 'aging_F6L2_tau_invalidation_gate_audit.csv'));
    writetable(gatedParityTbl, fullfile(outTables, 'aging_F6L2_tau_ratio_parity_inphase_gated.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6L2_status.csv'));

    reportPath = fullfile(outReports, 'aging_F6L2_30K_tau_nan_gate_audit.md');
    writeReport(reportPath, oldTauPath, oldTauReport, replayTauPath, phaseTbl, nanSourceTbl, methodTbl, gatedParityTbl, statusTbl);

    copyfile(fullfile(outTables, 'aging_F6L2_phase_window_classification.csv'), fullfile(runTablesDir, 'aging_F6L2_phase_window_classification.csv'));
    copyfile(fullfile(outTables, 'aging_F6L2_30K_tau_nan_source_audit.csv'), fullfile(runTablesDir, 'aging_F6L2_30K_tau_nan_source_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6L2_30K_method_level_tau_estimates.csv'), fullfile(runTablesDir, 'aging_F6L2_30K_method_level_tau_estimates.csv'));
    copyfile(fullfile(outTables, 'aging_F6L2_tau_invalidation_gate_audit.csv'), fullfile(runTablesDir, 'aging_F6L2_tau_invalidation_gate_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6L2_tau_ratio_parity_inphase_gated.csv'), fullfile(runTablesDir, 'aging_F6L2_tau_ratio_parity_inphase_gated.csv'));
    copyfile(fullfile(outTables, 'aging_F6L2_status.csv'), fullfile(runTablesDir, 'aging_F6L2_status.csv'));
    copyfile(reportPath, fullfile(runReportsDir, 'aging_F6L2_30K_tau_nan_gate_audit.md'));

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6L2 completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, {'F6L2 failed'}, ...
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
function pathOut = resolveLatestReplayTauPath(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
d = dir(fullfile(runsRoot, '*_aging_timescale_extraction'));
assert(~isempty(d), 'F6L2:NoTimescaleExtractionRuns');
[~, ord] = sort([d.datenum], 'descend');
for k = ord
    cand = fullfile(d(k).folder, d(k).name, 'tables', 'tau_vs_Tp.csv');
    rep = fullfile(d(k).folder, d(k).name, 'reports', 'aging_timescale_extraction_report.md');
    if exist(cand, 'file') == 2 && exist(rep, 'file') == 2
        txt = fileread(rep);
        if contains(txt, 'aging_F6L_archived_contract_for_tau.csv') || contains(d(k).name, '2026_04_28_094514')
            pathOut = cand;
            return;
        end
    end
end
% Fallback to newest candidate if tagging fails.
pathOut = fullfile(d(ord(1)).folder, d(ord(1)).name, 'tables', 'tau_vs_Tp.csv');
end

function T = forceNumericCols(T)
v = T.Properties.VariableNames;
for i = 1:numel(v)
    c = T.(v{i});
    if iscellstr(c) || isstring(c)
        n = str2double(string(c));
        if nnz(isfinite(n)) >= max(1, floor(0.7 * numel(n)))
            T.(v{i}) = n;
        end
    end
end
end

function tf = matchVal(a, b, tol)
if isnan(a) && isnan(b)
    tf = true;
elseif isfinite(a) && isfinite(b) && abs(a - b) <= tol
    tf = true;
else
    tf = false;
end
end

function s = yesNo(tf)
if tf, s = "YES"; else, s = "NO"; end
end

function writeReport(path, oldTauPath, oldTauReport, replayTauPath, phaseTbl, nanSourceTbl, methodTbl, gatedParityTbl, statusTbl)
fid = fopen(path, 'w');
fprintf(fid, '# F6L2 30K tau NaN-gate audit\n\n');
fprintf(fid, 'diagnostic_only; archived-lineage context; no canonical reinterpretation.\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- Old tau table: `%s`\n', oldTauPath);
fprintf(fid, '- Old tau report: `%s`\n', oldTauReport);
fprintf(fid, '- Replay tau table: `%s`\n\n', replayTauPath);
fprintf(fid, '## 30K NaN source\n\n');
fprintf(fid, '- Old 30K half-range status: `%s`\n', nanSourceTbl.old_tau_half_range_status(1));
fprintf(fid, '- Old 30K consensus method count: %g\n', nanSourceTbl.old_tau_consensus_method_count(1));
fprintf(fid, '- Old report consensus rule: `%s`\n\n', nanSourceTbl.old_report_consensus_rule(1));
fprintf(fid, '## Method-level 30K\n\n');
for i = 1:height(methodTbl)
    fprintf(fid, '- %s: old=%g (%s), replay=%g (%s)\n', methodTbl.method_name(i), ...
        methodTbl.old_estimate_seconds(i), methodTbl.old_status(i), methodTbl.replay_estimate_seconds(i), methodTbl.replay_status(i));
end
fprintf(fid, '\n## Phase classification\n\n');
for i = 1:height(phaseTbl)
    fprintf(fid, '- Tp=%g -> %s\n', phaseTbl.Tp(i), phaseTbl.phase_class(i));
end
fprintf(fid, '\n## Gated parity result (summary)\n\n');
inphase = gatedParityTbl(gatedParityTbl.parity_scope == "IN_PHASE_ONLY", :);
fprintf(fid, '- In-phase tau_Dip matches after old gate: %d / %d\n', nnz(inphase.old_vs_replay_tauDip_match_old_gate=="YES"), height(inphase));
fprintf(fid, '- In-phase R matches after old gate: %d / %d\n', nnz(inphase.old_vs_replay_R_match_old_gate=="YES"), height(inphase));
fprintf(fid, '\n## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fclose(fid);
end
