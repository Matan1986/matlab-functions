clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

cfgRun = struct();
cfgRun.runLabel = 'deltaM_sign_convention_audit';

try
    run = createRunContext('aging', cfgRun);

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

    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    n = numel(state.pauseRuns);
    T = nan(n,1);
    mean_dip = nan(n,1);
    mean_plateau = nan(n,1);
    median_left = nan(n,1);
    median_right = nan(n,1);
    fm_step = nan(n,1);
    dip_n = nan(n,1);
    plateau_n = nan(n,1);

    for i = 1:n
        pr = state.pauseRuns(i);
        if ~isfield(pr, 'T_common') || ~isfield(pr, 'DeltaM') || ~isfield(pr, 'waitK')
            continue;
        end
        tv = pr.T_common(:);
        dv = pr.DeltaM(:);
        nn = min(numel(tv), numel(dv));
        tv = tv(1:nn);
        dv = dv(1:nn);
        v = isfinite(tv) & isfinite(dv);
        tv = tv(v);
        dv = dv(v);
        if isempty(tv) || ~isfinite(pr.waitK)
            continue;
        end

        tp = pr.waitK;
        T(i) = tp;

        dipMask = abs(tv - tp) <= cfg.dip_window_K;
        leftMask = tv < (tp - cfg.dip_window_K);
        rightMask = tv > (tp + cfg.dip_window_K);
        plateauMask = leftMask | rightMask;

        if any(dipMask)
            mean_dip(i) = mean(dv(dipMask), 'omitnan');
            dip_n(i) = nnz(dipMask);
        end
        if any(plateauMask)
            mean_plateau(i) = mean(dv(plateauMask), 'omitnan');
            plateau_n(i) = nnz(plateauMask);
        end
        if nnz(leftMask) >= 3
            median_left(i) = median(dv(leftMask), 'omitnan');
        end
        if nnz(rightMask) >= 3
            median_right(i) = median(dv(rightMask), 'omitnan');
        end
        if isfinite(median_left(i)) && isfinite(median_right(i))
            fm_step(i) = median_right(i) - median_left(i);
        end
    end

    signTbl = table(T, mean_dip, mean_plateau, median_left, median_right, fm_step, dip_n, plateau_n, ...
        'VariableNames', {'Tp', 'mean_DeltaM_dip', 'mean_DeltaM_plateau', 'median_left', 'median_right', 'FM_step_right_minus_left', 'n_dip', 'n_plateau'});
    outSignCsv = fullfile(repoRoot, 'tables', 'aging', 'deltaM_sign_behavior.csv');
    writetable(signTbl, outSignCsv);

    definitionsTbl = table( ...
        ["Aging/analyzeAgingMemory.m"; ...
         "Aging/computeDeltaM.m"; ...
         "Aging/pipeline/stage3_computeDeltaM.m"; ...
         "Aging/models/analyzeAFM_FM_components.m"; ...
         "Aging/models/analyzeAFM_FM_derivative.m"], ...
        ["dM = M_no_i - M_pa_i;"; ...
         "pauseRuns = analyzeAgingMemory(... subtractOrder);"; ...
         "[state.pauseRuns, state.pauseRuns_raw] = computeDeltaM(... cfg.subtractOrder, ...);"; ...
         "dM_sharp = dM - dM_smooth;"; ...
         "result.FM_step_raw = baseR - baseL;"], ...
        ["B"; "B"; "B"; "B-propagation"; "B-propagation"], ...
        ["raw DeltaM definition"; "raw DeltaM construction call"; "pipeline DeltaM propagation"; "smoothing/intermediate propagation"; "derivative FM extraction"], ...
        'VariableNames', {'path', 'exact_code_line', 'convention', 'role'});
    outDefCsv = fullfile(repoRoot, 'tables', 'aging', 'deltaM_definition_audit.csv');
    writetable(definitionsTbl, outDefCsv);

    dipMeanAll = mean(mean_dip, 'omitnan');
    plateauMeanAll = mean(mean_plateau, 'omitnan');
    fmMeanAll = mean(fm_step, 'omitnan');

    reportPath = fullfile(repoRoot, 'reports', 'aging', 'deltaM_sign_audit_report.md');
    fid = fopen(reportPath, 'w');
    fprintf(fid, '# DeltaM Sign Audit Report\n\n');
    fprintf(fid, '- Canonical definition enforced: `DeltaM = M_noPause - M_pause`\n');
    fprintf(fid, '- Mean dip-region DeltaM (across Tp): %.12g\n', dipMeanAll);
    fprintf(fid, '- Mean plateau-region DeltaM (across Tp): %.12g\n', plateauMeanAll);
    fprintf(fid, '- Mean FM step (right-left): %.12g\n', fmMeanAll);
    fprintf(fid, '- Definition audit table: `tables/aging/deltaM_definition_audit.csv`\n');
    fprintf(fid, '- Sign behavior table: `tables/aging/deltaM_sign_behavior.csv`\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, n, {'DeltaM sign convention audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_deltaM_sign_convention_audit_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'DeltaM sign convention audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
