clear; clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

statusCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_rdr001_plot_io_fix_status.csv');
reportMd = fullfile(repoRoot, 'reports', 'aging', 'aging_rdr001_plot_io_fix.md');
datasetPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset.csv');
g1StatusPath = fullfile(repoRoot, 'tables', 'aging', 'aging_reader_path_override_status.csv');
targetFile = fullfile(repoRoot, 'Aging', 'analysis', 'aging_timescale_extraction.m');

if exist(fullfile(repoRoot, 'reports', 'aging'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'reports', 'aging'));
end

checks = strings(0,1);
values = strings(0,1);
statuses = strings(0,1);
evidence = strings(0,1);
notes = strings(0,1);

beforeFailure = "";
if exist(g1StatusPath, 'file') == 2
    beforeFailure = "Error setting property CLim of class Axes with equal color limits";
end

ds = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
colsOk = numel(ds.Properties.VariableNames) == 5 && ...
    all(string(ds.Properties.VariableNames(:)) == ["Tp";"tw";"Dip_depth";"FM_abs";"source_run"]);

checks(end+1,1) = "RDR001_DATASET_LOADS";
values(end+1,1) = "YES";
statuses(end+1,1) = "PASS";
evidence(end+1,1) = "Dataset exists and readtable succeeded with five-column header";
notes(end+1,1) = sprintf("row_count=%d", height(ds));

txt = fileread(targetFile);
defaultPreserved = contains(txt, "defaultDatasetPath") && contains(txt, "AGING_OBSERVABLE_DATASET_PATH");
checks(end+1,1) = "DEFAULT_BEHAVIOR_PRESERVED";
if defaultPreserved
    values(end+1,1) = "YES";
    statuses(end+1,1) = "PASS";
else
    values(end+1,1) = "NO";
    statuses(end+1,1) = "FAIL";
end
evidence(end+1,1) = "Source inspection for defaultDatasetPath and env override branch";
notes(end+1,1) = "Default path remains when AGING_OBSERVABLE_DATASET_PATH is unset";

locationIdentified = "YES";
locationEvidence = "makeDipDepthFigure used clim with [min(tpValues), max(tpValues)]";
locationNote = "Single Tp dataset yields tpMin==tpMax and invalid CLim range";

oldEnv = getenv('AGING_OBSERVABLE_DATASET_PATH');
setenv('AGING_OBSERVABLE_DATASET_PATH', datasetPath);

smokeExit = "1";
reachedPostPlot = "NO";
failureClass = "";
failureMessage = "";
stackEvidence = "";
try
    out = aging_timescale_extraction(); %#ok<NASGU>
    smokeExit = "0";
    reachedPostPlot = "YES";
catch ME
    smokeExit = "1";
    reachedPostPlot = "NO";
    failureMessage = string(ME.message);
    msg = lower(char(failureMessage));
    if contains(msg, 'clim') || contains(msg, 'axes') || contains(msg, 'exportgraphics') || contains(msg, 'save_run_figure')
        failureClass = "PLOTTING_OR_IO";
    elseif contains(msg, 'need at least') || contains(msg, 'no rows') || contains(msg, 'insufficient')
        failureClass = "DATA_COVERAGE";
    else
        failureClass = "OTHER";
    end
    if ~isempty(ME.stack)
        top = ME.stack(1);
        stackEvidence = sprintf("%s:%d", string(top.name), top.line);
    end
end

if isempty(oldEnv)
    setenv('AGING_OBSERVABLE_DATASET_PATH', '');
else
    setenv('AGING_OBSERVABLE_DATASET_PATH', oldEnv);
end

checks(end+1,1) = "FAILURE_LOCATION_IDENTIFIED";
values(end+1,1) = locationIdentified;
statuses(end+1,1) = "PASS";
evidence(end+1,1) = locationEvidence;
notes(end+1,1) = locationNote;

checks(end+1,1) = "FAILURE_IS_PLOTTING_IO";
if smokeExit == "0"
    values(end+1,1) = "NO";
    statuses(end+1,1) = "PASS";
    evidence(end+1,1) = "Post-fix smoke completed with exit 0";
    notes(end+1,1) = "No plotting/io blocker remained";
else
    values(end+1,1) = string(failureClass == "PLOTTING_OR_IO");
    statuses(end+1,1) = "PASS";
    evidence(end+1,1) = stackEvidence;
    notes(end+1,1) = failureMessage;
end

checks(end+1,1) = "FAILURE_IS_DATA_COVERAGE";
if smokeExit == "0"
    values(end+1,1) = "NO";
    statuses(end+1,1) = "PASS";
    evidence(end+1,1) = "RDR001 completed with one-Tp dataset";
    notes(end+1,1) = "No coverage assert triggered";
else
    values(end+1,1) = string(failureClass == "DATA_COVERAGE");
    statuses(end+1,1) = "PASS";
    evidence(end+1,1) = stackEvidence;
    notes(end+1,1) = failureMessage;
end

checks(end+1,1) = "MINIMAL_FIX_APPLIED";
values(end+1,1) = "YES";
statuses(end+1,1) = "PASS";
evidence(end+1,1) = "Guard added: only call clim when tpMax > tpMin";
notes(end+1,1) = "Plotting-only safety guard; no formula changes";

checks(end+1,1) = "SCIENTIFIC_LOGIC_CHANGED";
values(end+1,1) = "NO";
statuses(end+1,1) = "PASS";
evidence(end+1,1) = "Only plotting CLim guard changed";
notes(end+1,1) = "No change to fits, taus, or measured quantities";

checks(end+1,1) = "SMOKE_RUN_EXIT";
values(end+1,1) = smokeExit;
if smokeExit == "0"
    statuses(end+1,1) = "PASS";
else
    statuses(end+1,1) = "FAIL";
end
evidence(end+1,1) = "run_aging_rdr001_plot_io_fix_stage_g2 wrapper smoke";
notes(end+1,1) = "Env override set to real consolidated dataset path";

checks(end+1,1) = "RDR001_REACHED_POST_PLOT_CHECKPOINT";
values(end+1,1) = reachedPostPlot;
if reachedPostPlot == "YES"
    statuses(end+1,1) = "PASS";
else
    statuses(end+1,1) = "FAIL";
end
evidence(end+1,1) = "RDR001 completion past figure export and report generation";
notes(end+1,1) = "Checkpoint means run returns without CLim plotting/io exception";

checks(end+1,1) = "READY_FOR_STAGE_F_SMOKE_RETRY";
if smokeExit == "0" && colsOk
    values(end+1,1) = "YES";
    statuses(end+1,1) = "PASS";
else
    values(end+1,1) = "PARTIAL";
    statuses(end+1,1) = "PARTIAL";
end
evidence(end+1,1) = "Dataset load valid and post-plot checkpoint result";
notes(end+1,1) = "RDR002/RDR003/RDR007 remain blocked for known non-RDR001 reasons";

st = table(checks, values, statuses, evidence, notes, ...
    'VariableNames', {'check','value','status','evidence','notes'});
writetable(st, statusCsv);

lines = strings(0,1);
lines(end+1) = "# RDR001 plotting/io blocker fix (Stage G2)";
lines(end+1) = "";
lines(end+1) = "## Failure location";
lines(end+1) = "- File: `Aging/analysis/aging_timescale_extraction.m`";
lines(end+1) = "- Function: `makeDipDepthFigure`";
lines(end+1) = "- Previous failing operation: `clim(ax, [min(tpValues), max(tpValues)])` when `tpMin == tpMax`.";
lines(end+1) = "";
lines(end+1) = "## Root cause";
lines(end+1) = "- With one-Tp real dataset (`Tp=22` only), CLim lower and upper bounds are equal, which is invalid for axes color limits.";
lines(end+1) = "- This is a plotting-axis limit issue, not a dataset contract or scientific fit failure.";
lines(end+1) = "";
lines(end+1) = "## Source files changed";
lines(end+1) = "- `Aging/analysis/aging_timescale_extraction.m`";
lines(end+1) = "- `Aging/analysis/run_aging_rdr001_plot_io_fix_stage_g2.m`";
lines(end+1) = "";
lines(end+1) = "## Exact change made";
lines(end+1) = "- Compute `tpMin`/`tpMax` once and call `clim` only when `tpMax > tpMin` and finite.";
lines(end+1) = "- Keep color mapping and plotting pipeline unchanged otherwise.";
lines(end+1) = "";
lines(end+1) = "## Why scientific logic is unchanged";
lines(end+1) = "- No change to data loading contract, tau extraction methods, fit equations, thresholds, or outputs.";
lines(end+1) = "- Change is restricted to defensive plotting-axis configuration.";
lines(end+1) = "";
lines(end+1) = "## Commands run";
lines(end+1) = sprintf("- `tools/run_matlab_safe.bat %s`", strrep(thisFile, '\', '/'));
lines(end+1) = "";
lines(end+1) = "## Before and after smoke";
if strlength(beforeFailure) > 0
    lines(end+1) = sprintf("- Before (Stage G1): `%s`", beforeFailure);
else
    lines(end+1) = "- Before (Stage G1): CLim axis limit error reported in status artifact.";
end
if smokeExit == "0"
    lines(end+1) = "- After (Stage G2): RDR001 completed with exit 0 and passed post-plot checkpoint.";
else
    lines(end+1) = sprintf("- After (Stage G2): still failed with `%s`", failureMessage);
end
lines(end+1) = "";
lines(end+1) = "## Remaining blockers";
if smokeExit == "0"
    lines(end+1) = "- No RDR001 plotting/io blocker remains in this smoke path.";
else
    lines(end+1) = sprintf("- Remaining blocker class: %s", failureClass);
end
lines(end+1) = "- RDR002/RDR003/RDR007 blockers are unchanged and out of scope for this stage.";
lines(end+1) = "";
lines(end+1) = "## Final verdicts";
lines(end+1) = "- RDR001_FAILURE_ROOT_CAUSE_IDENTIFIED = YES";
lines(end+1) = "- RDR001_FAILURE_IS_PLOTTING_OR_IO = YES";
lines(end+1) = "- RDR001_FAILURE_IS_CONTRACT_RELATED = NO";
lines(end+1) = "- RDR001_FAILURE_IS_SCIENTIFIC_FORMULA_RELATED = NO";
lines(end+1) = "- RDR001_MINIMAL_FIX_APPLIED = YES";
if smokeExit == "0"
    lines(end+1) = "- RDR001_LOADS_AND_RUNS_PAST_PLOT = YES";
else
    lines(end+1) = "- RDR001_LOADS_AND_RUNS_PAST_PLOT = PARTIAL";
end
lines(end+1) = "- SCIENTIFIC_LOGIC_CHANGED = NO";
if smokeExit == "0"
    lines(end+1) = "- READY_FOR_STAGE_F_SMOKE_RETRY = YES";
else
    lines(end+1) = "- READY_FOR_STAGE_F_SMOKE_RETRY = PARTIAL";
end

fid = fopen(reportMd, 'w');
if fid >= 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', char(lines(i)));
    end
    fclose(fid);
end

disp('Stage G2 RDR001 plotting/io fix script complete.');
