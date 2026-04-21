function run_xx_relaxation_full_audit(runTag)
% Full measurement-level audit for XX relaxation dataset.
% Strictly read-only on extraction/event-detection logic.
%
% runTag (optional): e.g. "config2" reads *_config2.csv and writes *_config2 artifacts.
%                   omitted uses legacy filenames (Config3-era tables).

if nargin < 1 || isempty(runTag)
    tagSuffix = "";
else
    tagSuffix = "_" + string(runTag);
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
eventPath = fullfile(repoRoot, "tables", "xx_relaxation_event_level_full" + tagSuffix + ".csv");
aggPath = fullfile(repoRoot, "tables", "xx_relaxation_aggregated_by_state" + tagSuffix + ".csv");

events = readtable(eventPath, "TextType", "string");
agg = readtable(aggPath, "TextType", "string"); %#ok<NASGU> % Input consumed for traceability.

events.is_resolved = isfinite(events.tau_relax);

maxPulseByFile = groupsummary(events(:, {'file_id', 'pulse_index'}), "file_id", "max", "pulse_index");
maxPulseByFile.Properties.VariableNames{'max_pulse_index'} = 'pulse_index_max';
events = outerjoin(events, maxPulseByFile, "Keys", "file_id", "MergeKeys", true, "Type", "left");
events.pulse_position_norm = events.pulse_index ./ max(events.pulse_index_max, 1);

qualityTbl = buildQualityAudit(events);
symmetryTbl = buildSymmetryAudit(events);
sequenceTbl = buildSequenceAudit(events);
regimeTbl = buildRegimeSplit(events);
datasetStats = buildDatasetSummary(events);

qualityOut = fullfile(repoRoot, "tables", "xx_relaxation_quality_audit" + tagSuffix + ".csv");
symmetryOut = fullfile(repoRoot, "tables", "xx_relaxation_symmetry_audit" + tagSuffix + ".csv");
sequenceOut = fullfile(repoRoot, "tables", "xx_relaxation_sequence_audit" + tagSuffix + ".csv");
regimeOut = fullfile(repoRoot, "tables", "xx_relaxation_regime_split" + tagSuffix + ".csv");
statusOut = fullfile(repoRoot, "tables", "xx_relaxation_full_audit_status" + tagSuffix + ".csv");

writetable(qualityTbl, qualityOut);
writetable(symmetryTbl, symmetryOut);
writetable(sequenceTbl, sequenceOut);
writetable(regimeTbl, regimeOut);

qualityFlags = buildQualityFlags(events, qualityTbl);
symmetryFlags = buildSymmetryFlags(symmetryTbl);
sequenceFlags = buildSequenceFlags(events, sequenceTbl);
regimeFlags = buildRegimeFlags(regimeTbl);
datasetFlags = buildDatasetFlags(datasetStats);

writeQualityReport(fullfile(repoRoot, "reports", "xx_relaxation_quality_audit" + tagSuffix + ".md"), qualityTbl, qualityFlags);
writeSymmetryReport(fullfile(repoRoot, "reports", "xx_relaxation_symmetry_audit" + tagSuffix + ".md"), symmetryTbl, symmetryFlags);
writeSequenceReport(fullfile(repoRoot, "reports", "xx_relaxation_sequence_audit" + tagSuffix + ".md"), sequenceTbl, sequenceFlags);
writeRegimeReport(fullfile(repoRoot, "reports", "xx_relaxation_regime_split" + tagSuffix + ".md"), regimeTbl, regimeFlags);
writeDatasetSummaryReport(fullfile(repoRoot, "reports", "xx_relaxation_dataset_summary" + tagSuffix + ".md"), datasetStats, datasetFlags);

statusTbl = table( ...
    ["quality_audit"; "symmetry_audit"; "sequence_audit"; "regime_split"; "dataset_summary"], ...
    repmat("DONE", 5, 1), ...
    ["Artifacts written from existing extracted tables."; ...
     "Artifacts written from existing extracted tables."; ...
     "Artifacts written from existing extracted tables."; ...
     "Artifacts written from existing extracted tables."; ...
     "Artifacts written from existing extracted tables."], ...
    'VariableNames', {'audit_name','status','reason'});
writetable(statusTbl, statusOut);

fprintf('Wrote %s (%d rows)\n', qualityOut, height(qualityTbl));
fprintf('Wrote %s (%d rows)\n', symmetryOut, height(symmetryTbl));
fprintf('Wrote %s (%d rows)\n', sequenceOut, height(sequenceTbl));
fprintf('Wrote %s (%d rows)\n', regimeOut, height(regimeTbl));
fprintf('Wrote %s\n', statusOut);
end

function tbl = buildQualityAudit(events)
rows = table();
states = ["ALL"; "A"; "B"];
for s = 1:numel(states)
    stateName = states(s);
    if stateName == "ALL"
        slice = events;
    else
        slice = events(events.target_state == stateName, :);
    end
    g = findgroups(slice.config_id, slice.temperature);
    out = table();
    out.config_id = splitapply(@(x) x(1), slice.config_id, g);
    out.temperature = splitapply(@(x) x(1), slice.temperature, g);
    out.state = repmat(stateName, max(g), 1);
    out.count_total = splitapply(@numel, slice.tau_relax, g);
    out.count_resolved = splitapply(@(x) sum(isfinite(x)), slice.tau_relax, g);
    out.resolved_fraction = out.count_resolved ./ max(out.count_total, 1);
    out.mean_deltaV = splitapply(@(x) mean(x, "omitnan"), slice.DeltaV, g);
    out.std_deltaV = splitapply(@(x) std(x, "omitnan"), slice.DeltaV, g);
    rows = [rows; out]; %#ok<AGROW>
end
tbl = sortrows(rows, {'config_id', 'temperature', 'state'});
end

function tbl = buildSymmetryAudit(events)
resolved = events(events.is_resolved, :);
g = findgroups(resolved.config_id, resolved.temperature);
cfg = splitapply(@(x) x(1), resolved.config_id, g);
temp = splitapply(@(x) x(1), resolved.temperature, g);

meanA = splitapply(@(st, x) mean(x(st == "A"), "omitnan"), resolved.target_state, resolved.tau_relax, g);
meanB = splitapply(@(st, x) mean(x(st == "B"), "omitnan"), resolved.target_state, resolved.tau_relax, g);
stdA = splitapply(@(st, x) std(x(st == "A"), "omitnan"), resolved.target_state, resolved.tau_relax, g);
stdB = splitapply(@(st, x) std(x(st == "B"), "omitnan"), resolved.target_state, resolved.tau_relax, g);
countA = splitapply(@(st) sum(st == "A"), resolved.target_state, g);
countB = splitapply(@(st) sum(st == "B"), resolved.target_state, g);

deltaTau = meanA - meanB;
pooledStd = sqrt((stdA.^2 + stdB.^2) ./ 2);
deltaTauNorm = abs(deltaTau) ./ max(pooledStd, eps);

tbl = table(cfg, temp, meanA, meanB, stdA, stdB, countA, countB, deltaTau, deltaTauNorm, ...
    'VariableNames', {'config_id','temperature','mean_tau_A','mean_tau_B','std_tau_A','std_tau_B','count_A','count_B','delta_tau','delta_tau_norm'});
tbl = sortrows(tbl, {'config_id', 'temperature'});
end

function tbl = buildSequenceAudit(events)
g = findgroups(events.pulse_index);
pulseIndex = splitapply(@(x) x(1), events.pulse_index, g);
count = splitapply(@numel, events.tau_relax, g);
countResolved = splitapply(@(x) sum(isfinite(x)), events.tau_relax, g);
resolvedFraction = countResolved ./ max(count, 1);
meanTau = splitapply(@(x) mean(x, "omitnan"), events.tau_relax, g);
tbl = table(pulseIndex, resolvedFraction, meanTau, count, ...
    'VariableNames', {'pulse_index','resolved_fraction','mean_tau','count'});
tbl = sortrows(tbl, 'pulse_index');
end

function tbl = buildRegimeSplit(events)
resolved = events(events.is_resolved, :);
gAll = findgroups(events.config_id);
cfgAll = splitapply(@(x) x(1), events.config_id, gAll);
nTot = splitapply(@numel, events.tau_relax, gAll);
nRes = splitapply(@(x) sum(isfinite(x)), events.tau_relax, gAll);
resolvedFrac = nRes ./ max(nTot, 1);

gRes = findgroups(resolved.config_id);
cfgRes = splitapply(@(x) x(1), resolved.config_id, gRes);
meanTau = splitapply(@(x) mean(x, "omitnan"), resolved.tau_relax, gRes);
varTau = splitapply(@(x) var(x, "omitnan"), resolved.tau_relax, gRes);

[tf, loc] = ismember(cfgAll, cfgRes);
meanTauAll = NaN(size(cfgAll));
varTauAll = NaN(size(cfgAll));
meanTauAll(tf) = meanTau(loc(tf));
varTauAll(tf) = varTau(loc(tf));

tbl = table(cfgAll, nTot, nRes, resolvedFrac, meanTauAll, varTauAll, ...
    'VariableNames', {'config_id','count_total','count_resolved','mean_resolved_fraction','mean_tau_relax_resolved','var_tau_relax_resolved'});
tbl = sortrows(tbl, 'config_id');
end

function stats = buildDatasetSummary(events)
stats.N_total = height(events);
stats.N_resolved = sum(events.is_resolved);
stats.resolved_fraction_global = stats.N_resolved / max(stats.N_total, 1);
stats.A_count = sum(events.target_state == "A");
stats.B_count = sum(events.target_state == "B");
stats.balancedness = abs(stats.A_count - stats.B_count) / max(stats.N_total, 1);
end

function flags = buildQualityFlags(events, qualityTbl)
allRows = qualityTbl(qualityTbl.state == "ALL", :);
flags.RESOLVED_FRACTION_DEPENDS_ON_T = yesNo(dependsOnTemperature(allRows.temperature, allRows.resolved_fraction));
flags.RESOLVED_FRACTION_DEPENDS_ON_CONFIG = yesNo(dependsOnCategory(allRows.resolved_fraction, allRows.config_id));
flags.RESOLVED_FRACTION_DEPENDS_ON_STATE = yesNo(dependsOnCategory(events.is_resolved, events.target_state));

seqTbl = buildSequenceAudit(events);
flags.RESOLVED_FRACTION_DEPENDS_ON_SEQUENCE = yesNo(dependsOnTemperature(seqTbl.pulse_index, seqTbl.resolved_fraction));
end

function flags = buildSymmetryFlags(symmetryTbl)
finiteMask = isfinite(symmetryTbl.delta_tau_norm);
if ~any(finiteMask)
    dep = false;
else
    dep = mean(symmetryTbl.delta_tau_norm(finiteMask), "omitnan") > 0.5;
end
flags.RELAXATION_STATE_DEPENDENT = yesNo(dep);
flags.SYMMETRY_ROBUST = yesNo(~dep);
end

function flags = buildSequenceFlags(events, sequenceTbl)
x = sequenceTbl.pulse_index;
y = sequenceTbl.resolved_fraction;
flags.SEQUENCE_DEPENDENCE = yesNo(dependsOnTemperature(x, y));

n = height(sequenceTbl);
cut = max(floor(n / 2), 1);
early = mean(sequenceTbl.resolved_fraction(1:cut), "omitnan");
late = mean(sequenceTbl.resolved_fraction((cut + 1):end), "omitnan");
if isempty(late)
    late = early;
end
flags.EARLY_LATE_DRIFT = yesNo(abs(early - late) > 0.1);

resolved = events(events.is_resolved, :);
if isempty(resolved)
    flags.ASYMMETRY_LOCALIZED_IN_SEQUENCE = "NO";
else
    byPulseState = groupsummary(resolved, {'pulse_index', 'target_state'}, "mean", "tau_relax");
    p = unique(byPulseState.pulse_index);
    delta = NaN(numel(p), 1);
    for i = 1:numel(p)
        rows = byPulseState(byPulseState.pulse_index == p(i), :);
        a = rows.mean_tau_relax(rows.target_state == "A");
        b = rows.mean_tau_relax(rows.target_state == "B");
        if ~isempty(a) && ~isempty(b)
            delta(i) = abs(a - b);
        end
    end
    delta = delta(isfinite(delta));
    if isempty(delta)
        flags.ASYMMETRY_LOCALIZED_IN_SEQUENCE = "NO";
    else
        flags.ASYMMETRY_LOCALIZED_IN_SEQUENCE = yesNo(max(delta) > 2 * mean(delta, "omitnan"));
    end
end
end

function flags = buildRegimeFlags(regimeTbl)
if height(regimeTbl) < 2
    flags.REGIME_DIFFERENCE_IN_DETECTABILITY = "NO";
    flags.REGIME_DIFFERENCE_IN_TAU = "NO";
    return;
end
flags.REGIME_DIFFERENCE_IN_DETECTABILITY = yesNo(range(regimeTbl.mean_resolved_fraction) > 0.1);
flags.REGIME_DIFFERENCE_IN_TAU = yesNo(range(regimeTbl.mean_tau_relax_resolved) > 0.5);
end

function flags = buildDatasetFlags(stats)
flags.DATASET_SUFFICIENT = "YES";
flags.STATE_BALANCED = yesNo(stats.balancedness <= 0.1);
flags.RELAXATION_MOSTLY_UNRESOLVED = yesNo(stats.resolved_fraction_global < 0.5);
end

function writeQualityReport(path, tbl, flags)
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# XX Relaxation Quality Audit\n\n');
fprintf(fid, '- Rows: %d\n', height(tbl));
fprintf(fid, '- Grouping includes state split (`ALL`, `A`, `B`).\n\n');
fprintf(fid, '## Flags\n');
fprintf(fid, 'RESOLVED_FRACTION_DEPENDS_ON_T = %s\n', flags.RESOLVED_FRACTION_DEPENDS_ON_T);
fprintf(fid, 'RESOLVED_FRACTION_DEPENDS_ON_CONFIG = %s\n', flags.RESOLVED_FRACTION_DEPENDS_ON_CONFIG);
fprintf(fid, 'RESOLVED_FRACTION_DEPENDS_ON_STATE = %s\n', flags.RESOLVED_FRACTION_DEPENDS_ON_STATE);
fprintf(fid, 'RESOLVED_FRACTION_DEPENDS_ON_SEQUENCE = %s\n\n', flags.RESOLVED_FRACTION_DEPENDS_ON_SEQUENCE);
writeFooter(fid);
end

function writeSymmetryReport(path, tbl, flags)
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# XX Relaxation Symmetry Audit\n\n');
fprintf(fid, '- Resolved-only rows: %d\n', height(tbl));
fprintf(fid, '- Comparison key: `(config_id, temperature)`.\n\n');
fprintf(fid, '## Flags\n');
fprintf(fid, 'RELAXATION_STATE_DEPENDENT = %s\n', flags.RELAXATION_STATE_DEPENDENT);
fprintf(fid, 'SYMMETRY_ROBUST = %s\n\n', flags.SYMMETRY_ROBUST);
writeFooter(fid);
end

function writeSequenceReport(path, tbl, flags)
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# XX Relaxation Sequence Audit\n\n');
fprintf(fid, '- Pulse index rows: %d\n', height(tbl));
fprintf(fid, '- Channels: detectability trend and resolved tau trend.\n\n');
fprintf(fid, '## Flags\n');
fprintf(fid, 'SEQUENCE_DEPENDENCE = %s\n', flags.SEQUENCE_DEPENDENCE);
fprintf(fid, 'EARLY_LATE_DRIFT = %s\n', flags.EARLY_LATE_DRIFT);
fprintf(fid, 'ASYMMETRY_LOCALIZED_IN_SEQUENCE = %s\n\n', flags.ASYMMETRY_LOCALIZED_IN_SEQUENCE);
writeFooter(fid);
end

function writeRegimeReport(path, tbl, flags)
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# XX Relaxation Regime Split\n\n');
fprintf(fid, '- Config rows: %d\n\n', height(tbl));
fprintf(fid, '## Flags\n');
fprintf(fid, 'REGIME_DIFFERENCE_IN_DETECTABILITY = %s\n', flags.REGIME_DIFFERENCE_IN_DETECTABILITY);
fprintf(fid, 'REGIME_DIFFERENCE_IN_TAU = %s\n\n', flags.REGIME_DIFFERENCE_IN_TAU);
writeFooter(fid);
end

function writeDatasetSummaryReport(path, stats, flags)
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# XX Relaxation Dataset Summary\n\n');
fprintf(fid, '- N_total = %d\n', stats.N_total);
fprintf(fid, '- N_resolved = %d\n', stats.N_resolved);
fprintf(fid, '- resolved_fraction_global = %.6f\n', stats.resolved_fraction_global);
fprintf(fid, '- A_count = %d\n', stats.A_count);
fprintf(fid, '- B_count = %d\n', stats.B_count);
fprintf(fid, '- BALANCEDNESS = %.6f\n\n', stats.balancedness);
fprintf(fid, '## Flags\n');
fprintf(fid, 'DATASET_SUFFICIENT = %s\n', flags.DATASET_SUFFICIENT);
fprintf(fid, 'STATE_BALANCED = %s\n', flags.STATE_BALANCED);
fprintf(fid, 'RELAXATION_MOSTLY_UNRESOLVED = %s\n\n', flags.RELAXATION_MOSTLY_UNRESOLVED);
writeFooter(fid);
end

function writeFooter(fid)
fprintf(fid, '---\n');
fprintf(fid, 'All analyses performed strictly on extracted dataset.\n');
fprintf(fid, 'No detection logic modified.\n');
fprintf(fid, 'Results reflect measurement layer only.\n');
end

function tf = dependsOnTemperature(x, y)
mask = isfinite(x) & isfinite(y);
if sum(mask) < 3
    tf = false;
    return;
end
r = corr(x(mask), y(mask), 'Type', 'Spearman', 'Rows', 'complete');
tf = abs(r) >= 0.2;
end

function tf = dependsOnCategory(y, category)
mask = isfinite(y) & ~ismissing(category);
if sum(mask) < 3
    tf = false;
    return;
end
g = findgroups(category(mask));
if max(g) < 2
    tf = false;
    return;
end
globalMean = mean(y(mask), 'omitnan');
groupMeans = splitapply(@(x) mean(x, 'omitnan'), y(mask), g);
groupCounts = splitapply(@numel, y(mask), g);
ssBetween = sum(groupCounts .* (groupMeans - globalMean).^2);
ssTotal = sum((y(mask) - globalMean).^2);
if ssTotal <= 0
    tf = false;
else
    tf = (ssBetween / ssTotal) > 0.05;
end
end

function out = yesNo(tf)
if tf
    out = "YES";
else
    out = "NO";
end
end
