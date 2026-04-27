%% RUN_RELAXATION_RF5A_AMPLITUDE_FACTORIZATION
% RF5A amplitude-only replay on RF3R post-field-off robust-baseline object:
%   DeltaM(t;T) ~= A(T) * F(t)
%
% Scope guards (RF3R rerun):
% - Uses ONLY relaxation_post_field_off_RF3R_canonical run tables (no RF3 / old RF5A inputs).
% - Default replay set only (valid_for_default_replay == YES); quality-flagged traces excluded.
% - Diagnostic-only outputs.
% - No time-rescaling collapse / no general collapse optimization / no RF5B / no cross-module.

clear; clc;
rng(42, "twister");

%% Resolve repo root
current_dir = pwd;
temp_dir = current_dir;
repoRoot = '';
for level = 1:15
    if exist(fullfile(temp_dir, 'README.md'), 'file') && ...
       exist(fullfile(temp_dir, 'Aging'), 'dir') && ...
       exist(fullfile(temp_dir, 'Switching'), 'dir')
        repoRoot = temp_dir;
        break;
    end
    parent_dir = fileparts(temp_dir);
    if strcmp(parent_dir, temp_dir), break; end
    temp_dir = parent_dir;
end
if isempty(repoRoot)
    error('Could not detect repo root.');
end

addpath(fullfile(repoRoot, 'tools', 'figures'));

run_id = "run_2026_04_26_234453";
rfRunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', run_id);
rfTablesDir = fullfile(rfRunDir, 'tables');

figDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_amplitude_factorization_RF3R', run_id);
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(outTablesDir), mkdir(outTablesDir); end
if ~isfolder(outReportsDir), mkdir(outReportsDir); end

failurePath = fullfile(outTablesDir, 'relaxation_RF5A_verdict_status_RF3R.csv');

%% Load required inputs (RF3R run only)
rf3rGate = readtable(fullfile(outTablesDir, 'relaxation_RF3R_gate_audit_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
rf4bGate = readtable(fullfile(outTablesDir, 'relaxation_RF4B_visualization_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
creation = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_creation_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
manifest = readtable(fullfile(rfTablesDir, 'relaxation_event_origin_manifest.csv'), ...
    "TextType", "string", "Delimiter", ",");
curveIndex = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_index.csv'), ...
    "TextType", "string", "Delimiter", ",");
curveQuality = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_quality.csv'), ...
    "TextType", "string", "Delimiter", ",");
curveSamples = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_samples.csv'), ...
    "TextType", "string", "Delimiter", ",");

%% Preflight gate checks (STOP on failure; write failure verdict)
try
    assert(isfolder(rfRunDir), 'STOP: RF3R run directory missing.');
    assert(strcmpi(strtrim(rf3rGate.RF3R_RUN_AUDIT_COMPLETE(1)), "YES"), 'STOP: RF3R audit not complete.');
    assert(strcmpi(strtrim(rf3rGate.RF3R_EXECUTION_SUCCESS(1)), "YES"), 'STOP: RF3R execution not successful.');
    assert(strcmpi(strtrim(rf4bGate.RF4B_VISUALIZATION_REPAIR_COMPLETE(1)), "YES"), 'STOP: RF4B not complete.');
    assert(strcmpi(strtrim(rf4bGate.RF4B_RERUN_COMPLETE(1)), "YES"), 'STOP: RF4B rerun not complete.');
    assert(strcmpi(strtrim(rf4bGate.RF3R_RUN_USED(1)), "YES"), 'STOP: RF4B did not use RF3R.');
    assert(strcmpi(strtrim(rf4bGate.DEFAULT_REPLAY_SET_ENFORCED(1)), "YES"), 'STOP: RF4B default replay not enforced.');
    assert(strcmpi(strtrim(rf4bGate.FLAGGED_TRACES_EXCLUDED(1)), "YES"), 'STOP: RF4B flagged exclusion not confirmed.');
    assert(strcmpi(strtrim(rf4bGate.FIGURES_READABLE(1)), "YES"), 'STOP: RF4B figures not marked readable.');
    assert(strcmpi(strtrim(rf4bGate.VISUAL_OBJECT_MATCHES_POST_FIELD_OFF_RELAXATION(1)), "YES"), ...
        'STOP: RF4B visual object mismatch.');
    assert(strcmpi(strtrim(creation.READY_FOR_COLLAPSE_REPLAY(1)), "NO"), 'STOP: Collapse replay must remain NO.');
    assert(strcmpi(strtrim(creation.READY_FOR_CROSS_MODULE_ANALYSIS(1)), "NO"), 'STOP: Cross-module must remain NO.');
catch ME
    fail = table("NO","NO","NO","NO","NO","YES",string(ME.message), ...
        'VariableNames', {'RF5A_RERUN_COMPLETE','RF3R_RUN_USED','RF4B_RERUN_GATE_PASSED', ...
        'DEFAULT_REPLAY_SET_ENFORCED','FLAGGED_TRACES_EXCLUDED','QUALITY_FLAGGED_TRACES_IN_ANALYSIS', ...
        'failure_reason'});
    writetable(fail, failurePath);
    rethrow(ME);
end

%% Default replay manifest (strict: YES replay AND quality_flag NO)
validMask = strcmpi(strtrim(manifest.trace_valid_for_relaxation), "YES");
validManifestAll = manifest(validMask, :);
nAll = height(validManifestAll);
exclRows = table('Size', [0 4], 'VariableTypes', {'string','string','string','string'}, ...
    'VariableNames', {'run_id','trace_id','exclusion_reason','detail'});

includeMask = false(nAll, 1);
for k = 1:nAll
    tid = string(validManifestAll.trace_id(k));
    ix = find(strcmp(string(curveIndex.trace_id), tid), 1);
    qx = find(strcmp(string(curveQuality.trace_id), tid), 1);
    if isempty(ix) || isempty(qx)
        exclRows = [exclRows; table(string(run_id), tid, "MISSING_INDEX_OR_QUALITY", "", ...
            'VariableNames', exclRows.Properties.VariableNames)]; %#ok<AGROW>
        continue;
    end
    vr = strtrim(string(curveIndex.valid_for_default_replay(ix)));
    qf = strtrim(string(curveQuality.quality_flag(qx)));
    if strcmpi(vr, "NO")
        exclRows = [exclRows; table(string(run_id), tid, "NOT_VALID_FOR_DEFAULT_REPLAY", vr, ...
            'VariableNames', exclRows.Properties.VariableNames)]; %#ok<AGROW>
        continue;
    end
    if strcmpi(qf, "YES")
        exclRows = [exclRows; table(string(run_id), tid, "QUALITY_FLAGGED", string(curveQuality.quality_flag_reason(qx)), ...
            'VariableNames', exclRows.Properties.VariableNames)]; %#ok<AGROW>
        continue;
    end
    includeMask(k) = true;
end

validManifest = validManifestAll(includeMask, :);
if isempty(validManifest)
    fail = table("NO","YES","YES","YES","YES","NO","EMPTY_DEFAULT_REPLAY_SET", ...
        'VariableNames', {'RF5A_RERUN_COMPLETE','RF3R_RUN_USED','RF4B_RERUN_GATE_PASSED', ...
        'DEFAULT_REPLAY_SET_ENFORCED','FLAGGED_TRACES_EXCLUDED','QUALITY_FLAGGED_TRACES_IN_ANALYSIS', ...
        'failure_reason'});
    writetable(fail, failurePath);
    error('STOP: default replay set empty after filtering.');
end

temps = local_toDouble(validManifest.temperature);
[temps, ord] = sort(temps, 'ascend');
validManifest = validManifest(ord, :);
traceIds = string(validManifest.trace_id);
nTrace = numel(traceIds);
if nTrace < 2
    fail = table("NO","YES","YES","YES","YES","NO","INSUFFICIENT_DEFAULT_REPLAY_TRACES", ...
        'VariableNames', {'RF5A_RERUN_COMPLETE','RF3R_RUN_USED','RF4B_RERUN_GATE_PASSED', ...
        'DEFAULT_REPLAY_SET_ENFORCED','FLAGGED_TRACES_EXCLUDED','QUALITY_FLAGGED_TRACES_IN_ANALYSIS', ...
        'failure_reason'});
    writetable(fail, failurePath);
    error('STOP: fewer than two default-replay traces; cannot run RF5A spread diagnostics.');
end

% Hard leak check: no quality-flagged trace in analysis set
for k = 1:nTrace
    qx = find(strcmp(string(curveQuality.trace_id), traceIds(k)), 1);
    if strcmpi(strtrim(string(curveQuality.quality_flag(qx))), "YES")
        fail = table("NO","YES","YES","YES","YES","YES","QUALITY_FLAGGED_TRACE_IN_ANALYSIS", ...
            'VariableNames', {'RF5A_RERUN_COMPLETE','RF3R_RUN_USED','RF4B_RERUN_GATE_PASSED', ...
            'DEFAULT_REPLAY_SET_ENFORCED','FLAGGED_TRACES_EXCLUDED','QUALITY_FLAGGED_TRACES_IN_ANALYSIS', ...
            'failure_reason'});
        writetable(fail, failurePath);
        error('STOP: quality-flagged trace entered default RF5A analysis: %s', traceIds(k));
    end
end

curveSamples.time_s = local_toDouble(curveSamples.time_since_field_off);
curveSamples.delta_m_num = local_toDouble(curveSamples.delta_m);

% Common deterministic diagnostic grid (positive post-field-off times only)
tMinEach = nan(nTrace,1);
tMaxEach = nan(nTrace,1);
for i = 1:nTrace
    s = curveSamples(strcmp(string(curveSamples.trace_id), traceIds(i)), :);
    t = s.time_s;
    t = t(isfinite(t) & t > 0);
    tMinEach(i) = min(t);
    tMaxEach(i) = max(t);
end
tMinCommon = max(tMinEach);  % intersection start
tMaxCommon = min(tMaxEach);  % intersection end
if ~isfinite(tMinCommon) || ~isfinite(tMaxCommon) || tMinCommon <= 0 || tMaxCommon <= tMinCommon
    error('Invalid common time interval for RF5A.');
end

nGrid = 320;
tGridLinear = linspace(tMinCommon, tMaxCommon, nGrid);
tGridLog = logspace(log10(tMinCommon), log10(tMaxCommon), nGrid);

Xlin = nan(nTrace, nGrid);
Xlog = nan(nTrace, nGrid);
for i = 1:nTrace
    s = curveSamples(strcmp(string(curveSamples.trace_id), traceIds(i)), :);
    t = s.time_s;
    x = s.delta_m_num;
    m = isfinite(t) & isfinite(x) & t > 0;
    [tUniq, ia] = unique(t(m), 'stable');
    xUniq = x(m); xUniq = xUniq(ia);
    Xlin(i,:) = interp1(tUniq, xUniq, tGridLinear, 'linear', 'extrap');
    Xlog(i,:) = interp1(tUniq, xUniq, tGridLog, 'linear', 'extrap');
end

%% Amplitude-only choices
choiceList = ["peak_to_peak","l2_norm","mad_scale","abs_endpoint_diff","projection_onto_corrected_mean_curve"];
nChoice = numel(choiceList);

spread_before = local_pairwise_spread(Xlin);
resChoice = struct([]);

for c = 1:nChoice
    method = choiceList(c);
    A = local_compute_amplitude(Xlin, method);
    A(abs(A) < 1e-15) = 1e-15;

    Xn = Xlin ./ A;
    F = mean(Xn, 1, 'omitnan');
    Xhat = A * F;
    R = Xlin - Xhat;

    err_rank1 = norm(R, 'fro') / norm(Xlin, 'fro');
    ss_res = sum(R(:).^2, 'omitnan');
    ss_tot = sum(Xlin(:).^2, 'omitnan');
    var_expl = 1 - ss_res / max(ss_tot, eps);
    spread_after = local_pairwise_spread(Xn);
    spread_reduction = spread_before - spread_after;
    temp_resid = sqrt(mean(R.^2, 2, 'omitnan'));

    [~, S, ~] = svd(Xlin, 'econ');
    svals = diag(S);
    rank1_opt = 1 - (svals(1)^2 / sum(svals.^2));

    resChoice(c).method = method;
    resChoice(c).A = A;
    resChoice(c).F = F;
    resChoice(c).Xn = Xn;
    resChoice(c).Xhat = Xhat;
    resChoice(c).R = R;
    resChoice(c).err_rank1 = err_rank1;
    resChoice(c).var_expl = var_expl;
    resChoice(c).spread_before = spread_before;
    resChoice(c).spread_after = spread_after;
    resChoice(c).spread_reduction = spread_reduction;
    resChoice(c).temp_resid = temp_resid;
    resChoice(c).rank1_opt_err = rank1_opt;
end

% Pick best by min constrained error
errs = arrayfun(@(z) z.err_rank1, resChoice);
[~, bestIdx] = min(errs);
best = resChoice(bestIdx);

%% Residual shape diagnostics (best)
Rbest = best.R;
nCol = size(Rbest,2);
i1 = 1:floor(nCol/3);
i2 = floor(nCol/3)+1:floor(2*nCol/3);
i3 = floor(2*nCol/3)+1:nCol;
resEarly = sqrt(mean(Rbest(:,i1).^2, 2, 'omitnan'));
resMid = sqrt(mean(Rbest(:,i2).^2, 2, 'omitnan'));
resLate = sqrt(mean(Rbest(:,i3).^2, 2, 'omitnan'));
[~, worstOrd] = sort(best.temp_resid, 'descend');
worstTemps = temps(worstOrd(1:min(5,nTrace)));
[~, Sres, ~] = svd(Rbest, 'econ');
sRes = diag(Sres);
resRankFrac = sRes.^2 / sum(sRes.^2);

%% Negative controls on best amplitude method
nCtrl = 200;
real_improvement = best.spread_reduction;
ctrl_label_shuffle = nan(nCtrl,1);
ctrl_trace_perm = nan(nCtrl,1);
ctrl_rand_amp = nan(nCtrl,1);
ctrl_smooth_amp = nan(nCtrl,1);
ctrl_syn_baseline = nan(nCtrl,1);

A_best = best.A;
F_best = best.F;
resStd = std(Rbest(:), 'omitnan');

for k = 1:nCtrl
    p = randperm(nTrace);

    % 1) temperature-label shuffle (shuffle amplitudes across temperatures)
    A_shuf = A_best(p);
    Xn_shuf = Xlin ./ A_shuf;
    ctrl_label_shuffle(k) = spread_before - local_pairwise_spread(Xn_shuf);

    % 2) trace-order permutation control (permute trace assignment before amplitude apply)
    X_perm = Xlin(p,:);
    Xn_perm = X_perm ./ A_best;
    ctrl_trace_perm(k) = spread_before - local_pairwise_spread(Xn_perm);

    % 3) random amplitude surrogate
    Ar = exp(mean(log(abs(A_best))) + std(log(abs(A_best))) * randn(nTrace,1));
    Xn_rand = Xlin ./ Ar;
    ctrl_rand_amp(k) = spread_before - local_pairwise_spread(Xn_rand);

    % 4) smooth amplitude surrogate (2nd-order polynomial of A(T))
    pp = polyfit(temps, A_best, 2);
    As = polyval(pp, temps);
    As(abs(As) < 1e-15) = 1e-15;
    Xn_smooth = Xlin ./ As;
    ctrl_smooth_amp(k) = spread_before - local_pairwise_spread(Xn_smooth);

    % 5) mean-curve + amplitude synthetic baseline
    Xsyn = A_best * F_best + resStd * randn(size(Xlin));
    A_syn = local_compute_amplitude(Xsyn, best.method);
    A_syn(abs(A_syn) < 1e-15) = 1e-15;
    Xn_syn = Xsyn ./ A_syn;
    ctrl_syn_baseline(k) = local_pairwise_spread(Xsyn) - local_pairwise_spread(Xn_syn);
end

ctrl_all = [ctrl_label_shuffle; ctrl_trace_perm; ctrl_rand_amp; ctrl_smooth_amp; ctrl_syn_baseline];
ctrl95 = quantile(ctrl_all, 0.95);
exceeds_controls = real_improvement > ctrl95;

%% Tables
% 1) amplitude factorization metrics
metricsRows = table();
for c = 1:nChoice
    z = resChoice(c);
    row = table(string(run_id), z.method, z.err_rank1, z.rank1_opt_err, z.var_expl, ...
        z.spread_before, z.spread_after, z.spread_reduction, ...
        mean(z.temp_resid,'omitnan'), max(z.temp_resid,[],'omitnan'), ...
        'VariableNames', {'run_id','amplitude_method','constrained_rank1_error', ...
        'diagnostic_svd_rank1_error','variance_explained','pairwise_spread_before', ...
        'pairwise_spread_after','pairwise_spread_reduction','mean_temp_residual_rms','max_temp_residual_rms'});
    metricsRows = [metricsRows; row]; %#ok<AGROW>
end
writetable(metricsRows, fullfile(outTablesDir, 'relaxation_RF5A_amplitude_factorization_metrics_RF3R.csv'));

veCol = zeros(nChoice, 1);
srCol = zeros(nChoice, 1);
for cc = 1:nChoice
    veCol(cc) = resChoice(cc).var_expl;
    srCol(cc) = resChoice(cc).spread_reduction;
end
% 2) amplitude choice comparison
choiceCmp = table(string(choiceList(:)), errs(:), veCol, srCol, ...
    repmat(string(choiceList(bestIdx)), nChoice, 1), ...
    'VariableNames', {'amplitude_method','constrained_rank1_error','variance_explained', ...
    'spread_reduction','best_method'});
writetable(choiceCmp, fullfile(outTablesDir, 'relaxation_RF5A_amplitude_choice_comparison_RF3R.csv'));

% 3) residual shape metrics
shapeTbl = table(temps, best.temp_resid, resEarly, resMid, resLate, ...
    'VariableNames', {'temperature','residual_rms_total','residual_rms_early','residual_rms_mid','residual_rms_late'});
writetable(shapeTbl, fullfile(outTablesDir, 'relaxation_RF5A_shape_residual_metrics_RF3R.csv'));

% 4) negative controls
ctrlTbl = table( ...
    [repmat("temperature_label_shuffle", nCtrl,1); repmat("trace_order_permutation", nCtrl,1); ...
     repmat("random_amplitude_surrogate", nCtrl,1); repmat("smooth_amplitude_surrogate", nCtrl,1); ...
     repmat("mean_curve_plus_amplitude_synthetic", nCtrl,1)], ...
    [ctrl_label_shuffle; ctrl_trace_perm; ctrl_rand_amp; ctrl_smooth_amp; ctrl_syn_baseline], ...
    'VariableNames', {'control_type','spread_reduction'});
writetable(ctrlTbl, fullfile(outTablesDir, 'relaxation_RF5A_negative_control_results_RF3R.csv'));

% 5) temperature residuals
tempResTbl = table(repmat(string(run_id), nTrace,1), traceIds, temps, best.A, best.temp_resid, ...
    'VariableNames', {'run_id','trace_id','temperature','amplitude_best_method','residual_rms'});
writetable(tempResTbl, fullfile(outTablesDir, 'relaxation_RF5A_temperature_residuals_RF3R.csv'));

writetable(exclRows, fullfile(outTablesDir, 'relaxation_RF5A_exclusion_log_RF3R.csv'));

%% Figures + inventory
inv = table('Size',[0 7], 'VariableTypes', repmat("string",1,7), ...
    'VariableNames', {'figure_id','title','png_path','fig_path','source_data','canonical_or_diagnostic','notes'});
cmap = parula(nTrace);

% Figure 1: corrected curves
base_name = 'rf5a_corrected_post_field_off_curves';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.4]);
hold on;
for i = 1:nTrace
    semilogx(tGridLinear, Xlin(i,:), '-', 'LineWidth', 2.0, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s)');
ylabel('Delta M (emu)');
title('Corrected post-field-off canonical curves DeltaM(t;T)');
cb = colorbar; colormap(parula); cb.Label.String = 'Temperature (K)';
[png_p, fig_p] = local_save_pair(fig, base_name, figDir); close(fig);
inv = [inv; {base_name, "Corrected curves DeltaM(t;T)", string(png_p), string(fig_p), ...
    "RF3R curve_samples default replay", "CANONICAL", "RF3R default-replay post-field-off DeltaM"}];

% Figure 2: normalized overlays for each amplitude choice
base_name = 'rf5a_amplitude_normalized_overlays_by_choice';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.0]);
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');
for c = 1:nChoice
    nexttile;
    hold on;
    Xn = resChoice(c).Xn;
    for i = 1:nTrace
        semilogx(tGridLinear, Xn(i,:), '-', 'LineWidth', 1.8, 'Color', cmap(i,:));
    end
    xlabel('time\_since\_field\_off (s)');
    ylabel('Delta M / A(T)');
    title(sprintf('Amplitude normalization: %s', choiceList(c)));
    grid on;
end
nexttile;
text(0.05,0.65, sprintf('DIAGNOSTIC ONLY\nBest method: %s\nNo time-rescaling used', choiceList(bestIdx)), 'Units','normalized');
axis off;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir); close(fig);
inv = [inv; {base_name, "Amplitude-normalized overlays by choice", string(png_p), string(fig_p), ...
    "RF3R curve_samples default replay", "DIAGNOSTIC_ONLY", "Predefined amplitude definitions only"}];

% Figure 3: best method master curve overlay
base_name = 'rf5a_best_amplitude_master_curve_overlay';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.6]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
for i = 1:nTrace
    semilogx(tGridLinear, best.Xn(i,:), '-', 'LineWidth', 1.6, 'Color', cmap(i,:));
end
semilogx(tGridLinear, best.F, 'k-', 'LineWidth', 3.0);
xlabel('time\_since\_field\_off (s)');
ylabel('Delta M / A(T)');
title(sprintf('Best amplitude-only normalized overlays (%s)', best.method));
cb = colorbar; colormap(parula); cb.Label.String = 'Temperature (K)';
nexttile; hold on;
for i = 1:nTrace
    semilogx(tGridLinear, Xlin(i,:), '-', 'LineWidth', 1.2, 'Color', [0.7 0.7 0.7]);
    semilogx(tGridLinear, best.Xhat(i,:), '--', 'LineWidth', 1.8, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s)');
ylabel('Delta M (emu)');
title('Constrained reconstruction A(T)F(t) vs data');
[png_p, fig_p] = local_save_pair(fig, base_name, figDir); close(fig);
inv = [inv; {base_name, "Best amplitude-only master-curve overlay", string(png_p), string(fig_p), ...
    "RF3R curve_samples default replay", "DIAGNOSTIC_ONLY", "Constrained A(T)F(t) replay only"}];

% Figure 4: residual heatmap
base_name = 'rf5a_residual_heatmap_best_amplitude';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.6]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
imagesc(log10(tGridLinear), temps, Rbest); set(gca,'YDir','normal');
xlabel('log_{10}(time\_since\_field\_off / s)');
ylabel('Temperature (K)');
title('Residual heatmap: X - A(T)F(t) (best method)');
cb = colorbar; colormap(parula); cb.Label.String = 'Residual Delta M (emu)';
nexttile;
plot(temps, best.temp_resid, '-o', 'LineWidth', 2.2);
xlabel('Temperature (K)');
ylabel('Residual RMS (emu)');
title('Residual-by-temperature');
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir); close(fig);
inv = [inv; {base_name, "Residual heatmap and residual-by-temperature", string(png_p), string(fig_p), ...
    "RF3R curve_samples default replay", "DIAGNOSTIC_ONLY", "Residual shape after best amplitude factorization"}];

% Figure 5: negative-control summary
base_name = 'rf5a_negative_control_comparison_summary';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.6]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
cats = categorical(["Real","LabelShuffle","TracePerm","RandAmp","SmoothAmp","Synthetic"]);
vals = [real_improvement, mean(ctrl_label_shuffle), mean(ctrl_trace_perm), mean(ctrl_rand_amp), mean(ctrl_smooth_amp), mean(ctrl_syn_baseline)];
bar(cats, vals); ylabel('Spread reduction');
title('Amplitude-only spread reduction vs controls');
grid on;
nexttile;
boxchart(categorical(ctrlTbl.control_type), ctrlTbl.spread_reduction);
hold on;
yline(real_improvement, 'r-', 'LineWidth', 2.0);
ylabel('Spread reduction');
title('Negative-control distributions (red = real)');
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir); close(fig);
inv = [inv; {base_name, "Negative-control comparison", string(png_p), string(fig_p), ...
    "RF3R curve_samples + surrogate controls", "DIAGNOSTIC_ONLY", "Real vs conservative controls"}];

writetable(inv, fullfile(outTablesDir, 'relaxation_RF5A_figure_inventory_RF3R.csv'));

%% Verdict logic
amp_survives = "INCONCLUSIVE";
residual_changes = "INCONCLUSIVE";
exceeds_ctrl = "INCONCLUSIVE";

if best.spread_reduction > 0 && exceeds_controls && best.var_expl > 0.7
    amp_survives = "YES";
    exceeds_ctrl = "YES";
elseif best.spread_reduction > 0 && exceeds_controls
    amp_survives = "PARTIAL";
    exceeds_ctrl = "PARTIAL";
elseif best.spread_reduction > 0
    amp_survives = "PARTIAL";
    exceeds_ctrl = "NO";
else
    amp_survives = "NO";
    exceeds_ctrl = "NO";
end

lateDominant = mean(resLate,'omitnan') > 1.2 * mean(resMid,'omitnan');
if max(best.temp_resid) > 1.8 * median(best.temp_resid,'omitnan') || lateDominant
    residual_changes = "YES";
else
    residual_changes = "PARTIAL";
end

worstIdx = worstOrd(1);
worstT = temps(worstIdx);
near13 = abs(worstT - 13) < 0.25;
id13 = contains(lower(traceIds(worstIdx)), "13k") | contains(lower(string(validManifest.source_file(worstIdx))), "13k");
dom13K = "NO";
if (near13 || id13) && nTrace >= 2
    r1 = best.temp_resid(worstIdx);
    r2 = best.temp_resid(worstOrd(2));
    if r1 > 1.4 * max(r2, eps)
        dom13K = "YES";
    end
end

ready_vis = "YES";

verdict = table( ...
    "YES", ...
    "YES", ...
    "YES", ...
    "YES", ...
    "YES", ...
    "NO", ...
    nTrace, ...
    "YES", ...
    string(choiceList(bestIdx)), ...
    amp_survives, ...
    residual_changes, ...
    exceeds_ctrl, ...
    dom13K, ...
    "YES", ...
    ready_vis, ...
    "NO", ...
    "NO", ...
    "NO", ...
    'VariableNames', { ...
    'RF5A_RERUN_COMPLETE', ...
    'RF3R_RUN_USED', ...
    'RF4B_RERUN_GATE_PASSED', ...
    'DEFAULT_REPLAY_SET_ENFORCED', ...
    'FLAGGED_TRACES_EXCLUDED', ...
    'QUALITY_FLAGGED_TRACES_IN_ANALYSIS', ...
    'N_DEFAULT_REPLAY_TRACES', ...
    'AMPLITUDE_ONLY_FACTORIZATION_TESTED', ...
    'BEST_AMPLITUDE_CHOICE', ...
    'AMPLITUDE_ONLY_FACTORIZATION_SURVIVES', ...
    'RESIDUAL_SHAPE_CHANGES_PRESENT', ...
    'AMPLITUDE_ONLY_EXCEEDS_NEGATIVE_CONTROLS', ...
    'RESULT_DOMINATED_BY_13K_OUTLIER', ...
    'OUTPUTS_DIAGNOSTIC_ONLY', ...
    'READY_FOR_RF5A_VISUAL_REVIEW', ...
    'READY_FOR_RF5B_EFFECTIVE_RANK', ...
    'READY_FOR_COLLAPSE_REPLAY', ...
    'READY_FOR_CROSS_MODULE_ANALYSIS'});
writetable(verdict, fullfile(outTablesDir, 'relaxation_RF5A_verdict_status_RF3R.csv'));

%% Report
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_amplitude_only_factorization_RF3R.md');
lines = {
    '# Relaxation RF5A: Amplitude-Only Factorization (RF3R default replay)'
    ''
    'This RF5A rerun tests only `DeltaM(t;T) ~= A(T)F(t)` on the RF3R post-field-off robust-baseline object, default replay set only.'
    'Inputs are limited to the audited RF3R canonical run; old RF3 / full-trace / prior RF5A CSV outputs are not used as inputs.'
    ''
    sprintf('- RF3R run: `%s`', rfRunDir)
    sprintf('- Best amplitude definition: `%s`', best.method)
    sprintf('- Constrained amplitude-only rank-1 error: %.6f', best.err_rank1)
    sprintf('- Diagnostic unconstrained SVD rank-1 error: %.6f', best.rank1_opt_err)
    sprintf('- Spread reduction (real): %.6f', real_improvement)
    sprintf('- Control 95th percentile spread reduction: %.6f', ctrl95)
    sprintf('- Amplitude-only survives: `%s`', amp_survives)
    sprintf('- Residual shape changes present: `%s`', residual_changes)
    sprintf('- Exceeds negative controls: `%s`', exceeds_ctrl)
    sprintf('- Default replay traces in RF5A: %d', nTrace)
    sprintf('- Result dominated by 13K outlier (worst-residual dominance test): `%s`', dom13K)
    ''
    '## Time grid definition'
    sprintf('- Common positive-time interval: [%.6g, %.6g] s', tMinCommon, tMaxCommon)
    sprintf('- Linear grid points: %d', nGrid)
    sprintf('- Log-time grid points: %d', nGrid)
    '- Zero point handling: `t=0` excluded from log grid by construction using positive-time intersection.'
    ''
    '## Interpretation'
    '- This replay tests only `DeltaM(t;T) ~= A(T)F(t)` with predefined amplitude rules.'
    '- Any apparent master-curve behavior is diagnostic amplitude-only evidence, not collapse confirmation.'
    '- Residual diagnostics indicate how much structured shape variation remains after amplitude-only normalization.'
    ''
    '## Figure paths'
    };
for i = 1:height(inv)
    lines{end+1,1} = sprintf('- `%s`', inv.png_path(i)); %#ok<AGROW>
    lines{end+1,1} = sprintf('- `%s`', inv.fig_path(i)); %#ok<AGROW>
end
lines = [lines; {
    ''
    '## Explicit non-actions'
    '- No time-rescaling collapse was performed.'
    '- No general collapse optimization was performed.'
    '- No time-mode analysis was performed.'
    '- No full collapse replay was performed.'
    '- No cross-module analysis was performed.'
    }];
fid = fopen(reportPath, 'w');
if fid < 0, error('Cannot write report.'); end
for i = 1:numel(lines), fprintf(fid, '%s\n', lines{i}); end
fclose(fid);

disp('RF5A amplitude-only factorization complete.');
disp(figDir);

%% ---------------- Local functions ----------------
function A = local_compute_amplitude(X, method)
method = string(method);
n = size(X,1);
A = nan(n,1);
switch method
    case "peak_to_peak"
        for i = 1:n
            xi = X(i,:); xi = xi(isfinite(xi));
            A(i) = max(xi) - min(xi);
        end
    case "l2_norm"
        A = sqrt(mean(X.^2, 2, 'omitnan'));
    case "mad_scale"
        for i = 1:n
            xi = X(i,:); xi = xi(isfinite(xi));
            A(i) = median(abs(xi - median(xi, 'omitnan')), 'omitnan');
        end
    case "abs_endpoint_diff"
        A = abs(X(:,end) - X(:,1));
    case "projection_onto_corrected_mean_curve"
        f0 = mean(X, 1, 'omitnan');
        den = sum(f0.^2, 'omitnan');
        if den <= eps, den = eps; end
        for i = 1:n
            A(i) = sum(X(i,:) .* f0, 2, 'omitnan') / den;
        end
    otherwise
        error('Unknown amplitude method.');
end
A(~isfinite(A)) = 1;
end

function s = local_pairwise_spread(X)
n = size(X,1);
acc = 0;
cnt = 0;
for i = 1:n
    for j = i+1:n
        d = X(i,:) - X(j,:);
        acc = acc + sqrt(mean(d.^2, 'omitnan'));
        cnt = cnt + 1;
    end
end
s = acc / max(cnt,1);
end

function [png_path, fig_path] = local_save_pair(fig, base_name, outDir)
if ~strcmp(char(string(get(fig,'Name'))), base_name)
    error('Figure Name must match base_name.');
end
apply_publication_style(fig);
png_path = fullfile(outDir, [base_name '.png']);
fig_path = fullfile(outDir, [base_name '.fig']);
exportgraphics(fig, png_path, 'Resolution', 600);
savefig(fig, fig_path);
end

function x = local_toDouble(v)
if isnumeric(v)
    x = double(v);
else
    x = str2double(string(v));
end
end
