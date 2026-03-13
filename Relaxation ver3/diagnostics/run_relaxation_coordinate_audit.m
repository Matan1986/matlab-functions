function out = run_relaxation_coordinate_audit(cfg)
% run_relaxation_coordinate_audit
% Code audit for Relaxation coordinate candidates (A_relax, T_relax, shoulder_ratio).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

runLabel = getDef(cfg, 'runLabel', 'coordinate_audit');
runCfg = struct();
runCfg.runLabel = runLabel;
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();

fprintf('Relaxation coordinate audit run directory:\n%s\n', runDir);

% Prepare review directory
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end

% Coordinate mapping table (audit-level summary)
coordTbl = table( ...
    ["A_relax"; "A_relax"; "A_relax"; "T_relax"; "T_relax"; "shape_shoulder"], ...
    ["S_log"; "S_max"; "rate_peak"; "Temp_K_at_global_max_Smax"; "Temp_K_at_global_max_rate_peak"; "shoulder_ratio_lowT_to_main"], ...
    ["existing"; "existing"; "existing"; "derived_from_existing"; "derived_from_existing"; "missing"], ...
    [ ...
      "Relaxation ver3/fitAllRelaxations.m:11,245-248"; ...
      "Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m:220-234,246"; ...
      "Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m:213,240"; ...
      "Derived from S_ridge_peak_trajectory.csv (Temp_K,S_max)"; ...
      "Derived from relaxation_geometry_summary.csv (Temp_K,rate_peak)"; ...
      "No dedicated low-T shoulder/main-lobe ratio metric found" ...
    ], ...
    [ ...
      "Log-fit viscosity parameter; robust candidate for amplitude under fit assumptions"; ...
      "From S(T,t) ridge extraction; method-dependent but directly geometric"; ...
      "Peak rate per temperature in corrected geometry summary"; ...
      "Compute argmax_T of aggregated S_max(T)"; ...
      "Compute argmax_T of rate_peak(T)"; ...
      "Requires explicit shoulder/main-band definition over temperature profile" ...
    ], ...
    'VariableNames', {'coordinate_candidate','metric_name','status','source','notes'});

coordTablePath = save_run_table(coordTbl, 'relaxation_coordinate_metric_map.csv', runDir);

reportLines = [
"# Relaxation Coordinate Audit"
""
"## Scope"
"- Module audited: `Relaxation ver3/`"
"- Goal: assess existing metrics for coordinate candidates `A_relax`, `T_relax`, `shoulder_ratio`."
""
"## Relevant Files"
"- `Relaxation ver3/fitAllRelaxations.m`"
"- `Relaxation ver3/fitLogRelaxation.m`"
"- `Relaxation ver3/diagnostics/analyze_relaxation_derivative_smoothing.m`"
"- `Relaxation ver3/diagnostics/relaxation_corrected_geometry_analysis.m`"
"- `Relaxation ver3/diagnostics/survey_relaxation_observables.m`"
"- `Relaxation ver3/diagnostics/render_relaxation_derivative_interpretable.m`"
""
"## Existing Metrics That Already Match The Coordinate Intent"
"- **Amplitude-like (`A_relax`)**"
"  - `S_log` from log fits: `fitAllRelaxations` outputs column `S` and `survey_relaxation_observables` exports `S_log` for stability sweeps."
"  - `S_max` from derivative-map ridge extraction: `S_ridge_peak_trajectory.csv` with columns (`Temp_K`,`S_max`,`log10_t_peak`,`t_peak_s`)."
"  - `rate_peak` and `amplitude_to_tref` in `relaxation_geometry_summary.csv` from corrected geometry analysis."
"- **Temperature-scale (`T_relax`)**"
"  - Not stored as a single scalar yet, but directly derivable as `argmax_T S_max(T)` or `argmax_T rate_peak(T)` from existing exports."
"- **Shape/curvature proxies**"
"  - `slope_ratio_late_over_early`, `curvature_log`, `curvature_sign_change` exist in geometry summaries and observable sweeps."
""
"## Missing Piece For Candidate `shoulder_ratio`"
"- No script currently exports an explicit low-temperature shoulder / main-lobe ratio over **temperature**."
"- Existing metrics do not separate the two-lobe structure (`~10-18 K` shoulder vs `~24-27 K` main lobe) into a single ratio." 
""
"## Minimal Additions (No Refactor)"
"1. Reuse existing exported profile `S_max(T)` (or `rate_peak(T)`) as the temperature-structure backbone."
"2. Add one small helper in diagnostics to compute:"
"   - `A_relax = max_T profile(T)`"
"   - `T_relax = argmax_T profile(T)`"
"   - `shoulder_ratio = mean(profile(T_shoulder_band)) / mean(profile(T_main_band))`"
"3. Store these 3 values in a new table (e.g. `relaxation_coordinates.csv`) and include in run-level reports."
""
"## Reuse Priority"
"- Prefer `S_ridge_peak_trajectory.csv` and `relaxation_geometry_summary.csv` as primary inputs."
"- Avoid introducing new decomposition/model code for this coordinate layer."
""
"## Audit Outcome"
"- `A_relax`: **already available** (multiple viable existing metrics)."
"- `T_relax`: **derivable from existing exports** with minimal code."
"- `shoulder_ratio`: **not yet implemented** as an explicit coordinate; requires a small additive helper only."
""
"## Artifact"
"- Coordinate mapping table: `tables/relaxation_coordinate_metric_map.csv`"
];
reportText = strjoin(reportLines, newline);
reportPath = save_run_report(reportText, 'relaxation_coordinate_audit.md', runDir);

% Ensure notes and log are updated
appendText(run.log_path, sprintf('[%s] coordinate audit completed\n', stampNow()));
appendText(run.notes_path, sprintf('Coordinate audit report: %s\n', reportPath));

% Build review ZIP
zipPath = fullfile(reviewDir, sprintf('relaxation_coordinate_audit_%s.zip', run.run_id));
if exist(zipPath, 'file')
    delete(zipPath);
end
zipInputs = {'reports/relaxation_coordinate_audit.md', 'tables/relaxation_coordinate_metric_map.csv', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.reportPath = string(reportPath);
out.tablePath = string(coordTablePath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation coordinate audit complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('Table: %s\n', coordTablePath);
fprintf('ZIP: %s\n\n', zipPath);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = getDef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
