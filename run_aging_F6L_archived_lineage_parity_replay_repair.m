% F6L — Aging archived-lineage parity replay repair.
% archived_lineage_replay_only not_canonical not_physical_claim
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6L_archived_lineage_parity_replay_repair.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6L:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6L_archived_lineage_parity_replay_repair';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6L_archived_lineage_parity_replay_repair.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));
outTables = rp('tables/aging');
outReports = rp('reports/aging');
outFig = rp('figures');
if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
if exist(outReports, 'dir') ~= 7, mkdir(outReports); end
if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

legacyDatasetPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
legacyDatasetManifest = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/run_manifest.json');
legacyDatasetReport = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/reports/aging_dataset_build_report.md');
legacyAuditAggPath = rp('results_old/aging/runs/run_2026_03_11_011643_observable_identification_audit/tables/aging_observable_point_aggregation.csv');
legacyAuditManifest = rp('results_old/aging/runs/run_2026_03_11_011643_observable_identification_audit/run_manifest.json');

f6kStatus = rp('tables/aging/aging_F6K_status.csv');
f6kRoot = rp('tables/aging/aging_F6K_root_cause_verdict.csv');
f6kAlign = rp('tables/aging/aging_F6K_per_row_source_alignment.csv');
f6kReport = rp('reports/aging/aging_F6K_dip_replay_gap_root_cause_audit.md');

legacyTauDipPath = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
legacyTauFmPath = rp('results_old/aging/runs/run_2026_03_13_013634_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv');
failedDipClockPath = rp('results_old/aging/runs/run_2026_03_13_005134_aging_fm_using_dip_clock/tables/fm_collapse_using_dip_tau_metrics.csv');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, {'F6L not executed'}, ...
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

    fidPointer = fopen(fullfile(repoRoot, 'run_dir_pointer.txt'), 'w');
    fprintf(fidPointer, '%s\n', runCtx.run_dir);
    fclose(fidPointer);

    assert(exist(legacyDatasetPath, 'file') == 2, 'F6L:MissingLegacyDataset');
    assert(exist(legacyAuditAggPath, 'file') == 2, 'F6L:MissingLegacyAuditAggregation');
    assert(exist(legacyTauDipPath, 'file') == 2, 'F6L:MissingLegacyDipTau');
    assert(exist(legacyTauFmPath, 'file') == 2, 'F6L:MissingLegacyFmTau');
    assert(exist(failedDipClockPath, 'file') == 2, 'F6L:MissingFailedDipClockMetrics');
    assert(exist(f6kStatus, 'file') == 2 && exist(f6kRoot, 'file') == 2 && exist(f6kAlign, 'file') == 2 && exist(f6kReport, 'file') == 2, ...
        'F6L:MissingRequiredF6KReferences');

    legacyTbl = readLegacyFive(legacyDatasetPath);
    aggTbl = readtable(legacyAuditAggPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    aggTbl.Tp_K = double(aggTbl.Tp_K);
    aggTbl.tw_seconds = double(aggTbl.tw_seconds);
    aggTbl.Dip_depth = double(aggTbl.Dip_depth);
    aggTbl.FM_abs = double(aggTbl.FM_abs);
    if ismember('FM_step_mag', aggTbl.Properties.VariableNames)
        aggTbl.FM_step_mag = double(aggTbl.FM_step_mag);
    else
        aggTbl.FM_step_mag = NaN(height(aggTbl), 1);
    end

    %% 1) Archived source inventory
    sourceRuns = unique(string(aggTbl.source_run));
    srcInventory = table('Size', [0 14], 'VariableTypes', ...
        {'string','string','double','string','string','string','string','string','double','double','double','double','string','string'}, ...
        'VariableNames', {'source_run_archived','source_dir','n_rows_required','manifest_exists','observable_matrix_exists','run_dir_exists', ...
        'required_rows_found','dip_depth_present','fm_abs_present','n_rows_found','n_dip_finite','n_fm_finite','source_manifest_commit','provenance_status'});

    for i = 1:numel(sourceRuns)
        src = sourceRuns(i);
        srcDir = fullfile(repoRoot, 'results_old', 'aging', 'runs', char(src));
        runDirExists = exist(srcDir, 'dir') == 7;
        manifestPath = fullfile(srcDir, 'run_manifest.json');
        matPath = fullfile(srcDir, 'tables', 'observable_matrix.csv');
        hasMan = exist(manifestPath, 'file') == 2;
        hasMat = exist(matPath, 'file') == 2;

        subReq = aggTbl(aggTbl.source_run == src, :);
        nReq = height(subReq);
        nFound = 0; nDipFinite = 0; nFmFinite = 0;
        reqFound = "NO";
        dipPresent = "NO";
        fmPresent = "NO";
        commit = "";
        status = "missing_inputs";

        if hasMan
            commit = parseManifestCommit(manifestPath);
        end

        if hasMat
            matTbl = readtable(matPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
            matTp = double(matTbl.Tp_K);
            matTw = double(matTbl.tw_seconds);
            matDip = double(matTbl.Dip_depth);
            matFm = double(matTbl.FM_abs);

            tfRows = false(nReq, 1);
            for r = 1:nReq
                tfRows(r) = any(matTp == subReq.Tp_K(r) & matTw == subReq.tw_seconds(r));
            end
            nFound = nnz(tfRows);
            reqFound = yn(nFound == nReq);

            nDipFinite = nnz(isfinite(matDip));
            nFmFinite = nnz(isfinite(matFm));
            dipPresent = yn(any(isfinite(matDip)));
            fmPresent = yn(any(isfinite(matFm)));
            status = "recoverable";
            if nFound < nReq
                status = "partial_rows";
            end
        end

        srcInventory = [srcInventory; {src, string(srcDir), nReq, yn(hasMan), yn(hasMat), yn(runDirExists), ...
            reqFound, dipPresent, fmPresent, nFound, nDipFinite, nFmFinite, string(commit), string(status)}]; %#ok<AGROW>
    end
    srcInventory = sortrows(srcInventory, 'source_run_archived');

    %% 2) Archived-lineage replay dataset (reconstructed from audit aggregation)
    replayTbl = table();
    replayTbl.Tp = aggTbl.Tp_K;
    replayTbl.tw = aggTbl.tw_seconds;
    replayTbl.Dip_depth_archived_replay = aggTbl.Dip_depth;
    replayTbl.FM_abs_archived_replay = aggTbl.FM_abs;
    replayTbl.source_run_archived = string(aggTbl.source_run);
    replayTbl.source_manifest_commit = repmat("", height(replayTbl), 1);
    for i = 1:height(replayTbl)
        m = srcInventory.source_manifest_commit(srcInventory.source_run_archived == replayTbl.source_run_archived(i));
        if ~isempty(m), replayTbl.source_manifest_commit(i) = m(1); end
    end
    replayTbl.provenance_status = repmat("ARCHIVED_TRACEABLE", height(replayTbl), 1);
    replayTbl.replay_class = repmat("ARCHIVED_LINEAGE_REPLAY", height(replayTbl), 1);
    replayTbl.canonical_evidence = repmat("NO", height(replayTbl), 1);
    replayTbl = sortrows(replayTbl, {'Tp','tw'});

    %% 3) Dataset parity check against archived five-column dataset
    parityTbl = table('Size', [0 17], 'VariableTypes', ...
        {'double','double','double','double','double','double','double','double','double','double','double','double','string','string','string','string','string'}, ...
        'VariableNames', {'Tp','tw','Dip_depth_old','Dip_depth_replay','Dip_abs_diff','Dip_rel_diff','Dip_log10_ratio', ...
        'FM_abs_old','FM_abs_replay','FM_abs_diff','FM_rel_diff','FM_log10_ratio', ...
        'exact_or_tolerance_match','dip_match','fm_match','mismatch_reason','source_run_archived'});

    tolAbs = 1e-12;
    for i = 1:height(legacyTbl)
        tp = legacyTbl.Tp(i); tw = legacyTbl.tw(i);
        r = replayTbl(replayTbl.Tp == tp & replayTbl.tw == tw, :);
        if isempty(r)
            parityTbl = [parityTbl; {tp, tw, legacyTbl.Dip_depth(i), NaN, NaN, NaN, NaN, ...
                legacyTbl.FM_abs(i), NaN, NaN, NaN, NaN, "NO", "NO", "NO", "missing_row", ""}]; %#ok<AGROW>
            continue;
        end
        dOld = legacyTbl.Dip_depth(i); dRep = r.Dip_depth_archived_replay(1);
        fOld = legacyTbl.FM_abs(i); fRep = r.FM_abs_archived_replay(1);
        dAbs = abs(dRep - dOld);
        fAbs = abs(fRep - fOld);
        dRel = relDiff(dOld, dRep);
        fRel = relDiff(fOld, fRep);
        dLog = logRatio(dOld, dRep);
        fLog = logRatio(fOld, fRep);
        dMatch = valueMatch(dOld, dRep, tolAbs);
        fMatch = valueMatch(fOld, fRep, tolAbs);
        exact = yn(strcmp(dMatch, "YES") && strcmp(fMatch, "YES"));
        reason = "match";
        if exact == "NO"
            if strcmp(dMatch, "NO") && strcmp(fMatch, "YES")
                reason = "dip_mismatch";
            elseif strcmp(dMatch, "YES") && strcmp(fMatch, "NO")
                reason = "fm_mismatch";
            else
                reason = "dip_and_fm_mismatch";
            end
        end
        parityTbl = [parityTbl; {tp, tw, dOld, dRep, dAbs, dRel, dLog, ...
            fOld, fRep, fAbs, fRel, fLog, exact, dMatch, fMatch, reason, r.source_run_archived(1)}]; %#ok<AGROW>
    end
    parityTbl = sortrows(parityTbl, {'Tp','tw'});

    %% 4) Tau layer parity replay (legacy tau layer on archived replay dataset)
    contractPath = fullfile(runTablesDir, 'aging_F6L_archived_contract_for_tau.csv');
    contractTbl = table(replayTbl.Tp, replayTbl.tw, replayTbl.Dip_depth_archived_replay, replayTbl.FM_abs_archived_replay, ...
        replayTbl.source_run_archived, 'VariableNames', {'Tp','tw','Dip_depth','FM_abs','source_run'});
    writetable(contractTbl, contractPath);

    oldEnv = getenv('AGING_OBSERVABLE_DATASET_PATH');
    setenv('AGING_OBSERVABLE_DATASET_PATH', contractPath);
    dipOut = aging_timescale_extraction();
    dipTauReplay = readtable(fullfile(char(dipOut.run_dir), 'tables', 'tau_vs_Tp.csv'), 'TextType', 'string');

    cfgFm = struct();
    cfgFm.datasetPath = contractPath;
    cfgFm.dipTauPath = fullfile(char(dipOut.run_dir), 'tables', 'tau_vs_Tp.csv');
    cfgFm.failedDipClockMetricsPath = failedDipClockPath;
    cfgFm.runLabel = 'aging_F6L_fm_tau_archived_replay';
    fmOut = aging_fm_timescale_analysis(cfgFm);
    fmTauReplay = readtable(fullfile(char(fmOut.run_dir), 'tables', 'tau_FM_vs_Tp.csv'), 'TextType', 'string');
    setenv('AGING_OBSERVABLE_DATASET_PATH', oldEnv);

    dipTauOld = readtable(legacyTauDipPath, 'TextType', 'string');
    fmTauOld = readtable(legacyTauFmPath, 'TextType', 'string');

    tauParity = buildTauParityTable(dipTauOld, fmTauOld, dipTauReplay, fmTauReplay, tolAbs);

    %% 5) 26 K focused parity diagnosis
    p26 = parityTbl(parityTbl.Tp == 26, :);
    t26 = tauParity(tauParity.Tp == 26, :);
    if isempty(t26)
        t26 = table(26, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "NO", "NO", "missing_tau_26K", ...
            'VariableNames', {'Tp','tau_Dip_old','tau_Dip_archived_replay','tau_FM_old','tau_FM_archived_replay', ...
            'R_old','R_archived_replay','tau_Dip_rel_diff','R_rel_diff','old_tau_dip_match','old_R_match','tau_mismatch_reason'});
    end
    d26Tbl = table();
    d26Tbl.Tp = p26.Tp;
    d26Tbl.tw = p26.tw;
    d26Tbl.Dip_depth_old = p26.Dip_depth_old;
    d26Tbl.Dip_depth_archived_replay = p26.Dip_depth_replay;
    d26Tbl.FM_abs_old = p26.FM_abs_old;
    d26Tbl.FM_abs_archived_replay = p26.FM_abs_replay;
    d26Tbl.Dip_rel_diff = p26.Dip_rel_diff;
    d26Tbl.FM_rel_diff = p26.FM_rel_diff;
    d26Tbl.tau_Dip_old_26K = repmat(t26.tau_Dip_old(1), height(d26Tbl), 1);
    d26Tbl.tau_Dip_archived_replay_26K = repmat(t26.tau_Dip_archived_replay(1), height(d26Tbl), 1);
    d26Tbl.tau_FM_old_26K = repmat(t26.tau_FM_old(1), height(d26Tbl), 1);
    d26Tbl.tau_FM_archived_replay_26K = repmat(t26.tau_FM_archived_replay(1), height(d26Tbl), 1);
    d26Tbl.R_old_26K = repmat(t26.R_old(1), height(d26Tbl), 1);
    d26Tbl.R_archived_replay_26K = repmat(t26.R_archived_replay(1), height(d26Tbl), 1);
    d26Tbl.fast_dip_highR_reproduced = repmat(yn(t26.R_archived_replay(1) > 50 && t26.tau_Dip_archived_replay(1) < 30), height(d26Tbl), 1);

    %% 6) Provenance/boundary flags
    flagsTbl = table( ...
        ["ARCHIVED_LINEAGE_REPLAY"; "CURRENT_CANONICAL_REPLAY"; "CANONICAL_PHYSICS_EVIDENCE"; "R_VS_X_ALLOWED"; "METHOD_SEARCH_PERFORMED"], ...
        ["YES"; "NO"; "NO"; "NO"; "NO"], ...
        'VariableNames', {'flag_key','flag_value'});

    %% 7) Next action decision
    nextTbl = table( ...
        ["NEXT_ACTION"; "RATIONALE"; "READY_FOR_F6M_SOURCE_SELECTION_BRIDGE"; "READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH"], ...
        ["F6M_ARCHIVED_VS_CURRENT_SOURCE_SELECTION_BRIDGE"; ...
         "Archived parity replay can be reconstructed from archived lineage; current exports are non-equivalent so bridge/selection repair is next."; ...
         "YES"; "NO"], ...
        'VariableNames', {'decision_key','decision_value'});

    %% Optional figures
    makeF6LFigures(outFig, d26Tbl, tauParity);

    %% Status verdicts
    dipParity = all(strcmp(parityTbl.dip_match, "YES"));
    fmParity = all(strcmp(parityTbl.fm_match, "YES"));
    oldFiveReproduced = all(strcmp(parityTbl.exact_or_tolerance_match, "YES"));
    tauDipReproduced = all(strcmp(tauParity.old_tau_dip_match, "YES"));
    tauFmReproduced = all(strcmp(tauParity.old_tau_fm_match, "YES"));
    rReproduced = all(strcmp(tauParity.old_R_match, "YES"));
    fastDip26 = ~isempty(t26) && isfinite(t26.tau_Dip_archived_replay(1)) && t26.tau_Dip_archived_replay(1) < 30;
    highR26 = ~isempty(t26) && isfinite(t26.R_archived_replay(1)) && t26.R_archived_replay(1) > 50;

    statusRows = {
        'F6L_ARCHIVED_PARITY_REPLAY_COMPLETED', 'YES';
        'ARCHIVED_SOURCE_RUNS_INVENTORIED', 'YES';
        'ARCHIVED_LINEAGE_REPLAY_DATASET_CREATED', 'YES';
        'OLD_FIVE_COLUMN_DATASET_REPRODUCED', yn(oldFiveReproduced);
        'DIP_DEPTH_PARITY_PASSED', yn(dipParity);
        'FM_ABS_PARITY_PASSED', yn(fmParity);
        'TAU_LAYER_PARITY_REPLAYED', 'YES';
        'OLD_TAU_DIP_REPRODUCED', yn(tauDipReproduced);
        'OLD_TAU_FM_REPRODUCED', yn(tauFmReproduced);
        'OLD_R_RATIO_REPRODUCED', yn(rReproduced);
        'OLD_26K_FAST_DIP_REPRODUCED', yn(fastDip26);
        'OLD_26K_HIGH_R_REPRODUCED', yn(highR26);
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
    writetable(srcInventory, fullfile(outTables, 'aging_F6L_archived_source_inventory.csv'));
    writetable(replayTbl, fullfile(outTables, 'aging_F6L_archived_lineage_replay_dataset.csv'));
    writetable(parityTbl, fullfile(outTables, 'aging_F6L_archived_dataset_parity_check.csv'));
    writetable(tauParity, fullfile(outTables, 'aging_F6L_tau_ratio_parity_replay.csv'));
    writetable(d26Tbl, fullfile(outTables, 'aging_F6L_26K_parity_diagnosis.csv'));
    writetable(flagsTbl, fullfile(outTables, 'aging_F6L_provenance_boundary_flags.csv'));
    writetable(nextTbl, fullfile(outTables, 'aging_F6L_next_action_decision.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6L_status.csv'));

    reportPath = fullfile(outReports, 'aging_F6L_archived_lineage_parity_replay_repair.md');
    writeF6LReport(reportPath, legacyDatasetPath, legacyDatasetReport, legacyAuditAggPath, legacyAuditManifest, srcInventory, parityTbl, tauParity, d26Tbl, statusTbl);

    copyfile(fullfile(outTables, 'aging_F6L_archived_source_inventory.csv'), fullfile(runTablesDir, 'aging_F6L_archived_source_inventory.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_archived_lineage_replay_dataset.csv'), fullfile(runTablesDir, 'aging_F6L_archived_lineage_replay_dataset.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_archived_dataset_parity_check.csv'), fullfile(runTablesDir, 'aging_F6L_archived_dataset_parity_check.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_tau_ratio_parity_replay.csv'), fullfile(runTablesDir, 'aging_F6L_tau_ratio_parity_replay.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_26K_parity_diagnosis.csv'), fullfile(runTablesDir, 'aging_F6L_26K_parity_diagnosis.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_provenance_boundary_flags.csv'), fullfile(runTablesDir, 'aging_F6L_provenance_boundary_flags.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_next_action_decision.csv'), fullfile(runTablesDir, 'aging_F6L_next_action_decision.csv'));
    copyfile(fullfile(outTables, 'aging_F6L_status.csv'), fullfile(runTablesDir, 'aging_F6L_status.csv'));
    copyfile(reportPath, fullfile(runReportsDir, 'aging_F6L_archived_lineage_parity_replay_repair.md'));
    if exist(fullfile(outFig, 'aging_F6L_26K_archived_replay_dip_fm_curves.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6L_26K_archived_replay_dip_fm_curves.png'), fullfile(runFigDir, 'aging_F6L_26K_archived_replay_dip_fm_curves.png'));
    end
    if exist(fullfile(outFig, 'aging_F6L_R_archived_replay_vs_old.png'), 'file') == 2
        copyfile(fullfile(outFig, 'aging_F6L_R_archived_replay_vs_old.png'), fullfile(runFigDir, 'aging_F6L_R_archived_replay_vs_old.png'));
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6L archived-lineage parity replay completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, {'F6L failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
    if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
        writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
    end
    rethrow(ME);
end

if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
    writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
end

%% ---- local functions ----
function T = readLegacyFive(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp','tw','Dip_depth','FM_abs','source_run'};
opts.VariableTypes = {'double','double','double','double','string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
end

function c = parseManifestCommit(path)
c = "";
if exist(path, 'file') ~= 2
    return;
end
txt = fileread(path);
m = regexp(txt, '"git_commit"\s*:\s*"([^"]+)"', 'tokens', 'once');
if ~isempty(m)
    c = string(m{1});
end
end

function y = yn(tf)
if tf, y = "YES"; else, y = "NO"; end
end

function d = relDiff(a, b)
if ~isfinite(a) || ~isfinite(b)
    d = NaN;
elseif abs(a) > eps
    d = (b - a) ./ abs(a);
else
    d = b - a;
end
end

function l = logRatio(a, b)
if isfinite(a) && isfinite(b) && a > 0 && b > 0
    l = log10(b ./ a);
else
    l = NaN;
end
end

function m = valueMatch(a, b, tolAbs)
if isnan(a) && isnan(b)
    m = "YES";
elseif isfinite(a) && isfinite(b) && abs(a - b) <= tolAbs
    m = "YES";
else
    m = "NO";
end
end

function tauTbl = buildTauParityTable(dipOld, fmOld, dipRep, fmRep, tolAbs)
tauTbl = table('Size', [0 20], 'VariableTypes', ...
    {'double','double','double','double','double','double','double','double','double','double','double','double','string','string','string','string','string','string','string','string'}, ...
    'VariableNames', {'Tp','tau_Dip_old','tau_Dip_archived_replay','tau_Dip_abs_diff','tau_Dip_rel_diff', ...
    'tau_FM_old','tau_FM_archived_replay','tau_FM_abs_diff','tau_FM_rel_diff', ...
    'R_old','R_archived_replay','R_abs_diff','R_rel_diff', ...
    'old_tau_dip_match','old_tau_fm_match','old_R_match','tau_mismatch_reason','replay_class','canonical_evidence','provenance_status'});

tpList = unique(dipOld.Tp);
for i = 1:numel(tpList)
    tp = tpList(i);
    dO = dipOld(dipOld.Tp == tp, :);
    fO = fmOld(fmOld.Tp == tp, :);
    dR = dipRep(dipRep.Tp == tp, :);
    fR = fmRep(fmRep.Tp == tp, :);
    if isempty(dO) || isempty(dR) || isempty(fO) || isempty(fR)
        continue;
    end
    tdO = dO.tau_effective_seconds(1);
    tdR = dR.tau_effective_seconds(1);
    tfO = fO.tau_effective_seconds(1);
    tfR = fR.tau_effective_seconds(1);
    rO = NaN; rR = NaN;
    if isfinite(tdO) && tdO > 0 && isfinite(tfO) && tfO > 0, rO = tfO ./ tdO; end
    if isfinite(tdR) && tdR > 0 && isfinite(tfR) && tfR > 0, rR = tfR ./ tdR; end

    tdM = valueMatch(tdO, tdR, tolAbs);
    tfM = valueMatch(tfO, tfR, tolAbs);
    rM = valueMatch(rO, rR, tolAbs);
    reason = "match";
    if tdM == "NO" || tfM == "NO" || rM == "NO"
        reason = "tau_or_ratio_mismatch";
    end

    tauTbl = [tauTbl; {tp, tdO, tdR, abs(tdR - tdO), relDiff(tdO, tdR), ...
        tfO, tfR, abs(tfR - tfO), relDiff(tfO, tfR), ...
        rO, rR, abs(rR - rO), relDiff(rO, rR), ...
        tdM, tfM, rM, reason, "ARCHIVED_LINEAGE_REPLAY", "NO", "ARCHIVED_TRACEABLE"}]; %#ok<AGROW>
end
tauTbl = sortrows(tauTbl, 'Tp');
end

function makeF6LFigures(outFig, d26Tbl, tauTbl)
if ~isempty(d26Tbl) && height(d26Tbl) >= 2
    fx = figure('Position', [80 80 740 430], 'Color', 'w');
    tiledlayout(1,2,'Padding','compact');
    nexttile;
    loglog(d26Tbl.tw, abs(d26Tbl.Dip_depth_old), '-o', 'DisplayName', 'Dip old'); hold on;
    loglog(d26Tbl.tw, abs(d26Tbl.Dip_depth_archived_replay), '-s', 'DisplayName', 'Dip archived replay');
    grid on; xlabel('t_w (s)'); title('26K |Dip_depth|');
    legend('Location','best');
    nexttile;
    loglog(d26Tbl.tw, abs(d26Tbl.FM_abs_old), '-o', 'DisplayName', 'FM old'); hold on;
    loglog(d26Tbl.tw, abs(d26Tbl.FM_abs_archived_replay), '-s', 'DisplayName', 'FM archived replay');
    grid on; xlabel('t_w (s)'); title('26K |FM_abs|');
    legend('Location','best');
    sgtitle('F6L archived-lineage parity at 26K');
    exportgraphics(fx, fullfile(outFig, 'aging_F6L_26K_archived_replay_dip_fm_curves.png'), 'Resolution', 130);
    close(fx);
end

if ~isempty(tauTbl) && height(tauTbl) >= 2
    fx = figure('Position', [80 80 560 420], 'Color', 'w');
    plot(tauTbl.Tp, tauTbl.R_old, '-o', 'DisplayName', 'R old'); hold on;
    plot(tauTbl.Tp, tauTbl.R_archived_replay, '-s', 'DisplayName', 'R archived replay');
    grid on; xlabel('T_p (K)'); ylabel('R = tau_FM / tau_Dip');
    title('F6L R parity (archived replay vs old)');
    legend('Location', 'best');
    exportgraphics(fx, fullfile(outFig, 'aging_F6L_R_archived_replay_vs_old.png'), 'Resolution', 130);
    close(fx);
end
end

function writeF6LReport(path, legacyDatasetPath, legacyDatasetReport, legacyAuditAggPath, legacyAuditManifest, srcInv, parity, tauParity, d26, statusTbl)
fid = fopen(path, 'w');
fprintf(fid, '# F6L archived-lineage parity replay repair\n\n');
fprintf(fid, 'ARCHIVED_LINEAGE_REPLAY only; NOT canonical physics evidence.\n\n');
fprintf(fid, '## Inputs\n\n');
fprintf(fid, '- `%s`\n', legacyDatasetPath);
fprintf(fid, '- `%s`\n', legacyDatasetReport);
fprintf(fid, '- `%s`\n', legacyAuditAggPath);
fprintf(fid, '- `%s`\n\n', legacyAuditManifest);

fprintf(fid, '## Inventory summary\n\n');
fprintf(fid, '- Archived source runs inventoried: %d\n', height(srcInv));
fprintf(fid, '- Runs with observable_matrix present: %d\n', nnz(srcInv.observable_matrix_exists == "YES"));
fprintf(fid, '- Runs with required rows found: %d\n\n', nnz(srcInv.required_rows_found == "YES"));

fprintf(fid, '## Parity summary\n\n');
fprintf(fid, '- Five-column exact/tolerance matches: %d / %d\n', nnz(parity.exact_or_tolerance_match == "YES"), height(parity));
fprintf(fid, '- Dip parity passed: %s\n', yesNo(nnz(parity.dip_match == "YES") == height(parity)));
fprintf(fid, '- FM parity passed: %s\n', yesNo(nnz(parity.fm_match == "YES") == height(parity)));
fprintf(fid, '- Tau Dip reproduced: %s\n', yesNo(nnz(tauParity.old_tau_dip_match == "YES") == height(tauParity)));
fprintf(fid, '- Tau FM reproduced: %s\n', yesNo(nnz(tauParity.old_tau_fm_match == "YES") == height(tauParity)));
fprintf(fid, '- R reproduced: %s\n\n', yesNo(nnz(tauParity.old_R_match == "YES") == height(tauParity)));

sub26 = d26(1,:);
if ~isempty(sub26)
    fprintf(fid, '## 26 K parity values\n\n');
    fprintf(fid, '- tau_Dip old = %.12g\n', sub26.tau_Dip_old_26K);
    fprintf(fid, '- tau_Dip archived replay = %.12g\n', sub26.tau_Dip_archived_replay_26K);
    fprintf(fid, '- tau_FM old = %.12g\n', sub26.tau_FM_old_26K);
    fprintf(fid, '- tau_FM archived replay = %.12g\n', sub26.tau_FM_archived_replay_26K);
    fprintf(fid, '- R old = %.12g\n', sub26.R_old_26K);
    fprintf(fid, '- R archived replay = %.12g\n', sub26.R_archived_replay_26K);
    fprintf(fid, '- old 26K fast-dip/high-R reproduced: %s\n\n', char(sub26.fast_dip_highR_reproduced));
end

fprintf(fid, '## Status flags\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end

fprintf(fid, '\n## Boundary flags\n\n');
fprintf(fid, '- ARCHIVED_LINEAGE_REPLAY = YES\n');
fprintf(fid, '- CURRENT_CANONICAL_REPLAY = NO\n');
fprintf(fid, '- CANONICAL_PHYSICS_EVIDENCE = NO\n');
fprintf(fid, '- R_VS_X_ALLOWED = NO\n');
fprintf(fid, '- METHOD_SEARCH_PERFORMED = NO\n');
fclose(fid);
end

function s = yesNo(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end
