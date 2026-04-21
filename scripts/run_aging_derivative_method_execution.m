clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

cfgRun = struct();
cfgRun.runLabel = 'aging_derivative_method_execution';

try
    run = createRunContext('aging', cfgRun);

    cfg = struct();
    cfg.dataDir = dataDir;
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
    cfg.outputFolder = run.run_dir;
    cfg.sample_name = 'MG119';

    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    nRuns = numel(state.pauseRuns);
    Tp = nan(nRuns, 1);
    AFM = nan(nRuns, 1);
    FM = nan(nRuns, 1);
    baseline_left_median = nan(nRuns, 1);
    baseline_right_median = nan(nRuns, 1);
    baseline_slope = nan(nRuns, 1);
    n_left = nan(nRuns, 1);
    n_right = nan(nRuns, 1);
    FM_plateau_valid = false(nRuns, 1);

    representativeIdx = 1;
    targetTp = 22;
    bestDist = inf;
    repT = [];
    repDM = [];
    repDMSmooth = [];
    repTp = NaN;
    repBaseL = NaN;
    repBaseR = NaN;
    repLeftMask = [];
    repRightMask = [];
    repDipMask = [];

    for i = 1:nRuns
        runi = state.pauseRuns(i);
        if ~isfield(runi, 'T_common') || ~isfield(runi, 'DeltaM') || ~isfield(runi, 'waitK')
            continue;
        end
        if isempty(runi.T_common) || isempty(runi.DeltaM) || ~isfinite(runi.waitK)
            continue;
        end

        result = analyzeAFM_FM_derivative(runi.T_common, runi.DeltaM, runi.waitK, cfg);

        Tp(i) = runi.waitK;
        if isfield(result, 'AFM_area') && isfinite(result.AFM_area)
            AFM(i) = result.AFM_area;
        elseif isfield(result, 'AFM_amp') && isfinite(result.AFM_amp)
            AFM(i) = result.AFM_amp;
        end
        if isfield(result, 'FM_step_mag') && isfinite(result.FM_step_mag)
            FM(i) = result.FM_step_mag;
        end
        if isfield(result, 'baseline_slope') && isfinite(result.baseline_slope)
            baseline_slope(i) = result.baseline_slope;
        end
        if isfield(result, 'FM_plateau_valid')
            FM_plateau_valid(i) = logical(result.FM_plateau_valid);
        end

        if isfield(result, 'diagnostics') && isstruct(result.diagnostics)
            if isfield(result.diagnostics, 'baseL') && isfinite(result.diagnostics.baseL)
                baseline_left_median(i) = result.diagnostics.baseL;
            end
            if isfield(result.diagnostics, 'baseR') && isfinite(result.diagnostics.baseR)
                baseline_right_median(i) = result.diagnostics.baseR;
            end
            if isfield(result.diagnostics, 'leftCount') && isfinite(result.diagnostics.leftCount)
                n_left(i) = result.diagnostics.leftCount;
            end
            if isfield(result.diagnostics, 'rightCount') && isfinite(result.diagnostics.rightCount)
                n_right(i) = result.diagnostics.rightCount;
            end
        end

        dist = abs(runi.waitK - targetTp);
        if dist < bestDist
            bestDist = dist;
            representativeIdx = i;
            repT = runi.T_common(:);
            repDM = runi.DeltaM(:);
            repTp = runi.waitK;
            if isfield(result, 'DeltaM_smooth') && ~isempty(result.DeltaM_smooth)
                repDMSmooth = result.DeltaM_smooth(:);
            else
                repDMSmooth = nan(size(repDM));
            end
            if isfield(result, 'diagnostics') && isstruct(result.diagnostics)
                if isfield(result.diagnostics, 'baseL')
                    repBaseL = result.diagnostics.baseL;
                end
                if isfield(result.diagnostics, 'baseR')
                    repBaseR = result.diagnostics.baseR;
                end
                if isfield(result.diagnostics, 'leftMask')
                    repLeftMask = result.diagnostics.leftMask(:);
                end
                if isfield(result.diagnostics, 'rightMask')
                    repRightMask = result.diagnostics.rightMask(:);
                end
                if isfield(result.diagnostics, 'dipMask')
                    repDipMask = result.diagnostics.dipMask(:);
                end
            end
        end
    end

    resultsTbl = table(Tp, AFM, FM, baseline_left_median, baseline_right_median, baseline_slope, n_left, n_right, FM_plateau_valid, ...
        'VariableNames', {'T', 'AFM', 'FM', 'left_median', 'right_median', 'baseline_slope', 'n_left', 'n_right', 'FM_plateau_valid'});
    outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_derivative_method_results.csv');
    writetable(resultsTbl, outCsv);

    repStep = nan(size(repDM));
    if isfinite(repBaseL)
        repStep(repT <= repTp - cfg.dip_window_K) = repBaseL;
    end
    if isfinite(repBaseR)
        repStep(repT >= repTp + cfg.dip_window_K) = repBaseR;
    end

    transitionMask = (repT > repTp - cfg.dip_window_K) & (repT < repTp + cfg.dip_window_K);
    if any(transitionMask) && isfinite(repBaseL) && isfinite(repBaseR)
        tTransition = repT(transitionMask);
        t0 = min(tTransition);
        t1 = max(tTransition);
        if t1 > t0
            repStep(transitionMask) = repBaseL + (repBaseR - repBaseL) * ((tTransition - t0) ./ (t1 - t0));
        else
            repStep(transitionMask) = repBaseL;
        end
    end

    repStep(~isfinite(repStep)) = repDMSmooth(~isfinite(repStep));
    repDip = repDM - repStep;

    pauseRunPlot = struct();
    pauseRunPlot.T_common = repT;
    pauseRunPlot.DeltaM = repDM;
    pauseRunPlot.DeltaM_smooth = repStep;
    pauseRunPlot.DeltaM_sharp = repDip;
    pauseRunPlot.waitK = repTp;
    pauseRunPlot.excludeLowT_FM = cfg.excludeLowT_FM;
    pauseRunPlot.excludeLowT_K = cfg.excludeLowT_K;

    plotAFM_FM_decomposition(pauseRunPlot, 16);
    fig = gcf;
    set(fig, 'Visible', 'off');

    figPath = fullfile(run.run_dir, 'aging_derivative_decomposition_reuse.fig');
    pngPath = fullfile(run.run_dir, 'aging_derivative_decomposition_reuse.png');
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    reportPath = fullfile(repoRoot, 'reports', 'aging', 'aging_derivative_method_explanation.md');
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('DerivativeMethodExecution:ReportWriteFailed', 'Failed to write report file');
    end
    fprintf(fid, '# Aging Derivative Method Explanation\n\n');
    fprintf(fid, '## Exact computation\n\n');
    fprintf(fid, '### AFM\n\n');
    fprintf(fid, '- Input signal variable: `dM` (DeltaM)\n');
    fprintf(fid, '- Code path: `Aging/models/analyzeAFM_FM_derivative.m` calls `Aging/models/analyzeAFM_FM_components.m`\n');
    fprintf(fid, '- Exact AFM extraction expressions in decomposition backbone:\n');
    fprintf(fid, '  - height mode: `pauseRuns(i).AFM_amp = -mean(dipVals);`\n');
    fprintf(fid, '  - area mode: `pauseRuns(i).AFM_area = trapz(xDip, yDip);`\n');
    fprintf(fid, '- In this run (`cfg.AFM_metric_main = ''area''`), AFM output is area metric (`AFM_area`).\n\n');
    fprintf(fid, '### FM\n\n');
    fprintf(fid, '- Exact expression in derivative method:\n');
    fprintf(fid, '  - `baseL = median(dM_smooth(leftMask), ''omitnan'');`\n');
    fprintf(fid, '  - `baseR = median(dM_smooth(rightMask), ''omitnan'');`\n');
    fprintf(fid, '  - `result.FM_step_raw = baseR - baseL;`\n');
    fprintf(fid, '  - `result.FM_step_mag = result.FM_step_raw;`\n');
    fprintf(fid, '- Left region definition: `leftMask = isfinite(T) & isfinite(dM_smooth) & (T < Tp - cfg.dip_window_K);`\n');
    fprintf(fid, '- Right region definition: `rightMask = isfinite(T) & isfinite(dM_smooth) & (T > Tp + cfg.dip_window_K);`\n');
    fprintf(fid, '- Smoothing used before region medians: decomposition-provided `DeltaM_smooth`.\n\n');
    fprintf(fid, '## Signal flow\n\n');
    fprintf(fid, '1. Raw traces loaded (`M_noPause`, `M_pause`).\n');
    fprintf(fid, '2. DeltaM built in stage3 (`computeDeltaM` -> `analyzeAgingMemory`).\n');
    fprintf(fid, '3. Derivative method called with (`T_common`, `DeltaM`, `Tp`).\n');
    fprintf(fid, '4. Decomposition backbone computes `DeltaM_smooth` and dip channel metrics.\n');
    fprintf(fid, '5. Derivative mode computes FM as right-median minus left-median on `DeltaM_smooth`.\n');
    fprintf(fid, '6. AFM and FM outputs stored per temperature and written to results table.\n\n');
    fprintf(fid, '## Interpretation\n\n');
    fprintf(fid, '- AFM: dip quantity from local dip feature (area metric in this run).\n');
    fprintf(fid, '- FM: step height from background shift (`right median - left median`).\n\n');
    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- Results table: `%s`\n', outCsv);
    fprintf(fid, '- Figure FIG: `%s`\n', figPath);
    fprintf(fid, '- Figure PNG: `%s`\n', pngPath);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRuns, {'derivative method execution and documentation completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_derivative_method_execution_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'derivative method execution failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
