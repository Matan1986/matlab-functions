function out = aging_fm_switching_sector_link(cfg)
% aging_fm_switching_sector_link
% Reuse saved Aging and Switching outputs to test whether the FM sector in
% Aging is more naturally linked to Switching dynamics than the Dip sector.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);
scanTbl = buildRepositoryScanTable(source);
aging = loadAgingData(source);
switching = loadSwitchingData(source);

fmSummaryTbl = buildFmRepresentationSummary(aging, source);
fmReps = buildFmRepresentations(aging, fmSummaryTbl);
dipReps = buildDipRepresentations(aging);
switchObs = buildSwitchingObservables(switching);

selectedFm = fmReps([fmReps.selected_for_testing]);
selectedDip = dipReps([dipReps.selected_for_testing]);
selectedSwitch = switchObs([switchObs.selected_for_testing]);

fmCorrTbl = compareRepresentationLibrary(selectedFm, selectedSwitch, "fm");
dipCorrTbl = compareRepresentationLibrary(selectedDip, selectedSwitch, "dip_control");
interpretation = interpretSectorLink(fmCorrTbl, dipCorrTbl, source);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('aging:%s,%s,%s | switching:%s,%s,%s', ...
    char(source.agingDatasetRunName), char(source.fmTauRunName), char(source.dipTauRunName), ...
    char(source.switchRunName), char(source.switchMotionRunName), char(source.switchFullScalingRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Aging FM <-> Switching sector-link run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] aging_fm_switching_sector_link started\n', stampNow()));

save_run_table(scanTbl, 'repository_scan_summary.csv', runDir);
fmSummaryPath = save_run_table(fmSummaryTbl, 'fm_representation_summary.csv', runDir);
fmCorrPath = save_run_table(fmCorrTbl, 'fm_switching_correlations.csv', runDir);
dipCorrPath = save_run_table(dipCorrTbl, 'dip_switching_control_correlations.csv', runDir);
switchSummaryPath = save_run_table(buildSwitchingObservableSummary(selectedSwitch), 'switching_observable_summary.csv', runDir);

figFmRep = saveFmRepresentationFigure(fmReps, runDir, 'fm_representations_vs_temperature');
figFmCmp = saveComparisonFigure(selectedFm, selectedSwitch, fmCorrTbl, interpretation.fmBestPair, runDir, 'fm_vs_switching_comparisons', 'FM representations vs Switching observables');
figDipCmp = saveComparisonFigure(selectedDip, selectedSwitch, dipCorrTbl, interpretation.dipBestPair, runDir, 'dip_vs_switching_control', 'Dip control representations vs Switching observables');

reportText = buildReportText(thisFile, source, scanTbl, fmSummaryTbl, selectedSwitch, fmCorrTbl, dipCorrTbl, interpretation);
reportPath = save_run_report(reportText, 'aging_fm_switching_sector_link_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_fm_switching_sector_link_outputs.zip');

appendText(run.notes_path, sprintf('Final assignment: %s\n', char(interpretation.final_assignment)));
appendText(run.log_path, sprintf('FM summary: %s\nFM correlations: %s\nDip control: %s\nSwitching summary: %s\nReport: %s\nZIP: %s\n', ...
    fmSummaryPath, fmCorrPath, dipCorrPath, switchSummaryPath, reportPath, zipPath));
appendText(run.log_path, sprintf('[%s] aging_fm_switching_sector_link complete\n', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.tables = struct('fm_summary', string(fmSummaryPath), 'fm_correlations', string(fmCorrPath), 'dip_correlations', string(dipCorrPath), 'switching_summary', string(switchSummaryPath));
out.figures = struct('fm_representations', string(figFmRep.png), 'fm_comparisons', string(figFmCmp.png), 'dip_comparisons', string(figDipCmp.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.interpretation = interpretation;
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'aging_fm_switching_sector_link');
cfg = setDefaultField(cfg, 'agingDatasetRunName', 'run_2026_03_12_211204_aging_dataset_build');
cfg = setDefaultField(cfg, 'fmTauRunName', 'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefaultField(cfg, 'dipTauRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefaultField(cfg, 'dipCollapseRunName', 'run_2026_03_12_233710_aging_time_rescaling_collapse');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'switchMotionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'switchFullScalingRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'switchCompositeRunName', 'run_2026_03_13_020519_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'existingStateRunName', 'run_2026_03_11_203011_existing_results_state_map');
cfg = setDefaultField(cfg, 'unifiedRunName', 'run_2026_03_12_075103_unified_dynamical_crossover_synthesis');
cfg = setDefaultField(cfg, 'subspaceRunName', 'run_2026_03_12_084004_common_dynamical_subspace');
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
fields = {'agingDatasetRunName','fmTauRunName','dipTauRunName','dipCollapseRunName','switchRunName','switchMotionRunName','switchFullScalingRunName','switchCompositeRunName','existingStateRunName','unifiedRunName','subspaceRunName'};
for i = 1:numel(fields)
    source.(fields{i}) = string(cfg.(fields{i}));
end
source.repoRoot = string(repoRoot);
source.agingDatasetRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingDatasetRunName));
source.fmTauRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.fmTauRunName));
source.dipTauRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.dipTauRunName));
source.dipCollapseRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.dipCollapseRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.switchMotionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.switchMotionRunName));
source.switchFullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchFullScalingRunName));
source.switchCompositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.switchCompositeRunName));
source.existingStateRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.existingStateRunName));
source.unifiedRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.unifiedRunName));
source.subspaceRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.subspaceRunName));
required = {
    source.agingDatasetRunDir, fullfile(char(source.agingDatasetRunDir), 'tables', 'aging_observable_dataset.csv');
    source.fmTauRunDir, fullfile(char(source.fmTauRunDir), 'tables', 'tau_FM_vs_Tp.csv');
    source.dipTauRunDir, fullfile(char(source.dipTauRunDir), 'tables', 'tau_vs_Tp.csv');
    source.switchRunDir, fullfile(char(source.switchRunDir), 'observable_matrix.csv');
    source.switchMotionRunDir, fullfile(char(source.switchMotionRunDir), 'tables', 'relaxation_switching_motion_table.csv');
    source.switchFullScalingRunDir, fullfile(char(source.switchFullScalingRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    source.switchCompositeRunDir, fullfile(char(source.switchCompositeRunDir), 'reports', 'switching_composite_observable_scan.md');
    source.existingStateRunDir, fullfile(char(source.existingStateRunDir), 'reports', 'existing_results_state_map.md');
    source.unifiedRunDir, fullfile(char(source.unifiedRunDir), 'reports', 'unified_dynamical_crossover_and_aging_switching_link.md');
    source.subspaceRunDir, fullfile(char(source.subspaceRunDir), 'reports', 'common_dynamical_subspace_analysis.md')};
for i = 1:size(required,1)
    assert(exist(required{i,1}, 'dir') == 7, 'Missing run dir: %s', required{i,1});
    assert(exist(required{i,2}, 'file') == 2, 'Missing source file: %s', required{i,2});
end
end

function scanTbl = buildRepositoryScanTable(source)
rows = {
    'direct_aging_fm_vs_switching', 'run_2026_03_11_203011_existing_results_state_map', 'gap_scan', 'No saved modern run directly compares Switching motion or growth observables to Aging Dip_depth, FM_abs, or related sector observables.', false;
    'historical_scalar_cross_plot', 'analysis/cross_experiment_observables.m', 'historical_script', 'A historical script plots Switching S_peak(T) against Aging Dip_depth(T), but it is not a run-scoped FM-sector analysis.', false;
    'aggregated_fm_vs_switching_subspace', 'run_2026_03_12_084004_common_dynamical_subspace', 'indirect_old_fm_scalarization', 'An older aggregated FM_abs(Tp) export was found to align with Switching |dI_peak/dT|, but that run predated tau_FM and did not justify reducing FM_abs(Tp, tw) to one scalar.', false;
    'background_proxy_vs_switching', 'run_2026_03_12_075103_unified_dynamical_crossover_synthesis', 'indirect_proxy_link', 'The unified crossover synthesis explicitly used a structural-collapse background proxy instead of scalar FM_abs and reported strong background-proxy vs Switching mobility alignment.', true;
    'fm_sector_timescale', 'run_2026_03_13_013634_aging_fm_timescale_analysis', 'current_fm_sector_result', 'FM_abs shows a meaningful collapse under tau_FM(Tp), with tau_FM distinct from tau_dip.', true;
    'dip_sector_timescale', 'run_2026_03_12_223709_aging_timescale_extraction + run_2026_03_12_233710_aging_time_rescaling_collapse', 'current_dip_sector_result', 'Dip_depth has its own resolved tau_dip(Tp) and a strong time-rescaling collapse.', true;
    'switching_observable_reuse', 'run_2026_03_10_112659_alignment_audit + run_2026_03_11_084425_relaxation_switching_motion_test + run_2026_03_12_234016_switching_full_scaling_collapse', 'reused_switching_observables', 'I_peak(T), S_peak(T), width_I(T), ridge motion |dI_peak/dT|, and full-scaling width(T) already exist as saved outputs.', true};
scanTbl = cell2table(rows, 'VariableNames', {'scan_item','source_run','comparison_type','summary','reused_in_this_run'});
scanTbl.scan_item = string(scanTbl.scan_item);
scanTbl.source_run = string(scanTbl.source_run);
scanTbl.comparison_type = string(scanTbl.comparison_type);
scanTbl.summary = string(scanTbl.summary);
scanTbl.reused_in_this_run = logical(scanTbl.reused_in_this_run);
scanTbl.repo_root = repmat(source.repoRoot, height(scanTbl), 1);
end

function aging = loadAgingData(source)
aging = struct();
aging.dataset = standardizeVariableNames(readtable(fullfile(source.agingDatasetRunDir, 'tables', 'aging_observable_dataset.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ','));
aging.fmTau = standardizeVariableNames(makeNumericColumns(readtable(fullfile(source.fmTauRunDir, 'tables', 'tau_FM_vs_Tp.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',')));
aging.dipTau = standardizeVariableNames(makeNumericColumns(readtable(fullfile(source.dipTauRunDir, 'tables', 'tau_vs_Tp.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',')));
aging.dataset.Tp = double(aging.dataset.Tp);
aging.dataset.tw = double(aging.dataset.tw);
aging.dataset.Dip_depth = double(aging.dataset.Dip_depth);
aging.dataset.FM_abs = double(aging.dataset.FM_abs);
end

function switching = loadSwitchingData(source)
switching = struct();
switching.canonical = standardizeVariableNames(makeNumericColumns(readtable(fullfile(source.switchRunDir, 'observable_matrix.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',')));
switching.motion = standardizeVariableNames(makeNumericColumns(readtable(fullfile(source.switchMotionRunDir, 'tables', 'relaxation_switching_motion_table.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',')));
switching.fullScaling = standardizeVariableNames(makeNumericColumns(readtable(fullfile(source.switchFullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',')));
end
function tbl = buildFmRepresentationSummary(aging, source)
fmData = aging.dataset(isfinite(aging.dataset.FM_abs), :);
fmTemps = unique(fmData.Tp);
rows = repmat(struct('representation_id',"",'family',"",'definition',"",'usable_temperatures',"",'n_temperatures',0,'selected_for_testing',false,'validity_note',"",'stability_note',"",'source_run',"",'source_file',""), 0, 1);
for tw = [3 36 360 3600]
    sub = fmData(abs(fmData.tw - tw) < eps, :);
    row = rowsTemplate();
    row.representation_id = "fm_fixed_tw_" + string(tw);
    row.family = "fixed_wait_slice";
    row.definition = sprintf('FM_abs(Tp, t_w = %g s)', tw);
    row.usable_temperatures = joinNumbers(unique(sub.Tp).');
    row.n_temperatures = numel(unique(sub.Tp));
    row.selected_for_testing = row.n_temperatures >= 5;
    if tw == 3
        row.validity_note = "Meaningful as the earliest available FM slice, but high-T support is missing because Tp = 30 and 34 K do not include 3 s data.";
        row.stability_note = "Too sparse for a main comparison.";
    else
        row.validity_note = "Meaningful because it compares FM_abs at one common laboratory waiting time without imposing an internal-clock projection.";
        row.stability_note = "Acceptable 6-point support, but each scalar still samples only one point from a sparse trajectory.";
    end
    rows(end+1,1) = row; %#ok<AGROW>
end
row = rowsTemplate();
row.representation_id = "fm_max_over_tw";
row.family = "envelope_scalar";
row.definition = "max_t_w FM_abs(Tp, t_w)";
row.usable_temperatures = joinNumbers(fmTemps.');
row.n_temperatures = numel(fmTemps);
row.selected_for_testing = true;
row.validity_note = "Meaningful as an upper-envelope scalar summarizing the largest observed FM background at each Tp.";
row.stability_note = "Boundary-sensitive because several temperatures peak at the longest measured time.";
rows(end+1,1) = row; %#ok<AGROW>
row = rowsTemplate();
row.representation_id = "fm_range_to_peak";
row.family = "trajectory_scalar";
row.definition = "FM_abs_peak(Tp) - FM_abs_start(Tp)";
row.usable_temperatures = joinNumbers(fmTemps.');
row.n_temperatures = numel(fmTemps);
row.selected_for_testing = true;
row.validity_note = "Meaningful because it isolates the waiting-time-induced FM growth rather than the absolute FM offset.";
row.stability_note = "Still inherits some boundary sensitivity from peak-at-3600 s traces.";
rows(end+1,1) = row; %#ok<AGROW>
for u = [1 2]
    repTbl = buildTauScaledTable(aging.dataset, aging.fmTau, 'FM_abs', u, 'tau_effective_seconds');
    row = rowsTemplate();
    row.representation_id = "fm_tau_scaled_u" + strrep(string(num2str(u)), '.', 'p');
    row.family = "internal_coordinate_slice";
    row.definition = sprintf('FM_abs at t_w / tau_FM(Tp) = %g', u);
    row.usable_temperatures = joinNumbers(repTbl.Tp.');
    row.n_temperatures = height(repTbl);
    row.selected_for_testing = row.n_temperatures >= 5;
    if u == 1
        row.validity_note = "Meaningful because it compares FM_abs at a matched internal-clock location using the FM sector's own extracted tau_FM.";
        row.stability_note = "Physically anchored but partly tied to the tau_FM construction itself.";
    else
        row.validity_note = "Meaningful because it probes a later common stage of the FM trajectory after rescaling by tau_FM.";
        row.stability_note = "Less tautological than u = 1, but still interpolation-limited by 3-4 point traces.";
    end
    rows(end+1,1) = row; %#ok<AGROW>
end
tbl = struct2table(rows);
tbl.source_run = repmat(source.fmTauRunName, height(tbl), 1);
tbl.source_file = repmat(string(fullfile(source.fmTauRunDir, 'tables', 'tau_FM_vs_Tp.csv')), height(tbl), 1);
end

function rep = rowsTemplate()
rep = struct('representation_id',"",'family',"",'definition',"",'usable_temperatures',"",'n_temperatures',0,'selected_for_testing',false,'validity_note',"",'stability_note',"",'source_run',"",'source_file',"");
end

function reps = buildFmRepresentations(aging, summaryTbl)
reps = repmat(emptyRep(), 0, 1);
for i = 1:height(summaryTbl)
    id = summaryTbl.representation_id(i);
    if startsWith(id, "fm_fixed_tw_")
        tw = str2double(extractAfter(id, "fm_fixed_tw_"));
        reps(end+1,1) = buildFixedWaitRepresentation(aging.dataset, 'FM_abs', tw, id, summaryTbl.definition(i), summaryTbl.selected_for_testing(i)); %#ok<AGROW>
    elseif id == "fm_max_over_tw"
        reps(end+1,1) = buildGroupedRepresentation(aging.dataset, 'FM_abs', @maxNoNan, id, summaryTbl.definition(i), true); %#ok<AGROW>
    elseif id == "fm_range_to_peak"
        reps(end+1,1) = buildTauDerivedRepresentation(aging.fmTau, 'FM_abs_range_to_peak', id, summaryTbl.definition(i), true); %#ok<AGROW>
    elseif id == "fm_tau_scaled_u1"
        reps(end+1,1) = buildTauScaledRepresentation(aging.dataset, aging.fmTau, 'FM_abs', 1, id, summaryTbl.definition(i), true); %#ok<AGROW>
    elseif id == "fm_tau_scaled_u2"
        reps(end+1,1) = buildTauScaledRepresentation(aging.dataset, aging.fmTau, 'FM_abs', 2, id, summaryTbl.definition(i), true); %#ok<AGROW>
    end
end
end

function reps = buildDipRepresentations(aging)
reps = repmat(emptyRep(), 0, 1);
reps(end+1,1) = buildFixedWaitRepresentation(aging.dataset, 'Dip_depth', 36, "dip_fixed_tw_36", "Dip_depth(Tp, t_w = 36 s)", true); %#ok<AGROW>
reps(end+1,1) = buildFixedWaitRepresentation(aging.dataset, 'Dip_depth', 360, "dip_fixed_tw_360", "Dip_depth(Tp, t_w = 360 s)", true); %#ok<AGROW>
reps(end+1,1) = buildFixedWaitRepresentation(aging.dataset, 'Dip_depth', 3600, "dip_fixed_tw_3600", "Dip_depth(Tp, t_w = 3600 s)", true); %#ok<AGROW>
reps(end+1,1) = buildGroupedRepresentation(aging.dataset, 'Dip_depth', @maxNoNan, "dip_max_over_tw", "max_t_w Dip_depth(Tp, t_w)", true); %#ok<AGROW>
reps(end+1,1) = buildTauDerivedRepresentation(aging.dipTau, 'Dip_depth_range_to_peak', "dip_range_to_peak", "Dip_depth_peak(Tp) - Dip_depth_start(Tp)", true); %#ok<AGROW>
reps(end+1,1) = buildTauScaledRepresentation(aging.dataset, aging.dipTau, 'Dip_depth', 1, "dip_tau_scaled_u1", "Dip_depth at t_w / tau_dip(Tp) = 1", true); %#ok<AGROW>
reps(end+1,1) = buildTauScaledRepresentation(aging.dataset, aging.dipTau, 'Dip_depth', 2, "dip_tau_scaled_u2", "Dip_depth at t_w / tau_dip(Tp) = 2", true); %#ok<AGROW>
end

function obs = buildSwitchingObservables(switching)
obs = repmat(emptyObs(), 0, 1);
obs(end+1,1) = makeSwitchObs("ridge_motion_abs_dIpeak_dT", 'Switching ridge motion |dI_peak/dT|', switching.motion.T_K, switching.motion.motion_abs_dI_peak_dT, "mobility", true, "Saved ridge-motion observable and the most direct Switching mobility proxy.", "run_2026_03_11_084425_relaxation_switching_motion_test", "Good support from 14-30 K; 34 K is missing."); %#ok<AGROW>
obs(end+1,1) = makeSwitchObs("S_peak", 'Switching S_peak(T)', switching.canonical.T, switching.canonical.S_peak, "amplitude", true, "Canonical Switching peak amplitude from the alignment audit.", "run_2026_03_10_112659_alignment_audit", "Available through 34 K."); %#ok<AGROW>
obs(end+1,1) = makeSwitchObs("I_peak", 'Switching I_peak(T)', switching.canonical.T, switching.canonical.I_peak, "ridge_position", true, "Canonical ridge-position observable; useful as a pinned/mobile coordinate rather than as a mobility amplitude.", "run_2026_03_10_112659_alignment_audit", "Available through 34 K, but the 34 K point is non-monotone."); %#ok<AGROW>
obs(end+1,1) = makeSwitchObs("width_I", 'Switching width_I(T)', switching.canonical.T, switching.canonical.width_I, "width", true, "Requested canonical width observable from the alignment audit.", "run_2026_03_10_112659_alignment_audit", "High-temperature support is poor because width_I is NaN above 28 K."); %#ok<AGROW>
obs(end+1,1) = makeSwitchObs("width_full_scaling", 'Switching full-scaling width(T)', switching.fullScaling.T_K, switching.fullScaling.width_chosen_mA, "width", true, "Newer saved width observable from the full-scaling collapse run.", "run_2026_03_12_234016_switching_full_scaling_collapse", "Extends usable width coverage to 30 K, but still lacks 34 K."); %#ok<AGROW>
[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
XcanonicalAtFullScalingT = interp1(canonicalT, canonicalX, switching.fullScaling.T_K, 'linear', NaN);
obs(end+1,1) = makeSwitchObs("I_over_wS", 'Switching composite I/(w S)', switching.fullScaling.T_K, XcanonicalAtFullScalingT, "composite", false, "Exploratory composite from the switching composite scan; inspected but not used in the main assignment.", "run_2026_03_13_020519_switching_composite_observable_scan", "Composite context only, not a canonical target."); %#ok<AGROW>
end

function tbl = buildSwitchingObservableSummary(selectedSwitch)
rows = repmat(struct('observable_key',"",'display_name',"",'physical_role',"",'selected_for_testing',false,'n_native_points',0,'native_temperatures',"",'reason',"",'coverage_note',"",'source_run',""), 0, 1);
for i = 1:numel(selectedSwitch)
    rows(end+1,1) = struct('observable_key',selectedSwitch(i).key,'display_name',selectedSwitch(i).label,'physical_role',selectedSwitch(i).role,'selected_for_testing',selectedSwitch(i).selected_for_testing,'n_native_points',numel(selectedSwitch(i).T),'native_temperatures',joinNumbers(selectedSwitch(i).T.'),'reason',selectedSwitch(i).reason,'coverage_note',selectedSwitch(i).coverage_note,'source_run',selectedSwitch(i).source_run); %#ok<AGROW>
end
tbl = struct2table(rows);
end

function tbl = compareRepresentationLibrary(reps, switchObs, sectorTag)
rows = repmat(emptyCorrRow(), 0, 1);
for i = 1:numel(reps)
    for j = 1:numel(switchObs)
        rows(end+1,1) = compareOnePair(reps(i), switchObs(j), sectorTag); %#ok<AGROW>
    end
end
tbl = struct2table(rows);
end

function row = compareOnePair(rep, obs, sectorTag)
[Tov, x, y] = overlapVectors(rep.T, rep.values, obs.T, obs.values);
looPearson = NaN(numel(Tov), 1);
looSpearman = NaN(numel(Tov), 1);
if numel(Tov) >= 4
    for k = 1:numel(Tov)
        mask = true(numel(Tov),1); mask(k) = false;
        looPearson(k) = corrSafe(x(mask), y(mask));
        looSpearman(k) = spearmanSafe(x(mask), y(mask));
    end
end
row = struct();
row.sector_tag = string(sectorTag);
row.representation_id = rep.id;
row.representation_label = rep.label;
row.representation_family = rep.family;
row.switching_observable = obs.key;
row.switching_label = obs.label;
row.switching_role = obs.role;
row.switching_source_run = obs.source_run;
row.overlap_temperatures = joinNumbers(Tov.');
row.n_overlap = numel(Tov);
row.pearson_r = corrSafe(x, y);
row.spearman_r = spearmanSafe(x, y);
row.sign_consistent = isfinite(row.pearson_r) && isfinite(row.spearman_r) && sign(row.pearson_r) == sign(row.spearman_r) && sign(row.pearson_r) ~= 0;
row.representation_peak_T = peakTemperature(Tov, x);
row.switching_peak_T = peakTemperature(Tov, y);
row.peak_delta_K = row.representation_peak_T - row.switching_peak_T;
row.loo_pearson_min = min(looPearson, [], 'omitnan');
row.loo_pearson_max = max(looPearson, [], 'omitnan');
row.loo_spearman_min = min(looSpearman, [], 'omitnan');
row.loo_spearman_max = max(looSpearman, [], 'omitnan');
row.single_point_driver_flag = isSinglePointDriven(row.pearson_r, row.spearman_r, looPearson, looSpearman, row.n_overlap);
row.robustness_note = buildRobustnessNote(row);
end

function interpretation = interpretSectorLink(fmCorrTbl, dipCorrTbl, source)
interpretation = struct();
interpretation.source = source;
fmEligible = fmCorrTbl(fmCorrTbl.n_overlap >= 5 & fmCorrTbl.sign_consistent & ~fmCorrTbl.single_point_driver_flag, :);
if isempty(fmEligible), fmEligible = fmCorrTbl(fmCorrTbl.n_overlap >= 5, :); end
dipEligible = dipCorrTbl(dipCorrTbl.n_overlap >= 4 & dipCorrTbl.sign_consistent & ~dipCorrTbl.single_point_driver_flag, :);
if isempty(dipEligible), dipEligible = dipCorrTbl(dipCorrTbl.n_overlap >= 4, :); end
interpretation.fmBestPair = fmEligible(pickBestCorrelationRow(fmEligible), :);
interpretation.dipBestPair = dipEligible(pickBestCorrelationRow(dipEligible), :);
interpretation.fmMotionSummary = summarizeGroup(fmCorrTbl(fmCorrTbl.switching_observable == "ridge_motion_abs_dIpeak_dT" & fmCorrTbl.n_overlap >= 5, :));
interpretation.dipMotionSummary = summarizeGroup(dipCorrTbl(dipCorrTbl.switching_observable == "ridge_motion_abs_dIpeak_dT" & dipCorrTbl.n_overlap >= 4, :));
interpretation.fmPinningSummary = summarizeGroup(fmCorrTbl(fmCorrTbl.switching_observable == "I_peak" & fmCorrTbl.n_overlap >= 5, :));
interpretation.dipPinningSummary = summarizeGroup(dipCorrTbl(dipCorrTbl.switching_observable == "I_peak" & dipCorrTbl.n_overlap >= 4, :));
fmMobilityStrong = interpretation.fmMotionSummary.n_rows >= 2 && interpretation.fmMotionSummary.median_abs_pearson >= 0.65 && interpretation.fmMotionSummary.sign_stable;
dipPinningStrong = interpretation.dipPinningSummary.n_rows >= 2 && interpretation.dipPinningSummary.median_abs_pearson >= 0.60 && interpretation.dipPinningSummary.sign_stable;
dipMobilityStrong = interpretation.dipMotionSummary.n_rows >= 2 && interpretation.dipMotionSummary.median_abs_pearson >= 0.65 && interpretation.dipMotionSummary.sign_stable;
if fmMobilityStrong && dipPinningStrong
    interpretation.final_assignment = "switching_related_to_both_in_different_ways";
    interpretation.conclusion_text = "FM representations align more naturally with Switching mobility-like observables, while the Dip controls align more naturally with I_peak-style pinning coordinates.";
elseif fmMobilityStrong && ~dipMobilityStrong
    interpretation.final_assignment = "switching_more_closely_related_to_fm_sector";
    interpretation.conclusion_text = "Across the justified FM projections, the most stable relation is to Switching mobility or broad-width observables, and the Dip controls do not show an equally strong mobility-style link.";
elseif dipPinningStrong && ~fmMobilityStrong
    interpretation.final_assignment = "switching_more_closely_related_to_dip_sector";
    interpretation.conclusion_text = "The Dip controls show the clearer relation to Switching, while FM projections do not produce a comparably stable mobility-style pattern.";
else
    interpretation.final_assignment = "current_data_insufficient_for_clean_assignment";
    interpretation.conclusion_text = "Some relations are suggestive, but the overlap sizes and representation dependence remain too limited for a clean sector assignment.";
end
interpretation.limitations_text = "FM support is restricted to Tp = 14-34 K with only 3-4 waiting times per trace, and several scalar projections are boundary-sensitive because the observed maximum often occurs at 3600 s.";
interpretation.uncertainty_text = "This is still a scalarized comparison between one Aging representation and one Switching observable at a time; it does not establish a unique microscopic mechanism.";
end
function reportText = buildReportText(thisFile, source, scanTbl, fmSummaryTbl, selectedSwitch, fmCorrTbl, dipCorrTbl, interpretation)
lines = strings(0,1);
lines(end+1) = "# Aging FM-Switching Sector Link";
lines(end+1) = "";
lines(end+1) = sprintf('Generated: %s', stampNow());
lines(end+1) = sprintf('Analysis script: `%s`', string(thisFile));
lines(end+1) = sprintf('Run root: `%s`', string(getRunOutputDir()));
lines(end+1) = "";
lines(end+1) = "## 1. Repository scan summary";
for i = 1:height(scanTbl)
    lines(end+1) = sprintf('- `%s`: %s', scanTbl.source_run(i), scanTbl.summary(i));
end
lines(end+1) = '- Net scan verdict: no prior run tested the current FM sector, defined by `FM_abs(Tp, tw)` together with its own `tau_FM(Tp)`, directly against saved Switching observables.';
lines(end+1) = "";
lines(end+1) = "## 2. Which prior runs were reused";
lines(end+1) = sprintf('- Aging dataset: `%s`', source.agingDatasetRunName);
lines(end+1) = sprintf('- FM timescale run: `%s`', source.fmTauRunName);
lines(end+1) = sprintf('- Dip timescale run: `%s`', source.dipTauRunName);
lines(end+1) = sprintf('- Dip collapse reference: `%s`', source.dipCollapseRunName);
lines(end+1) = sprintf('- Switching canonical observables: `%s`', source.switchRunName);
lines(end+1) = sprintf('- Switching ridge-motion run: `%s`', source.switchMotionRunName);
lines(end+1) = sprintf('- Switching full-scaling width run: `%s`', source.switchFullScalingRunName);
lines(end+1) = sprintf('- Inspected but not used as a primary target: `%s`.', source.switchCompositeRunName);
lines(end+1) = '- No existing runs were modified and no raw maps were recomputed.';
lines(end+1) = "";
lines(end+1) = "## 3. Candidate FM representations considered";
for i = 1:height(fmSummaryTbl)
    lines(end+1) = sprintf('- `%s`: %s', fmSummaryTbl.representation_id(i), fmSummaryTbl.definition(i));
    lines(end+1) = sprintf('  usable temperatures: `%s`; selected for testing: `%s`.', fmSummaryTbl.usable_temperatures(i), yesNo(fmSummaryTbl.selected_for_testing(i)));
    lines(end+1) = sprintf('  why meaningful or not: %s', fmSummaryTbl.validity_note(i));
    lines(end+1) = sprintf('  stability note: %s', fmSummaryTbl.stability_note(i));
end
lines(end+1) = "";
lines(end+1) = "## 4. Why each FM representation is or is not valid";
lines(end+1) = '- Fixed-wait slices are the least assumptive projections because they keep laboratory time explicit, but each one samples only one point from a sparse trace.';
lines(end+1) = '- `FM_max(Tp)` and `FM_range_to_peak(Tp)` summarize the whole trajectory into one scalar, so they are acceptable only as descriptive envelope/growth measures.';
lines(end+1) = '- The `t_w / tau_FM` slices are the most principled internal-coordinate projections because they respect the newly established FM clock; `u = 2` is less tautological than `u = 1`.';
lines(end+1) = '- The excluded `t_w = 3 s` FM slice is physically meaningful but too sparse for a main statistical comparison.';
lines(end+1) = "";
lines(end+1) = "## 5. Which Switching observables were tested";
for i = 1:numel(selectedSwitch)
    lines(end+1) = sprintf('- `%s`: %s', selectedSwitch(i).key, selectedSwitch(i).reason);
    lines(end+1) = sprintf('  coverage note: %s', selectedSwitch(i).coverage_note);
end
lines(end+1) = '- I inspected the saved composite observable `I/(w S)` as context, but did not use it for the main assignment because it is an exploratory composite rather than a canonical Switching observable.';
lines(end+1) = "";
lines(end+1) = "## 6. All correlation results with overlap sizes";
lines(end+1) = "### FM versus Switching";
for i = 1:height(fmCorrTbl)
    lines(end+1) = sprintf('- `%s` vs `%s`: n = %d, Pearson = %.4f, Spearman = %.4f, peak delta = %+g K, single-point-driven = `%s`.', fmCorrTbl.representation_id(i), fmCorrTbl.switching_observable(i), fmCorrTbl.n_overlap(i), fmCorrTbl.pearson_r(i), fmCorrTbl.spearman_r(i), fmCorrTbl.peak_delta_K(i), yesNo(fmCorrTbl.single_point_driver_flag(i)));
end
lines(end+1) = "### Dip control versus Switching";
for i = 1:height(dipCorrTbl)
    lines(end+1) = sprintf('- `%s` vs `%s`: n = %d, Pearson = %.4f, Spearman = %.4f, peak delta = %+g K, single-point-driven = `%s`.', dipCorrTbl.representation_id(i), dipCorrTbl.switching_observable(i), dipCorrTbl.n_overlap(i), dipCorrTbl.pearson_r(i), dipCorrTbl.spearman_r(i), dipCorrTbl.peak_delta_K(i), yesNo(dipCorrTbl.single_point_driver_flag(i)));
end
lines(end+1) = "";
lines(end+1) = "## 7. Robustness notes";
lines(end+1) = sprintf('- FM best-supported pair: `%s` vs `%s` with Pearson = %.4f, Spearman = %.4f, n = %d.', interpretation.fmBestPair.representation_id, interpretation.fmBestPair.switching_observable, interpretation.fmBestPair.pearson_r, interpretation.fmBestPair.spearman_r, interpretation.fmBestPair.n_overlap);
lines(end+1) = sprintf('- Dip best-supported control pair: `%s` vs `%s` with Pearson = %.4f, Spearman = %.4f, n = %d.', interpretation.dipBestPair.representation_id, interpretation.dipBestPair.switching_observable, interpretation.dipBestPair.pearson_r, interpretation.dipBestPair.spearman_r, interpretation.dipBestPair.n_overlap);
lines(end+1) = sprintf('- FM mobility summary across representations: median |Pearson| = %.4f, sign stable = `%s`.', interpretation.fmMotionSummary.median_abs_pearson, yesNo(interpretation.fmMotionSummary.sign_stable));
lines(end+1) = sprintf('- Dip pinning summary across controls: median |Pearson| = %.4f, sign stable = `%s`.', interpretation.dipPinningSummary.median_abs_pearson, yesNo(interpretation.dipPinningSummary.sign_stable));
lines(end+1) = '- Pairs with only four overlapping temperatures were treated as suggestive controls rather than decisive evidence.';
lines(end+1) = '- Leave-one-out ranges are recorded in the CSV tables and were used to flag point-driven relations conservatively.';
lines(end+1) = "";
lines(end+1) = "## 8. Final physical conclusion";
lines(end+1) = sprintf('- Best-supported assignment: **%s**.', strrep(char(interpretation.final_assignment), '_', ' '));
lines(end+1) = sprintf('- Short conclusion: %s', interpretation.conclusion_text);
lines(end+1) = '- Relative to the prior unified crossover synthesis, this run addresses the missing question directly by testing FM-sector projections rather than a structural-collapse proxy.';
lines(end+1) = "";
lines(end+1) = "## 9. Uncertainty / limitations";
lines(end+1) = sprintf('- %s', interpretation.limitations_text);
lines(end+1) = sprintf('- %s', interpretation.uncertainty_text);
lines(end+1) = '- The result is therefore phenomenological and representation-dependent by construction; it is evidence about which scalarized link is more defensible with the current saved outputs, not proof of a unique microscopic mechanism.';
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = '- number of curves: 3 curves in the fixed-wait FM panel, 2 curves in the FM-envelope panel, 2 curves in the tau-scaled FM panel; each comparison figure uses 1 overlay pair plus 2 heatmaps.';
lines(end+1) = '- legend vs colormap: legends for the line panels; diverging heatmaps with colorbars for the correlation summaries.';
lines(end+1) = '- colormap used: custom blue-white-red diverging map for correlation heatmaps; no colormap for line overlays.';
lines(end+1) = '- smoothing applied: none. All representations are built from saved scalar outputs with only linear interpolation in log10(t_w) for the tau-scaled slices.';
lines(end+1) = '- justification: the figure set separates representation definition from cross-experiment comparison so that the unavoidable scalarization choices remain visible.';
reportText = strjoin(lines, newline);
end

function figPaths = saveFmRepresentationFigure(reps, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.0, 12.0);
tl = tiledlayout(fh, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); hold(ax1, 'on'); plotRep(ax1, reps, "fm_fixed_tw_36", [0.00 0.45 0.74]); plotRep(ax1, reps, "fm_fixed_tw_360", [0.85 0.33 0.10]); plotRep(ax1, reps, "fm_fixed_tw_3600", [0.47 0.67 0.19]); hold(ax1, 'off'); grid(ax1, 'on'); xlabel(ax1, 'Stop temperature T_p (K)'); ylabel(ax1, 'FM abs (arb.)'); title(ax1, 'FM fixed-wait representations'); legend(ax1, 'Location', 'best'); setAxisStyle(ax1);
ax2 = nexttile(tl, 2); hold(ax2, 'on'); plotRep(ax2, reps, "fm_max_over_tw", [0.15 0.15 0.15]); plotRep(ax2, reps, "fm_range_to_peak", [0.49 0.18 0.56]); hold(ax2, 'off'); grid(ax2, 'on'); xlabel(ax2, 'Stop temperature T_p (K)'); ylabel(ax2, 'Derived FM magnitude (arb.)'); title(ax2, 'FM envelope and net-growth scalars'); legend(ax2, 'Location', 'best'); setAxisStyle(ax2);
ax3 = nexttile(tl, 3); hold(ax3, 'on'); plotRep(ax3, reps, "fm_tau_scaled_u1", [0.00 0.50 0.30]); plotRep(ax3, reps, "fm_tau_scaled_u2", [0.93 0.69 0.13]); hold(ax3, 'off'); grid(ax3, 'on'); xlabel(ax3, 'Stop temperature T_p (K)'); ylabel(ax3, 'FM abs (arb.)'); title(ax3, 'FM representations at matched internal coordinate'); legend(ax3, 'Location', 'best'); setAxisStyle(ax3);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function figPaths = saveComparisonFigure(reps, switchObs, corrTbl, bestPair, runDir, figureName, mainTitle)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.0, 12.0);
tl = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); plotAnnotatedHeatmap(ax1, buildHeatmapMatrix(corrTbl, reps, switchObs, 'pearson_r'), {reps.label}, {switchObs.label}, 'Pearson r'); title(ax1, 'Pearson correlations');
ax2 = nexttile(tl, 2); plotAnnotatedHeatmap(ax2, buildHeatmapMatrix(corrTbl, reps, switchObs, 'spearman_r'), {reps.label}, {switchObs.label}, 'Spearman rho'); title(ax2, 'Spearman correlations');
ax3 = nexttile(tl, [1 2]);
bestRep = findRepresentation(reps, bestPair.representation_id); bestObs = findSwitchObs(switchObs, bestPair.switching_observable); [Tov, x, y] = overlapVectors(bestRep.T, normalizeMinMax(bestRep.values), bestObs.T, normalizeMinMax(bestObs.values));
hold(ax3, 'on'); plot(ax3, Tov, x, '-o', 'LineWidth', 2.3, 'MarkerSize', 6, 'Color', [0.00 0.45 0.74], 'DisplayName', char(bestRep.label)); plot(ax3, Tov, y, '-s', 'LineWidth', 2.3, 'MarkerSize', 6, 'Color', [0.85 0.33 0.10], 'DisplayName', char(bestObs.label)); hold(ax3, 'off'); grid(ax3, 'on'); xlabel(ax3, 'Overlapping temperature points (K)'); ylabel(ax3, 'Normalized magnitude'); title(ax3, sprintf('Best-supported overlay: %s vs %s (r = %.3f, rho = %.3f, n = %d)', bestRep.id, bestObs.key, bestPair.pearson_r, bestPair.spearman_r, bestPair.n_overlap)); legend(ax3, 'Location', 'best'); setAxisStyle(ax3);
title(tl, mainTitle, 'FontSize', 16, 'FontWeight', 'bold');
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function plotAnnotatedHeatmap(ax, M, yLabels, xLabels, colorbarLabel)
imagesc(ax, M); axis(ax, 'xy'); colormap(ax, blueWhiteRedMap(256)); caxis(ax, [-1 1]); cb = colorbar(ax); cb.Label.String = colorbarLabel; cb.Label.FontSize = 14; set(ax, 'XTick', 1:numel(xLabels), 'XTickLabel', xLabels, 'YTick', 1:numel(yLabels), 'YTickLabel', yLabels, 'TickLabelInterpreter', 'none'); xtickangle(ax, 30); xlabel(ax, 'Switching observable'); ylabel(ax, 'Representation'); setAxisStyle(ax);
for i = 1:size(M,1)
    for j = 1:size(M,2)
        if isfinite(M(i,j))
            text(ax, j, i, sprintf('%.2f', M(i,j)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 11, 'Color', pickTextColor(M(i,j)));
        else
            text(ax, j, i, 'n/a', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', [0.25 0.25 0.25]);
        end
    end
end
end

function M = buildHeatmapMatrix(corrTbl, reps, switchObs, fieldName)
M = NaN(numel(reps), numel(switchObs));
for i = 1:numel(reps)
    for j = 1:numel(switchObs)
        mask = corrTbl.representation_id == reps(i).id & corrTbl.switching_observable == switchObs(j).key;
        if any(mask), M(i,j) = corrTbl.(fieldName)(find(mask, 1, 'first')); end
    end
end
end

function rep = findRepresentation(reps, repId)
rep = reps(find(string({reps.id}) == string(repId), 1, 'first'));
end

function obs = findSwitchObs(switchObs, key)
obs = switchObs(find(string({switchObs.key}) == string(key), 1, 'first'));
end

function [Tov, x, y] = overlapVectors(T1, x1, T2, x2)
tbl1 = table(T1(:), x1(:), 'VariableNames', {'T','x'}); tbl2 = table(T2(:), x2(:), 'VariableNames', {'T','y'}); tbl = innerjoin(tbl1, tbl2, 'Keys', 'T'); tbl = tbl(isfinite(tbl.x) & isfinite(tbl.y), :); tbl = sortrows(tbl, 'T'); Tov = tbl.T(:); x = tbl.x(:); y = tbl.y(:);
end

function rep = buildFixedWaitRepresentation(dataset, valueName, tw, id, label, selected)
mask = abs(dataset.tw - tw) < eps & isfinite(dataset.(valueName)); sub = dataset(mask, {'Tp', valueName}); sub.Properties.VariableNames{2} = 'value'; sub = sortrows(sub, 'Tp'); rep = emptyRep(); rep.id = string(id); rep.label = string(label); rep.family = chooseFamily(rep.id); rep.T = sub.Tp(:); rep.values = sub.value(:); rep.table = sub; rep.selected_for_testing = logical(selected);
end

function rep = buildGroupedRepresentation(dataset, valueName, groupFun, id, label, selected)
sub = dataset(:, {'Tp', valueName}); sub = sub(isfinite(sub.(valueName)), :); [Tu,~,g] = unique(sub.Tp); vals = splitapply(groupFun, sub.(valueName), g); tbl = table(Tu(:), vals(:), 'VariableNames', {'Tp','value'}); rep = emptyRep(); rep.id = string(id); rep.label = string(label); rep.family = chooseFamily(rep.id); rep.T = tbl.Tp(:); rep.values = tbl.value(:); rep.table = tbl; rep.selected_for_testing = logical(selected);
end

function rep = buildTauDerivedRepresentation(tauTbl, columnName, id, label, selected)
mask = isfinite(tauTbl.(columnName)); tbl = table(tauTbl.Tp(mask), tauTbl.(columnName)(mask), 'VariableNames', {'Tp','value'}); rep = emptyRep(); rep.id = string(id); rep.label = string(label); rep.family = chooseFamily(rep.id); rep.T = tbl.Tp(:); rep.values = tbl.value(:); rep.table = tbl; rep.selected_for_testing = logical(selected);
end

function rep = buildTauScaledRepresentation(dataset, tauTbl, valueName, u, id, label, selected)
tbl = buildTauScaledTable(dataset, tauTbl, valueName, u, 'tau_effective_seconds'); rep = emptyRep(); rep.id = string(id); rep.label = string(label); rep.family = chooseFamily(rep.id); rep.T = tbl.Tp(:); rep.values = tbl.value(:); rep.table = tbl; rep.selected_for_testing = logical(selected) && height(tbl) >= 4;
end

function tbl = buildTauScaledTable(dataset, tauTbl, valueName, u, tauColumn)
rows = repmat(struct('Tp',NaN,'value',NaN,'u',u,'tau_seconds',NaN,'query_tw_seconds',NaN), 0, 1);
for i = 1:height(tauTbl)
    tp = tauTbl.Tp(i); tau = tauTbl.(tauColumn)(i);
    if ~(isfinite(tp) && isfinite(tau) && tau > 0), continue; end
    sub = dataset(dataset.Tp == tp & isfinite(dataset.(valueName)) & isfinite(dataset.tw) & dataset.tw > 0, {'tw', valueName});
    if height(sub) < 2, continue; end
    queryTw = u * tau; if queryTw < min(sub.tw) || queryTw > max(sub.tw), continue; end
    value = interp1(log10(sub.tw(:)), sub.(valueName)(:), log10(queryTw), 'linear', NaN); if ~isfinite(value), continue; end
    rows(end+1,1) = struct('Tp',tp,'value',value,'u',u,'tau_seconds',tau,'query_tw_seconds',queryTw); %#ok<AGROW>
end
tbl = struct2table(rows); if ~isempty(tbl), tbl = sortrows(tbl, 'Tp'); end
end

function rep = emptyRep()
rep = struct('id',"",'label',"",'family',"",'T',NaN(0,1),'values',NaN(0,1),'table',table(),'selected_for_testing',false);
end

function obs = emptyObs()
obs = struct('key',"",'label',"",'T',NaN(0,1),'values',NaN(0,1),'role',"",'selected_for_testing',false,'reason',"",'coverage_note',"",'source_run',"");
end

function row = emptyCorrRow()
row = struct('sector_tag',"",'representation_id',"",'representation_label',"",'representation_family',"",'switching_observable',"",'switching_label',"",'switching_role',"",'switching_source_run',"",'overlap_temperatures',"",'n_overlap',0,'pearson_r',NaN,'spearman_r',NaN,'sign_consistent',false,'representation_peak_T',NaN,'switching_peak_T',NaN,'peak_delta_K',NaN,'loo_pearson_min',NaN,'loo_pearson_max',NaN,'loo_spearman_min',NaN,'loo_spearman_max',NaN,'single_point_driver_flag',false,'robustness_note',"");
end

function obs = makeSwitchObs(key, label, T, values, role, selected, reason, sourceRun, coverageNote)
mask = isfinite(T) & isfinite(values); obs = emptyObs(); obs.key = string(key); obs.label = string(label); obs.T = double(T(mask)); obs.values = double(values(mask)); obs.role = string(role); obs.selected_for_testing = logical(selected); obs.reason = string(reason); obs.coverage_note = string(coverageNote); obs.source_run = string(sourceRun);
end

function fam = chooseFamily(id)
if contains(id, "fixed_tw"), fam = "fixed_wait_slice"; elseif contains(id, "range"), fam = "trajectory_scalar"; elseif contains(id, "max"), fam = "envelope_scalar"; elseif contains(id, "tau_scaled"), fam = "internal_coordinate_slice"; else, fam = "other"; end
end

function idx = pickBestCorrelationRow(tbl)
if isempty(tbl), idx = 1; return; end
score = 0.5 * abs(tbl.pearson_r) + 0.5 * abs(tbl.spearman_r) - 0.02 * max(0, 5 - tbl.n_overlap); score(tbl.single_point_driver_flag) = score(tbl.single_point_driver_flag) - 1; [~, idx] = max(score);
end

function summary = summarizeGroup(tbl)
summary = struct('n_rows',height(tbl),'median_abs_pearson',NaN,'sign_stable',false);
if isempty(tbl), return; end
summary.median_abs_pearson = median(abs(tbl.pearson_r), 'omitnan'); signs = sign(tbl.pearson_r); signs = signs(isfinite(signs) & signs ~= 0); summary.sign_stable = ~isempty(signs) && numel(unique(signs)) == 1;
end

function tf = isSinglePointDriven(fullPearson, fullSpearman, looPearson, looSpearman, nOverlap)
if nOverlap <= 4, tf = true; return; end
looPearson = looPearson(isfinite(looPearson)); looSpearman = looSpearman(isfinite(looSpearman)); if isempty(looPearson) || isempty(looSpearman), tf = true; return; end
tf = any(sign(looPearson) ~= sign(fullPearson)) || any(sign(looSpearman) ~= sign(fullSpearman)) || max(abs(looPearson - fullPearson)) > 0.35 || max(abs(looSpearman - fullSpearman)) > 0.35;
end

function note = buildRobustnessNote(row)
if row.n_overlap <= 4, note = "Limited overlap; any correlation is only suggestive."; elseif row.single_point_driver_flag, note = "Correlation changes substantially under leave-one-out deletion."; elseif row.sign_consistent, note = "Pearson and Spearman agree in sign and leave-one-out changes stay moderate."; else, note = "Pearson and Spearman do not agree on sign."; end
end

function out = maxNoNan(x)
x = x(isfinite(x)); if isempty(x), out = NaN; else, out = max(x); end
end

function x = normalizeMinMax(x)
x = double(x(:)); mask = isfinite(x); if ~any(mask), return; end; x(mask) = (x(mask) - min(x(mask))) ./ max(eps, max(x(mask)) - min(x(mask)));
end

function Tpk = peakTemperature(T, x)
Tpk = NaN; mask = isfinite(T) & isfinite(x); if ~any(mask), return; end; [~, idx] = max(x(mask)); Tv = T(mask); Tpk = Tv(idx);
end

function c = corrSafe(x, y)
x = double(x(:)); y = double(y(:)); mask = isfinite(x) & isfinite(y); c = NaN; if nnz(mask) < 3, return; end; cc = corrcoef(x(mask), y(mask)); if numel(cc) >= 4, c = cc(1,2); end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = double(x(:)); r = NaN(size(x)); valid = isfinite(x); if ~any(valid), return; end; xs = x(valid); [xsSorted, order] = sort(xs); ranks = zeros(size(xsSorted)); ii = 1; while ii <= numel(xsSorted), jj = ii; while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii), jj = jj + 1; end; ranks(ii:jj) = mean(ii:jj); ii = jj + 1; end; tmp = zeros(size(xsSorted)); tmp(order) = ranks; r(valid) = tmp;
end

function str = joinNumbers(x)
x = double(x(:)); x = x(isfinite(x)); if isempty(x), str = ""; return; end; parts = strings(numel(x),1); for i = 1:numel(x), if abs(x(i) - round(x(i))) < 1e-9, parts(i) = sprintf('%.0f', x(i)); else, parts(i) = sprintf('%.3g', x(i)); end, end; str = strjoin(parts.', ', ');
end

function s = yesNo(tf)
if tf, s = "yes"; else, s = "no"; end
end

function tbl = standardizeVariableNames(tbl)
vars = string(tbl.Properties.VariableNames);
for i = 1:numel(vars)
    clean = regexprep(vars(i), '[^A-Za-z0-9_]', '');
    if strlength(clean) == 0
        continue;
    end
    vars(i) = clean;
end
tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings(cellstr(vars));
end

function out = makeNumericColumns(tbl)
out = tbl; for i = 1:numel(out.Properties.VariableNames), vn = out.Properties.VariableNames{i}; col = out.(vn); if iscell(col) || isstring(col), num = str2double(string(col)); if nnz(isfinite(num)) > 0, out.(vn) = num; end, end, end
end

function plotRep(ax, reps, repId, colorVal)
idx = find(string({reps.id}) == string(repId), 1, 'first'); if isempty(idx), return; end; plot(ax, reps(idx).T, reps(idx).values, '-o', 'LineWidth', 2.3, 'MarkerSize', 5.5, 'Color', colorVal, 'MarkerFaceColor', 'w', 'DisplayName', char(reps(idx).label));
end

function cmap = blueWhiteRedMap(n)
if nargin < 1, n = 256; end; n1 = floor(n/2); n2 = n - n1; blue = [linspace(0.10,1.00,n1)' linspace(0.30,1.00,n1)' ones(n1,1)]; red = [ones(n2,1) linspace(1.00,0.20,n2)' linspace(1.00,0.20,n2)']; cmap = [blue; flipud(red)];
end

function color = pickTextColor(val)
if abs(val) > 0.55, color = [1 1 1]; else, color = [0.10 0.10 0.10]; end
end

function setFigureGeometry(fig, widthCm, heightCm)
set(fig, 'Units', 'centimeters', 'Position', [2 2 widthCm heightCm], 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 widthCm heightCm], 'PaperSize', [widthCm heightCm], 'Color', 'w');
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review'); if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end; zipPath = fullfile(reviewDir, zipName); if exist(zipPath, 'file') == 2, delete(zipPath); end; zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a'); if fid < 0, return; end; cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU> ; fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field)), cfg.(field) = value; end
end





