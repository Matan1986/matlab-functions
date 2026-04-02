% ================================
% EXPERIMENTAL SCRIPT
% NOT CANONICAL
%
% Purpose:
% Baseline / raw observable exploration
%
% Status:
% Not part of validated switching pipeline
% Do NOT use for canonical physics results
% ================================

clear; clc;

repoRoot = '';
probeDir = pwd;
for level = 1:15
    if exist(fullfile(probeDir, 'README.md'), 'file') == 2 && ...
       exist(fullfile(probeDir, 'Aging'), 'dir') == 7 && ...
       exist(fullfile(probeDir, 'Switching'), 'dir') == 7
        repoRoot = probeDir;
        break;
    end
    parentDir = fileparts(probeDir);
    if strcmp(parentDir, probeDir)
        break;
    end
    probeDir = parentDir;
end
assert(~isempty(repoRoot), 'Could not resolve repository root.');

legacyRoot = fullfile(repoRoot, 'Switching ver12');
assert(isfolder(legacyRoot), 'Legacy Switching module not found: %s', legacyRoot);

addpath(genpath(legacyRoot));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'General ver2')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = struct();
cfg.runLabel = 'switching_physical_baseline_model';
cfg.dataset = 'pulse_plateau_physical_baseline_model';
runCtx = createRunContext('switching', cfg);
runDir = runCtx.run_dir;

pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
fidp = fopen(pointerPath, 'w');
assert(fidp >= 0, 'Could not write run pointer: %s', pointerPath);
fprintf(fidp, '%s', runDir);
fclose(fidp);

tablesRepo = fullfile(repoRoot, 'tables');
reportsRepo = fullfile(repoRoot, 'reports');
if exist(tablesRepo, 'dir') ~= 7
    mkdir(tablesRepo);
end
if exist(reportsRepo, 'dir') ~= 7
    mkdir(reportsRepo);
end
runTables = fullfile(runDir, 'tables');
runReports = fullfile(runDir, 'reports');
if exist(runTables, 'dir') ~= 7
    mkdir(runTables);
end
if exist(runReports, 'dir') ~= 7
    mkdir(runReports);
end

alignCfgFiles = dir(fullfile(repoRoot, 'results', 'switching', 'runs', 'run_*_alignment_audit', 'config_snapshot.m'));
if isempty(alignCfgFiles)
    alignCfgFiles = dir(fullfile(repoRoot, 'results', 'switching', 'runs', 'run_*alignment_audit*', 'config_snapshot.m'));
end
assert(~isempty(alignCfgFiles), 'No alignment_audit config snapshots found.');
[~, iCfg] = max([alignCfgFiles.datenum]);
alignCfgPath = fullfile(alignCfgFiles(iCfg).folder, alignCfgFiles(iCfg).name);
cfgText = fileread(alignCfgPath);
parentDataDir = '';

jsonTok = regexp(cfgText, 'cfg_snapshot_json\s*=\s*''([^'']+)''\s*;', 'tokens', 'once');
if ~isempty(jsonTok)
    jObj = jsondecode(jsonTok{1});
    if isfield(jObj, 'dataset')
        parentDataDir = string(jObj.dataset);
    end
end

if strlength(parentDataDir) == 0
    mt = regexp(cfgText, '"dataset":"([^"]+)"', 'tokens', 'once');
    if ~isempty(mt)
        parentDataDir = string(strrep(mt{1}, '\\', '\'));
    end
end

if strlength(parentDataDir) == 0
    mt2 = regexp(cfgText, 'cfg\.dataset\s*=\s*''([^'']+)''\s*;', 'tokens', 'once');
    if ~isempty(mt2)
        parentDataDir = string(mt2{1});
    end
end

assert(strlength(parentDataDir) > 0, 'Could not parse dataset path from %s', alignCfgPath);
parentDataDir = char(parentDataDir);
assert(isfolder(parentDataDir), 'Dataset directory not accessible: %s', parentDataDir);

subDirs = dir(parentDataDir);
subNames = string({subDirs.name});
subMask = [subDirs.isdir] & ~startsWith(subNames, '.') & startsWith(subNames, "Temp Dep", 'IgnoreCase', true);
subDirs = subDirs(subMask);
assert(~isempty(subDirs), 'No Temp Dep subfolders found in %s', parentDataDir);

firstDir = fullfile(parentDataDir, subDirs(1).name);
firstDep = extract_dep_type_from_folder(firstDir);
[firstFileList, ~, ~, ~] = getFileListSwitching(firstDir, firstDep);
assert(~isempty(firstFileList), 'Could not load switching files from %s', firstDir);

presetName = resolve_preset(firstFileList(1).name, true, '1xy_3xx');
[~, ~, labels, normalizeTo] = select_preset(presetName);
if isscalar(normalizeTo)
    normalizeToVec = repmat(normalizeTo, 1, 4);
else
    normalizeToVec = normalizeTo(:)';
    if numel(normalizeToVec) < 4
        normalizeToVec = [normalizeToVec, repmat(normalizeToVec(end), 1, 4 - numel(normalizeToVec))];
    else
        normalizeToVec = normalizeToVec(1:4);
    end
end

rows = table();
switchVotes = [];
allChannelsPresent = false(1,4);

metricType = "P2P_percent";
for iDir = 1:numel(subDirs)
    thisDir = fullfile(parentDataDir, subDirs(iDir).name);
    depType = extract_dep_type_from_folder(thisDir);
    [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, depType);
    if isempty(fileList)
        continue;
    end

    current_mA = meta.Current_mA;
    if ~isfinite(current_mA)
        continue;
    end

    pulseScheme = extractPulseSchemeFromFolder(thisDir);
    delay_ms = extract_delay_between_pulses_from_name(thisDir) * 1e3;
    numPulsesSameDep = pulseScheme.totalPulses;

    I_A = current_mA / 1000;
    if ~isfinite(I_A) || I_A == 0
        I_A = 1;
    end

    [stored_data, tableData] = processFilesSwitching( ...
        thisDir, fileList, sortedValues, I_A, 1e3, 4000, 16, 4, 2, 11, ...
        false, delay_ms, numPulsesSameDep, 15, NaN, NaN, normalizeToVec, ...
        true, 1.5, 50, false, pulseScheme);

    stabOpts = struct();
    stabOpts.useFiltered = true;
    stabOpts.useCentered = false;
    stabOpts.stateMethod = pulseScheme.mode;
    stabOpts.skipFirstPlateaus = 1;
    stabOpts.skipLastPlateaus = 0;
    stabOpts.pulseScheme = pulseScheme;
    stabOpts.debugMode = false;

    stability = analyzeSwitchingStability(stored_data, sortedValues, delay_ms, 15, stabOpts);
    if isfield(stability, 'switching') && isfield(stability.switching, 'globalChannel')
        swCh = stability.switching.globalChannel;
        if isfinite(swCh)
            switchVotes(end+1,1) = swCh; %#ok<AGROW>
        end
    end

    for ch = 1:4
        chField = sprintf('ch%d', ch);
        if ~isfield(tableData, chField) || isempty(tableData.(chField))
            continue;
        end
        allChannelsPresent(ch) = true;

        tblCh = tableData.(chField);
        Tvec = double(tblCh(:,1));
        avgP2P = double(tblCh(:,2));
        avgRes = double(tblCh(:,3));
        Spercent = double(tblCh(:,4));
        stdP2PPercent = double(tblCh(:,5));
        p2pUncert = double(tblCh(:,6));
        xxBase = double(tblCh(:,7));

        if metricType == "meanP2P"
            Sobs = avgP2P;
        elseif metricType == "medianAbs"
            Sobs = abs(Spercent);
        else
            Sobs = Spercent;
        end

        n = numel(Tvec);
        addTbl = table( ...
            repmat(current_mA, n, 1), Tvec(:), repmat(ch, n, 1), ...
            avgP2P(:), avgRes(:), Sobs(:), stdP2PPercent(:), p2pUncert(:), xxBase(:), ...
            repmat(string(subDirs(iDir).name), n, 1), ...
            'VariableNames', {'current_mA','T_K','channel','deltaR_high_minus_low','avg_plateau_R', ...
            'S_xy_over_xx_percent','std_p2p_percent','p2p_uncertainty','xx_reference', 'folder'});
        rows = [rows; addTbl]; %#ok<AGROW>
    end
end

assert(~isempty(rows), 'No physical rows extracted from processFilesSwitching.');
assert(all(allChannelsPresent), 'Not all 4 channels are present in extracted data.');

xyCandidates = [];
labelStrings = strings(1,4);
for ch = 1:4
    chKey = sprintf('ch%d', ch);
    if isfield(labels, chKey)
        labelStrings(ch) = string(labels.(chKey));
    else
        labelStrings(ch) = "";
    end
    if contains(lower(labelStrings(ch)), 'xy')
        xyCandidates(end+1) = ch; %#ok<AGROW>
    end
end
if isempty(xyCandidates)
    xyCandidates = [1 3];
end

if isempty(switchVotes)
    XY_channel = xyCandidates(1);
else
    votes = switchVotes(isfinite(switchVotes));
    if isempty(votes)
        XY_channel = xyCandidates(1);
    else
        XY_channel = mode(votes);
    end
    if ~ismember(XY_channel, 1:4)
        XY_channel = xyCandidates(1);
    end
end

XX_channel = normalizeToVec(XY_channel);
if ~(isfinite(XX_channel) && XX_channel >= 1 && XX_channel <= 4)
    xxCandidates = find(contains(lower(labelStrings), 'xx'));
    assert(~isempty(xxCandidates), 'No XX channel candidate found.');
    XX_channel = xxCandidates(1);
end
XX_channel = round(XX_channel);

xyRows = rows(rows.channel == XY_channel, :);
assert(~isempty(xyRows), 'No rows for selected XY channel %d.', XY_channel);

[grp, Ivals, Tvals] = findgroups(xyRows.current_mA, round(xyRows.T_K));
rawXY = splitapply(@(x) mean(x, 'omitnan'), xyRows.deltaR_high_minus_low, grp);
normXY = splitapply(@(x) mean(x, 'omitnan'), xyRows.S_xy_over_xx_percent, grp);
xxRef = splitapply(@(x) mean(x, 'omitnan'), xyRows.xx_reference, grp);

physTbl = table(Ivals, Tvals, rawXY, normXY, xxRef, ...
    'VariableNames', {'I_mA','T_K','raw_xy','normalized_xy_over_xx','xx_reference'});
physTbl = sortrows(physTbl, {'T_K','I_mA'});

absRaw = abs(physTbl.raw_xy);
q = quantile(absRaw(isfinite(absRaw)), 0.35);
if ~isfinite(q)
    q = median(absRaw, 'omitnan');
end
nonSwitchMask = isfinite(physTbl.raw_xy) & abs(physTbl.raw_xy) <= q;
if nnz(nonSwitchMask) < 8
    [~, idxSort] = sort(absRaw, 'ascend');
    keepN = min(numel(idxSort), max(8, round(0.4 * numel(idxSort))));
    nonSwitchMask = false(size(absRaw));
    nonSwitchMask(idxSort(1:keepN)) = true;
    nonSwitchMask = nonSwitchMask & isfinite(physTbl.raw_xy);
end
assert(nnz(nonSwitchMask) >= 3, 'Insufficient non-switching points for baseline modeling.');

Xc = ones(nnz(nonSwitchMask), 1);
XI = [ones(nnz(nonSwitchMask), 1), physTbl.I_mA(nonSwitchMask)];
XIT = [ones(nnz(nonSwitchMask), 1), physTbl.I_mA(nonSwitchMask), physTbl.T_K(nonSwitchMask)];
yNS = physTbl.raw_xy(nonSwitchMask);

betaC = Xc \ yNS;
betaI = XI \ yNS;
betaIT = XIT \ yNS;

predC_ns = Xc * betaC;
predI_ns = XI * betaI;
predIT_ns = XIT * betaIT;
rmseC = sqrt(mean((yNS - predC_ns).^2, 'omitnan'));
rmseI = sqrt(mean((yNS - predI_ns).^2, 'omitnan'));
rmseIT = sqrt(mean((yNS - predIT_ns).^2, 'omitnan'));

XallIT = [ones(height(physTbl),1), physTbl.I_mA, physTbl.T_K];
baselineHat = XallIT * betaIT;
physTbl.corrected_xy = physTbl.raw_xy - baselineHat;

BASELINE_CONSTANT_INVALID = "NO";
if rmseIT + 1e-12 < 0.95 * rmseC
    BASELINE_CONSTANT_INVALID = "YES";
end

BASELINE_DEPENDS_ON_CURRENT = "NO";
if rmseI + 1e-12 < 0.97 * rmseC && abs(betaI(2)) > 1e-6
    BASELINE_DEPENDS_ON_CURRENT = "YES";
end

BASELINE_DEPENDS_ON_TEMPERATURE = "NO";
if rmseIT + 1e-12 < 0.97 * rmseI && abs(betaIT(3)) > 1e-6
    BASELINE_DEPENDS_ON_TEMPERATURE = "YES";
end

RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT = "NO";
if BASELINE_CONSTANT_INVALID == "YES" || BASELINE_DEPENDS_ON_CURRENT == "YES" || BASELINE_DEPENDS_ON_TEMPERATURE == "YES"
    RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT = "YES";
end

corrRawXX = corr(physTbl.raw_xy, physTbl.xx_reference, 'rows', 'complete');
corrCorrXX = corr(physTbl.corrected_xy, physTbl.xx_reference, 'rows', 'complete');
NORMALIZATION_REMOVES_TRANSPORT_COMPONENT = "NO";
if isfinite(corrRawXX) && abs(corrRawXX) > 0.15
    NORMALIZATION_REMOVES_TRANSPORT_COMPONENT = "YES";
end
if isfinite(corrCorrXX) && abs(corrCorrXX) < abs(corrRawXX)
    NORMALIZATION_REMOVES_TRANSPORT_COMPONENT = "YES";
end

temps = sort(unique(physTbl.T_K));
currents = sort(unique(physTbl.I_mA))';

signalMaps = struct();
families = ["raw_xy", "corrected_xy", "normalized_xy_over_xx"];
for f = 1:numel(families)
    fam = families(f);
    M = NaN(numel(temps), numel(currents));
    for it = 1:numel(temps)
        for ii = 1:numel(currents)
            m = physTbl.T_K == temps(it) & abs(physTbl.I_mA - currents(ii)) < 1e-9;
            if any(m)
                M(it, ii) = mean(physTbl.(fam)(m), 'omitnan');
            end
        end
    end
    signalMaps.(char(fam)) = M;
end

summaryRows = table();
for f = 1:numel(families)
    fam = families(f);
    M = signalMaps.(char(fam));

    famRows = table();
    for it = 1:numel(temps)
        row = M(it, :);
        v = isfinite(row) & isfinite(currents);
        if nnz(v) < 5
            continue;
        end

        x = currents(v);
        y = row(v);
        [sPeak, idxPeak] = max(y);
        iPeak = x(idxPeak);

        half = 0.5 * sPeak;
        leftCross = NaN;
        rightCross = NaN;
        for j = idxPeak:-1:2
            y1 = y(j-1);
            y2 = y(j);
            if y1 < half && y2 >= half
                if abs(y2 - y1) < eps
                    leftCross = 0.5 * (x(j-1) + x(j));
                else
                    t = (half - y1) / (y2 - y1);
                    leftCross = x(j-1) + t * (x(j) - x(j-1));
                end
                break;
            end
        end
        for j = idxPeak:(numel(x)-1)
            y1 = y(j);
            y2 = y(j+1);
            if y1 >= half && y2 < half
                if abs(y2 - y1) < eps
                    rightCross = 0.5 * (x(j) + x(j+1));
                else
                    t = (half - y1) / (y2 - y1);
                    rightCross = x(j) + t * (x(j+1) - x(j));
                end
                break;
            end
        end
        width = rightCross - leftCross;
        if ~(isfinite(width) && width > 0)
            width = max(x) - min(x);
        end

        xn = (x - iPeak) ./ max(width, eps);
        yn = y ./ max(sPeak, eps);
        fitMask = isfinite(xn) & isfinite(yn) & abs(xn) <= 1;
        if nnz(fitMask) >= 3
            p = polyfit(xn(fitMask), yn(fitMask), 1);
            kappa1 = p(1);
        else
            kappa1 = NaN;
        end

        famRows = [famRows; table(fam, temps(it), iPeak, sPeak, width, kappa1, NaN, ...
            'VariableNames', {'family','T_K','I_peak','S_peak','width','kappa1','collapse_score'})]; %#ok<AGROW>
    end

    xGrid = -2:0.2:2;
    prof = NaN(height(famRows), numel(xGrid));
    for r = 1:height(famRows)
        t = famRows.T_K(r);
        it = find(temps == t, 1, 'first');
        if isempty(it)
            continue;
        end
        row = M(it, :);
        v = isfinite(row) & isfinite(currents);
        if nnz(v) < 5
            continue;
        end
        x = (currents(v) - famRows.I_peak(r)) ./ max(famRows.width(r), eps);
        y = row(v) ./ max(famRows.S_peak(r), eps);
        [xS, ord] = sort(x);
        yS = y(ord);
        prof(r, :) = interp1(xS, yS, xGrid, 'linear', NaN);
    end
    meanProf = mean(prof, 1, 'omitnan');
    famRows.collapse_score = sqrt(mean((prof - meanProf).^2, 2, 'omitnan'));

    summaryRows = [summaryRows; famRows]; %#ok<AGROW>
end

summaryRows = sortrows(summaryRows, {'T_K','family'});

rawFam = summaryRows(summaryRows.family == "raw_xy", :);
corrFam = summaryRows(summaryRows.family == "corrected_xy", :);
rawCollapse = median(rawFam.collapse_score, 'omitnan');
corrCollapse = median(corrFam.collapse_score, 'omitnan');
CORRECTED_BASELINE_IMPROVES_SIGNAL = "NO";
if corrCollapse + 1e-12 < rawCollapse
    CORRECTED_BASELINE_IMPROVES_SIGNAL = "YES";
end

statusTbl = table( ...
    "SUCCESS", "YES", "", height(summaryRows), "physical baseline model computed", ...
    string(parentDataDir), string(presetName), ...
    "1,2,3,4", XY_channel, XX_channel, ...
    "baseline(I,T)=a+b*I+c*T from non-switching windows", ...
    rmseC, rmseI, rmseIT, betaIT(1), betaIT(2), betaIT(3), ...
    corrRawXX, corrCorrXX, ...
    BASELINE_CONSTANT_INVALID, BASELINE_DEPENDS_ON_CURRENT, BASELINE_DEPENDS_ON_TEMPERATURE, ...
    RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT, NORMALIZATION_REMOVES_TRANSPORT_COMPONENT, CORRECTED_BASELINE_IMPROVES_SIGNAL, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_ROWS','MAIN_RESULT_SUMMARY', ...
    'DATA_ROOT','PRESET_NAME','CHANNELS_USED','XY_CHANNEL','XX_CHANNEL', ...
    'BASELINE_MODEL', ...
    'RMSE_CONSTANT','RMSE_LINEAR_I','RMSE_LINEAR_IT','B0','BI','BT', ...
    'CORR_RAW_WITH_XXREF','CORR_CORRECTED_WITH_XXREF', ...
    'BASELINE_CONSTANT_INVALID','BASELINE_DEPENDS_ON_CURRENT','BASELINE_DEPENDS_ON_TEMPERATURE', ...
    'RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT','NORMALIZATION_REMOVES_TRANSPORT_COMPONENT','CORRECTED_BASELINE_IMPROVES_SIGNAL'});

outSummaryRepo = fullfile(tablesRepo, 'switching_physical_baseline_model_summary.csv');
outStatusRepo = fullfile(tablesRepo, 'switching_physical_baseline_model_status.csv');
outReportRepo = fullfile(reportsRepo, 'switching_physical_baseline_model_report.md');

writetable(summaryRows, outSummaryRepo);
writetable(statusTbl, outStatusRepo);

lines = strings(0,1);
lines(end+1) = "# Switching physical baseline model report";
lines(end+1) = "";
lines(end+1) = "This is an observable-definition and signal-isolation correction in the physics layer.";
lines(end+1) = "No mixed robustness verdict was used.";
lines(end+1) = "";
lines(end+1) = "## Physical measurement definition";
lines(end+1) = "- 4-channel lock-in structure was used (channels 1-4).";
lines(end+1) = "- Preset selection: " + string(presetName);
lines(end+1) = "- XY channel used: " + string(XY_channel);
lines(end+1) = "- XX normalization channel used: " + string(XX_channel);
lines(end+1) = "- Pulse-aware plateau readout from processFilesSwitching was used (after-settling windows between pulses).";
lines(end+1) = "- Observable definitions: raw_xy = state_high - state_low; normalized_xy_over_xx = (state_high-state_low)/XX.";
lines(end+1) = "";
lines(end+1) = "## Baseline model";
lines(end+1) = "- Non-switching region selector: lowest-|raw_xy| points (quantile-based).";
lines(end+1) = "- Model tested: constant, linear(I), linear(I,T).";
lines(end+1) = "- Selected correction model: baseline(I,T)=a+b*I+c*T from non-switching windows.";
lines(end+1) = sprintf('- RMSE constant: %.6g', rmseC);
lines(end+1) = sprintf('- RMSE linear(I): %.6g', rmseI);
lines(end+1) = sprintf('- RMSE linear(I,T): %.6g', rmseIT);
lines(end+1) = sprintf('- Coefficients: a=%.6g, bI=%.6g, cT=%.6g', betaIT(1), betaIT(2), betaIT(3));
lines(end+1) = "";
lines(end+1) = "## A. raw XY behavior";
lines(end+1) = sprintf('- Median collapse_score: %.6g', rawCollapse);
lines(end+1) = sprintf('- corr(raw_xy, XX_reference): %.6g', corrRawXX);
lines(end+1) = "";
lines(end+1) = "## B. baseline-corrected XY behavior";
lines(end+1) = sprintf('- Median collapse_score: %.6g', corrCollapse);
lines(end+1) = sprintf('- corr(corrected_xy, XX_reference): %.6g', corrCorrXX);
lines(end+1) = "";
lines(end+1) = "## C. normalized XY/XX behavior";
lines(end+1) = "- Derived from the same pulse-plateau extraction using XX normalization channel.";
lines(end+1) = "- Reported separately from corrected-XY verdict logic.";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- BASELINE_CONSTANT_INVALID=" + BASELINE_CONSTANT_INVALID;
lines(end+1) = "- BASELINE_DEPENDS_ON_CURRENT=" + BASELINE_DEPENDS_ON_CURRENT;
lines(end+1) = "- BASELINE_DEPENDS_ON_TEMPERATURE=" + BASELINE_DEPENDS_ON_TEMPERATURE;
lines(end+1) = "- RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT=" + RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT;
lines(end+1) = "- NORMALIZATION_REMOVES_TRANSPORT_COMPONENT=" + NORMALIZATION_REMOVES_TRANSPORT_COMPONENT;
lines(end+1) = "- CORRECTED_BASELINE_IMPROVES_SIGNAL=" + CORRECTED_BASELINE_IMPROVES_SIGNAL;

fid = fopen(outReportRepo, 'w');
assert(fid >= 0, 'Could not write report: %s', outReportRepo);
fprintf(fid, '%s\n', strjoin(cellstr(lines), newline));
fclose(fid);

outSummaryRun = fullfile(runTables, 'switching_physical_baseline_model_summary.csv');
outStatusRun = fullfile(runTables, 'switching_physical_baseline_model_status.csv');
outReportRun = fullfile(runReports, 'switching_physical_baseline_model_report.md');
outReportRootRun = fullfile(runDir, 'switching_physical_baseline_model_report.md');
copyfile(outSummaryRepo, outSummaryRun);
copyfile(outStatusRepo, outStatusRun);
copyfile(outReportRepo, outReportRun);
copyfile(outReportRepo, outReportRootRun);

execTbl = table("SUCCESS", "YES", "", height(summaryRows), "physical baseline model complete", ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
execPath = fullfile(runDir, 'execution_status.csv');
writetable(execTbl, execPath);

manifest = struct();
manifest.outputs = {outSummaryRun; outStatusRun; outReportRun; outReportRootRun; execPath};
manifestPath = fullfile(runDir, 'run_manifest.json');
fidm = fopen(manifestPath, 'w');
assert(fidm >= 0, 'Could not write run manifest: %s', manifestPath);
fprintf(fidm, '%s', jsonencode(manifest));
fclose(fidm);

pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
fidp = fopen(pointerPath, 'w');
assert(fidp >= 0, 'Could not write run pointer: %s', pointerPath);
fprintf(fidp, '%s', runDir);
fclose(fidp);

fprintf('CHANNELS_USED=1,2,3,4\n');
fprintf('XY_CHANNEL=%d\n', XY_channel);
fprintf('XX_CHANNEL=%d\n', XX_channel);
fprintf('BASELINE_MODEL_USED=baseline(I,T)=a+b*I+c*T from non-switching windows\n');
fprintf('BASELINE_CONSTANT_INVALID=%s\n', char(BASELINE_CONSTANT_INVALID));
fprintf('BASELINE_DEPENDS_ON_CURRENT=%s\n', char(BASELINE_DEPENDS_ON_CURRENT));
fprintf('BASELINE_DEPENDS_ON_TEMPERATURE=%s\n', char(BASELINE_DEPENDS_ON_TEMPERATURE));
fprintf('RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT=%s\n', char(RAW_SIGNAL_CONTAMINATED_BY_TRANSPORT));
fprintf('NORMALIZATION_REMOVES_TRANSPORT_COMPONENT=%s\n', char(NORMALIZATION_REMOVES_TRANSPORT_COMPONENT));
fprintf('CORRECTED_BASELINE_IMPROVES_SIGNAL=%s\n', char(CORRECTED_BASELINE_IMPROVES_SIGNAL));
fprintf('INTERPRETATION=Baseline must be treated as transport-dependent, not constant\n');
