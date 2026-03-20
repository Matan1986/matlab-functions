function out = effective_observables_catalog_run(cfg)
% effective_observables_catalog_run
% Build a complete catalog of effective physical observables and extract
% missing physically motivated observables into a new cross-experiment run.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSources(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('switch:%s | relax:%s | aging:%s', ...
    char(source.switchingFullScalingRun), ...
    char(source.relaxationStabilityRun), ...
    char(source.agingClockRatioRun));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Effective observable catalog run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] effective observable catalog started\n', stampNow()));

existingCatalog = buildExistingCatalog(source);
verifyCatalogColumns(existingCatalog);

[switchTbl, relaxTbl, newObsLong, newCatalogRows] = extractMissingObservables(source, cfg, run);
verifyNoExistingDuplicates(existingCatalog, newCatalogRows);

completeCatalog = [existingCatalog; newCatalogRows];
completeCatalog = sortrows(completeCatalog, {'experiment_source', 'observable_name'});

catalogCsvPath = save_run_table(completeCatalog, 'effective_observables_catalog.csv', runDir);
newObsPath = save_run_table(newObsLong, 'new_effective_observables_values.csv', runDir);
switchPath = save_run_table(switchTbl, 'new_switching_observables_vs_T.csv', runDir);
relaxPath = save_run_table(relaxTbl, 'new_relaxation_observables_vs_T.csv', runDir);

switchFig = makeSwitchingNewObservableFigure(switchTbl, runDir);
relaxFig = makeRelaxationNewObservableFigure(relaxTbl, runDir);
overlayFig = makeOverlayFigure(source, switchTbl, relaxTbl, runDir);

obsIndexTbl = buildObservablesIndex(newObsLong, run.run_id);
obsIndexPath = export_observables('cross_experiment', runDir, obsIndexTbl);

reportText = buildCatalogReport(source, existingCatalog, newCatalogRows, switchTbl, relaxTbl, cfg, runDir);
catalogMdPath = save_run_report(reportText, 'effective_observables_catalog.md', runDir);

scriptCopyPath = fullfile(runDir, 'reports', 'effective_observables_catalog_run_script_copy.m');
scriptSource = [thisFile '.m'];
copyfile(scriptSource, scriptCopyPath);




zipPath = buildReviewZip(runDir, 'review_bundle.zip');

appendText(run.notes_path, sprintf('Existing observables cataloged: %d\n', height(existingCatalog)));
appendText(run.notes_path, sprintf('New observables extracted: %d\n', numel(unique(newObsLong.observable_name))));
appendText(run.notes_path, sprintf('Catalog CSV: %s\n', catalogCsvPath));
appendText(run.notes_path, sprintf('Catalog MD: %s\n', catalogMdPath));

appendText(run.log_path, sprintf('Existing catalog rows: %d\n', height(existingCatalog)));
appendText(run.log_path, sprintf('New observable rows: %d\n', height(newObsLong)));
appendText(run.log_path, sprintf('Catalog CSV: %s\n', catalogCsvPath));
appendText(run.log_path, sprintf('Catalog MD: %s\n', catalogMdPath));
appendText(run.log_path, sprintf('New observables table: %s\n', newObsPath));
appendText(run.log_path, sprintf('Switching table: %s\n', switchPath));
appendText(run.log_path, sprintf('Relaxation table: %s\n', relaxPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', switchFig.overlay_png));
appendText(run.log_path, sprintf('Observables index: %s\n', obsIndexPath));
appendText(run.log_path, sprintf('Script copy: %s\n', scriptCopyPath));
appendText(run.log_path, sprintf('ZIP bundle: %s\n', zipPath));
appendText(run.log_path, sprintf('[%s] effective observable catalog complete\n', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.paths = struct( ...
    'catalog_csv', string(catalogCsvPath), ...
    'catalog_md', string(catalogMdPath), ...
    'new_values', string(newObsPath), ...
    'new_switching', string(switchPath), ...
    'new_relaxation', string(relaxPath), ...
    'observables_index', string(obsIndexPath), ...
    'switching_figure', string(switchFig.main_png), ...
    'relaxation_figure', string(relaxFig.main_png), ...
    'overlay_figure', string(overlayFig.main_png), ...
    'review_bundle', string(zipPath));
out.tables = struct('catalog', completeCatalog, 'new_values', newObsLong);

fprintf('\n=== Effective observable catalog complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Catalog CSV: %s\n', catalogCsvPath);
fprintf('Catalog MD: %s\n', catalogMdPath);
fprintf('Overlay figure: %s\n', overlayFig.main_png);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'effective_observables_catalog');
cfg = setDefault(cfg, 't0Seconds', 1.0);
cfg = setDefault(cfg, 'curvatureSmoothWindow', 3);
cfg = setDefault(cfg, 'derivativeSmoothWindow', 3);
end

function source = resolveSources(repoRoot, cfg)
source = struct();
source.repoRoot = string(repoRoot);

source.switchingFullScalingRun = "run_2026_03_12_234016_switching_full_scaling_collapse";
source.switchingAlignmentRun = "run_2026_03_10_112659_alignment_audit";
source.switchingSusceptibilityRun = "run_2026_03_14_063231_switching_dynamical_susceptibility";
source.switchingEffectiveRun = "run_2026_03_13_152008_switching_effective_observables";
source.switchingGeometryRun = "run_2026_03_13_112155_switching_geometry_diagnostics";
source.switchingDynamicShapeRun = "run_2026_03_14_161801_switching_dynamic_shape_mode";
source.switchingChiDecompRun = "run_2026_03_14_121511_switching_chi_shift_shape_decomposition";

source.relaxationGeometryRun = "run_2026_03_10_151424_geometry_observables";
source.relaxationTimelawRun = "run_2026_03_10_143906_timelaw_observables";
source.relaxationStabilityRun = "run_2026_03_10_175048_relaxation_observable_stability_audit";

source.agingObservableRun = "run_2026_03_10_200643_observable_mode_correlation";
source.agingDipTauRun = "run_2026_03_12_223709_aging_timescale_extraction";
source.agingFMTauRun = "run_2026_03_13_013634_aging_fm_timescale_analysis";
source.agingClockRatioRun = "run_2026_03_14_074613_aging_clock_ratio_analysis";

source.switchingFullScalingPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.switchingFullScalingRun), 'tables', 'switching_full_scaling_parameters.csv');
source.switchingAlignmentCorePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.switchingAlignmentRun), 'switching_alignment_core_data.mat');
source.switchingSusceptibilityPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    char(source.switchingSusceptibilityRun), 'tables', 'susceptibility_observables.csv');
source.switchingEffectivePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.switchingEffectiveRun), 'tables', 'switching_effective_observables_table.csv');
source.switchingGeometryPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.switchingGeometryRun), 'tables', 'switching_geometry_observables.csv');
source.switchingDynamicShapePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.switchingDynamicShapeRun), 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.switchingChiDecompPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    char(source.switchingChiDecompRun), 'tables', 'chi_decomposition_vs_T.csv');

source.relaxationStabilityPath = fullfile(repoRoot, 'results', 'relaxation', 'runs', ...
    char(source.relaxationStabilityRun), 'tables', 'temperature_observables.csv');
source.relaxationTimelawPath = fullfile(repoRoot, 'results', 'relaxation', 'runs', ...
    char(source.relaxationTimelawRun), 'tables', 'time_fit_results.csv');

source.agingDipTauPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(source.agingDipTauRun), 'tables', 'tau_vs_Tp.csv');
source.agingFMTauPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(source.agingFMTauRun), 'tables', 'tau_FM_vs_Tp.csv');
source.agingClockRatioPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(source.agingClockRatioRun), 'tables', 'table_clock_ratio.csv');

requiredFiles = { ...
    source.switchingFullScalingPath; ...
    source.switchingAlignmentCorePath; ...
    source.switchingSusceptibilityPath; ...
    source.switchingEffectivePath; ...
    source.relaxationStabilityPath; ...
    source.relaxationTimelawPath; ...
    source.agingDipTauPath; ...
    source.agingFMTauPath; ...
    source.agingClockRatioPath};
for i = 1:numel(requiredFiles)
    assert(exist(requiredFiles{i}, 'file') == 2, 'Missing required source file: %s', requiredFiles{i});
end

source.cfg = cfg;
end
function tbl = buildExistingCatalog(source)
rows = {
    "A_T", "A(T)=sigma_1*u_1(T) from rank-1 relaxation map projection", "Relaxation", source.relaxationStabilityRun, "Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m", "Relaxation activity amplitude";
    "Relax_beta_T", "beta(T) from stretched-exponential fit of DeltaM(T,t)", "Relaxation", source.relaxationStabilityRun, "Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m", "Relaxation-law stretching exponent";
    "Relax_tau_T", "tau(T) from stretched-exponential fit of DeltaM(T,t)", "Relaxation", source.relaxationStabilityRun, "Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m", "Relaxation timescale";
    "Relax_t_half", "t_half(T) from fitted time-law crossing of half-response", "Relaxation", source.relaxationTimelawRun, "Relaxation ver3/diagnostics/run_relaxation_timelaw_observables.m", "Half-response activation timescale";
    "Relax_initial_slope", "-d(DeltaM)/d(log10 t)|_{early}", "Relaxation", source.relaxationTimelawRun, "Relaxation ver3/diagnostics/run_relaxation_timelaw_observables.m", "Early-time response rate";
    "Relax_Amp_peak", "max_T A(T)", "Relaxation", source.relaxationGeometryRun, "Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m", "Peak relaxation activity";
    "Relax_T_peak", "argmax_T A(T)", "Relaxation", source.relaxationGeometryRun, "Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m", "Temperature of activity peak";
    "Relax_peak_width", "FWHM in T of A(T)", "Relaxation", source.relaxationGeometryRun, "Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m", "Thermal breadth of relaxation activity";
    "Relax_mode2_strength", "sigma_2/sigma_1 from SVD of DeltaM map", "Relaxation", source.relaxationGeometryRun, "Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m", "Subleading geometric deformation strength";
    "Relax_rank1_residual_fraction", "1-variance_explained(rank1)", "Relaxation", source.relaxationGeometryRun, "Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m", "Non-separable residual fraction";
    "Dip_depth", "Depth of aging dip component from decomposition", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "Aging memory dip amplitude";
    "Dip_T0", "Center temperature of dip component", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "Dip position coordinate";
    "Dip_sigma", "Dip width parameter from component fit", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "Dip breadth / disorder scale";
    "FM_abs", "Absolute FM component amplitude", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "FM-sector response amplitude";
    "FM_E", "FM component energy-like metric from decomposition", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "FM-sector integrated strength proxy";
    "FM_step_mag", "Signed FM step magnitude from decomposition", "Aging", source.agingObservableRun, "Aging/analysis/aging_observable_mode_correlation.m", "FM step direction and magnitude";
    "tau_dip_seconds", "Effective dip clock tau_dip(Tp) from dip-depth growth", "Aging", source.agingDipTauRun, "Aging/analysis/aging_timescale_extraction.m", "Dip-sector aging timescale";
    "tau_FM_seconds", "Effective FM clock tau_FM(Tp) from FM_abs growth", "Aging", source.agingFMTauRun, "Aging/analysis/aging_fm_timescale_analysis.m", "FM-sector aging timescale";
    "R_tau_FM_over_tau_dip", "R(Tp)=tau_FM(Tp)/tau_dip(Tp)", "Aging", source.agingClockRatioRun, "Aging/analysis/aging_clock_ratio_analysis.m", "Two-clock ratio / sector decoupling";
    "I_peak_mA", "I at maximum S(I,T)", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Ridge center coordinate";
    "width_mA", "Collapse width from FWHM/sigma rule", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Ridge width / barrier spread proxy";
    "S_peak", "Peak switching amplitude max_I S(I,T)", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Switching strength scale";
    "X", "X(T)=I_peak/(width*S_peak)", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Composite switching geometry coordinate";
    "collapse_defect", "RMSE of collapsed curve to master curve", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Deviation from single-collapse shape";
    "asym", "(wR-wL)/(wR+wL) or area-asymmetry family", "Switching", source.switchingEffectiveRun, "Switching/analysis/switching_effective_observables.m", "Ridge asymmetry / skewness";
    "halfwidth_diff_norm", "(wR-wL)/(wR+wL) from alignment geometry", "Switching", source.switchingAlignmentRun, "Switching/analysis/switching_alignment_audit.m", "Half-width asymmetry deformation";
    "dI_peak_dT_mA_per_K", "dI_peak/dT from smoothed temperature profile", "Switching", source.switchingGeometryRun, "Switching/analysis/switching_geometry_diagnostics.m", "Ridge motion susceptibility";
    "dwidth_dT_mA_per_K", "d(width)/dT from smoothed profile", "Switching", source.switchingGeometryRun, "Switching/analysis/switching_geometry_diagnostics.m", "Ridge broadening rate";
    "dS_peak_dT_per_K", "dS_peak/dT from smoothed profile", "Switching", source.switchingGeometryRun, "Switching/analysis/switching_geometry_diagnostics.m", "Peak-amplitude thermal slope";
    "chi_dyn", "sqrt(mean_I((dS/dT)^2))", "Cross-experiment", source.switchingSusceptibilityRun, "analysis/switching_dynamical_susceptibility.m", "Dynamical susceptibility amplitude";
    "chi_dyn_ridge", "|dS/dT| evaluated near ridge center", "Cross-experiment", source.switchingSusceptibilityRun, "analysis/switching_dynamical_susceptibility.m", "Ridge-local susceptibility";
    "a_1", "Leading shape-mode amplitude from SVD of residual dS/dT", "Switching", source.switchingDynamicShapeRun, "Switching/analysis/switching_dynamic_shape_mode_analysis.m", "Dynamic shape mode strength";
    "shift_energy_fraction", "E_shift/(E_shift+E_shape)", "Cross-experiment", source.switchingChiDecompRun, "analysis/switching_chi_shift_shape_decomposition.m", "Motion-dominated contribution fraction";
    "shape_energy_fraction", "E_shape/(E_shift+E_shape)", "Cross-experiment", source.switchingChiDecompRun, "analysis/switching_chi_shift_shape_decomposition.m", "Internal-shape contribution fraction"
    };

tbl = cell2table(rows, 'VariableNames', { ...
    'observable_name', ...
    'mathematical_definition', ...
    'experiment_source', ...
    'source_run', ...
    'source_script', ...
    'physical_interpretation'});
end

function verifyCatalogColumns(tbl)
required = {'observable_name','mathematical_definition','experiment_source','source_run','source_script','physical_interpretation'};
assert(all(ismember(required, tbl.Properties.VariableNames)), 'Catalog table missing required columns.');
end

function [switchTbl, relaxTbl, newObsLong, newCatalogRows] = extractMissingObservables(source, cfg, run)
params = readtable(source.switchingFullScalingPath);
params = sortrows(params, 'T_K');

sus = readtable(source.switchingSusceptibilityPath);
sus = sortrows(sus, 'T_K');

core = load(source.switchingAlignmentCorePath, 'temps', 'currents', 'Smap');
Tmap = double(core.temps(:));
Igrid = double(core.currents(:));
Smap = double(core.Smap);
if size(Smap, 1) == numel(Igrid) && size(Smap, 2) == numel(Tmap)
    Smap = Smap.';
elseif ~(size(Smap, 1) == numel(Tmap) && size(Smap, 2) == numel(Igrid))
    error('Switching map size mismatch: [%d x %d] vs temps=%d currents=%d.', ...
        size(Smap, 1), size(Smap, 2), numel(Tmap), numel(Igrid));
end
[Tmap, ordT] = sort(Tmap);
[Igrid, ordI] = sort(Igrid);
Smap = Smap(ordT, ordI);

tMask = isfinite(params.T_K) & isfinite(params.Ipeak_mA) & isfinite(params.width_chosen_mA) ...
    & isfinite(params.S_peak) & isfinite(params.left_half_current_mA) ...
    & isfinite(params.right_half_current_mA) & params.width_chosen_mA > 0 ...
    & params.S_peak > 0;
params = params(tMask, :);

[Ts, ia, ib] = intersect(double(params.T_K(:)), double(sus.T_K(:)), 'stable');
[Ts, ia2, imap] = intersect(Ts, Tmap, 'stable');
ia = ia(ia2);
ib = ib(ia2);

assert(~isempty(Ts), 'No common switching temperatures across full scaling, susceptibility, and map data.');

Ipeak = double(params.Ipeak_mA(ia));
width = double(params.width_chosen_mA(ia));
Speak = double(params.S_peak(ia));
leftHalf = double(params.left_half_current_mA(ia));
rightHalf = double(params.right_half_current_mA(ia));
chiDyn = double(sus.chi_dyn(ib));
Srows = Smap(imap, :);

IpeakSmooth = smoothdata(Ipeak, 'movmean', min(cfg.derivativeSmoothWindow, numel(Ipeak)));
dIpeak = gradient(IpeakSmooth, Ts);

wL = Ipeak - leftHalf;
wR = rightHalf - Ipeak;
halfwidthRatio = safeDivide(wR, wL);
ridgeMobility = safeDivide(abs(dIpeak), width);
chiOverSpeak = safeDivide(chiDyn, Speak);

curvatureNorm = NaN(size(Ts));
for i = 1:numel(Ts)
    y = Srows(i, :);
    xAll = Igrid(:)';
    mask = isfinite(y) & isfinite(xAll);
    if nnz(mask) < 5
        continue;
    end
    x = xAll(mask);
    z = y(mask);
    z = smoothdata(z, 'movmean', min(cfg.curvatureSmoothWindow, numel(z)));
    d1 = gradient(z, x);
    d2 = gradient(d1, x);
    d2AtPeak = interp1(x, d2, Ipeak(i), 'linear', NaN);
    if isfinite(d2AtPeak)
        curvatureNorm(i) = -(width(i)^2 / max(Speak(i), eps)) * d2AtPeak;
    end
end

switchTbl = table( ...
    Ts(:), Ipeak(:), width(:), Speak(:), chiDyn(:), dIpeak(:), ...
    halfwidthRatio(:), ridgeMobility(:), chiOverSpeak(:), curvatureNorm(:), ...
    'VariableNames', {'T_K','I_peak_mA','width_mA','S_peak','chi_dyn', ...
    'dI_peak_dT_mA_per_K','halfwidth_ratio','ridge_mobility_index', ...
    'chi_dyn_over_S_peak','switch_peak_curvature_norm'});

relaxStable = readtable(source.relaxationStabilityPath);
assert(all(ismember({'T','A_T','Relax_beta_T'}, relaxStable.Properties.VariableNames)), ...
    'Relaxation stability table missing required columns.');
relaxStable = sortrows(relaxStable, 'T');

timelaw = readtable(source.relaxationTimelawPath);
assert(all(ismember({'scope','Temp_K','Relax_t_half'}, timelaw.Properties.VariableNames)), ...
    'Relaxation time-law table missing required columns.');
sliceMask = strcmp(string(timelaw.scope), "temperature_slice");
timeSlice = timelaw(sliceMask, :);
timeSlice = sortrows(timeSlice, 'Temp_K');

Trel = double(relaxStable.T(:));
beta = double(relaxStable.Relax_beta_T(:));
Arel = double(relaxStable.A_T(:));

tHalfInterp = interp1(double(timeSlice.Temp_K(:)), double(timeSlice.Relax_t_half(:)), Trel, 'pchip', NaN);
kB_eV = 8.617333262145e-5;
Eact = kB_eV .* Trel .* log(safeDivide(tHalfInterp, cfg.t0Seconds));
betaDisorder = safeDivide(1, beta) - 1;

relaxTbl = table( ...
    Trel(:), Arel(:), beta(:), tHalfInterp(:), Eact(:), betaDisorder(:), ...
    'VariableNames', {'T_K','A_T','Relax_beta_T','Relax_t_half', ...
    'E_act_relax_eV','beta_disorder_width'});

newObsLong = [ ...
    makeLongRows("switch_peak_curvature_norm", Ts, curvatureNorm, "dimensionless", "switching_map S(I,T)"); ...
    makeLongRows("ridge_mobility_index", Ts, ridgeMobility, "1/K", "switching I_peak(T), width(T)"); ...
    makeLongRows("halfwidth_ratio", Ts, halfwidthRatio, "dimensionless", "switching half-width decomposition"); ...
    makeLongRows("chi_dyn_over_S_peak", Ts, chiOverSpeak, "1/K", "chi_dyn(T) and S_peak(T)"); ...
    makeLongRows("E_act_relax_eV", Trel, Eact, "eV", "relaxation t_half(T)"); ...
    makeLongRows("beta_disorder_width", Trel, betaDisorder, "dimensionless", "relaxation beta(T)")];

newObsLong = struct2table(newObsLong);
newObsLong = sortrows(newObsLong, {'observable_name', 'temperature_K'});

scriptPath = "analysis/effective_observables_catalog_run.m";
newCatalogRows = table( ...
    ["switch_peak_curvature_norm"; "ridge_mobility_index"; "halfwidth_ratio"; ...
     "chi_dyn_over_S_peak"; "E_act_relax_eV"; "beta_disorder_width"], ...
    ["-width(T)^2/S_peak(T) * d2S/dI2 at I=I_peak(T)"; ...
     "|dI_peak/dT| / width(T)"; ...
     "wR(T)/wL(T), where wL=I_peak-I_left_half and wR=I_right_half-I_peak"; ...
     "chi_dyn(T) / S_peak(T)"; ...
     "k_B*T*ln(t_half(T)/t0), t0=1 s"; ...
     "1/beta(T) - 1"], ...
    ["Switching"; "Switching"; "Switching"; "Cross-experiment"; "Relaxation"; "Relaxation"], ...
    repmat(string(run.run_id), 6, 1), ...
    repmat(scriptPath, 6, 1), ...
    ["Normalized peak curvature of switching ridge (barrier-shape stiffness proxy)"; ...
     "Thermal ridge mobility relative to intrinsic switching width"; ...
     "Ridge deformation skew ratio between right and left half-width sectors"; ...
     "Dynamic susceptibility per unit static switching amplitude"; ...
     "Relaxation activation-energy proxy from half-time"; ...
     "Disorder / barrier-distribution width proxy from stretched exponent"], ...
    'VariableNames', {'observable_name','mathematical_definition','experiment_source', ...
    'source_run','source_script','physical_interpretation'});
end

function rows = makeLongRows(name, T, values, units, dataset)
rows = repmat(struct( ...
    'observable_name', "", ...
    'temperature_K', NaN, ...
    'value', NaN, ...
    'units', "", ...
    'dataset_source', ""), numel(T), 1);
for i = 1:numel(T)
    rows(i).observable_name = string(name);
    rows(i).temperature_K = T(i);
    rows(i).value = values(i);
    rows(i).units = string(units);
    rows(i).dataset_source = string(dataset);
end
end

function verifyNoExistingDuplicates(existingCatalog, newCatalogRows)
existingNames = lower(strtrim(string(existingCatalog.observable_name)));
newNames = lower(strtrim(string(newCatalogRows.observable_name)));
dups = intersect(unique(existingNames), unique(newNames));
assert(isempty(dups), ...
    'Proposed observable(s) already exist in catalog: %s', strjoin(cellstr(dups), ', '));
end

function figOut = makeSwitchingNewObservableFigure(switchTbl, runDir)
fh = create_figure('Visible', 'off', 'Position', [2 2 18.0 11.0]);
tlo = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plotLine(ax1, switchTbl.T_K, switchTbl.switch_peak_curvature_norm, [0.00 0.45 0.74], ...
    'switch_peak_curvature_norm(T)');
ylabel(ax1, 'dimensionless');

ax2 = nexttile(tlo, 2);
plotLine(ax2, switchTbl.T_K, switchTbl.ridge_mobility_index, [0.85 0.33 0.10], ...
    'ridge_mobility_index(T)');
ylabel(ax2, '1/K');

ax3 = nexttile(tlo, 3);
plotLine(ax3, switchTbl.T_K, switchTbl.halfwidth_ratio, [0.47 0.67 0.19], ...
    'halfwidth_ratio(T)=w_R/w_L');
ylabel(ax3, 'dimensionless');

ax4 = nexttile(tlo, 4);
plotLine(ax4, switchTbl.T_K, switchTbl.chi_dyn_over_S_peak, [0.49 0.18 0.56], ...
    'chi_dyn_over_S_peak(T)');
ylabel(ax4, '1/K');

xlabel(ax3, 'Temperature (K)');
xlabel(ax4, 'Temperature (K)');
title(tlo, 'New switching effective observables vs temperature');

paths = save_run_figure(fh, 'new_switching_observables_vs_temperature', runDir);
close(fh);

figOut = struct('main_png', string(paths.png), 'overlay_png', string(paths.png));
end

function figOut = makeRelaxationNewObservableFigure(relaxTbl, runDir)
fh = create_figure('Visible', 'off', 'Position', [2 2 16.0 8.5]);
tlo = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plotLine(ax1, relaxTbl.T_K, relaxTbl.E_act_relax_eV, [0.85 0.33 0.10], ...
    'E_act_relax_eV(T)');
ylabel(ax1, 'eV');
xlabel(ax1, 'Temperature (K)');

ax2 = nexttile(tlo, 2);
plotLine(ax2, relaxTbl.T_K, relaxTbl.beta_disorder_width, [0.00 0.45 0.74], ...
    'beta_disorder_width(T)=1/beta-1');
ylabel(ax2, 'dimensionless');
xlabel(ax2, 'Temperature (K)');

title(tlo, 'New relaxation effective observables vs temperature');
paths = save_run_figure(fh, 'new_relaxation_observables_vs_temperature', runDir);
close(fh);
figOut = struct('main_png', string(paths.png));
end
function figOut = makeOverlayFigure(source, switchTbl, relaxTbl, runDir)
relaxStable = readtable(source.relaxationStabilityPath);
switchEff = readtable(source.switchingEffectivePath);
clockTbl = readtable(source.agingClockRatioPath);
susTbl = readtable(source.switchingSusceptibilityPath);

curves = makeCurve("A(T)", double(relaxStable.T), double(relaxStable.A_T));
curves(end + 1) = makeCurve("X(T)", double(switchEff.T_K), double(switchEff.X));
curves(end + 1) = makeCurve("chi_dyn(T)", double(susTbl.T_K), double(susTbl.chi_dyn));
curves(end + 1) = makeCurve("tau_dip(Tp)", double(clockTbl.Tp), double(clockTbl.tau_dip_seconds));
curves(end + 1) = makeCurve("tau_FM(Tp)", double(clockTbl.Tp), double(clockTbl.tau_FM_seconds));
curves(end + 1) = makeCurve("R(Tp)", double(clockTbl.Tp), double(clockTbl.R_tau_FM_over_tau_dip));

curves(end + 1) = makeCurve("ridge_mobility_index", double(switchTbl.T_K), double(switchTbl.ridge_mobility_index));
curves(end + 1) = makeCurve("switch_peak_curvature_norm", double(switchTbl.T_K), double(switchTbl.switch_peak_curvature_norm));
curves(end + 1) = makeCurve("E_act_relax_eV", double(relaxTbl.T_K), double(relaxTbl.E_act_relax_eV));

fh = create_figure('Visible', 'off', 'Position', [2 2 18.0 11.0]);
ax = axes(fh);
hold(ax, 'on');
cc = lines(numel(curves));
for i = 1:numel(curves)
    [t, y] = cleanCurve(curves(i).T, curves(i).Y);
    if numel(t) < 2
        continue;
    end
    yNorm = normalize01(y);
    plot(ax, t, yNorm, '-o', 'LineWidth', 1.8, 'MarkerSize', 4.5, ...
        'Color', cc(i, :), 'DisplayName', char(curves(i).name));
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized observable (0 to 1)');
title(ax, 'Most important observables vs temperature (normalized overlay)');
legend(ax, 'Location', 'eastoutside', 'Box', 'off');
set(ax, 'FontName', 'Helvetica', 'FontSize', 11, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off');
paths = save_run_figure(fh, 'observables_vs_temperature', runDir);
close(fh);
figOut = struct('main_png', string(paths.png));
end

function c = makeCurve(name, T, Y)
c = struct('name', string(name), 'T', T(:), 'Y', Y(:));
end

function [T, Y] = cleanCurve(T, Y)
mask = isfinite(T) & isfinite(Y);
T = T(mask);
Y = Y(mask);
[T, ord] = sort(T);
Y = Y(ord);
[T, iu] = unique(T, 'stable');
Y = Y(iu);
end

function y = normalize01(x)
x = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~(isfinite(mn) && isfinite(mx) && mx > mn)
    y = NaN(size(x));
    return;
end
y = (x - mn) ./ (mx - mn);
end

function plotLine(ax, T, Y, colorVal, ttl)
plot(ax, T, Y, '-o', 'Color', colorVal, 'LineWidth', 2.0, ...
    'MarkerFaceColor', colorVal, 'MarkerSize', 5.5);
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
title(ax, ttl, 'Interpreter', 'none');
set(ax, 'FontName', 'Helvetica', 'FontSize', 11, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off');
end

function obsTbl = buildObservablesIndex(newObsLong, runId)
n = height(newObsLong);
obsTbl = table( ...
    repmat("cross_experiment", n, 1), ...
    repmat("effective_observables_catalog", n, 1), ...
    newObsLong.temperature_K, ...
    string(newObsLong.observable_name), ...
    newObsLong.value, ...
    string(newObsLong.units), ...
    repmat("observable", n, 1), ...
    repmat(string(runId), n, 1), ...
    'VariableNames', {'experiment','sample','temperature','observable','value','units','role','source_run'});
end

function reportText = buildCatalogReport(source, existingCatalog, newCatalogRows, switchTbl, relaxTbl, cfg, runDir)
lines = strings(0, 1);
lines(end + 1) = "# Effective physical observables catalog";
lines(end + 1) = "";
lines(end + 1) = "Generated: " + string(stampNow());
lines(end + 1) = "Run root: `" + string(runDir) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Step 1 - Repository scan summary";
lines(end + 1) = "- Existing observables cataloged from canonical runs and scripts: `" + string(height(existingCatalog)) + "`.";
lines(end + 1) = "- Source runs used:";
lines(end + 1) = "  - Relaxation: `" + source.relaxationStabilityRun + "`, `" + source.relaxationTimelawRun + "`, `" + source.relaxationGeometryRun + "`.";
lines(end + 1) = "  - Aging: `" + source.agingObservableRun + "`, `" + source.agingDipTauRun + "`, `" + source.agingFMTauRun + "`, `" + source.agingClockRatioRun + "`.";
lines(end + 1) = "  - Switching/Cross: `" + source.switchingEffectiveRun + "`, `" + source.switchingGeometryRun + "`, `" + source.switchingSusceptibilityRun + "`, `" + source.switchingDynamicShapeRun + "`, `" + source.switchingChiDecompRun + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Step 2 - Missing effective observables proposed";
for i = 1:height(newCatalogRows)
    lines(end + 1) = "- `" + newCatalogRows.observable_name(i) + "`: " + ...
        newCatalogRows.mathematical_definition(i) + ". Interpretation: " + ...
        newCatalogRows.physical_interpretation(i) + ".";
end
lines(end + 1) = "";
lines(end + 1) = "## Step 3 - Extraction summary";
lines(end + 1) = "- Duplicate check: proposed names were verified not to collide with the existing catalog names.";
lines(end + 1) = "- New switching observables table: `tables/new_switching_observables_vs_T.csv`.";
lines(end + 1) = "- New relaxation observables table: `tables/new_relaxation_observables_vs_T.csv`.";
lines(end + 1) = "- New long-form values: `tables/new_effective_observables_values.csv`.";
lines(end + 1) = "- New-observable index export: `observables.csv` at run root.";
lines(end + 1) = "";
lines(end + 1) = "## Step 4 - Complete catalog artifacts";
lines(end + 1) = "- CSV catalog: `tables/effective_observables_catalog.csv`.";
lines(end + 1) = "- Markdown catalog: `reports/effective_observables_catalog.md`.";
lines(end + 1) = "- Overlay figure: `figures/observables_vs_temperature.png`.";
lines(end + 1) = "- Review bundle: `review/review_bundle.zip`.";
lines(end + 1) = "";
lines(end + 1) = "## Relevant temperature regimes (new observables)";
lines(end + 1) = "- Switching-derived new observables: `" + fmtRange(switchTbl.T_K) + "` K.";
lines(end + 1) = "- Relaxation-derived new observables: `" + fmtRange(relaxTbl.T_K) + "` K.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 4 in switching-new panel, 2 in relaxation-new panel, and 9 in the normalized overlay";
lines(end + 1) = "- legend vs colormap: legends used for all multi-curve line panels";
lines(end + 1) = "- colormap used: default line color cycle (no heatmap in this run)";
lines(end + 1) = "- smoothing applied: moving-average for derivative stability in curvature and mobility calculations (`window = " + string(cfg.derivativeSmoothWindow) + "` and `" + string(cfg.curvatureSmoothWindow) + "`)";
lines(end + 1) = "- justification: line-plot diagnostics are sufficient because all extracted observables are scalar-vs-temperature quantities";
reportText = strjoin(lines, newline);
end

function txt = fmtRange(x)
x = x(isfinite(x));
if isempty(x)
    txt = "NaN";
else
    txt = sprintf('%.1f-%.1f', min(x), max(x));
end
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'observables.csv', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function y = safeDivide(a, b)
if isscalar(a) && ~isscalar(b)
    y = NaN(size(b));
    if ~isfinite(a)
        return;
    end
    mask = isfinite(b) & abs(b) > eps;
    y(mask) = a ./ b(mask);
    return;
end

if isscalar(b) && ~isscalar(a)
    y = NaN(size(a));
    if ~(isfinite(b) && abs(b) > eps)
        return;
    end
    mask = isfinite(a);
    y(mask) = a(mask) ./ b;
    return;
end

y = NaN(size(a));
mask = isfinite(a) & isfinite(b) & abs(b) > eps;
y(mask) = a(mask) ./ b(mask);
end
function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end







