function out = barrier_landscape_reconstruction(cfg)
% barrier_landscape_reconstruction
% Build a reference activation-coordinate view by applying an Arrhenius
% projection to the relaxation activity envelope without rerunning the
% source pipeline.

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
source = resolveSource(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | map:%s', char(source.relaxRunName), char(source.mapRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Reference activation-coordinate reconstruction run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Relaxation map source run: %s\n', source.mapRunName);
fprintf('Relaxation map source: %s\n', source.mapPath);

appendText(run.log_path, sprintf('[%s] reference activation-coordinate reconstruction started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source run: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Map source run: %s\n', char(source.mapRunName)));
appendText(run.log_path, sprintf('Map source path: %s\n', char(source.mapPath)));

relax = loadRelaxationEnvelope(source);
scan = reconstructBarrierScan(relax, cfg);

axisTbl = buildBarrierEnergyAxisTable(scan);
refTbl = buildReferenceDistributionTable(scan, cfg.referenceTau0_s);
scanTbl = buildTau0ScanTable(scan);

axisPath = save_run_table(axisTbl, 'barrier_energy_axis.csv', runDir);
refPath = save_run_table(refTbl, 'effective_barrier_distribution.csv', runDir);
scanPath = save_run_table(scanTbl, 'barrier_distribution_tau0_scan.csv', runDir);

figA = saveAmplitudeFigure(relax, scan, runDir, 'A_vs_T');
figP = saveDistributionFigure(scan, cfg.referenceTau0_s, runDir, 'effective_barrier_distribution');
figSens = saveSensitivityFigure(scan, runDir, 'barrier_distribution_tau0_sensitivity');
figDeriv = saveDerivativeFigure(scan, runDir, 'barrier_distribution_derivative');
figCdf = saveCumulativeFigure(scan, runDir, 'barrier_distribution_cumulative');

reportText = buildReport(source, relax, scan, cfg);
reportPath = save_run_report(reportText, 'barrier_landscape_reconstruction_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] reference activation-coordinate reconstruction complete\n', stampNow()));
appendText(run.log_path, sprintf('t_min = %.9g s\n', relax.tMin_s));
appendText(run.log_path, sprintf('t_max = %.9g s\n', relax.tMax_s));
appendText(run.log_path, sprintf('t_eff = %.9g s\n', relax.tEff_s));
appendText(run.log_path, sprintf('Reference tau0 = %.9g s\n', cfg.referenceTau0_s));
appendText(run.log_path, sprintf('Activation-axis table: %s\n', axisPath));
appendText(run.log_path, sprintf('Reference projection table: %s\n', refPath));
appendText(run.log_path, sprintf('Tau0 scan table: %s\n', scanPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

refSummary = getSummaryForTau0(scan, cfg.referenceTau0_s);
appendText(run.notes_path, sprintf('t_min = %.6g s\n', relax.tMin_s));
appendText(run.notes_path, sprintf('t_max = %.6g s\n', relax.tMax_s));
appendText(run.notes_path, sprintf('t_eff = %.6g s\n', relax.tEff_s));
appendText(run.notes_path, sprintf('Reference tau0 = %.6g s\n', cfg.referenceTau0_s));
appendText(run.notes_path, sprintf('Reference peak activation coordinate = %.6g meV\n', refSummary.peakE_meV));
appendText(run.notes_path, sprintf('Reference median activation coordinate = %.6g meV\n', refSummary.E50_meV));
appendText(run.notes_path, sprintf('Reference dominant activation-coordinate region = [%.6g, %.6g] meV\n', refSummary.halfmaxLow_meV, refSummary.halfmaxHigh_meV));
appendText(run.notes_path, sprintf('Reference derivative landmarks = [%.6g, %.6g] meV\n', refSummary.derivativeRiseE_meV, refSummary.derivativeFallE_meV));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.relax = relax;
out.scan = scan;
out.tables = struct( ...
    'barrier_energy_axis', string(axisPath), ...
    'effective_distribution', string(refPath), ...
    'tau0_scan', string(scanPath));
out.figures = struct( ...
    'A_vs_T', string(figA.png), ...
    'effective_barrier_distribution', string(figP.png), ...
    'tau0_sensitivity', string(figSens.png), ...
    'derivative', string(figDeriv.png), ...
    'cumulative', string(figCdf.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Reference activation-coordinate reconstruction complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('t_eff = %.6f s (from %.6f s to %.6f s)\n', relax.tEff_s, relax.tMin_s, relax.tMax_s);
fprintf('Reference tau0 = %.1e s -> peak activation coordinate = %.3f meV\n', cfg.referenceTau0_s, refSummary.peakE_meV);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'barrier_landscape_reconstruction');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'tau0_s', [1e-9, 1e-10, 1e-11, 1e-12]);
cfg = setDefaultField(cfg, 'referenceTau0_s', 1e-10);
cfg = setDefaultField(cfg, 'kB_eV_per_K', 8.617333262145e-5);
cfg = setDefaultField(cfg, 'quantiles', [0.10, 0.50, 0.90]);
end

function source = resolveSource(repoRoot, cfg)
source = struct();
source.relaxRunName = string(cfg.relaxRunName);
source.relaxRunDir = string(fullfile(repoRoot, 'results', 'relaxation', 'runs', cfg.relaxRunName));
if exist(source.relaxRunDir, 'dir') ~= 7
    error('Relaxation source run not found: %s', source.relaxRunDir);
end

source.tempObsPath = string(fullfile(source.relaxRunDir, 'tables', 'temperature_observables.csv'));
source.obsPath = string(fullfile(source.relaxRunDir, 'tables', 'observables_relaxation.csv'));
source.manifestPath = string(fullfile(source.relaxRunDir, 'run_manifest.json'));
required = [source.tempObsPath, source.obsPath, source.manifestPath];
for i = 1:numel(required)
    if exist(required(i), 'file') ~= 2
        error('Required source file not found: %s', required(i));
    end
end

manifest = jsondecode(fileread(source.manifestPath));
mapPath = "";
if isfield(manifest, 'dataset') && ~isempty(manifest.dataset)
    candidate = string(manifest.dataset);
    if exist(candidate, 'file') == 2
        mapPath = candidate;
    end
end

if strlength(mapPath) == 0
    error('The relaxation manifest does not point to a readable source map CSV.');
end

mapRunDir = string(fileparts(fileparts(mapPath)));
if exist(mapRunDir, 'dir') ~= 7
    error('Map run directory not found for source map: %s', mapRunDir);
end

[~, mapRunName] = fileparts(mapRunDir);
source.mapPath = mapPath;
source.mapRunDir = mapRunDir;
source.mapRunName = string(mapRunName);
end

function relax = loadRelaxationEnvelope(source)
tempTbl = readtable(source.tempObsPath);
obsTbl = readtable(source.obsPath);
mapMat = readmatrix(source.mapPath);

if size(mapMat, 1) < 2 || size(mapMat, 2) < 3
    error('Source map matrix is too small to define a time axis: %s', source.mapPath);
end

xGrid = mapMat(1, 2:end);
tGrid = 10 .^ xGrid(:);
tGrid = tGrid(isfinite(tGrid) & tGrid > 0);
if isempty(tGrid)
    error('No valid positive time samples were recovered from %s', source.mapPath);
end

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.R = tempTbl.R_T(:);
relax.betaT = tempTbl.Relax_beta_T(:);
relax.tauT = tempTbl.Relax_tau_T(:);
relax.Relax_Amp_peak = obsTbl.Relax_Amp_peak(1);
relax.Relax_T_peak = obsTbl.Relax_T_peak(1);
relax.Relax_peak_width = obsTbl.Relax_peak_width(1);
relax.Relax_mode2_strength = obsTbl.Relax_mode2_strength(1);
relax.Relax_rank1_residual_fraction = obsTbl.Relax_rank1_residual_fraction(1);
relax.Relax_beta_global = obsTbl.Relax_beta_global(1);
relax.Relax_tau_global = obsTbl.Relax_tau_global(1);
relax.Relax_t_half = obsTbl.Relax_t_half(1);
relax.log10t = xGrid(:);
relax.tGrid_s = tGrid(:);
relax.tMin_s = min(tGrid);
relax.tMax_s = max(tGrid);
relax.tEff_s = sqrt(relax.tMin_s * relax.tMax_s);
relax.tEff_grid_s = exp(mean(log(tGrid)));
end

function scan = reconstructBarrierScan(relax, cfg)
scan = struct();
scan.kB_eV_per_K = cfg.kB_eV_per_K;
scan.tau0_s = cfg.tau0_s(:);
scan.referenceTau0_s = cfg.referenceTau0_s;
scan.T = relax.T(:);
scan.A = relax.A(:);
scan.tMin_s = relax.tMin_s;
scan.tMax_s = relax.tMax_s;
scan.tEff_s = relax.tEff_s;
scan.entries = cell(numel(scan.tau0_s), 1);

for i = 1:numel(scan.tau0_s)
    tau0 = scan.tau0_s(i);
    lnFactor = log(scan.tEff_s / tau0);
    E_eV = cfg.kB_eV_per_K .* scan.T .* lnFactor;
    Praw = scan.A;
    normConst = trapz(E_eV, Praw);
    if ~(isfinite(normConst) && normConst > 0)
        error('Failed to normalize activation-coordinate structure for tau0 = %.3g s', tau0);
    end

    P = Praw ./ normConst;
    dPdE = gradient(P, E_eV);
    cdf = cumtrapz(E_eV, P);
    if isfinite(cdf(end)) && cdf(end) > 0
        cdf = cdf ./ cdf(end);
    end

    qE = interpolateQuantiles(E_eV, cdf, cfg.quantiles);
    [halfLow, halfHigh, halfWidth, peakE] = halfmaxWindow(E_eV, P);
    [~, iPeak] = max(P);
    [~, iRise] = max(dPdE);
    [~, iFall] = min(dPdE);

    entry = struct();
    entry.tau0_s = tau0;
    entry.lnFactor = lnFactor;
    entry.E_eV = E_eV(:);
    entry.E_meV = 1e3 .* E_eV(:);
    entry.P_raw = Praw(:);
    entry.P = P(:);
    entry.dPdE = dPdE(:);
    entry.cdf = cdf(:);
    entry.peakIndex = iPeak;
    entry.peakT_K = scan.T(iPeak);
    entry.peakE_eV = peakE;
    entry.peakE_meV = 1e3 * peakE;
    entry.halfmaxLow_eV = halfLow;
    entry.halfmaxHigh_eV = halfHigh;
    entry.halfmaxWidth_eV = halfWidth;
    entry.halfmaxLow_meV = 1e3 * halfLow;
    entry.halfmaxHigh_meV = 1e3 * halfHigh;
    entry.halfmaxWidth_meV = 1e3 * halfWidth;
    entry.derivativeRiseIndex = iRise;
    entry.derivativeFallIndex = iFall;
    entry.derivativeRiseE_eV = E_eV(iRise);
    entry.derivativeRiseE_meV = 1e3 * E_eV(iRise);
    entry.derivativeFallE_eV = E_eV(iFall);
    entry.derivativeFallE_meV = 1e3 * E_eV(iFall);
    entry.E10_eV = qE(1);
    entry.E50_eV = qE(2);
    entry.E90_eV = qE(3);
    entry.E10_meV = 1e3 * qE(1);
    entry.E50_meV = 1e3 * qE(2);
    entry.E90_meV = 1e3 * qE(3);
    scan.entries{i} = entry;
end
end

function tbl = buildBarrierEnergyAxisTable(scan)
rows = cell(numel(scan.entries), 1);
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    n = numel(e.E_eV);
    rows{i} = table( ...
        repmat(e.tau0_s, n, 1), ...
        repmat(scan.tMin_s, n, 1), ...
        repmat(scan.tMax_s, n, 1), ...
        repmat(scan.tEff_s, n, 1), ...
        repmat(e.lnFactor, n, 1), ...
        scan.T(:), ...
        e.E_eV(:), ...
        e.E_meV(:), ...
        'VariableNames', {'tau0_s','t_min_s','t_max_s','t_eff_s','ln_t_eff_over_tau0','T_K','E_eff_eV','E_eff_meV'});
    rows{i}.reference_tau0 = repmat(e.tau0_s == scan.referenceTau0_s, n, 1);
end
tbl = vertcat(rows{:});
end

function tbl = buildReferenceDistributionTable(scan, referenceTau0)
e = getEntryForTau0(scan, referenceTau0);
tbl = table( ...
    repmat(e.tau0_s, numel(scan.T), 1), ...
    repmat(scan.tMin_s, numel(scan.T), 1), ...
    repmat(scan.tMax_s, numel(scan.T), 1), ...
    repmat(scan.tEff_s, numel(scan.T), 1), ...
    repmat(e.lnFactor, numel(scan.T), 1), ...
    scan.T(:), ...
    scan.A(:), ...
    e.E_eV(:), ...
    e.E_meV(:), ...
    e.P(:), ...
    e.dPdE(:), ...
    e.cdf(:), ...
    'VariableNames', {'tau0_s','t_min_s','t_max_s','t_eff_s','ln_t_eff_over_tau0','T_K','A_T','E_eff_eV','E_eff_meV','P_eff_per_eV','dP_dE_per_eV2','cumulative_probability'});
end

function tbl = buildTau0ScanTable(scan)
rows = cell(numel(scan.entries), 1);
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    n = numel(scan.T);
    rows{i} = table( ...
        repmat(e.tau0_s, n, 1), ...
        repmat(scan.tEff_s, n, 1), ...
        repmat(e.peakE_meV, n, 1), ...
        repmat(e.E10_meV, n, 1), ...
        repmat(e.E50_meV, n, 1), ...
        repmat(e.E90_meV, n, 1), ...
        repmat(e.halfmaxLow_meV, n, 1), ...
        repmat(e.halfmaxHigh_meV, n, 1), ...
        repmat(e.derivativeRiseE_meV, n, 1), ...
        repmat(e.derivativeFallE_meV, n, 1), ...
        scan.T(:), ...
        scan.A(:), ...
        e.E_eV(:), ...
        e.E_meV(:), ...
        e.P(:), ...
        e.dPdE(:), ...
        e.cdf(:), ...
        'VariableNames', {'tau0_s','t_eff_s','peak_barrier_meV','E10_meV','E50_meV','E90_meV','dominant_region_low_meV','dominant_region_high_meV','rising_edge_meV','falling_edge_meV','T_K','A_T','E_eff_eV','E_eff_meV','P_eff_per_eV','dP_dE_per_eV2','cumulative_probability'});
    rows{i}.reference_tau0 = repmat(e.tau0_s == scan.referenceTau0_s, n, 1);
end
tbl = vertcat(rows{:});
end

function figPaths = saveAmplitudeFigure(relax, scan, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 640]);
ax = axes(fh);
plot(ax, relax.T, relax.A, '-o', 'LineWidth', 2.4, 'MarkerSize', 6, ...
    'Color', [0.00 0.35 0.62], 'MarkerFaceColor', [0.72 0.86 0.97]);
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'A(T)', 'FontSize', 14);
title(ax, 'Relaxation activity envelope A(T)', 'FontSize', 16);
txt = sprintf('t window: %.3f to %.3f s\nt_{eff} = %.3f s', scan.tMin_s, scan.tMax_s, scan.tEff_s);
text(ax, relax.T(2), 0.90 * max(relax.A), txt, 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
set(ax, 'FontSize', 13, 'LineWidth', 1.2);
figPaths = saveFigurePng(fh, figureName, runDir);
close(fh);
end

function figPaths = saveDistributionFigure(scan, referenceTau0, runDir, figureName)
e = getEntryForTau0(scan, referenceTau0);
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 640]);
ax = axes(fh);
plot(ax, e.E_meV, e.P, '-o', 'LineWidth', 2.4, 'MarkerSize', 6, ...
    'Color', [0.75 0.23 0.13], 'MarkerFaceColor', [0.98 0.80 0.72], ...
    'DisplayName', sprintf('\\tau_0 = %.0e s', e.tau0_s));
hold(ax, 'on');
patch(ax, [e.halfmaxLow_meV e.halfmaxHigh_meV e.halfmaxHigh_meV e.halfmaxLow_meV], ...
    [0 0 max(e.P) max(e.P)], [0.98 0.88 0.82], 'FaceAlpha', 0.35, ...
    'EdgeColor', 'none', 'DisplayName', 'dominant region (FWHM)');
xline(ax, e.peakE_meV, '--', 'LineWidth', 1.8, 'Color', [0.35 0.10 0.10], ...
    'DisplayName', sprintf('peak = %.2f meV', e.peakE_meV));
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Reference activation coordinate E_{eff} (meV)', 'FontSize', 14);
ylabel(ax, 'Projected activity-envelope weight (1/eV)', 'FontSize', 14);
title(ax, 'Arrhenius projection of the relaxation activity envelope', 'FontSize', 16);
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 13, 'LineWidth', 1.2);
figPaths = saveFigurePng(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSensitivityFigure(scan, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 640]);
ax = axes(fh);
hold(ax, 'on');
colors = lines(numel(scan.entries));
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    plot(ax, e.E_meV, e.P, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, ...
        'Color', colors(i,:), 'DisplayName', sprintf('\\tau_0 = %.0e s', e.tau0_s));
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Reference activation coordinate E_{eff} (meV)', 'FontSize', 14);
ylabel(ax, 'Projected activity-envelope weight (1/eV)', 'FontSize', 14);
title(ax, 'Sensitivity of the Arrhenius projection to the attempt-time assumption', 'FontSize', 16);
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 13, 'LineWidth', 1.2);
figPaths = saveFigurePng(fh, figureName, runDir);
close(fh);
end

function figPaths = saveDerivativeFigure(scan, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 640]);
ax = axes(fh);
hold(ax, 'on');
colors = lines(numel(scan.entries));
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    plot(ax, e.E_meV, e.dPdE, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, ...
        'Color', colors(i,:), 'DisplayName', sprintf('\\tau_0 = %.0e s', e.tau0_s));
    plot(ax, e.E_meV(e.derivativeRiseIndex), e.dPdE(e.derivativeRiseIndex), 's', ...
        'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'HandleVisibility', 'off');
    plot(ax, e.E_meV(e.derivativeFallIndex), e.dPdE(e.derivativeFallIndex), 'd', ...
        'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'HandleVisibility', 'off');
end
yline(ax, 0, ':', 'LineWidth', 1.5, 'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Reference activation coordinate E_{eff} (meV)', 'FontSize', 14);
ylabel(ax, 'dP_{eff}/dE (1/eV^2)', 'FontSize', 14);
title(ax, 'Derivative of the activation-coordinate structure', 'FontSize', 16);
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 13, 'LineWidth', 1.2);
figPaths = saveFigurePng(fh, figureName, runDir);
close(fh);
end

function figPaths = saveCumulativeFigure(scan, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 640]);
ax = axes(fh);
hold(ax, 'on');
colors = lines(numel(scan.entries));
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    plot(ax, e.E_meV, e.cdf, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, ...
        'Color', colors(i,:), 'DisplayName', sprintf('\\tau_0 = %.0e s', e.tau0_s));
end
hold(ax, 'off');
grid(ax, 'on');
ylim(ax, [0 1]);
xlabel(ax, 'Reference activation coordinate E_{eff} (meV)', 'FontSize', 14);
ylabel(ax, 'Cumulative projected activity', 'FontSize', 14);
title(ax, 'Cumulative activation-coordinate structure', 'FontSize', 16);
legend(ax, 'Location', 'southeast');
set(ax, 'FontSize', 13, 'LineWidth', 1.2);
figPaths = saveFigurePng(fh, figureName, runDir);
close(fh);
end

function reportText = buildReport(source, relax, scan, cfg)
ref = getSummaryForTau0(scan, cfg.referenceTau0_s);
peakCoords = zeros(numel(scan.entries), 1);
for i = 1:numel(scan.entries)
    peakCoords(i) = scan.entries{i}.peakE_meV;
end
L = strings(0,1);
L(end+1) = "# Reference Arrhenius Projection of the Relaxation Activity Envelope";
L(end+1) = "";
L(end+1) = "## Empirical Results";
L(end+1) = sprintf('- Relaxation source run: `%s`', source.relaxRunName);
L(end+1) = sprintf('- The relaxation map is well described by a dominant separable structure `DeltaM(T,t) ~= A(T) f(t)`, and the leading time dependence is represented here by a stretched exponential with `beta = %.6f` and `tau = %.3f s`.', relax.Relax_beta_global, relax.Relax_tau_global);
L(end+1) = sprintf('- The empirical relaxation activity envelope `A(T)` peaks near `%.1f K` with FWHM `%.3f K`.', relax.Relax_T_peak, relax.Relax_peak_width);
L(end+1) = sprintf('- The experimental time window recovered from the source map is `%.6f s` to `%.6f s`.', relax.tMin_s, relax.tMax_s);
L(end+1) = sprintf('- Because the source time grid is log-spaced, `t_eff = sqrt(t_min t_max) = %.6f s` is used as a transparent reference midpoint for the Arrhenius mapping.', relax.tEff_s);
L(end+1) = "";
L(end+1) = "";
L(end+1) = "";
L(end+1) = "## Model-Dependent Projection";
L(end+1) = "- The meV axis is introduced only through the reference Arrhenius mapping `E_eff(T) = k_B T ln(t_eff / tau0)`.";
L(end+1) = "- In this report, `A(T)` is the empirical object; the Arrhenius step simply maps that same relaxation activity envelope onto a reference activation axis.";
L(end+1) = "- The resulting meV values should therefore be read as `Arrhenius-projected activation coordinates`, not as a uniquely established microscopic energy landscape.";
L(end+1) = sprintf('- Under the reference mapping with `tau0 = %.0e s`, the activity peak is mapped onto a reference activation coordinate of `%.3f meV`.', cfg.referenceTau0_s, ref.peakE_meV);
L(end+1) = sprintf('- The reference projected activity band spans `%.3f` to `%.3f meV`, with 10%%, 50%%, and 90%% cumulative reference activation coordinates at `%.3f`, `%.3f`, and `%.3f meV`.', ref.halfmaxLow_meV, ref.halfmaxHigh_meV, ref.E10_meV, ref.E50_meV, ref.E90_meV);
L(end+1) = sprintf('- The derivative landmarks occur near `%.3f meV` and `%.3f meV`; these are mapped landmarks of the reference activation axis, not direct evidence for sharp microscopic activation thresholds.', ref.derivativeRiseE_meV, ref.derivativeFallE_meV);
L(end+1) = sprintf('- Across the requested `tau0` scan, the activity peak maps to reference activation coordinates between `%.3f` and `%.3f meV`.', min(peakCoords), max(peakCoords));
for i = 1:numel(scan.entries)
    e = scan.entries{i};
    L(end+1) = sprintf('- `tau0 = %.0e s`: the activity peak maps to `%.3f meV`, and the reference 10-90%% activation window spans `%.3f` to `%.3f meV`.', e.tau0_s, e.peakE_meV, e.E10_meV, e.E90_meV);
end
L(end+1) = "";
L(end+1) = "## Interpretation Scope and Limitations";
L(end+1) = "- This reconstruction provides a convenient coordinate system for comparing experiments and for placing other observables on the same Arrhenius-projected activation axis.";
L(end+1) = "- It does not uniquely determine microscopic activation energies or a single universal microscopic energy landscape.";
L(end+1) = "- Earlier relaxation diagnostics in this repository found strong separability of `DeltaM(T,t)`, but they did not establish a global Arrhenius collapse or a single temperature-independent Arrhenius-style scaling across the full dataset.";
L(end+1) = "- Because that global Arrhenius collapse is absent, the meV axis should be treated as an Arrhenius projection of the activity envelope rather than as proof of a unique microscopic activation spectrum.";
L(end+1) = "- The absolute meV scale remains logarithmically dependent on the assumed `tau0`, even though the temperature-side activity envelope is robust.";
L(end+1) = "";
L(end+1) = "## Interpretation Summary";
L(end+1) = "The relaxation analysis establishes a robust temperature-dependent activity envelope with a peak near 27 K. Mapping this envelope onto a reference activation axis provides a convenient coordinate for comparing experiments, but should not be interpreted as a unique microscopic energy landscape.";
L(end+1) = "";
L(end+1) = "## Visualization choices";
L(end+1) = "- number of curves: 1 curve for `A(T)`, 1 curve for the reference Arrhenius projection, and 4-curve overlays for the `tau0` sensitivity, derivative, and cumulative plots";
L(end+1) = "- legend vs colormap: legends were used throughout because each plot stays compact and discrete in `tau0`";
L(end+1) = "- colormap used: MATLAB default line palette for the scan overlays";
L(end+1) = "- smoothing applied: none beyond the native discrete gradient, so the projection stays tied directly to the exported observables";
L(end+1) = "- justification: the figure set is meant to show the empirical relaxation activity envelope together with its reference Arrhenius projection and `tau0` sensitivity";
L(end+1) = "";
L(end+1) = "## Changelog";
L(end+1) = "- Interpretation corrected: legacy terminology was replaced with `reference activation coordinate`, `Arrhenius projection of the activity envelope`, and `activation-coordinate structure`.";
L(end+1) = "- The report now separates empirical results from the model-dependent Arrhenius projection layer.";
L(end+1) = "- The reconstruction algorithm, data loading, `tau0` scan, and all numerical results were unchanged; only the interpretation and documentation wording were corrected.";
reportText = strjoin(L, newline);
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'barrier_landscape_reconstruction_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function e = getEntryForTau0(scan, tau0)
idx = find(abs(scan.tau0_s - tau0) <= max(eps(tau0), 1e-18), 1, 'first');
if isempty(idx)
    error('Requested tau0 %.3g s was not found in the scan.', tau0);
end
e = scan.entries{idx};
end

function summary = getSummaryForTau0(scan, tau0)
summary = getEntryForTau0(scan, tau0);
end

function qE = interpolateQuantiles(E_eV, cdf, q)
q = q(:).';
qE = NaN(size(q));
ok = isfinite(E_eV) & isfinite(cdf);
E_eV = E_eV(ok);
cdf = cdf(ok);
if numel(E_eV) < 2
    return;
end
[cdf, ia] = unique(cdf, 'stable');
E_eV = E_eV(ia);
for i = 1:numel(q)
    qi = q(i);
    if qi <= cdf(1)
        qE(i) = E_eV(1);
    elseif qi >= cdf(end)
        qE(i) = E_eV(end);
    else
        qE(i) = interp1(cdf, E_eV, qi, 'linear');
    end
end
end

function [lo, hi, w, peakX] = halfmaxWindow(x, y)
x = x(:);
y = y(:);
lo = NaN;
hi = NaN;
w = NaN;
peakX = NaN;
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
if numel(x) < 3
    return;
end

[peakVal, ip] = max(y);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end

peakX = x(ip);
halfVal = 0.5 * peakVal;
il = find(y(1:ip) <= halfVal, 1, 'last');
if isempty(il)
    lo = x(1);
elseif il == ip
    lo = x(ip);
else
    lo = linearCross(x(il), x(il + 1), y(il) - halfVal, y(il + 1) - halfVal);
end

ir = find(y(ip:end) <= halfVal, 1, 'first');
if isempty(ir)
    hi = x(end);
else
    jr = ip + ir - 1;
    if jr == ip
        hi = x(ip);
    else
        hi = linearCross(x(jr - 1), x(jr), y(jr - 1) - halfVal, y(jr) - halfVal);
    end
end

w = hi - lo;
if ~(isfinite(w) && w >= 0)
    w = NaN;
end
end

function x0 = linearCross(x1, x2, y1, y2)
if ~all(isfinite([x1, x2, y1, y2]))
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1, x2]);
else
    x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
end
end

function paths = saveFigurePng(fh, figureName, runDir)
figureName = char(string(figureName));
figuresDir = fullfile(runDir, 'figures');
if exist(figuresDir, 'dir') ~= 7
    mkdir(figuresDir);
end
paths = struct();
paths.png = fullfile(figuresDir, [figureName '.png']);
set(fh, 'Color', 'w');
exportgraphics(fh, paths.png, 'Resolution', 300);
fprintf('Saved figure PNG: %s\n', paths.png);
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



