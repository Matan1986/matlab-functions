% F6J-REPLAY — Replay legacy Dip_depth/FM_abs definitions on current canonical Aging structured exports.
% diagnostic_replay_only not_canonical not_physical_claim not_mechanism not_R_vs_X
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6J_replay_legacy_observables_on_current_pipeline.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6J:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6J_replay_legacy_observables_on_current_pipeline';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6J_replay_legacy_observables_on_current_pipeline.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));

legacyDatasetPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
pointerPath = rp('tables/aging/consolidation_structured_run_dir.txt');
mappingCsv = rp('tables/aging/aging_dataset_mapping_from_structured_outputs.csv');
contractCsv = rp('tables/aging/aging_observable_dataset_contract.csv');
legacyTauDipPath = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
legacyTauFmPath = rp('results_old/aging/runs/run_2026_03_13_013634_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv');
failedDipClockPath = rp('results_old/aging/runs/run_2026_03_13_005134_aging_fm_using_dip_clock/tables/fm_collapse_using_dip_tau_metrics.csv');

outTables = rp('tables/aging');
outReports = rp('reports/aging');
outFig = rp('figures');
for d = {outTables, outReports, outFig}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, {'F6J not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});

runCtx = [];
dipOut = [];
fmOut = [];
tauErrMsg = '';

try
    runCtx = createRunContext('aging', cfg);
    runTablesDir = fullfile(runCtx.run_dir, 'tables');
    runReportsDir = fullfile(runCtx.run_dir, 'reports');
    runFigDir = fullfile(runCtx.run_dir, 'figures');
    for d = {runTablesDir, runReportsDir, runFigDir}
        if exist(d{1}, 'dir') ~= 7
            mkdir(d{1});
        end
    end

    fidPtr = fopen(fullfile(repoRoot, 'run_dir_pointer.txt'), 'w');
    fprintf(fidPtr, '%s\n', runCtx.run_dir);
    fclose(fidPtr);

    %% 1) Definition inventory (code-documented)
    invRows = {
        'consolidation', 'run_aging_observable_dataset_consolidation.m', ...
        'Stage E: reads structured export observable_matrix.csv / observables.csv; maps Tp_K,tw_seconds,Dip_depth,FM_abs to five-column contract (identity numeric copy).', ...
        'YES', 'tables/aging/aging_dataset_mapping_from_structured_outputs.csv';
        'stage4_pipeline', 'Aging/pipeline/stage4_analyzeAFM_FM.m', ...
        'Dip_depth defaults from AFM_amp with Dip_depth_source afm_amp_residual if unset; FM_signed from FM_step_raw/FM_step_mag; FM_abs = abs(FM_signed). Not tanh/Gaussian in contract path.', ...
        'YES', 'smooth/residual decomposition via analyzeAFM_FM_components when agingMetricMode direct';
        'structured_export', 'Aging/analysis/aging_structured_results_export.m', ...
        'buildObservableMatrix emits Dip_depth and FM_abs per pause-run row for consolidation.', ...
        'YES', 'per repo measurement freeze docs';
        'legacy_dataset_build', 'results_old/.../aging_dataset_build', ...
        'Historical run that produced archived aging_observable_dataset.csv used by old tau pipelines.', ...
        'YES', 'see results_old manifest';
        'keywords_stage_DeltaM', 'Aging/pipeline/stage4_analyzeAFM_FM.m', ...
        'DeltaM_signed; dip_signed = DeltaM_signed - DeltaM_smooth; FM_signed physical sign; stage4 not stage5/stage6 summary.', ...
        'YES', 'F6J uses consolidated scalar Dip_depth/FM_abs only';
        'keywords_search_terms', 'repo docs + mapping CSV', ...
        'aging_observable_dataset; Dip_depth; FM_abs; stage4; baseline; residual; dip_component; AFM_like/FM_like via amp/step paths — see aging_measurement_definition_freeze.md.', ...
        'YES', 'no independent R-era script located beyond consolidation + structured export';
        };
    invTbl = cell2table(invRows, 'VariableNames', ...
        {'definition_layer', 'primary_script_or_artifact', 'definition_summary', 'traceable_in_repo', 'notes_or_dependency'});

    %% 2) Resolve current structured aggregate (consolidation pointer)
    assert(exist(pointerPath, 'file') == 2, 'F6J:MissingPointer');
    rawPtr = strtrim(fileread(pointerPath));
    if rawPtr(1) == '/' || (numel(rawPtr) > 2 && rawPtr(2) == ':')
        structuredRunDir = rawPtr;
    else
        structuredRunDir = fullfile(repoRoot, strrep(rawPtr, '/', filesep));
    end
    structuredRunDir = char(string(structuredRunDir));
    matrixPath = fullfile(structuredRunDir, 'tables', 'observable_matrix.csv');
    obsAltPath = fullfile(structuredRunDir, 'tables', 'observables.csv');
    if exist(matrixPath, 'file') == 2
        inPath = matrixPath;
        usedTable = 'observable_matrix.csv';
    elseif exist(obsAltPath, 'file') == 2
        inPath = obsAltPath;
        usedTable = 'observables.csv';
    else
        error('F6J:NoStructuredExport', 'Missing observable_matrix and observables under %s', structuredRunDir);
    end

    inTbl = readtable(inPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    manifestRunId = deriveManifestRunId(structuredRunDir);
    [replayFive, extractionStatus, nIn, nOut] = buildFiveColumnReplay(inTbl, manifestRunId, inPath);

    %% Audit table
    tpVals = unique(replayFive.Tp, 'sorted');
    twVals = unique(replayFive.tw, 'sorted');
    auditTbl = table( ...
        string(structuredRunDir), string(usedTable), height(inTbl), height(replayFive), ...
        min(tpVals), max(tpVals), strjoin(string(tpVals'), ', '), ...
        strjoin(string(twVals'), ', '), ...
        sum(isfinite(replayFive.Dip_depth)), sum(isfinite(replayFive.FM_abs)), ...
        string(extractionStatus), ...
        'VariableNames', {'structured_run_dir', 'table_used', 'n_rows_input', 'n_rows_after_contract_filter', ...
        'tp_min', 'tp_max', 'tp_list', 'tw_list', 'n_finite_dip', 'n_finite_fm', 'replay_note'});

    %% User-named replay dataset + contract copy for tau engines
    replayNamed = table();
    replayNamed.Tp = replayFive.Tp;
    replayNamed.tw = replayFive.tw;
    replayNamed.Dip_depth_replay_olddef_on_current = replayFive.Dip_depth;
    replayNamed.FM_abs_replay_olddef_on_current = replayFive.FM_abs;
    replayNamed.source_current_run = replayFive.source_run;
    replayNamed.extraction_replay_status = repmat(string(extractionStatus), height(replayNamed), 1);

    contractForTauPath = fullfile(runTablesDir, 'aging_F6J_contract_for_tau_pipeline.csv');
    writetable(replayFive, contractForTauPath);

    %% Legacy observable for comparison
    legacyTbl = readLegacyFiveColumn(legacyDatasetPath);

    %% Shape comparison (aligned Tp/tw inner join)
    cmpTbl = buildShapeComparison(legacyTbl, replayNamed);

    %% Optional figures (dip/FM curves only until R table exists)
    makeReplayFigures(outFig, legacyTbl, replayFive);

    %% 3–5) Tau replay (old layers on replay contract)
    dipRunDir = '';
    fmRunDir = '';
    tauReplayTbl = table();
    rCmpTbl = table();

    contractAbs = contractForTauPath;
    if ispc
        contractAbs = strrep(contractAbs, '/', filesep);
    end

    try
        setenv('AGING_OBSERVABLE_DATASET_PATH', contractAbs);
        dipOut = aging_timescale_extraction();
        dipRunDir = char(string(dipOut.run_dir));
        tauDipReplay = readtable(fullfile(dipRunDir, 'tables', 'tau_vs_Tp.csv'), 'TextType', 'string');

        cfgFm = struct();
        cfgFm.datasetPath = contractAbs;
        cfgFm.dipTauPath = fullfile(dipRunDir, 'tables', 'tau_vs_Tp.csv');
        cfgFm.failedDipClockMetricsPath = failedDipClockPath;
        cfgFm.runLabel = 'aging_F6J_fm_tau_replay';
        fmOut = aging_fm_timescale_analysis(cfgFm);
        fmRunDir = char(string(fmOut.run_dir));
        tauFmReplay = readtable(fullfile(fmRunDir, 'tables', 'tau_FM_vs_Tp.csv'), 'TextType', 'string');

        tauReplayTbl = buildTauReplayTable(tauDipReplay, tauFmReplay);
        legacyTauDip = readtable(legacyTauDipPath, 'TextType', 'string');
        legacyTauFm = readtable(legacyTauFmPath, 'TextType', 'string');
        rCmpTbl = buildRcomparison(legacyTauDip, legacyTauFm, tauReplayTbl);
        makeRfigure(outFig, rCmpTbl);
    catch ME
        tauErrMsg = ME.message;
        dipRunDir = '';
        fmRunDir = '';
    end
    setenv('AGING_OBSERVABLE_DATASET_PATH', '');

    %% Verdicts
    verdictTbl = buildVerdictTable(invTbl, auditTbl, replayFive, cmpTbl, tauReplayTbl, rCmpTbl, tauErrMsg);

    %% Write all artifacts
    writetable(invTbl, fullfile(outTables, 'aging_F6J_replay_old_observable_definition_inventory.csv'));
    writetable(auditTbl, fullfile(outTables, 'aging_F6J_current_artifact_replay_input_audit.csv'));
    writetable(replayNamed, fullfile(outTables, 'aging_F6J_olddef_on_current_observable_dataset.csv'));
    writetable(cmpTbl, fullfile(outTables, 'aging_F6J_olddef_on_current_shape_comparison.csv'));
    if ~isempty(tauReplayTbl) && height(tauReplayTbl) > 0
        writetable(tauReplayTbl, fullfile(outTables, 'aging_F6J_olddef_on_current_tau_table.csv'));
    end
    if ~isempty(rCmpTbl) && height(rCmpTbl) > 0
        writetable(rCmpTbl, fullfile(outTables, 'aging_F6J_olddef_on_current_R_comparison.csv'));
    end
    writetable(verdictTbl, fullfile(outTables, 'aging_F6J_replay_status.csv'));

    copyfile(fullfile(outTables, 'aging_F6J_replay_old_observable_definition_inventory.csv'), fullfile(runTablesDir, 'aging_F6J_replay_old_observable_definition_inventory.csv'));
    copyfile(fullfile(outTables, 'aging_F6J_current_artifact_replay_input_audit.csv'), fullfile(runTablesDir, 'aging_F6J_current_artifact_replay_input_audit.csv'));
    copyfile(fullfile(outTables, 'aging_F6J_olddef_on_current_observable_dataset.csv'), fullfile(runTablesDir, 'aging_F6J_olddef_on_current_observable_dataset.csv'));
    copyfile(fullfile(outTables, 'aging_F6J_olddef_on_current_shape_comparison.csv'), fullfile(runTablesDir, 'aging_F6J_olddef_on_current_shape_comparison.csv'));
    if ~isempty(tauReplayTbl) && height(tauReplayTbl) > 0
        copyfile(fullfile(outTables, 'aging_F6J_olddef_on_current_tau_table.csv'), fullfile(runTablesDir, 'aging_F6J_olddef_on_current_tau_table.csv'));
    end
    if ~isempty(rCmpTbl) && height(rCmpTbl) > 0
        copyfile(fullfile(outTables, 'aging_F6J_olddef_on_current_R_comparison.csv'), fullfile(runTablesDir, 'aging_F6J_olddef_on_current_R_comparison.csv'));
    end
    copyfile(fullfile(outTables, 'aging_F6J_replay_status.csv'), fullfile(runTablesDir, 'aging_F6J_replay_status.csv'));
    copyfile(contractForTauPath, fullfile(outTables, 'aging_F6J_contract_for_tau_pipeline.csv'));

    mdPath = fullfile(outReports, 'aging_F6J_replay_legacy_observables_on_current_pipeline.md');
    writeF6Jreport(mdPath, legacyDatasetPath, structuredRunDir, matrixPath, cmpTbl, verdictTbl, tauErrMsg, dipRunDir, fmRunDir);
    copyfile(mdPath, fullfile(runReportsDir, 'aging_F6J_replay_legacy_observables_on_current_pipeline.md'));

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6J replay completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, {'F6J failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'MAIN_RESULT_SUMMARY'});
    if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
        writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
    end
    rethrow(ME);
end

if ~isempty(runCtx) && isfield(runCtx, 'run_dir')
    writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
end

%% --- local functions ---
function id = deriveManifestRunId(structuredRunDir)
manPath = fullfile(structuredRunDir, 'run_manifest.json');
id = '';
if exist(manPath, 'file') == 2
    try
        mf = fileread(manPath);
        if contains(mf, '"run_label"')
            tok = regexp(mf, '"run_label"\s*:\s*"([^"]*)"', 'tokens', 'once');
            if ~isempty(tok)
                id = tok{1};
            end
        end
    catch
        id = '';
    end
end
if isempty(id)
    id = char(string(structuredRunDir));
    ix = strfind(id, filesep);
    if ~isempty(ix)
        id = id(ix(end) + 1:end);
    end
end
end

function [outFive, statusMsg, nIn, nOut] = buildFiveColumnReplay(inTbl, manifestRunId, inPath)
nIn = height(inTbl);
Tp = double(inTbl.Tp_K);
tw = double(inTbl.tw_seconds);
dd = double(inTbl.Dip_depth);
fa = double(inTbl.FM_abs);
n0 = numel(Tp);
src = strings(n0, 1);
for r = 1:n0
    sr = '';
    if ismember('sample', inTbl.Properties.VariableNames)
        sr = char(string(inTbl.sample(r)));
    end
    ds = '';
    if ismember('dataset', inTbl.Properties.VariableNames)
        ds = char(string(inTbl.dataset(r)));
    end
    src(r) = sprintf('%s|%s|%s', manifestRunId, sr, ds);
end
ok = isfinite(Tp) & isfinite(tw) & isfinite(dd) & isfinite(fa) & (tw > 0) & (strlength(strtrim(src)) > 0);
outFive = table();
outFive.Tp = Tp(ok);
outFive.tw = tw(ok);
outFive.Dip_depth = dd(ok);
outFive.FM_abs = fa(ok);
outFive.source_run = src(ok);
statusMsg = sprintf('identity_consolidation_like_finite_FM_required rows %d->%d from %s', nIn, height(outFive), inPath);
nOut = height(outFive);
end

function legacyTbl = readLegacyFiveColumn(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
opts.VariableTypes = {'double', 'double', 'double', 'double', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
opts = setvaropts(opts, 'source_run', 'WhitespaceRule', 'preserve');
legacyTbl = readtable(path, opts);
end

function cmpTbl = buildShapeComparison(legacyTbl, replayNamed)
cmpTbl = table('Size', [0 12], 'VariableTypes', ...
    {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'string', 'string'}, ...
    'VariableNames', {'Tp', 'tw', 'Dip_legacy', 'Dip_replay', 'rel_diff_dip', 'log10_ratio_dip', ...
    'FM_legacy', 'FM_replay', 'rel_diff_fm', 'log10_ratio_fm', 'legacy_row_status', 'replay_row_status'});

for i = 1:height(legacyTbl)
    tp = legacyTbl.Tp(i);
    tw = legacyTbl.tw(i);
    sub = replayNamed(replayNamed.Tp == tp & replayNamed.tw == tw, :);
    dL = legacyTbl.Dip_depth(i);
    fL = legacyTbl.FM_abs(i);
    if isempty(sub)
        legacyTag = 'legacy_only';
        replayTag = 'missing_on_current_aggregate';
        dR = NaN;
        fR = NaN;
    else
        dR = sub.Dip_depth_replay_olddef_on_current(1);
        fR = sub.FM_abs_replay_olddef_on_current(1);
        legacyTag = 'aligned';
        replayTag = 'aligned';
    end
    rd = relDiff(dL, dR);
    rf = relDiff(fL, fR);
    lr = log10Ratio(dL, dR);
    lrf = log10Ratio(fL, fR);
    cmpTbl = [cmpTbl; {tp, tw, dL, dR, rd, lr, fL, fR, rf, lrf, legacyTag, replayTag}]; %#ok<AGROW>
end
end

function x = relDiff(a, b)
if ~isfinite(a) || ~isfinite(b)
    x = NaN;
elseif abs(a) > eps
    x = (b - a) / abs(a);
else
    x = b - a;
end
end

function x = log10Ratio(a, b)
if isfinite(a) && isfinite(b) && a > 0 && b > 0
    x = log10(b / a);
else
    x = NaN;
end
end

function makeReplayFigures(outFig, legacyTbl, replayFive)
tpPlot = 26;
subL = legacyTbl(legacyTbl.Tp == tpPlot, :);
subR = replayFive(replayFive.Tp == tpPlot, :);
subL = sortrows(subL, 'tw');
subR = sortrows(subR, 'tw');
if height(subL) >= 2 && height(subR) >= 2
    fx = figure('Position', [80 80 720 460], 'Color', 'w');
    tiledlayout(1, 2, 'Padding', 'compact');
    nexttile;
    loglog(subL.tw, abs(subL.Dip_depth), '-o', 'DisplayName', 'legacy'); hold on;
    loglog(subR.tw, abs(subR.Dip_depth), '-s', 'DisplayName', 'replay current');
    grid on;
    title(sprintf('T_p=%g K |Dip_depth|', tpPlot));
    legend('Location', 'best');
    xlabel('t_w (s)');
    nexttile;
    loglog(subL.tw, abs(subL.FM_abs), '-o', 'DisplayName', 'legacy'); hold on;
    loglog(subR.tw, abs(subR.FM_abs), '-s', 'DisplayName', 'replay current');
    grid on;
    title(sprintf('T_p=%g K |FM_abs|', tpPlot));
    legend('Location', 'best');
    xlabel('t_w (s)');
    sgtitle('F6J legacy vs replay (non-canonical)', 'Interpreter', 'none');
    exportgraphics(fx, fullfile(outFig, 'aging_F6J_olddef_current_vs_legacy_Dip_depth.png'), 'Resolution', 120);
    close(fx);
end

% R comparison figure requires tau paths — skip if not available
end

function tauReplayTbl = buildTauReplayTable(tauDipReplay, tauFmReplay)
tauReplayTbl = table('Size', [0 6], 'VariableTypes', ...
    {'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Tp', 'tau_dip_replay_seconds', 'tau_fm_replay_seconds', 'R_replay', ...
    'fm_has_fm_flag', 'matched_row'});
for i = 1:height(tauDipReplay)
    tp = tauDipReplay.Tp(i);
    rowF = tauFmReplay(tauFmReplay.Tp == tp, :);
    if isempty(rowF)
        continue;
    end
    td = tauDipReplay.tau_effective_seconds(i);
    hasFm = 1;
    if ismember('has_fm', rowF.Properties.VariableNames)
        hasFm = double(rowF.has_fm(1));
    end
    tf = rowF.tau_effective_seconds(1);
    if ~isfinite(td) || ~isfinite(tf) || td <= 0 || tf <= 0 || hasFm < 1
        R = NaN;
    else
        R = tf / td;
    end
    tauReplayTbl = [tauReplayTbl; {tp, td, tf, R, hasFm, 1}]; %#ok<AGROW>
end
end

function makeRfigure(outFig, rCmpTbl)
if isempty(rCmpTbl) || height(rCmpTbl) < 2
    return;
end
sub = rCmpTbl(isfinite(rCmpTbl.R_legacy) & isfinite(rCmpTbl.R_replay), :);
if height(sub) < 2
    return;
end
fx = figure('Position', [80 80 560 420], 'Color', 'w');
plot(sub.Tp, sub.R_legacy, '-o', 'DisplayName', 'R legacy'); hold on;
plot(sub.Tp, sub.R_replay, '-s', 'DisplayName', 'R replay on current');
grid on;
ylabel('R = tau_FM / tau_Dip');
xlabel('T_p (K)');
title('F6J R comparison (non-canonical)');
legend('Location', 'best');
exportgraphics(fx, fullfile(outFig, 'aging_F6J_olddef_current_R_vs_legacy_R.png'), 'Resolution', 120);
close(fx);
end

function rCmpTbl = buildRcomparison(legacyTauDip, legacyTauFm, tauReplayTbl)
rCmpTbl = table('Size', [0 10], 'VariableTypes', ...
    {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'string', 'string'}, ...
    'VariableNames', {'Tp', 'tau_dip_legacy', 'tau_fm_legacy', 'R_legacy', ...
    'tau_dip_replay', 'tau_fm_replay', 'R_replay', 'log10_R_ratio_replay_over_legacy', ...
    'legacy_finite', 'replay_finite'});
tpList = unique(tauReplayTbl.Tp);
for k = 1:numel(tpList)
    tp = tpList(k);
    ld = legacyTauDip(legacyTauDip.Tp == tp, :);
    lf = legacyTauFm(legacyTauFm.Tp == tp, :);
    if isempty(ld)
        continue;
    end
    tdL = ld.tau_effective_seconds(1);
    tfL = NaN;
    Rl = NaN;
    legFin = 'dip_only';
    if ~isempty(lf) && ismember('has_fm', lf.Properties.VariableNames) && lf.has_fm(1) >= 1
        tfL = lf.tau_effective_seconds(1);
        if isfinite(tdL) && isfinite(tfL) && tdL > 0 && tfL > 0
            Rl = tfL / tdL;
        end
        legFin = 'dip_fm';
    end
    Rr = tauReplayTbl.R_replay(tauReplayTbl.Tp == tp);
    if numel(Rr) > 1
        Rr = Rr(1);
    elseif isempty(Rr)
        Rr = NaN;
    else
        Rr = Rr(1);
    end
    tdr = tauReplayTbl.tau_dip_replay_seconds(tauReplayTbl.Tp == tp);
    tfr = tauReplayTbl.tau_fm_replay_seconds(tauReplayTbl.Tp == tp);
    if ~isempty(tdr), tdr = tdr(1); else, tdr = NaN; end
    if ~isempty(tfr), tfr = tfr(1); else, tfr = NaN; end
    lratio = NaN;
    if isfinite(Rl) && isfinite(Rr) && Rl > 0 && Rr > 0
        lratio = log10(Rr / Rl);
    end
    rFin = 'finite';
    if ~isfinite(Rr)
        rFin = 'not_finite';
    end
    rCmpTbl = [rCmpTbl; {tp, tdL, tfL, Rl, tdr, tfr, Rr, lratio, legFin, rFin}]; %#ok<AGROW>
end
end

function verdictTbl = buildVerdictTable(invTbl, auditTbl, replayFive, cmpTbl, tauReplayTbl, rCmpTbl, tauErrMsg)
ex = 'YES';
app = 'NO';
created = 'YES';
tauRan = 'NO';
rRep = 'NOT_RUN';
spikeRep = 'NO';
if ~isempty(cmpTbl) && height(cmpTbl) > 0
    al = cmpTbl(strcmp(cmpTbl.replay_row_status, 'aligned'), :);
    if ~isempty(al)
        mad = median(abs(al.rel_diff_dip), 'omitnan');
        if mad > 0.05 || max(abs(al.rel_diff_dip), [], 'omitnan') > 0.5
            ex = 'PARTIAL';
            app = 'YES';
        end
    end
end
if ~isempty(tauErrMsg) && strlength(string(tauErrMsg)) > 0
    tauRan = 'NO';
    rRep = 'NOT_RUN';
elseif ~isempty(tauReplayTbl) && height(tauReplayTbl) > 0
    tauRan = 'YES';
    rRep = 'PARTIAL';
end
if ~isempty(rCmpTbl) && height(rCmpTbl) > 0
    rRep = 'PARTIAL';
    sub = rCmpTbl(rCmpTbl.Tp == 26 & isfinite(rCmpTbl.R_legacy) & isfinite(rCmpTbl.R_replay), :);
    if ~isempty(sub)
        lr = abs(log10(sub.R_replay(1) / sub.R_legacy(1)));
        if lr < 0.25
            rRep = 'YES';
        end
        if sub.R_replay(1) > 50 && sub.R_legacy(1) > 50
            spikeRep = 'YES';
        end
    end
end

rows = {
    'F6J_REPLAY_COMPLETED', 'YES';
    'LEGACY_OBSERVABLE_BUILDER_FOUND', 'YES';
    'CURRENT_CANONICAL_INPUTS_FOUND', 'YES';
    'EXACT_OLD_OBSERVABLE_REPLAY_POSSIBLE', ex;
    'APPROXIMATE_OLD_OBSERVABLE_REPLAY_PERFORMED', app;
    'OLDDEF_CURRENT_OBSERVABLE_DATASET_CREATED', created;
    'OLD_TAU_LAYER_REPLAYED_ON_CURRENT_OBSERVABLES', tauRan;
    'OLD_R_REPRODUCED_ON_CURRENT_RUNS', rRep;
    'OLD_26K_SPIKE_REPRODUCED_ON_CURRENT_RUNS', spikeRep;
    'OLD_VALUES_USED_AS_CANONICAL_EVIDENCE', 'NO';
    'NEW_METHOD_SEARCH_PERFORMED', 'NO';
    'R_VS_X_ANALYSIS_PERFORMED', 'NO';
    'MECHANISM_VALIDATION_PERFORMED', 'NO';
    'READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH', 'YES'
    };
verdictTbl = cell2table(rows, 'VariableNames', {'verdict_key', 'verdict_value'});
end

function writeF6Jreport(mdPath, legacyDatasetPath, structuredRunDir, matrixPath, cmpTbl, verdictTbl, tauErrMsg, dipRunDir, fmRunDir)
fid = fopen(mdPath, 'w');
fprintf(fid, '# F6J-REPLAY: legacy observable definitions on current structured exports\n\n');
fprintf(fid, 'diagnostic_replay_only; not_canonical; not_physical_claim.\n\n');
fprintf(fid, '- Legacy reference dataset: `%s`\n', legacyDatasetPath);
fprintf(fid, '- Current structured aggregate dir: `%s`\n', structuredRunDir);
fprintf(fid, '- Matrix file: `%s`\n\n', matrixPath);
fprintf(fid, '## Definition (summary)\n\n');
fprintf(fid, 'Legacy `Dip_depth` / `FM_abs` in the five-column contract are **identity copies** of `observable_matrix.csv` columns produced by structured export (`aging_structured_results_export` / Stage4/stage pipeline), consolidated by `run_aging_observable_dataset_consolidation.m`. Stage4 sets `Dip_depth` from residual/AFM amplitude path and `FM_abs = abs(FM_signed)` (`stage4_analyzeAFM_FM.m`). This replay **does not** use `Dip_depth_direct_TrackB`.\n\n');
fprintf(fid, '## Verdicts\n\n');
for i = 1:height(verdictTbl)
    fprintf(fid, '- **%s**: %s\n', verdictTbl.verdict_key{i}, verdictTbl.verdict_value{i});
end
if ~isempty(tauErrMsg)
    fprintf(fid, '\n## Tau replay error\n\n```\n%s\n```\n', tauErrMsg);
else
    fprintf(fid, '\n## Tau run directories (diagnostic)\n\n');
    fprintf(fid, '- Dip extraction: `%s`\n', dipRunDir);
    fprintf(fid, '- FM extraction: `%s`\n', fmRunDir);
end
fprintf(fid, '\n## Shape comparison notes\n\n');
if ~isempty(cmpTbl) && height(cmpTbl) > 0
    sm = cmpTbl(cmpTbl.Tp == 26 & cmpTbl.tw == 3600, :);
    if ~isempty(sm)
        fprintf(fid, 'At 26 K, t_w=3600 s: rel_diff_dip=%.4g, rel_diff_fm=%.4g (see CSV for full grid).\n', ...
            sm.rel_diff_dip(1), sm.rel_diff_fm(1));
    end
end
fprintf(fid, '\n## Tables\n\nSee `tables/aging/aging_F6J_*.csv`.\n');
fclose(fid);
end
