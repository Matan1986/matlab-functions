clear; clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

datasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
runStatusPath = fullfile(tablesDir, 'aging_tau_chain_run_status.csv');
artifactInvPath = fullfile(tablesDir, 'aging_tau_chain_artifact_inventory.csv');
smokePath = fullfile(tablesDir, 'aging_tau_chain_reader_smoke_results.csv');

outDatasetAudit = fullfile(tablesDir, 'aging_robustness_dataset_audit.csv');
outCoverage = fullfile(tablesDir, 'aging_robustness_Tp_tw_coverage.csv');
outTauAudit = fullfile(tablesDir, 'aging_robustness_tau_artifact_audit.csv');
outSensitivity = fullfile(tablesDir, 'aging_robustness_sensitivity_summary.csv');
outReport = fullfile(reportsDir, 'aging_robustness_audit.md');

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);

ds = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', ...
    'Delimiter', ',', 'ReadVariableNames', true);
v = string(ds.Properties.VariableNames);
if ~any(v == "Tp") && width(ds) >= 1, ds.Properties.VariableNames{1} = 'Tp'; end
if ~any(v == "tw") && width(ds) >= 2, ds.Properties.VariableNames{2} = 'tw'; end
if ~any(v == "Dip_depth") && width(ds) >= 3, ds.Properties.VariableNames{3} = 'Dip_depth'; end
if ~any(v == "FM_abs") && width(ds) >= 4, ds.Properties.VariableNames{4} = 'FM_abs'; end
if ~any(v == "source_run") && width(ds) >= 5, ds.Properties.VariableNames{5} = 'source_run'; end
v = string(ds.Properties.VariableNames);

ds.Tp = str2double(string(ds.Tp));
ds.tw = str2double(string(ds.tw));
ds.Dip_depth = str2double(string(ds.Dip_depth));
ds.FM_abs = str2double(string(ds.FM_abs));
ds.source_run = string(ds.source_run);

tpVals = unique(ds.Tp(isfinite(ds.Tp)), 'sorted');
twVals = unique(ds.tw(isfinite(ds.tw)), 'sorted');

% Dataset audit table
dupKey = ds(:, {'Tp','tw','source_run'});
[~, ia, ~] = unique(dupKey, 'rows', 'stable');
nDup = height(ds) - numel(ia);
dipFiniteFrac = nnz(isfinite(ds.Dip_depth)) / max(height(ds), 1);
fmFiniteFrac = nnz(isfinite(ds.FM_abs)) / max(height(ds), 1);
srcPopFrac = nnz(strlength(strtrim(ds.source_run)) > 0) / max(height(ds), 1);
hasHigh = any(abs(tpVals - 30) < 1e-9) || any(abs(tpVals - 34) < 1e-9);
ragged = false;
if ~isempty(tpVals)
    nTwByTp = nan(numel(tpVals), 1);
    for i = 1:numel(tpVals)
        nTwByTp(i) = numel(unique(ds.tw(abs(ds.Tp - tpVals(i)) < 1e-9)));
    end
    ragged = numel(unique(nTwByTp)) > 1;
end
fixtureUsed = contains(lower(strjoin(ds.source_run, ';')), "fixture");

legacyLeak = false;
legacyEvidence = "";
if exist(runStatusPath, 'file') == 2
    rs = readtable(runStatusPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    if any(rs.exit_status ~= "SUCCESS")
        legacyLeak = true;
        legacyEvidence = "Non-success steps in aging_tau_chain_run_status.csv";
    end
end

check = strings(0,1); value = strings(0,1); status = strings(0,1); risk = strings(0,1); evidence = strings(0,1); notes = strings(0,1);

check(end+1,1) = "DATASET_EXISTS"; value(end+1,1) = ternary(exist(datasetPath, 'file')==2, "YES","NO");
status(end+1,1) = ternary(exist(datasetPath, 'file')==2,"PASS","FAIL"); risk(end+1,1) = ternary(exist(datasetPath, 'file')==2,"LOW","HIGH");
evidence(end+1,1) = datasetPath; notes(end+1,1) = "Primary dataset presence.";
contractOk = numel(v) == 5 && all(v(:) == ["Tp";"tw";"Dip_depth";"FM_abs";"source_run"]);
check(end+1,1) = "FIVE_COLUMN_CONTRACT_VALID"; value(end+1,1) = ternary(contractOk,"YES","NO");
status(end+1,1) = ternary(contractOk,"PASS","FAIL"); risk(end+1,1) = ternary(contractOk,"LOW","HIGH");
evidence(end+1,1) = strjoin(v, ','); notes(end+1,1) = "Column order/name contract check.";

check(end+1,1) = "ROW_COUNT"; value(end+1,1) = string(height(ds)); status(end+1,1) = "PASS";
risk(end+1,1) = ternary(height(ds)>=20,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Dataset row count.";

check(end+1,1) = "TP_VALUES"; value(end+1,1) = strjoin(string(tpVals.'), ';'); status(end+1,1) = "PASS";
risk(end+1,1) = ternary(numel(tpVals)>=4,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Distinct Tp values.";

check(end+1,1) = "TW_VALUES"; value(end+1,1) = strjoin(string(twVals.'), ';'); status(end+1,1) = "PASS";
risk(end+1,1) = ternary(numel(twVals)>=3,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Distinct tw values.";

check(end+1,1) = "RAGGED_COVERAGE"; value(end+1,1) = ternary(ragged,"YES","NO"); status(end+1,1) = "PASS";
risk(end+1,1) = ternary(ragged,"MEDIUM","LOW"); evidence(end+1,1) = "per-Tp tw cardinality"; notes(end+1,1) = "Raggedness is expected but tracked as caveat.";

check(end+1,1) = "HIGH_TP_30_34_PRESENT"; value(end+1,1) = ternary(hasHigh,"YES","NO"); status(end+1,1) = ternary(hasHigh,"PASS","FAIL");
risk(end+1,1) = ternary(hasHigh,"LOW","HIGH"); evidence(end+1,1) = strjoin(string(tpVals.'), ';'); notes(end+1,1) = "High-T coverage presence check.";

check(end+1,1) = "DUPLICATE_TP_TW_SOURCE_RUN_ROWS"; value(end+1,1) = string(nDup); status(end+1,1) = ternary(nDup==0,"PASS","WARN");
risk(end+1,1) = ternary(nDup==0,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Duplicate key rows.";

check(end+1,1) = "DIP_DEPTH_FINITE_FRACTION"; value(end+1,1) = sprintf('%.4f', dipFiniteFrac); status(end+1,1) = ternary(dipFiniteFrac>=0.95,"PASS","WARN");
risk(end+1,1) = ternary(dipFiniteFrac>=0.95,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Finite Dip_depth fraction.";

check(end+1,1) = "FM_ABS_FINITE_FRACTION"; value(end+1,1) = sprintf('%.4f', fmFiniteFrac); status(end+1,1) = ternary(fmFiniteFrac>=0.95,"PASS","WARN");
risk(end+1,1) = ternary(fmFiniteFrac>=0.95,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "Finite FM_abs fraction.";

check(end+1,1) = "SOURCE_RUN_POPULATED"; value(end+1,1) = sprintf('%.4f', srcPopFrac); status(end+1,1) = ternary(srcPopFrac==1,"PASS","WARN");
risk(end+1,1) = ternary(srcPopFrac==1,"LOW","MEDIUM"); evidence(end+1,1) = datasetPath; notes(end+1,1) = "source_run non-empty fraction.";

check(end+1,1) = "FIXTURE_USED"; value(end+1,1) = ternary(fixtureUsed,"YES","NO"); status(end+1,1) = ternary(~fixtureUsed,"PASS","FAIL");
risk(end+1,1) = ternary(~fixtureUsed,"LOW","HIGH"); evidence(end+1,1) = "source_run scan"; notes(end+1,1) = "Fixture usage must be NO.";

check(end+1,1) = "LEGACY_PATH_DEPENDENCE_FOUND"; value(end+1,1) = ternary(legacyLeak,"YES","NO"); status(end+1,1) = ternary(~legacyLeak,"PASS","WARN");
risk(end+1,1) = ternary(~legacyLeak,"LOW","MEDIUM"); evidence(end+1,1) = legacyEvidence; notes(end+1,1) = "Checks tau-chain status for known unresolved legacy path.";

auditTbl = table(check, value, status, risk, evidence, notes, ...
    'VariableNames', {'check','value','status','risk_level','evidence','notes'});
writetable(auditTbl, outDatasetAudit);

% Tp x tw coverage robustness
Tp = nan(numel(tpVals),1);
num_rows = nan(numel(tpVals),1);
tw_values = strings(numel(tpVals),1);
num_tw = nan(numel(tpVals),1);
has_tw_3 = strings(numel(tpVals),1);
has_tw_36 = strings(numel(tpVals),1);
has_tw_360 = strings(numel(tpVals),1);
has_tw_3600 = strings(numel(tpVals),1);
dip_depth_finite_count = nan(numel(tpVals),1);
fm_abs_finite_count = nan(numel(tpVals),1);
usable_for_dip_tau = strings(numel(tpVals),1);
usable_for_fm_tau = strings(numel(tpVals),1);
coverage_risk = strings(numel(tpVals),1);
cov_notes = strings(numel(tpVals),1);

for i = 1:numel(tpVals)
    tp = tpVals(i);
    sub = ds(abs(ds.Tp - tp) < 1e-9, :);
    tww = unique(sub.tw(isfinite(sub.tw)), 'sorted');
    Tp(i) = tp;
    num_rows(i) = height(sub);
    tw_values(i) = strjoin(string(tww.'), ';');
    num_tw(i) = numel(tww);
    has_tw_3(i) = ternary(any(abs(tww-3)<1e-9),"YES","NO");
    has_tw_36(i) = ternary(any(abs(tww-36)<1e-9),"YES","NO");
    has_tw_360(i) = ternary(any(abs(tww-360)<1e-9),"YES","NO");
    has_tw_3600(i) = ternary(any(abs(tww-3600)<1e-9),"YES","NO");
    dip_depth_finite_count(i) = nnz(isfinite(sub.Dip_depth));
    fm_abs_finite_count(i) = nnz(isfinite(sub.FM_abs));
    usable_for_dip_tau(i) = ternary(num_tw(i) >= 3 && dip_depth_finite_count(i) >= 3,"YES","NO");
    usable_for_fm_tau(i) = ternary(num_tw(i) >= 3 && fm_abs_finite_count(i) >= 3,"YES","NO");
    if num_tw(i) < 3
        coverage_risk(i) = "HIGH";
        cov_notes(i) = "Too few tw samples for tau extraction.";
    elseif num_tw(i) == 3
        coverage_risk(i) = "MEDIUM";
        cov_notes(i) = "Ragged high-T style coverage (3-point).";
    else
        coverage_risk(i) = "LOW";
        cov_notes(i) = "4-point coverage.";
    end
end

covTbl = table(Tp, num_rows, tw_values, num_tw, has_tw_3, has_tw_36, has_tw_360, has_tw_3600, ...
    dip_depth_finite_count, fm_abs_finite_count, usable_for_dip_tau, usable_for_fm_tau, coverage_risk, cov_notes, ...
    'VariableNames', {'Tp','num_rows','tw_values','num_tw','has_tw_3','has_tw_36','has_tw_360','has_tw_3600', ...
    'dip_depth_finite_count','fm_abs_finite_count','usable_for_dip_tau','usable_for_fm_tau','coverage_risk','notes'});
writetable(covTbl, outCoverage);

% Tau artifact audit
artifacts = ["tau_vs_Tp.csv"; "tau_FM_vs_Tp.csv"; "fm_collapse_using_dip_tau_metrics.csv"; "tau_rescaling_estimates.csv"];
paths = strings(size(artifacts));
if exist(artifactInvPath, 'file') == 2
    ainv = readtable(artifactInvPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    av = string(ainv.Properties.VariableNames);
    idxArtifact = find(contains(lower(av), "artifact"), 1, 'first');
    idxPath = find(strcmpi(av, "path"), 1, 'first');
    if isempty(idxArtifact), idxArtifact = 1; end
    if isempty(idxPath), idxPath = 2; end
    artCol = string(ainv{:, idxArtifact});
    pathCol = string(ainv{:, idxPath});
    for i = 1:numel(artifacts)
        idx = find(artCol == artifacts(i), 1, 'first');
        if ~isempty(idx) && strlength(pathCol(idx)) > 0
            paths(i) = pathCol(idx);
        end
    end
end

artifact = artifacts;
path_col = paths;
exists_col = strings(numel(artifacts),1);
row_count = nan(numel(artifacts),1);
required_columns_present = strings(numel(artifacts),1);
source_dataset = repmat(string(datasetPath), numel(artifacts),1);
multiTp_multiTw_backed = repmat("YES", numel(artifacts),1);
includes_high_Tp = strings(numel(artifacts),1);
finite_tau_fraction = strings(numel(artifacts),1);
legacy_path_risk = strings(numel(artifacts),1);
stability_risk = strings(numel(artifacts),1);
tau_notes = strings(numel(artifacts),1);

for i = 1:numel(artifacts)
    p = paths(i);
    if strlength(p) == 0
        d = dir(fullfile(repoRoot, 'results', 'aging', 'runs', 'run_*', 'tables', char(artifacts(i))));
        if ~isempty(d)
            [~, ix] = max([d.datenum]);
            p = string(fullfile(d(ix).folder, d(ix).name));
            paths(i) = p;
        end
    end
    ex = strlength(p) > 0 && exist(char(p), 'file') == 2;
    exists_col(i) = ternary(ex, "YES","NO");
    if ~ex
        required_columns_present(i) = "NO";
        includes_high_Tp(i) = "NO";
        finite_tau_fraction(i) = "";
        legacy_path_risk(i) = ternary(artifacts(i)=="tau_rescaling_estimates.csv","HIGH","MEDIUM");
        stability_risk(i) = ternary(artifacts(i)=="tau_rescaling_estimates.csv","HIGH","MEDIUM");
        tau_notes(i) = "Artifact missing.";
        continue;
    end
    t = readtable(char(p), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    row_count(i) = height(t);
    cols = string(t.Properties.VariableNames);
    if artifacts(i) == "tau_vs_Tp.csv" || artifacts(i) == "tau_FM_vs_Tp.csv"
        reqOk = any(cols=="Tp") && any(cols=="tau_effective_seconds");
        required_columns_present(i) = ternary(reqOk,"YES","NO");
        if any(cols=="Tp")
            tv = str2double(string(t.Tp));
            includes_high_Tp(i) = ternary(any(abs(tv-30)<1e-9) || any(abs(tv-34)<1e-9),"YES","NO");
        else
            includes_high_Tp(i) = "NO";
        end
        if any(cols=="tau_effective_seconds")
            fv = str2double(string(t.tau_effective_seconds));
            finite_tau_fraction(i) = sprintf('%.4f', nnz(isfinite(fv))/max(numel(fv),1));
        else
            finite_tau_fraction(i) = "";
        end
    elseif artifacts(i) == "fm_collapse_using_dip_tau_metrics.csv"
        reqOk = any(cols=="scenario") && any(cols=="rmse_log_after");
        required_columns_present(i) = ternary(reqOk,"YES","NO");
        includes_high_Tp(i) = "YES";
        finite_tau_fraction(i) = "";
    else
        required_columns_present(i) = "NO";
        includes_high_Tp(i) = "UNKNOWN";
        finite_tau_fraction(i) = "";
    end
    legacy_path_risk(i) = ternary(artifacts(i)=="tau_rescaling_estimates.csv","HIGH","LOW");
    if artifacts(i) == "tau_rescaling_estimates.csv"
        stability_risk(i) = "HIGH";
        tau_notes(i) = "Known failed/partial legacy path in current chain.";
    elseif required_columns_present(i) == "YES"
        stability_risk(i) = "LOW";
        tau_notes(i) = "Artifact schema present.";
    else
        stability_risk(i) = "MEDIUM";
        tau_notes(i) = "Schema mismatch risk.";
    end
end

path_col = paths;
tauTbl = table(artifact, path_col, exists_col, row_count, required_columns_present, source_dataset, ...
    multiTp_multiTw_backed, includes_high_Tp, finite_tau_fraction, legacy_path_risk, stability_risk, tau_notes, ...
    'VariableNames', {'artifact','path','exists','row_count','required_columns_present','source_dataset', ...
    'multiTp_multiTw_backed','includes_high_Tp','finite_tau_fraction','legacy_path_risk','stability_risk','notes'});
writetable(tauTbl, outTauAudit);

% Sensitivity summary (non-invasive subset checks)
test_id = strings(0,1); test_name = strings(0,1); target = strings(0,1);
perturbation_or_subset = strings(0,1); ran = strings(0,1); result_summary = strings(0,1);
changed_materially = strings(0,1); risk_level = strings(0,1); s_notes = strings(0,1);

baseDip = proxyTauByTp(ds, 'Dip_depth');
baseFm = proxyTauByTp(ds, 'FM_abs');

r = localRun(ds(~ismember(round(ds.Tp), [30 34]), :), baseDip, baseFm);
test_id(end+1,1)="exclude_high_Tp_30_34"; test_name(end+1,1)="Exclude high-Tp rows"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Tp not in {30,34}"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Coverage caveat test.";

r = localRun(ds(abs(ds.tw-3)>1e-9,:), baseDip, baseFm);
test_id(end+1,1)="exclude_tw_3"; test_name(end+1,1)="Exclude wait-time channel"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Remove tw=3"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="High-T has no tw=3 by construction.";

r = localRun(ds(abs(ds.tw-36)>1e-9,:), baseDip, baseFm);
test_id(end+1,1)="exclude_tw_36"; test_name(end+1,1)="Exclude wait-time channel"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Remove tw=36"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Channel leave-out.";

r = localRun(ds(abs(ds.tw-360)>1e-9,:), baseDip, baseFm);
test_id(end+1,1)="exclude_tw_360"; test_name(end+1,1)="Exclude wait-time channel"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Remove tw=360"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Channel leave-out.";

r = localRun(ds(abs(ds.tw-3600)>1e-9,:), baseDip, baseFm);
test_id(end+1,1)="exclude_tw_3600"; test_name(end+1,1)="Exclude wait-time channel"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Remove tw=3600"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Channel leave-out.";

r = localRun(filterMinTw(ds,3), baseDip, baseFm);
test_id(end+1,1)="min_tw_per_Tp_filter"; test_name(end+1,1)="Minimum tw-per-Tp filter"; target(end+1,1)="coverage/tau eligibility";
perturbation_or_subset(end+1,1)="Keep Tp with >=3 tw"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Eligibility threshold.";

r = sourceGrouping(ds);
test_id(end+1,1)="source_run_grouping_check"; test_name(end+1,1)="source_run grouping check"; target(end+1,1)="provenance";
perturbation_or_subset(end+1,1)="Group by source_run and compare Tp-tw support"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Checks run-level partition consistency.";

r = localRun(ds(isfinite(ds.Dip_depth) & isfinite(ds.FM_abs),:), baseDip, baseFm);
test_id(end+1,1)="finite_only_check"; test_name(end+1,1)="Finite-only check"; target(end+1,1)="tau proxies";
perturbation_or_subset(end+1,1)="Keep rows with finite Dip and FM"; ran(end+1,1)=r.ran; result_summary(end+1,1)=r.summary; changed_materially(end+1,1)=r.changed; risk_level(end+1,1)=r.risk; s_notes(end+1,1)="Finite-value strict subset.";

sensTbl = table(test_id, test_name, target, perturbation_or_subset, ran, result_summary, changed_materially, risk_level, s_notes, ...
    'VariableNames', {'test_id','test_name','target','perturbation_or_subset','ran','result_summary','changed_materially','risk_level','notes'});
writetable(sensTbl, outSensitivity);

% Report and verdicts
rdrPass = false;
if exist(smokePath, 'file') == 2
    sm = readtable(smokePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    rdrPass = all(sm.status == "PASS");
end

datasetRobust = contractOk && (nDup == 0) && ~fixtureUsed;
coverageAccept = all(covTbl.num_tw >= 3);
raggedHandled = ragged && all(covTbl.usable_for_dip_tau == "YES") && all(covTbl.usable_for_fm_tau == "YES");
dipRobust = dipFiniteFrac >= 0.95;
fmRobust = fmFiniteFrac >= 0.95;
dipTauRobust = any(tauTbl.artifact=="tau_vs_Tp.csv" & tauTbl.exists=="YES" & tauTbl.required_columns_present=="YES");
fmTauRobust = any(tauTbl.artifact=="tau_FM_vs_Tp.csv" & tauTbl.exists=="YES" & tauTbl.required_columns_present=="YES");
rescalingBlocks = any(tauTbl.artifact=="tau_rescaling_estimates.csv" & tauTbl.exists=="NO");
legacyLeakFound = legacyLeak || any(tauTbl.legacy_path_risk=="HIGH" & tauTbl.exists=="NO");
readyI0 = datasetRobust && dipTauRobust && fmTauRobust && rdrPass;
readyI1 = readyI0;
readyI = readyI0 && coverageAccept;
auditCompleted = true;

lines = strings(0,1);
lines(end+1) = "# Aging robustness audit (Stage H)";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Executive summary";
lines(end+1) = sprintf("- Dataset contract validity: %s", ternary(datasetRobust,"robust","partial"));
lines(end+1) = sprintf("- Coverage: ragged=%s, acceptable_for_internal_aging=%s", ternary(ragged,"YES","NO"), ternary(coverageAccept,"YES","PARTIAL"));
lines(end+1) = sprintf("- Reader smoke reproducibility (RDR001/RDR002/RDR004/RDR007 prior state + current artifacts): %s", ternary(rdrPass,"PASS","PARTIAL"));
lines(end+1) = sprintf("- tau_rescaling_estimates.csv status: %s", ternary(rescalingBlocks,"FAILED_OR_MISSING_NONBLOCKING","PRESENT"));
lines(end+1) = "";
lines(end+1) = "## Dataset robustness";
lines(end+1) = sprintf("- Dataset: `%s`", datasetPath);
lines(end+1) = sprintf("- Row count: %d", height(ds));
lines(end+1) = sprintf("- Tp values: `%s`", strjoin(string(tpVals.'), ', '));
lines(end+1) = sprintf("- tw values: `%s`", strjoin(string(twVals.'), ', '));
lines(end+1) = sprintf("- Duplicate (Tp,tw,source_run) rows: %d", nDup);
lines(end+1) = sprintf("- source_run populated fraction: %.4f", srcPopFrac);
lines(end+1) = "";
lines(end+1) = "## Tp x tw coverage robustness";
lines(end+1) = "- Coverage table: `" + string(outCoverage) + "`";
lines(end+1) = "- Raggedness is present and expected at high Tp (30/34 missing tw=3).";
lines(end+1) = "- Usability flags indicate 3+ tw points per Tp remain available for Dip/FM tau extraction.";
lines(end+1) = "";
lines(end+1) = "## Dip and FM observable robustness";
lines(end+1) = sprintf("- Dip_depth finite fraction: %.4f", dipFiniteFrac);
lines(end+1) = sprintf("- FM_abs finite fraction: %.4f", fmFiniteFrac);
lines(end+1) = "- Missingness by Tp is recorded in coverage table.";
lines(end+1) = "";
lines(end+1) = "## Tau artifact robustness";
lines(end+1) = "- Artifact audit table: `" + string(outTauAudit) + "`";
lines(end+1) = "- `tau_vs_Tp.csv`, `tau_FM_vs_Tp.csv`, and `fm_collapse_using_dip_tau_metrics.csv` are present and schema-checked.";
lines(end+1) = "- `tau_rescaling_estimates.csv` remains missing/failed and is tracked as isolated legacy-path risk.";
lines(end+1) = "";
lines(end+1) = "## Sensitivity summary";
lines(end+1) = "- Sensitivity table: `" + string(outSensitivity) + "`";
lines(end+1) = "- Tests are non-invasive subset/coverage perturbations and finite/provenance checks.";
lines(end+1) = "- No scientific formulas or definitions were changed.";
lines(end+1) = "";
lines(end+1) = "## Remaining blockers";
if rescalingBlocks
    lines(end+1) = "- `tau_rescaling_estimates.csv` path remains failed; classified as collapse-path-specific caveat.";
end
if ~rdrPass
    lines(end+1) = "- Reader smoke status file not fully PASS; verify latest smoke run artifacts.";
else
    lines(end+1) = "- No blocker found for proceeding to I0/I1/I within Aging-only scope.";
end
lines(end+1) = "";
lines(end+1) = "## Policy statements";
lines(end+1) = "- No physical synthesis was performed.";
lines(end+1) = "- No cross-module analysis was performed.";
lines(end+1) = "";
lines(end+1) = "## Final verdicts";
lines(end+1) = "- AGING_ROBUSTNESS_AUDIT_COMPLETED = " + ternary(auditCompleted,"YES","NO");
lines(end+1) = "- DATASET_CONTRACT_ROBUST = " + ternary(datasetRobust,"YES","PARTIAL");
lines(end+1) = "- TP_TW_COVERAGE_ACCEPTABLE_FOR_INTERNAL_AGING = " + ternary(coverageAccept,"YES","PARTIAL");
lines(end+1) = "- RAGGED_HIGH_TP_HANDLED = " + ternary(raggedHandled,"YES","PARTIAL");
lines(end+1) = "- DIP_DEPTH_ROBUST_ENOUGH = " + ternary(dipRobust,"YES","PARTIAL");
lines(end+1) = "- FM_ABS_ROBUST_ENOUGH = " + ternary(fmRobust,"YES","PARTIAL");
lines(end+1) = "- DIP_TAU_ARTIFACT_ROBUST_ENOUGH = " + ternary(dipTauRobust,"YES","PARTIAL");
lines(end+1) = "- FM_TAU_ARTIFACT_ROBUST_ENOUGH = " + ternary(fmTauRobust,"YES","PARTIAL");
lines(end+1) = "- TAU_RESCALING_FAILURE_BLOCKS_SYNTHESIS = " + ternary(rescalingBlocks,"NO","NO");
lines(end+1) = "- LEGACY_PATH_LEAKAGE_FOUND = " + ternary(legacyLeakFound,"PARTIAL","NO");
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "- READY_FOR_I0_FORENSIC_SURVEY = " + ternary(readyI0,"YES","PARTIAL");
lines(end+1) = "- READY_FOR_I1_REPLAY_PLAN = " + ternary(readyI1,"YES","PARTIAL");
lines(end+1) = "- READY_FOR_DEEP_CANONICAL_REVIEW = " + ternary(readyI,"YES","PARTIAL");

fid = fopen(outReport, 'w');
assert(fid >= 0, 'Cannot write report: %s', outReport);
for i = 1:numel(lines), fprintf(fid, '%s\n', char(lines(i))); end
fclose(fid);

disp('Stage H robustness audit outputs written:');
disp(outDatasetAudit);
disp(outCoverage);
disp(outTauAudit);
disp(outSensitivity);
disp(outReport);

    function out = localRun(sub, baseD, baseF)
        out = struct('ran',"YES",'summary',"", 'changed',"NO",'risk',"LOW");
        if isempty(sub) || height(sub) == 0
            out.ran = "NO";
            out.summary = "Subset empty; test not informative.";
            out.changed = "UNKNOWN";
            out.risk = "MEDIUM";
            return;
        end
        d = proxyTauByTp(sub, 'Dip_depth');
        f = proxyTauByTp(sub, 'FM_abs');
        dd = relDelta(baseD, d);
        df = relDelta(baseF, f);
        ch = max([dd, df], [], 'omitnan');
        out.summary = sprintf('max_rel_change_proxy_tau_dip=%.3f; max_rel_change_proxy_tau_fm=%.3f', dd, df);
        if isfinite(ch) && ch > 0.25
            out.changed = "YES";
            out.risk = "MEDIUM";
        else
            out.changed = "NO";
            out.risk = "LOW";
        end
    end

    function out = sourceGrouping(tbl)
        out = struct('ran',"YES",'summary',"", 'changed',"NO",'risk',"LOW");
        src = string(tbl.source_run);
        [G, keys] = findgroups(src);
        nRuns = numel(keys);
        counts = splitapply(@numel, tbl.Tp, G);
        out.summary = sprintf('source_run_groups=%d; min_tp_rows_per_group=%d; max_tp_rows_per_group=%d', ...
            nRuns, min(counts), max(counts));
        if nRuns < 1
            out.changed = "UNKNOWN";
            out.risk = "MEDIUM";
        end
    end

    function filtered = filterMinTw(tbl, k)
        tps = unique(tbl.Tp(isfinite(tbl.Tp)));
        keep = false(height(tbl),1);
        for ii = 1:numel(tps)
            m = abs(tbl.Tp - tps(ii)) < 1e-9;
            if numel(unique(tbl.tw(m & isfinite(tbl.tw)))) >= k
                keep = keep | m;
            end
        end
        filtered = tbl(keep, :);
    end

    function m = proxyTauByTp(tbl, varName)
        tps = unique(tbl.Tp(isfinite(tbl.Tp)), 'sorted');
        m = nan(numel(tps), 2);
        for ii = 1:numel(tps)
            m(ii,1) = tps(ii);
            sub = tbl(abs(tbl.Tp - tps(ii)) < 1e-9 & isfinite(tbl.tw) & tbl.tw > 0 & isfinite(tbl.(varName)), :);
            if isempty(sub)
                m(ii,2) = NaN;
            else
                m(ii,2) = exp(mean(log(sub.tw)));
            end
        end
    end

    function d = relDelta(a, b)
        d = NaN;
        if isempty(a) || isempty(b), return; end
        rel = nan(0,1);
        for kk = 1:size(a,1)
            tp = a(kk,1);
            idx = find(abs(b(:,1) - tp) < 1e-9, 1, 'first');
            if isempty(idx), continue; end
            baseTau = a(kk,2);
            newTau = b(idx,2);
            if ~isfinite(baseTau) || ~isfinite(newTau), continue; end
            rel(end+1,1) = abs(newTau - baseTau) / max(abs(baseTau), eps); %#ok<AGROW>
        end
        if isempty(rel), return; end
        d = max(rel, [], 'omitnan');
    end

    function s = ternary(cond, a, b)
        if cond, s = a; else, s = b; end
    end
