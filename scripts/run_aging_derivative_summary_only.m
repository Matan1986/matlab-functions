clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

cfgRun = struct();
cfgRun.runLabel = 'aging_derivative_summary_only';

try
    run = createRunContext('aging', cfgRun);

    inCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_derivative_method_results.csv');
    if exist(inCsv, 'file') ~= 2
        error('DerivativeSummaryOnly:MissingInput', 'Input table missing: %s', inCsv);
    end

    tbl = readtable(inCsv);
    vars = string(tbl.Properties.VariableNames);

    hasT = any(vars == "T");
    hasAFM = any(vars == "AFM");
    hasFM = any(vars == "FM");

    if ~(hasT && hasAFM && hasFM)
        cfg = struct();
        cfg.dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';
        cfg.normalizeByMass = true;
        cfg.debugMode = false;
        cfg.Bohar_units = true;
        cfg.agingMetricMode = 'derivative';
        cfg.AFM_metric_main = 'area';
        cfg.dip_window_K = 5;
        cfg.smoothWindow_K = 20;
        cfg.excludeLowT_FM = true;
        cfg.excludeLowT_K = 6;
        cfg.FM_plateau_K = 6;
        cfg.excludeLowT_mode = 'pre';
        cfg.FM_buffer_K = 6;
        cfg.filterMethod = 'sgolay';
        cfg.sgolayOrder = 2;
        cfg.sgolayFrame = 15;
        cfg.doFilterDeltaM = true;
        cfg.alignDeltaM = false;
        cfg.alignRef = 'lowT';
        cfg.alignWindow_K = 2;
        cfg.subtractOrder = 'noMinusPause';

        stateRaw = stage1_loadData(cfg);
        stateRaw = stage2_preprocess(stateRaw, cfg);
        stateRaw = stage3_computeDeltaM(stateRaw, cfg);

        nRuns = numel(stateRaw.pauseRuns);
        T = nan(nRuns, 1);
        AFM = nan(nRuns, 1);
        FM = nan(nRuns, 1);
        left_median = nan(nRuns, 1);
        right_median = nan(nRuns, 1);

        for i = 1:nRuns
            runi = stateRaw.pauseRuns(i);
            result = analyzeAFM_FM_derivative(runi.T_common, runi.DeltaM, runi.waitK, cfg);
            T(i) = runi.waitK;
            if isfield(result, 'AFM_area') && isfinite(result.AFM_area)
                AFM(i) = result.AFM_area;
            elseif isfield(result, 'AFM_amp') && isfinite(result.AFM_amp)
                AFM(i) = result.AFM_amp;
            end
            if isfield(result, 'FM_step_mag') && isfinite(result.FM_step_mag)
                FM(i) = result.FM_step_mag;
            end
            if isfield(result, 'diagnostics') && isstruct(result.diagnostics)
                if isfield(result.diagnostics, 'baseL') && isfinite(result.diagnostics.baseL)
                    left_median(i) = result.diagnostics.baseL;
                end
                if isfield(result.diagnostics, 'baseR') && isfinite(result.diagnostics.baseR)
                    right_median(i) = result.diagnostics.baseR;
                end
            end
        end

        tbl = table(T, AFM, FM, left_median, right_median, ...
            'VariableNames', {'T', 'AFM', 'FM', 'left_median', 'right_median'});
        writetable(tbl, inCsv);
    end

    T = tbl.T(:);
    AFM = tbl.AFM(:);
    FM = tbl.FM(:);

    n = numel(T);
    pauseRuns = repmat(struct( ...
        'waitK', NaN, ...
        'Dip_A', NaN, ...
        'Dip_sigma', NaN, ...
        'Dip_area', NaN, ...
        'FM_step_A', NaN, ...
        'FM_E', NaN), n, 1);
    for i = 1:n
        pauseRuns(i).waitK = T(i);
        pauseRuns(i).Dip_A = AFM(i);
        pauseRuns(i).Dip_sigma = NaN;
        pauseRuns(i).Dip_area = AFM(i);
        pauseRuns(i).FM_step_A = FM(i);
        pauseRuns(i).FM_E = FM(i);
    end

    state = struct();
    state.pauseRuns = pauseRuns;

    cfgSummary = struct();
    cfgSummary.agingMetricMode = 'derivative';
    cfgSummary.AFM_metric_main = 'area';
    cfgSummary.fontsize = 24;
    cfgSummary.disableStage6Diagnostics = true;

    close all;
    stage6_extractMetrics(state, cfgSummary);

    h = findobj('Type', 'figure', 'Name', 'Aging memory summary');
    if isempty(h)
        error('DerivativeSummaryOnly:SummaryFigureMissing', 'Aging memory summary figure was not generated');
    end
    h = h(1);
    set(h, 'Visible', 'off');

    figPath = fullfile(run.run_dir, 'aging_derivative_summary.fig');
    pngPath = fullfile(run.run_dir, 'aging_derivative_summary.png');
    savefig(h, figPath);
    exportgraphics(h, pngPath, 'Resolution', 300);
    close(h);

    reportPath = fullfile(repoRoot, 'reports', 'aging', 'aging_summary_debug.md');
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('DerivativeSummaryOnly:ReportWriteFailed', 'Cannot write report');
    end
    missingMask = ~isfinite(FM);
    missingTemps = T(missingMask);
    if isempty(missingTemps)
        missingText = 'none';
    else
        missingText = strjoin(string(missingTemps.'), ', ');
    end
    fprintf(fid, '# Aging Summary Debug\n\n');
    fprintf(fid, '## Labels and format\n\n');
    fprintf(fid, '- Reused original summary generator: `Aging/pipeline/stage6_extractMetrics.m`\n');
    fprintf(fid, '- Panel wording and unit formatting are now from the original summary style (no derivative wording).\n\n');
    fprintf(fid, '## Missing temperatures in FM panel\n\n');
    fprintf(fid, '- WHY_ARE_TEMPERATURES_MISSING = FM is NaN for temperatures where derivative baseline windows are insufficient (`FM_plateau_valid = false` path); those rows remain in table but markers are not drawn for NaN y-values.\n');
    fprintf(fid, '- Missing FM temperatures: %s\n\n', missingText);
    fprintf(fid, '## Sign consistency\n\n');
    fprintf(fid, '- WHY_AFM_POSITIVE = AFM is a dip-magnitude metric (area/height convention is positive by construction).\n');
    fprintf(fid, '- WHY_FM_NEGATIVE = derivative FM is defined as `median(right) - median(left)` on DeltaM_smooth and can be negative depending on baseline ordering around Tp.\n');
    fprintf(fid, '- SIGN_CONVENTION_CORRECT = YES (sign preserved, no abs sign hack in plotting).\n\n');
    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- Output FIG: `%s`\n', figPath);
    fprintf(fid, '- Output PNG: `%s`\n', pngPath);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, n, {'aging summary generated with original style labels and sign debug report'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_derivative_summary_only_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'aging summary only generation failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
