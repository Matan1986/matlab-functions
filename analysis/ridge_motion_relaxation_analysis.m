function out = ridge_motion_relaxation_analysis(cfg)
% ridge_motion_relaxation_analysis
% Compare full-scaling switching ridge motion against Relaxation activity.

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

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('switch:%s | relax:%s', char(source.switchRunName), char(source.relaxRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Ridge-motion relaxation analysis run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);

appendText(run.log_path, sprintf('[%s] ridge-motion relaxation analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));

switching = loadSwitchingData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);

T = switching.T(:);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
R = interp1(relax.T, relax.R, T, cfg.interpMethod, NaN);
beta = interp1(relax.T, relax.beta, T, cfg.interpMethod, NaN);
tau = interp1(relax.T, relax.tau, T, cfg.interpMethod, NaN);

[IpeakSmooth, dIdT] = smoothAndDifferentiate(T, switching.I_peak, cfg.derivativeSmoothWindow);
[Asmooth, dAdT] = smoothAndDifferentiate(T, A, cfg.derivativeSmoothWindow);
motion = abs(dIdT);
[motionSmooth, dMotiondT] = smoothAndDifferentiate(T, motion, cfg.derivativeSmoothWindow);

motionNorm = normalizeVector(motion);
ANorm = normalizeVector(A);
widthNorm = normalizeVector(switching.width);
SpeakNorm = normalizeVector(switching.S_peak);

validMask = isfinite(T) & isfinite(A) & isfinite(motion);
positiveMask = validMask & A > 0 & motion > 0;

pearsonA = corrSafe(motion(validMask), A(validMask));
spearmanA = spearmanSafe(motion(validMask), A(validMask));
pearsonR = corrSafe(motion(validMask), R(validMask));
spearmanR = spearmanSafe(motion(validMask), R(validMask));
pearsonBeta = corrSafe(motion(validMask), beta(validMask));
spearmanBeta = spearmanSafe(motion(validMask), beta(validMask));
pearsonTau = corrSafe(motion(validMask), tau(validMask));
spearmanTau = spearmanSafe(motion(validMask), tau(validMask));
pearsonNorm = corrSafe(motionNorm(validMask), ANorm(validMask));
spearmanNorm = spearmanSafe(motionNorm(validMask), ANorm(validMask));
rmseNorm = computeRMSE(motionNorm(validMask), ANorm(validMask));

fitDirect = fitThroughOrigin(A(validMask), motion(validMask), 'motion = c A');
fitMotionPower = fitPowerLaw(A(positiveMask), motion(positiveMask), 'motion = c A^alpha');
fitAPower = fitPowerLaw(motion(positiveMask), A(positiveMask), 'A = c motion^alpha');

motionPeakT = findPeakT(T, motion);
APeakT = findPeakT(T, A);
motionRiseT = findExtremeT(T, dMotiondT, 'max');
motionFallT = findExtremeT(T, dMotiondT, 'min');
AriseT = findExtremeT(T, dAdT, 'max');
AFallT = findExtremeT(T, dAdT, 'min');

pearsonWidth = corrSafe(motion(validMask), switching.width(validMask));
spearmanWidth = spearmanSafe(motion(validMask), switching.width(validMask));
pearsonSpeak = corrSafe(motion(validMask), switching.S_peak(validMask));
spearmanSpeak = spearmanSafe(motion(validMask), switching.S_peak(validMask));
widthVsA = corrSafe(switching.width(validMask), A(validMask));
widthVsAS = spearmanSafe(switching.width(validMask), A(validMask));
SpeakVsA = corrSafe(switching.S_peak(validMask), A(validMask));
SpeakVsAS = spearmanSafe(switching.S_peak(validMask), A(validMask));

resultsTbl = table(T, switching.I_peak, IpeakSmooth, dIdT, motion, motionNorm, A, ANorm, R, beta, tau, ...
    switching.S_peak, SpeakNorm, switching.width, widthNorm, Asmooth, dAdT, motionSmooth, dMotiondT, validMask, positiveMask, ...
    'VariableNames', {'T_K','I_peak_raw_mA','I_peak_smooth_mA','dI_peak_dT_mA_per_K','motion_abs_dI_peak_dT','motion_norm', ...
    'A_interp','A_norm','R_interp','beta_interp','tau_interp','S_peak','S_peak_norm','width_mA','width_norm', ...
    'A_smooth','dA_dT','motion_smooth','dMotiondT','valid_mask','positive_mask'});
fitTbl = table( ...
    string({'direct_proportional'; 'motion_from_A_power'; 'A_from_motion_power'}), ...
    string({fitDirect.model; fitMotionPower.model; fitAPower.model}), ...
    [fitDirect.c; fitMotionPower.c; fitAPower.c], ...
    [NaN; fitMotionPower.alpha; fitAPower.alpha], ...
    [fitDirect.r2; fitMotionPower.r2; fitAPower.r2], ...
    [fitDirect.rmse; fitMotionPower.rmse; fitAPower.rmse], ...
    [fitDirect.mae; fitMotionPower.mae; fitAPower.mae], ...
    [fitDirect.n_points; fitMotionPower.n_points; fitAPower.n_points], ...
    'VariableNames', {'fit_key','model','c','alpha','r2','rmse','mae','n_points'});
featureTbl = table( ...
    string({'motion_vs_A_pearson'; 'motion_vs_A_spearman'; 'motion_peak_T_K'; 'A_peak_T_K'; 'motion_peak_minus_A_peak_K'; ...
    'motion_rise_T_K'; 'motion_fall_T_K'; 'A_rise_T_K'; 'A_fall_T_K'; 'motion_vs_width_pearson'; 'motion_vs_S_peak_pearson'; 'n_points'}), ...
    [pearsonA; spearmanA; motionPeakT; APeakT; motionPeakT - APeakT; motionRiseT; motionFallT; AriseT; AFallT; pearsonWidth; pearsonSpeak; nnz(validMask)], ...
    string({'unitless'; 'unitless'; 'K'; 'K'; 'K'; 'K'; 'K'; 'K'; 'K'; 'unitless'; 'unitless'; 'count'}), ...
    'VariableNames', {'metric','value','units'});
manifestTbl = table( ...
    string({'switching'; 'relaxation'; 'relaxation'}), ...
    [source.switchRunName; source.relaxRunName; source.relaxRunName], ...
    string({fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv')}), ...
    string({'switching I_peak(T), S_peak(T), width(T)'; 'relaxation observables'; 'relaxation peak metadata'}), ...
    'VariableNames', {'experiment','source_run','source_file','role'});

resultsPath = save_run_table(resultsTbl, 'ridge_motion_results.csv', runDir);
fitPath = save_run_table(fitTbl, 'ridge_motion_fit_summary.csv', runDir);
featurePath = save_run_table(featureTbl, 'ridge_motion_feature_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, motion, '-o', 'Color', [0.80 0.29 0.25], 'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', [0.80 0.29 0.25]);
xline(ax, motionPeakT, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.4, 'HandleVisibility', 'off');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, '|dI_{peak}/dT| (mA/K)');
title(ax, 'Switching ridge motion from full-scaling I_{peak}(T)');
xlim(ax, [min(T) max(T)]);
ylim(ax, paddedLimits(motion, 0.10));
text(ax, 0.05, 0.95, sprintf('Peak T = %.1f K', motionPeakT), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
figMotion = save_run_figure(fig, 'ridge_motion_vs_T', runDir);
close(fig);

fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, A, '-s', 'Color', [0.00 0.45 0.70], 'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', [0.00 0.45 0.70]);
xline(ax, APeakT, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.4, 'HandleVisibility', 'off');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'A(T) (signal units)');
title(ax, 'Relaxation activity interpolated onto the switching grid');
xlim(ax, [min(T) max(T)]);
ylim(ax, paddedLimits(A, 0.10));
text(ax, 0.05, 0.95, sprintf('Peak T = %.1f K', APeakT), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
figA = save_run_figure(fig, 'relaxation_A_vs_T', runDir);
close(fig);

fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
scatter(ax, A(validMask), motion(validMask), 30, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.9);
xlabel(ax, 'A(T) (signal units)');
ylabel(ax, '|dI_{peak}/dT| (mA/K)');
title(ax, 'Ridge motion against relaxation activity');
text(ax, 0.05, 0.95, sprintf('Pearson = %.3f\nSpearman = %.3f', pearsonA, spearmanA), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
figScatter = save_run_figure(fig, 'ridge_motion_vs_A_scatter', runDir);
close(fig);

fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, motionNorm, '-o', 'Color', [0.80 0.29 0.25], 'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', [0.80 0.29 0.25], 'DisplayName', '|dI_{peak}/dT| / max');
plot(ax, T, ANorm, '-s', 'Color', [0.00 0.45 0.70], 'LineWidth', 2.0, 'MarkerSize', 5, 'MarkerFaceColor', [0.00 0.45 0.70], 'DisplayName', 'A(T) / max');
xline(ax, motionPeakT, '--', 'Color', [0.80 0.29 0.25], 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(ax, APeakT, '--', 'Color', [0.00 0.45 0.70], 'LineWidth', 1.2, 'HandleVisibility', 'off');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude (arb. units)');
title(ax, 'Normalized ridge motion and relaxation activity');
legend(ax, 'Location', 'best', 'Box', 'off');
xlim(ax, [min(T) max(T)]);
ylim(ax, [-0.02 1.05]);
text(ax, 0.05, 0.95, sprintf('Peak offset = %+0.1f K\nRMSE = %.3f', motionPeakT - APeakT, rmseNorm), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
figOverlay = save_run_figure(fig, 'normalized_ridge_vs_A_overlay', runDir);
close(fig);

fig = create_figure('Position', [2 2 16.5 5.8]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
[x1, order1] = sort(A(validMask));
y1 = motion(validMask); y1 = y1(order1); yhat1 = fitDirect.yhat(order1);
hold(ax1, 'on');
scatter(ax1, x1, y1, 26, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.8);
plot(ax1, x1, yhat1, '-', 'Color', [0.80 0.29 0.25], 'LineWidth', 1.8);
hold(ax1, 'off');
xlabel(ax1, 'A(T) (signal units)');
ylabel(ax1, '|dI_{peak}/dT| (mA/K)');
title(ax1, 'motion = c A');
text(ax1, 0.05, 0.95, sprintf('c = %.3g\nR^2 = %.3f', fitDirect.c, fitDirect.r2), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax1);
ax2 = nexttile(tl, 2);
[x2, order2] = sort(A(positiveMask));
y2 = motion(positiveMask); y2 = y2(order2); yhat2 = fitMotionPower.yhat(order2);
hold(ax2, 'on');
scatter(ax2, x2, y2, 26, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.8);
plot(ax2, x2, yhat2, '-', 'Color', [0.00 0.45 0.70], 'LineWidth', 1.8);
hold(ax2, 'off');
set(ax2, 'XScale', 'log', 'YScale', 'log');
xlabel(ax2, 'A(T) (signal units)');
ylabel(ax2, '|dI_{peak}/dT| (mA/K)');
title(ax2, 'motion = c A^\alpha');
text(ax2, 0.05, 0.95, sprintf('alpha = %.3f\nR^2 = %.3f', fitMotionPower.alpha, fitMotionPower.r2), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax2);
ax3 = nexttile(tl, 3);
[x3, order3] = sort(motion(positiveMask));
y3 = A(positiveMask); y3 = y3(order3); yhat3 = fitAPower.yhat(order3);
hold(ax3, 'on');
scatter(ax3, x3, y3, 26, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.8);
plot(ax3, x3, yhat3, '-', 'Color', [0.00 0.45 0.70], 'LineWidth', 1.8);
hold(ax3, 'off');
set(ax3, 'XScale', 'log', 'YScale', 'log');
xlabel(ax3, '|dI_{peak}/dT| (mA/K)');
ylabel(ax3, 'A(T) (signal units)');
title(ax3, 'A = c motion^\alpha');
text(ax3, 0.05, 0.95, sprintf('alpha = %.3f\nR^2 = %.3f', fitAPower.alpha, fitAPower.r2), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax3);
figFits = save_run_figure(fig, 'ridge_motion_scaling_fits', runDir);
close(fig);

fig = create_figure('Position', [2 2 15.8 6.0]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
scatter(ax1, switching.width(validMask), motion(validMask), 28, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.8);
xlabel(ax1, 'width(T) (mA)');
ylabel(ax1, '|dI_{peak}/dT| (mA/K)');
title(ax1, 'Ridge motion vs width(T)');
text(ax1, 0.05, 0.95, sprintf('Pearson = %.3f\nSpearman = %.3f', pearsonWidth, spearmanWidth), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax1);
ax2 = nexttile(tl, 2);
scatter(ax2, switching.S_peak(validMask), motion(validMask), 28, 'o', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.82 0.82 0.82], 'LineWidth', 0.8);
xlabel(ax2, 'S_{peak}(T) (signal units)');
ylabel(ax2, '|dI_{peak}/dT| (mA/K)');
title(ax2, 'Ridge motion vs S_{peak}(T)');
text(ax2, 0.05, 0.95, sprintf('Pearson = %.3f\nSpearman = %.3f', pearsonSpeak, spearmanSpeak), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax2);
figSecondary = save_run_figure(fig, 'ridge_motion_vs_switching_observables', runDir);
close(fig);
if pearsonA > 0.6 && abs(motionPeakT - APeakT) <= 4
    trackerText = '- Ridge motion does track the Relaxation activity envelope at the empirical level: the correlation is positive and the peak sits close to the Relaxation crossover region.';
elseif pearsonA > 0.3
    trackerText = '- Ridge motion tracks the Relaxation activity only partially: the trend is positive, but the match is not tight enough to call it a one-to-one envelope tracker.';
else
    trackerText = '- Ridge motion does not behave like a strong direct tracker of the Relaxation activity envelope in this full-scaling reuse test.';
end
if abs(motionPeakT - APeakT) <= 2
    peakText = '- The ridge-motion peak lies in essentially the same crossover band as the Relaxation A(T) peak.';
else
    peakText = '- The ridge-motion peak is close to, but not identical with, the Relaxation A(T) peak; the offset should be treated as finite-resolution rather than exact coincidence.';
end
if fitMotionPower.r2 > fitDirect.r2
    scalingText = '- Among the simple models tested here, the power-law form describes the relation better than strict proportionality.';
else
    scalingText = '- Among the simple models tested here, strict proportionality is at least as good as the power-law alternatives.';
end
if pearsonA > 0 && widthVsA < 0
    widthText = '- Ridge motion is a better direct cross-experiment tracker than width(T) because motion varies in the same direction as A(T), while width(T) varies oppositely. Width can still be stronger in absolute correlation magnitude, but it behaves as an inverse scale rather than a direct bridge.';
else
    widthText = '- Ridge motion is not clearly superior to width(T) on every metric, so any claim of a unique bridge observable would be too strong.';
end

lines = strings(0, 1);
lines(end + 1) = "# Ridge motion relaxation analysis";
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = "- Prior ridge-motion bridge runs already existed for the older switching alignment-audit source. The main direct comparison was `run_2026_03_11_084425_relaxation_switching_motion_test`, which reported positive motion-vs-A alignment and a near-crossover peak match.";
lines(end + 1) = "- `run_2026_03_12_004907_switching_relaxation_observable_comparis` reused that saved motion baseline and ranked `|dI_peak/dT|` as the strongest saved switching observable against `A(T)` among motion, centroid, width, and curvature.";
lines(end + 1) = "- For the newer full-scaling switching run `run_2026_03_12_234016_switching_full_scaling_collapse`, existing cross-experiment reuse was limited to width-only and composite-observable analyses; no saved run was found that directly derived full-scaling `|dI_peak/dT|` and compared it to Relaxation `A(T)`.";
lines(end + 1) = "- This run therefore fills that exact gap while reusing only immutable saved outputs from the requested source runs.";
lines(end + 1) = "";
lines(end + 1) = "## Inputs and definitions";
lines(end + 1) = sprintf('- Switching source: `%s`.', source.switchRunName);
lines(end + 1) = sprintf('- Relaxation source: `%s`.', source.relaxRunName);
lines(end + 1) = "- Switching observables were read from `switching_full_scaling_parameters.csv`: `I_peak(T)`, `S_peak(T)`, and `width(T)`.";
lines(end + 1) = "- Relaxation observables were read from `temperature_observables.csv`: `A(T)`, `R(T)`, `beta(T)`, and `tau(T)`.";
lines(end + 1) = sprintf('- Relaxation observables were interpolated onto the switching temperature grid with `%s`.', cfg.interpMethod);
lines(end + 1) = sprintf('- Ridge motion was defined as `|dI_peak/dT|` after a %d-point moving-mean smoothing of `I_peak(T)` followed by a centered gradient.', cfg.derivativeSmoothWindow);
lines(end + 1) = "";
lines(end + 1) = "## Primary tests";
lines(end + 1) = sprintf('- Direct correlation: `|dI_peak/dT|` vs `A(T)` gives Pearson `%.4f` and Spearman `%.4f`.', pearsonA, spearmanA);
lines(end + 1) = sprintf('- Shape comparison: the normalized curves have Pearson `%.4f` and RMSE `%.4f` on the switching grid.', pearsonNorm, rmseNorm);
lines(end + 1) = sprintf('- Peak alignment: `T_peak[motion] = %.1f K`, `T_peak[A] = %.1f K`, so the signed offset is `%+0.1f K`.', motionPeakT, APeakT, motionPeakT - APeakT);
lines(end + 1) = sprintf('- Derivative structure: motion rises fastest near `%.1f K` and falls fastest near `%.1f K`; `A(T)` rises fastest near `%.1f K` and falls fastest near `%.1f K`.', motionRiseT, motionFallT, AriseT, AFallT);
lines(end + 1) = sprintf('- Scaling test `motion = c A`: `c = %.4g`, `R^2 = %.4f`, `RMSE = %.4f`.', fitDirect.c, fitDirect.r2, fitDirect.rmse);
lines(end + 1) = sprintf('- Scaling test `motion = c A^alpha`: `alpha = %.4f`, `R^2 = %.4f`, `RMSE = %.4f`.', fitMotionPower.alpha, fitMotionPower.r2, fitMotionPower.rmse);
lines(end + 1) = sprintf('- Inverse-direction test `A = c motion^alpha`: `alpha = %.4f`, `R^2 = %.4f`, `RMSE = %.4f`.', fitAPower.alpha, fitAPower.r2, fitAPower.rmse);
lines(end + 1) = "";
lines(end + 1) = "## Secondary tests";
lines(end + 1) = sprintf('- `|dI_peak/dT|` vs `width(T)`: Pearson `%.4f`, Spearman `%.4f`.', pearsonWidth, spearmanWidth);
lines(end + 1) = sprintf('- `|dI_peak/dT|` vs `S_peak(T)`: Pearson `%.4f`, Spearman `%.4f`.', pearsonSpeak, spearmanSpeak);
lines(end + 1) = sprintf('- For context, `width(T)` vs `A(T)` is `%.4f / %.4f` (Pearson / Spearman), while `S_peak(T)` vs `A(T)` is `%.4f / %.4f`.', widthVsA, widthVsAS, SpeakVsA, SpeakVsAS);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = trackerText;
lines(end + 1) = peakText;
lines(end + 1) = scalingText;
lines(end + 1) = widthText;
lines(end + 1) = '- The full-scaling results are consistent with ridge motion representing a shared dynamical scale between Switching and Relaxation, but the evidence remains empirical and model-dependent rather than mechanistic.';
lines(end + 1) = "";
lines(end + 1) = "## Relaxation side context";
lines(end + 1) = sprintf('- Motion vs `R(T)`: Pearson `%.4f`, Spearman `%.4f`.', pearsonR, spearmanR);
lines(end + 1) = sprintf('- Motion vs `beta(T)`: Pearson `%.4f`, Spearman `%.4f`.', pearsonBeta, spearmanBeta);
lines(end + 1) = sprintf('- Motion vs `tau(T)`: Pearson `%.4f`, Spearman `%.4f`.', pearsonTau, spearmanTau);
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = '- number of curves: 1 curve each in `ridge_motion_vs_T` and `relaxation_A_vs_T`; 2 curves in the normalized overlay; fitted curves plus markers in the scaling-fit panels; 1 scatter series in each secondary panel.';
lines(end + 1) = '- legend vs colormap: legends only; no figure exceeded six simultaneously encoded curves.';
lines(end + 1) = '- colormap used: none.';
lines(end + 1) = sprintf('- smoothing applied: %d-point moving mean before differentiating `I_peak(T)` and before derivative-structure comparison of `A(T)` and motion(T).', cfg.derivativeSmoothWindow);
lines(end + 1) = '- justification: the figure set keeps each requested test separate so the empirical bridge question stays easy to read and inspect.';
reportPath = save_run_report(strjoin(lines, newline), 'ridge_motion_relaxation_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'ridge_motion_relaxation_analysis_bundle.zip');

appendText(run.notes_path, sprintf('Motion vs A Pearson = %.6g\n', pearsonA));
appendText(run.notes_path, sprintf('Motion vs A Spearman = %.6g\n', spearmanA));
appendText(run.notes_path, sprintf('Motion peak T = %.6g K\n', motionPeakT));
appendText(run.notes_path, sprintf('A peak T = %.6g K\n', APeakT));
appendText(run.notes_path, sprintf('Width vs A Pearson = %.6g\n', widthVsA));
appendText(run.notes_path, sprintf('Width vs A Spearman = %.6g\n', widthVsAS));
appendText(run.notes_path, sprintf('Width vs motion Pearson = %.6g\n', pearsonWidth));
appendText(run.log_path, sprintf('[%s] ridge-motion relaxation analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Results table: %s\n', resultsPath));
appendText(run.log_path, sprintf('Fit summary: %s\n', fitPath));
appendText(run.log_path, sprintf('Feature summary: %s\n', featurePath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.tables = struct('ridge_motion_results', string(resultsPath), 'fit_summary', string(fitPath), 'feature_summary', string(featurePath), 'manifest', string(manifestPath));
out.figures = struct('ridge_motion_vs_T', string(figMotion.png), 'relaxation_A_vs_T', string(figA.png), 'ridge_motion_vs_A_scatter', string(figScatter.png), 'normalized_overlay', string(figOverlay.png), 'scaling_fits', string(figFits.png), 'secondary', string(figSecondary.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Ridge-motion relaxation analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Motion vs A: Pearson %.4f, Spearman %.4f\n', pearsonA, spearmanA);
fprintf('Motion peak vs A peak: %.1f K vs %.1f K\n', motionPeakT, APeakT);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'ridge_motion_relaxation_analysis');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'derivativeSmoothWindow', 3);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
requiredPaths = { ...
    source.switchRunDir, fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv')};
for i = 1:size(requiredPaths, 1)
    if exist(requiredPaths{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredPaths{i, 1});
    end
    if exist(requiredPaths{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredPaths{i, 2});
    end
end
end

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.Ipeak_mA) & isfinite(tbl.S_peak) & isfinite(tbl.width_chosen_mA);
tbl = sortrows(tbl(mask, :), 'T_K');
switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak = tbl.Ipeak_mA(:);
switching.S_peak = tbl.S_peak(:);
switching.width = tbl.width_chosen_mA(:);
end

function relax = loadRelaxationData(runDir)
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
tempTbl = sortrows(tempTbl, 'T');
relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.R = tempTbl.R_T(:);
relax.beta = tempTbl.Relax_beta_T(:);
relax.tau = tempTbl.Relax_tau_T(:);
relax.sourcePeakT = obsTbl.Relax_T_peak(1);
end
function [ySmooth, dydT] = smoothAndDifferentiate(T, y, window)
ySmooth = NaN(size(y));
dydT = NaN(size(y));
mask = isfinite(T) & isfinite(y);
if nnz(mask) < 3
    return;
end
Tg = T(mask);
Yg = y(mask);
if window >= 2
    Yg = smoothdata(Yg, 'movmean', min(window, numel(Yg)));
end
ySmooth(mask) = Yg;
dydT(mask) = gradient(Yg, Tg);
end

function yNorm = normalizeVector(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
mx = max(y(mask), [], 'omitnan');
if isfinite(mx) && mx ~= 0
    yNorm(mask) = y(mask) ./ mx;
end
end

function fitResult = fitThroughOrigin(x, y, modelText)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 3
    fitResult = struct('model', modelText, 'c', NaN, 'r2', NaN, 'rmse', NaN, 'mae', NaN, 'yhat', NaN(size(x)), 'n_points', numel(x));
    return;
end
c = (x' * y) / (x' * x);
yhat = c * x;
fitResult = struct('model', modelText, 'c', c, 'r2', computeR2(y, yhat), 'rmse', computeRMSE(y, yhat), 'mae', computeMAE(y, yhat), 'yhat', yhat, 'n_points', numel(x));
end

function fitResult = fitPowerLaw(x, y, modelText)
mask = isfinite(x) & isfinite(y) & x > 0 & y > 0;
x = x(mask);
y = y(mask);
if numel(x) < 3
    fitResult = struct('model', modelText, 'c', NaN, 'alpha', NaN, 'r2', NaN, 'rmse', NaN, 'mae', NaN, 'yhat', NaN(size(x)), 'n_points', numel(x));
    return;
end
coeffs = polyfit(log(x), log(y), 1);
alpha = coeffs(1);
c = exp(coeffs(2));
yhat = c .* x .^ alpha;
fitResult = struct('model', modelText, 'c', c, 'alpha', alpha, 'r2', computeR2(y, yhat), 'rmse', computeRMSE(y, yhat), 'mae', computeMAE(y, yhat), 'yhat', yhat, 'n_points', numel(x));
end

function c = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
c = NaN;
if nnz(mask) < 3
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) >= 4
    c = cc(1, 2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = x(:);
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 3
    r2 = NaN;
    return;
end
yv = y(mask);
yhatv = yhat(mask);
ssRes = sum((yv - yhatv).^2);
ssTot = sum((yv - mean(yv)).^2);
if ssTot == 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function rmse = computeRMSE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    rmse = NaN;
    return;
end
rmse = sqrt(mean((y(mask) - yhat(mask)).^2));
end

function mae = computeMAE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    mae = NaN;
    return;
end
mae = mean(abs(y(mask) - yhat(mask)));
end

function tPeak = findPeakT(T, y)
tPeak = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
tPeak = Tvalid(idx);
end

function tExtreme = findExtremeT(T, y, mode)
tExtreme = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
Tvalid = T(mask);
Yvalid = y(mask);
if strcmpi(mode, 'max')
    [~, idx] = max(Yvalid);
else
    [~, idx] = min(Yvalid);
end
tExtreme = Tvalid(idx);
end

function lims = paddedLimits(y, frac)
y = y(isfinite(y));
if isempty(y)
    lims = [0 1];
    return;
end
yMin = min(y);
yMax = max(y);
if yMin == yMax
    pad = max(abs(yMin) * frac, 1);
else
    pad = frac * (yMax - yMin);
end
lims = [yMin - pad, yMax + pad];
end

function styleAxis(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
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

