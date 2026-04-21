clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

runCfg = struct();
runCfg.runLabel = 'extrema_smoothed_deltaM_stability_check';

try
    run = createRunContext('aging', runCfg);

    cfg = struct();
    cfg.dataDir = dataDir;
    cfg.normalizeByMass = true;
    cfg.debugMode = false;
    cfg.Bohar_units = true;
    cfg.dip_window_K = 5;
    cfg.subtractOrder = 'noMinusPause';
    cfg.alignDeltaM = false;
    cfg.alignRef = 'lowT';
    cfg.alignWindow_K = 2;
    cfg.doFilterDeltaM = true;
    cfg.filterMethod = 'sgolay';
    cfg.sgolayOrder = 2;
    cfg.sgolayFrame = 15;

    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    nRuns = numel(state.pauseRuns);
    Tp = nan(nRuns,1);
    FM_base = nan(nRuns,1);
    AFM_base = nan(nRuns,1);
    FM_w_std = nan(nRuns,1);
    AFM_w_std = nan(nRuns,1);
    FM_noise_std = nan(nRuns,1);
    AFM_noise_std = nan(nRuns,1);

    windows = [9 11 13];
    nNoise = 40;
    rng(1);

    for i = 1:nRuns
        runi = state.pauseRuns(i);
        Tp(i) = runi.waitK;
        dM = runi.DeltaM(:);
        valid = isfinite(dM);
        dM = dM(valid);
        if isempty(dM)
            continue;
        end

        dM11 = movmean(dM, 11);
        FM_base(i) = max(dM11);
        AFM_base(i) = min(dM11);

        fmW = nan(numel(windows),1);
        afmW = nan(numel(windows),1);
        for k = 1:numel(windows)
            ds = movmean(dM, windows(k));
            fmW(k) = max(ds);
            afmW(k) = min(ds);
        end
        FM_w_std(i) = std(fmW, 'omitnan');
        AFM_w_std(i) = std(afmW, 'omitnan');

        resid = dM - dM11;
        sigma = std(resid, 'omitnan');
        if ~isfinite(sigma)
            sigma = 0;
        end
        fmN = nan(nNoise,1);
        afmN = nan(nNoise,1);
        for n = 1:nNoise
            dMp = dM + sigma * randn(size(dM));
            dsp = movmean(dMp, 11);
            fmN(n) = max(dsp);
            afmN(n) = min(dsp);
        end
        FM_noise_std(i) = std(fmN, 'omitnan');
        AFM_noise_std(i) = std(afmN, 'omitnan');
    end

    stabTbl = table(Tp, FM_base, AFM_base, FM_w_std, AFM_w_std, FM_noise_std, AFM_noise_std);
    outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_smoothed_deltaM_stability.csv');
    writetable(stabTbl, outCsv);

    fmRelW = median(FM_w_std ./ max(abs(FM_base), eps), 'omitnan');
    afmRelW = median(AFM_w_std ./ max(abs(AFM_base), eps), 'omitnan');
    fmRelN = median(FM_noise_std ./ max(abs(FM_base), eps), 'omitnan');
    afmRelN = median(AFM_noise_std ./ max(abs(AFM_base), eps), 'omitnan');

    extremaStable = (fmRelW < 0.25) && (afmRelW < 0.25) && (fmRelN < 0.25) && (afmRelN < 0.25);
    if extremaStable
        stableStr = 'YES';
    else
        stableStr = 'NO';
    end

    rep = fullfile(repoRoot, 'reports', 'aging', 'aging_extrema_smoothed_deltaM_stability.md');
    fid = fopen(rep, 'w');
    fprintf(fid, '# extrema_smoothed DeltaM Stability Recheck\n\n');
    fprintf(fid, '- median_rel_window_FM = %.6g\n', fmRelW);
    fprintf(fid, '- median_rel_window_AFM = %.6g\n', afmRelW);
    fprintf(fid, '- median_rel_noise_FM = %.6g\n', fmRelN);
    fprintf(fid, '- median_rel_noise_AFM = %.6g\n', afmRelN);
    fprintf(fid, '- EXTREMA_STABLE_ON_DELTA_M = %s\n', stableStr);
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRuns, {'DeltaM stability check completed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_extrema_smoothed_deltaM_stability_check_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'DeltaM stability check failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
