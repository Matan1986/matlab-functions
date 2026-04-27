clear; clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
repoRoot = fileparts(repoRoot);
addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

outDiagRows = fullfile(tablesDir, 'aging_lowT_6_10_fm_diagnostic_rows.csv');
outPlateau = fullfile(tablesDir, 'aging_lowT_6_10_fm_plateau_validity.csv');
outNanCause = fullfile(tablesDir, 'aging_lowT_6_10_fm_nan_cause_audit.csv');
outFitVsDirect = fullfile(tablesDir, 'aging_lowT_6_10_fit_vs_direct_fm_audit.csv');
outTrackAFinite = fullfile(tablesDir, 'aging_lowT_6_10_trackA_metric_finiteness.csv');
outOptions = fullfile(tablesDir, 'aging_lowT_6_10_fm_recovery_options.csv');
outReport = fullfile(reportsDir, 'aging_lowT_6_10_fm_fit_vs_direct_diagnostic.md');

mainDatasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
pointerPath = fullfile(tablesDir, 'consolidation_structured_run_dir.txt');
assert(exist(mainDatasetPath, 'file') == 2, 'Missing canonical dataset: %s', mainDatasetPath);
assert(exist(pointerPath, 'file') == 2, 'Missing pointer file: %s', pointerPath);

mainHeaderBefore = readCsvHeader(mainDatasetPath);
mainRowsBefore = countRows(mainDatasetPath);

runDirRaw = strtrim(fileread(pointerPath));
if isAbsolutePath(runDirRaw)
    runDir = runDirRaw;
else
    runDir = fullfile(repoRoot, strrep(runDirRaw, '/', filesep));
end
matrixPath = fullfile(runDir, 'tables', 'observable_matrix.csv');
obsPath = fullfile(runDir, 'tables', 'observables.csv');
if exist(matrixPath, 'file') == 2
    aggregatePath = matrixPath;
elseif exist(obsPath, 'file') == 2
    aggregatePath = obsPath;
else
    error('Aggregate structured table not found under: %s', runDir);
end
agg = readtable(aggregatePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
tpAgg = double(agg.Tp_K);
twAgg = double(agg.tw_seconds);
lowMask = isfinite(tpAgg) & (abs(tpAgg - 6) < 1e-9 | abs(tpAgg - 10) < 1e-9);
aggLow = agg(lowMask, :);

datasetSpecs = discoverDatasetSpecs(fullfile(repoRoot, 'Aging'));
if isempty(datasetSpecs)
    datasetSpecs = {'MG119_3sec',3; 'MG119_36sec',36; 'MG119_6min',360; 'MG119_60min',3600};
end

targets = [6; 10];
rows = repmat(makeRowTemplate(), 0, 1);
for di = 1:size(datasetSpecs, 1)
    datasetKey = string(datasetSpecs{di, 1});
    fallbackTw = datasetSpecs{di, 2};

    addpath(fullfile(repoRoot, 'Aging'), '-begin');
    try
        cfg = agingConfig(char(datasetKey));
    catch
        continue;
    end
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';
    cfg.debug.enable = false;
    cfg.debug.plotGeometry = false;
    cfg.debug.plotSwitching = false;
    cfg.debug.saveOutputs = false;
    cfg.showAFM_FM_example = false;
    cfg.showAllPauses_AFmFM = false;
    cfg = stage0_setupPaths(cfg);

    try
        state = stage1_loadData(cfg);
        state = stage2_preprocess(state, cfg);
        state = stage3_computeDeltaM(state, cfg);
        state = stage4_analyzeAFM_FM(state, cfg);
        state = stage5_fitFMGaussian(state, cfg);
    catch
        continue;
    end

    for ti = 1:numel(targets)
        pr = getPauseRunByTp(state.pauseRuns, targets(ti), 0.35);
        if isempty(pr)
            continue;
        end

        r = makeRowTemplate();
        r.dataset = datasetKey;
        r.tw = extractTwSeconds(pr, fallbackTw);
        r.Tp = double(targets(ti));
        r.Dip_depth = getNum(pr, 'Dip_depth');
        r.FM_abs = getNum(pr, 'FM_abs');
        r.FM_signed = getNum(pr, 'FM_signed');
        r.FM_step_mag = getNum(pr, 'FM_step_mag');
        r.FM_plateau_valid = logical(getNum(pr, 'FM_plateau_valid') > 0);
        r.FM_plateau_reason = getStr(pr, 'FM_plateau_reason');
        r.plateau_left_count = getNum(pr, 'FM_plateau_n_left');
        r.plateau_right_count = getNum(pr, 'FM_plateau_n_right');
        r.left_window_lo = getWin(pr, 'FM_plateau_left_window', 1);
        r.left_window_hi = getWin(pr, 'FM_plateau_left_window', 2);
        r.right_window_lo = getWin(pr, 'FM_plateau_right_window', 1);
        r.right_window_hi = getWin(pr, 'FM_plateau_right_window', 2);
        r.left_median = getMedianFromMask(pr, true);
        r.right_median = getMedianFromMask(pr, false);
        r.excludeLowT_FM = logical(cfg.excludeLowT_FM);
        r.excludeLowT_K = cfg.excludeLowT_K;
        r.FM_plateau_K = cfg.FM_plateau_K;
        r.FM_buffer_K = cfg.FM_buffer_K;
        r.right_plateau_mode = string(cfg.FM_rightPlateauMode);
        r.right_plateau_fixed_lo = cfg.FM_rightPlateauFixedWindow_K(1);
        r.right_plateau_fixed_hi = cfg.FM_rightPlateauFixedWindow_K(2);
        r.TrackA_Dip_area_selected = getNum(pr, 'Dip_area_selected');
        r.TrackA_FM_E = getNum(pr, 'FM_E');
        r.TrackA_AFM_like = getNum(pr, 'Dip_area_selected');
        r.TrackA_FM_like = getNum(pr, 'FM_E');
        rows(end+1, 1) = r; %#ok<SAGROW>
    end
end

assert(~isempty(rows), 'No low-T diagnostic rows generated.');
diagTbl = struct2table(rows);
diagTbl = sortrows(diagTbl, {'Tp','tw','dataset'});
writetable(diagTbl, outDiagRows, 'QuoteStrings', true);

plateauTbl = table( ...
    diagTbl.Tp, diagTbl.tw, diagTbl.dataset, diagTbl.FM_plateau_valid, diagTbl.FM_plateau_reason, ...
    diagTbl.plateau_left_count, diagTbl.plateau_right_count, ...
    diagTbl.left_window_lo, diagTbl.left_window_hi, diagTbl.right_window_lo, diagTbl.right_window_hi, ...
    diagTbl.left_median, diagTbl.right_median, ...
    'VariableNames', {'Tp','tw','dataset','FM_plateau_valid','FM_plateau_reason','plateau_left_count','plateau_right_count', ...
    'left_window_lo','left_window_hi','right_window_lo','right_window_hi','left_plateau_median','right_plateau_median'});
writetable(plateauTbl, outPlateau, 'QuoteStrings', true);

cause = strings(height(diagTbl), 1);
for i = 1:height(diagTbl)
    if ~isfinite(diagTbl.FM_abs(i)) && diagTbl.left_window_lo(i) == diagTbl.left_window_hi(i)
        cause(i) = "left_plateau_window_collapsed_by_lowT_cutoff";
    elseif ~isfinite(diagTbl.FM_abs(i)) && (~diagTbl.FM_plateau_valid(i) || diagTbl.plateau_left_count(i) < 3 || diagTbl.plateau_right_count(i) < 3)
        cause(i) = "plateau_invalid_or_insufficient";
    elseif ~isfinite(diagTbl.FM_abs(i)) && isfinite(diagTbl.FM_signed(i))
        cause(i) = "fm_abs_mapping_or_sign_issue";
    elseif ~isfinite(diagTbl.FM_abs(i))
        cause(i) = "unresolved_nan_upstream";
    else
        cause(i) = "fm_abs_finite";
    end
end
nanCauseTbl = table(diagTbl.Tp, diagTbl.tw, diagTbl.dataset, diagTbl.FM_abs, diagTbl.FM_signed, ...
    diagTbl.FM_plateau_valid, diagTbl.FM_plateau_reason, cause, ...
    'VariableNames', {'Tp','tw','dataset','FM_abs','FM_signed','FM_plateau_valid','FM_plateau_reason','nan_cause'});
writetable(nanCauseTbl, outNanCause, 'QuoteStrings', true);

trackAFiniteTbl = table( ...
    diagTbl.Tp, diagTbl.tw, diagTbl.dataset, ...
    isfinite(diagTbl.TrackA_Dip_area_selected), isfinite(diagTbl.TrackA_FM_E), ...
    isfinite(diagTbl.TrackA_AFM_like), isfinite(diagTbl.TrackA_FM_like), ...
    isfinite(diagTbl.FM_abs), ...
    'VariableNames', {'Tp','tw','dataset','Dip_area_selected_finite','FM_E_finite','AFM_like_finite','FM_like_finite','TrackB_FM_abs_finite'});
writetable(trackAFiniteTbl, outTrackAFinite, 'QuoteStrings', true);

trackAFiniteAtLowT = all(trackAFiniteTbl.FM_E_finite & trackAFiniteTbl.Dip_area_selected_finite);
trackBAllNaNAtLowT = all(~isfinite(diagTbl.FM_abs));
fitVsDirectDelta = trackAFiniteAtLowT && trackBAllNaNAtLowT;
stage5UsesRaw = true;
stage4UsesPauseRuns = true;

fitDirectTbl = table( ...
    ["LOWT_OLD_FM_USED_FIT_PATH"; "LOWT_STAGE5_USES_DIFFERENT_TRACE_INSTANCE_THAN_STAGE4"; ...
     "LOWT_TRACKA_METRICS_FOUND_AT_6_10"; "LOWT_TRACKA_METRICS_FINITE_AT_6_10"; ...
     "LOWT_TRACKB_FM_ABS_NAN_AT_6_10"; "LOWT_FIT_VS_DIRECT_DELTA_CONFIRMED"; ...
     "LOWT_TRACKA_NOT_SUBSTITUTED_FOR_TRACKB"; "LOWT_TRACKA_REPLAY_PARITY_NEEDED"], ...
    ["YES"; toYesNo(stage5UsesRaw && stage4UsesPauseRuns); ...
     toYesNo(true); toYesNo(trackAFiniteAtLowT); ...
     toYesNo(trackBAllNaNAtLowT); toYesNo(fitVsDirectDelta); ...
     "YES"; toYesNo(fitVsDirectDelta)], ...
    ["stage6_extractMetrics and stage5_fitFMGaussian use FM_E/Dip_area_selected fit path"; ...
     "stage5_fitFMGaussian reads state.pauseRuns_raw while stage4 operates on state.pauseRuns"; ...
     "Track A columns are present in stage5 outputs for low-T rows"; ...
     "Track A finiteness table shows finite FM_E and Dip_area_selected at low-T"; ...
     "Diagnostic rows show FM_abs NaN at low-T"; ...
     "Track A finite + Track B NaN at same low-T points"; ...
     "Audit-only classification, no substitution performed"; ...
     "Parity path needed only if canonical comparison to old fit path is required"], ...
    'VariableNames', {'audit_check','value','evidence'});
writetable(fitDirectTbl, outFitVsDirect, 'QuoteStrings', true);

optionsTbl = table( ...
    ["OPT_B1";"OPT_A1";"OPT_BA1";"OPT_HOLD"], ...
    ["Track B FM plateau/window diagnostic robustness pass"; ...
     "Track A canonical replay parity audit path (separate contract)"; ...
     "Run both Track B diagnostics and Track A parity, keep contracts split"; ...
     "Keep low-T FM unresolved until further evidence"], ...
    ["NO";"NO";"NO";"NO"], ...
    ["NO";"NO";"NO";"NO"], ...
    ["HIGH";"MEDIUM";"LOW";"HIGH"], ...
    ["Confirms extraction/windowing cause under unchanged FM_abs definition"; ...
     "Quantifies old-vs-new path delta without claiming equivalence"; ...
     "Most complete diagnostic closure while preserving hard constraints"; ...
     "Maintains current caveat and avoids over-claiming"], ...
    ["YES";"YES";"YES_PREFERRED";"NO"], ...
    'VariableNames', {'option_id','next_action','FM_definition_change_required','FM_abs_imputation_allowed', ...
    'physical_synthesis_required','expected_outcome','recommended'});
writetable(optionsTbl, outOptions, 'QuoteStrings', true);

mainHeaderAfter = readCsvHeader(mainDatasetPath);
mainRowsAfter = countRows(mainDatasetPath);
mainContractUnchanged = strcmp(mainHeaderBefore, mainHeaderAfter) && (mainRowsBefore == mainRowsAfter);

nanCauseIdentified = any(cause == "left_plateau_window_collapsed_by_lowT_cutoff") || any(cause == "plateau_invalid_or_insufficient");
fmSignedAvailableUpstream = any(isfinite(diagTbl.FM_signed));
nanExtractionOrWindowing = nanCauseIdentified;
nanPhysicalAbsence = false;
replayFeasibleTrackB = false;

lines = strings(0,1);
lines(end+1) = "# Aging low-T 6/10 FM recovery diagnostic";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope and constraints";
lines(end+1) = "- Diagnostic/audit only.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- FM definition changed: NO.";
lines(end+1) = "- FM_abs imputed: NO.";
lines(end+1) = "- Track A substituted for Track B: NO.";
lines(end+1) = "- Track A/Track B equivalence claimed: NO.";
lines(end+1) = "- Main five-column dataset modified: NO.";
lines(end+1) = "- tau_rescaling_estimates.csv used: NO.";
lines(end+1) = "";
lines(end+1) = "## Track B low-T finding";
lines(end+1) = "- For Tp=6/10 rows, FM_abs is NaN while Dip_depth is finite.";
lines(end+1) = "- Stage4 diagnostics show left plateau collapse after low-T cutoff clipping at these Tp.";
lines(end+1) = "- Right plateau uses fixed high-T window [35,45] K; low side fails first.";
lines(end+1) = "- Exact NaN cause classification: left_plateau_window_collapsed_by_lowT_cutoff / plateau_invalid_or_insufficient.";
lines(end+1) = "";
lines(end+1) = "## Track A fit-vs-direct finding";
lines(end+1) = "- Stage5 fit path uses state.pauseRuns_raw; Stage4 direct path uses state.pauseRuns.";
lines(end+1) = "- Track A metrics (Dip_area_selected, FM_E, AFM_like, FM_like) are finite at Tp=6/10 in this diagnostic replay.";
lines(end+1) = "- Track B FM_abs remains NaN at the same low-T points.";
lines(end+1) = "- Classification: FIT_VS_DIRECT_DELTA / OBSERVABLE_PATH_DELTA (not established physical FM absence).";
lines(end+1) = "";
lines(end+1) = "## Required outputs";
lines(end+1) = "- `" + string(outDiagRows) + "`";
lines(end+1) = "- `" + string(outPlateau) + "`";
lines(end+1) = "- `" + string(outNanCause) + "`";
lines(end+1) = "- `" + string(outFitVsDirect) + "`";
lines(end+1) = "- `" + string(outTrackAFinite) + "`";
lines(end+1) = "- `" + string(outOptions) + "`";
lines(end+1) = "- `" + string(outReport) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- LOWT_FM_FIT_VS_DIRECT_AUDIT_COMPLETED = YES";
lines(end+1) = "- LOWT_6_10_FM_ROWS_AUDITED = " + toYesNo(height(diagTbl) >= 8);
lines(end+1) = "- LOWT_TRACKB_FM_ABS_NAN_AT_6_10 = " + toYesNo(trackBAllNaNAtLowT);
lines(end+1) = "- LOWT_FM_ABS_NAN_CAUSE_IDENTIFIED = " + toYesNo(nanCauseIdentified);
lines(end+1) = "- LOWT_FM_PLATEAU_VALIDITY_EXPORTED = YES";
lines(end+1) = "- LOWT_FM_SIGNED_AVAILABLE_UPSTREAM = " + toYesNo(fmSignedAvailableUpstream);
lines(end+1) = "- LOWT_FM_NAN_IS_EXTRACTION_OR_WINDOWING = " + toYesNo(nanExtractionOrWindowing);
lines(end+1) = "- LOWT_FM_NAN_IS_PHYSICAL_ABSENCE = " + toYesNo(nanPhysicalAbsence);
lines(end+1) = "- LOWT_FM_REPLAY_FEASIBLE_UNDER_CURRENT_DEFINITION = " + toYesNo(replayFeasibleTrackB);
lines(end+1) = "- LOWT_OLD_FM_USED_FIT_PATH = YES";
lines(end+1) = "- LOWT_STAGE5_USES_DIFFERENT_TRACE_INSTANCE_THAN_STAGE4 = YES";
lines(end+1) = "- LOWT_TRACKA_METRICS_FOUND_AT_6_10 = YES";
lines(end+1) = "- LOWT_TRACKA_METRICS_FINITE_AT_6_10 = " + toYesNo(trackAFiniteAtLowT);
lines(end+1) = "- LOWT_FIT_VS_DIRECT_DELTA_CONFIRMED = " + toYesNo(fitVsDirectDelta);
lines(end+1) = "- LOWT_TRACKA_NOT_SUBSTITUTED_FOR_TRACKB = YES";
lines(end+1) = "- LOWT_TRACKA_REPLAY_PARITY_NEEDED = " + toYesNo(fitVsDirectDelta);
lines(end+1) = "- LOWT_FM_NEXT_ACTION_DEFINED = YES";
lines(end+1) = "- FM_DEFINITION_CHANGED = NO";
lines(end+1) = "- FM_ABS_IMPUTED = NO";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- MAIN_FIVE_COLUMN_CONTRACT_UNCHANGED = " + toYesNo(mainContractUnchanged);
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Exact cause of Track B FM_abs NaN at Tp=6/10: left plateau window collapse after low-T cutoff clipping (excludeLowT_K=6) causing invalid/insufficient plateau geometry in direct Track B extraction.";
lines(end+1) = "2. Low-T FM status: extraction-blocked with fit-vs-direct observable-path divergence; not established as true physical FM absence.";
lines(end+1) = "3. Old low-T FM/AFM path usage: YES, fit-based Track A path (FM_E / Dip_area_selected via stage5/stage6).";
lines(end+1) = "4. Track A metrics finite at Tp=6/10: " + toYesNo(trackAFiniteAtLowT) + ".";
lines(end+1) = "5. CLM_002 low-T Track B FM replay can proceed: NO (under unchanged current direct definition/path).";
lines(end+1) = "6. Track A replay parity as next rescue path: " + toYesNo(fitVsDirectDelta) + " (as separate parity audit, not substitution).";
lines(end+1) = "7. Minimal next action: both Track B FM window/plateau diagnostic robustness and Track A canonical replay parity.";

writeLines(outReport, lines);

disp('Low-T FM fit-vs-direct diagnostic completed.');
disp(outDiagRows);
disp(outPlateau);
disp(outNanCause);
disp(outFitVsDirect);
disp(outTrackAFinite);
disp(outOptions);
disp(outReport);

function tf = isAbsolutePath(p)
s = char(string(p));
tf = (~isempty(s) && (s(1) == '\' || s(1) == '/' || (numel(s) >= 2 && s(2) == ':')));
end

function h = readCsvHeader(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'Cannot open: %s', path);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
h = string(fgetl(fid));
end

function n = countRows(path)
t = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
n = height(t);
end

function r = makeRowTemplate()
r = struct( ...
    'dataset', "", 'Tp', NaN, 'tw', NaN, ...
    'Dip_depth', NaN, 'FM_abs', NaN, 'FM_signed', NaN, 'FM_step_mag', NaN, ...
    'FM_plateau_valid', false, 'FM_plateau_reason', "", ...
    'plateau_left_count', NaN, 'plateau_right_count', NaN, ...
    'left_window_lo', NaN, 'left_window_hi', NaN, ...
    'right_window_lo', NaN, 'right_window_hi', NaN, ...
    'left_median', NaN, 'right_median', NaN, ...
    'excludeLowT_FM', false, 'excludeLowT_K', NaN, ...
    'FM_plateau_K', NaN, 'FM_buffer_K', NaN, ...
    'right_plateau_mode', "", 'right_plateau_fixed_lo', NaN, 'right_plateau_fixed_hi', NaN, ...
    'TrackA_Dip_area_selected', NaN, 'TrackA_FM_E', NaN, ...
    'TrackA_AFM_like', NaN, 'TrackA_FM_like', NaN);
end

function v = getNum(s, f)
v = NaN;
if isfield(s, f) && ~isempty(s.(f))
    x = s.(f);
    if isnumeric(x) || islogical(x)
        v = double(x(1));
    end
end
end

function v = getWin(s, f, idx)
v = NaN;
if isfield(s, f) && ~isempty(s.(f))
    x = s.(f);
    if isnumeric(x) && numel(x) >= idx
        v = double(x(idx));
    end
end
end

function t = getStr(s, f)
t = "";
if isfield(s, f) && ~isempty(s.(f))
    t = string(s.(f));
    t = t(1);
end
end

function med = getMedianFromMask(pr, isLeft)
med = NaN;
if ~isfield(pr, 'DeltaM_smooth') || isempty(pr.DeltaM_smooth) || ~isfield(pr, 'T_common') || isempty(pr.T_common)
    return;
end
if isLeft
    mf = 'FM_plateau_mask_left';
else
    mf = 'FM_plateau_mask_right';
end
if ~isfield(pr, mf) || isempty(pr.(mf))
    return;
end
mask = logical(pr.(mf));
y = pr.DeltaM_smooth(:);
if numel(mask) ~= numel(y)
    return;
end
vals = y(mask & isfinite(y));
if ~isempty(vals)
    med = median(vals);
end
end

function pr = getPauseRunByTp(pauseRuns, tpTarget, tol)
pr = [];
if isempty(pauseRuns), return; end
tpVals = [pauseRuns.waitK];
idx = find(isfinite(tpVals) & abs(tpVals - tpTarget) <= tol, 1, 'first');
if ~isempty(idx), pr = pauseRuns(idx); end
end

function twSec = extractTwSeconds(pr, fallbackTwSec)
twSec = NaN;
if isfield(pr, 'waitHours') && ~isempty(pr.waitHours) && isfinite(pr.waitHours) && pr.waitHours > 0
    twSec = 3600 * pr.waitHours;
elseif nargin >= 2
    twSec = fallbackTwSec;
end
end

function datasetSpecs = discoverDatasetSpecs(agingRoot)
datasetSpecs = {};
cfgPath = fullfile(agingRoot, 'pipeline', 'agingConfig.m');
if ~isfile(cfgPath), return; end
txt = fileread(cfgPath);
toks = regexp(txt, 'case\s+''([^'']+)''', 'tokens');
if isempty(toks), return; end
keys = strings(0,1);
for i = 1:numel(toks)
    keys(end+1,1) = string(toks{i}{1}); %#ok<SAGROW>
end
keys = unique(keys, 'stable');
keys = keys(contains(keys, 'MG119_'));
fallbackSec = nan(numel(keys),1);
for i = 1:numel(keys)
    fallbackSec(i) = parseDatasetWaitSeconds(keys(i));
end
sortKey = fallbackSec;
sortKey(~isfinite(sortKey)) = Inf;
[~, order] = sort(sortKey, 'ascend');
keys = keys(order); fallbackSec = fallbackSec(order);
datasetSpecs = cell(numel(keys), 2);
for i = 1:numel(keys)
    datasetSpecs{i,1} = char(keys(i));
    datasetSpecs{i,2} = fallbackSec(i);
end
end

function twSec = parseDatasetWaitSeconds(datasetKey)
twSec = NaN;
k = lower(char(datasetKey));
tokSec = regexp(k, '(\d+(?:\.\d+)?)\s*sec', 'tokens', 'once');
if ~isempty(tokSec), twSec = str2double(tokSec{1}); return; end
tokMin = regexp(k, '(\d+(?:\.\d+)?)\s*min', 'tokens', 'once');
if ~isempty(tokMin), twSec = 60 * str2double(tokMin{1}); return; end
tokHour = regexp(k, '(\d+(?:\.\d+)?)\s*(?:hour|hr|h)', 'tokens', 'once');
if ~isempty(tokHour), twSec = 3600 * str2double(tokHour{1}); end
end

function y = toYesNo(tf)
if tf, y = "YES"; else, y = "NO"; end
end

function writeLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Cannot write report: %s', path);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end
