fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XX35mA:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_35mA_model_free_relaxation';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_35mA_model_free_relaxation.csv');
summaryOutPath = fullfile(repoRoot, 'tables', 'xx_35mA_temperature_relaxation_summary.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_35mA_relaxation_onset.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    cfg = xx_relaxation_config2_sources();
    cfg35 = cfg(contains(string({cfg.config_id}), "35mA"));
    if isempty(cfg35)
        error('XX35mA:ConfigMissing', 'Could not find config2_35mA source in xx_relaxation_config2_sources().');
    end

    sourceDir = fullfile(char(cfg35.baseDir), char(cfg35.tempDepFolder));
    if exist(sourceDir, 'dir') ~= 7
        error('XX35mA:SourceMissing', '35 mA source directory not found: %s', sourceDir);
    end

    files = dir(fullfile(sourceDir, '*.dat'));
    if isempty(files)
        error('XX35mA:NoFiles', 'No .dat files found under %s', sourceDir);
    end

    oldTauPath = fullfile(repoRoot, 'tables', 'xx_relaxation_event_level_full_config2.csv');
    if exist(oldTauPath, 'file') ~= 2
        error('XX35mA:TauTableMissing', 'Missing prior tau table: %s', oldTauPath);
    end
    tauTbl = readtable(oldTauPath);
    tauTbl.config_id = string(tauTbl.config_id);
    tau35 = tauTbl(contains(tauTbl.config_id, "35mA"), :);

    file_id = strings(0, 1);
    temperature = zeros(0, 1);
    pulse_index = zeros(0, 1);
    target_state = strings(0, 1);
    switch_idx = zeros(0, 1);
    relax_start_idx = zeros(0, 1);
    window_end_idx = zeros(0, 1);
    dt_s = NaN(0, 1);
    total_pulse_height = NaN(0, 1);
    early_window_mean = NaN(0, 1);
    late_window_mean = NaN(0, 1);
    relaxation_amplitude = NaN(0, 1);
    normalized_relaxation_amplitude = NaN(0, 1);
    noise_sigma_late = NaN(0, 1);
    nonzero_relaxation = false(0, 1);

    relTimeStore = cell(0, 1);
    relShapeStore = cell(0, 1);

    knownSpacingSec = 15;

    for f = 1:numel(files)
        fname = string(files(f).name);
        tokT = regexp(fname, '_T([0-9]+(?:\.[0-9]+)?)_', 'tokens', 'once');
        if isempty(tokT)
            continue;
        end
        tK = str2double(tokT{1});

        rawPath = fullfile(sourceDir, char(fname));
        data = readtable(rawPath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
        if ~ismember('Time (ms)', data.Properties.VariableNames) || ~ismember('LI3_X (V)', data.Properties.VariableNames)
            continue;
        end

        tMs = data{:, 'Time (ms)'};
        vRaw = data{:, 'LI3_X (V)'};
        if numel(tMs) < 50 || numel(vRaw) ~= numel(tMs)
            continue;
        end

        tSec = (tMs - tMs(1)) ./ 1000;
        dt = median(diff(tSec), 'omitnan');
        if ~isfinite(dt) || dt <= 0
            continue;
        end

        filtN = max(5, round(0.05 / dt));
        v = movmean(vRaw, filtN, 'omitnan');
        absDvDt = abs(gradient(v, dt));

        q90 = quantile(absDvDt, 0.90);
        q99 = quantile(absDvDt, 0.99);
        thr = max(q99, q90 + 3 * mad(absDvDt, 1));
        minDist = max(round((0.6 * knownSpacingSec) / dt), 5);
        [~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr, 'MinPeakDistance', minDist);
        if numel(pulseIdx) < 4
            thr2 = quantile(absDvDt, 0.995);
            [~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr2, 'MinPeakDistance', max(round((0.4 * knownSpacingSec) / dt), 3));
        end
        if isempty(pulseIdx)
            continue;
        end

        meanPeriod = knownSpacingSec;
        if numel(pulseIdx) > 1
            meanPeriod = median(diff(tSec(pulseIdx)), 'omitnan');
        end
        W = max(round(0.12 * meanPeriod / dt), 8);
        stableN = max(round(W / 3), 5);
        slopeFloor = median(absDvDt, 'omitnan') + 1.5 * mad(absDvDt, 1);
        rollStd = movstd(v, W, 0, 'omitnan');
        stdFloor = median(rollStd, 'omitnan') + 2.0 * mad(rollStd, 1);
        if ~isfinite(stdFloor) || stdFloor <= 0
            stdFloor = std(v, 'omitnan') * 0.1;
        end

        for p = 1:numel(pulseIdx)
            thisPeak = pulseIdx(p);
            nextPulse = numel(v);
            if p < numel(pulseIdx)
                nextPulse = pulseIdx(p + 1) - 1;
            end

            pulseEnd = thisPeak;
            while pulseEnd < nextPulse
                if absDvDt(pulseEnd) < 1.2 * slopeFloor
                    break;
                end
                pulseEnd = pulseEnd + 1;
            end
            pulseEnd = min(pulseEnd, nextPulse);

            relaxStart = pulseEnd;
            need = 4;
            while relaxStart + need < nextPulse
                if all(absDvDt(relaxStart:(relaxStart + need - 1)) < 1.1 * slopeFloor)
                    break;
                end
                relaxStart = relaxStart + 1;
            end
            relaxStart = min(relaxStart, nextPulse);

            if relaxStart + W + stableN > nextPulse
                continue;
            end

            stable = false(nextPulse, 1);
            for k = relaxStart:(nextPulse - W + 1)
                seg = v(k:(k + W - 1));
                slopeVal = mean(absDvDt(k:(k + W - 1)), 'omitnan');
                stable(k) = (slopeVal < slopeFloor) && (std(seg, 'omitnan') < stdFloor);
            end

            runLen = 0;
            plateauStart = NaN;
            for k = relaxStart:(nextPulse - W + 1)
                if stable(k)
                    runLen = runLen + 1;
                    if runLen >= stableN
                        plateauStart = k - stableN + 1;
                        break;
                    end
                else
                    runLen = 0;
                end
            end
            if ~isfinite(plateauStart)
                continue;
            end

            vPlateau = mean(v(plateauStart:nextPulse), 'omitnan');
            preN = max(5, round(0.2 / dt));
            preStart = max(1, thisPeak - preN);
            preEnd = max(preStart, thisPeak - 1);
            preLevel = mean(v(preStart:preEnd), 'omitnan');

            totalH = abs(vPlateau - preLevel);
            if ~isfinite(totalH) || totalH <= 0
                continue;
            end

            segIdx = relaxStart:nextPulse;
            nSeg = numel(segIdx);
            if nSeg < 8
                continue;
            end

            sgn = sign(vPlateau - preLevel);
            if sgn == 0
                continue;
            end
            signedLevel = sgn * (v(segIdx) - preLevel);

            wN = max(3, min(round(0.2 * nSeg), floor(nSeg / 3)));
            earlyMean = mean(signedLevel(1:wN), 'omitnan');
            lateMean = mean(signedLevel((nSeg - wN + 1):nSeg), 'omitnan');
            amp = earlyMean - lateMean;
            normAmp = amp / totalH;

            lateSigma = std(signedLevel((nSeg - wN + 1):nSeg), 'omitnan');
            if ~isfinite(lateSigma)
                lateSigma = 0;
            end
            nonzero = (amp > max(2 * lateSigma, 1e-12));

            if totalH < max(5 * lateSigma, 1e-12)
                continue;
            end

            file_id(end + 1, 1) = fname; %#ok<AGROW>
            temperature(end + 1, 1) = tK; %#ok<AGROW>
            pulse_index(end + 1, 1) = p; %#ok<AGROW>
            if mod(p, 2) == 1
                target_state(end + 1, 1) = "A"; %#ok<AGROW>
            else
                target_state(end + 1, 1) = "B"; %#ok<AGROW>
            end
            switch_idx(end + 1, 1) = thisPeak; %#ok<AGROW>
            relax_start_idx(end + 1, 1) = relaxStart; %#ok<AGROW>
            window_end_idx(end + 1, 1) = nextPulse; %#ok<AGROW>
            dt_s(end + 1, 1) = dt; %#ok<AGROW>
            total_pulse_height(end + 1, 1) = totalH; %#ok<AGROW>
            early_window_mean(end + 1, 1) = earlyMean; %#ok<AGROW>
            late_window_mean(end + 1, 1) = lateMean; %#ok<AGROW>
            relaxation_amplitude(end + 1, 1) = amp; %#ok<AGROW>
            normalized_relaxation_amplitude(end + 1, 1) = normAmp; %#ok<AGROW>
            noise_sigma_late(end + 1, 1) = lateSigma; %#ok<AGROW>
            nonzero_relaxation(end + 1, 1) = nonzero; %#ok<AGROW>

            tRel = tSec(segIdx) - tSec(thisPeak);
            relTimeStore{end + 1, 1} = tRel; %#ok<AGROW>
            relShapeStore{end + 1, 1} = (signedLevel - lateMean); %#ok<AGROW>
        end
    end

    eventTbl = table(file_id, temperature, pulse_index, target_state, switch_idx, ...
        relax_start_idx, window_end_idx, dt_s, total_pulse_height, ...
        early_window_mean, late_window_mean, relaxation_amplitude, ...
        normalized_relaxation_amplitude, noise_sigma_late, nonzero_relaxation);
    eventTbl = sortrows(eventTbl, {'temperature', 'file_id', 'pulse_index'});
    writetable(eventTbl, eventOutPath);

    uT = unique(eventTbl.temperature);
    nT = numel(uT);
    total_events = zeros(nT, 1);
    fraction_nonzero_model_free = NaN(nT, 1);
    median_relaxation_amplitude = NaN(nT, 1);
    median_normalized_relaxation_amplitude = NaN(nT, 1);
    old_tau_total_events = zeros(nT, 1);
    old_tau_positive_events = zeros(nT, 1);
    old_tau_positive_fraction = NaN(nT, 1);

    for i = 1:nT
        tNow = uT(i);
        idx = (eventTbl.temperature == tNow);
        total_events(i) = sum(idx);
        fraction_nonzero_model_free(i) = mean(eventTbl.nonzero_relaxation(idx));
        median_relaxation_amplitude(i) = median(eventTbl.relaxation_amplitude(idx), 'omitnan');
        median_normalized_relaxation_amplitude(i) = median(eventTbl.normalized_relaxation_amplitude(idx), 'omitnan');

        idxTau = (abs(tau35.temperature - tNow) < 1e-6);
        old_tau_total_events(i) = sum(idxTau);
        old_tau_positive_events(i) = sum(tau35.tau_relax(idxTau) > 0, 'omitnan');
        if old_tau_total_events(i) > 0
            old_tau_positive_fraction(i) = old_tau_positive_events(i) / old_tau_total_events(i);
        end
    end

    summaryTbl = table(uT, total_events, fraction_nonzero_model_free, ...
        median_relaxation_amplitude, median_normalized_relaxation_amplitude, ...
        old_tau_total_events, old_tau_positive_events, old_tau_positive_fraction, ...
        'VariableNames', {'temperature', 'total_events', 'fraction_nonzero_model_free', ...
        'median_relaxation_amplitude', 'median_normalized_relaxation_amplitude', ...
        'old_tau_total_events', 'old_tau_positive_events', 'old_tau_positive_fraction'});
    summaryTbl = sortrows(summaryTbl, 'temperature');
    writetable(summaryTbl, summaryOutPath);

    tSorted = summaryTbl.temperature;
    if numel(tSorted) < 3
        error('XX35mA:TooFewTemps', 'Need at least 3 temperatures for low/intermediate/high representatives.');
    end
    tLow = tSorted(1);
    tMid = tSorted(round((numel(tSorted) + 1) / 2));
    tHigh = tSorted(end);
    repTemps = [tLow, tMid, tHigh];

    repNames = ["LOW", "INTERMEDIATE", "HIGH"];
    rep_desc = strings(3, 1);
    rep_mean_early = NaN(3, 1);
    rep_mean_late = NaN(3, 1);
    rep_mean_amp = NaN(3, 1);
    rep_mean_norm = NaN(3, 1);
    rep_n_events = zeros(3, 1);

    for r = 1:3
        tRep = repTemps(r);
        idxR = (eventTbl.temperature == tRep);
        rep_n_events(r) = sum(idxR);
        rep_mean_early(r) = mean(eventTbl.early_window_mean(idxR), 'omitnan');
        rep_mean_late(r) = mean(eventTbl.late_window_mean(idxR), 'omitnan');
        rep_mean_amp(r) = mean(eventTbl.relaxation_amplitude(idxR), 'omitnan');
        rep_mean_norm(r) = mean(eventTbl.normalized_relaxation_amplitude(idxR), 'omitnan');

        tGrid = linspace(0, 6, 241)';
        yStack = NaN(numel(tGrid), 0);
        idxList = find(idxR);
        for j = 1:numel(idxList)
            tr = relTimeStore{idxList(j)};
            yr = relShapeStore{idxList(j)};
            ok = isfinite(tr) & isfinite(yr);
            tr = tr(ok);
            yr = yr(ok);
            if numel(tr) < 5
                continue;
            end
            [trU, ia] = unique(tr);
            yrU = yr(ia);
            if numel(trU) < 5
                continue;
            end
            yI = interp1(trU, yrU, tGrid, 'linear', NaN);
            yStack(:, end + 1) = yI; %#ok<AGROW>
        end
        yAvg = mean(yStack, 2, 'omitnan');

        eIdx = (tGrid >= 0.2) & (tGrid <= 1.2);
        lIdx = (tGrid >= 3.0) & (tGrid <= 5.0);
        meanE = mean(yAvg(eIdx), 'omitnan');
        meanL = mean(yAvg(lIdx), 'omitnan');
        rep_desc(r) = sprintf('%s T=%.2f K: n=%d, aligned avg |V-Vlate| early=%.3e, late=%.3e, drop=%.3e.', ...
            repNames(r), tRep, rep_n_events(r), meanE, meanL, meanE - meanL);
    end

    lowIdx = (eventTbl.temperature == tLow);
    lowAmp = eventTbl.relaxation_amplitude(lowIdx);
    lowNoise = eventTbl.noise_sigma_late(lowIdx);
    lowAmpMed = median(lowAmp, 'omitnan');
    lowNoiseMed = median(lowNoise, 'omitnan');
    lowFlat = (lowAmpMed <= max(2 * lowNoiseMed, 1e-12));

    highIdx = (eventTbl.temperature == tHigh);
    highHas = mean(eventTbl.nonzero_relaxation(highIdx)) > 0.5;

    xT = summaryTbl.temperature;
    yFrac = summaryTbl.fraction_nonzero_model_free;
    if numel(xT) >= 3
        slopeEarly = (yFrac(round(numel(yFrac) / 2)) - yFrac(1)) / max(xT(round(numel(yFrac) / 2)) - xT(1), eps);
        slopeLate = (yFrac(end) - yFrac(round(numel(yFrac) / 2))) / max(xT(end) - xT(round(numel(yFrac) / 2)), eps);
        onsetWithT = (yFrac(end) > yFrac(1) + 0.15) && (slopeLate > 0 || slopeEarly > 0);
    else
        onsetWithT = (yFrac(end) > yFrac(1));
    end

    dFrac = summaryTbl.fraction_nonzero_model_free - summaryTbl.old_tau_positive_fraction;
    oldTauUnder = median(dFrac, 'omitnan') > 0.05;

    LOW_T_NO_RELAXATION_REAL = lowFlat;
    HIGH_T_RELAXATION_PRESENT = highHas;
    RELAXATION_ONSET_WITH_T = onsetWithT;
    OLD_TAU_UNDERCAPTURES_RELAXATION = oldTauUnder;

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XX35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end

    fprintf(fid, '# XX 35 mA Relaxation Onset Analysis\n\n');
    fprintf(fid, 'Scope: 35 mA only (`config2_35mA`) with model-free intra-pulse relaxation metrics.\n\n');

    fprintf(fid, '## Representative pulse-shape descriptions\n\n');
    fprintf(fid, '- %s\n', rep_desc(1));
    fprintf(fid, '- %s\n', rep_desc(2));
    fprintf(fid, '- %s\n\n', rep_desc(3));

    fprintf(fid, '## Temperature trend (35 mA)\n\n');
    fprintf(fid, '- `fraction_nonzero_model_free` is computed by event-level threshold `relaxation_amplitude > 2*sigma_late`.\n');
    fprintf(fid, '- `median_relaxation_amplitude` and `median_normalized_relaxation_amplitude` summarize model-free strength.\n');
    fprintf(fid, '- Old metric comparison uses `old_tau_positive_fraction = fraction(tau_relax > 0)` from `xx_relaxation_event_level_full_config2.csv`.\n\n');

    fprintf(fid, '## Low-T regime interpretation\n\n');
    fprintf(fid, '- Low representative temperature: %.2f K.\n', tLow);
    fprintf(fid, '- Median low-T model-free amplitude: %.3e.\n', lowAmpMed);
    fprintf(fid, '- Median low-T late-window noise sigma: %.3e.\n', lowNoiseMed);
    fprintf(fid, '- Flat-within-noise criterion (`amp <= 2*sigma_late`) at low T: %s.\n\n', string(lowFlat));

    fprintf(fid, '## Tau vs model-free comparison\n\n');
    fprintf(fid, '- Median across temperatures of `(fraction_nonzero_model_free - old_tau_positive_fraction)`: %.3f.\n', median(dFrac, 'omitnan'));
    fprintf(fid, '- Positive values indicate model-free metric detects relaxation in events where tau fit is not positive.\n\n');

    fprintf(fid, '## Final verdicts\n\n');
    if LOW_T_NO_RELAXATION_REAL
        fprintf(fid, 'LOW_T_NO_RELAXATION_REAL = YES\n');
    else
        fprintf(fid, 'LOW_T_NO_RELAXATION_REAL = NO\n');
    end
    if HIGH_T_RELAXATION_PRESENT
        fprintf(fid, 'HIGH_T_RELAXATION_PRESENT = YES\n');
    else
        fprintf(fid, 'HIGH_T_RELAXATION_PRESENT = NO\n');
    end
    if RELAXATION_ONSET_WITH_T
        fprintf(fid, 'RELAXATION_ONSET_WITH_T = YES\n');
    else
        fprintf(fid, 'RELAXATION_ONSET_WITH_T = NO\n');
    end
    if OLD_TAU_UNDERCAPTURES_RELAXATION
        fprintf(fid, 'OLD_TAU_UNDERCAPTURES_RELAXATION = YES\n');
    else
        fprintf(fid, 'OLD_TAU_UNDERCAPTURES_RELAXATION = NO\n');
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(uT), {'35mA model-free relaxation tables and report generated'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_35mA_model_free_relaxation_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'35mA model-free relaxation failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPath);
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
writetable(executionStatus, statusPath);

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
