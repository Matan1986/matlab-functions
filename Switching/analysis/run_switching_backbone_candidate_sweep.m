clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

outMetricsName = 'switching_backbone_candidate_sweep_metrics.csv';
outSummaryName = 'switching_backbone_candidate_regime_summary.csv';
outStatusName = 'switching_backbone_sweep_status.csv';
outReportName = 'switching_backbone_candidate_sweep.md';

statusText = 'FAILED';
nCandidates = 4;
tempBinsUsed = '';
integrityChecks = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_backbone_candidate_sweep';
    cfg.dataset = 'canonical_switching_tables_only';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    runsRoot = switchingCanonicalRunRoot(repoRoot);
    sCandidates = {};
    oCandidates = {};

    if exist(runsRoot, 'dir') == 7
        runDirs = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
        for iRun = 1:numel(runDirs)
            tDir = fullfile(runsRoot, runDirs(iRun).name, 'tables');
            sPath = fullfile(tDir, 'switching_canonical_S_long.csv');
            oPath = fullfile(tDir, 'switching_canonical_observables.csv');
            if exist(sPath, 'file') == 2 && exist(oPath, 'file') == 2
                sCandidates{end+1, 1} = sPath; %#ok<AGROW>
                oCandidates{end+1, 1} = oPath; %#ok<AGROW>
            end
        end
    end

    if isempty(sCandidates)
        knownRunIds = { ...
            'run_2026_04_03_000147_switching_canonical'; ...
            'run_2026_04_03_091018_switching_canonical'};
        for iK = 1:numel(knownRunIds)
            tDir = fullfile(repoRoot, 'results', 'switching', 'runs', knownRunIds{iK}, 'tables');
            sPath = fullfile(tDir, 'switching_canonical_S_long.csv');
            oPath = fullfile(tDir, 'switching_canonical_observables.csv');
            if exist(sPath, 'file') == 2 && exist(oPath, 'file') == 2
                sCandidates{end+1, 1} = sPath; %#ok<AGROW>
                oCandidates{end+1, 1} = oPath; %#ok<AGROW>
            end
        end
    end

    inputFound = ~isempty(sCandidates);
    selectedSource = '';
    if inputFound
        [~, idxNewest] = max(cellfun(@(p) dir(p).datenum, sCandidates));
        fileS = sCandidates{idxNewest};
        fileO = oCandidates{idxNewest};
        selectedSource = fileS;
    else
        fileS = '';
        fileO = '';
    end

    metricsVarNames = {'candidate_id', 'T_K', 'RMSE_global', 'RMSE_ridge', 'rank1_energy', 'residual_cosine_prev_T', 'regime_label'};
    summaryVarNames = {'candidate_id', 'mean_RMSE_lowT', 'mean_RMSE_midT', 'mean_RMSE_highT', ...
        'mean_RMSE_ridge_lowT', 'mean_RMSE_ridge_midT', 'mean_RMSE_ridge_highT', ...
        'mean_rank1_lowT', 'mean_rank1_midT', 'mean_rank1_highT', ...
        'degradation_onset_T', 'lowT_degradation', 'ridge_mismatch_persistent', 'highT_pattern_persistent'};

    if ~inputFound
        metricsTbl = cell2table(cell(0, numel(metricsVarNames)), 'VariableNames', metricsVarNames);
        summaryTbl = cell2table(cell(0, numel(summaryVarNames)), 'VariableNames', summaryVarNames);

        statusText = 'NO_INPUT';
        tempBinsUsed = 'none';
        integrityChecks = 'INPUT_FOUND=NO';
    else
        tblS = readtable(fileS);
        tblO = readtable(fileO);

        reqS = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'PT_pdf', 'CDF_pt'};
        for iC = 1:numel(reqS)
            if ~ismember(reqS{iC}, tblS.Properties.VariableNames)
                error('run_switching_backbone_candidate_sweep:MissingSLongColumn', ...
                    'switching_canonical_S_long.csv missing %s', reqS{iC});
            end
        end
        reqO = {'T_K', 'S_peak'};
        for iC = 1:numel(reqO)
            if ~ismember(reqO{iC}, tblO.Properties.VariableNames)
                error('run_switching_backbone_candidate_sweep:MissingObsColumn', ...
                    'switching_canonical_observables.csv missing %s', reqO{iC});
            end
        end

        temps = unique(double(tblS.T_K(:)));
        temps = temps(isfinite(temps));
        temps = sort(temps(:));
        currents = unique(double(tblS.current_mA(:)));
        currents = currents(isfinite(currents));
        currents = sort(currents(:));
        nT = numel(temps);
        nI = numel(currents);
        if nT < 3 || nI < 5
            error('run_switching_backbone_candidate_sweep:InsufficientGrid', ...
                'Need at least 3 temperatures and 5 current points (got nT=%d, nI=%d).', nT, nI);
        end

        Smap = NaN(nT, nI);
        ScdfC1 = NaN(nT, nI);
        PTmap = NaN(nT, nI);
        CDFmap = NaN(nT, nI);
        Speak = NaN(nT, 1);
        for it = 1:nT
            tMask = abs(double(tblS.T_K) - temps(it)) < 1e-9;
            sub = tblS(tMask, :);
            for ii = 1:nI
                m = abs(double(sub.current_mA) - currents(ii)) < 1e-9;
                if any(m)
                    Smap(it, ii) = mean(double(sub.S_percent(m)), 'omitnan');
                    ScdfC1(it, ii) = mean(double(sub.S_model_pt_percent(m)), 'omitnan');
                    PTmap(it, ii) = mean(double(sub.PT_pdf(m)), 'omitnan');
                    CDFmap(it, ii) = mean(double(sub.CDF_pt(m)), 'omitnan');
                end
            end
            oMask = abs(double(tblO.T_K) - temps(it)) < 1e-9;
            if any(oMask)
                Speak(it) = mean(double(tblO.S_peak(oMask)), 'omitnan');
            end
        end

        lowBoundary = 22;
        highBoundary = 26;
        if sum(temps <= lowBoundary) == 0 || sum(temps >= highBoundary) == 0
            q = quantile(temps, [1/3, 2/3]);
            lowBoundary = q(1);
            highBoundary = q(2);
        end
        regime = strings(nT, 1);
        for it = 1:nT
            if temps(it) <= lowBoundary
                regime(it) = "lowT";
            elseif temps(it) >= highBoundary
                regime(it) = "highT";
            else
                regime(it) = "midT";
            end
        end
        tempBinsUsed = sprintf('low<=%.4g;mid(%.4g,%.4g);high>=%.4g', lowBoundary, lowBoundary, highBoundary, highBoundary);

        ridgeMask = currents >= 35 & currents <= 45;
        if ~any(ridgeMask)
            ridgeMask = currents >= quantile(currents, 0.55) & currents <= quantile(currents, 0.80);
        end

        candidates = {'C1', 'C2', 'C3', 'C4'};
        candidateDesc = {'rowwise_monotone_cdf_from_S_over_Speak', ...
            'PT_matrix_driven_canonicalized', ...
            'pooled_crossT_backbone', ...
            'rowwise_cdf_crossT_smoothness'};
        nCand = numel(candidates);
        RMSE = NaN(nT, nCand);
        RMSERidge = NaN(nT, nCand);
        rank1Energy = NaN(nT, nCand);
        residualVarMode1 = NaN(nT, nCand);
        residualCosPrev = NaN(nT, nCand);
        scdfAll = NaN(nT, nI, nCand);

        scdfAll(:, :, 1) = ScdfC1;

        for it = 1:nT
            rowPt = PTmap(it, :);
            rowP = rowPt(:)';
            rowP(~isfinite(rowP)) = 0;
            rowP = max(rowP, 0);
            v = isfinite(Smap(it, :));
            if nnz(v) >= 3
                area = trapz(currents(v), rowP(v));
                if isfinite(area) && area > 0
                    rowP(v) = rowP(v) ./ area;
                elseif any(v)
                    rowP(v) = 0;
                end
                cdf = cumtrapz(currents(v), rowP(v));
                if cdf(end) > 0
                    cdf = cdf ./ cdf(end);
                end
                cdf = min(max(cdf, 0), 1);
                cdfFull = NaN(1, nI);
                cdfFull(v) = cdf;
                for j = 2:nI
                    if isfinite(cdfFull(j)) && isfinite(cdfFull(j-1)) && cdfFull(j) < cdfFull(j-1)
                        cdfFull(j) = cdfFull(j-1);
                    end
                end
                if isfinite(Speak(it))
                    scdfAll(it, :, 2) = Speak(it) .* cdfFull;
                end
            end
        end

        cdfNorm = NaN(nT, nI);
        for it = 1:nT
            if isfinite(Speak(it)) && Speak(it) > 0
                cdfNorm(it, :) = ScdfC1(it, :) ./ Speak(it);
            end
        end
        pooled = nanmean(cdfNorm, 1);
        pooled = min(max(pooled, 0), 1);
        for j = 2:nI
            if isfinite(pooled(j)) && isfinite(pooled(j-1)) && pooled(j) < pooled(j-1)
                pooled(j) = pooled(j-1);
            end
        end
        if isfinite(pooled(end)) && pooled(end) > 0
            pooled = pooled ./ pooled(end);
        end
        for it = 1:nT
            if isfinite(Speak(it))
                scdfAll(it, :, 3) = Speak(it) .* pooled;
            end
        end

        smoothCdf = cdfNorm;
        for ii = 1:nI
            col = cdfNorm(:, ii);
            smoothCdf(:, ii) = movmean(col, 3, 'omitnan');
        end
        smoothCdf = min(max(smoothCdf, 0), 1);
        for it = 1:nT
            row = smoothCdf(it, :);
            for j = 2:nI
                if isfinite(row(j)) && isfinite(row(j-1)) && row(j) < row(j-1)
                    row(j) = row(j-1);
                end
            end
            if isfinite(row(end)) && row(end) > 0
                row = row ./ row(end);
            end
            if isfinite(Speak(it))
                scdfAll(it, :, 4) = Speak(it) .* row;
            end
        end

        for ic = 1:nCand
            residual = Smap - scdfAll(:, :, ic);
            residualFill = residual;
            residualFill(~isfinite(residualFill)) = 0;
            [U, Sg, V] = svd(residualFill, 'econ');
            if isempty(Sg)
                phi1 = zeros(nI, 1);
                sigma1 = 0;
            else
                phi1 = V(:, 1);
                sigma1 = Sg(1, 1);
            end
            for it = 1:nT
                v = isfinite(Smap(it, :)) & isfinite(scdfAll(it, :, ic));
                if any(v)
                    d = Smap(it, v) - scdfAll(it, v, ic);
                    RMSE(it, ic) = sqrt(mean(d.^2, 'omitnan'));
                    if any(v & ridgeMask')
                        dR = Smap(it, v & ridgeMask') - scdfAll(it, v & ridgeMask', ic);
                        RMSERidge(it, ic) = sqrt(mean(dR.^2, 'omitnan'));
                    end
                end
                rv = residual(it, :)';
                vm = isfinite(rv) & isfinite(phi1);
                if any(vm)
                    denom = sum(rv(vm).^2);
                    if denom > 0
                        a = dot(rv(vm), phi1(vm));
                        rank1Energy(it, ic) = (a^2) / denom;
                        residualVarMode1(it, ic) = (sigma1^2) / max(sum(diag(Sg).^2), eps);
                    end
                end
                if it > 1
                    rvp = residual(it-1, :)';
                    v2 = isfinite(rv) & isfinite(rvp);
                    if sum(v2) >= 2
                        n1 = norm(rv(v2));
                        n2 = norm(rvp(v2));
                        if n1 > 0 && n2 > 0
                            residualCosPrev(it, ic) = dot(rv(v2), rvp(v2)) / (n1 * n2);
                        end
                    end
                end
            end
        end

        metricsRows = nT * nCand;
        candidateIdCol = strings(metricsRows, 1);
        Tcol = NaN(metricsRows, 1);
        rmseCol = NaN(metricsRows, 1);
        rmseRCol = NaN(metricsRows, 1);
        rank1Col = NaN(metricsRows, 1);
        cosPrevCol = NaN(metricsRows, 1);
        regimeCol = strings(metricsRows, 1);
        rr = 0;
        for ic = 1:nCand
            for it = 1:nT
                rr = rr + 1;
                candidateIdCol(rr) = string(candidates{ic});
                Tcol(rr) = temps(it);
                rmseCol(rr) = RMSE(it, ic);
                rmseRCol(rr) = RMSERidge(it, ic);
                rank1Col(rr) = rank1Energy(it, ic);
                cosPrevCol(rr) = residualCosPrev(it, ic);
                regimeCol(rr) = regime(it);
            end
        end
        metricsTbl = table(candidateIdCol, Tcol, rmseCol, rmseRCol, rank1Col, cosPrevCol, regimeCol, 'VariableNames', metricsVarNames);

        lowMask = regime == "lowT";
        midMask = regime == "midT";
        highMask = regime == "highT";
        summaryTbl = table('Size', [nCand, numel(summaryVarNames)], ...
            'VariableTypes', {'string','double','double','double','double','double','double','double','double','double','double','string','string','string'}, ...
            'VariableNames', summaryVarNames);

        baseRmse = RMSE(:, 1);
        baseHighRmse = RMSE(highMask, 1);
        for ic = 1:nCand
            summaryTbl.candidate_id(ic) = string(candidates{ic});
            summaryTbl.mean_RMSE_lowT(ic) = mean(RMSE(lowMask, ic), 'omitnan');
            summaryTbl.mean_RMSE_midT(ic) = mean(RMSE(midMask, ic), 'omitnan');
            summaryTbl.mean_RMSE_highT(ic) = mean(RMSE(highMask, ic), 'omitnan');
            summaryTbl.mean_RMSE_ridge_lowT(ic) = mean(RMSERidge(lowMask, ic), 'omitnan');
            summaryTbl.mean_RMSE_ridge_midT(ic) = mean(RMSERidge(midMask, ic), 'omitnan');
            summaryTbl.mean_RMSE_ridge_highT(ic) = mean(RMSERidge(highMask, ic), 'omitnan');
            summaryTbl.mean_rank1_lowT(ic) = mean(rank1Energy(lowMask, ic), 'omitnan');
            summaryTbl.mean_rank1_midT(ic) = mean(rank1Energy(midMask, ic), 'omitnan');
            summaryTbl.mean_rank1_highT(ic) = mean(rank1Energy(highMask, ic), 'omitnan');

            onset = NaN;
            lowMed = median(RMSE(lowMask, ic), 'omitnan');
            if isfinite(lowMed) && lowMed > 0
                onsetIdx = find(RMSE(:, ic) >= 1.25 * lowMed, 1, 'first');
                if ~isempty(onsetIdx)
                    onset = temps(onsetIdx);
                end
            end
            summaryTbl.degradation_onset_T(ic) = onset;

            lowDeg = "NO";
            if ic > 1
                if mean(RMSE(lowMask, ic), 'omitnan') > 1.05 * mean(baseRmse(lowMask), 'omitnan')
                    lowDeg = "YES";
                end
            end
            summaryTbl.lowT_degradation(ic) = lowDeg;

            ridgePersistent = "NO";
            if mean(RMSERidge(highMask, ic), 'omitnan') > 1.15 * mean(RMSERidge(lowMask, ic), 'omitnan')
                ridgePersistent = "YES";
            end
            summaryTbl.ridge_mismatch_persistent(ic) = ridgePersistent;

            highPersistent = "NO";
            if ic > 1 && ~isempty(baseHighRmse)
                if mean(RMSE(highMask, ic), 'omitnan') >= 0.95 * mean(baseHighRmse, 'omitnan')
                    highPersistent = "YES";
                end
            elseif ic == 1
                highPersistent = "YES";
            end
            summaryTbl.highT_pattern_persistent(ic) = highPersistent;
        end

        statusText = 'SUCCESS';
        integrityChecks = sprintf('INPUT_FOUND=YES;SOURCE=%s;N_T=%d;N_I=%d;RidgeWindowDefined=%d', selectedSource, nT, nI, any(ridgeMask));

        dRmseHigh = summaryTbl.mean_RMSE_highT - summaryTbl.mean_RMSE_highT(1);
        dRmseRidgeHigh = summaryTbl.mean_RMSE_ridge_highT - summaryTbl.mean_RMSE_ridge_highT(1);
        anyOutperforms = any((dRmseHigh(2:end) < -1e-12) | (dRmseRidgeHigh(2:end) < -1e-12));
        improvesHighNoLow = false;
        for ic = 2:nCand
            betterHigh = summaryTbl.mean_RMSE_highT(ic) < summaryTbl.mean_RMSE_highT(1) || ...
                summaryTbl.mean_RMSE_ridge_highT(ic) < summaryTbl.mean_RMSE_ridge_highT(1);
            noLowHurt = summaryTbl.lowT_degradation(ic) == "NO";
            if betterHigh && noLowHurt
                improvesHighNoLow = true;
            end
        end
        residualInvariant = true;
        baseRank = rank1Energy(:, 1);
        baseCos = residualCosPrev(:, 1);
        for ic = 2:nCand
            dRank = abs(mean(rank1Energy(:, ic) - baseRank, 'omitnan'));
            dCos = abs(mean(residualCosPrev(:, ic) - baseCos, 'omitnan'));
            if dRank > 0.1 || dCos > 0.15
                residualInvariant = false;
            end
        end

        backboneLimiting = "YES";
        highDependent = "YES";
        if ~improvesHighNoLow && residualInvariant
            backboneLimiting = "NO";
            highDependent = "NO";
        end
        backboneConsistent = "NO";
        if all(summaryTbl.lowT_degradation == "NO")
            backboneConsistent = "YES";
        end
        safeProceed = "NO";
        if backboneLimiting == "NO"
            safeProceed = "YES";
        end

        bestGlobalIdx = find(summaryTbl.mean_RMSE_lowT + summaryTbl.mean_RMSE_midT + summaryTbl.mean_RMSE_highT == ...
            min(summaryTbl.mean_RMSE_lowT + summaryTbl.mean_RMSE_midT + summaryTbl.mean_RMSE_highT), 1, 'first');
        bestRidgeIdx = find(summaryTbl.mean_RMSE_ridge_lowT + summaryTbl.mean_RMSE_ridge_midT + summaryTbl.mean_RMSE_ridge_highT == ...
            min(summaryTbl.mean_RMSE_ridge_lowT + summaryTbl.mean_RMSE_ridge_midT + summaryTbl.mean_RMSE_ridge_highT), 1, 'first');

        reportLines = {};
        reportLines{end+1} = '# Switching Backbone Candidate Sweep';
        reportLines{end+1} = '';
        reportLines{end+1} = '## 1. Candidate Definitions';
        reportLines{end+1} = '';
        for ic = 1:nCand
            reportLines{end+1} = sprintf('- %s: %s', candidates{ic}, candidateDesc{ic});
        end
        reportLines{end+1} = '';
        reportLines{end+1} = '## 2. Global Comparison';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- overall RMSE minimum candidate: %s', candidates{bestGlobalIdx});
        reportLines{end+1} = sprintf('- ridge RMSE minimum candidate: %s', candidates{bestRidgeIdx});
        reportLines{end+1} = '';
        reportLines{end+1} = '## 3. Low-T Sanity Check (CRITICAL)';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- low-T mean RMSE by candidate: C1=%.6g, C2=%.6g, C3=%.6g, C4=%.6g', ...
            summaryTbl.mean_RMSE_lowT(1), summaryTbl.mean_RMSE_lowT(2), summaryTbl.mean_RMSE_lowT(3), summaryTbl.mean_RMSE_lowT(4));
        reportLines{end+1} = sprintf('- low-T degradation flags: C1=%s, C2=%s, C3=%s, C4=%s', ...
            summaryTbl.lowT_degradation(1), summaryTbl.lowT_degradation(2), summaryTbl.lowT_degradation(3), summaryTbl.lowT_degradation(4));
        reportLines{end+1} = sprintf('- low-T residual rank1 means: C1=%.6g, C2=%.6g, C3=%.6g, C4=%.6g', ...
            summaryTbl.mean_rank1_lowT(1), summaryTbl.mean_rank1_lowT(2), summaryTbl.mean_rank1_lowT(3), summaryTbl.mean_rank1_lowT(4));
        reportLines{end+1} = '';
        reportLines{end+1} = '## 4. Mid-T Transition Analysis';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- degradation_onset_T: C1=%.6g, C2=%.6g, C3=%.6g, C4=%.6g', ...
            summaryTbl.degradation_onset_T(1), summaryTbl.degradation_onset_T(2), summaryTbl.degradation_onset_T(3), summaryTbl.degradation_onset_T(4));
        reportLines{end+1} = '- onset consistency checked via same threshold ratio (1.25 x low-T median RMSE).';
        reportLines{end+1} = '';
        reportLines{end+1} = '## 5. High-T Behavior';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- high-T mean RMSE: C1=%.6g, C2=%.6g, C3=%.6g, C4=%.6g', ...
            summaryTbl.mean_RMSE_highT(1), summaryTbl.mean_RMSE_highT(2), summaryTbl.mean_RMSE_highT(3), summaryTbl.mean_RMSE_highT(4));
        reportLines{end+1} = sprintf('- ridge mismatch persistence flags: C1=%s, C2=%s, C3=%s, C4=%s', ...
            summaryTbl.ridge_mismatch_persistent(1), summaryTbl.ridge_mismatch_persistent(2), summaryTbl.ridge_mismatch_persistent(3), summaryTbl.ridge_mismatch_persistent(4));
        reportLines{end+1} = '';
        reportLines{end+1} = '## 6. Residual Structure Consistency';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- residual structure backbone-invariant by threshold test: %s', string(residualInvariant));
        reportLines{end+1} = '';
        reportLines{end+1} = '## Final Verdicts';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- BACKBONE_SELECTION_IS_LIMITING_FACTOR = %s', backboneLimiting);
        reportLines{end+1} = sprintf('- ANY_CANDIDATE_OUTPERFORMS_C1 = %s', string(anyOutperforms));
        reportLines{end+1} = sprintf('- ANY_CANDIDATE_IMPROVES_HIGH_T_WITHOUT_HURTING_LOW_T = %s', string(improvesHighNoLow));
        reportLines{end+1} = sprintf('- HIGH_T_MISMATCH_BACKBONE_DEPENDENT = %s', highDependent);
        reportLines{end+1} = sprintf('- BACKBONE_CONSISTENT_ACROSS_T = %s', backboneConsistent);
        reportLines{end+1} = sprintf('- SAFE_TO_PROCEED_TO_MODE_ANALYSIS = %s', safeProceed);
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- temperature_bins_used: %s', tempBinsUsed);
        reportLines{end+1} = sprintf('- data_integrity_checks: %s', integrityChecks);
    end

    statusTbl = table(string(statusText), nCandidates, string(tempBinsUsed), string(integrityChecks), ...
        'VariableNames', {'STATUS', 'N_candidates', 'temperature_bins_used', 'data_integrity_checks'});

    runMetricsPath = fullfile(runTablesDir, outMetricsName);
    runSummaryPath = fullfile(runTablesDir, outSummaryName);
    runStatusPath = fullfile(runTablesDir, outStatusName);
    repoMetricsPath = fullfile(repoRoot, 'tables', outMetricsName);
    repoSummaryPath = fullfile(repoRoot, 'tables', outSummaryName);
    repoStatusPath = fullfile(repoRoot, 'tables', outStatusName);
    runReportPath = fullfile(runReportsDir, outReportName);
    repoReportPath = fullfile(repoRoot, 'reports', outReportName);

    writetable(metricsTbl, runMetricsPath);
    writetable(summaryTbl, runSummaryPath);
    writetable(statusTbl, runStatusPath);
    writetable(metricsTbl, repoMetricsPath);
    writetable(summaryTbl, repoSummaryPath);
    writetable(statusTbl, repoStatusPath);

    if ~exist('reportLines', 'var')
        reportLines = {};
        reportLines{end+1} = '# Switching Backbone Candidate Sweep';
        reportLines{end+1} = '';
        reportLines{end+1} = '- Input canonical tables were not found.';
        reportLines{end+1} = '- Required output files were written with empty tables.';
        reportLines{end+1} = '';
        reportLines{end+1} = '- BACKBONE_SELECTION_IS_LIMITING_FACTOR = INCONCLUSIVE';
        reportLines{end+1} = '- ANY_CANDIDATE_OUTPERFORMS_C1 = INCONCLUSIVE';
        reportLines{end+1} = '- ANY_CANDIDATE_IMPROVES_HIGH_T_WITHOUT_HURTING_LOW_T = INCONCLUSIVE';
        reportLines{end+1} = '- HIGH_T_MISMATCH_BACKBONE_DEPENDENT = INCONCLUSIVE';
        reportLines{end+1} = '- BACKBONE_CONSISTENT_ACROSS_T = INCONCLUSIVE';
        reportLines{end+1} = '- SAFE_TO_PROCEED_TO_MODE_ANALYSIS = INCONCLUSIVE';
    end

    fidRep = fopen(runReportPath, 'w');
    if fidRep < 0
        error('run_switching_backbone_candidate_sweep:ReportWriteFailed', 'Cannot write run report: %s', runReportPath);
    end
    for iL = 1:numel(reportLines)
        fprintf(fidRep, '%s\n', reportLines{iL});
    end
    fclose(fidRep);

    fidRep2 = fopen(repoReportPath, 'w');
    if fidRep2 < 0
        error('run_switching_backbone_candidate_sweep:ReportWriteFailed', 'Cannot write repo report: %s', repoReportPath);
    end
    for iL = 1:numel(reportLines)
        fprintf(fidRep2, '%s\n', reportLines{iL});
    end
    fclose(fidRep2);

    nTOut = 0;
    if exist('metricsTbl', 'var')
        nTOut = numel(unique(metricsTbl.T_K));
    end
    inFoundStr = 'NO';
    if inputFound
        inFoundStr = 'YES';
    end
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {inFoundStr}, {''}, nTOut, {'switching backbone candidate sweep completed'}, true);

    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_backbone_candidate_sweep_failure');
        if exist(runDir, 'dir') ~= 7
            mkdir(runDir);
        end
    end
    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    metricsTbl = cell2table(cell(0, 7), 'VariableNames', {'candidate_id', 'T_K', 'RMSE_global', 'RMSE_ridge', 'rank1_energy', 'residual_cosine_prev_T', 'regime_label'});
    summaryTbl = cell2table(cell(0, 14), 'VariableNames', {'candidate_id', 'mean_RMSE_lowT', 'mean_RMSE_midT', 'mean_RMSE_highT', ...
        'mean_RMSE_ridge_lowT', 'mean_RMSE_ridge_midT', 'mean_RMSE_ridge_highT', ...
        'mean_rank1_lowT', 'mean_rank1_midT', 'mean_rank1_highT', ...
        'degradation_onset_T', 'lowT_degradation', 'ridge_mismatch_persistent', 'highT_pattern_persistent'});
    statusTbl = table("FAILED", 4, "", string(ME.message), ...
        'VariableNames', {'STATUS', 'N_candidates', 'temperature_bins_used', 'data_integrity_checks'});

    writetable(metricsTbl, fullfile(runTablesDir, outMetricsName));
    writetable(summaryTbl, fullfile(runTablesDir, outSummaryName));
    writetable(statusTbl, fullfile(runTablesDir, outStatusName));
    writetable(metricsTbl, fullfile(repoRoot, 'tables', outMetricsName));
    writetable(summaryTbl, fullfile(repoRoot, 'tables', outSummaryName));
    writetable(statusTbl, fullfile(repoRoot, 'tables', outStatusName));

    failLines = {};
    failLines{end+1} = '# Switching Backbone Candidate Sweep FAILED';
    failLines{end+1} = '';
    failLines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    failLines{end+1} = sprintf('- error_message: `%s`', ME.message);
    failLines{end+1} = '- BACKBONE_SELECTION_IS_LIMITING_FACTOR = INCONCLUSIVE';
    failLines{end+1} = '- ANY_CANDIDATE_OUTPERFORMS_C1 = INCONCLUSIVE';
    failLines{end+1} = '- ANY_CANDIDATE_IMPROVES_HIGH_T_WITHOUT_HURTING_LOW_T = INCONCLUSIVE';
    failLines{end+1} = '- HIGH_T_MISMATCH_BACKBONE_DEPENDENT = INCONCLUSIVE';
    failLines{end+1} = '- BACKBONE_CONSISTENT_ACROSS_T = INCONCLUSIVE';
    failLines{end+1} = '- SAFE_TO_PROCEED_TO_MODE_ANALYSIS = INCONCLUSIVE';

    fidFail = fopen(fullfile(runReportsDir, outReportName), 'w');
    if fidFail >= 0
        for iL = 1:numel(failLines)
            fprintf(fidFail, '%s\n', failLines{iL});
        end
        fclose(fidFail);
    end
    fidFail2 = fopen(fullfile(repoRoot, 'reports', outReportName), 'w');
    if fidFail2 >= 0
        for iL = 1:numel(failLines)
            fprintf(fidFail2, '%s\n', failLines{iL});
        end
        fclose(fidFail2);
    end

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching backbone candidate sweep failed'}, true);
    rethrow(ME);
end
