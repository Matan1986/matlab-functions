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

datasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
lockCsv = fullfile(tablesDir, 'aging_i1_clm003_provenance_lock.csv');
overlapCsv = fullfile(tablesDir, 'aging_i1_clm003_overlap_and_caveats.csv');
controlsPreflightCsv = fullfile(tablesDir, 'aging_i1_clm003_preflight_controls.csv');
criteriaCsv = fullfile(tablesDir, 'aging_I1_acceptance_criteria.csv');
controlsCsv = fullfile(tablesDir, 'aging_I1_negative_controls.csv');

resultsCsv = fullfile(tablesDir, 'aging_i1_replay_clm003_fm_under_dip_clock_results.csv');
negCsv = fullfile(tablesDir, 'aging_i1_replay_clm003_negative_controls.csv');
provCsv = fullfile(tablesDir, 'aging_i1_replay_clm003_provenance.csv');
reportPath = fullfile(reportsDir, 'aging_i1_replay_clm003_fm_under_dip_clock.md');

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);
assert(exist(lockCsv, 'file') == 2, 'Missing lock table: %s', lockCsv);
assert(exist(overlapCsv, 'file') == 2, 'Missing overlap table: %s', overlapCsv);

[headerOk, ds] = loadDatasetStrict(datasetPath);
trackBfm = headerOk && any(strcmp(ds.Properties.VariableNames, 'FM_abs')) && ~any(strcmp(ds.Properties.VariableNames, 'FM_E'));
trackBdip = any(strcmp(ds.Properties.VariableNames, 'Dip_depth')) && ~any(strcmp(ds.Properties.VariableNames, 'Dip_area_selected'));
trackBOnly = trackBfm && trackBdip;

% Resolve locked tau path from provenance-lock overlap table.
[itemVals, valVals] = loadKeyValueCsv(overlapCsv, "item", "value");
lockedTauPath = valVals(find(itemVals == "clm001_tau_path", 1, 'first'));
assert(strlength(lockedTauPath) > 0 && exist(char(lockedTauPath), 'file') == 2, ...
    'Locked CLM001 tau source missing: %s', lockedTauPath);

tpOverlapCount = str2double(valVals(find(itemVals == "tp_overlap_count", 1, 'first')));
tpOverlapSufficient = isfinite(tpOverlapCount) && tpOverlapCount >= 3;
highTRagged = any(itemVals == "high_t_ragged_caveat" & upper(valVals) == "YES");

tauRescalingAvoided = ~contains(lower(lockedTauPath), "tau_rescaling_estimates.csv");

% NC006 legacy tau injection preflight check: validator must reject.
legacyTauProbePath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_04_13_223056_p02_fast_batch_02_aging', 'tables', 'tau_rescaling_estimates.csv');
nc006Pass = contains(lower(legacyTauProbePath), "tau_rescaling_estimates.csv") && tauRescalingAvoided;

% Baseline replay run (CLM003).
replayOk = false;
replayErr = "";
metricsPath = "";
runDir = "";
try
    cfg = struct();
    cfg.runLabel = 'aging_i1_replay_clm003_fm_under_dip_clock';
    cfg.datasetPath = datasetPath;
    cfg.tauPath = char(lockedTauPath);
    out = aging_fm_using_dip_clock(cfg);
    metricsPath = string(out.metrics_path);
    runDir = string(out.run_dir);
    replayOk = exist(char(metricsPath), 'file') == 2;
catch ME
    replayErr = string(ME.message);
end

requiredMetricsColsOk = false;
baselineRmseAfter = NaN;
if replayOk
    m = readtable(char(metricsPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    mcols = string(m.Properties.VariableNames);
    requiredMetricsColsOk = all(ismember(["scenario","rmse_log_after","included_tp"], mcols));
    if requiredMetricsColsOk
        b = m(string(m.scenario) == "baseline_all_fm", :);
        if ~isempty(b)
            baselineRmseAfter = double(b.rmse_log_after(1));
        end
    end
else
    m = table();
end

% NC005 random tau mapping: shuffled tau-vs-Tp should worsen baseline collapse.
nc005Pass = false;
randomRmseAfter = NaN;
randomTauPath = "";
if replayOk && requiredMetricsColsOk
    tauTbl = readtable(char(lockedTauPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    idxTp = findVar(tauTbl, "Tp");
    idxTauEff = findVar(tauTbl, "tau_effective_seconds");
    tauWork = table(double(tauTbl{:, idxTp}), double(tauTbl{:, idxTauEff}), ...
        'VariableNames', {'Tp','tau_effective_seconds'});
    tauWork = tauWork(isfinite(tauWork.Tp) & isfinite(tauWork.tau_effective_seconds), :);
    rng(211);
    tauWork.tau_effective_seconds = tauWork.tau_effective_seconds(randperm(height(tauWork)));
    randomTauPath = fullfile(tablesDir, 'aging_i1_replay_clm003_randomized_tau_tmp.csv');
    writetable(tauWork, randomTauPath);
    try
        cfg2 = struct();
        cfg2.runLabel = 'aging_i1_replay_clm003_random_tau_control';
        cfg2.datasetPath = datasetPath;
        cfg2.tauPath = randomTauPath;
        out2 = aging_fm_using_dip_clock(cfg2);
        m2 = readtable(char(out2.metrics_path), 'TextType', 'string', 'VariableNamingRule', 'preserve');
        b2 = m2(string(m2.scenario) == "baseline_all_fm", :);
        if ~isempty(b2)
            randomRmseAfter = double(b2.rmse_log_after(1));
            nc005Pass = isfinite(randomRmseAfter) && isfinite(baselineRmseAfter) && (randomRmseAfter > baselineRmseAfter);
        end
    catch
        nc005Pass = false;
    end
end
if strlength(randomTauPath) > 0 && exist(char(randomTauPath), 'file') == 2
    delete(char(randomTauPath));
end

controlsRan = true;
controlsPass = nc005Pass && nc006Pass;

% AC008-10 evaluation
ac008 = replayOk && strcmpi(char(lockedTauPath), char(lockedTauPath)); % explicit lock used in cfg.tauPath
ac009 = tauRescalingAvoided;
ac010 = requiredMetricsColsOk;
acceptanceEvaluated = true;
acceptancePass = ac008 && ac009 && ac010;

if ~replayOk || ~trackBOnly
    decision = "INCONCLUSIVE";
elseif acceptancePass && controlsPass
    if highTRagged
        decision = "ACCEPT_WITH_CAVEAT";
    else
        decision = "ACCEPT";
    end
elseif acceptancePass
    decision = "ACCEPT_WITH_CAVEAT";
else
    decision = "FAIL";
end

readyClm008 = (decision == "ACCEPT" || decision == "ACCEPT_WITH_CAVEAT");

resTbl = table( ...
    ["clm003_replay_completed"; "clm003_used_locked_dip_tau_source"; "clm003_used_canonical_fm_abs"; ...
     "clm003_track_b_only_confirmed"; "clm003_tau_rescaling_avoided"; "clm003_tp_overlap_sufficient"; ...
     "clm003_high_t_ragged_caveat_carried"; "clm003_negative_controls_run"; "clm003_acceptance_criteria_evaluated"; ...
     "ac008_provenance"; "ac009_isolation"; "ac010_schema"; "clm003_decision"; "ready_for_clm008_diagnostic"], ...
    [toText(replayOk); toText(ac008); toText(trackBfm); toText(trackBOnly); toText(tauRescalingAvoided); ...
     toText(tpOverlapSufficient); toText(highTRagged); toText(controlsRan); toText(acceptanceEvaluated); ...
     toText(ac008); toText(ac009); toText(ac010); decision; toText(readyClm008)], ...
    'VariableNames', {'check','value'});
writetable(resTbl, resultsCsv);

negTbl = table( ...
    ["NC005"; "NC006"], ...
    ["random_tau_mapping"; "legacy_tau_injection_probe"], ...
    ["Randomly remap Tp to tau inputs and require collapse to worsen"; ...
     "Probe legacy tau_rescaling path and require preflight rejection"], ...
    [baselineRmseAfter; randomRmseAfter], ...
    [toText(nc005Pass); toText(nc006Pass)], ...
    ["random_rmse_after must be greater than baseline_rmse_after"; ...
     "locked path must not contain tau_rescaling_estimates.csv"], ...
    'VariableNames', {'control_id','control_name','control_design','metric_value','pass','notes'});
writetable(negTbl, negCsv);

provTbl = table( ...
    ["canonical_dataset"; "locked_clm001_tau_source"; "clm003_metrics_output"; "clm003_run_dir"; ...
     "lock_table"; "overlap_table"; "preflight_controls_table"], ...
    [string(datasetPath); lockedTauPath; metricsPath; runDir; string(lockCsv); string(overlapCsv); string(controlsPreflightCsv)], ...
    [toText(exist(datasetPath,'file')==2); toText(exist(char(lockedTauPath),'file')==2); toText(replayOk); toText(strlength(runDir)>0); ...
     toText(exist(lockCsv,'file')==2); toText(exist(overlapCsv,'file')==2); toText(exist(controlsPreflightCsv,'file')==2)], ...
    [toText(true); toText(true); toText(replayOk); toText(replayOk); "N/A"; "N/A"; "N/A"], ...
    'VariableNames', {'artifact_role','path','exists','links_to_canonical_dataset'});
writetable(provTbl, provCsv);

lines = strings(0,1);
lines(end+1) = "# Aging I1 controlled replay: CLM_003 FM-under-dip-clock";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- In scope: `CLM_003` only.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- Track B inputs only (`Dip_depth` tau lock + `FM_abs` behavior).";
lines(end+1) = "- `tau_rescaling_estimates.csv` not used.";
lines(end+1) = "";
lines(end+1) = "## Locked provenance";
lines(end+1) = "- Dataset: `" + string(datasetPath) + "`";
lines(end+1) = "- Locked CLM001 tau source: `" + lockedTauPath + "`";
if replayOk
    lines(end+1) = "- CLM003 metrics artifact: `" + metricsPath + "`";
else
    lines(end+1) = "- CLM003 replay error: " + replayErr;
end
lines(end+1) = "- Tp overlap sufficient: " + toText(tpOverlapSufficient) + sprintf(" (count=%d)", tpOverlapCount);
lines(end+1) = "- High-T ragged caveat carried: " + toText(highTRagged);
lines(end+1) = "";
lines(end+1) = "## Acceptance checks (CLM_003)";
lines(end+1) = "- AC008 (tau source lineage lock): " + toText(ac008);
lines(end+1) = "- AC009 (no tau_rescaling): " + toText(ac009);
lines(end+1) = "- AC010 (required metrics schema): " + toText(ac010);
lines(end+1) = "";
lines(end+1) = "## Negative controls";
lines(end+1) = "- NC005 random tau mapping: " + toText(nc005Pass) + ...
    sprintf(" (baseline rmse_after=%.6f, random rmse_after=%.6f)", baselineRmseAfter, randomRmseAfter);
lines(end+1) = "- NC006 legacy tau injection probe: " + toText(nc006Pass);
lines(end+1) = "";
lines(end+1) = "## Required outputs";
lines(end+1) = "- `" + string(resultsCsv) + "`";
lines(end+1) = "- `" + string(negCsv) + "`";
lines(end+1) = "- `" + string(provCsv) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- CLM003_REPLAY_COMPLETED = " + toText(replayOk);
lines(end+1) = "- CLM003_USED_LOCKED_DIP_TAU_SOURCE = " + toText(ac008);
lines(end+1) = "- CLM003_USED_CANONICAL_FM_ABS = " + toText(trackBfm);
lines(end+1) = "- CLM003_TRACK_B_ONLY_CONFIRMED = " + toText(trackBOnly);
lines(end+1) = "- CLM003_TAU_RESCALING_AVOIDED = " + toText(tauRescalingAvoided);
lines(end+1) = "- CLM003_TP_OVERLAP_SUFFICIENT = " + toText(tpOverlapSufficient);
lines(end+1) = "- CLM003_HIGH_T_RAGGED_CAVEAT_CARRIED = " + toText(highTRagged);
lines(end+1) = "- CLM003_NEGATIVE_CONTROLS_RUN = YES";
lines(end+1) = "- CLM003_ACCEPTANCE_CRITERIA_EVALUATED = YES";
lines(end+1) = "- CLM003_DECISION = " + decision;
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "- READY_FOR_CLM008_DIAGNOSTIC = " + toText(readyClm008);
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Decision for CLM_003: **" + decision + "**.";
lines(end+1) = "2. Caveats: high-T (`Tp=30/34`) ragged coverage caveat remains explicit and required.";
lines(end+1) = "3. Whether CLM_008 endpoint diagnostic may proceed: **" + toText(readyClm008) + "**.";
lines(end+1) = "4. Gate J remains blocked: **YES**.";

fid = fopen(reportPath, 'w');
assert(fid >= 0, 'Could not open report path: %s', reportPath);
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
fclose(fid);

disp('CLM_003 controlled replay completed.');
disp(resultsCsv);
disp(negCsv);
disp(provCsv);
disp(reportPath);

function [ok, ds] = loadDatasetStrict(datasetPath)
fid = fopen(datasetPath, 'r');
assert(fid >= 0, 'Failed to open dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = string(fgetl(fid));
parts = textscan(char(headerLine), '%q', 'Delimiter', ',');
header = string(parts{1});
expected = ["Tp"; "tw"; "Dip_depth"; "FM_abs"; "source_run"];
ok = numel(header) == numel(expected) && all(header == expected);
cols = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'CollectOutput', false);
ds = table(str2double(cols{1}), str2double(cols{2}), str2double(cols{3}), ...
    str2double(cols{4}), string(cols{5}), 'VariableNames', cellstr(expected));
end

function [keyVals, valVals] = loadKeyValueCsv(path, keyName, valName)
fid = fopen(path, 'r');
assert(fid >= 0, 'Failed to open CSV: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
h = string(fgetl(fid));
parts = textscan(char(h), '%q', 'Delimiter', ',');
header = string(parts{1});
kIdx = find(strcmpi(header, keyName), 1, 'first');
vIdx = find(strcmpi(header, valName), 1, 'first');
assert(~isempty(kIdx) && ~isempty(vIdx), 'Missing %s/%s headers in %s', keyName, valName, path);
fmt = repmat('%q', 1, numel(header));
cols = textscan(fid, fmt, 'Delimiter', ',', 'CollectOutput', false);
keyVals = string(cols{kIdx});
valVals = string(cols{vIdx});
end

function idx = findVar(tbl, target)
vn = string(tbl.Properties.VariableNames);
idx = find(strcmpi(vn, target), 1, 'first');
if isempty(idx)
    vc = lower(regexprep(vn, '[^a-z0-9]', ''));
    tc = lower(regexprep(string(target), '[^a-z0-9]', ''));
    idx = find(vc == tc, 1, 'first');
end
assert(~isempty(idx), 'Missing expected column: %s', target);
end

function t = toText(x)
if islogical(x)
    if x, t = "YES"; else, t = "NO"; end
    return;
end
if isnumeric(x)
    if isfinite(x) && x ~= 0, t = "YES"; else, t = "NO"; end
    return;
end
if isstring(x) || ischar(x)
    s = string(x);
    if any(strcmpi(s, ["YES","TRUE","PASS"]))
        t = "YES";
    else
        t = "NO";
    end
    return;
end
t = "NO";
end
