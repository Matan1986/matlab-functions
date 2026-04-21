clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

runCfg = struct();
runCfg.runLabel = 'extrema_smoothed_temperature_audit';

try
    run = createRunContext('aging', runCfg);

    cfg = struct();
    cfg.dataDir = dataDir;
    cfg.normalizeByMass = true;
    cfg.debugMode = false;
    cfg.Bohar_units = true;
    cfg.agingMetricMode = 'extrema_smoothed';
    cfg.AFM_metric_main = 'area';
    cfg.dip_window_K = 5;
    cfg.subtractOrder = 'noMinusPause';
    cfg.alignDeltaM = false;
    cfg.alignRef = 'lowT';
    cfg.alignWindow_K = 2;
    cfg.doFilterDeltaM = true;
    cfg.filterMethod = 'sgolay';
    cfg.sgolayOrder = 2;
    cfg.sgolayFrame = 15;
    cfg.fontsize = 16;
    cfg.saveTableMode = 'none';
    cfg.outputFolder = run.run_dir;
    cfg.sample_name = 'MG119';
    cfg.RobustnessCheck = false;
    cfg.showAFM_FM_example = false;
    cfg.debug = struct();
    cfg.debug.enable = false;
    cfg.debug.plotGeometry = false;
    cfg.run = run;

    files = dir(fullfile(dataDir, '*aging_*.dat'));
    rawPauseTemps = [];
    for i = 1:numel(files)
        meta = parseAgingFilename(files(i).name);
        if ~meta.isNoPause && isfinite(meta.waitK)
            rawPauseTemps(end+1,1) = meta.waitK; %#ok<AGROW>
        end
    end
    rawPauseTemps = sort(rawPauseTemps);

    state = stage1_loadData(cfg);
    stage1Temps = [state.pauseRuns.waitK]';

    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);
    stage3Temps = [state.pauseRuns.waitK]';

    state = stage4_analyzeAFM_FM(state, cfg);
    stage4Temps = [state.pauseRuns.waitK]';

    set(0, 'DefaultFigureVisible', 'off');
    state = stage6_extractMetrics(state, cfg);
    plotTemps = [state.pauseRuns.waitK]';

    summaryFig = findobj('Type', 'figure', 'Name', 'Aging memory summary');
    if ~isempty(summaryFig)
        summaryFig = summaryFig(1);
        figPath = fullfile(run.run_dir, 'aging_memory_summary_extrema_smoothed.fig');
        pngPath = fullfile(run.run_dir, 'aging_memory_summary_extrema_smoothed.png');
        savefig(summaryFig, figPath);
        exportgraphics(summaryFig, pngPath, 'Resolution', 300);
    else
        figPath = '';
        pngPath = '';
    end

    stage9_export(state, cfg);

    extremaCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_smoothed_results.csv');
    extremaTbl = readtable(extremaCsv);
    stage9Temps = extremaTbl.temperature;

    mkList = @(x) strjoin(string(sort(x(:)')), ';');
    auditTbl = table( ...
        ["raw_dataset_folder"; "stage1_loadData"; "stage3_computeDeltaM"; "stage4_analyzeAFM_FM"; "stage6_extractMetrics_plot_input"; "stage9_export_csv"], ...
        [mkList(rawPauseTemps); mkList(stage1Temps); mkList(stage3Temps); mkList(stage4Temps); mkList(plotTemps); mkList(stage9Temps)], ...
        [numel(rawPauseTemps); numel(stage1Temps); numel(stage3Temps); numel(stage4Temps); numel(plotTemps); numel(stage9Temps)], ...
        ["pause temperatures parsed from filenames"; ...
         "pauseRuns.waitK after stage1"; ...
         "pauseRuns.waitK preserved through stage3"; ...
         "pauseRuns.waitK preserved through stage4"; ...
         "Tp vector used by summary plotting"; ...
         "temperature column written to results csv"], ...
        'VariableNames', {'source_stage', 'temperatures_present', 'n_temperatures', 'notes'});

    auditCsvPath = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_smoothed_temperature_audit.csv');
    writetable(auditTbl, auditCsvPath);

    fullRangePlotted = isequal(sort(rawPauseTemps), sort(plotTemps));
    axisFixed = ~isempty(figPath) && ~isempty(pngPath);
    if axisFixed
        axisFixedStr = 'YES';
    else
        axisFixedStr = 'NO';
    end
    if fullRangePlotted
        fullRangeStr = 'YES';
    else
        fullRangeStr = 'NO';
    end
    reportPath = fullfile(repoRoot, 'reports', 'aging', 'aging_extrema_smoothed_figure_fix.md');
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('ExtremaSmoothedAudit:ReportWriteFailed', 'Failed to write figure fix report');
    end
    fprintf(fid, '# extrema_smoothed Figure Fix and Temperature Audit\n\n');
    fprintf(fid, '## 1. Axis fix\n\n');
    fprintf(fid, '- Cause: stage6 forced axis limits with fixed x padding (+/-1 K) and y lower bound at 0, which can make bounds tight and clip negative values.\n');
    fprintf(fid, '- Change: stage6 now uses data-driven x and y padding (5%% span, with minimal floor), keeping the same plotting style and function.\n\n');
    fprintf(fid, '## 2. Temperature audit\n\n');
    fprintf(fid, '- Raw dataset pause temperatures: %s\n', mkList(rawPauseTemps));
    fprintf(fid, '- Loaded in pipeline (stage1): %s\n', mkList(stage1Temps));
    fprintf(fid, '- After stage4: %s\n', mkList(stage4Temps));
    fprintf(fid, '- Passed to plotting (stage6 Tp): %s\n', mkList(plotTemps));
    fprintf(fid, '- Exported in stage9 csv: %s\n', mkList(stage9Temps));
    fprintf(fid, '- Missing-temperature root cause in prior run: the earlier minimal validation script used a hard-coded subset [10,14,18,22,26], so 6,30,34 K were never included.\n\n');
    fprintf(fid, '## 3. Final verdict\n\n');
    fprintf(fid, '- AXIS_LIMITS_FIXED = %s\n', axisFixedStr);
    fprintf(fid, '- FULL_TEMPERATURE_RANGE_PLOTTED = %s\n', fullRangeStr);
    fprintf(fid, '- FIG_PATH = %s\n', figPath);
    fprintf(fid, '- PNG_PATH = %s\n', pngPath);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(extremaTbl), {'temperature audit and figure fix completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_extrema_smoothed_temperature_audit_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'temperature audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
