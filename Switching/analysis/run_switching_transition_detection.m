clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

outTableName = 'switching_transition_detection.csv';
outStatusName = 'switching_transition_detection_status.csv';
outReportName = 'switching_transition_detection.md';

try
    cfg = struct();
    cfg.runLabel = 'switching_transition_detection';
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
    pCandidates = {};
    oCandidates = {};
    if exist(runsRoot, 'dir') == 7
        d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
        for i = 1:numel(d)
            tDir = fullfile(runsRoot, d(i).name, 'tables');
            sPath = fullfile(tDir, 'switching_canonical_S_long.csv');
            pPath = fullfile(tDir, 'switching_canonical_phi1.csv');
            oPath = fullfile(tDir, 'switching_canonical_observables.csv');
            if exist(sPath, 'file') == 2 && exist(pPath, 'file') == 2 && exist(oPath, 'file') == 2
                sCandidates{end+1, 1} = sPath; %#ok<AGROW>
                pCandidates{end+1, 1} = pPath; %#ok<AGROW>
                oCandidates{end+1, 1} = oPath; %#ok<AGROW>
            end
        end
    end
    if isempty(sCandidates)
        error('run_switching_transition_detection:NoInput', 'No canonical switching tables found.');
    end
    [~, idxNewest] = max(cellfun(@(p) dir(p).datenum, sCandidates));
    fileS = sCandidates{idxNewest};
    filePhi = pCandidates{idxNewest};
    fileObs = oCandidates{idxNewest};

    tblS = readtable(fileS);
    tblPhi = readtable(filePhi);
    tblObs = readtable(fileObs);

    cT = findColumnContains(tblS, {'t_k'});
    cI = findColumnContains(tblS, {'current', 'ma'});
    cS = findColumnContains(tblS, {'s_percent'});
    cPt = findColumnContains(tblS, {'s_model_pt_percent'});
    cFull = findColumnContains(tblS, {'s_model_full_percent'});
    if isempty(cT) || isempty(cI) || isempty(cS) || isempty(cPt)
        error('run_switching_transition_detection:MissingSCols', 'Missing required S_long columns.');
    end

    cPhiI = findColumnContains(tblPhi, {'current', 'ma'});
    cPhi = findColumnContains(tblPhi, {'phi1'});
    cObsT = findColumnContains(tblObs, {'t_k'});
    cK1 = findColumnContains(tblObs, {'kappa1'});
    if isempty(cPhiI) || isempty(cPhi) || isempty(cObsT) || isempty(cK1)
        error('run_switching_transition_detection:MissingPhiObsCols', 'Missing required phi1/observables columns.');
    end

    Traw = double(tblS.(cT));
    Iraw = double(tblS.(cI));
    Sraw = double(tblS.(cS));
    SptRaw = double(tblS.(cPt));

    temps = unique(Traw(isfinite(Traw)));
    temps = sort(temps(:));
    currents = unique(Iraw(isfinite(Iraw)));
    currents = sort(currents(:));
    nT = numel(temps);
    nI = numel(currents);

    Smap = NaN(nT, nI);
    Scdf = NaN(nT, nI);
    Srank1 = NaN(nT, nI);
    kappa1 = NaN(nT, 1);
    for it = 1:nT
        t = temps(it);
        mT = abs(Traw - t) < 1e-9;
        subI = Iraw(mT);
        subS = Sraw(mT);
        subPt = SptRaw(mT);
        if ~isempty(cFull)
            subFull = double(tblS.(cFull)(mT));
        else
            subFull = NaN(size(subS));
        end
        for ii = 1:nI
            mI = abs(subI - currents(ii)) < 1e-9;
            if any(mI)
                Smap(it, ii) = mean(subS(mI), 'omitnan');
                Scdf(it, ii) = mean(subPt(mI), 'omitnan');
                if any(isfinite(subFull(mI)))
                    Srank1(it, ii) = mean(subFull(mI), 'omitnan');
                end
            end
        end
        mO = abs(double(tblObs.(cObsT)) - t) < 1e-9;
        if any(mO)
            kappa1(it) = mean(double(tblObs.(cK1)(mO)), 'omitnan');
        end
    end

    if all(~isfinite(Srank1(:)))
        phiI = double(tblPhi.(cPhiI));
        phiV = double(tblPhi.(cPhi));
        phiByI = NaN(nI, 1);
        for ii = 1:nI
            m = abs(phiI - currents(ii)) < 1e-9;
            if any(m)
                phiByI(ii) = mean(phiV(m), 'omitnan');
            end
        end
        for it = 1:nT
            if isfinite(kappa1(it))
                Srank1(it, :) = Scdf(it, :) + kappa1(it) .* phiByI';
            end
        end
    end

    R = Smap - Scdf;
    Rfill = R;
    Rfill(~isfinite(Rfill)) = 0;
    [~, ~, V] = svd(Rfill, 'econ');
    phi1 = V(:, 1);
    phi2 = zeros(nI, 1);
    if size(V, 2) >= 2
        phi2 = V(:, 2);
    end

    RMSE_backbone = NaN(nT, 1);
    RMSE_rank1 = NaN(nT, 1);
    residual_norm = NaN(nT, 1);
    rank1_energy = NaN(nT, 1);
    rank2_increment = NaN(nT, 1);
    kappa2 = NaN(nT, 1);
    for it = 1:nT
        vb = isfinite(Smap(it, :)) & isfinite(Scdf(it, :));
        if any(vb)
            d = Smap(it, vb) - Scdf(it, vb);
            RMSE_backbone(it) = sqrt(mean(d.^2, 'omitnan'));
            residual_norm(it) = norm(d, 2);
        end
        vr = isfinite(Smap(it, :)) & isfinite(Srank1(it, :));
        if any(vr)
            d1 = Smap(it, vr) - Srank1(it, vr);
            RMSE_rank1(it) = sqrt(mean(d1.^2, 'omitnan'));
        end
        r = R(it, :)';
        v = isfinite(r) & isfinite(phi1);
        if any(v)
            en = sum(r(v).^2);
            if en > 0
                a1 = dot(r(v), phi1(v));
                rank1_energy(it) = (a1^2) / en;
                if any(isfinite(phi2(v)))
                    a2 = dot(r(v), phi2(v));
                    rank2_increment(it) = (a2^2) / en;
                    kappa2(it) = a2;
                end
            end
        end
    end

    nBase = max(3, min(max(4, round(0.30 * nT)), nT - 2));
    baseIdx = 1:nBase;
    if nT < 6
        baseIdx = 1:max(2, floor(nT/2));
    end

    [fRmseB, chRmseB] = detectMetricTransition(RMSE_backbone, baseIdx, false);
    [fRmse1, chRmse1] = detectMetricTransition(RMSE_rank1, baseIdx, false);
    [fRes, chRes] = detectMetricTransition(residual_norm, baseIdx, false);
    [fRank1Drop, chRank1] = detectMetricTransition(rank1_energy, baseIdx, true);
    [fK2, chK2] = detectMetricTransition(abs(kappa2), baseIdx, false);

    transition_score = zeros(nT, 1);
    transition_score(fRmseB) = transition_score(fRmseB) + 1;
    transition_score(chRmseB) = transition_score(chRmseB) + 1;
    transition_score(fRmse1) = transition_score(fRmse1) + 1;
    transition_score(chRmse1) = transition_score(chRmse1) + 1;
    transition_score(fRes) = transition_score(fRes) + 1;
    transition_score(chRes) = transition_score(chRes) + 1;
    transition_score(fRank1Drop) = transition_score(fRank1Drop) + 1;
    transition_score(chRank1) = transition_score(chRank1) + 1;
    transition_score(fK2) = transition_score(fK2) + 1;
    transition_score(chK2) = transition_score(chK2) + 1;

    transition_flag = strings(nT, 1);
    transition_flag(:) = "NO";
    rawFlag = transition_score >= 2;
    for it = 1:nT
        if rawFlag(it)
            transition_flag(it) = "YES";
        end
    end

    stableFlag = rawFlag;
    if nT >= 3
        for it = 2:(nT-1)
            if rawFlag(it) && (~rawFlag(it-1) && ~rawFlag(it+1))
                stableFlag(it) = false;
            end
        end
    end
    transition_flag(:) = "NO";
    transition_flag(stableFlag) = "YES";

    [onsetIdx, wStartIdx, wEndIdx] = firstConsistentWindow(stableFlag);
    transition_onset_T = NaN;
    transition_window_start = NaN;
    transition_window_end = NaN;
    if isfinite(onsetIdx)
        transition_onset_T = temps(onsetIdx);
        transition_window_start = temps(wStartIdx);
        transition_window_end = temps(wEndIdx);
    end

    outTbl = table(temps, RMSE_backbone, RMSE_rank1, residual_norm, rank1_energy, rank2_increment, kappa2, transition_flag, ...
        'VariableNames', {'T_K', 'RMSE_backbone', 'RMSE_rank1', 'residual_norm', 'rank1_energy', 'rank2_increment', 'kappa2', 'transition_flag'});

    statusTbl = table(string("SUCCESS"), ...
        string(sprintf('source=%s', fileS)), ...
        transition_onset_T, transition_window_start, transition_window_end, ...
        'VariableNames', {'STATUS', 'data_integrity_checks', 'transition_onset_T', 'transition_window_start', 'transition_window_end'});

    reportLines = {};
    reportLines{end+1} = '# Switching Transition Detection';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Method';
    reportLines{end+1} = '- Data-driven deviations from low-T baseline (first ~30% lowest T points).';
    reportLines{end+1} = '- Signals: RMSE_backbone, RMSE_rank1, residual_norm, rank1_energy drop, kappa2 emergence.';
    reportLines{end+1} = '- Transition flag requires multi-signal support (score >=2) and temporal consistency (isolated singletons removed).';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Derived Metrics';
    if isfinite(transition_onset_T)
        reportLines{end+1} = sprintf('- transition_onset_T = %.6g K', transition_onset_T);
        reportLines{end+1} = sprintf('- transition_window_start = %.6g K', transition_window_start);
        reportLines{end+1} = sprintf('- transition_window_end = %.6g K', transition_window_end);
    else
        reportLines{end+1} = '- transition_onset_T = INCONCLUSIVE';
        reportLines{end+1} = '- transition_window_start = INCONCLUSIVE';
        reportLines{end+1} = '- transition_window_end = INCONCLUSIVE';
    end

    writetable(outTbl, fullfile(runTablesDir, outTableName));
    writetable(statusTbl, fullfile(runTablesDir, outStatusName));
    writetable(outTbl, fullfile(repoRoot, 'tables', outTableName));
    writetable(statusTbl, fullfile(repoRoot, 'tables', outStatusName));
    writeLines(fullfile(runReportsDir, outReportName), reportLines);
    writeLines(fullfile(repoRoot, 'reports', outReportName), reportLines);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching transition detection completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_transition_detection_failure');
        if exist(runDir, 'dir') ~= 7
            mkdir(runDir);
        end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'tables'));
    end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'reports'));
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    outTbl = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), ...
        'VariableNames', {'T_K', 'RMSE_backbone', 'RMSE_rank1', 'residual_norm', 'rank1_energy', 'rank2_increment', 'kappa2', 'transition_flag'});
    statusTbl = table(string("FAILED"), string(ME.message), NaN, NaN, NaN, ...
        'VariableNames', {'STATUS', 'data_integrity_checks', 'transition_onset_T', 'transition_window_start', 'transition_window_end'});
    writetable(outTbl, fullfile(runDir, 'tables', outTableName));
    writetable(statusTbl, fullfile(runDir, 'tables', outStatusName));
    writetable(outTbl, fullfile(repoRoot, 'tables', outTableName));
    writetable(statusTbl, fullfile(repoRoot, 'tables', outStatusName));

    lines = {};
    lines{end+1} = '# Switching Transition Detection FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', outReportName), lines);
    writeLines(fullfile(repoRoot, 'reports', outReportName), lines);

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching transition detection failed'}, true);
    rethrow(ME);
end

function c = findColumnContains(tbl, keys)
names = string(tbl.Properties.VariableNames);
c = '';
for i = 1:numel(names)
    n = lower(char(names(i)));
    ok = true;
    for k = 1:numel(keys)
        if ~contains(n, lower(keys{k}))
            ok = false;
            break;
        end
    end
    if ok
        c = char(names(i));
        return;
    end
end
end

function [firstDev, slopeChange] = detectMetricTransition(x, baseIdx, invertDirection)
firstDev = false(size(x));
slopeChange = false(size(x));
if isempty(x) || nnz(isfinite(x(baseIdx))) < 2
    return;
end

mu = mean(x(baseIdx), 'omitnan');
sd = std(x(baseIdx), 'omitnan');
if ~isfinite(sd) || sd <= 0
    sd = max(abs(mu) * 0.05, 1e-12);
end

thr = mu + 2 * sd;
if invertDirection
    thr = mu - 2 * sd;
end
for i = 1:numel(x)
    if ~isfinite(x(i))
        continue;
    end
    if invertDirection
        if x(i) < thr
            firstDev(i) = true;
        end
    else
        if x(i) > thr
            firstDev(i) = true;
        end
    end
end

dx = diff(x);
if numel(dx) < 2
    return;
end
bmax = min(numel(baseIdx)-1, numel(dx));
if bmax < 2
    return;
end
baseSlope = dx(1:bmax);
ms = mean(baseSlope, 'omitnan');
ss = std(baseSlope, 'omitnan');
if ~isfinite(ss) || ss <= 0
    ss = max(abs(ms) * 0.05, 1e-12);
end
for i = 1:numel(dx)
    if ~isfinite(dx(i))
        continue;
    end
    if abs(dx(i) - ms) > 2 * ss
        slopeChange(i+1) = true;
    end
end
end

function [onsetIdx, startIdx, endIdx] = firstConsistentWindow(flag)
onsetIdx = NaN;
startIdx = NaN;
endIdx = NaN;
if ~any(flag)
    return;
end
n = numel(flag);
i = 1;
while i <= n
    if ~flag(i)
        i = i + 1;
        continue;
    end
    j = i;
    while j < n && flag(j+1)
        j = j + 1;
    end
    if (j - i + 1) >= 2
        onsetIdx = i;
        startIdx = i;
        endIdx = j;
        return;
    end
    i = j + 1;
end
idx = find(flag, 1, 'first');
onsetIdx = idx;
startIdx = idx;
endIdx = idx;
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_transition_detection:WriteFail', 'Cannot write file: %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
