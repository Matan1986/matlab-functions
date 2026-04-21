clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

runCfg = struct();
runCfg.runLabel = 'extrema_smoothed_minimal_validation';

try
    run = createRunContext('aging', runCfg);

    cfg = struct();
    cfg.agingMetricMode = 'extrema_smoothed';
    cfg.doPlotting = false;
    cfg.debug = struct();
    cfg.debug.enable = false;
    cfg.debug.plotVisible = "off";
    cfg.debug.plots = "none";
    cfg.debug.plotGeometry = false;
    cfg.saveTableMode = 'none';
    cfg.run = run;
    cfg.outputFolder = run.run_dir;
    cfg.sample_name = 'MG119';
    cfg.fontsize = 16;
    cfg.AFM_metric_main = 'area';
    cfg.dip_window_K = 5;
    cfg.RobustnessCheck = false;
    cfg.showAFM_FM_example = false;

    Tp = [10; 14; 18; 22; 26];
    Tgrid = linspace(4, 34, 61)';
    pauseRuns = repmat(struct(), numel(Tp), 1);
    for i = 1:numel(Tp)
        amp = 0.03 + 0.002 * i;
        baseline = 0.15 - 0.0015 * Tgrid;
        dip = -amp * exp(-0.5 * ((Tgrid - Tp(i)) / 2.0).^2);
        Mtrace = baseline + dip;
        pauseRuns(i).waitK = Tp(i);
        pauseRuns(i).M = Mtrace;
        pauseRuns(i).T_common = Tgrid;
        pauseRuns(i).DeltaM = dip;
        pauseRuns(i).DeltaM_atPause = interp1(Tgrid, dip, Tp(i), 'linear', 'extrap');
        pauseRuns(i).DeltaM_localMin = min(dip);
        pauseRuns(i).T_localMin = Tgrid(dip == min(dip));
        if numel(pauseRuns(i).T_localMin) > 1
            pauseRuns(i).T_localMin = pauseRuns(i).T_localMin(1);
        end
    end

    state = struct();
    state.pauseRuns = pauseRuns;

    set(0, 'DefaultFigureVisible', 'off');
    state = stage4_analyzeAFM_FM(state, cfg);
    state = stage6_extractMetrics(state, cfg);
    stage9_export(state, cfg);

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

    resultPath = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_smoothed_results.csv');
    hasResult = exist(resultPath, 'file') == 2;
    nRows = 0;
    statusMessage = 'extrema_smoothed run completed';
    if hasResult
        resultTbl = readtable(resultPath);
        nRows = height(resultTbl);
    else
        statusMessage = 'missing extrema_smoothed results csv';
    end

    reportPath = fullfile(run.run_dir, 'extrema_smoothed_validation_run.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('ExtremaSmoothedValidation:ReportWriteFailed', 'Failed to write run report');
    end
    fprintf(fidReport, '# extrema\\_smoothed Minimal Run\\n\\n');
    fprintf(fidReport, '- MODE: %s\\n', cfg.agingMetricMode);
    fprintf(fidReport, '- STAGES: stage4 -> stage6 -> stage9\\n');
    fprintf(fidReport, '- RESULT_CSV: %s\\n', resultPath);
    fprintf(fidReport, '- RESULT_ROWS: %d\\n', nRows);
    fprintf(fidReport, '- FIG_PATH: %s\\n', figPath);
    fprintf(fidReport, '- PNG_PATH: %s\\n', pngPath);
    fclose(fidReport);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRows, {statusMessage}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_extrema_smoothed_validation_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'extrema_smoothed minimal run failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
