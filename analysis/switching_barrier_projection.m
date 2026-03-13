function out = switching_barrier_projection(cfg)
% switching_barrier_projection
if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = defaults(cfg, repoRoot);
verifyInputs(cfg);

runCfg = struct('runLabel', cfg.runLabel, ...
    'dataset', sprintf('relax:%s | switch:%s', char(cfg.relaxRunName), char(cfg.switchRunName)));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
appendText(run.log_path, sprintf('[%s] switching barrier projection started\n', stampNow()));

relax = loadRelaxation(cfg.relaxRunDir);
switching = loadSwitching(cfg.switchRunDir, cfg);
barrier = buildBarrier(relax, cfg);
proj = buildProjection(relax, switching, barrier, cfg);
metrics = summarizeAlignment(barrier, proj, cfg);

projPath = save_run_table(buildProjectionTable(proj), 'switching_barrier_projection.csv', runDir);
metricsPath = save_run_table(buildMetricsTable(metrics, cfg), 'switching_barrier_alignment_metrics.csv', runDir);
fig1 = figBarrier(barrier, proj, metrics, runDir, 'ridge_positions_on_barrier_distribution');
fig2 = figMotion(proj, metrics, runDir, 'switching_barrier_projection');
fig3 = figAmplitude(proj, metrics, runDir, 'switching_barrier_alignment');
fig4 = figTrajectory(proj, metrics, runDir, 'switching_E_J_trajectory');
reportPath = save_run_report(buildReport(cfg, metrics), 'switching_barrier_projection_report.md', runDir);
zipPath = buildZip(runDir);

appendText(run.log_path, sprintf('[%s] projection complete\n', stampNow()));
appendText(run.log_path, sprintf('Projection table: %s\n', projPath));
appendText(run.log_path, sprintf('Metrics table: %s\n', metricsPath));
appendText(run.log_path, sprintf('Report: %s\nZIP: %s\n', reportPath, zipPath));
appendText(run.notes_path, sprintf('density_peak_E_meV = %.6g\n', metrics.E_peak));
appendText(run.notes_path, sprintf('motion_peak_E_meV = %.6g\n', metrics.E_motion));
appendText(run.notes_path, sprintf('amplitude_peak_E_meV = %.6g\n', metrics.E_amp));
appendText(run.notes_path, sprintf('same_distribution_verdict = %s\n', char(metrics.sameDistribution)));

out = struct('run', run, 'runDir', string(runDir), 'tables', struct('projection', string(projPath), 'metrics', string(metricsPath)), ...
    'figures', struct('distribution', string(fig1.png), 'motion', string(fig2.png), 'alignment', string(fig3.png), 'trajectory', string(fig4.png)), ...
    'reportPath', string(reportPath), 'zipPath', string(zipPath), 'metrics', metrics);
end

function cfg = defaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'switching_barrier_projection');
cfg = setDefault(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefault(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'tau0_s', 1e-9);
cfg = setDefault(cfg, 'signalFloorFrac', 0.05);
cfg = setDefault(cfg, 'tempSmoothWindow', 3);
cfg = setDefault(cfg, 'energySmoothWindow', 3);
cfg = setDefault(cfg, 'supportFrac', 0.10);
cfg = setDefault(cfg, 'pinnedSlopeFrac', 0.50);
cfg = setDefault(cfg, 'kB_meV_per_K', 0.08617333262145);
cfg.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(string(cfg.relaxRunName)));
cfg.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(string(cfg.switchRunName)));
end

function verifyInputs(cfg)
assert(exist(fullfile(cfg.relaxRunDir, 'tables', 'temperature_observables.csv'), 'file') == 2, 'Missing relaxation temperature table.');
assert(exist(fullfile(cfg.relaxRunDir, 'tables', 'observables_relaxation.csv'), 'file') == 2, 'Missing relaxation observables table.');
assert(exist(fullfile(cfg.switchRunDir, 'observable_matrix.csv'), 'file') == 2, 'Missing switching observable matrix.');
end

function relax = loadRelaxation(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obs = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
relax.tau = tbl.Relax_tau_T(:);
relax.beta = tbl.Relax_beta_T(:);
relax.Tpeak = obs.Relax_T_peak(1);
relax.width = obs.Relax_peak_width(1);
end

function switching = loadSwitching(runDir, cfg)
tbl = readtable(fullfile(runDir, 'observable_matrix.csv'));
switching = struct();
switching.T = tbl.T(:);
switching.I = tbl.I_peak(:);
switching.S = tbl.S_peak(:);
switching.width_I = optionalColumn(tbl, 'width_I');
switching.halfwidth_diff_norm = optionalColumn(tbl, 'halfwidth_diff_norm');
switching.asym = optionalColumn(tbl, 'asym');
switching.floor = cfg.signalFloorFrac * max(switching.S, [], 'omitnan');
switching.robust = isfinite(switching.T) & isfinite(switching.I) & isfinite(switching.S) & switching.S >= switching.floor;
end

function barrier = buildBarrier(relax, cfg)
mask = isfinite(relax.T) & isfinite(relax.A) & isfinite(relax.tau) & relax.tau > 0;
T = relax.T(mask); A = max(relax.A(mask), 0); tau = relax.tau(mask);
[T, ord] = sort(T); A = A(ord); tau = tau(ord);
logTau = log(tau);
if cfg.energySmoothWindow >= 2
    logTau = smoothdata(logTau, 'movmean', min(cfg.energySmoothWindow, numel(logTau)));
end
E = cfg.kB_meV_per_K .* T .* (logTau - log(cfg.tau0_s));
E = makeIncreasing(E);
dEdT = abs(centralDiff(T, E));
P = A ./ max(dEdT, eps);
P = P ./ trapz(E, P);
dPdE = centralDiff(E, P);
[windowLo, windowHi, windowW, Epeak] = halfmax(E, P);
if ~isfinite(Epeak)
    [~, iPeak] = max(P, [], 'omitnan');
    Epeak = E(iPeak);
end
left = find(E < Epeak); right = find(E > Epeak);
[~, iL] = max(dPdE(left)); [~, iR] = min(dPdE(right));
barrier = struct('T', T, 'A', A, 'E', E, 'P', P, 'dPdE', dPdE, 'absSlope', abs(dPdE), ...
    'windowLo', windowLo, 'windowHi', windowHi, 'windowW', windowW, 'Epeak', Epeak, ...
    'Tpeak', interp1(E, T, Epeak, 'linear', NaN), 'Eleft', E(left(iL)), 'Eright', E(right(iR)), 'step', median(diff(E), 'omitnan'));
end

function proj = buildProjection(relax, switching, barrier, cfg)
keep = switching.T >= min(relax.T) & switching.T <= max(relax.T);
proj = struct();
proj.T = switching.T(keep);
proj.I = switching.I(keep);
proj.S = switching.S(keep);
proj.width_I = switching.width_I(keep);
proj.halfwidth_diff_norm = switching.halfwidth_diff_norm(keep);
proj.asym = switching.asym(keep);
proj.robust = switching.robust(keep);
proj.A = interp1(relax.T, relax.A, proj.T, 'pchip', NaN);
proj.tau = interp1(relax.T, relax.tau, proj.T, 'pchip', NaN);
proj.beta = interp1(relax.T, relax.beta, proj.T, 'pchip', NaN);
proj.E = interp1(barrier.T, barrier.E, proj.T, 'pchip', NaN);
proj.P = interp1(barrier.E, barrier.P, proj.E, 'pchip', NaN);
proj.dPdE = interp1(barrier.E, barrier.dPdE, proj.E, 'pchip', NaN);
proj.absSlope = abs(proj.dPdE);
proj.Is = NaN(size(proj.I)); proj.dIdT = NaN(size(proj.I)); proj.motion = NaN(size(proj.I));
Tg = proj.T(proj.robust); Ig = proj.I(proj.robust);
if numel(Tg) >= 2
    Is = smoothdata(Ig, 'movmean', min(cfg.tempSmoothWindow, numel(Ig)));
    proj.Is(proj.robust) = Is;
    proj.dIdT(proj.robust) = centralDiff(Tg, Is);
    proj.motion(proj.robust) = abs(proj.dIdT(proj.robust));
end
proj.analysis = proj.robust & isfinite(proj.E) & isfinite(proj.P) & isfinite(proj.motion);
proj.motionN = normalizeMask(proj.motion, proj.analysis);
proj.SN = normalizeMask(proj.S, proj.analysis);
proj.PN = normalizeMask(proj.P, proj.analysis);
end

function metrics = summarizeAlignment(barrier, proj, cfg)
mask = proj.analysis;
T = proj.T(mask); E = proj.E(mask); I = proj.Is(mask); S = proj.S(mask); motion = proj.motion(mask); P = proj.P(mask); absSlope = proj.absSlope(mask);
[~, iM] = max(motion, [], 'omitnan'); [~, iS] = max(S, [], 'omitnan');
metrics = struct();
metrics.E_peak = barrier.Epeak; metrics.T_peak = barrier.Tpeak; metrics.windowLo = barrier.windowLo; metrics.windowHi = barrier.windowHi; metrics.windowW = barrier.windowW;
metrics.E_left = barrier.Eleft; metrics.E_right = barrier.Eright;
metrics.T_motion = T(iM); metrics.E_motion = E(iM); metrics.I_motion = I(iM); metrics.P_motion = P(iM);
metrics.T_amp = T(iS); metrics.E_amp = E(iS); metrics.I_amp = I(iS); metrics.P_amp = P(iS);
metrics.motionRegion = regionLabel(metrics.E_motion, barrier); metrics.ampRegion = regionLabel(metrics.E_amp, barrier);
metrics.r_motion_P = corrSafe(motion, P); metrics.rs_motion_P = corrSafeSpearman(motion, P);
metrics.r_motion_slope = corrSafe(motion, absSlope); metrics.rs_motion_slope = corrSafeSpearman(motion, absSlope);
metrics.r_S_P = corrSafe(S, P); metrics.rs_S_P = corrSafeSpearman(S, P);
metrics.r_S_slope = corrSafe(S, absSlope); metrics.rs_S_slope = corrSafeSpearman(S, absSlope);
metrics.motionToSteep = min(abs([metrics.E_motion - barrier.Eleft, metrics.E_motion - barrier.Eright]));
metrics.ampToPeak = metrics.E_amp - barrier.Epeak;
metrics.supportFraction = mean(P >= cfg.supportFrac * max(barrier.P), 'omitnan');
metrics.motionTracksSteep = metrics.motionToSteep <= max(0.2 * barrier.windowW, barrier.step);
metrics.ampPinned = metrics.P_amp >= 0.8 * max(barrier.P) && absSlope(iS) <= cfg.pinnedSlopeFrac * max(barrier.absSlope);
if metrics.supportFraction >= 0.6
    metrics.sameDistribution = "supported";
elseif metrics.supportFraction >= 0.3
    metrics.sameDistribution = "partial";
else
    metrics.sameDistribution = "weak";
end
end
function tbl = buildProjectionTable(proj)
tbl = table(proj.T(:), proj.A(:), proj.tau(:), proj.beta(:), proj.E(:), proj.P(:), proj.dPdE(:), proj.absSlope(:), ...
    proj.I(:), proj.Is(:), proj.dIdT(:), proj.motion(:), proj.S(:), proj.width_I(:), proj.halfwidth_diff_norm(:), proj.asym(:), ...
    proj.motionN(:), proj.SN(:), proj.PN(:), proj.robust(:), proj.analysis(:), ...
    'VariableNames', {'T_K','A_interp','Relax_tau_interp_s','Relax_beta_interp','E_ridge_meV','P_eff_at_ridge_per_meV','dP_dE_at_ridge_per_meV2','abs_dP_dE_at_ridge_per_meV2','I_peak_raw_mA','I_peak_smooth_mA','dI_peak_dT_smooth_mA_per_K','motion_mA_per_K','S_peak','width_I','halfwidth_diff_norm','asym','motion_norm','S_peak_norm','P_eff_norm_at_ridge','robust_switch_mask','analysis_mask'});
end

function tbl = buildMetricsTable(metrics, cfg)
tbl = table(string(cfg.relaxRunName), string(cfg.switchRunName), cfg.tau0_s, cfg.tempSmoothWindow, cfg.signalFloorFrac, ...
    metrics.E_peak, metrics.T_peak, metrics.windowLo, metrics.windowHi, metrics.windowW, metrics.E_left, metrics.E_right, ...
    metrics.T_motion, metrics.E_motion, metrics.I_motion, string(metrics.motionRegion), metrics.T_amp, metrics.E_amp, metrics.I_amp, string(metrics.ampRegion), ...
    metrics.r_motion_P, metrics.rs_motion_P, metrics.r_motion_slope, metrics.rs_motion_slope, metrics.r_S_P, metrics.rs_S_P, metrics.r_S_slope, metrics.rs_S_slope, ...
    metrics.motionToSteep, metrics.ampToPeak, metrics.supportFraction, metrics.motionTracksSteep, metrics.ampPinned, string(metrics.sameDistribution), ...
    'VariableNames', {'relax_run_name','switch_run_name','tau0_s','temp_smooth_window','signal_floor_frac','density_peak_E_meV','density_peak_T_K','density_window_low_meV','density_window_high_meV','density_window_width_meV','steep_low_E_meV','steep_high_E_meV','motion_peak_T_K','motion_peak_E_meV','motion_peak_I_mA','motion_peak_region','amplitude_peak_T_K','amplitude_peak_E_meV','amplitude_peak_I_mA','amplitude_peak_region','pearson_motion_vs_density','spearman_motion_vs_density','pearson_motion_vs_absSlope','spearman_motion_vs_absSlope','pearson_Speak_vs_density','spearman_Speak_vs_density','pearson_Speak_vs_absSlope','spearman_Speak_vs_absSlope','motion_delta_to_nearest_steep_meV','amplitude_delta_to_density_peak_meV','switch_support_fraction','motion_tracks_steep_region','amplitude_in_pinned_sector','same_distribution_verdict'});
end

function figPaths = figBarrier(barrier, proj, metrics, runDir, name)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 720]);
ax = axes(fh);
plot(ax, barrier.E, barrier.P, 'k-', 'LineWidth', 2.2, 'DisplayName', 'P_{eff}(E)'); hold(ax, 'on');
mask = proj.analysis;
scatter(ax, proj.E(mask), proj.P(mask), 70, proj.T(mask), 'filled', 'DisplayName', 'Ridge positions');
plot(ax, metrics.E_peak, interp1(barrier.E, barrier.P, metrics.E_peak, 'pchip'), 'kd', 'MarkerFaceColor', 'y', 'MarkerSize', 9, 'DisplayName', 'Density peak');
plot(ax, metrics.E_motion, metrics.P_motion, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 9, 'DisplayName', 'Motion max');
plot(ax, metrics.E_amp, metrics.P_amp, 'bs', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Amplitude max');
plot(ax, metrics.E_left, interp1(barrier.E, barrier.P, metrics.E_left, 'pchip'), '^', 'Color', [0 0.6 0], 'MarkerFaceColor', [0 0.6 0], 'DisplayName', 'Steep low-E');
plot(ax, metrics.E_right, interp1(barrier.E, barrier.P, metrics.E_right, 'pchip'), 'v', 'Color', [0.5 0 0.7], 'MarkerFaceColor', [0.5 0 0.7], 'DisplayName', 'Steep high-E');
hold(ax, 'off'); grid(ax, 'on'); xlabel(ax, 'Barrier energy E_{eff} (meV)'); ylabel(ax, 'P_{eff}(E) (1/meV)'); title(ax, 'Barrier distribution with switching ridge positions'); legend(ax, 'Location', 'best'); cb = colorbar(ax); ylabel(cb, 'T (K)');
figPaths = save_run_figure(fh, name, runDir); close(fh);
end

function figPaths = figMotion(proj, metrics, runDir, name)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); mask = proj.analysis;
ax1 = nexttile(tl, 1); scatter(ax1, proj.P(mask), proj.motion(mask), 75, proj.E(mask), 'filled'); grid(ax1, 'on'); xlabel(ax1, 'P_{eff}(E_{ridge})'); ylabel(ax1, '|dI_{peak}/dT| (mA/K)'); title(ax1, 'Ridge motion vs barrier density'); cb = colorbar(ax1); ylabel(cb, 'E_{ridge} (meV)');
text(ax1, 0.03, 0.94, sprintf('Pearson = %.3f\nSpearman = %.3f', metrics.r_motion_P, metrics.rs_motion_P), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'Margin', 6);
ax2 = nexttile(tl, 2); yyaxis(ax2, 'left'); plot(ax2, proj.E(mask), proj.motionN(mask), '-o', 'LineWidth', 2); ylabel(ax2, 'Normalized motion'); yyaxis(ax2, 'right'); plot(ax2, proj.E(mask), proj.PN(mask), '-s', 'LineWidth', 2); ylabel(ax2, 'Normalized density'); grid(ax2, 'on'); xlabel(ax2, 'E_{ridge} (meV)'); title(ax2, 'Motion and density on the barrier axis');
figPaths = save_run_figure(fh, name, runDir); close(fh);
end

function figPaths = figAmplitude(proj, metrics, runDir, name)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); mask = proj.analysis;
ax1 = nexttile(tl, 1); scatter(ax1, proj.P(mask), proj.S(mask), 75, proj.E(mask), 'filled'); grid(ax1, 'on'); xlabel(ax1, 'P_{eff}(E_{ridge})'); ylabel(ax1, 'S_{peak}(T)'); title(ax1, 'Switching amplitude vs barrier density'); cb = colorbar(ax1); ylabel(cb, 'E_{ridge} (meV)');
text(ax1, 0.03, 0.94, sprintf('Pearson = %.3f\nSpearman = %.3f', metrics.r_S_P, metrics.rs_S_P), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'Margin', 6);
ax2 = nexttile(tl, 2); yyaxis(ax2, 'left'); plot(ax2, proj.E(mask), proj.SN(mask), '-o', 'LineWidth', 2); ylabel(ax2, 'Normalized amplitude'); yyaxis(ax2, 'right'); plot(ax2, proj.E(mask), proj.PN(mask), '-s', 'LineWidth', 2); ylabel(ax2, 'Normalized density'); grid(ax2, 'on'); xlabel(ax2, 'E_{ridge} (meV)'); title(ax2, 'Amplitude and density on the barrier axis');
figPaths = save_run_figure(fh, name, runDir); close(fh);
end

function figPaths = figTrajectory(proj, metrics, runDir, name)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); ax = axes(fh); mask = proj.analysis;
plot(ax, proj.E(mask), proj.Is(mask), '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.8); hold(ax, 'on');
scatter(ax, proj.E(mask), proj.Is(mask), 80, proj.T(mask), 'filled', 'DisplayName', 'Ridge trajectory');
plot(ax, metrics.E_motion, metrics.I_motion, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 9, 'DisplayName', 'Motion max');
plot(ax, metrics.E_amp, metrics.I_amp, 'bs', 'MarkerFaceColor', 'b', 'MarkerSize', 9, 'DisplayName', 'Amplitude max'); hold(ax, 'off');
grid(ax, 'on'); xlabel(ax, 'Barrier energy E_{ridge} (meV)'); ylabel(ax, 'Current J = I_{peak}(T) (mA)'); title(ax, 'Switching trajectory in (E,J) space'); legend(ax, 'Location', 'best'); cb = colorbar(ax); ylabel(cb, 'T (K)');
figPaths = save_run_figure(fh, name, runDir); close(fh);
end

function txt = buildReport(cfg, metrics)
L = strings(0, 1);
L(end+1) = "# Switching Barrier Projection Report";
L(end+1) = "";
L(end+1) = "## Inputs";
L(end+1) = sprintf('- Relaxation source run: `%s`.', cfg.relaxRunName);
L(end+1) = sprintf('- Switching source run: `%s`.', cfg.switchRunName);
L(end+1) = sprintf('- Barrier mapping assumption: `E_{eff}(T) = k_B T ln(\\tau(T)/\\tau_0)` with `\\tau_0 = %.3g s`.', cfg.tau0_s);
L(end+1) = "- `P_{eff}(E)` was reconstructed from the saved `A(T)` and `\\tau(T)` outputs only.";
L(end+1) = "";
L(end+1) = "## Findings";
L(end+1) = sprintf('1. Switching samples the relaxation-derived barrier distribution at the `%s` level; the support fraction inside the main distribution is `%.3f`.', strrep(metrics.sameDistribution, '_', ' '), metrics.supportFraction);
if metrics.motionTracksSteep
    L(end+1) = sprintf('2. Ridge motion is consistent with the steepest barrier sectors: the motion maximum sits `%.3f meV` from the nearest steep flank.', metrics.motionToSteep);
else
    L(end+1) = sprintf('2. Ridge motion is only partially aligned with the steepest barrier sectors: the motion maximum is `%.3f meV` from the nearest steep flank.', metrics.motionToSteep);
end
if metrics.ampPinned
    L(end+1) = sprintf('3. `S_peak` is strongest in a pinned barrier sector: the amplitude maximum sits near the density core at `E = %.3f meV`.', metrics.E_amp);
else
    L(end+1) = sprintf('3. `S_peak` does not isolate a clearly pinned barrier sector: the amplitude maximum is offset from the density peak by `%.3f meV`.', metrics.ampToPeak);
end
L(end+1) = "4. For current-tilted activation physics, the clean interpretation is that current moves the switching threshold through the same barrier landscape seen by relaxation, while the saved outputs are insufficient to invert the tilt coefficient `gamma` or pulse duration explicitly.";
L(end+1) = "";
L(end+1) = "## Correlations";
L(end+1) = sprintf('- `corr(motion, P_{eff})` = `%.4f` Pearson, `%.4f` Spearman.', metrics.r_motion_P, metrics.rs_motion_P);
L(end+1) = sprintf('- `corr(motion, |dP/dE|)` = `%.4f` Pearson, `%.4f` Spearman.', metrics.r_motion_slope, metrics.rs_motion_slope);
L(end+1) = sprintf('- `corr(S_{peak}, P_{eff})` = `%.4f` Pearson, `%.4f` Spearman.', metrics.r_S_P, metrics.rs_S_P);
L(end+1) = sprintf('- `corr(S_{peak}, |dP/dE|)` = `%.4f` Pearson, `%.4f` Spearman.', metrics.r_S_slope, metrics.rs_S_slope);
L(end+1) = "";
L(end+1) = "## Caveats";
L(end+1) = "- The absolute energy scale depends on the assumed attempt time `tau0`.";
L(end+1) = "- The source runs do not export `gamma` or pulse duration, so `(E,J)` is a barrier-sector trajectory rather than a full untilted barrier inversion.";
L(end+1) = "- Sparse switching temperatures make `|dI_{peak}/dT|` derivative-sensitive even after light smoothing.";
txt = strjoin(L, newline);
end

function zipPath = buildZip(runDir)
reviewDir = fullfile(runDir, 'review'); if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'switching_barrier_projection_bundle.zip'); if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end
function y = centralDiff(x, f)
x = x(:); f = f(:); y = NaN(size(f));
ok = isfinite(x) & isfinite(f); x = x(ok); f = f(ok);
if numel(x) < 2, return; end
if numel(x) == 2
    g = repmat((f(2) - f(1)) / (x(2) - x(1)), size(f));
else
    g = NaN(size(f));
    g(1) = (f(2) - f(1)) / (x(2) - x(1));
    g(end) = (f(end) - f(end-1)) / (x(end) - x(end-1));
    for i = 2:(numel(x) - 1)
        g(i) = (f(i+1) - f(i-1)) / (x(i+1) - x(i-1));
    end
end
y(ok) = g;
end

function x = makeIncreasing(x)
x = x(:);
for i = 2:numel(x)
    if ~(x(i) > x(i-1))
        x(i) = x(i-1) + max(eps(x(i-1)), 1e-9);
    end
end
end

function [lo, hi, w, xp] = halfmax(x, y)
x = x(:); y = y(:); lo = NaN; hi = NaN; w = NaN; xp = NaN;
ok = isfinite(x) & isfinite(y); x = x(ok); y = y(ok);
if numel(x) < 3, return; end
[yp, ip] = max(y); if ~(isfinite(yp) && yp > 0), return; end
xp = x(ip); yh = 0.5 * yp;
il = find(y(1:ip) <= yh, 1, 'last');
if isempty(il), lo = x(1); elseif il == ip, lo = x(ip); else, lo = crossLinear(x(il), x(il+1), y(il)-yh, y(il+1)-yh); end
ir = find(y(ip:end) <= yh, 1, 'first');
if isempty(ir), hi = x(end); else, jr = ip + ir - 1; if jr == ip, hi = x(ip); else, hi = crossLinear(x(jr-1), x(jr), y(jr-1)-yh, y(jr)-yh); end, end
w = hi - lo;
end

function x0 = crossLinear(x1, x2, y1, y2)
if abs(y2 - y1) < eps, x0 = mean([x1, x2], 'omitnan'); else, x0 = x1 - y1 * (x2 - x1) / (y2 - y1); end
end

function s = normalizeMask(x, mask)
x = x(:); mask = logical(mask(:)); s = NaN(size(x));
if ~any(mask), return; end
m = max(x(mask), [], 'omitnan');
if isfinite(m) && m > 0, s(mask) = x(mask) ./ m; end
end

function r = corrSafe(x, y)
x = x(:); y = y(:); ok = isfinite(x) & isfinite(y);
if nnz(ok) < 3, r = NaN; return; end
x = x(ok); y = y(ok); x = x - mean(x); y = y - mean(y); den = sqrt(sum(x.^2) * sum(y.^2));
if den <= 0 || ~isfinite(den), r = NaN; else, r = sum(x .* y) / den; end
end

function r = corrSafeSpearman(x, y)
x = x(:); y = y(:); ok = isfinite(x) & isfinite(y);
if nnz(ok) < 3, r = NaN; return; end
r = corrSafe(rankTies(x(ok)), rankTies(y(ok)));
end

function r = rankTies(x)
x = x(:); [xs, ord] = sort(x); r = NaN(size(x)); i = 1;
while i <= numel(xs)
    j = i; while j < numel(xs) && xs(j+1) == xs(i), j = j + 1; end
    r(ord(i:j)) = 0.5 * (i + j); i = j + 1;
end
end

function label = regionLabel(E, barrier)
if E < barrier.windowLo, label = "low_energy_flank"; elseif E <= barrier.windowHi, label = "high_density_core"; else, label = "high_energy_tail"; end
end

function v = optionalColumn(tbl, name)
if ismember(string(name), string(tbl.Properties.VariableNames)), v = tbl.(name)(:); else, v = NaN(height(tbl), 1); end
end

function cfg = setDefault(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field)), cfg.(field) = value; end
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a'); if fid < 0, return; end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
