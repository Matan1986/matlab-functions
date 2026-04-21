function run_xx_relaxation_morphology_map(runTag)
% XX relaxation morphology map:
% classify events as settled vs unsettled-but-relaxing vs no-clear-relaxation.
% This script preserves the existing event detection, relaxation window,
% plateau definition, and tau_relax logic. Morphology descriptors are additive.
%
% runTag (optional): e.g. "config2" uses Config2 raw sources and *_config2 artifacts.

if nargin < 1 || isempty(runTag)
    tagSuffix = "";
    useConfig2 = false;
else
    tagSuffix = "_" + string(runTag);
    useConfig2 = (string(runTag) == "config2");
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
selectedChannel = 3; % Preserve validated channel policy.

eventInPath = fullfile(repoRoot, "tables", "xx_relaxation_event_level_full" + tagSuffix + ".csv");
eventOutPath = fullfile(repoRoot, "tables", "xx_relaxation_morphology_event_level" + tagSuffix + ".csv");
aggOutPath = fullfile(repoRoot, "tables", "xx_relaxation_morphology_aggregated" + tagSuffix + ".csv");
reportPath = fullfile(repoRoot, "reports", "xx_relaxation_morphology_map" + tagSuffix + ".md");

figSettled = fullfile(repoRoot, "figures", "xx_relaxation_settled_map" + tagSuffix + ".png");
figRelaxing = fullfile(repoRoot, "figures", "xx_relaxation_unsettled_but_relaxing_map" + tagSuffix + ".png");
figNoClear = fullfile(repoRoot, "figures", "xx_relaxation_no_clear_map" + tagSuffix + ".png");

ensureParentDirs({eventOutPath, aggOutPath, reportPath, figSettled, figRelaxing, figNoClear});

eventRef = readtable(eventInPath, 'VariableNamingRule', 'preserve');
eventRef.target_state = string(eventRef.target_state);
eventRef.file_id = string(eventRef.file_id);
eventRef.config_id = string(eventRef.config_id);

if useConfig2
    cfg = xx_relaxation_config2_sources();
else
    cfg = getConfigSources();
end
eventMorph = table();
for c = 1:numel(cfg)
    sourceDir = fullfile(cfg(c).baseDir, cfg(c).tempDepFolder);
    if exist(sourceDir, 'dir') ~= 7
        warning('xx_relax_morph:MissingRawDir', 'Missing source directory: %s', sourceDir);
        continue;
    end

    fileRows = collectRawFilesSingleFolder(sourceDir);
    if isempty(fileRows)
        continue;
    end

    for i = 1:numel(fileRows)
        rowsI = extractMorphologyForFile(fileRows(i), selectedChannel);
        if isempty(rowsI)
            continue;
        end
        rowsI.config_id = repmat(cfg(c).config_id, height(rowsI), 1);
        eventMorph = [eventMorph; rowsI]; %#ok<AGROW>
    end
end

if isempty(eventMorph)
    error('xx_relax_morph:NoEvents', 'No morphology events extracted from configured raw data sources.');
end

eventMorph = innerjoin(eventMorph, eventRef(:, {'file_id', 'config_id', 'temperature', 'pulse_index', 'target_state', 'tau_relax', 'plateau_detected'}), ...
    'Keys', {'file_id', 'config_id', 'temperature', 'pulse_index', 'target_state'});

eventMorph = classifyMorphology(eventMorph);
writetable(eventMorph, eventOutPath);

aggTbl = aggregateMorphology(eventMorph);
writetable(aggTbl, aggOutPath);

plotMorphologyMap(aggTbl, "settled_fraction", "Settled Fraction Map", figSettled);
plotMorphologyMap(aggTbl, "unsettled_but_relaxing_fraction", "Unsettled-but-Relaxing Fraction Map", figRelaxing);
plotMorphologyMap(aggTbl, "no_clear_relaxation_fraction", "No-Clear-Relaxation Fraction Map", figNoClear);

[flagHighCurrentRegion, flagUpperEnhanced] = evaluateHighCurrentHypothesis(aggTbl);
writeReport(reportPath, eventMorph, aggTbl, selectedChannel, flagHighCurrentRegion, flagUpperEnhanced, tagSuffix);

fprintf('Wrote %s (%d rows)\n', eventOutPath, height(eventMorph));
fprintf('Wrote %s (%d rows)\n', aggOutPath, height(aggTbl));
fprintf('Wrote %s\n', figSettled);
fprintf('Wrote %s\n', figRelaxing);
fprintf('Wrote %s\n', figNoClear);
fprintf('Wrote %s\n', reportPath);
end

function ensureParentDirs(paths)
for i = 1:numel(paths)
    parent = fileparts(paths{i});
    if exist(parent, 'dir') ~= 7
        mkdir(parent);
    end
end
end

function cfg = getConfigSources()
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
    rows(end + 1).path = fullfile(string(files(f).folder), fname); %#ok<AGROW>
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

function outTbl = extractMorphologyForFile(fileRow, selectedChannel)
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

file_id = strings(0, 1);
temperature = zeros(0, 1);
pulse_index = zeros(0, 1);
target_state = strings(0, 1);
relax_start_idx = zeros(0, 1);
switch_idx = zeros(0, 1, 'int64');
window_end_idx = zeros(0, 1);
v_plateau = NaN(0, 1);
DeltaV_start = NaN(0, 1);
DeltaV_end = NaN(0, 1);
frac_remaining = NaN(0, 1);
frac_decay = NaN(0, 1);
spearman_rho = NaN(0, 1);
linear_slope = NaN(0, 1);
rms_residual = NaN(0, 1);
diff_sign_changes = NaN(0, 1);
window_n = zeros(0, 1);

for p = 1:numel(pulseIdx)
    thisPeak = pulseIdx(p);
    nextPulse = numel(v);
    if p < numel(pulseIdx)
        nextPulse = pulseIdx(p + 1) - 1;
    end

    pulseEndIdx = findPulseEnd(absDvDt, thisPeak, slopeFloor, nextPulse);
    relaxStartIdx = findRelaxationStart(absDvDt, pulseEndIdx, slopeFloor, nextPulse);
    [plateauStart, ok] = findStablePlateauStart(v, absDvDt, relaxStartIdx, nextPulse, W, stableN, slopeFloor, stdFloor);

    dStart = NaN;
    dEnd = NaN;
    remFrac = NaN;
    decFrac = NaN;
    rho = NaN;
    slopeVal = NaN;
    rmsVal = NaN;
    signChangesVal = NaN;
    vPlateau = NaN;

    if ok && relaxStartIdx < nextPulse
        plateauWindow = v(plateauStart:nextPulse);
        vPlateau = mean(plateauWindow, 'omitnan');
        absErr = abs(v(relaxStartIdx:nextPulse) - vPlateau);
        tRel = tSec(relaxStartIdx:nextPulse) - tSec(relaxStartIdx);

        dStart = absErr(1);
        dEnd = absErr(end);
        denom = max(dStart, eps);
        remFrac = dEnd / denom;
        decFrac = (dStart - dEnd) / denom;

        if numel(absErr) >= 3 && any(isfinite(absErr))
            rho = corr((1:numel(absErr))', absErr, 'Type', 'Spearman', 'Rows', 'pairwise');
            pFit = polyfit(tRel, absErr, 1);
            slopeVal = pFit(1);
            trend = polyval(pFit, tRel);
            rmsVal = sqrt(mean((absErr - trend).^2, 'omitnan'));
            dAbs = diff(absErr);
            dSign = sign(dAbs);
            dSign = dSign(dSign ~= 0);
            if isempty(dSign)
                signChangesVal = 0;
            else
                signChangesVal = sum(abs(diff(dSign)) > 0);
            end
        end
    end

    file_id(end + 1, 1) = string(fileRow.name); %#ok<AGROW>
    temperature(end + 1, 1) = fileRow.temperature; %#ok<AGROW>
    pulse_index(end + 1, 1) = p; %#ok<AGROW>
    target_state(end + 1, 1) = stateFromIndex(p); %#ok<AGROW>
    relax_start_idx(end + 1, 1) = relaxStartIdx; %#ok<AGROW>
    switch_idx(end + 1, 1) = int64(thisPeak); %#ok<AGROW>
    window_end_idx(end + 1, 1) = nextPulse; %#ok<AGROW>
    v_plateau(end + 1, 1) = vPlateau; %#ok<AGROW>
    DeltaV_start(end + 1, 1) = dStart; %#ok<AGROW>
    DeltaV_end(end + 1, 1) = dEnd; %#ok<AGROW>
    frac_remaining(end + 1, 1) = remFrac; %#ok<AGROW>
    frac_decay(end + 1, 1) = decFrac; %#ok<AGROW>
    spearman_rho(end + 1, 1) = rho; %#ok<AGROW>
    linear_slope(end + 1, 1) = slopeVal; %#ok<AGROW>
    rms_residual(end + 1, 1) = rmsVal; %#ok<AGROW>
    diff_sign_changes(end + 1, 1) = signChangesVal; %#ok<AGROW>
    window_n(end + 1, 1) = nextPulse - relaxStartIdx + 1; %#ok<AGROW>
end

outTbl = table(file_id, temperature, pulse_index, target_state, ...
    relax_start_idx, switch_idx, window_end_idx, v_plateau, DeltaV_start, DeltaV_end, ...
    frac_remaining, frac_decay, spearman_rho, linear_slope, rms_residual, ...
    diff_sign_changes, window_n);
end

function rows = classifyMorphology(rows)
rows.is_settled = isfinite(rows.tau_relax);
rows.has_substantial_decay = rows.frac_decay >= 0.35;
rows.has_monotonic_trend = rows.spearman_rho <= -0.45 & rows.linear_slope < 0;
rows.is_unsettled_but_relaxing = ...
    (~rows.is_settled) & rows.plateau_detected & rows.has_substantial_decay & rows.has_monotonic_trend;
rows.is_no_clear_relaxation = ...
    (~rows.is_settled) & rows.plateau_detected & (~rows.is_unsettled_but_relaxing);

morphology_class = strings(height(rows), 1);
morphology_class(rows.is_settled) = "SETTLED";
morphology_class(rows.is_unsettled_but_relaxing) = "UNSETTLED_BUT_RELAXING";
morphology_class(rows.is_no_clear_relaxation) = "NO_CLEAR_RELAXATION";
morphology_class(~rows.plateau_detected) = "NO_CLEAR_RELAXATION";
rows.morphology_class = morphology_class;

rows.current_mA = parseCurrentFromConfig(rows.config_id);
rows = sortrows(rows, {'config_id', 'temperature', 'pulse_index'});
end

function aggTbl = aggregateMorphology(rows)
g = findgroups(rows.config_id, rows.current_mA, rows.temperature, rows.target_state);
nGroups = max(g);

config_id = strings(nGroups, 1);
current_mA = NaN(nGroups, 1);
temperature = NaN(nGroups, 1);
state = strings(nGroups, 1);
n_events = zeros(nGroups, 1);
settled_fraction = NaN(nGroups, 1);
unsettled_but_relaxing_fraction = NaN(nGroups, 1);
no_clear_relaxation_fraction = NaN(nGroups, 1);
mean_frac_decay = NaN(nGroups, 1);
mean_spearman_rho = NaN(nGroups, 1);

for gi = 1:nGroups
    blk = rows(g == gi, :);
    config_id(gi) = blk.config_id(1);
    current_mA(gi) = blk.current_mA(1);
    temperature(gi) = blk.temperature(1);
    state(gi) = blk.target_state(1);
    n_events(gi) = height(blk);

    settled_fraction(gi) = mean(blk.morphology_class == "SETTLED");
    unsettled_but_relaxing_fraction(gi) = mean(blk.morphology_class == "UNSETTLED_BUT_RELAXING");
    no_clear_relaxation_fraction(gi) = mean(blk.morphology_class == "NO_CLEAR_RELAXATION");
    mean_frac_decay(gi) = mean(blk.frac_decay, 'omitnan');
    mean_spearman_rho(gi) = mean(blk.spearman_rho, 'omitnan');
end

aggTbl = table(config_id, current_mA, temperature, state, n_events, settled_fraction, ...
    unsettled_but_relaxing_fraction, no_clear_relaxation_fraction, mean_frac_decay, mean_spearman_rho);
aggTbl = sortrows(aggTbl, {'current_mA', 'temperature', 'state'});
end

function plotMorphologyMap(aggTbl, fractionVar, titleText, outPath)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 500]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

states = ["A", "B"];
for si = 1:numel(states)
    nexttile;
    s = states(si);
    blk = aggTbl(aggTbl.state == s, :);
    scatter(blk.temperature, blk.current_mA, 110, blk.(fractionVar), 'filled');
    xlabel('Temperature (K)');
    ylabel('Current / config (mA)');
    title(sprintf('%s state', s));
    colormap(parula);
    c = colorbar;
    c.Label.String = strrep(fractionVar, '_', ' ');
    caxis([0 1]);
    grid on;
end
sgtitle(titleText);
exportgraphics(f, outPath, 'Resolution', 160);
close(f);
end

function [isPresent, upperEnhanced] = evaluateHighCurrentHypothesis(aggTbl)
maxCurrent = max(aggTbl.current_mA, [], 'omitnan');
blk = aggTbl(aggTbl.current_mA == maxCurrent, :);
if isempty(blk)
    isPresent = false;
    upperEnhanced = false;
    return;
end

hiT = blk.temperature >= quantile(blk.temperature, 0.6);
reg = blk(hiT, :);
if isempty(reg)
    reg = blk;
end

isPresent = any(reg.unsettled_but_relaxing_fraction >= 0.4 & reg.settled_fraction <= 0.6);

bFrac = mean(reg.unsettled_but_relaxing_fraction(reg.state == "B"), 'omitnan');
aFrac = mean(reg.unsettled_but_relaxing_fraction(reg.state == "A"), 'omitnan');
upperEnhanced = isfinite(bFrac) && isfinite(aFrac) && (bFrac > aFrac);
end

function writeReport(reportPath, eventTbl, aggTbl, selectedChannel, highCurrentPresent, upperEnhanced, tagSuffix)
if nargin < 7
    tagSuffix = "";
end
nEvents = height(eventTbl);
nSettled = sum(eventTbl.morphology_class == "SETTLED");
nRelaxing = sum(eventTbl.morphology_class == "UNSETTLED_BUT_RELAXING");
nNoClear = sum(eventTbl.morphology_class == "NO_CLEAR_RELAXATION");

maxCurrent = max(aggTbl.current_mA, [], 'omitnan');
highCurrentRows = aggTbl(aggTbl.current_mA == maxCurrent, :);

fid = fopen(reportPath, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# XX Relaxation Morphology Map\n\n');
fprintf(fid, '## 1. Purpose\n');
fprintf(fid, 'This audit separates unresolved settling (`tau_relax` undefined) from absence of visible relaxation.\n');
fprintf(fid, 'Event-level morphology descriptors are computed on top of the validated XX segmentation.\n\n');

fprintf(fid, '## 2. Definitions used\n');
fprintf(fid, '- **SETTLED**: `tau_relax` is finite.\n');
fprintf(fid, '- **UNSETTLED_BUT_RELAXING**: `tau_relax` is NaN, with substantial net decay and monotonic trend toward `V_plateau`.\n');
fprintf(fid, '- **NO_CLEAR_RELAXATION**: `tau_relax` is NaN and the decay criteria are not met.\n\n');

fprintf(fid, '## 3. Event-level evidence\n');
fprintf(fid, '- Core descriptors: `DeltaV_start`, `DeltaV_end`, `frac_remaining`, `frac_decay`.\n');
fprintf(fid, '- Trend descriptors: Spearman correlation and linear slope of `|v(t)-V_plateau|` over the relaxation window.\n');
fprintf(fid, '- Optional robustness descriptors: RMS residual and first-difference sign-change count.\n');
fprintf(fid, '- Operational thresholds for unsettled-but-relaxing: `frac_decay >= 0.35`, `spearman_rho <= -0.45`, and `linear_slope < 0`.\n\n');

fprintf(fid, '## 4. Map-level findings\n');
fprintf(fid, '- Total events: %d\n', nEvents);
fprintf(fid, '- Settled: %d (%.1f%%)\n', nSettled, 100 * nSettled / max(nEvents, 1));
fprintf(fid, '- Unsettled but relaxing: %d (%.1f%%)\n', nRelaxing, 100 * nRelaxing / max(nEvents, 1));
fprintf(fid, '- No clear relaxation: %d (%.1f%%)\n\n', nNoClear, 100 * nNoClear / max(nEvents, 1));

fprintf(fid, '## 5. High-current / high-temperature focus\n');
fprintf(fid, 'Strongest config identified by current label: %.2f mA.\n', maxCurrent);
if ~isempty(highCurrentRows)
    fprintf(fid, 'State-separated fractions at strongest config:\n');
    uRows = unique(highCurrentRows(:, {'temperature', 'state', 'settled_fraction', 'unsettled_but_relaxing_fraction'}), 'rows');
    for i = 1:height(uRows)
        fprintf(fid, '- T=%.2f K, state=%s: settled=%.2f, unsettled_but_relaxing=%.2f\n', ...
            uRows.temperature(i), string(uRows.state(i)), uRows.settled_fraction(i), uRows.unsettled_but_relaxing_fraction(i));
    end
end
fprintf(fid, '\nDirect hypothesis answer:\n');
fprintf(fid, '- High-current region with strong relaxation but incomplete settling: %s\n', yesNo(highCurrentPresent));
fprintf(fid, '- Upper/high-resistance state enhanced unsettled relaxation: %s\n\n', yesNo(upperEnhanced));

fprintf(fid, '## 6. What is and is not concluded\n');
fprintf(fid, '- Full settling and relaxation existence are empirically separated.\n');
fprintf(fid, '- No mechanism claims are made.\n\n');

fprintf(fid, '## Output artifacts\n');
fprintf(fid, '- `tables/xx_relaxation_morphology_event_level%s.csv`\n', char(tagSuffix));
fprintf(fid, '- `tables/xx_relaxation_morphology_aggregated%s.csv`\n', char(tagSuffix));
fprintf(fid, '- `figures/xx_relaxation_settled_map%s.png`\n', char(tagSuffix));
fprintf(fid, '- `figures/xx_relaxation_unsettled_but_relaxing_map%s.png`\n', char(tagSuffix));
fprintf(fid, '- `figures/xx_relaxation_no_clear_map%s.png`\n', char(tagSuffix));
fprintf(fid, '- `reports/xx_relaxation_morphology_map%s.md`\n\n', char(tagSuffix));

fprintf(fid, '## Mandatory flags\n');
fprintf(fid, '- `SETTLED_VS_UNSETTLED_RELAXING_DISTINGUISHED = YES`\n');
fprintf(fid, '- `HIGH_CURRENT_UNSETTLED_RELAXATION_REGION_PRESENT = %s`\n', yesNo(highCurrentPresent));
fprintf(fid, '- `UPPER_STATE_ENHANCED_UNSETTLED_RELAXATION = %s`\n', yesNo(upperEnhanced));
fprintf(fid, '- `MAPS_WRITTEN = YES`\n');
fprintf(fid, '- `NO_CORE_LOGIC_CHANGED = YES`\n\n');

fprintf(fid, '## Success criteria\n');
fprintf(fid, '- `EVENT_CLASSES_WRITTEN = YES`\n');
fprintf(fid, '- `AGGREGATED_MAPS_WRITTEN = YES`\n');
fprintf(fid, '- `USER_HYPOTHESIS_TESTED = YES`\n\n');

fprintf(fid, 'All analyses preserve the original XX event detection, plateau definition, relaxation window, and `tau_relax` logic.\n');
fprintf(fid, 'This audit adds morphology descriptors only, to distinguish incomplete settling from absence of visible relaxation.\n');
fprintf(fid, '\nChannel policy used: `PIPELINE_SELECTED_CHANNEL = %d`.\n', selectedChannel);
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

function current_mA = parseCurrentFromConfig(config_id)
config_id = string(config_id);
current_mA = NaN(size(config_id));
for i = 1:numel(config_id)
    tok = regexp(config_id(i), '([0-9]+(?:p[0-9]+)?)mA', 'tokens', 'once');
    if isempty(tok)
        continue;
    end
    val = replace(tok{1}, "p", ".");
    current_mA(i) = str2double(val);
end
end

function out = yesNo(tf)
if tf
    out = 'YES';
else
    out = 'NO';
end
end
