function out = ridge_crossover_vs_relaxation(cfg)
if nargin < 1 || ~isstruct(cfg), cfg = struct(); end
thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);
cfg = defaults(cfg, repoRoot);
runCfg = struct('runLabel', cfg.runLabel, 'dataset', sprintf('relax:%s | switch:%s', cfg.relaxRunName, cfg.switchRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
fprintf('Repository State Summary:\n');
fprintf('- Reusing switching ridge observables: I_peak(T), S_peak(T), width_I(T), halfwidth_diff_norm, asym.\n');
fprintf('- Reusing switching_alignment_core_data.mat only for the map overlay.\n');
fprintf('- Reusing relaxation A(T), R(T), Relax_T_peak, Relax_peak_width from the stability audit.\n');
fprintf('- New work is limited to light T-axis smoothing and crossover metrics.\n\n');
fprintf('Ridge-crossover vs relaxation run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] ridge-crossover vs relaxation started\n', stampNow()));
relax = loadRelaxation(cfg.relaxRunDir);
switching = loadSwitching(cfg.switchRunDir, cfg);
comp = computeCrossover(relax, switching, cfg);
metricsTbl = table(comp.T_all, switching.I_ridge, switching.S_ridge, switching.width_I, switching.halfwidth_diff_norm, switching.asym, comp.I_smooth, comp.S_smooth, comp.dI_dT, comp.dS_dT, comp.motion, comp.growth, comp.ratio, comp.balance, comp.indicator, comp.A_interp_all, comp.R_interp_all, switching.robustMask, 'VariableNames', {'T','I_ridge','S_ridge','width_I','halfwidth_diff_norm','asym','I_ridge_smooth','S_ridge_smooth','dI_ridge_dT','dS_ridge_dT','motion_dominance','growth_dominance','crossover_ratio','crossover_balance','crossover_indicator','A_interp','R_interp','robust_ridge_mask'});
summaryTbl = table(relax.Relax_T_peak, relax.Relax_peak_width, relax.windowLow, relax.windowHigh, comp.crossoverPeakT, comp.balanceCrossT, comp.regionLow, comp.regionHigh, comp.regionWidth, comp.windowOverlap, comp.peakDiffK, comp.balanceDiffK, string(comp.sequenceVerdict), string(comp.verdict), 'VariableNames', {'Relax_T_peak','Relax_peak_width','Relax_window_low','Relax_window_high','crossover_T_peak','balance_cross_T','crossover_region_low','crossover_region_high','crossover_region_width','window_overlap','peak_difference_K','balance_cross_difference_K','ridge_sequence_verdict','relaxation_alignment_verdict'});
corrTbl = table(["motion_dominance";"growth_dominance";"crossover_ratio";"crossover_indicator"], [comp.corr_A_motion;comp.corr_A_growth;comp.corr_A_ratio;comp.corr_A_indicator], [comp.corr_R_motion;comp.corr_R_growth;comp.corr_R_ratio;comp.corr_R_indicator], [rmsDiff(comp.A_norm, comp.motion(comp.robustMask));rmsDiff(comp.A_norm, comp.growth(comp.robustMask));NaN;rmsDiff(comp.A_norm, comp.indicator(comp.robustMask))], 'VariableNames', {'metric_name','corr_with_A','corr_with_R','rms_vs_A_norm'});
metricsPath = save_run_table(metricsTbl, 'ridge_crossover_metrics_vs_T.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'ridge_crossover_summary.csv', runDir);
corrPath = save_run_table(corrTbl, 'ridge_relaxation_correlation_table.csv', runDir);
fig1 = figMap(switching, runDir, 'switching_map_with_ridge');
fig2 = figTraj(switching, comp, runDir, 'ridge_position_and_amplitude_vs_T');
fig3 = figDyn(comp, runDir, 'ridge_dynamics_vs_T');
fig4 = figCompare(relax, comp, runDir, 'relaxation_vs_ridge_crossover');
fig5 = figSummary(relax, switching, comp, runDir, 'ridge_crossover_summary');
reportPath = save_run_report(buildReport(cfg, relax, comp), 'ridge_crossover_vs_relaxation_report.md', runDir);
zipPath = buildZip(runDir);
appendText(run.log_path, sprintf('[%s] complete\n', stampNow()));
appendText(run.log_path, sprintf('Tables: %s | %s | %s\n', metricsPath, summaryPath, corrPath));
appendText(run.log_path, sprintf('Report: %s\nZIP: %s\n', reportPath, zipPath));
out = struct('runDir', string(runDir), 'comparison', comp, 'reportPath', string(reportPath), 'zipPath', string(zipPath), 'figures', struct('map', string(fig1.png), 'traj', string(fig2.png), 'dyn', string(fig3.png), 'compare', string(fig4.png), 'summary', string(fig5.png)));
fprintf('\n=== Ridge-crossover vs relaxation complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(A,motion)=%.6f | corr(A,growth)=%.6f | corr(A,indicator)=%.6f\n', comp.corr_A_motion, comp.corr_A_growth, comp.corr_A_indicator);
fprintf('Relax_T_peak vs crossover_T_peak: %.3f K vs %.3f K\n', relax.Relax_T_peak, comp.crossoverPeakT);
fprintf('Relax_peak_width vs crossover_width: %.3f K vs %.3f K\n', relax.Relax_peak_width, comp.regionWidth);
fprintf('Verdict: %s\n', comp.verdict);
end

function cfg = defaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'ridge_crossover_vs_relaxation');
cfg = setDefault(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefault(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'tempSmoothWindow', 3);
cfg = setDefault(cfg, 'signalFloorFrac', 0.05);
cfg.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', cfg.relaxRunName);
cfg.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.switchRunName);
end

function relax = loadRelaxation(runDir)
obs = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
relax = struct();
relax.T = tbl.T(:); relax.A = tbl.A_T(:);
if ismember('R_T', string(tbl.Properties.VariableNames)), relax.R = tbl.R_T(:); else, relax.R = NaN(size(relax.T)); end
relax.Relax_T_peak = obs.Relax_T_peak(1); relax.Relax_peak_width = obs.Relax_peak_width(1);
[relax.windowLow, relax.windowHigh, relax.windowWidth, ~] = halfmaxWindow(relax.T, relax.A);
if ~isfinite(relax.windowWidth)
    relax.windowWidth = relax.Relax_peak_width; relax.windowLow = relax.Relax_T_peak - 0.5 * relax.Relax_peak_width; relax.windowHigh = relax.Relax_T_peak + 0.5 * relax.Relax_peak_width;
end
relax.A_norm = normMax(relax.A); relax.R_norm = normMax(relax.R);
end

function switching = loadSwitching(runDir, cfg)
obs = readtable(fullfile(runDir, 'observable_matrix.csv'));
core = load(fullfile(runDir, 'switching_alignment_core_data.mat'));
switching = struct();
switching.T = obs.T(:); switching.I_ridge = obs.I_peak(:); switching.S_ridge = obs.S_peak(:); switching.width_I = obs.width_I(:); switching.halfwidth_diff_norm = obs.halfwidth_diff_norm(:); switching.asym = obs.asym(:);
switching.currents = core.currents(:); switching.temps_map = core.temps(:); switching.Smap = core.Smap;
switching.signalFloor = cfg.signalFloorFrac * max(switching.S_ridge, [], 'omitnan');
switching.robustMask = isfinite(switching.T) & isfinite(switching.I_ridge) & isfinite(switching.S_ridge) & switching.S_ridge >= switching.signalFloor;
end

function comp = computeCrossover(relax, switching, cfg)
comp = struct();
T = switching.T(:); I = switching.I_ridge(:); S = switching.S_ridge(:); mask = switching.robustMask(:);
comp.T_all = T;
comp.I_smooth = NaN(size(T)); comp.S_smooth = NaN(size(T)); comp.dI_dT = NaN(size(T)); comp.dS_dT = NaN(size(T));
Tg = T(mask); Ig = I(mask); Sg = S(mask);
if numel(Tg) >= 3
    Is = smoothdata(Ig, 'movmean', cfg.tempSmoothWindow); Ss = smoothdata(Sg, 'movmean', cfg.tempSmoothWindow);
    comp.I_smooth(mask) = Is; comp.S_smooth(mask) = Ss; comp.dI_dT(mask) = gradient(Is, Tg); comp.dS_dT(mask) = gradient(Ss, Tg);
end
comp.motion = unitMax(abs(comp.dI_dT)); comp.growth = unitMax(abs(comp.dS_dT)); comp.ratio = comp.growth ./ max(comp.motion, 1e-6); comp.balance = comp.growth - comp.motion; comp.indicator = 0.5 * (comp.motion + comp.growth) .* max(0, 1 - abs(comp.balance));
comp.A_interp_all = NaN(size(T)); comp.R_interp_all = NaN(size(T)); comp.A_interp_all(mask) = interp1(relax.T, relax.A, Tg, 'pchip', NaN); comp.R_interp_all(mask) = interp1(relax.T, relax.R, Tg, 'pchip', NaN);
comp.A_norm = normMax(comp.A_interp_all(mask)); comp.R_norm = normMax(comp.R_interp_all(mask));
comp.corr_A_motion = corrSafe(comp.A_interp_all(mask), comp.motion(mask)); comp.corr_A_growth = corrSafe(comp.A_interp_all(mask), comp.growth(mask)); comp.corr_A_ratio = corrSafe(comp.A_interp_all(mask), comp.ratio(mask)); comp.corr_A_indicator = corrSafe(comp.A_interp_all(mask), comp.indicator(mask));
comp.corr_R_motion = corrSafe(comp.R_interp_all(mask), comp.motion(mask)); comp.corr_R_growth = corrSafe(comp.R_interp_all(mask), comp.growth(mask)); comp.corr_R_ratio = corrSafe(comp.R_interp_all(mask), comp.ratio(mask)); comp.corr_R_indicator = corrSafe(comp.R_interp_all(mask), comp.indicator(mask));
[comp.regionLow, comp.regionHigh, comp.regionWidth, comp.crossoverPeakT] = halfmaxWindow(T, comp.indicator); if ~isfinite(comp.crossoverPeakT), [~,k] = max(comp.indicator, [], 'omitnan'); if isfinite(k), comp.crossoverPeakT = T(k); end, end
comp.balanceCrossT = zeroCross(T, comp.balance);
comp.windowOverlap = intervalOverlap(relax.windowLow, relax.windowHigh, comp.regionLow, comp.regionHigh); comp.peakDiffK = comp.crossoverPeakT - relax.Relax_T_peak; comp.balanceDiffK = comp.balanceCrossT - relax.Relax_T_peak;
lowPlateau = I(mask & T <= 20); comp.lowTPlateauCurrent = modeOrMedian(lowPlateau);
highMask = mask & T >= comp.crossoverPeakT; lowMask = mask & T <= comp.crossoverPeakT;
comp.meanMotionHigh = mean(comp.motion(highMask), 'omitnan'); comp.meanGrowthHigh = mean(comp.growth(highMask), 'omitnan'); comp.meanMotionLow = mean(comp.motion(lowMask), 'omitnan'); comp.meanGrowthLow = mean(comp.growth(lowMask), 'omitnan');
if comp.meanMotionHigh > comp.meanGrowthHigh && comp.meanGrowthLow > comp.meanMotionLow && nnz(abs(I(lowMask) - comp.lowTPlateauCurrent) < 1e-9) >= 3
    comp.sequenceVerdict = "present";
elseif comp.meanMotionHigh > comp.meanGrowthHigh || comp.meanGrowthLow > comp.meanMotionLow
    comp.sequenceVerdict = "partial";
else
    comp.sequenceVerdict = "not_clear";
end
insidePeak = inWindow(comp.crossoverPeakT, relax.windowLow, relax.windowHigh); insideBalance = inWindow(comp.balanceCrossT, relax.windowLow, relax.windowHigh);
if insidePeak && comp.windowOverlap >= 0.35 && comp.corr_A_indicator >= 0.35 && comp.sequenceVerdict == "present"
    comp.verdict = "supported";
elseif (insidePeak || insideBalance || comp.windowOverlap >= 0.15) && comp.sequenceVerdict ~= "not_clear"
    comp.verdict = "partially_supported";
else
    comp.verdict = "not_supported";
end
comp.robustMask = mask;
end

function figPaths = figMap(switching, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 650]);
ax = axes(fh); imagesc(ax, switching.currents, switching.temps_map, switching.Smap); axis(ax, 'xy'); colormap(ax, parula); cb = colorbar(ax); ylabel(cb, 'Switching signal S(T,I)', 'FontSize', 14);
hold(ax, 'on'); plot(ax, switching.I_ridge, switching.T, 'k-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'I_{ridge}=I_{peak}'); plot(ax, switching.I_ridge(switching.robustMask), switching.T(switching.robustMask), 'wo', 'LineWidth', 1.8, 'MarkerSize', 6, 'DisplayName', 'robust ridge region'); hold(ax, 'off');
xlabel(ax, 'Current I (mA)', 'FontSize', 14); ylabel(ax, 'Temperature T (K)', 'FontSize', 14); title(ax, 'Switching map with ridge trajectory', 'FontSize', 16); legend(ax, 'Location', 'southwest'); set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function figPaths = figTraj(switching, comp, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); plot(ax1, switching.T, switching.I_ridge, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'I_{ridge}'); hold(ax1, 'on'); plot(ax1, switching.T, comp.I_smooth, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'smoothed I_{ridge}'); yline(ax1, comp.lowTPlateauCurrent, '--', 'LineWidth', 1.8, 'DisplayName', 'low-T plateau'); hold(ax1, 'off'); grid(ax1, 'on'); xlabel(ax1, 'Temperature T (K)', 'FontSize', 14); ylabel(ax1, 'I_{ridge}(T) (mA)', 'FontSize', 14); title(ax1, 'Ridge current trajectory', 'FontSize', 16); legend(ax1, 'Location', 'best'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);
ax2 = nexttile(tl, 2); plot(ax2, switching.T, switching.S_ridge, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'S_{ridge}'); hold(ax2, 'on'); plot(ax2, switching.T, comp.S_smooth, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'smoothed S_{ridge}'); hold(ax2, 'off'); grid(ax2, 'on'); xlabel(ax2, 'Temperature T (K)', 'FontSize', 14); ylabel(ax2, 'S_{ridge}(T)', 'FontSize', 14); title(ax2, 'Ridge amplitude evolution', 'FontSize', 16); legend(ax2, 'Location', 'best'); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function figPaths = figDyn(comp, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); plot(ax1, comp.T_all, comp.dI_dT, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'dI_{ridge}/dT'); hold(ax1, 'on'); plot(ax1, comp.T_all, comp.dS_dT, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'dS_{ridge}/dT'); xline(ax1, comp.balanceCrossT, ':', 'LineWidth', 1.8, 'DisplayName', 'balance cross'); hold(ax1, 'off'); grid(ax1, 'on'); xlabel(ax1, 'Temperature T (K)', 'FontSize', 14); ylabel(ax1, 'Derivative per K', 'FontSize', 14); title(ax1, 'Ridge dynamics from light finite differences', 'FontSize', 16); legend(ax1, 'Location', 'best'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);
ax2 = nexttile(tl, 2); plot(ax2, comp.T_all, comp.motion, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'motion dominance'); hold(ax2, 'on'); plot(ax2, comp.T_all, comp.growth, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'growth dominance'); plot(ax2, comp.T_all, comp.indicator, '-^', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'crossover indicator'); xline(ax2, comp.crossoverPeakT, '--', 'LineWidth', 1.8, 'DisplayName', 'crossover peak'); hold(ax2, 'off'); grid(ax2, 'on'); xlabel(ax2, 'Temperature T (K)', 'FontSize', 14); ylabel(ax2, 'Normalized crossover metric', 'FontSize', 14); title(ax2, 'Current-drift to amplitude-growth crossover', 'FontSize', 16); legend(ax2, 'Location', 'best'); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function figPaths = figCompare(relax, comp, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); plot(ax1, relax.T, relax.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max'); hold(ax1, 'on'); plot(ax1, relax.T, relax.R_norm, '--', 'LineWidth', 2.0, 'DisplayName', 'R(T) / max'); plot(ax1, comp.T_all, comp.motion, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'motion dominance'); plot(ax1, comp.T_all, comp.growth, '-^', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'growth dominance'); hold(ax1, 'off'); grid(ax1, 'on'); xlabel(ax1, 'Temperature T (K)', 'FontSize', 14); ylabel(ax1, 'Normalized coordinate', 'FontSize', 14); title(ax1, 'Relaxation compared to ridge motion and ridge growth', 'FontSize', 16); legend(ax1, 'Location', 'eastoutside'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);
ax2 = nexttile(tl, 2); plot(ax2, relax.T, relax.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max'); hold(ax2, 'on'); plot(ax2, relax.T, relax.R_norm, '--', 'LineWidth', 2.0, 'DisplayName', 'R(T) / max'); plot(ax2, comp.T_all, comp.indicator, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'crossover indicator'); text(ax2, min(comp.T_all(comp.robustMask))+0.5, 0.12, sprintf('corr(A,indicator)=%.3f\ncorr(R,indicator)=%.3f', comp.corr_A_indicator, comp.corr_R_indicator), 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6); hold(ax2, 'off'); grid(ax2, 'on'); xlabel(ax2, 'Temperature T (K)', 'FontSize', 14); ylabel(ax2, 'Normalized coordinate', 'FontSize', 14); title(ax2, 'Relaxation versus ridge-crossover indicator', 'FontSize', 16); legend(ax2, 'Location', 'best'); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end

function figPaths = figSummary(relax, switching, comp, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]); tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); patch(ax1, [relax.windowLow relax.windowHigh relax.windowHigh relax.windowLow], [0 0 1.05 1.05], [0.75 0.85 1.00], 'FaceAlpha', 0.30, 'EdgeColor', 'none', 'DisplayName', 'Relaxation FWHM'); hold(ax1, 'on'); patch(ax1, [comp.regionLow comp.regionHigh comp.regionHigh comp.regionLow], [0 0 1.05 1.05], [1.00 0.85 0.75], 'FaceAlpha', 0.30, 'EdgeColor', 'none', 'DisplayName', 'Crossover region'); plot(ax1, relax.T, relax.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max'); plot(ax1, relax.T, relax.R_norm, '--', 'LineWidth', 2.0, 'DisplayName', 'R(T) / max'); plot(ax1, comp.T_all, comp.indicator, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'crossover indicator'); plot(ax1, comp.T_all, comp.motion, '--', 'LineWidth', 2.0, 'DisplayName', 'motion dominance'); plot(ax1, comp.T_all, comp.growth, ':', 'LineWidth', 2.0, 'DisplayName', 'growth dominance'); plot(ax1, relax.Relax_T_peak, 1.0, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'DisplayName', 'Relax T_{peak}'); plot(ax1, comp.crossoverPeakT, 0.96, 'kd', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'DisplayName', 'crossover T_{peak}'); hold(ax1, 'off'); grid(ax1, 'on'); ylim(ax1, [0 1.05]); xlabel(ax1, 'Temperature T (K)', 'FontSize', 14); ylabel(ax1, 'Normalized coordinate', 'FontSize', 14); title(ax1, 'Relaxation window versus ridge-crossover region', 'FontSize', 16); legend(ax1, 'Location', 'eastoutside'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);
ax2 = nexttile(tl, 2); plot(ax2, switching.T, switching.I_ridge, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'I_{ridge}'); hold(ax2, 'on'); yyaxis(ax2, 'right'); plot(ax2, switching.T, switching.S_ridge, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'S_{ridge}'); yyaxis(ax2, 'left'); xline(ax2, relax.windowLow, '--', 'LineWidth', 1.8, 'HandleVisibility', 'off'); xline(ax2, relax.windowHigh, '--', 'LineWidth', 1.8, 'HandleVisibility', 'off'); xline(ax2, comp.balanceCrossT, ':', 'LineWidth', 1.8, 'DisplayName', 'balance cross'); xline(ax2, comp.crossoverPeakT, '-.', 'LineWidth', 1.8, 'DisplayName', 'crossover peak'); text(ax2, min(switching.T)+0.5, min(switching.I_ridge)+1.5, sprintf('Sequence: %s\nOverlap: %.3f\nVerdict: %s', strrep(comp.sequenceVerdict, '_', ' '), comp.windowOverlap, strrep(comp.verdict, '_', ' ')), 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6); hold(ax2, 'off'); grid(ax2, 'on'); yyaxis(ax2, 'left'); xlabel(ax2, 'Temperature T (K)', 'FontSize', 14); ylabel(ax2, 'I_{ridge}(T) (mA)', 'FontSize', 14); yyaxis(ax2, 'right'); ylabel(ax2, 'S_{ridge}(T)', 'FontSize', 14); title(ax2, 'Where ridge drift slows and ridge growth begins', 'FontSize', 16); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir); close(fh);
end
function reportText = buildReport(cfg, relax, comp)
L = strings(0,1);
L(end+1) = "# Ridge Crossover vs Relaxation Report"; L(end+1) = "";
L(end+1) = "## 1. Repository State Summary";
L(end+1) = "- Reused switching ridge observables directly from the alignment-audit exports: `I_peak(T)`, `S_peak(T)`, `width_I(T)`, `halfwidth_diff_norm`, and `asym`.";
L(end+1) = "- Reused the saved switching map from `switching_alignment_core_data.mat` only for the map-with-ridge visualization.";
L(end+1) = "- Reused relaxation `A(T)` as the primary comparison target and `R(T)` only as a secondary consistency check.";
L(end+1) = "- No new ridge detector was introduced; the ridge proxy remains `I_ridge(T)=I_peak(T)`.";
L(end+1) = "";
L(end+1) = "## 2. Files / functions reused";
L(end+1) = sprintf('- Switching source run: `%s`', cfg.switchRunName);
L(end+1) = sprintf('- Relaxation source run: `%s`', cfg.relaxRunName);
L(end+1) = "- Reused logic from `Switching/analysis/switching_alignment_audit.m`, `Switching/analysis/switching_mechanism_followup.m`, `Switching/analysis/switching_second_structural_observable_search.m`, and `Switching/analysis/switching_XI_Xshape_analysis.m`.";
L(end+1) = "";
L(end+1) = "## 3. Exact definitions of the crossover metrics";
L(end+1) = sprintf('- Robust ridge mask: `S_ridge(T) >= %.3g * max(S_ridge)`.', cfg.signalFloorFrac);
L(end+1) = sprintf('- Smoothing before finite differences: `%d`-point moving average on `I_ridge(T)` and `S_ridge(T)` only.', cfg.tempSmoothWindow);
L(end+1) = "- `motion_dominance(T) = |dI_ridge/dT| / max|dI_ridge/dT|`.";
L(end+1) = "- `growth_dominance(T) = |dS_ridge/dT| / max|dS_ridge/dT|`.";
L(end+1) = "- `crossover_ratio(T) = growth_dominance / max(motion_dominance, eps)`.";
L(end+1) = "- `crossover_balance(T) = growth_dominance - motion_dominance`.";
L(end+1) = "- `crossover_indicator(T) = 0.5*(motion_dominance + growth_dominance) * (1 - |crossover_balance|)`.";
L(end+1) = "";
L(end+1) = "## 4. Does the ridge show the claimed sequence?";
L(end+1) = sprintf('- Sequence verdict: **%s**', strrep(comp.sequenceVerdict, '_', ' '));
L(end+1) = sprintf('- High-T mean motion/growth dominance: %.3f / %.3f.', comp.meanMotionHigh, comp.meanGrowthHigh);
L(end+1) = sprintf('- Low-T mean motion/growth dominance: %.3f / %.3f.', comp.meanMotionLow, comp.meanGrowthLow);
L(end+1) = sprintf('- Low-T plateau current estimate: %.3f mA.', comp.lowTPlateauCurrent);
L(end+1) = "";
L(end+1) = "## 5. Quantitative comparison to relaxation A(T)";
L(end+1) = sprintf('- corr(A(T), motion_dominance(T)) = %.4f', comp.corr_A_motion);
L(end+1) = sprintf('- corr(A(T), growth_dominance(T)) = %.4f', comp.corr_A_growth);
L(end+1) = sprintf('- corr(A(T), crossover_ratio(T)) = %.4f', comp.corr_A_ratio);
L(end+1) = sprintf('- corr(A(T), crossover_indicator(T)) = %.4f', comp.corr_A_indicator);
L(end+1) = sprintf('- Secondary check with R(T): corr(R, motion)=%.4f, corr(R, growth)=%.4f, corr(R, indicator)=%.4f.', comp.corr_R_motion, comp.corr_R_growth, comp.corr_R_indicator);
L(end+1) = sprintf('- Relax_T_peak = %.3f K; crossover_T_peak = %.3f K; peak difference = %.3f K.', relax.Relax_T_peak, comp.crossoverPeakT, comp.peakDiffK);
L(end+1) = sprintf('- Relaxation FWHM window = [%.3f, %.3f] K.', relax.windowLow, relax.windowHigh);
L(end+1) = sprintf('- Crossover region = [%.3f, %.3f] K with width %.3f K.', comp.regionLow, comp.regionHigh, comp.regionWidth);
L(end+1) = sprintf('- Relaxation/crossover overlap fraction = %.4f.', comp.windowOverlap);
L(end+1) = sprintf('- Balance-cross temperature = %.3f K; difference from Relax_T_peak = %.3f K.', comp.balanceCrossT, comp.balanceDiffK);
L(end+1) = "";
L(end+1) = "## 6. Hypothesis verdict";
L(end+1) = sprintf('- Overall verdict: **%s**', strrep(comp.verdict, '_', ' '));
if comp.verdict == "supported"
    L(end+1) = "- The switching ridge motion-to-growth crossover lines up with the relaxation participation window in both location and broad extent.";
elseif comp.verdict == "partially_supported"
    L(end+1) = "- The switching ridge shows a motion-to-growth crossover and it touches or overlaps the relaxation window, but the alignment is not clean enough to call it a full match.";
else
    L(end+1) = "- The switching ridge either does not show a clear motion-to-growth crossover or the inferred crossover region does not align with the relaxation participation window.";
end
L(end+1) = "";
L(end+1) = "## 7. Caveats";
L(end+1) = "- Sparse temperature sampling makes the finite differences definition-sensitive.";
L(end+1) = "- Relaxation and switching temperature grids are offset, so relaxation observables were interpolated onto the switching grid for the correlations.";
L(end+1) = "- The highest-temperature switching point is low-signal and can distort ridge-drift metrics; a light signal-floor mask was applied.";
L(end+1) = "- The crossover region is not infinitely sharp in a discrete dataset, so any inferred boundary remains somewhat ambiguous.";
L(end+1) = "";
L(end+1) = "## Visualization choices";
L(end+1) = "- number of curves: 2 ridge overlays on the map, 2 curves in the trajectory panels, 3 curves in the dynamics panel, and 3-5 curves in the comparison/summary panels";
L(end+1) = "- legend vs colormap: legends for line plots because each panel stays at 6 or fewer curves; parula plus colorbar for the map";
L(end+1) = "- colormap used: parula";
L(end+1) = sprintf('- smoothing applied: %d-point moving average on `I_ridge(T)` and `S_ridge(T)` only', cfg.tempSmoothWindow);
L(end+1) = "- justification: the figure set is aimed at making the ridge motion itself visually comparable to the relaxation participation window";
reportText = strjoin(L, newline);
end

function zipPath = buildZip(runDir)
reviewDir = fullfile(runDir, 'review'); if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'ridge_crossover_vs_relaxation.zip'); if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function [lo, hi, w, peakT] = halfmaxWindow(T, y)
T = T(:); y = y(:); lo = NaN; hi = NaN; w = NaN; peakT = NaN; ok = isfinite(T) & isfinite(y); T = T(ok); y = y(ok); if numel(T) < 3, return; end
[pv, ip] = max(y); if ~(isfinite(pv) && pv > 0), return; end; peakT = T(ip); hv = 0.5 * pv; il = find(y(1:ip) <= hv, 1, 'last');
if isempty(il), lo = T(1); elseif il == ip, lo = T(ip); else, lo = xcross(T(il), T(il+1), y(il)-hv, y(il+1)-hv); end
ir = find(y(ip:end) <= hv, 1, 'first'); if isempty(ir), hi = T(end); else, jr = ip + ir - 1; if jr == ip, hi = T(ip); else, hi = xcross(T(jr-1), T(jr), y(jr-1)-hv, y(jr)-hv); end, end
w = hi - lo; if ~(isfinite(w) && w >= 0), w = NaN; end
end
function y = normMax(x)
x = x(:);
y = NaN(size(x));
m = max(x, [], 'omitnan');
if isfinite(m) && m > 0
    y = x ./ m;
end
end

function y = unitMax(x)
x = x(:);
y = NaN(size(x));
m = max(x, [], 'omitnan');
if isfinite(m) && m > 0
    y = x ./ m;
end
end

function r = corrSafe(x, y)
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
r = NaN;
if nnz(ok) < 3
    return;
end
c = corrcoef(x(ok), y(ok));
if numel(c) >= 4
    r = c(1,2);
end
end

function r = rmsDiff(x, y)
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
r = NaN;
if nnz(ok) < 3
    return;
end
r = sqrt(mean((x(ok) - y(ok)).^2));
end

function o = intervalOverlap(a, b, c, d)
o = NaN;
if ~all(isfinite([a b c d]))
    return;
end
iw = max(0, min(b, d) - max(a, c));
uw = max(b, d) - min(a, c);
if uw > 0
    o = iw / uw;
end
end

function tf = inWindow(x, a, b)
tf = all(isfinite([x a b])) && x >= a && x <= b;
end

function x = xcross(x1, x2, y1, y2)
if ~all(isfinite([x1 x2 y1 y2]))
    x = NaN;
    return;
end
if abs(y2 - y1) < eps
    x = mean([x1 x2]);
else
    x = x1 - y1 * (x2 - x1) / (y2 - y1);
end
end

function z = zeroCross(T, y)
z = NaN;
T = T(:);
y = y(:);
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
for i = 1:(numel(T) - 1)
    if y(i) == 0
        z = T(i);
        return;
    end
    if y(i) * y(i + 1) < 0
        z = xcross(T(i), T(i + 1), y(i), y(i + 1));
        return;
    end
end
end

function v = modeOrMedian(x)
x = x(isfinite(x));
v = NaN;
if isempty(x)
    return;
end
u = unique(x);
c = zeros(size(u));
for i = 1:numel(u)
    c(i) = sum(abs(x - u(i)) < 1e-9);
end
[m, k] = max(c);
if m >= 2
    v = u(k);
else
    v = median(x);
end
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

function cfg = setDefault(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end


