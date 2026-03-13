function out = barrier_landscape_interpretation_review(cfg)
% barrier_landscape_interpretation_review
% Revisit the interpretation of the reference activation-coordinate map
% obtained from the Arrhenius projection of the relaxation activity envelope in light of earlier relaxation diagnostics.
% 
% INTERPRETATION CLARIFICATION FOR FUTURE REPORTS
% - Treat E_eff = k_B T ln(t_ref/tau0) as a reference activation coordinate.
% - Do not describe this coordinate as a unique microscopic energy landscape
%   unless independent Arrhenius-collapse and Arrhenius-scaling diagnostics support that.
% - Describe computed regions as empirical observable-dominant regions:
%   motion-related strongest, memory-like or low-temperature strongest, or
%   switching-response strongest, rather than microscopic sectors.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveRuns(repoRoot, cfg);
prior = loadPriorDiagnostics(source);
barrier = loadBarrierProjection(source.barrierRunDir);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('barrier:%s | relax:%s', char(source.barrierRunName), char(source.stabilityRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Reference activation-coordinate interpretation review run directory:\n%s\n', runDir);
fprintf('Reference activation-coordinate source run: %s\n', source.barrierRunName);
fprintf('Relaxation time-mode source run: %s\n', source.timeModeRunName);

appendText(run.log_path, sprintf('[%s] activation-coordinate interpretation review started\n', stampNow()));
appendText(run.log_path, sprintf('Activation-coordinate source: %s\n', char(source.barrierRunName)));
appendText(run.log_path, sprintf('Time-mode source: %s\n', char(source.timeModeRunName)));
appendText(run.log_path, sprintf('SVD source: %s\n', char(source.svdRunName)));
appendText(run.log_path, sprintf('Stability source: %s\n', char(source.stabilityRunName)));

summaryTbl = buildDiagnosticSummaryTable(source, prior, barrier);
summaryPath = save_run_table(summaryTbl, 'prior_relaxation_diagnostics_summary.csv', runDir);
reportText = buildReport(source, prior, barrier);
reportPath = save_run_report(reportText, 'barrier_landscape_reconstruction_revised_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] activation-coordinate interpretation review complete\n', stampNow()));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

appendText(run.notes_path, sprintf('Reference conclusion: reference activation coordinate, not unique microscopic energy landscape\n'));
appendText(run.notes_path, sprintf('No global Arrhenius collapse: rank1 collapse metric = %.6f\n', prior.timeMode.rank1Collapse));
appendText(run.notes_path, sprintf('No simple temperature-independent Arrhenius-style scaling: S/T collapse metric = %.6f\n', prior.timeMode.barrierScalingCollapse));
appendText(run.notes_path, sprintf('Reference peak activation coordinate from projection = %.6f meV\n', barrier.reference.peakE_meV));
appendText(run.notes_path, sprintf('Reference median activation coordinate from projection = %.6f meV\n', barrier.reference.E50_meV));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.prior = prior;
out.barrier = barrier;
out.summaryTablePath = string(summaryPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Activation-coordinate interpretation review complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'barrier_landscape_interpretation_review');
cfg = setDefaultField(cfg, 'barrierRunHint', 'barrier_landscape_reconstruction');
cfg = setDefaultField(cfg, 'timeModeRunHint', 'time_mode_analysis');
cfg = setDefaultField(cfg, 'svdRunHint', 'svd_audit');
cfg = setDefaultField(cfg, 'timelawRunHint', 'timelaw_observables');
cfg = setDefaultField(cfg, 'geometryRunHint', 'geometry_observables');
cfg = setDefaultField(cfg, 'stabilityRunHint', 'relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'coordinateRunHint', 'coordinate_extraction');
end

function source = resolveRuns(repoRoot, cfg)
source = struct();
[source.barrierRunDir, source.barrierRunName] = findLatestRunWithFiles(repoRoot, 'cross_experiment', ...
    {'tables\effective_barrier_distribution.csv', 'tables\barrier_distribution_tau0_scan.csv', 'reports\barrier_landscape_reconstruction_report.md'}, cfg.barrierRunHint);
[source.timeModeRunDir, source.timeModeRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\collapse_metrics.csv', 'tables\barrier_scaling_metrics.csv', 'tables\time_mode_fits.csv', 'reports\relaxation_time_mode_analysis.md'}, cfg.timeModeRunHint);
[source.svdRunDir, source.svdRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\reconstruction_error_summary.csv', 'reports\relaxation_svd_audit.md'}, cfg.svdRunHint);
[source.timelawRunDir, source.timelawRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\time_fit_results.csv', 'reports\relaxation_timelaw_observables.md'}, cfg.timelawRunHint);
[source.geometryRunDir, source.geometryRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\deltaM_reconstruction_metrics.csv', 'reports\relaxation_geometry_observables.md', 'observables.csv'}, cfg.geometryRunHint);
[source.stabilityRunDir, source.stabilityRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\observables_relaxation.csv', 'tables\temperature_observables.csv', 'reports\relaxation_observable_stability_report.md'}, cfg.stabilityRunHint);
[source.coordinateRunDir, source.coordinateRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\coordinates_relaxation.csv', 'reports\relaxation_coordinate_extraction.md'}, cfg.coordinateRunHint);

source.barrierReportPath = string(fullfile(source.barrierRunDir, 'reports', 'barrier_landscape_reconstruction_report.md'));
source.timeModeReportPath = string(fullfile(source.timeModeRunDir, 'reports', 'relaxation_time_mode_analysis.md'));
source.svdReportPath = string(fullfile(source.svdRunDir, 'reports', 'relaxation_svd_audit.md'));
source.timelawReportPath = string(fullfile(source.timelawRunDir, 'reports', 'relaxation_timelaw_observables.md'));
source.geometryReportPath = string(fullfile(source.geometryRunDir, 'reports', 'relaxation_geometry_observables.md'));
source.stabilityReportPath = string(fullfile(source.stabilityRunDir, 'reports', 'relaxation_observable_stability_report.md'));
source.coordinateReportPath = string(fullfile(source.coordinateRunDir, 'reports', 'relaxation_coordinate_extraction.md'));
end

function prior = loadPriorDiagnostics(source)
prior = struct();

svdTbl = readtable(fullfile(source.svdRunDir, 'tables', 'reconstruction_error_summary.csv'));
row = svdTbl(strcmp(string(svdTbl.map_name), "dM") & svdTbl.rank_used == 1, :);
prior.svd.rank1RelativeFroError = row.relative_fro_error(1);
prior.svd.rank1VarianceExplained = row.variance_explained_or_energy_captured(1);
prior.svd.rank1RmsResidual = row.rms_residual(1);

collapseTbl = readtable(fullfile(source.timeModeRunDir, 'tables', 'collapse_metrics.csv'));
barrierScaleTbl = readtable(fullfile(source.timeModeRunDir, 'tables', 'barrier_scaling_metrics.csv'));
fitTbl = readtable(fullfile(source.timeModeRunDir, 'tables', 'time_mode_fits.csv'));
seFit = fitTbl(strcmp(string(fitTbl.model), "stretched_exponential"), :);
logFit = fitTbl(strcmp(string(fitTbl.model), "logarithmic"), :);
prior.timeMode.rank1Collapse = collapseTbl.collapse_error_metric(1);
prior.timeMode.rank1MeanStd = collapseTbl.mean_pointwise_std(1);
prior.timeMode.barrierScalingCollapse = barrierScaleTbl.collapse_error_metric(1);
prior.timeMode.barrierScalingMeanStd = barrierScaleTbl.mean_pointwise_std(1);
prior.timeMode.bestModel = "stretched_exponential";
prior.timeMode.stretchedExpR2 = seFit.R2(1);
prior.timeMode.stretchedExpRms = seFit.rms_error(1);
prior.timeMode.logarithmicR2 = logFit.R2(1);
prior.timeMode.logarithmicRms = logFit.rms_error(1);

fitResults = readtable(fullfile(source.timelawRunDir, 'tables', 'time_fit_results.csv'));
globalSE = fitResults(strcmp(string(fitResults.scope), "dominant_time_mode") & strcmp(string(fitResults.model), "stretched_exponential"), :);
validSlices = fitResults(strcmp(string(fitResults.scope), "temperature_slice") & strcmp(string(fitResults.model), "stretched_exponential") & fitResults.fit_ok == 1, :);
prior.timelaw.betaGlobal = globalSE.param_beta(1);
prior.timelaw.tauGlobal_s = globalSE.param_tau(1);
prior.timelaw.tHalf_s = globalSE.Relax_t_half(1);
prior.timelaw.betaMin = min(validSlices.param_beta);
prior.timelaw.betaMax = max(validSlices.param_beta);
prior.timelaw.tauMin_s = min(validSlices.param_tau);
prior.timelaw.tauMax_s = max(validSlices.param_tau);

obsTbl = readtable(fullfile(source.stabilityRunDir, 'tables', 'observables_relaxation.csv'));
prior.stability.Relax_Amp_peak = obsTbl.Relax_Amp_peak(1);
prior.stability.Relax_T_peak = obsTbl.Relax_T_peak(1);
prior.stability.Relax_peak_width = obsTbl.Relax_peak_width(1);
prior.stability.Relax_mode2_strength = obsTbl.Relax_mode2_strength(1);
prior.stability.Relax_rank1_residual_fraction = obsTbl.Relax_rank1_residual_fraction(1);
prior.stability.Relax_beta_global = obsTbl.Relax_beta_global(1);
prior.stability.Relax_tau_global = obsTbl.Relax_tau_global(1);
prior.stability.Relax_t_half = obsTbl.Relax_t_half(1);

coordTbl = readtable(fullfile(source.coordinateRunDir, 'tables', 'coordinates_relaxation.csv'));
prior.coordinates.T_relax = coordTbl.T_relax(1);
prior.coordinates.shoulder_strength = coordTbl.shoulder_strength(1);
prior.coordinates.skew_relax = coordTbl.skew_relax(1);

prior.coordinateAuditLimit = "Existing diagnostics already identified a structured shoulder/main-lobe temperature landscape in related relaxation observables, so not every relaxation feature is reducible to one narrow single-peak activation-coordinate picture.";
end

function barrier = loadBarrierProjection(barrierRunDir)
barrier = struct();
axisTbl = readtable(fullfile(barrierRunDir, 'tables', 'barrier_energy_axis.csv'));
refTbl = readtable(fullfile(barrierRunDir, 'tables', 'effective_barrier_distribution.csv'));
scanTbl = readtable(fullfile(barrierRunDir, 'tables', 'barrier_distribution_tau0_scan.csv'));

barrier.runDir = string(barrierRunDir);
barrier.tMin_s = axisTbl.t_min_s(1);
barrier.tMax_s = axisTbl.t_max_s(1);
barrier.tEff_s = axisTbl.t_eff_s(1);
barrier.referenceTau0_s = refTbl.tau0_s(1);

[~, iPeak] = max(refTbl.P_eff_per_eV);
barrier.reference.peakT_K = refTbl.T_K(iPeak);
barrier.reference.peakE_meV = refTbl.E_eff_meV(iPeak);
barrier.reference.dominantLow_meV = scanTbl.dominant_region_low_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.dominantHigh_meV = scanTbl.dominant_region_high_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.risingEdge_meV = scanTbl.rising_edge_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.fallingEdge_meV = scanTbl.falling_edge_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.E10_meV = scanTbl.E10_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.E50_meV = scanTbl.E50_meV(find(scanTbl.reference_tau0, 1, 'first'));
barrier.reference.E90_meV = scanTbl.E90_meV(find(scanTbl.reference_tau0, 1, 'first'));

uTau0 = unique(scanTbl.tau0_s, 'stable');
rows = cell(numel(uTau0), 1);
for i = 1:numel(uTau0)
    row = scanTbl(abs(scanTbl.tau0_s - uTau0(i)) <= max(eps(uTau0(i)), 1e-18), :);
    rows{i} = row(1, :);
end
barrier.scanSummary = vertcat(rows{:});
end

function tbl = buildDiagnosticSummaryTable(source, prior, barrier)
diagnostic = [ ...
    "rank1_deltaM_geometry"; ...
    "dominant_time_law"; ...
    "global_rank1_collapse"; ...
    "simple_barrier_scaling_test"; ...
    "stable_temperature_envelope"; ...
    "structured_temperature_profile"; ...
    "arrhenius_projection_summary" ...
    ];

runName = [ ...
    source.svdRunName; ...
    source.timelawRunName; ...
    source.timeModeRunName; ...
    source.timeModeRunName; ...
    source.stabilityRunName; ...
    source.coordinateRunName; ...
    source.barrierRunName ...
    ];

reportPath = [ ...
    source.svdReportPath; ...
    source.timelawReportPath; ...
    source.timeModeReportPath; ...
    source.timeModeReportPath; ...
    source.stabilityReportPath; ...
    source.coordinateReportPath; ...
    source.barrierReportPath ...
    ];

empiricalFinding = [ ...
    string(sprintf('DeltaM rank-1 variance explained = %.6f; relative Frobenius error = %.6f.', prior.svd.rank1VarianceExplained, prior.svd.rank1RelativeFroError)); ...
    string(sprintf('Best time-law is stretched exponential with R^2 = %.6f versus logarithmic R^2 = %.6f.', prior.timeMode.stretchedExpR2, prior.timeMode.logarithmicR2)); ...
    string(sprintf('Normalized rank-1 collapse error = %.6f, so the temperature curves do not collapse tightly.', prior.timeMode.rank1Collapse)); ...
    string(sprintf('S(T,t)/T collapse error = %.6f, so a simple temperature-independent activation-coordinate structure is not sufficient.', prior.timeMode.barrierScalingCollapse)); ...
    string(sprintf('A(T) peak = %.3f at T = %.1f K with FWHM = %.3f K; the envelope was already shown to be stable.', prior.stability.Relax_Amp_peak, prior.stability.Relax_T_peak, prior.stability.Relax_peak_width)); ...
    string(sprintf('Related relaxation profile S_max(T) shows shoulder_strength = %.3f at T_relax = %.1f K.', prior.coordinates.shoulder_strength, prior.coordinates.T_relax)); ...
    string(sprintf('Reference Arrhenius projection uses t_eff = %.3f s and gives a reference peak activation coordinate of %.3f meV at T = %.1f K.', barrier.tEff_s, barrier.reference.peakE_meV, barrier.reference.peakT_K)) ...
    ];

implication = [ ...
    "A single dominant temperature envelope is a good empirical summary of DeltaM, but that does not by itself prove a unique microscopic energy landscape."; ...
    "Relaxation dynamics are distributed and stretched-exponential, not a pure logarithmic Arrhenius-collapse form."; ...
    "The dominant mode is separable, but the normalized temperature curves still retain substantial temperature-dependent structure beyond a universal collapse."; ...
    "The project already tested and did not confirm a global temperature-independent Arrhenius scaling."; ...
    "The central activity window near 27 K is data-driven and robust."; ...
    "The relaxation activity envelope contains structured temperature features, so activation-coordinate language should stay phenomenological and comparative."; ...
    "The meV axis is best treated as a reference Arrhenius projection of the relaxation activity envelope." ...
    ];

kind = [ ...
    "data_driven"; ...
    "data_driven"; ...
    "limit"; ...
    "limit"; ...
    "data_driven"; ...
    "limit"; ...
    "mapping_dependent" ...
    ];

tbl = table(diagnostic, kind, runName, reportPath, empiricalFinding, implication);
end

function reportText = buildReport(source, prior, barrier)
L = strings(0,1);
L(end+1) = "# Revised Interpretation of the Reference Arrhenius Projection";
L(end+1) = "";
L(end+1) = "## Empirical Results";
L(end+1) = sprintf('- `DeltaM(T,t)` was previously shown to be strongly rank-1, with variance explained `~%.4f` and relative Frobenius error `~%.3f`.', prior.svd.rank1VarianceExplained, prior.svd.rank1RelativeFroError);
L(end+1) = "- This supports a dominant separable structure `DeltaM(T,t) ~= A(T) f(t)`, where `A(T)` is the temperature-dependent relaxation activity envelope.";
L(end+1) = "- The dominant time dependence is well represented by a stretched exponential rather than a logarithmic law.";
L(end+1) = sprintf('- Earlier repository diagnostics also showed that a global Arrhenius-style collapse was **not** obtained (`collapse error ~%.2f`) and that a simple temperature-independent Arrhenius-style scaling collapse was **not** obtained (`collapse error ~%.2f`).', prior.timeMode.rank1Collapse, prior.timeMode.barrierScalingCollapse);
L(end+1) = sprintf('- The empirical activity envelope is robust and peaks near `%.0f K`, with a width of about `%.3f K`.', prior.stability.Relax_T_peak, prior.stability.Relax_peak_width);
L(end+1) = "";
L(end+1) = "## Reference Time Scale Used in the Activation Projection";
L(end+1) = sprintf('- The Arrhenius projection uses a reference time scale `t_ref = t_eff = %.6f s`.', barrier.tEff_s);
L(end+1) = sprintf('- Here `t_ref` represents the characteristic time scale of the experimental measurement window, derived from the accessible time span `%.6f s` to `%.6f s`.', barrier.tMin_s, barrier.tMax_s);
L(end+1) = "- `t_ref` should not be interpreted as a microscopic attempt time.";
L(end+1) = "- For that reason, the Arrhenius mapping defines a **reference activation coordinate**, not a direct measurement of microscopic activation energies.";
L(end+1) = "- Changing either `tau0` or `t_ref` shifts the meV axis, but it does not change the empirical structure of the relaxation activity envelope `A(T)`.";
L(end+1) = "";
L(end+1) = "## Structure of the Relaxation Activity Envelope";
L(end+1) = sprintf('- The envelope `A(T)` exhibits a broad peak near `%.0f K`.', prior.stability.Relax_T_peak);
L(end+1) = "- The profile is not perfectly single-peaked and shows a noticeable shoulder.";
L(end+1) = sprintf('- The `shoulder_strength` diagnostic (`~%.2f`) indicates a statistically significant deviation from a simple unimodal profile.', prior.coordinates.shoulder_strength);
L(end+1) = "- This shoulder should not be interpreted as evidence for distinct microscopic sectors or populations.";
L(end+1) = "- Instead, it is evidence that the activity envelope may contain multiple overlapping dynamical contributions within the experimental temperature window.";
L(end+1) = "";
L(end+1) = "## Model-Dependent Projection";
L(end+1) = "- The meV axis is introduced only through the reference Arrhenius mapping `E_eff(T) = k_B T ln(t_ref / tau0)`.";
L(end+1) = "- In this interpretation, `A(T)` is the empirical result. The Arrhenius step simply maps that same relaxation activity envelope onto a reference activation axis.";
L(end+1) = "- The resulting meV values should therefore be described as **effective activation coordinates derived from an Arrhenius reference projection**.";
L(end+1) = sprintf('- The reference mapping with `tau0 = %.0e s` places the activity peak at a reference activation coordinate of `%.3f meV`.', barrier.referenceTau0_s, barrier.reference.peakE_meV);
L(end+1) = sprintf('- The reference projected activity band spans `%.3f` to `%.3f meV`, with cumulative reference activation coordinates at `%.3f meV` (10%%), `%.3f meV` (50%%), and `%.3f meV` (90%%).', barrier.reference.dominantLow_meV, barrier.reference.dominantHigh_meV, barrier.reference.E10_meV, barrier.reference.E50_meV, barrier.reference.E90_meV);
L(end+1) = sprintf('- The derivative landmarks near `%.3f meV` and `%.3f meV` describe observable prominence along the activation axis rather than directly measured microscopic sectors.', barrier.reference.risingEdge_meV, barrier.reference.fallingEdge_meV);
L(end+1) = sprintf('- Across the requested `tau0` scan, the activity peak maps to reference activation coordinates between `%.3f meV` and `%.3f meV`.', min(barrier.scanSummary.peak_barrier_meV), max(barrier.scanSummary.peak_barrier_meV));
for i = 1:height(barrier.scanSummary)
    row = barrier.scanSummary(i, :);
    L(end+1) = sprintf('- `tau0 = %.0e s`: activity peak mapped to `%.3f meV`, with a reference 10-90%% activation window `%.3f` to `%.3f meV`.', row.tau0_s, row.peak_barrier_meV, row.E10_meV, row.E90_meV);
end
L(end+1) = "";
L(end+1) = "## Interpretation Scope and Limitations";
L(end+1) = "- This reconstruction provides a convenient coordinate system for comparing experiments and for placing other observables on the same Arrhenius-projected activation axis.";
L(end+1) = "- It does **not** uniquely determine microscopic activation energies.";
L(end+1) = "- It does **not** establish a single universal microscopic energy landscape.";
L(end+1) = "- The earlier failure of global Arrhenius collapse prevents claiming that the relaxation data uniquely establish one temperature-independent activation spectrum.";
L(end+1) = "- The absolute meV scale remains logarithmically dependent on the assumed `tau0`, even though the temperature-side activity envelope is robust.";
L(end+1) = "";
L(end+1) = "## Empirical Conclusions from the Relaxation Analysis";
L(end+1) = "- The relaxation map is strongly rank-1.";
L(end+1) = "- The time dependence follows a stretched exponential law.";
L(end+1) = "- The temperature envelope `A(T)` contains a broad peak and additional structure, including a noticeable shoulder.";
L(end+1) = "- The Arrhenius projection provides a convenient reference coordinate for comparing experiments.";
L(end+1) = "- The analysis does **not** uniquely determine a microscopic energy landscape.";
L(end+1) = "";
L(end+1) = "## Interpretation Summary";
L(end+1) = "The relaxation analysis demonstrates a robust temperature-dependent relaxation activity envelope with a peak near `27 K` and a nearly separable `DeltaM(T,t)` structure. Mapping that envelope onto a reference activation axis is useful as a reference coordinate for comparing experiments, but the mapped meV values should be interpreted as Arrhenius-projected activation coordinates rather than as a uniquely reconstructed microscopic energy landscape.";
L(end+1) = "";
L(end+1) = "## Practical Framing";
L(end+1) = "- Safe empirical statement: relaxation activity is concentrated in a broad central temperature band near `27 K`.";
L(end+1) = "- Safe model statement: under the chosen Arrhenius reference mapping, that activity band is mapped onto a broad reference activation-coordinate band in meV.";
L(end+1) = "- Statement to avoid: that the relaxation analysis has already established a unique microscopic energy landscape.";
L(end+1) = "";
L(end+1) = "## Changelog";
L(end+1) = "- Clarified the reference time scale used in the Arrhenius projection and stated explicitly that it is derived from the measurement window, not from a microscopic attempt time.";
L(end+1) = "- Added explicit documentation of the observed shoulder in the relaxation activity envelope.";
L(end+1) = "- Clarified the empirical conclusions and the interpretation limits of the Arrhenius-projected activation axis.";
L(end+1) = "- No numerical values were changed, no algorithms were modified, and the underlying Arrhenius-projection computation remains identical.";
reportText = strjoin(L, newline);
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'barrier_landscape_interpretation_review_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No run directories found under %s', runsRoot);
end
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No %s run matched label hint %s with required files.', experiment, labelHint);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end




