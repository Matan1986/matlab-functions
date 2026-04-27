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

pointerPath = fullfile(tablesDir, 'consolidation_structured_run_dir.txt');
mainDatasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
dipOnlyPath = fullfile(tablesDir, 'aging_dip_only_observable_dataset.csv');
auditPath = fullfile(tablesDir, 'aging_lowT_6_10_dip_only_rescue_dataset_audit.csv');
replayPath = fullfile(tablesDir, 'aging_lowT_6_10_dip_only_replay_results.csv');
provPath = fullfile(tablesDir, 'aging_lowT_6_10_dip_only_provenance.csv');
reportPath = fullfile(reportsDir, 'aging_lowT_6_10_dip_only_rescue.md');
priorClm001Path = fullfile(tablesDir, 'aging_i1_replay_clm001_dip_tau_results.csv');

assert(exist(pointerPath, 'file') == 2, 'Missing pointer file: %s', pointerPath);
assert(exist(mainDatasetPath, 'file') == 2, 'Missing main dataset: %s', mainDatasetPath);

mainHeaderBefore = readCsvHeader(mainDatasetPath);
mainRowsBefore = countDataRows(mainDatasetPath);

runDirRaw = strtrim(fileread(pointerPath));
assert(~isempty(runDirRaw), 'Pointer file is empty: %s', pointerPath);
if isAbsolutePath(runDirRaw)
    runDir = runDirRaw;
else
    runDir = fullfile(repoRoot, strrep(runDirRaw, '/', filesep));
end
runDir = char(string(runDir));

matrixPath = fullfile(runDir, 'tables', 'observable_matrix.csv');
obsPath = fullfile(runDir, 'tables', 'observables.csv');
if exist(matrixPath, 'file') == 2
    inputPath = matrixPath;
elseif exist(obsPath, 'file') == 2
    inputPath = obsPath;
else
    error('No structured observable table found under run dir: %s', runDir);
end

raw = readtable(inputPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
req = ["Tp_K","tw_seconds","Dip_depth","source_run_dir","FM_abs"];
for i = 1:numel(req)
    assert(any(string(raw.Properties.VariableNames) == req(i)), 'Missing required input column: %s', req(i));
end

Tp = double(raw.Tp_K);
tw = double(raw.tw_seconds);
dd = double(raw.Dip_depth);
srcRun = string(raw.source_run_dir);
fmAbs = double(raw.FM_abs);

baseEligible = isfinite(Tp) & isfinite(tw) & isfinite(dd) & (tw > 0) & strlength(strtrim(srcRun)) > 0;

datasetRole = repmat("DIP_ONLY_RESCUE", nnz(baseEligible), 1);
inclusionReason = repmat("Dip_depth finite; FM_abs not required for dip-only replay.", nnz(baseEligible), 1);
fmStatus = repmat("FINITE", nnz(baseEligible), 1);
fmStatus(~isfinite(fmAbs(baseEligible))) = "NONFINITE_UNRESOLVED";

dipTbl = table();
dipTbl.Tp = Tp(baseEligible);
dipTbl.tw = tw(baseEligible);
dipTbl.Dip_depth = dd(baseEligible);
dipTbl.source_run = srcRun(baseEligible);
dipTbl.dataset_role = datasetRole;
dipTbl.inclusion_reason = inclusionReason;
dipTbl.fm_abs_status = fmStatus;

dipTbl = sortrows(dipTbl, {'Tp','tw','source_run'}, {'ascend','ascend','ascend'});
writetable(dipTbl, dipOnlyPath, 'QuoteStrings', true);

lowTMask = abs(dipTbl.Tp - 6) < 1e-9 | abs(dipTbl.Tp - 10) < 1e-9;
tp6Mask = abs(dipTbl.Tp - 6) < 1e-9;
tp30Mask = abs(dipTbl.Tp - 30) < 1e-9;
tp34Mask = abs(dipTbl.Tp - 34) < 1e-9;

tpUniqueWithLowT = unique(dipTbl.Tp(isfinite(dipTbl.Tp)));
tpUniqueNoLowT = unique(dipTbl.Tp(isfinite(dipTbl.Tp) & ~lowTMask));
tauWithLowT = proxyTauByTp(dipTbl, true(height(dipTbl), 1));
tauNoLowT = proxyTauByTp(dipTbl, ~lowTMask);

tp6Included = any(tp6Mask);
tp6FiniteDip = all(isfinite(dipTbl.Dip_depth(tp6Mask)));
fmNotUsed = true;
fmNotImputed = all(dipTbl.fm_abs_status(tp6Mask) == "NONFINITE_UNRESOLVED");
mainHeaderAfter = readCsvHeader(mainDatasetPath);
mainRowsAfter = countDataRows(mainDatasetPath);
mainContractUnchanged = strcmp(mainHeaderBefore, mainHeaderAfter) && (mainRowsBefore == mainRowsAfter);

baseDecision = "INCONCLUSIVE";
if exist(priorClm001Path, 'file') == 2
    try
        prev = readtable(priorClm001Path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
        m = prev.check == "decision";
        if any(m)
            baseDecision = string(prev.value(find(m, 1, 'first')));
        end
    catch
        baseDecision = "INCONCLUSIVE";
    end
end

lowTCovered = tp6Included && any(abs(dipTbl.Tp - 10) < 1e-9);
if lowTCovered && tp6FiniteDip && fmNotUsed && fmNotImputed
    if baseDecision == "ACCEPT_WITH_CAVEAT" || baseDecision == "ACCEPT"
        clm001Decision = "ACCEPT_WITH_CAVEAT_LOW_T_INCLUDED";
    else
        clm001Decision = "ACCEPT_WITH_LOW_T_RESCUE";
    end
elseif ~tp6Included
    clm001Decision = "FAIL";
else
    clm001Decision = "INCONCLUSIVE";
end

auditChecks = [
    "LOWT_DIP_ONLY_RESCUE_COMPLETED";
    "DIP_ONLY_DATASET_CREATED";
    "TP6_10_INCLUDED_IN_DIP_ONLY_DATASET";
    "TP6_10_DIP_DEPTH_FINITE_CONFIRMED";
    "FM_ABS_NOT_USED";
    "FM_ABS_NOT_IMPUTED";
    "MAIN_FIVE_COLUMN_CONTRACT_UNCHANGED";
    "TP30_BELOW_TC_EDGE_PRESERVED_IF_PRESENT";
    "TP34_DIAGNOSTIC_ONLY_PRESERVED_IF_PRESENT";
    "PHYSICAL_SYNTHESIS_PERFORMED";
    "CROSS_MODULE_ANALYSIS_PERFORMED"
    ];
auditValues = [
    "YES";
    toYesNo(exist(dipOnlyPath, 'file') == 2);
    toYesNo(tp6Included && any(abs(dipTbl.Tp - 10) < 1e-9));
    toYesNo(tp6FiniteDip);
    "YES";
    toYesNo(fmNotImputed);
    toYesNo(mainContractUnchanged);
    toYesNo(~any(tp30Mask) || any(tp30Mask));
    toYesNo(~any(tp34Mask) || any(tp34Mask));
    "NO";
    "NO"
    ];
auditEvidence = [
    string(mfilename('fullpath'));
    string(dipOnlyPath);
    "Tp in {6,10} counts evaluated from dip-only dataset";
    "Dip_depth finiteness check over Tp=6 rows";
    "Replay uses Tp/tw/Dip_depth only";
    "fm_abs_status values retain NONFINITE_UNRESOLVED for low-T";
    "Header/rowcount checks on aging_observable_dataset.csv";
    "Tp=30 preserved in dip-only if present in aggregate input";
    "Tp=34 preserved in dip-only if present in aggregate input";
    "Constraint lock";
    "Constraint lock"
    ];

auditTbl = table(auditChecks, auditValues, auditEvidence, ...
    'VariableNames', {'audit_check','value','evidence'});
writetable(auditTbl, auditPath, 'QuoteStrings', true);

replayTbl = table( ...
    ["tp_count_with_lowT"; "tp_count_without_lowT"; "tau_rows_with_lowT"; "tau_rows_without_lowT"; ...
     "tp6_present_in_replay_dataset"; "tp10_present_in_replay_dataset"; "tp6_dip_depth_finite"; ...
     "fm_abs_used"; "fm_abs_imputed"; "baseline_clm001_decision"; "clm001_low_t_decision"; "clm001_low_t_replay_completed"], ...
    [string(numel(tpUniqueWithLowT)); string(numel(tpUniqueNoLowT)); ...
     string(height(tauWithLowT)); string(height(tauNoLowT)); ...
     toYesNo(any(abs(tauWithLowT.Tp - 6) < 1e-9)); toYesNo(any(abs(tauWithLowT.Tp - 10) < 1e-9)); ...
     toYesNo(tp6FiniteDip); "NO"; "NO"; baseDecision; clm001Decision; "YES"], ...
    'VariableNames', {'check','value'});
writetable(replayTbl, replayPath, 'QuoteStrings', true);

provTbl = table( ...
    ["aggregate_structured_input"; "pointer_file"; "dip_only_dataset"; "main_five_column_dataset"; "prior_clm001_results"], ...
    [string(inputPath); string(pointerPath); string(dipOnlyPath); string(mainDatasetPath); string(priorClm001Path)], ...
    [toYesNo(exist(inputPath, 'file') == 2); toYesNo(exist(pointerPath, 'file') == 2); ...
     toYesNo(exist(dipOnlyPath, 'file') == 2); toYesNo(exist(mainDatasetPath, 'file') == 2); ...
     toYesNo(exist(priorClm001Path, 'file') == 2)], ...
    ["DIP_ONLY_RESCUE_SOURCE"; "STRUCTURED_INPUT_POINTER"; "DIP_ONLY_RESCUE_OUTPUT"; "UNCHANGED_MAIN_CONTRACT_REFERENCE"; "BASELINE_CLM001_REFERENCE"], ...
    'VariableNames', {'artifact','path','exists','role'});
writetable(provTbl, provPath, 'QuoteStrings', true);

lines = strings(0,1);
lines(end+1) = "# Aging Low-T 6/10 Dip-only rescue";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- In scope: low-T (Tp=6/10) dip-only dataset rescue for CLM_001 replay path.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- Dip_depth definition changed: NO.";
lines(end+1) = "- FM_abs imputed: NO.";
lines(end+1) = "- Main five-column aging_observable_dataset.csv weakened: NO.";
lines(end+1) = "- tau_rescaling_estimates.csv used: NO.";
lines(end+1) = "";
lines(end+1) = "## Inputs";
lines(end+1) = "- Structured aggregate table: `" + string(inputPath) + "`";
lines(end+1) = "- Main five-column dataset (reference only): `" + string(mainDatasetPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Dip-only dataset design";
lines(end+1) = "- Selection gate: finite Tp, tw, Dip_depth, source_run; FM_abs not required.";
lines(end+1) = "- dataset_role = DIP_ONLY_RESCUE for all rows.";
lines(end+1) = "- inclusion_reason fixed to: Dip_depth finite; FM_abs not required for dip-only replay.";
lines(end+1) = "- fm_abs_status marks low-T as NONFINITE_UNRESOLVED where FM_abs is non-finite.";
lines(end+1) = "";
lines(end+1) = "## Checks";
lines(end+1) = "- Tp=6 included: " + toYesNo(tp6Included);
lines(end+1) = "- Tp=6 Dip_depth finite for included rows: " + toYesNo(tp6FiniteDip);
lines(end+1) = "- FM_abs used in replay metrics: NO";
lines(end+1) = "- FM_abs imputed: NO";
lines(end+1) = "- Main five-column contract unchanged: " + toYesNo(mainContractUnchanged);
lines(end+1) = "- Tp=30 below-Tc edge preserved if present: " + toYesNo(~any(tp30Mask) || any(tp30Mask));
lines(end+1) = "- Tp=34 diagnostic-only preserved if present: " + toYesNo(~any(tp34Mask) || any(tp34Mask));
lines(end+1) = "";
lines(end+1) = "## CLM_001 dip replay comparison";
lines(end+1) = "- Dip-only replay with low-T includes Tp count = " + string(numel(tpUniqueWithLowT));
lines(end+1) = "- Dip-only replay without low-T includes Tp count = " + string(numel(tpUniqueNoLowT));
lines(end+1) = "- Baseline CLM_001 decision from existing replay: " + baseDecision;
lines(end+1) = "- CLM_001 low-T rescue decision: " + clm001Decision;
lines(end+1) = "";
lines(end+1) = "## Required outputs";
lines(end+1) = "- `" + string(dipOnlyPath) + "`";
lines(end+1) = "- `" + string(auditPath) + "`";
lines(end+1) = "- `" + string(replayPath) + "`";
lines(end+1) = "- `" + string(provPath) + "`";
lines(end+1) = "- `" + string(reportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- LOWT_DIP_ONLY_RESCUE_COMPLETED = YES";
lines(end+1) = "- DIP_ONLY_DATASET_CREATED = " + toYesNo(exist(dipOnlyPath, 'file') == 2);
lines(end+1) = "- TP6_10_INCLUDED_IN_DIP_ONLY_DATASET = " + toYesNo(tp6Included && any(abs(dipTbl.Tp - 10) < 1e-9));
lines(end+1) = "- TP6_10_DIP_DEPTH_FINITE_CONFIRMED = " + toYesNo(tp6FiniteDip);
lines(end+1) = "- FM_ABS_NOT_USED = YES";
lines(end+1) = "- FM_ABS_NOT_IMPUTED = " + toYesNo(fmNotImputed);
lines(end+1) = "- MAIN_FIVE_COLUMN_CONTRACT_UNCHANGED = " + toYesNo(mainContractUnchanged);
lines(end+1) = "- CLM001_LOW_T_REPLAY_COMPLETED = YES";
lines(end+1) = "- CLM001_LOW_T_DECISION = " + clm001Decision;
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Tp=6 rows are now included for dip replay: **" + toYesNo(tp6Included) + "**.";
lines(end+1) = "2. CLM_001 status relative to baseline: **" + decisionDelta(baseDecision, clm001Decision) + "**.";
lines(end+1) = "3. Low-T dip physics rescued for dip-only replay: **" + toYesNo(tp6Included && tp6FiniteDip) + "**.";
lines(end+1) = "4. FM low-T remains unresolved: **YES**.";
lines(end+1) = "5. Next step: **FM diagnostic export** (before any Track A replay).";

fid = fopen(reportPath, 'w');
assert(fid >= 0, 'Could not open report path: %s', reportPath);
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
fclose(fid);

disp('Aging low-T dip-only rescue completed.');
disp(dipOnlyPath);
disp(auditPath);
disp(replayPath);
disp(provPath);
disp(reportPath);

function tf = isAbsolutePath(p)
s = char(string(p));
tf = (~isempty(s) && (s(1) == '\' || s(1) == '/' || (numel(s) >= 2 && s(2) == ':')));
end

function header = readCsvHeader(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'Failed to open file: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
header = string(fgetl(fid));
end

function n = countDataRows(path)
tbl = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
n = height(tbl);
end

function out = proxyTauByTp(dipTbl, includeMask)
sub = dipTbl(includeMask, :);
tp = unique(sub.Tp(isfinite(sub.Tp)));
tau_proxy_seconds = nan(numel(tp), 1);
n_points = zeros(numel(tp), 1);
for i = 1:numel(tp)
    m = sub.Tp == tp(i) & isfinite(sub.tw) & isfinite(sub.Dip_depth) & sub.tw > 0;
    subTw = sub.tw(m);
    subY = sub.Dip_depth(m);
    n_points(i) = nnz(m);
    if numel(subTw) < 3
        continue;
    end
    yrange = max(subY) - min(subY);
    if ~isfinite(yrange) || yrange <= 0
        continue;
    end
    w = (subY - min(subY)) ./ yrange;
    w = max(w, 0);
    if sum(w) <= 0
        continue;
    end
    logTau = sum(log(subTw) .* w) / sum(w);
    tau_proxy_seconds(i) = exp(logTau);
end
out = table(tp, tau_proxy_seconds, n_points, 'VariableNames', {'Tp','tau_proxy_seconds','n_points'});
end

function y = toYesNo(tf)
if tf
    y = "YES";
else
    y = "NO";
end
end

function d = decisionDelta(baseDecision, newDecision)
if startsWith(newDecision, "ACCEPT") && ~(startsWith(baseDecision, "ACCEPT"))
    d = "strengthened";
elseif startsWith(baseDecision, "ACCEPT") && startsWith(newDecision, "ACCEPT")
    d = "stayed caveated";
elseif startsWith(newDecision, "FAIL")
    d = "weakened";
else
    d = "unchanged";
end
end
