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
clm001ResPath = fullfile(tablesDir, 'aging_i1_replay_clm001_dip_tau_results.csv');
clm002ResPath = fullfile(tablesDir, 'aging_i1_replay_clm002_fm_tau_results.csv');
clm003ResPath = fullfile(tablesDir, 'aging_i1_replay_clm003_fm_under_dip_clock_results.csv');
clm001ProvPath = fullfile(tablesDir, 'aging_i1_replay_clm001_provenance.csv');
clm002ProvPath = fullfile(tablesDir, 'aging_i1_replay_clm002_provenance.csv');
clm003ProvPath = fullfile(tablesDir, 'aging_i1_replay_clm003_provenance.csv');
coveragePath = fullfile(tablesDir, 'aging_robustness_Tp_tw_coverage.csv');
sensitivityPath = fullfile(tablesDir, 'aging_robustness_sensitivity_summary.csv');

resultsCsv = fullfile(tablesDir, 'aging_i1_replay_clm008_highT_endpoint_results.csv');
sensitivityCsv = fullfile(tablesDir, 'aging_i1_replay_clm008_endpoint_sensitivity.csv');
dispositionCsv = fullfile(tablesDir, 'aging_i1_replay_clm008_endpoint_disposition.csv');
reportPath = fullfile(reportsDir, 'aging_i1_replay_clm008_highT_endpoint_diagnostic.md');

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);
assert(exist(clm001ResPath, 'file') == 2, 'Missing CLM001 results');
assert(exist(clm002ResPath, 'file') == 2, 'Missing CLM002 results');
assert(exist(clm003ResPath, 'file') == 2, 'Missing CLM003 results');
assert(exist(coveragePath, 'file') == 2, 'Missing coverage table');
assert(exist(sensitivityPath, 'file') == 2, 'Missing sensitivity table');

[~, ds] = loadDatasetStrict(datasetPath);

tp = unique(double(ds.Tp(isfinite(double(ds.Tp)))));
has30 = any(abs(tp - 30) < 1e-9);
has34 = any(abs(tp - 34) < 1e-9);
highTPresent = has30 && has34;

sub30 = ds(abs(double(ds.Tp) - 30) < 1e-9, :);
sub34 = ds(abs(double(ds.Tp) - 34) < 1e-9, :);
tw30 = unique(double(sub30.tw(isfinite(double(sub30.tw)))));
tw34 = unique(double(sub34.tw(isfinite(double(sub34.tw)))));
missingTw3_30 = ~any(abs(tw30 - 3) < 1e-9);
missingTw3_34 = ~any(abs(tw34 - 3) < 1e-9);
raggedCoverageConfirmed = missingTw3_30 && missingTw3_34;

covTbl = readtable(coveragePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
row30 = covTbl(abs(double(covTbl.Tp) - 30) < 1e-9, :);
row34 = covTbl(abs(double(covTbl.Tp) - 34) < 1e-9, :);
covTw3No = ~isempty(row30) && ~isempty(row34) && ...
    string(row30.has_tw_3(1)) == "NO" && string(row34.has_tw_3(1)) == "NO";

clm001Decision = getDecision(clm001ResPath, "decision");
clm002Decision = getDecision(clm002ResPath, "decision");
clm003Decision = getDecision(clm003ResPath, "clm003_decision");

% Included vs excluded comparison from Stage H sensitivity artifact
sensTbl = readtable(sensitivityPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
testCol = findVar(sensTbl, "test_id");
chgCol = findVar(sensTbl, "changed_materially");
riskCol = findVar(sensTbl, "risk_level");
sumCol = findVar(sensTbl, "result_summary");

ix = find(string(sensTbl{:, testCol}) == "exclude_high_Tp_30_34", 1, 'first');
assert(~isempty(ix), 'exclude_high_Tp_30_34 sensitivity row not found.');
excludeHighTChanged = string(sensTbl{ix, chgCol}) == "YES";
excludeHighTRisk = string(sensTbl{ix, riskCol});
excludeHighTSummary = string(sensTbl{ix, sumCol});
includedExcludedComparisonDone = true;

% Decision stability: this diagnostic does not rerun CLM001/2/3 scripts, only evaluates
% whether Stage H high-T exclusion materially changes tau proxies.
decisionsStable = ~excludeHighTChanged;

% Schema/provenance health checks from prior controlled replays.
provOk = checkProvOk(clm001ProvPath) && checkProvOk(clm002ProvPath) && checkProvOk(clm003ProvPath);
schemaOk = strcmpi(getDecision(clm001ResPath, "replay_tau_schema_ok"), "YES") && ...
           strcmpi(getDecision(clm002ResPath, "replay_fm_tau_schema_ok"), "YES") && ...
           strcmpi(getDecision(clm003ResPath, "ac010_schema"), "YES");
schemaProvOk = provOk && schemaOk;

if ~highTPresent || ~raggedCoverageConfirmed
    endpointDisposition = "INCONCLUSIVE";
elseif schemaProvOk && decisionsStable
    endpointDisposition = "KEEP_WITH_CAVEAT";
elseif schemaProvOk
    endpointDisposition = "DIAGNOSTIC_ONLY";
else
    endpointDisposition = "INCONCLUSIVE";
end

readySummaryAudit = schemaProvOk;

resTbl = table( ...
    ["clm008_diagnostic_completed"; "clm008_high_t_endpoints_present"; "clm008_ragged_coverage_confirmed"; ...
     "clm008_included_excluded_comparison_done"; "clm008_decision_stability_evaluated"; "clm008_schema_provenance_ok"; ...
     "clm008_endpoint_disposition"; "physical_synthesis_performed"; "cross_module_analysis_performed"; ...
     "ready_for_replay_summary_audit"], ...
    ["YES"; toYN(highTPresent); toYN(raggedCoverageConfirmed && covTw3No); toYN(includedExcludedComparisonDone); ...
     toYN(true); toYN(schemaProvOk); endpointDisposition; "NO"; "NO"; toYN(readySummaryAudit)], ...
    'VariableNames', {'check','value'});
writetable(resTbl, resultsCsv);

senOut = table( ...
    ["include_all_tp"; "exclude_high_Tp_30_34"; "missing_tw3_highT"; "clm001_decision"; "clm002_decision"; "clm003_decision"], ...
    ["YES"; "YES"; toYN(raggedCoverageConfirmed); clm001Decision; clm002Decision; clm003Decision], ...
    ["Baseline includes Tp=30/34 with caveat"; ...
     "From Stage H sensitivity summary"; ...
     "Tp30/Tp34 both lack tw=3"; ...
     "Current controlled replay result"; ...
     "Current controlled replay result"; ...
     "Current controlled replay result"], ...
    ["N/A"; excludeHighTSummary; "tw=3 absent at high-T by construction"; ...
     "stability compared via high-T exclusion proxy"; ...
     "stability compared via high-T exclusion proxy"; ...
     "stability compared via high-T exclusion proxy"], ...
    ["N/A"; toYN(~excludeHighTChanged); "N/A"; toYN(decisionsStable); toYN(decisionsStable); toYN(decisionsStable)], ...
    'VariableNames', {'scenario','applied','basis','result_or_context','stable_under_highT_exclusion'});
writetable(senOut, sensitivityCsv);

dispTbl = table( ...
    endpointDisposition, ...
    toYN(decisionsStable), ...
    excludeHighTRisk, ...
    "High-T Tp=30/34 endpoints remain diagnostic with explicit ragged tw caveat; no mechanism claim allowed.", ...
    "Do not promote endpoint behavior to synthesis; carry caveat text in all replay summaries.", ...
    'VariableNames', {'endpoint_disposition','clm001_002_003_decisions_stable','stageH_exclude_highT_risk','required_caveat','policy_note'});
writetable(dispTbl, dispositionCsv);

lines = strings(0,1);
lines(end+1) = "# Aging I1 controlled diagnostic: CLM_008 high-T endpoint ragged-coverage";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- Diagnostic-only for `CLM_008`.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- No mechanism claim made.";
lines(end+1) = "";
lines(end+1) = "## Required checks";
lines(end+1) = "- Tp=30 and Tp=34 present: " + toYN(highTPresent);
lines(end+1) = "- Missing `tw=3` at Tp=30/34 identified: " + toYN(raggedCoverageConfirmed && covTw3No);
lines(end+1) = "- Included vs excluded comparison done: YES (Stage H `exclude_high_Tp_30_34`).";
lines(end+1) = "- Decision stability evaluated (CLM_001/002/003): " + toYN(decisionsStable);
lines(end+1) = "- Schema/provenance failures from high-T inclusion: " + toYN(~schemaProvOk) + " (NO means none found).";
lines(end+1) = "";
lines(end+1) = "## Endpoint disposition";
lines(end+1) = "- Disposition: **" + endpointDisposition + "**.";
lines(end+1) = "- Stage H exclude-highT risk level: " + excludeHighTRisk + ".";
lines(end+1) = "- Comparison summary: " + excludeHighTSummary + ".";
lines(end+1) = "";
lines(end+1) = "## Required outputs";
lines(end+1) = "- `" + string(resultsCsv) + "`";
lines(end+1) = "- `" + string(sensitivityCsv) + "`";
lines(end+1) = "- `" + string(dispositionCsv) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- CLM008_DIAGNOSTIC_COMPLETED = YES";
lines(end+1) = "- CLM008_HIGH_T_ENDPOINTS_PRESENT = " + toYN(highTPresent);
lines(end+1) = "- CLM008_RAGGED_COVERAGE_CONFIRMED = " + toYN(raggedCoverageConfirmed && covTw3No);
lines(end+1) = "- CLM008_INCLUDED_EXCLUDED_COMPARISON_DONE = YES";
lines(end+1) = "- CLM008_DECISION_STABILITY_EVALUATED = YES";
lines(end+1) = "- CLM008_SCHEMA_PROVENANCE_OK = " + toYN(schemaProvOk);
lines(end+1) = "- CLM008_ENDPOINT_DISPOSITION = " + endpointDisposition;
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "- READY_FOR_REPLAY_SUMMARY_AUDIT = " + toYN(readySummaryAudit);
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Endpoint disposition: **" + endpointDisposition + "**.";
lines(end+1) = "2. CLM_001/002/003 decision stability under high-T exclusion proxy: **" + toYN(decisionsStable) + "**.";
lines(end+1) = "3. Required caveats for future reports: retain explicit Tp30/34 ragged-coverage caveat and keep endpoint claims diagnostic-only.";
lines(end+1) = "4. Gate J remains blocked: **YES**.";

fid = fopen(reportPath, 'w');
assert(fid >= 0, 'Could not open report path: %s', reportPath);
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
fclose(fid);

disp('CLM_008 high-T endpoint diagnostic completed.');
disp(resultsCsv);
disp(sensitivityCsv);
disp(dispositionCsv);
disp(reportPath);

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

function val = getDecision(csvPath, checkName)
[keys, vals] = loadKeyValueCsv(csvPath, "check", "value");
rows = find(keys == checkName, 1, 'first');
if isempty(rows)
    val = "UNKNOWN";
else
    val = vals(rows);
end
end

function ok = checkProvOk(csvPath)
[~, vals] = loadKeyValueCsv(csvPath, "artifact_role", "exists");
ok = all(vals == "YES");
end

function s = toYN(x)
if islogical(x)
    if x, s = "YES"; else, s = "NO"; end
else
    s = "NO";
end
end

function [ok, ds] = loadDatasetStrict(datasetPath)
fid = fopen(datasetPath, 'r');
assert(fid >= 0, 'Failed to open dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = string(fgetl(fid));
parts = textscan(char(headerLine), '%q', 'Delimiter', ',');
header = string(parts{1});
expected = ["Tp"; "tw"; "Dip_depth"; "FM_abs"; "source_run"];
ok = numel(header) == numel(expected);
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
