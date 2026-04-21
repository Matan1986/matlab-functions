clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

cfgRun = struct();
cfgRun.runLabel = 'deltaM_plot_sign_forensics';

try
    run = createRunContext('aging', cfgRun);

    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

    cfg = struct();
    cfg.dataDir = dataDir;
    cfg.normalizeByMass = true;
    cfg.debugMode = false;
    cfg.Bohar_units = true;
    cfg.dip_window_K = 5;
    cfg.doFilterDeltaM = true;
    cfg.filterMethod = 'sgolay';
    cfg.sgolayOrder = 2;
    cfg.sgolayFrame = 15;
    cfg.alignDeltaM = false;
    cfg.alignRef = 'lowT';
    cfg.alignWindow_K = 2;

    state0 = stage1_loadData(cfg);
    state0 = stage2_preprocess(state0, cfg);

    cfgB = cfg;
    cfgB.subtractOrder = 'noMinusPause';
    stateB = stage3_computeDeltaM(state0, cfgB);

    TpAll = [state0.pauseRuns.waitK];
    [~, repIdx] = min(abs(TpAll - 22));

    pr = state0.pauseRuns(repIdx);
    T_no = state0.noPause_T(:);
    M_no = state0.noPause_M(:);
    T_pa = pr.T(:);
    M_pa = pr.M(:);

    Tmin = max(min(T_no), min(T_pa));
    Tmax = min(max(T_no), max(T_pa));
    Tgrid = linspace(Tmin, Tmax, max(300, numel(T_pa)))';
    M_no_i = interp1(T_no, M_no, Tgrid, 'linear');
    M_pa_i = interp1(T_pa, M_pa, Tgrid, 'linear');

    dA = M_pa_i - M_no_i; % historical plotted convention (pauseMinusNo)
    dB = M_no_i - M_pa_i; % canonical convention (noMinusPause)
    t = Tgrid;

    n = numel(t);

    mean_diff = mean(dA - dB, 'omitnan');
    mean_sum = mean(dA + dB, 'omitnan');
    mse_neg = mean((dA + dB).^2, 'omitnan');
    mse_same = mean((dA - dB).^2, 'omitnan');
    corr_neg = corr(dA, -dB, 'rows', 'complete');
    corr_same = corr(dA, dB, 'rows', 'complete');

    Tp = pr.waitK;
    dipMask = abs(t - Tp) <= cfg.dip_window_K;
    leftMask = t < (Tp - cfg.dip_window_K);
    rightMask = t > (Tp + cfg.dip_window_K);
    plateauMask = leftMask | rightMask;

    dipMeanA = mean(dA(dipMask), 'omitnan');
    dipMeanB = mean(dB(dipMask), 'omitnan');
    plateauMeanA = mean(dA(plateauMask), 'omitnan');
    plateauMeanB = mean(dB(plateauMask), 'omitnan');

    outTbl = table(mean_diff, mean_sum, mse_neg, mse_same, corr_neg, corr_same, dipMeanA, dipMeanB, plateauMeanA, plateauMeanB, ...
        'VariableNames', {'mean_DeltaM_plotted_minus_canonical', 'mean_DeltaM_plotted_plus_canonical', 'mse_vs_negative', 'mse_vs_same', 'corr_plotted_with_negCanonical', 'corr_plotted_with_canonical', 'dip_mean_plotted_pauseMinusNo', 'dip_mean_canonical_noMinusPause', 'plateau_mean_plotted_pauseMinusNo', 'plateau_mean_canonical_noMinusPause'});
    outCsv = fullfile(repoRoot, 'tables', 'aging', 'deltaM_plot_sign_forensics.csv');
    writetable(outTbl, outCsv);

    reportPath = fullfile(repoRoot, 'reports', 'aging', 'deltaM_plot_sign_forensics.md');
    fid = fopen(reportPath, 'w');
    fprintf(fid, '# DeltaM Plot Sign Forensics\n\n');
    fprintf(fid, '- Compared `stage3_computeDeltaM` outputs for `subtractOrder = pauseMinusNo` (plotted historical convention) vs `noMinusPause` (canonical).\n');
    fprintf(fid, '- mean(plotted - canonical): %.12g\n', mean_diff);
    fprintf(fid, '- mean(plotted + canonical): %.12g\n', mean_sum);
    fprintf(fid, '- mse(plotted, -canonical): %.12g\n', mse_neg);
    fprintf(fid, '- mse(plotted, canonical): %.12g\n', mse_same);
    fprintf(fid, '- corr(plotted, -canonical): %.12g\n', corr_neg);
    fprintf(fid, '- corr(plotted, canonical): %.12g\n', corr_same);
    fprintf(fid, '- dip mean plotted (pauseMinusNo): %.12g\n', dipMeanA);
    fprintf(fid, '- dip mean canonical (noMinusPause): %.12g\n', dipMeanB);
    fprintf(fid, '- plateau mean plotted (pauseMinusNo): %.12g\n', plateauMeanA);
    fprintf(fid, '- plateau mean canonical (noMinusPause): %.12g\n', plateauMeanB);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, n, {'DeltaM plot sign forensics completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_deltaM_plot_sign_forensics_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'DeltaM plot sign forensics failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
