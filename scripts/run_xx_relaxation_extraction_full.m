function run_xx_relaxation_extraction_full(profile)
% Build a full XX event-level dataset using validated audit logic.
% Read-only with respect to pipeline/detection logic; writes only artifacts.
%
% profile (optional):
%   omitted or "legacy_config3" - historical Config3 23 binding (misassigned for XX science).
%   "config2" - canonical XX-stable Config2 branch; all .dat files per current folder;
%                writes tables/reports with _config2 suffix (does not touch legacy names).

if nargin < 1 || isempty(profile)
    profile = "legacy_config3";
else
    profile = string(profile);
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
selectedChannel = 3; % PIPELINE_SELECTED_CHANNEL fixed by request.

if profile == "config2"
    cfg = xx_relaxation_config2_sources();
    useAllFiles = true;
    targetFilesPerConfig = inf;
    minTotalFiles = 1;
    outSuffix = "_config2";
    sourceBranchLabel = "Config2_Amp_Temp_Dep_all";
else
    cfg = getConfigSourcesLegacy();
    useAllFiles = false;
    targetFilesPerConfig = 5; % Prefer 6-10 total across configs.
    minTotalFiles = 5;
    outSuffix = "";
    sourceBranchLabel = "Config3_23_Amp_Temp_Dep_all_misassigned_for_XX";
end

allEvents = table();
sampledFiles = struct('config_id', {}, 'path', {}, 'name', {}, 'temperature', {});
for c = 1:numel(cfg)
    sourceDir = fullfile(cfg(c).baseDir, cfg(c).tempDepFolder);
    if exist(sourceDir, 'dir') ~= 7
        warning('xx_relax_full:MissingRawDir', 'Missing source directory: %s', sourceDir);
        continue;
    end

    fileRows = collectRawFilesSingleFolder(sourceDir);
    if isempty(fileRows)
        continue;
    end

    if useAllFiles
        chosenRows = fileRows;
    else
        chosenRows = chooseFilesSpanningTemperatures(fileRows, targetFilesPerConfig);
    end
    for i = 1:numel(chosenRows)
        rowsI = extractEventsForFile(chosenRows(i), selectedChannel);
        if isempty(rowsI)
            continue;
        end

        rowsI.config_id = repmat(cfg(c).config_id, height(rowsI), 1);
        rowsI.source_folder = repmat(string(cfg(c).tempDepFolder), height(rowsI), 1);
        rowsI.relaxation_detected = isfinite(rowsI.tau_relax);
        allEvents = [allEvents; rowsI]; %#ok<AGROW>

        sampledFiles(end + 1).config_id = cfg(c).config_id; %#ok<AGROW>
        sampledFiles(end).path = chosenRows(i).path;
        sampledFiles(end).name = chosenRows(i).name;
        sampledFiles(end).temperature = chosenRows(i).temperature;
    end
end

if isempty(allEvents)
    error('xx_relax_full:NoEvents', 'No events extracted from configured raw data sources.');
end

sampledFilesTbl = struct2table(sampledFiles);
sampledFilesTbl = unique(sampledFilesTbl(:, {'config_id', 'name', 'temperature'}));
if height(sampledFilesTbl) < minTotalFiles
    warning('xx_relax_full:FewFiles', 'Only %d files sampled (<%d).', height(sampledFilesTbl), minTotalFiles);
end

eventOut = fullfile(repoRoot, "tables", "xx_relaxation_event_level_full" + outSuffix + ".csv");
aggOut = fullfile(repoRoot, "tables", "xx_relaxation_aggregated_by_state" + outSuffix + ".csv");
reportOut = fullfile(repoRoot, "reports", "xx_relaxation_extraction_full" + outSuffix + ".md");

eventOutTbl = allEvents(:, {'file_id','config_id','temperature','pulse_index','target_state', ...
    'V_plateau','DeltaV','tau_relax','plateau_detected','relaxation_detected'});
writetable(eventOutTbl, eventOut);

aggTbl = aggregateByConfigTemperatureState(allEvents);
writetable(aggTbl, aggOut);

writeReport(reportOut, selectedChannel, sampledFilesTbl, allEvents, aggTbl, profile, outSuffix, sourceBranchLabel);

fprintf('Wrote %s (%d rows)\n', eventOut, height(eventOutTbl));
fprintf('Wrote %s (%d rows)\n', aggOut, height(aggTbl));
fprintf('Wrote %s\n', reportOut);
end

function cfg = getConfigSourcesLegacy()
cfg = struct([]);

cfg(1).config_id = "config3_30mA"; %#ok<AGROW>
cfg(1).baseDir = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all";
cfg(1).tempDepFolder = "Temp Dep 30mA 10ms 0T 15sec 10pulses 12";

cfg(2).config_id = "config3_25mA"; %#ok<AGROW>
cfg(2).baseDir = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all";
cfg(2).tempDepFolder = "Temp Dep 25mA 10ms 0T 15sec 10pulses 16";
end

function rows = collectRawFilesSingleFolder(tempDepDir)
rows = struct('path', {}, 'folder', {}, 'name', {}, 'temperature', {});
files = dir(fullfile(tempDepDir, "*.dat"));
for f = 1:numel(files)
    fname = string(files(f).name);
    tK = parseTemperatureFromFilename(fname);
    if isnan(tK)
        continue;
    end
    rows(end+1).path = fullfile(string(files(f).folder), fname); %#ok<AGROW>
    rows(end).folder = string(files(f).folder);
    rows(end).name = fname;
    rows(end).temperature = tK;
end
end

function tK = parseTemperatureFromFilename(fname)
tok = regexp(fname, '_T([0-9]+(?:\.[0-9]+)?)_', 'tokens', 'once');
if isempty(tok)
    tK = NaN;
else
    tK = str2double(tok{1});
end
end

function chosen = chooseFilesSpanningTemperatures(rows, nTake)
if isempty(rows)
    chosen = rows;
    return;
end
temps = [rows.temperature];
uTemps = sort(unique(temps(:)));
n = min(nTake, numel(uTemps));
idxTemp = unique(round(linspace(1, numel(uTemps), n)));
selectedTemps = uTemps(idxTemp);

chosen = struct('path', {}, 'folder', {}, 'name', {}, 'temperature', {});
for i = 1:numel(selectedTemps)
    t = selectedTemps(i);
    idx = find([rows.temperature] == t, 1, 'first');
    if isempty(idx)
        continue;
    end
    chosen(end + 1) = rows(idx); %#ok<AGROW>
end
end

function outTbl = extractEventsForFile(fileRow, selectedChannel)
data = readtable(fileRow.path, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
tMs = data{:, 'Time (ms)'};
tSec = (tMs - tMs(1)) ./ 1000;
if selectedChannel == 2
    v = data{:, 'LI2_X (V)'};
else
    v = data{:, 'LI3_X (V)'};
end

dt = median(diff(tSec), 'omitnan');
if ~isfinite(dt) || dt <= 0
    dt = 0.1;
end
knownSpacingSec = 15;
absDvDt = abs(gradient(v, dt));

q = quantile(absDvDt, [0.90, 0.99]);
thr = max(q(2), q(1) + 3 * mad(absDvDt, 1));
minDist = max(round((0.6 * knownSpacingSec) / dt), 5);
[~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr, 'MinPeakDistance', minDist);
if numel(pulseIdx) < 4
    thr2 = quantile(absDvDt, 0.995);
    [~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr2, 'MinPeakDistance', max(round((0.4 * knownSpacingSec) / dt), 3));
end

if isempty(pulseIdx)
    outTbl = table();
    return;
end

meanPeriod = knownSpacingSec;
if numel(pulseIdx) > 1
    meanPeriod = median(diff(tSec(pulseIdx)), 'omitnan');
end

W = max(round(0.12 * meanPeriod / dt), 8);
stableN = max(round(W / 3), 5);
slopeFloor = median(absDvDt, 'omitnan') + 1.5 * mad(absDvDt, 1);
rollStd = movingStd(v, W);
stdFloor = median(rollStd, 'omitnan') + 2.0 * mad(rollStd, 1);
if ~isfinite(stdFloor) || stdFloor <= 0
    stdFloor = std(v, 'omitnan') * 0.1;
end

fileId = repmat(string(fileRow.name), 0, 1);
temperature = zeros(0, 1);
pulseIndex = zeros(0, 1);
targetState = strings(0, 1);
VPlateau = zeros(0, 1);
deltaV = zeros(0, 1);
tauRelax = zeros(0, 1);
plateauDetected = false(0, 1);

for p = 1:numel(pulseIdx)
    thisPeak = pulseIdx(p);
    nextPulse = numel(v);
    if p < numel(pulseIdx)
        nextPulse = pulseIdx(p + 1) - 1;
    end

    pulseEndIdx = findPulseEnd(absDvDt, thisPeak, slopeFloor, nextPulse);
    relaxStartIdx = findRelaxationStart(absDvDt, pulseEndIdx, slopeFloor, nextPulse);
    [plateauStart, ok] = findStablePlateauStart(v, absDvDt, relaxStartIdx, nextPulse, W, stableN, slopeFloor, stdFloor);

    vPlateau = NaN;
    dV = NaN;
    tau = NaN;
    if ok
        plateauWindow = v(plateauStart:nextPulse);
        vPlateau = mean(plateauWindow, 'omitnan');
        dV = abs(v(relaxStartIdx) - vPlateau);
        tau = computeTauRelax(tSec, v, relaxStartIdx, nextPulse, vPlateau, stdFloor, stableN);
    end

    fileId(end+1, 1) = string(fileRow.name); %#ok<AGROW>
    temperature(end+1, 1) = fileRow.temperature; %#ok<AGROW>
    pulseIndex(end+1, 1) = p; %#ok<AGROW>
    targetState(end+1, 1) = stateFromIndex(p); %#ok<AGROW>
    VPlateau(end+1, 1) = vPlateau; %#ok<AGROW>
    deltaV(end+1, 1) = dV; %#ok<AGROW>
    tauRelax(end+1, 1) = tau; %#ok<AGROW>
    plateauDetected(end+1, 1) = ok; %#ok<AGROW>
end

outTbl = table(fileId, temperature, pulseIndex, targetState, VPlateau, deltaV, tauRelax, plateauDetected, ...
    'VariableNames', {'file_id','temperature','pulse_index','target_state','V_plateau','DeltaV','tau_relax','plateau_detected'});
end

function idx = findPulseEnd(absDvDt, peakIdx, slopeFloor, maxIdx)
idx = peakIdx;
while idx < maxIdx
    if absDvDt(idx) < 1.2 * slopeFloor
        break;
    end
    idx = idx + 1;
end
idx = min(idx, maxIdx);
end

function idx = findRelaxationStart(absDvDt, pulseEndIdx, slopeFloor, maxIdx)
idx = pulseEndIdx;
need = 4;
while idx + need < maxIdx
    if all(absDvDt(idx:(idx + need - 1)) < 1.1 * slopeFloor)
        break;
    end
    idx = idx + 1;
end
idx = min(idx, maxIdx);
end

function [plateauStart, ok] = findStablePlateauStart(v, absDvDt, startIdx, maxIdx, W, stableN, epsSlope, epsStd)
plateauStart = NaN;
ok = false;
if startIdx + W + stableN > maxIdx
    return;
end
stable = false(maxIdx, 1);
for k = startIdx:(maxIdx - W + 1)
    seg = v(k:(k + W - 1));
    slopeVal = mean(absDvDt(k:(k + W - 1)), 'omitnan');
    stable(k) = slopeVal < epsSlope && std(seg, 'omitnan') < epsStd;
end

run = 0;
for k = startIdx:(maxIdx - W + 1)
    if stable(k)
        run = run + 1;
        if run >= stableN
            plateauStart = k - stableN + 1;
            ok = true;
            return;
        end
    else
        run = 0;
    end
end
end

function tau = computeTauRelax(tSec, v, startIdx, stopIdx, vPlateau, epsStd, persistN)
tau = NaN;
if ~isfinite(vPlateau)
    return;
end
threshold = max(2 * epsStd, 1e-12);
within = abs(v(startIdx:stopIdx) - vPlateau) < threshold;
run = 0;
for i = 1:numel(within)
    if within(i)
        run = run + 1;
        if run >= persistN
            hit = startIdx + i - persistN;
            tau = tSec(hit) - tSec(startIdx);
            return;
        end
    else
        run = 0;
    end
end
end

function s = stateFromIndex(pulseIdx)
if mod(pulseIdx, 2) == 1
    s = "A";
else
    s = "B";
end
end

function x = movingStd(v, W)
x = NaN(size(v));
for i = W:numel(v)
    x(i) = std(v((i - W + 1):i), 'omitnan');
end
end

function aggTbl = aggregateByConfigTemperatureState(events)
eventsUsed = events(events.plateau_detected, :);
g = findgroups(eventsUsed.config_id, eventsUsed.temperature);
nGroups = max(g);

config_id = strings(nGroups, 1);
temperature = zeros(nGroups, 1);
mean_R_A = NaN(nGroups, 1);
std_R_A = NaN(nGroups, 1);
mean_R_B = NaN(nGroups, 1);
std_R_B = NaN(nGroups, 1);
mean_DeltaV_A = NaN(nGroups, 1);
mean_DeltaV_B = NaN(nGroups, 1);
mean_tau_A = NaN(nGroups, 1);
mean_tau_B = NaN(nGroups, 1);
N_A = zeros(nGroups, 1);
N_B = zeros(nGroups, 1);

for gi = 1:nGroups
    mask = (g == gi);
    block = eventsUsed(mask, :);
    config_id(gi) = block.config_id(1);
    temperature(gi) = block.temperature(1);

    a = block(block.target_state == "A", :);
    b = block(block.target_state == "B", :);

    mean_R_A(gi) = mean(a.V_plateau, 'omitnan');
    std_R_A(gi) = std(a.V_plateau, 'omitnan');
    mean_R_B(gi) = mean(b.V_plateau, 'omitnan');
    std_R_B(gi) = std(b.V_plateau, 'omitnan');

    mean_DeltaV_A(gi) = mean(a.DeltaV, 'omitnan');
    mean_DeltaV_B(gi) = mean(b.DeltaV, 'omitnan');
    mean_tau_A(gi) = mean(a.tau_relax, 'omitnan');
    mean_tau_B(gi) = mean(b.tau_relax, 'omitnan');
    N_A(gi) = height(a);
    N_B(gi) = height(b);
end

aggTbl = table(config_id, temperature, mean_R_A, std_R_A, mean_R_B, std_R_B, ...
    mean_DeltaV_A, mean_DeltaV_B, mean_tau_A, mean_tau_B, N_A, N_B);
aggTbl = sortrows(aggTbl, {'config_id', 'temperature'});
end

function writeReport(reportPath, selectedChannel, sampledFilesTbl, allEvents, aggTbl, profile, outSuffix, sourceBranchLabel)
nFiles = height(sampledFilesTbl);
nEvents = height(allEvents);
uCfg = unique(allEvents.config_id);
uT = unique(allEvents.temperature);

missingPlateau = sum(~allEvents.plateau_detected);
missingRelax = sum(allEvents.plateau_detected & ~allEvents.relaxation_detected);

aCount = sum(allEvents.target_state == "A");
bCount = sum(allEvents.target_state == "B");

[gCfg, cfgVals] = findgroups(allEvents.config_id);
cfgCounts = splitapply(@numel, allEvents.file_id, gCfg);

[gTemp, tempVals] = findgroups(allEvents.temperature);
tempCounts = splitapply(@numel, allEvents.file_id, gTemp);

[gCfgTemp, cfgTempVals, tempCfgVals] = findgroups(allEvents.config_id, allEvents.temperature);
cfgTempCounts = splitapply(@numel, allEvents.file_id, gCfgTemp);

fid = fopen(reportPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# XX Relaxation Extraction Full\n\n');
fprintf(fid, '## Scope\n');
fprintf(fid, '- Execution profile: `%s`\n', char(profile));
fprintf(fid, '- Source branch label: `%s`\n', char(sourceBranchLabel));
fprintf(fid, '- Source: raw XX Temp Dep files across configured current folders.\n');
fprintf(fid, '- Channel policy: `PIPELINE_SELECTED_CHANNEL = %d` only.\n', selectedChannel);
fprintf(fid, '- Detection logic: exact reuse of prior validated audit implementation.\n\n');

if profile == "config2"
    reqTags = ["config2_25mA", "config2_30mA", "config2_35mA"];
    present = false(size(reqTags));
    for ti = 1:numel(reqTags)
        present(ti) = any(allEvents.config_id == reqTags(ti));
    end
    fprintf(fid, '## Required current coverage (25 / 30 / 35 mA)\n');
    fprintf(fid, '- config2_25mA present in extraction: %s\n', ternaryYesNo(present(1)));
    fprintf(fid, '- config2_30mA present in extraction: %s\n', ternaryYesNo(present(2)));
    fprintf(fid, '- config2_35mA present in extraction: %s\n', ternaryYesNo(present(3)));
    fprintf(fid, '- All three required currents entered extraction: %s\n\n', ternaryYesNo(all(present)));
end

fprintf(fid, '## Coverage\n');
fprintf(fid, '- Files processed: %d\n', nFiles);
fprintf(fid, '- Events extracted: %d\n', nEvents);
fprintf(fid, '- Configs represented: %d (%s)\n', numel(uCfg), strjoin(cellstr(uCfg), ', '));
fprintf(fid, '- Temperatures represented: %d\n', numel(uT));
fprintf(fid, '- State counts: A=%d, B=%d\n\n', aCount, bCount);

fprintf(fid, '### Events by config\n');
for i = 1:numel(cfgVals)
    fprintf(fid, '- %s: %d events\n', string(cfgVals(i)), cfgCounts(i));
end
fprintf(fid, '\n');

if height(sampledFilesTbl) > 0 && ismember('config_id', sampledFilesTbl.Properties.VariableNames)
    fprintf(fid, '### Files by config\n');
    [gSf, cfgSf] = findgroups(sampledFilesTbl.config_id);
    nPer = splitapply(@numel, sampledFilesTbl.name, gSf);
    for i = 1:numel(cfgSf)
        fprintf(fid, '- %s: %d files\n', string(cfgSf(i)), nPer(i));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '### Events by temperature\n');
for i = 1:numel(tempVals)
    fprintf(fid, '- %.2f K: %d events\n', tempVals(i), tempCounts(i));
end
fprintf(fid, '\n');

fprintf(fid, '### Events by config and temperature\n');
for i = 1:numel(cfgTempCounts)
    fprintf(fid, '- %s @ %.2f K: %d events\n', string(cfgTempVals(i)), tempCfgVals(i), cfgTempCounts(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Data quality summary\n');
fprintf(fid, '- Missing plateau detections: %d / %d (%.2f%%)\n', missingPlateau, nEvents, 100 * missingPlateau / max(nEvents, 1));
fprintf(fid, '- Plateau found but relaxation unresolved (noisy/ambiguous): %d / %d (%.2f%%)\n', ...
    missingRelax, nEvents, 100 * missingRelax / max(nEvents, 1));
fprintf(fid, '- Aggregation includes only events with `plateau_detected = true` and remains state-separated (A/B).\n\n');

fprintf(fid, '## Output artifacts\n');
fprintf(fid, '- `tables/xx_relaxation_event_level_full%s.csv`\n', char(outSuffix));
fprintf(fid, '- `tables/xx_relaxation_aggregated_by_state%s.csv`\n', char(outSuffix));
fprintf(fid, '- `reports/xx_relaxation_extraction_full%s.md`\n\n', char(outSuffix));

fprintf(fid, '## Aggregation notes\n');
fprintf(fid, '- Grouping key: `(config_id, temperature)`.\n');
fprintf(fid, '- `mean_R_*`/`std_R_*` are computed from `V_plateau` per requested state.\n');
fprintf(fid, '- No A/B merging and no interpretation layers (kappa/phi).\n');
fprintf(fid, '- Aggregated rows written: %d\n', height(aggTbl));
end

function s = ternaryYesNo(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end
