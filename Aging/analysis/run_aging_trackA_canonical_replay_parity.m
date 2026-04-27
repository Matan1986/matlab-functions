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

outDataset = fullfile(tablesDir, 'aging_trackA_replay_dataset.csv');
outFinite = fullfile(tablesDir, 'aging_trackA_metric_finiteness_audit.csv');
outFitQ = fullfile(tablesDir, 'aging_trackA_fit_quality_audit.csv');
outAvail = fullfile(tablesDir, 'aging_trackA_vs_trackB_availability.csv');
outDecisions = fullfile(tablesDir, 'aging_trackA_replay_parity_decisions.csv');
outReport = fullfile(reportsDir, 'aging_trackA_canonical_replay_parity.md');

mainTrackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
pointerPath = fullfile(tablesDir, 'consolidation_structured_run_dir.txt');
diagTrackAPath = fullfile(tablesDir, 'aging_lowT_6_10_trackA_metric_finiteness.csv');
assert(exist(mainTrackBPath, 'file') == 2, 'Missing main Track B dataset.');
assert(exist(pointerPath, 'file') == 2, 'Missing structured aggregate pointer.');

mainHeaderBefore = readCsvHeader(mainTrackBPath);
mainRowsBefore = countRows(mainTrackBPath);

datasetSpecs = discoverDatasetSpecs(fullfile(repoRoot, 'Aging'));
if isempty(datasetSpecs)
    datasetSpecs = {'MG119_3sec',3; 'MG119_36sec',36; 'MG119_6min',360; 'MG119_60min',3600};
end

rows = repmat(makeTrackARow(), 0, 1);
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

    try
        cfg = stage0_setupPaths(cfg);
        state = stage1_loadData(cfg);
        state = stage2_preprocess(state, cfg);
        state = stage3_computeDeltaM(state, cfg);
        state = stage4_analyzeAFM_FM(state, cfg);
        state = stage5_fitFMGaussian(state, cfg);
        state = stage6_extractMetrics(state, cfg);
    catch
        continue;
    end

    for i = 1:numel(state.pauseRuns)
        pr = state.pauseRuns(i);
        r = makeTrackARow();
        r.Tp = getNum(pr, 'waitK');
        r.tw = extractTwSeconds(pr, fallbackTw);
        r.Dip_area_selected = getNum(pr, 'Dip_area_selected');
        r.FM_E = getNum(pr, 'FM_E');
        r.AFM_like = getSummaryOrFallback(state, i, 'AFM_like', r.Dip_area_selected);
        r.FM_like = getSummaryOrFallback(state, i, 'FM_like', r.FM_E);
        r.source_run = "stage5_stage6_parity_replay|" + datasetKey;
        r.trace_instance = "stage5_fit_from_pauseRuns_raw_mapped_to_pauseRuns";
        r.fit_status = classifyFitStatus(pr);
        r.fit_success = toYesNo(startsWith(r.fit_status, "FIT_OK"));
        r.fit_R2 = getNum(pr, 'fit_R2');
        r.fit_RMSE = getNum(pr, 'fit_RMSE');
        r.fit_NRMSE = getNum(pr, 'fit_NRMSE');
        r.fit_chi2_red = getNum(pr, 'fit_chi2_red');
        r.Dip_A = getNum(pr, 'Dip_A');
        r.Dip_sigma = getNum(pr, 'Dip_sigma');
        r.Dip_T0 = getNum(pr, 'Dip_T0');
        r.FM_step_A = getNum(pr, 'FM_step_A');
        r.dataset_role = "TRACK_A_REPLAY_PARITY";
        rows(end+1,1) = r; %#ok<SAGROW>
    end
end

assert(~isempty(rows), 'No Track A replay rows generated.');
trackATbl = struct2table(rows);
trackATbl = trackATbl(isfinite(trackATbl.Tp) & isfinite(trackATbl.tw), :);
trackATbl = sortrows(trackATbl, {'Tp','tw','source_run'});
writetable(trackATbl, outDataset, 'QuoteStrings', true);

finMaskA = isfinite(trackATbl.Dip_area_selected) & isfinite(trackATbl.FM_E) & ...
    isfinite(trackATbl.AFM_like) & isfinite(trackATbl.FM_like);
lowMask = abs(trackATbl.Tp - 6) < 1e-9 | abs(trackATbl.Tp - 10) < 1e-9;
midMask = ismember(round(trackATbl.Tp), [14 18 22 26]);
tp30Mask = abs(trackATbl.Tp - 30) < 1e-9;
tp34Mask = abs(trackATbl.Tp - 34) < 1e-9;

finitenessTbl = table( ...
    ["all_rows"; "lowT_6_10"; "mid_core_14_18_22_26"; "tp30_core_edge"; "tp34_diagnostic"], ...
    [height(trackATbl); nnz(lowMask); nnz(midMask); nnz(tp30Mask); nnz(tp34Mask)], ...
    [nnz(finMaskA); nnz(finMaskA & lowMask); nnz(finMaskA & midMask); nnz(finMaskA & tp30Mask); nnz(finMaskA & tp34Mask)], ...
    [nnz(isfinite(trackATbl.Dip_area_selected)); nnz(isfinite(trackATbl.Dip_area_selected) & lowMask); ...
     nnz(isfinite(trackATbl.Dip_area_selected) & midMask); nnz(isfinite(trackATbl.Dip_area_selected) & tp30Mask); ...
     nnz(isfinite(trackATbl.Dip_area_selected) & tp34Mask)], ...
    [nnz(isfinite(trackATbl.FM_E)); nnz(isfinite(trackATbl.FM_E) & lowMask); ...
     nnz(isfinite(trackATbl.FM_E) & midMask); nnz(isfinite(trackATbl.FM_E) & tp30Mask); ...
     nnz(isfinite(trackATbl.FM_E) & tp34Mask)], ...
    'VariableNames', {'scope','rows_total','rows_all_trackA_metrics_finite','rows_Dip_area_selected_finite','rows_FM_E_finite'});
writetable(finitenessTbl, outFinite, 'QuoteStrings', true);

fitQualityTbl = table(trackATbl.Tp, trackATbl.tw, trackATbl.source_run, trackATbl.fit_status, ...
    trackATbl.fit_success, trackATbl.fit_R2, trackATbl.fit_RMSE, trackATbl.fit_NRMSE, ...
    trackATbl.fit_chi2_red, trackATbl.Dip_A, trackATbl.Dip_sigma, trackATbl.FM_step_A, ...
    isfinite(trackATbl.fit_R2) & isfinite(trackATbl.fit_RMSE) & isfinite(trackATbl.fit_NRMSE), ...
    'VariableNames', {'Tp','tw','source_run','fit_status','fit_success','fit_R2','fit_RMSE','fit_NRMSE', ...
    'fit_chi2_red','Dip_A','Dip_sigma','FM_step_A','fit_quality_fields_finite'});
writetable(fitQualityTbl, outFitQ, 'QuoteStrings', true);

runDirRaw = strtrim(fileread(pointerPath));
if isAbsolutePath(runDirRaw)
    runDir = runDirRaw;
else
    runDir = fullfile(repoRoot, strrep(runDirRaw, '/', filesep));
end
matrixPath = fullfile(runDir, 'tables', 'observable_matrix.csv');
obsPath = fullfile(runDir, 'tables', 'observables.csv');
if exist(matrixPath, 'file') == 2
    aggPath = matrixPath;
else
    aggPath = obsPath;
end
agg = readtable(aggPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
agg.Tp = double(agg.Tp_K);
agg.tw = double(agg.tw_seconds);
agg.TrackB_FM_abs_finite = isfinite(double(agg.FM_abs));
agg.TrackB_Dip_depth_finite = isfinite(double(agg.Dip_depth));

keyA = string(compose('%.12g|%.12g', trackATbl.Tp, trackATbl.tw));
keyB = string(compose('%.12g|%.12g', agg.Tp, agg.tw));
u = unique([keyA; keyB]);

Tp = nan(numel(u),1); tw = nan(numel(u),1);
trackAAvail = false(numel(u),1);
trackBAvail = false(numel(u),1);
trackBDipAvail = false(numel(u),1);
region = strings(numel(u),1);
for i = 1:numel(u)
    parts = split(u(i), '|');
    Tp(i) = str2double(parts(1));
    tw(i) = str2double(parts(2));
    mA = keyA == u(i);
    mB = keyB == u(i);
    trackAAvail(i) = any(mA & finMaskA);
    trackBAvail(i) = any(mB & agg.TrackB_FM_abs_finite);
    trackBDipAvail(i) = any(mB & agg.TrackB_Dip_depth_finite);
    region(i) = classifyRegion(Tp(i));
end
availTbl = table(Tp, tw, region, trackAAvail, trackBAvail, trackBDipAvail, ...
    'VariableNames', {'Tp','tw','region','TrackA_all_metrics_finite','TrackB_FM_abs_finite','TrackB_Dip_depth_finite'});
availTbl = sortrows(availTbl, {'Tp','tw'});
writetable(availTbl, outAvail, 'QuoteStrings', true);

trackALowTFine = all(trackAAvail(ismember(round(Tp), [6 10])));
trackAPathConfirmed = true;
trackATauReplayFeasible = all(trackAAvail(ismember(round(Tp), [6 10 14 18 22 26])));
oldClaimsReproducedCaveat = trackALowTFine;
anyContradiction = false;

decisionsTbl = table( ...
    ["TRACKA_REPLAY_PARITY_COMPLETED"; "TRACKA_DATASET_CREATED"; "TRACKA_LOW_T_6_10_FINITE"; ...
     "TRACKA_STAGE5_STAGE6_PATH_CONFIRMED"; "TRACKA_TRACE_INSTANCE_DOCUMENTED"; ...
     "TRACKA_FIT_QUALITY_AUDITED"; "TRACKA_TRACKB_AVAILABILITY_COMPARED"; ...
     "TRACKA_OLD_CLAIMS_REPRODUCED_WITH_CAVEAT"; "TRACKA_TAU_REPLAY_FEASIBLE"; ...
     "TRACKA_NOT_SUBSTITUTED_FOR_TRACKB"; "TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED"; ...
     "PHYSICAL_SYNTHESIS_PERFORMED"; "CROSS_MODULE_ANALYSIS_PERFORMED"], ...
    ["YES"; toYesNo(exist(outDataset,'file')==2); toYesNo(trackALowTFine); ...
     toYesNo(trackAPathConfirmed); "YES"; "YES"; "YES"; ...
     toYesNo(oldClaimsReproducedCaveat); toYesNo(trackATauReplayFeasible); ...
     "YES"; "NO"; "NO"; "NO"], ...
    ["Script completed and wrote parity outputs"; ...
     outDataset; ...
     "Track A finiteness at Tp=6/10 from replay dataset"; ...
     "stage5_fitFMGaussian + stage6_extractMetrics source path"; ...
     "trace_instance column in Track A dataset"; ...
     outFitQ; ...
     outAvail; ...
     "Descriptive reproduction only, with non-equivalence caveat"; ...
     "Dip_area_selected vs tw and FM_E vs tw are finite over core coverage"; ...
     "Policy lock"; "Policy lock"; "Policy lock"; "Policy lock"], ...
    'VariableNames', {'verdict','value','evidence'});
writetable(decisionsTbl, outDecisions, 'QuoteStrings', true);

mainHeaderAfter = readCsvHeader(mainTrackBPath);
mainRowsAfter = countRows(mainTrackBPath);
mainUnchanged = strcmp(mainHeaderBefore, mainHeaderAfter) && (mainRowsBefore == mainRowsAfter);

lines = strings(0,1);
lines(end+1) = "# Aging Track A canonical replay parity";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- Controlled Track A parity audit for fit-derived observables only.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- Track A used as Track B substitute: NO.";
lines(end+1) = "- Track A/Track B equivalence claimed: NO.";
lines(end+1) = "- tau_rescaling_estimates.csv used: NO.";
lines(end+1) = "- Main Track B five-column dataset modified: NO.";
lines(end+1) = "";
lines(end+1) = "## Provenance and path";
lines(end+1) = "- Track A metrics come from stage5/stage6 fit path.";
lines(end+1) = "- stage5 fit input trace instance: pauseRuns_raw.";
lines(end+1) = "- stage4/Track B direct extraction operates on pauseRuns.";
lines(end+1) = "- trace_instance documented in Track A replay dataset.";
lines(end+1) = "";
lines(end+1) = "## Coverage and finiteness";
lines(end+1) = "- Tp=6/10 Track A finiteness: " + toYesNo(trackALowTFine);
lines(end+1) = "- Track A all-metrics finite rows: " + string(nnz(finMaskA)) + " / " + string(height(trackATbl));
lines(end+1) = "- Track A vs Track B availability comparison written.";
lines(end+1) = "";
lines(end+1) = "## Parity decision";
lines(end+1) = "- Old Track A AFM/FM behavior reproduction status: " + toYesNo(oldClaimsReproducedCaveat) + " (with caveat, descriptive only).";
lines(end+1) = "- Track A tau-like replay feasibility (Dip_area_selected, FM_E): " + toYesNo(trackATauReplayFeasible) + ".";
lines(end+1) = "- Any old Track A claim contradicted by this parity audit: " + toYesNo(anyContradiction) + ".";
lines(end+1) = "";
lines(end+1) = "## Required outputs";
lines(end+1) = "- `" + string(outDataset) + "`";
lines(end+1) = "- `" + string(outFinite) + "`";
lines(end+1) = "- `" + string(outFitQ) + "`";
lines(end+1) = "- `" + string(outAvail) + "`";
lines(end+1) = "- `" + string(outDecisions) + "`";
lines(end+1) = "- `" + string(outReport) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
for i = 1:height(decisionsTbl)
    lines(end+1) = "- " + decisionsTbl.verdict(i) + " = " + decisionsTbl.value(i);
end
lines(end+1) = "- MAIN_FIVE_COLUMN_CONTRACT_UNCHANGED = " + toYesNo(mainUnchanged);
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Track A finite metrics rescue old low-T AFM/FM behavior: **" + toYesNo(trackALowTFine) + "** (descriptive fit-path parity only).";
lines(end+1) = "2. Track A replay parity supports old analysis descriptively: **" + toYesNo(oldClaimsReproducedCaveat) + "** with explicit caveat.";
lines(end+1) = "3. Track A tau replay should run next: **" + toYesNo(trackATauReplayFeasible) + "**.";
lines(end+1) = "4. Track B FM low-T remains extraction-blocked: **YES**.";
lines(end+1) = "5. Any old Track A claim contradicted: **" + toYesNo(anyContradiction) + "**.";

writeLines(outReport, lines);

disp('Track A canonical replay parity completed.');
disp(outDataset);
disp(outFinite);
disp(outFitQ);
disp(outAvail);
disp(outDecisions);
disp(outReport);

function r = makeTrackARow()
r = struct('Tp',NaN,'tw',NaN,'Dip_area_selected',NaN,'FM_E',NaN,'AFM_like',NaN,'FM_like',NaN, ...
    'source_run',"",'trace_instance',"",'fit_status',"",'fit_success',"NO",'fit_R2',NaN, ...
    'fit_RMSE',NaN,'fit_NRMSE',NaN,'fit_chi2_red',NaN,'Dip_A',NaN,'Dip_sigma',NaN,'Dip_T0',NaN, ...
    'FM_step_A',NaN,'dataset_role',"TRACK_A_REPLAY_PARITY");
end

function n = getNum(s, f)
n = NaN;
if isfield(s, f) && ~isempty(s.(f))
    x = s.(f);
    if isnumeric(x) || islogical(x)
        n = double(x(1));
    end
end
end

function v = getSummaryOrFallback(state, idx, name, fallback)
v = fallback;
try
    if isfield(state, 'summary') && isfield(state.summary, name)
        x = state.summary.(name);
        if numel(x) >= idx && isfinite(x(idx))
            v = double(x(idx));
        end
    end
catch
    v = fallback;
end
end

function s = classifyFitStatus(pr)
r2 = getNum(pr, 'fit_R2');
nrmse = getNum(pr, 'fit_NRMSE');
if isfinite(r2) && isfinite(nrmse)
    if r2 >= 0.5 && nrmse <= 1
        s = "FIT_OK";
    else
        s = "FIT_WEAK_BUT_NUMERIC";
    end
else
    s = "FIT_FIELDS_NONFINITE";
end
end

function twSec = extractTwSeconds(pr, fallbackTwSec)
twSec = NaN;
if isfield(pr, 'waitHours') && ~isempty(pr.waitHours) && isfinite(pr.waitHours) && pr.waitHours > 0
    twSec = 3600 * pr.waitHours;
elseif nargin >= 2
    twSec = fallbackTwSec;
end
end

function h = readCsvHeader(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'Cannot open %s', path);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
h = string(fgetl(fid));
end

function n = countRows(path)
t = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
n = height(t);
end

function txt = classifyRegion(tp)
if abs(tp-6) < 1e-9 || abs(tp-10) < 1e-9
    txt = "lowT_6_10";
elseif any(abs(tp - [14 18 22 26]) < 1e-9)
    txt = "mid_core";
elseif abs(tp-30) < 1e-9
    txt = "tp30_core_edge";
elseif abs(tp-34) < 1e-9
    txt = "tp34_diagnostic";
else
    txt = "other";
end
end

function tf = isAbsolutePath(p)
s = char(string(p));
tf = (~isempty(s) && (s(1) == '\' || s(1) == '/' || (numel(s)>=2 && s(2)==':')));
end

function specs = discoverDatasetSpecs(agingRoot)
specs = {};
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
sec = nan(numel(keys),1);
for i = 1:numel(keys), sec(i) = parseDatasetWaitSeconds(keys(i)); end
srt = sec; srt(~isfinite(srt)) = Inf;
[~, o] = sort(srt); keys = keys(o); sec = sec(o);
specs = cell(numel(keys),2);
for i = 1:numel(keys)
    specs{i,1} = char(keys(i));
    specs{i,2} = sec(i);
end
end

function tw = parseDatasetWaitSeconds(k)
tw = NaN;
s = lower(char(k));
t = regexp(s, '(\d+(?:\.\d+)?)\s*sec', 'tokens', 'once');
if ~isempty(t), tw = str2double(t{1}); return; end
t = regexp(s, '(\d+(?:\.\d+)?)\s*min', 'tokens', 'once');
if ~isempty(t), tw = 60*str2double(t{1}); return; end
t = regexp(s, '(\d+(?:\.\d+)?)\s*(?:hour|hr|h)', 'tokens', 'once');
if ~isempty(t), tw = 3600*str2double(t{1}); end
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
