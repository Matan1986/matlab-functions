fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = scriptDir;
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Aging'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_extraction_method_survey';

noiseOutPath = fullfile(repoRoot, 'tables', 'aging', 'aging_noise_characterization.csv');
stabilityOutPath = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_stability.csv');
methodOutPath = fullfile(repoRoot, 'tables', 'aging', 'aging_method_comparison.csv');
reportOutPath = fullfile(repoRoot, 'reports', 'aging', 'aging_extraction_method_survey.md');

noiseTbl = table();
stabilityTbl = table();
methodTbl = table();

try
    run = createRunContext('aging', cfg);

    outTablesDir = fileparts(noiseOutPath);
    outReportsDir = fileparts(reportOutPath);
    if exist(outTablesDir, 'dir') ~= 7
        mkdir(outTablesDir);
    end
    if exist(outReportsDir, 'dir') ~= 7
        mkdir(outReportsDir);
    end

    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';
    if exist(dataDir, 'dir') ~= 7
        error('AgingSurvey:MissingDataDir', 'Dataset folder not found: %s', dataDir);
    end

    [~, pauseRuns] = getFileList_aging(dataDir);
    nPause = numel(pauseRuns);
    if nPause < 3
        error('AgingSurvey:InsufficientTraces', 'Need >=3 pause traces, found %d', nPause);
    end

    nSelect = min(5, nPause);
    idxSelect = round(linspace(1, nPause, nSelect));
    idxSelect = unique(idxSelect(:)');
    nSelect = numel(idxSelect);

    smoothWindows = [5 9 13];
    localMeanRadius = 2;
    percentileHi = 98;
    percentileLo = 2;
    nPerturb = 30;
    rng(119);

    rowNoise = 0;
    rowStab = 0;
    rowMethod = 0;

    trace_name = strings(0,1);
    trace_file = strings(0,1);
    waitK = zeros(0,1);
    N = zeros(0,1);
    smooth_window = zeros(0,1);
    noise_level = zeros(0,1);
    signal_range = zeros(0,1);
    noise_ratio = zeros(0,1);
    diff_std = zeros(0,1);
    diff_mad = zeros(0,1);

    stab_trace_name = strings(0,1);
    stab_trace_file = strings(0,1);
    stab_waitK = zeros(0,1);
    stab_smooth_window = zeros(0,1);
    idx_max_raw = zeros(0,1);
    idx_max_smooth = zeros(0,1);
    idx_max_shift = zeros(0,1);
    idx_min_raw = zeros(0,1);
    idx_min_smooth = zeros(0,1);
    idx_min_shift = zeros(0,1);
    max_is_stable = zeros(0,1);
    min_is_stable = zeros(0,1);
    max_width_points = zeros(0,1);
    min_width_points = zeros(0,1);
    max_shape = strings(0,1);
    min_shape = strings(0,1);

    met_trace_name = strings(0,1);
    met_waitK = zeros(0,1);
    method = strings(0,1);
    param_smooth_window = zeros(0,1);
    perturb_scale = zeros(0,1);
    perturb_id = zeros(0,1);
    FM_value = zeros(0,1);
    AFM_value = zeros(0,1);
    FM_delta_from_base = zeros(0,1);
    AFM_delta_from_base = zeros(0,1);

    summary_method = strings(0,1);
    summary_window = zeros(0,1);
    summary_trace_count = zeros(0,1);
    summary_FM_std_across_traces = zeros(0,1);
    summary_AFM_std_across_traces = zeros(0,1);
    summary_FM_noise_sensitivity = zeros(0,1);
    summary_AFM_noise_sensitivity = zeros(0,1);
    summary_combined_score = zeros(0,1);

    for iSel = 1:nSelect
        pr = pauseRuns(idxSelect(iSel));
        [T, M] = importFiles_aging(pr.file, true, false);
        if isempty(T) || isempty(M)
            continue;
        end

        [~, baseName, ext] = fileparts(pr.file);
        traceLabel = string(strcat(baseName, ext));
        traceN = numel(M);
        thisRange = max(M) - min(M);
        if thisRange <= 0
            thisRange = eps;
        end

        for w = smoothWindows
            Msm = movmean(M, w);
            dM = diff(M);
            nLevel = std(M - Msm, 0);
            dStd = std(dM, 0);
            dMad = mad(dM, 1);

            rowNoise = rowNoise + 1;
            trace_name(rowNoise,1) = traceLabel;
            trace_file(rowNoise,1) = string(pr.file);
            waitK(rowNoise,1) = pr.waitK;
            N(rowNoise,1) = traceN;
            smooth_window(rowNoise,1) = w;
            noise_level(rowNoise,1) = nLevel;
            signal_range(rowNoise,1) = thisRange;
            noise_ratio(rowNoise,1) = nLevel / thisRange;
            diff_std(rowNoise,1) = dStd;
            diff_mad(rowNoise,1) = dMad;

            [~, iMaxRaw] = max(M);
            [~, iMaxSm] = max(Msm);
            [~, iMinRaw] = min(M);
            [~, iMinSm] = min(Msm);

            maxThresh = max(Msm) - 0.05 * thisRange;
            minThresh = min(Msm) + 0.05 * thisRange;
            maxMask = Msm >= maxThresh;
            minMask = Msm <= minThresh;

            maxEdges = diff([0; maxMask(:); 0]);
            maxStarts = find(maxEdges == 1);
            maxEnds = find(maxEdges == -1) - 1;
            if isempty(maxStarts)
                maxW = 1;
            else
                maxW = max(maxEnds - maxStarts + 1);
            end

            minEdges = diff([0; minMask(:); 0]);
            minStarts = find(minEdges == 1);
            minEnds = find(minEdges == -1) - 1;
            if isempty(minStarts)
                minW = 1;
            else
                minW = max(minEnds - minStarts + 1);
            end

            if maxW <= 2
                maxClass = "sharp";
            else
                maxClass = "broad";
            end
            if minW <= 2
                minClass = "sharp";
            else
                minClass = "broad";
            end

            rowStab = rowStab + 1;
            stab_trace_name(rowStab,1) = traceLabel;
            stab_trace_file(rowStab,1) = string(pr.file);
            stab_waitK(rowStab,1) = pr.waitK;
            stab_smooth_window(rowStab,1) = w;
            idx_max_raw(rowStab,1) = iMaxRaw;
            idx_max_smooth(rowStab,1) = iMaxSm;
            idx_max_shift(rowStab,1) = abs(iMaxRaw - iMaxSm);
            idx_min_raw(rowStab,1) = iMinRaw;
            idx_min_smooth(rowStab,1) = iMinSm;
            idx_min_shift(rowStab,1) = abs(iMinRaw - iMinSm);
            max_is_stable(rowStab,1) = abs(iMaxRaw - iMaxSm) <= 2;
            min_is_stable(rowStab,1) = abs(iMinRaw - iMinSm) <= 2;
            max_width_points(rowStab,1) = maxW;
            min_width_points(rowStab,1) = minW;
            max_shape(rowStab,1) = maxClass;
            min_shape(rowStab,1) = minClass;
        end

        wBase = 9;
        MsmBase = movmean(M, wBase);
        [~, iMaxSmBase] = max(MsmBase);
        [~, iMinSmBase] = min(MsmBase);

        iLmax = max(1, iMaxSmBase - localMeanRadius);
        iRmax = min(traceN, iMaxSmBase + localMeanRadius);
        iLmin = max(1, iMinSmBase - localMeanRadius);
        iRmin = min(traceN, iMinSmBase + localMeanRadius);

        baseFM_A = max(M);
        baseAFM_A = min(M);
        baseFM_B = max(MsmBase);
        baseAFM_B = min(MsmBase);
        baseFM_C = mean(M(iLmax:iRmax));
        baseAFM_C = mean(M(iLmin:iRmin));
        baseFM_D = prctile(M, percentileHi);
        baseAFM_D = prctile(M, percentileLo);

        for w = smoothWindows
            MsmW = movmean(M, w);
            [~, iMaxSmW] = max(MsmW);
            [~, iMinSmW] = min(MsmW);
            iLmaxW = max(1, iMaxSmW - localMeanRadius);
            iRmaxW = min(traceN, iMaxSmW + localMeanRadius);
            iLminW = max(1, iMinSmW - localMeanRadius);
            iRminW = min(traceN, iMinSmW + localMeanRadius);

            fmVals = [max(M), max(MsmW), mean(M(iLmaxW:iRmaxW)), prctile(M, percentileHi)];
            afmVals = [min(M), min(MsmW), mean(M(iLminW:iRminW)), prctile(M, percentileLo)];
            methods = ["A_raw_extrema","B_smoothed_extrema","C_extremum_local_mean","D_percentile_reference"];
            baseFmVals = [baseFM_A, baseFM_B, baseFM_C, baseFM_D];
            baseAfmVals = [baseAFM_A, baseAFM_B, baseAFM_C, baseAFM_D];

            for mIdx = 1:numel(methods)
                rowMethod = rowMethod + 1;
                met_trace_name(rowMethod,1) = traceLabel;
                met_waitK(rowMethod,1) = pr.waitK;
                method(rowMethod,1) = methods(mIdx);
                param_smooth_window(rowMethod,1) = w;
                perturb_scale(rowMethod,1) = 0;
                perturb_id(rowMethod,1) = 0;
                FM_value(rowMethod,1) = fmVals(mIdx);
                AFM_value(rowMethod,1) = afmVals(mIdx);
                FM_delta_from_base(rowMethod,1) = fmVals(mIdx) - baseFmVals(mIdx);
                AFM_delta_from_base(rowMethod,1) = afmVals(mIdx) - baseAfmVals(mIdx);
            end
        end

        MsmNoise = movmean(M, 9);
        noiseSigma = std(M - MsmNoise, 0);
        if ~isfinite(noiseSigma) || noiseSigma == 0
            noiseSigma = std(M, 0) * 0.01;
        end
        perturbSigma = 0.20 * noiseSigma;

        for k = 1:nPerturb
            Mp = M + perturbSigma * randn(size(M));
            MsmP = movmean(Mp, 9);
            [~, iMaxSmP] = max(MsmP);
            [~, iMinSmP] = min(MsmP);
            iLmaxP = max(1, iMaxSmP - localMeanRadius);
            iRmaxP = min(traceN, iMaxSmP + localMeanRadius);
            iLminP = max(1, iMinSmP - localMeanRadius);
            iRminP = min(traceN, iMinSmP + localMeanRadius);

            fmValsP = [max(Mp), max(MsmP), mean(Mp(iLmaxP:iRmaxP)), prctile(Mp, percentileHi)];
            afmValsP = [min(Mp), min(MsmP), mean(Mp(iLminP:iRminP)), prctile(Mp, percentileLo)];
            methodsP = ["A_raw_extrema","B_smoothed_extrema","C_extremum_local_mean","D_percentile_reference"];
            baseFmValsP = [baseFM_A, baseFM_B, baseFM_C, baseFM_D];
            baseAfmValsP = [baseAFM_A, baseAFM_B, baseAFM_C, baseAFM_D];

            for mIdx = 1:numel(methodsP)
                rowMethod = rowMethod + 1;
                met_trace_name(rowMethod,1) = traceLabel;
                met_waitK(rowMethod,1) = pr.waitK;
                method(rowMethod,1) = methodsP(mIdx);
                param_smooth_window(rowMethod,1) = 9;
                perturb_scale(rowMethod,1) = perturbSigma;
                perturb_id(rowMethod,1) = k;
                FM_value(rowMethod,1) = fmValsP(mIdx);
                AFM_value(rowMethod,1) = afmValsP(mIdx);
                FM_delta_from_base(rowMethod,1) = fmValsP(mIdx) - baseFmValsP(mIdx);
                AFM_delta_from_base(rowMethod,1) = afmValsP(mIdx) - baseAfmValsP(mIdx);
            end
        end
    end

    noiseTbl = table(trace_name, trace_file, waitK, N, smooth_window, noise_level, signal_range, noise_ratio, diff_std, diff_mad);
    stabilityTbl = table(stab_trace_name, stab_trace_file, stab_waitK, stab_smooth_window, ...
        idx_max_raw, idx_max_smooth, idx_max_shift, idx_min_raw, idx_min_smooth, idx_min_shift, ...
        max_is_stable, min_is_stable, max_width_points, min_width_points, max_shape, min_shape);
    methodTbl = table(met_trace_name, met_waitK, method, param_smooth_window, perturb_scale, perturb_id, ...
        FM_value, AFM_value, FM_delta_from_base, AFM_delta_from_base);

    methodList = unique(methodTbl.method, 'stable');
    windowList = unique(methodTbl.param_smooth_window(methodTbl.perturb_id == 0), 'stable');
    for mi = 1:numel(methodList)
        for wi = 1:numel(windowList)
            mKey = methodList(mi);
            wKey = windowList(wi);
            baseMask = methodTbl.method == mKey & methodTbl.param_smooth_window == wKey & methodTbl.perturb_id == 0;
            if ~any(baseMask)
                continue;
            end
            pertMask = methodTbl.method == mKey & methodTbl.perturb_id > 0;
            rowSummary = sum(baseMask);

            rowMethod = rowMethod + 1;
            summary_method(rowMethod,1) = mKey;
            summary_window(rowMethod,1) = wKey;
            summary_trace_count(rowMethod,1) = rowSummary;
            summary_FM_std_across_traces(rowMethod,1) = std(methodTbl.FM_value(baseMask), 0);
            summary_AFM_std_across_traces(rowMethod,1) = std(methodTbl.AFM_value(baseMask), 0);
            if any(pertMask)
                summary_FM_noise_sensitivity(rowMethod,1) = std(methodTbl.FM_delta_from_base(pertMask), 0);
                summary_AFM_noise_sensitivity(rowMethod,1) = std(methodTbl.AFM_delta_from_base(pertMask), 0);
            else
                summary_FM_noise_sensitivity(rowMethod,1) = NaN;
                summary_AFM_noise_sensitivity(rowMethod,1) = NaN;
            end
            summary_combined_score(rowMethod,1) = ...
                summary_FM_noise_sensitivity(rowMethod,1) + summary_AFM_noise_sensitivity(rowMethod,1) + ...
                summary_FM_std_across_traces(rowMethod,1) + summary_AFM_std_across_traces(rowMethod,1);
        end
    end

    summaryTbl = table(summary_method, summary_window, summary_trace_count, ...
        summary_FM_std_across_traces, summary_AFM_std_across_traces, ...
        summary_FM_noise_sensitivity, summary_AFM_noise_sensitivity, summary_combined_score);

    [~, bestIdx] = min(summaryTbl.summary_combined_score);
    recommendedMethod = string(summaryTbl.summary_method(bestIdx));
    recommendedWindow = summaryTbl.summary_window(bestIdx);

    noiseRatioVals = noiseTbl.noise_ratio;
    medNoiseRatio = median(noiseRatioVals, 'omitnan');
    p90NoiseRatio = prctile(noiseRatioVals, 90);
    maxNoiseRatio = max(noiseRatioVals);

    maxSharpFrac = mean(stabilityTbl.max_shape == "sharp");
    minSharpFrac = mean(stabilityTbl.min_shape == "sharp");
    maxStableFrac = mean(stabilityTbl.max_is_stable == 1);
    minStableFrac = mean(stabilityTbl.min_is_stable == 1);

    writetable(noiseTbl, noiseOutPath);
    writetable(stabilityTbl, stabilityOutPath);
    writetable(methodTbl, methodOutPath);

    fidReport = fopen(reportOutPath, 'w');
    if fidReport < 0
        error('AgingSurvey:ReportWriteFail', 'Failed to write report: %s', reportOutPath);
    end
    fprintf(fidReport, '# Aging extraction method survey\n\n');
    fprintf(fidReport, '## 1. Noise characterization summary\n\n');
    fprintf(fidReport, '- Traces analyzed: %d\n', numel(unique(noiseTbl.trace_name)));
    fprintf(fidReport, '- Smoothing windows tested: [%s]\n', strjoin(string(smoothWindows), ', '));
    fprintf(fidReport, '- Typical noise_ratio (median): %.6g\n', medNoiseRatio);
    fprintf(fidReport, '- High-end noise_ratio (90th pct): %.6g\n', p90NoiseRatio);
    fprintf(fidReport, '- Max observed noise_ratio: %.6g\n', maxNoiseRatio);
    fprintf(fidReport, '- Structure note: raw traces are monotonic-with-features and assessed by direct residual noise against light smoothing.\n\n');

    fprintf(fidReport, '## 2. Extrema behavior\n\n');
    fprintf(fidReport, '- Max classified as sharp fraction: %.3f\n', maxSharpFrac);
    fprintf(fidReport, '- Min classified as sharp fraction: %.3f\n', minSharpFrac);
    fprintf(fidReport, '- Max index stable under smoothing fraction: %.3f\n', maxStableFrac);
    fprintf(fidReport, '- Min index stable under smoothing fraction: %.3f\n', minStableFrac);
    fprintf(fidReport, '- Extrema width estimated from contiguous points within 5%% of smoothed extremum amplitude.\n\n');

    fprintf(fidReport, '## 3. Method comparison\n\n');
    fprintf(fidReport, '- Method A (raw extrema): simplest, highest spike sensitivity.\n');
    fprintf(fidReport, '- Method B (smoothed extrema): simple and robust to single-point spikes, mild window dependence.\n');
    fprintf(fidReport, '- Method C (extremum + local mean): robust and physically extremum-centered, slightly more parameters.\n');
    fprintf(fidReport, '- Method D (percentile): robust to spikes, but less direct extremum interpretation.\n');
    fprintf(fidReport, '- Quantitative method stability is in `tables/aging/aging_method_comparison.csv` with baseline and perturbation deltas.\n\n');

    fprintf(fidReport, '## 4. FINAL RECOMMENDATION (CLEAR)\n\n');
    fprintf(fidReport, '- Recommended method: %s\n', recommendedMethod);
    fprintf(fidReport, '- Recommended smoothing window: %d points\n', recommendedWindow);
    fprintf(fidReport, '- Why optimal here: lowest combined variability across traces plus lowest perturbation sensitivity in this dataset survey.\n\n');
    fprintf(fidReport, '### Exact algorithm\n\n');
    if recommendedMethod == "A_raw_extrema"
        fprintf(fidReport, '1. Load raw aging trace M(T).\n');
        fprintf(fidReport, '2. Compute FM-like amplitude as max(M).\n');
        fprintf(fidReport, '3. Compute AFM-like amplitude as min(M).\n');
    elseif recommendedMethod == "B_smoothed_extrema"
        fprintf(fidReport, '1. Load raw aging trace M(T).\n');
        fprintf(fidReport, '2. Apply movmean smoothing with window = %d points.\n', recommendedWindow);
        fprintf(fidReport, '3. Compute FM-like amplitude as max(smoothed M).\n');
        fprintf(fidReport, '4. Compute AFM-like amplitude as min(smoothed M).\n');
    elseif recommendedMethod == "C_extremum_local_mean"
        fprintf(fidReport, '1. Load raw aging trace M(T).\n');
        fprintf(fidReport, '2. Apply movmean smoothing with window = %d points.\n', recommendedWindow);
        fprintf(fidReport, '3. Find indices of max/min on smoothed trace.\n');
        fprintf(fidReport, '4. Compute FM-like/AFM-like as raw mean in +/- %d points around those indices.\n', localMeanRadius);
    else
        fprintf(fidReport, '1. Load raw aging trace M(T).\n');
        fprintf(fidReport, '2. Compute FM-like amplitude as 98th percentile of M.\n');
        fprintf(fidReport, '3. Compute AFM-like amplitude as 2nd percentile of M.\n');
    end
    fclose(fidReport);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(unique(noiseTbl.trace_name)), ...
        {sprintf('Recommended %s (window=%d)', recommendedMethod, recommendedWindow)}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    if exist(fileparts(noiseOutPath), 'dir') ~= 7
        mkdir(fileparts(noiseOutPath));
    end
    if exist(fileparts(reportOutPath), 'dir') ~= 7
        mkdir(fileparts(reportOutPath));
    end

    if isempty(noiseTbl)
        noiseTbl = table('Size', [0 10], ...
            'VariableTypes', {'string','string','double','double','double','double','double','double','double','double'}, ...
            'VariableNames', {'trace_name','trace_file','waitK','N','smooth_window','noise_level','signal_range','noise_ratio','diff_std','diff_mad'});
    end
    if isempty(stabilityTbl)
        stabilityTbl = table('Size', [0 16], ...
            'VariableTypes', {'string','string','double','double','double','double','double','double','double','double','double','double','double','double','string','string'}, ...
            'VariableNames', {'stab_trace_name','stab_trace_file','stab_waitK','stab_smooth_window','idx_max_raw','idx_max_smooth','idx_max_shift','idx_min_raw','idx_min_smooth','idx_min_shift','max_is_stable','min_is_stable','max_width_points','min_width_points','max_shape','min_shape'});
    end
    if isempty(methodTbl)
        methodTbl = table('Size', [0 10], ...
            'VariableTypes', {'string','double','string','double','double','double','double','double','double','double'}, ...
            'VariableNames', {'met_trace_name','met_waitK','method','param_smooth_window','perturb_scale','perturb_id','FM_value','AFM_value','FM_delta_from_base','AFM_delta_from_base'});
    end

    writetable(noiseTbl, noiseOutPath);
    writetable(stabilityTbl, stabilityOutPath);
    writetable(methodTbl, methodOutPath);

    fidReport = fopen(reportOutPath, 'w');
    if fidReport >= 0
        fprintf(fidReport, '# Aging extraction method survey\n\n');
        fprintf(fidReport, 'Execution failed.\n\n');
        fprintf(fidReport, '- Error: %s\n', ME.message);
        fclose(fidReport);
    end

    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_extraction_method_survey_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'aging extraction method survey failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
