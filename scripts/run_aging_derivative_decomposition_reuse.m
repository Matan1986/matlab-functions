clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

cfgRun = struct();
cfgRun.runLabel = 'aging_derivative_decomposition_reuse';

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
    cfg.outputFolder = run.run_dir;
    cfg.sample_name = 'MG119';

    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    TpAll = [state.pauseRuns.waitK];
    [~, repIdx] = min(abs(TpAll - 22));
    runi = state.pauseRuns(repIdx);

    result = analyzeAFM_FM_derivative(runi.T_common, runi.DeltaM, runi.waitK, cfg);

    T = runi.T_common(:);
    DeltaM = runi.DeltaM(:);
    Tp = runi.waitK;
    step_component = nan(size(DeltaM));

    baseL = NaN;
    baseR = NaN;
    if isfield(result, 'diagnostics') && isstruct(result.diagnostics)
        if isfield(result.diagnostics, 'baseL') && isfinite(result.diagnostics.baseL)
            baseL = result.diagnostics.baseL;
        end
        if isfield(result.diagnostics, 'baseR') && isfinite(result.diagnostics.baseR)
            baseR = result.diagnostics.baseR;
        end
    end

    if isfinite(baseL)
        step_component(T <= Tp - cfg.dip_window_K) = baseL;
    end
    if isfinite(baseR)
        step_component(T >= Tp + cfg.dip_window_K) = baseR;
    end

    transMask = (T > Tp - cfg.dip_window_K) & (T < Tp + cfg.dip_window_K);
    if any(transMask) && isfinite(baseL) && isfinite(baseR)
        tTrans = T(transMask);
        t0 = min(tTrans);
        t1 = max(tTrans);
        if t1 > t0
            step_component(transMask) = baseL + (baseR - baseL) .* ((tTrans - t0) ./ (t1 - t0));
        else
            step_component(transMask) = baseL;
        end
    end

    if isfield(result, 'DeltaM_smooth') && ~isempty(result.DeltaM_smooth)
        dM_smooth = result.DeltaM_smooth(:);
        fillMask = ~isfinite(step_component) & isfinite(dM_smooth);
        step_component(fillMask) = dM_smooth(fillMask);
    end

    dip_component = DeltaM - step_component;

    pauseRunPlot = struct();
    pauseRunPlot.T_common = T;
    pauseRunPlot.DeltaM = DeltaM;
    pauseRunPlot.DeltaM_smooth = step_component;
    pauseRunPlot.DeltaM_sharp = dip_component;
    pauseRunPlot.waitK = Tp;
    pauseRunPlot.excludeLowT_FM = cfg.excludeLowT_FM;
    pauseRunPlot.excludeLowT_K = cfg.excludeLowT_K;

    % Raw DeltaM plot using existing decomposition plotting logic
    % (first panel in plotAFM_FM_decomposition is the canonical raw DeltaM).
    plotAFM_FM_decomposition(pauseRunPlot, 16);
    hRaw = gcf;
    set(hRaw, 'Visible', 'off');
    axRaw = findall(hRaw, 'Type', 'axes');
    if numel(axRaw) >= 3
        delete(axRaw(1:2)); % keep only the top raw-DeltaM panel
    end
    axKeep = findall(hRaw, 'Type', 'axes');
    if ~isempty(axKeep)
        set(axKeep(1), 'Position', [0.13 0.15 0.78 0.75]);
        title(axKeep(1), '\DeltaM = M_{noPause} - M_{pause} (canonical)', 'FontWeight', 'bold');
    end
    rawFigPath = fullfile(run.run_dir, 'aging_deltaM_raw.fig');
    rawPngPath = fullfile(run.run_dir, 'aging_deltaM_raw.png');
    savefig(hRaw, rawFigPath);
    exportgraphics(hRaw, rawPngPath, 'Resolution', 300);
    close(hRaw);

    % Full AFM/FM decomposition plot using required plotting function.
    plotAFM_FM_decomposition(pauseRunPlot, 16);
    hDec = gcf;
    set(hDec, 'Visible', 'off');
    decFigPath = fullfile(run.run_dir, 'aging_decomposition.fig');
    decPngPath = fullfile(run.run_dir, 'aging_decomposition.png');
    savefig(hDec, decFigPath);
    exportgraphics(hDec, decPngPath, 'Resolution', 300);
    close(hDec);

    % Sign-consistency verification diagnostics
    dipMask = abs(T - Tp) <= cfg.dip_window_K;
    plateauMask = abs(T - Tp) > cfg.dip_window_K;
    dipMean = mean(DeltaM(dipMask), 'omitnan');
    plateauMean = mean(DeltaM(plateauMask), 'omitnan');
    FM = baseR - baseL;
    fprintf('\n=== Canonical Sign Consistency Check ===\n');
    fprintf('DeltaM definition: DeltaM = M_noPause - M_pause\n');
    fprintf('mean DeltaM in dip region: %.9g\n', dipMean);
    fprintf('mean DeltaM in plateau region: %.9g\n', plateauMean);
    fprintf('baseL: %.9g\n', baseL);
    fprintf('baseR: %.9g\n', baseR);
    fprintf('FM = baseR - baseL: %.9g\n', FM);
    fprintf('FM definition: FM = baseR - baseL\n');

    outTbl = table(T, DeltaM, step_component, dip_component, ...
        'VariableNames', {'T', 'DeltaM', 'DeltaM_smooth', 'DeltaM_sharp'});
    outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_derivative_method_results.csv');
    writetable(outTbl, outCsv);

    reportPath = fullfile(repoRoot, 'reports', 'aging', 'aging_derivative_method_explanation.md');
    fid = fopen(reportPath, 'w');
    fprintf(fid, '# Aging Derivative Decomposition Reuse\n\n');
    fprintf(fid, '- Reused plotting function: `Aging/plots/plotAFM_FM_decomposition.m`\n');
    fprintf(fid, '- Input signature used: `plotAFM_FM_decomposition(pauseRun, fontsize)`\n');
    fprintf(fid, '- `pauseRun.DeltaM = DeltaM`\n');
    fprintf(fid, '- `pauseRun.DeltaM_smooth = step_component` (from derivative baseline medians)\n');
    fprintf(fid, '- `pauseRun.DeltaM_sharp = dip_component = DeltaM - step_component`\n');
    fprintf(fid, '- RAW FIG: `%s`\n', rawFigPath);
    fprintf(fid, '- RAW PNG: `%s`\n', rawPngPath);
    fprintf(fid, '- DECOMP FIG: `%s`\n', decFigPath);
    fprintf(fid, '- DECOMP PNG: `%s`\n', decPngPath);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(T), {'reuse decomposition plotting function completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_derivative_decomposition_reuse_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'reuse decomposition plotting function failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
