function out = switching_composite_observable_scan(cfg)
% switching_composite_observable_scan
% Scan low-order composites of full-scaling switching observables against
% relaxation observables using saved run outputs only.

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
runCfg.dataset = sprintf('switch:%s | relax:%s | motion:%s', ...
    char(source.switchRunName), char(source.relaxRunName), char(source.motionRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching composite observable scan run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Ridge-motion source run: %s\n', source.motionRunName);

appendText(run.log_path, sprintf('[%s] switching composite observable scan started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Motion source: %s\n', char(source.motionRunName)));

switching = loadSwitchingData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);
motion = loadMotionData(source.motionRunDir, cfg);
aligned = buildAlignedData(switching, relax, motion, cfg);

candidateDefs = buildCandidateDefinitions(aligned, cfg);
aligned = attachCandidateSeries(aligned, candidateDefs);
compositeTbl = buildCompositeObservableTable(aligned, candidateDefs);
summaryTbl = buildCorrelationSummary(candidateDefs, aligned, cfg);
summaryTbl = addRanks(summaryTbl);

aRows = summaryTbl(strcmp(summaryTbl.relaxation_key, "A_T"), :);
topCandidates = selectTopCandidates(aRows, cfg);
fitTbl = buildTopCandidateFitSummary(topCandidates, aligned, cfg);
manifestTbl = buildManifestTable(source, cfg);

compositePath = save_run_table(compositeTbl, 'composite_observables_table.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'correlation_summary.csv', runDir);
fitPath = save_run_table(fitTbl, 'top_candidate_fit_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figHeatmap = saveCompositeCorrelationHeatmap(summaryTbl, runDir, 'composite_correlation_heatmap');
figOverlay = saveTopCandidatesVsAOverlay(topCandidates, aligned, runDir, 'top_candidates_vs_A_overlay');
figScatter = saveTopCandidatesScatter(topCandidates, aligned, runDir, 'top_candidates_scatter');
figNorm = saveNormalizedTopCandidatesOverlay(topCandidates, aligned, runDir, 'normalized_top_candidates_overlay');
figFit = saveTopCandidateFitPanels(topCandidates, fitTbl, aligned, runDir, 'top_candidate_fit_panels');
figMotion = saveTopCandidatesVsRidgeMotion(topCandidates, aligned, runDir, 'top_candidates_vs_ridge_motion');

reportText = buildReportText(source, aligned, summaryTbl, fitTbl, topCandidates, cfg);
reportPath = save_run_report(reportText, 'switching_composite_observable_scan.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_composite_observable_scan_bundle.zip');

bestA = aRows(1, :);
widthRow = aRows(strcmp(aRows.observable_key, "w"), :);
bestComposite = aRows(~strcmp(aRows.observable_key, "w"), :);
if ~isempty(bestComposite)
    bestComposite = bestComposite(1, :);
end

appendText(run.notes_path, sprintf('Temperature window = %.1f-%.1f K\n', min(aligned.T_K), max(aligned.T_K)));
appendText(run.notes_path, sprintf('Interpolation method = %s\n', cfg.interpMethod));
appendText(run.notes_path, sprintf('Best A(T) bridge = %s (Pearson %.6g, Spearman %.6g)\n', ...
    char(bestA.observable_key(1)), bestA.pearson_r(1), bestA.spearman_r(1)));
if ~isempty(widthRow)
    appendText(run.notes_path, sprintf('Width baseline vs A(T) = %.6g / %.6g\n', ...
        widthRow.pearson_r(1), widthRow.spearman_r(1)));
end
if ~isempty(bestComposite)
    appendText(run.notes_path, sprintf('Best composite vs A(T) = %s (Pearson %.6g, Spearman %.6g)\n', ...
        char(bestComposite.observable_key(1)), bestComposite.pearson_r(1), bestComposite.spearman_r(1)));
end

appendText(run.log_path, sprintf('[%s] switching composite observable scan complete\n', stampNow()));
appendText(run.log_path, sprintf('Composite table: %s\n', compositePath));
appendText(run.log_path, sprintf('Correlation summary: %s\n', summaryPath));
appendText(run.log_path, sprintf('Fit summary: %s\n', fitPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.candidates = candidateDefs;
out.topCandidates = topCandidates;
out.tables = struct('composite', string(compositePath), 'summary', string(summaryPath), ...
    'fit', string(fitPath), 'manifest', string(manifestPath));
out.figures = struct('heatmap', string(figHeatmap.png), 'overlay', string(figOverlay.png), ...
    'scatter', string(figScatter.png), 'normalized_overlay', string(figNorm.png), ...
    'fit_panels', string(figFit.png), 'ridge_motion', string(figMotion.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching composite observable scan complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best A(T) bridge: %s (Pearson %.4f, Spearman %.4f)\n', ...
    char(bestA.observable_key(1)), bestA.pearson_r(1), bestA.spearman_r(1));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'motionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'topCandidateCount', 4);
cfg = setDefaultField(cfg, 'fitCandidateCount', 3);
cfg = setDefaultField(cfg, 'denominatorGuardFraction', 1e-6);
cfg = setDefaultField(cfg, 'nearZeroFloor', 1e-12);
cfg = setDefaultField(cfg, 'classificationMargin', 0.03);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.motionRunName = string(cfg.motionRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.motionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.motionRunName));

requiredPaths = {
    source.switchRunDir, fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv');
    source.motionRunDir, fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')
    };

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
tbl = sortrows(tbl(mask, :), 'T_K');

switching = struct();
switching.T = tbl.T_K(:);
switching.width = tbl.width_chosen_mA(:);
switching.widthFwhm = tbl.width_fwhm_mA(:);
switching.widthSigma = tbl.width_sigma_mA(:);
switching.Speak = tbl.S_peak(:);
switching.Ipeak = tbl.Ipeak_mA(:);
switching.leftHalf = tbl.left_half_current_mA(:);
switching.rightHalf = tbl.right_half_current_mA(:);
switching.widthMethod = string(tbl.width_method(:));
switching.nValid = tbl.n_valid_points(:);
switching.peakIndex = tbl.peak_index(:);
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
relax.sourcePeakWidth = obsTbl.Relax_peak_width(1);
end

function motion = loadMotionData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'relaxation_switching_motion_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');

motion = struct();
motion.T = tbl.T_K(:);
motion.motion = tbl.motion_abs_dI_peak_dT(:);
motion.motionNorm = tbl.motion_norm(:);
motion.IpeakSmooth = tbl.I_peak_smooth_mA(:);
motion.validMask = logical(tbl.comparison_mask(:));
end

function aligned = buildAlignedData(switching, relax, motion, cfg)
T = switching.T(:);
aligned = struct();
aligned.T_K = T;
aligned.w = switching.width(:);
aligned.S = switching.Speak(:);
aligned.I = switching.Ipeak(:);
aligned.width_fwhm_mA = switching.widthFwhm(:);
aligned.width_sigma_mA = switching.widthSigma(:);
aligned.left_half_current_mA = switching.leftHalf(:);
aligned.right_half_current_mA = switching.rightHalf(:);
aligned.width_method = switching.widthMethod(:);
aligned.n_valid_points = switching.nValid(:);
aligned.peak_index = switching.peakIndex(:);

aligned.A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
aligned.R = interp1(relax.T, relax.R, T, cfg.interpMethod, NaN);
aligned.beta = interp1(relax.T, relax.beta, T, cfg.interpMethod, NaN);
aligned.tau = interp1(relax.T, relax.tau, T, cfg.interpMethod, NaN);

aligned.motion_abs = NaN(size(T));
aligned.motion_norm_saved = NaN(size(T));
aligned.I_peak_smooth_mA = NaN(size(T));
aligned.motion_valid_mask = false(size(T));
[lia, loc] = ismember(T, motion.T);
aligned.motion_abs(lia) = motion.motion(loc(lia));
aligned.motion_norm_saved(lia) = motion.motionNorm(loc(lia));
aligned.I_peak_smooth_mA(lia) = motion.IpeakSmooth(loc(lia));
aligned.motion_valid_mask(lia) = motion.validMask(loc(lia));

aligned.relaxation_peak_T_K = relax.sourcePeakT;
aligned.relaxation_peak_width_K = relax.sourcePeakWidth;
end

function candidateDefs = buildCandidateDefinitions(aligned, cfg)
w = aligned.w(:);
S = aligned.S(:);
I = aligned.I(:);

candidateDefs = repmat(struct('key', "", 'display_name', "", 'family', "", 'formula', "", ...
    'values', [], 'denominator_key', "", 'stability_floor', NaN, 'is_kept', false, 'drop_reason', ""), 0, 1);

candidateDefs(end+1) = makeCandidate("w", "width", "single", "w", w); %#ok<AGROW>
candidateDefs(end+1) = makeCandidate("S", "S_{peak}", "single", "S", S); %#ok<AGROW>
candidateDefs(end+1) = makeCandidate("I", "I_{peak}", "single", "I", I); %#ok<AGROW>

candidateDefs(end+1) = makeCandidate("w_times_S", "w S_{peak}", "product", "w*S", w .* S); %#ok<AGROW>
candidateDefs(end+1) = makeCandidate("w_times_I", "w I_{peak}", "product", "w*I", w .* I); %#ok<AGROW>
candidateDefs(end+1) = makeCandidate("S_times_I", "S_{peak} I_{peak}", "product", "S*I", S .* I); %#ok<AGROW>

candidateDefs(end+1) = makeRatioCandidate("w_over_S", "w / S_{peak}", "ratio", "w/S", w, S, "S", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("S_over_w", "S_{peak} / w", "ratio", "S/w", S, w, "w", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("w_over_I", "w / I_{peak}", "ratio", "w/I", w, I, "I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("I_over_w", "I_{peak} / w", "ratio", "I/w", I, w, "w", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("S_over_I", "S_{peak} / I_{peak}", "ratio", "S/I", S, I, "I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("I_over_S", "I_{peak} / S_{peak}", "ratio", "I/S", I, S, "S", cfg); %#ok<AGROW>

candidateDefs(end+1) = makeRatioCandidate("w2_over_S", "w^2 / S_{peak}", "variant", "w^2/S", w .^ 2, S, "S", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("S2_over_w", "S_{peak}^2 / w", "variant", "S^2/w", S .^ 2, w, "w", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("w2_over_I", "w^2 / I_{peak}", "variant", "w^2/I", w .^ 2, I, "I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("I2_over_w", "I_{peak}^2 / w", "variant", "I^2/w", I .^ 2, w, "w", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("S2_over_I", "S_{peak}^2 / I_{peak}", "variant", "S^2/I", S .^ 2, I, "I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("I2_over_S", "I_{peak}^2 / S_{peak}", "variant", "I^2/S", I .^ 2, S, "S", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("w_over_SI", "w / (S_{peak} I_{peak})", "variant", "w/(S*I)", w, S .* I, "S*I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("S_over_wI", "S_{peak} / (w I_{peak})", "variant", "S/(w*I)", S, w .* I, "w*I", cfg); %#ok<AGROW>
candidateDefs(end+1) = makeRatioCandidate("I_over_wS", "I_{peak} / (w S_{peak})", "variant", "I/(w*S)", I, w .* S, "w*S", cfg); %#ok<AGROW>

candidateDefs = candidateDefs([candidateDefs.is_kept]);
end

function aligned = attachCandidateSeries(aligned, candidateDefs)
for i = 1:numel(candidateDefs)
    aligned.(char(candidateDefs(i).key)) = candidateDefs(i).values(:);
end
end

function candidate = makeCandidate(key, displayName, family, formula, values)
candidate = struct();
candidate.key = string(key);
candidate.display_name = string(displayName);
candidate.family = string(family);
candidate.formula = string(formula);
candidate.values = values(:);
candidate.denominator_key = "";
candidate.stability_floor = NaN;
candidate.is_kept = all(isfinite(values(:)));
if candidate.is_kept
    candidate.drop_reason = "";
else
    candidate.drop_reason = "nonfinite_values";
end
end

function candidate = makeRatioCandidate(key, displayName, family, formula, numerator, denominator, denominatorKey, cfg)
[values, ok, floorValue] = guardedDivide(numerator, denominator, cfg);
candidate = makeCandidate(key, displayName, family, formula, values);
candidate.denominator_key = string(denominatorKey);
candidate.stability_floor = floorValue;
candidate.is_kept = ok && all(isfinite(values(:)));
if candidate.is_kept
    candidate.drop_reason = "";
elseif ~ok
    candidate.drop_reason = "denominator_guard_triggered";
else
    candidate.drop_reason = "nonfinite_values";
end
end

function [values, ok, floorValue] = guardedDivide(numerator, denominator, cfg)
denAbs = abs(denominator(:));
finiteMask = isfinite(denAbs);
if ~any(finiteMask)
    values = NaN(size(numerator));
    ok = false;
    floorValue = NaN;
    return;
end

scale = median(denAbs(finiteMask), 'omitnan');
if ~isfinite(scale) || scale <= 0
    scale = max(denAbs(finiteMask), [], 'omitnan');
end
floorValue = max(cfg.nearZeroFloor, cfg.denominatorGuardFraction * scale);
ok = all(finiteMask) && all(denAbs > floorValue);
values = numerator ./ denominator;
end

function compositeTbl = buildCompositeObservableTable(aligned, candidateDefs)
compositeTbl = table();
compositeTbl.T_K = aligned.T_K(:);
compositeTbl.width_mA = aligned.w(:);
compositeTbl.S_peak = aligned.S(:);
compositeTbl.I_peak_mA = aligned.I(:);
compositeTbl.A_interp = aligned.A(:);
compositeTbl.R_interp = aligned.R(:);
compositeTbl.beta_interp = aligned.beta(:);
compositeTbl.tau_interp = aligned.tau(:);
compositeTbl.motion_abs_dI_peak_dT = aligned.motion_abs(:);
compositeTbl.motion_valid_mask = aligned.motion_valid_mask(:);
for i = 1:numel(candidateDefs)
    compositeTbl.(char(candidateDefs(i).key)) = candidateDefs(i).values(:);
end
end

function summaryTbl = buildCorrelationSummary(candidateDefs, aligned, cfg)
relaxDefs = {
    'A_T', 'A(T)', aligned.A;
    'R_T', 'R(T)', aligned.R;
    'beta_T', 'beta(T)', aligned.beta;
    'tau_T', 'tau(T)', aligned.tau
    };

nRows = numel(candidateDefs) * size(relaxDefs, 1);
summaryTbl = table('Size', [nRows, 26], ...
    'VariableTypes', {'string','string','string','string','string','string','string', ...
    'double','double','double','double','double','double','double','double', ...
    'double','double','double','double','double','double','double','double', ...
    'string','string','logical'}, ...
    'VariableNames', {'observable_key','display_name','family','formula','relaxation_key','relaxation_display', ...
    'interp_method','n_points','pearson_r','spearman_r','shape_corr_norm','direct_shape_rmse', ...
    'inverse_shape_rmse','best_shape_rmse','shape_overlap_score','observable_peak_T_K','relax_peak_T_K', ...
    'peak_delta_K','observable_peak_value','relax_peak_value','stability_floor', ...
    'width_baseline_pearson_delta','width_baseline_spearman_delta','shape_mode','relation_to_A','peak_is_boundary'});
summaryTbl.interp_method(:) = string(cfg.interpMethod);

row = 0;
for i = 1:numel(candidateDefs)
    x = candidateDefs(i).values(:);
    xPeak = findPeakT(aligned.T_K, x);
    xPeakVal = interp1(aligned.T_K, x, xPeak, 'linear', NaN);
    for j = 1:size(relaxDefs, 1)
        row = row + 1;
        y = relaxDefs{j, 3};
        mask = isfinite(x) & isfinite(y(:));
        xUse = x(mask);
        yUse = y(mask);
        xNorm = normalize01(xUse);
        yNorm = normalize01(yUse);
        directRmse = computeRMSE(xNorm, yNorm);
        inverseRmse = computeRMSE(xNorm, 1 - yNorm);
        summaryTbl.observable_key(row) = candidateDefs(i).key;
        summaryTbl.display_name(row) = candidateDefs(i).display_name;
        summaryTbl.family(row) = candidateDefs(i).family;
        summaryTbl.formula(row) = candidateDefs(i).formula;
        summaryTbl.relaxation_key(row) = string(relaxDefs{j, 1});
        summaryTbl.relaxation_display(row) = string(relaxDefs{j, 2});
        summaryTbl.n_points(row) = nnz(mask);
        summaryTbl.pearson_r(row) = corrSafe(xUse, yUse);
        summaryTbl.spearman_r(row) = spearmanSafe(xUse, yUse);
        summaryTbl.shape_corr_norm(row) = corrSafe(xNorm, yNorm);
        summaryTbl.direct_shape_rmse(row) = directRmse;
        summaryTbl.inverse_shape_rmse(row) = inverseRmse;
        summaryTbl.best_shape_rmse(row) = min(directRmse, inverseRmse);
        summaryTbl.shape_overlap_score(row) = max(0, 1 - summaryTbl.best_shape_rmse(row));
        summaryTbl.observable_peak_T_K(row) = xPeak;
        summaryTbl.relax_peak_T_K(row) = findPeakT(aligned.T_K, y);
        summaryTbl.peak_delta_K(row) = xPeak - summaryTbl.relax_peak_T_K(row);
        summaryTbl.observable_peak_value(row) = xPeakVal;
        summaryTbl.relax_peak_value(row) = interp1(aligned.T_K, y, summaryTbl.relax_peak_T_K(row), 'linear', NaN);
        summaryTbl.stability_floor(row) = candidateDefs(i).stability_floor;
        summaryTbl.shape_mode(row) = chooseShapeMode(directRmse, inverseRmse);
        summaryTbl.peak_is_boundary(row) = isPeakBoundary(aligned.T_K, xPeak);
        if strcmp(relaxDefs{j, 1}, 'A_T')
            summaryTbl.relation_to_A(row) = classifyRelationToA(summaryTbl.pearson_r(row), directRmse, inverseRmse, cfg);
        else
            summaryTbl.relation_to_A(row) = "";
        end
    end
end

widthRows = summaryTbl(strcmp(summaryTbl.observable_key, "w"), :);
for j = 1:size(relaxDefs, 1)
    key = string(relaxDefs{j, 1});
    baseRow = widthRows(strcmp(widthRows.relaxation_key, key), :);
    mask = strcmp(summaryTbl.relaxation_key, key);
    if ~isempty(baseRow)
        summaryTbl.width_baseline_pearson_delta(mask) = summaryTbl.pearson_r(mask) - baseRow.pearson_r(1);
        summaryTbl.width_baseline_spearman_delta(mask) = summaryTbl.spearman_r(mask) - baseRow.spearman_r(1);
    end
end
end

function summaryTbl = addRanks(summaryTbl)
summaryTbl.abs_pearson_r = abs(summaryTbl.pearson_r);
summaryTbl.abs_spearman_r = abs(summaryTbl.spearman_r);
summaryTbl.abs_pearson_rank = NaN(height(summaryTbl), 1);
summaryTbl.abs_spearman_rank = NaN(height(summaryTbl), 1);

relaxKeys = unique(summaryTbl.relaxation_key, 'stable');
for i = 1:numel(relaxKeys)
    mask = strcmp(summaryTbl.relaxation_key, relaxKeys(i));
    sub = summaryTbl(mask, :);
    [~, orderS] = sortrows(table(-sub.abs_spearman_r, -sub.abs_pearson_r, sub.best_shape_rmse), [1 2 3]);
    [~, orderP] = sortrows(table(-sub.abs_pearson_r, -sub.abs_spearman_r, sub.best_shape_rmse), [1 2 3]);
    idx = find(mask);
    ranksS = NaN(numel(idx), 1);
    ranksP = NaN(numel(idx), 1);
    ranksS(orderS) = 1:numel(orderS);
    ranksP(orderP) = 1:numel(orderP);
    summaryTbl.abs_spearman_rank(mask) = ranksS;
    summaryTbl.abs_pearson_rank(mask) = ranksP;
end

summaryTbl = sortrows(summaryTbl, {'relaxation_key','abs_spearman_rank','abs_pearson_rank','best_shape_rmse'});
end

function topCandidates = selectTopCandidates(aRows, cfg)
aRows = sortrows(aRows, {'abs_spearman_rank','abs_pearson_rank','best_shape_rmse'});
allRows = aRows(1:min(cfg.topCandidateCount, height(aRows)), :);
fitRows = allRows(1:min(cfg.fitCandidateCount, height(allRows)), :);
topCandidates = struct('allRows', allRows, 'fitRows', fitRows, ...
    'keys', allRows.observable_key, 'fitKeys', fitRows.observable_key);
end

function fitTbl = buildTopCandidateFitSummary(topCandidates, aligned, cfg)
fitTbl = table();
for i = 1:height(topCandidates.fitRows)
    key = char(topCandidates.fitRows.observable_key(i));
    x = aligned.(key);
    mask = isfinite(x) & isfinite(aligned.A);
    A = aligned.A(mask);
    X = x(mask);

    direct = fitLinearDirect(A, X);
    inverse = fitInverseProportional(A, X);
    powerXA = fitPowerLaw(A, X, "X_from_A");
    powerAX = fitPowerLaw(X, A, "A_from_X");

    fitTbl = [fitTbl; packFitRow(key, topCandidates.fitRows.display_name(i), 'linear_X_from_A', direct, numel(X))]; %#ok<AGROW>
    fitTbl = [fitTbl; packFitRow(key, topCandidates.fitRows.display_name(i), 'inverse_X_from_A', inverse, numel(X))]; %#ok<AGROW>
    fitTbl = [fitTbl; packFitRow(key, topCandidates.fitRows.display_name(i), 'power_X_from_A', powerXA, numel(X))]; %#ok<AGROW>
    fitTbl = [fitTbl; packFitRow(key, topCandidates.fitRows.display_name(i), 'power_A_from_X', powerAX, numel(X))]; %#ok<AGROW>
end

fitTbl.interp_method = repmat(string(cfg.interpMethod), height(fitTbl), 1);
fitTbl = movevars(fitTbl, 'interp_method', 'After', 'model_key');
fitTbl = sortrows(fitTbl, {'observable_key','r2'}, {'ascend','descend'});
end

function row = packFitRow(observableKey, displayName, modelKey, fit, nPoints)
row = table();
row.observable_key = string(observableKey);
row.display_name = string(displayName);
row.model_key = string(modelKey);
row.n_points = nPoints;
row.param_a = fit.paramA;
row.param_b = fit.paramB;
row.alpha = fit.alpha;
row.r2 = fit.r2;
row.rmse = fit.rmse;
row.mae = fit.mae;
row.model_label = string(fit.modelLabel);
end

function fit = fitLinearDirect(A, X)
p = polyfit(A, X, 1);
yhat = polyval(p, A);
fit = struct('paramA', p(1), 'paramB', p(2), 'alpha', NaN, ...
    'r2', computeR2(X, yhat), 'rmse', computeRMSE(X, yhat), ...
    'mae', computeMAE(X, yhat), 'modelLabel', 'X = a A + b');
end

function fit = fitInverseProportional(A, X)
u = 1 ./ A;
k = (u' * X) / (u' * u);
yhat = k .* u;
fit = struct('paramA', k, 'paramB', 0, 'alpha', -1, ...
    'r2', computeR2(X, yhat), 'rmse', computeRMSE(X, yhat), ...
    'mae', computeMAE(X, yhat), 'modelLabel', 'X = k / A');
end

function fit = fitPowerLaw(independent, dependent, mode)
mask = isfinite(independent) & isfinite(dependent) & independent > 0 & dependent > 0;
if nnz(mask) < 3
    fit = struct('paramA', NaN, 'paramB', NaN, 'alpha', NaN, ...
        'r2', NaN, 'rmse', NaN, 'mae', NaN, 'modelLabel', sprintf('%s unavailable', char(mode)));
    return;
end

p = polyfit(log(independent(mask)), log(dependent(mask)), 1);
alpha = p(1);
c = exp(p(2));
yhat = c .* independent(mask) .^ alpha;
if strcmp(mode, "X_from_A")
    label = 'X = c A^\alpha';
else
    label = 'A = c X^\alpha';
end
fit = struct('paramA', c, 'paramB', NaN, 'alpha', alpha, ...
    'r2', computeR2(dependent(mask), yhat), 'rmse', computeRMSE(dependent(mask), yhat), ...
    'mae', computeMAE(dependent(mask), yhat), 'modelLabel', label);
end

function manifestTbl = buildManifestTable(source, cfg)
manifestTbl = table(string({'switching'; 'relaxation'; 'relaxation'; 'cross_experiment'}), ...
    [source.switchRunName; source.relaxRunName; source.relaxRunName; source.motionRunName], ...
    string({fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'); ...
    fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')}), ...
    string({'full-scaling switching parameters'; 'relaxation temperature observables'; ...
    'relaxation summary observables'; 'saved ridge-motion table'}), ...
    repmat(string(cfg.interpMethod), 4, 1), ...
    'VariableNames', {'experiment','source_run','source_file','role','interp_method'});
end
function figPaths = saveCompositeCorrelationHeatmap(summaryTbl, runDir, figureName)
relaxKeys = ["A_T","R_T","beta_T","tau_T"];
relaxLabels = {'A(T)','R(T)','beta(T)','tau(T)'};
obsRows = summaryTbl(strcmp(summaryTbl.relaxation_key, "A_T"), :);
obsKeys = obsRows.observable_key;
obsLabels = cellstr(obsRows.display_name);

pearsonMat = NaN(numel(obsKeys), numel(relaxKeys));
spearmanMat = NaN(numel(obsKeys), numel(relaxKeys));
for i = 1:numel(obsKeys)
    for j = 1:numel(relaxKeys)
        row = summaryTbl(strcmp(summaryTbl.observable_key, obsKeys(i)) & strcmp(summaryTbl.relaxation_key, relaxKeys(j)), :);
        pearsonMat(i, j) = row.pearson_r(1);
        spearmanMat(i, j) = row.spearman_r(1);
    end
end

fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 18 14]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
imagesc(ax1, pearsonMat);
title(ax1, 'Pearson r');
styleHeatmapAxes(ax1, obsLabels, relaxLabels);
applyHeatmapAnnotations(ax1, pearsonMat);
colorbar(ax1);
caxis(ax1, [-1 1]);

ax2 = nexttile(tl, 2);
imagesc(ax2, spearmanMat);
title(ax2, 'Spearman \rho');
styleHeatmapAxes(ax2, obsLabels, relaxLabels);
applyHeatmapAnnotations(ax2, spearmanMat);
colorbar(ax2);
caxis(ax2, [-1 1]);

colormap(fh, parula(256));
title(tl, 'Composite switching observable correlations vs relaxation observables');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function styleHeatmapAxes(ax, obsLabels, relaxLabels)
set(ax, 'YDir', 'normal', 'FontSize', 9, 'LineWidth', 1);
xticks(ax, 1:numel(relaxLabels));
xticklabels(ax, relaxLabels);
yticks(ax, 1:numel(obsLabels));
yticklabels(ax, obsLabels);
xlabel(ax, 'Relaxation observable');
ylabel(ax, 'Switching observable');
end

function applyHeatmapAnnotations(ax, data)
[nRows, nCols] = size(data);
for i = 1:nRows
    for j = 1:nCols
        text(ax, j, i, sprintf('%.2f', data(i, j)), 'HorizontalAlignment', 'center', ...
            'FontSize', 7, 'Color', annotationColor(data(i, j)));
    end
end
end

function color = annotationColor(value)
if abs(value) > 0.6
    color = [1 1 1];
else
    color = [0.1 0.1 0.1];
end
end

function figPaths = saveTopCandidatesVsAOverlay(topCandidates, aligned, runDir, figureName)
rows = topCandidates.allRows;
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17 10]);
ax = axes(fh);
hold(ax, 'on');

plot(ax, aligned.T_K, normalize01(aligned.A), '--', 'Color', [0 0 0], 'LineWidth', 2.6, 'DisplayName', 'A(T)');
colors = lines(height(rows));
for i = 1:height(rows)
    key = char(rows.observable_key(i));
    plot(ax, aligned.T_K, normalize01(aligned.(key)), '-', 'LineWidth', 1.9, 'Color', colors(i, :), ...
        'DisplayName', sprintf('%s [%s]', char(rows.observable_key(i)), char(rows.relation_to_A(i))));
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized amplitude');
title(ax, 'Top switching candidates overlaid with relaxation A(T)');
legend(ax, 'Location', 'eastoutside');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTopCandidatesScatter(topCandidates, aligned, runDir, figureName)
rows = topCandidates.allRows;
n = height(rows);
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 18 4 + 4.5 * n]);
tl = tiledlayout(fh, n, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(n);
for i = 1:n
    ax = nexttile(tl, i);
    key = char(rows.observable_key(i));
    mask = isfinite(aligned.A) & isfinite(aligned.(key));
    x = aligned.A(mask);
    y = aligned.(key);
    y = y(mask);
    scatter(ax, x, y, 42, aligned.T_K(mask), 'filled');
    hold(ax, 'on');
    p = polyfit(x, y, 1);
    xFit = linspace(min(x), max(x), 100);
    plot(ax, xFit, polyval(p, xFit), '--', 'Color', colors(i, :), 'LineWidth', 1.8);
    hold(ax, 'off');
    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    xlabel(ax, 'A(T)');
    ylabel(ax, char(rows.observable_key(i)));
    title(ax, sprintf('%s: Pearson %.2f, Spearman %.2f', char(rows.observable_key(i)), rows.pearson_r(i), rows.spearman_r(i)));
    grid(ax, 'on');
end
title(tl, 'Top candidate scatter comparisons versus A(T)');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveNormalizedTopCandidatesOverlay(topCandidates, aligned, runDir, figureName)
rows = topCandidates.allRows(1:min(3, height(topCandidates.allRows)), :);
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17 11]);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(height(rows));

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, aligned.T_K, normalize01(aligned.A), '--', 'Color', [0 0 0], 'LineWidth', 2.4, 'DisplayName', 'A(T)');
for i = 1:height(rows)
    plot(ax1, aligned.T_K, normalize01(aligned.(char(rows.observable_key(i)))), '-', ...
        'Color', colors(i, :), 'LineWidth', 1.8, 'DisplayName', char(rows.observable_key(i)));
end
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Normalized');
title(ax1, 'Direct normalized overlay');
legend(ax1, 'Location', 'eastoutside');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, aligned.T_K, 1 - normalize01(aligned.A), '--', 'Color', [0 0 0], 'LineWidth', 2.4, 'DisplayName', '1 - A(T)');
for i = 1:height(rows)
    plot(ax2, aligned.T_K, normalize01(aligned.(char(rows.observable_key(i)))), '-', ...
        'Color', colors(i, :), 'LineWidth', 1.8, 'DisplayName', char(rows.observable_key(i)));
end
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Normalized');
title(ax2, 'Mirror overlay for inverse-like comparisons');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTopCandidateFitPanels(topCandidates, fitTbl, aligned, runDir, figureName)
rows = topCandidates.fitRows;
n = height(rows);
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 18 4 + 5 * n]);
tl = tiledlayout(fh, n, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(n);

for i = 1:n
    ax = nexttile(tl, i);
    key = char(rows.observable_key(i));
    mask = isfinite(aligned.A) & isfinite(aligned.(key));
    A = aligned.A(mask);
    X = aligned.(key);
    X = X(mask);
    scatter(ax, A, X, 42, aligned.T_K(mask), 'filled');
    hold(ax, 'on');

    xFit = linspace(min(A), max(A), 200);
    direct = fitTbl(strcmp(fitTbl.observable_key, rows.observable_key(i)) & strcmp(fitTbl.model_key, "linear_X_from_A"), :);
    inverse = fitTbl(strcmp(fitTbl.observable_key, rows.observable_key(i)) & strcmp(fitTbl.model_key, "inverse_X_from_A"), :);
    power = fitTbl(strcmp(fitTbl.observable_key, rows.observable_key(i)) & strcmp(fitTbl.model_key, "power_X_from_A"), :);

    plot(ax, xFit, direct.param_a(1) .* xFit + direct.param_b(1), '-', 'Color', colors(i, :), 'LineWidth', 2.0, 'DisplayName', 'linear');
    plot(ax, xFit, inverse.param_a(1) ./ xFit, '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.0, 'DisplayName', 'inverse');
    if isfinite(power.param_a(1))
        plot(ax, xFit, power.param_a(1) .* xFit .^ power.alpha(1), ':', 'Color', [0.65 0.2 0.1], 'LineWidth', 2.4, 'DisplayName', 'power');
    end
    hold(ax, 'off');

    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    xlabel(ax, 'A(T)');
    ylabel(ax, char(rows.observable_key(i)));
    title(ax, sprintf('%s fits: best R^2 = %.2f', char(rows.observable_key(i)), max([direct.r2(1), inverse.r2(1), power.r2(1)])));
    legend(ax, 'Location', 'eastoutside');
    grid(ax, 'on');
end

title(tl, 'Simple model tests for top candidates');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTopCandidatesVsRidgeMotion(topCandidates, aligned, runDir, figureName)
rows = topCandidates.allRows(1:min(3, height(topCandidates.allRows)), :);
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 18 11]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(height(rows));
maskMotion = isfinite(aligned.motion_abs) & aligned.motion_valid_mask;

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, aligned.T_K(maskMotion), normalize01(aligned.motion_abs(maskMotion)), '--', 'Color', [0 0 0], 'LineWidth', 2.5, 'DisplayName', '|dI_{peak}/dT|');
for i = 1:height(rows)
    plot(ax1, aligned.T_K, normalize01(aligned.(char(rows.observable_key(i)))), '-', 'Color', colors(i, :), ...
        'LineWidth', 1.8, 'DisplayName', char(rows.observable_key(i)));
end
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Normalized');
title(ax1, 'Top candidates versus saved ridge motion');
legend(ax1, 'Location', 'eastoutside');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
for i = 1:height(rows)
    key = char(rows.observable_key(i));
    y = aligned.(key);
    mask = maskMotion & isfinite(y);
    scatter(ax2, aligned.motion_abs(mask), y(mask), 40, 'filled', ...
        'MarkerFaceColor', colors(i, :), 'DisplayName', char(rows.observable_key(i)));
end
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, '|dI_{peak}/dT| (mA/K)');
ylabel(ax2, 'Candidate value');
title(ax2, 'Ridge-motion scatter context');
legend(ax2, 'Location', 'best');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, aligned, summaryTbl, fitTbl, topCandidates, cfg)
aRows = summaryTbl(strcmp(summaryTbl.relaxation_key, "A_T"), :);
widthRow = findCandidateRow(aRows, "w");
bestRow = aRows(1, :);
bestComposite = aRows(~strcmp(aRows.observable_key, "w"), :);
if ~isempty(bestComposite)
    bestComposite = bestComposite(1, :);
end
wOverSRow = findCandidateRow(aRows, "w_over_S");
SOverWRow = findCandidateRow(aRows, "S_over_w");
wTimesSRow = findCandidateRow(aRows, "w_times_S");

[bestMotionPearson, bestMotionSpearman] = motionCorrelationPair(aligned, char(bestRow.observable_key));
[widthMotionPearson, widthMotionSpearman] = motionCorrelationPair(aligned, 'w');
relationLabel = classifyProxyBalance(bestRow.pearson_r(1), bestMotionPearson);

lines = strings(0, 1);
lines(end+1) = "# Switching composite observable scan";
lines(end+1) = "";
lines(end+1) = "## Inputs";
lines(end+1) = sprintf("- Switching full-scaling source: `%s`", char(source.switchRunName));
lines(end+1) = sprintf("- Relaxation source: `%s`", char(source.relaxRunName));
lines(end+1) = sprintf("- Saved ridge-motion source: `%s`", char(source.motionRunName));
lines(end+1) = sprintf("- Temperature window: %.0f-%.0f K on the switching grid", min(aligned.T_K), max(aligned.T_K));
lines(end+1) = sprintf("- Interpolation: `%s` from relaxation observables onto the switching temperature grid", cfg.interpMethod);
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "This run performs a structured low-order composite scan over the saved full-scaling switching observables `w = width(T)`, `S = S_peak(T)`, and `I = I_peak(T)`.";
lines(end+1) = "The tested family includes singles, pairwise products, pairwise ratios, and a limited set of squared or inverse-weighted variants. No higher-order ad hoc expressions were generated.";
lines(end+1) = "";
lines(end+1) = "## Existing repository state";
lines(end+1) = "- `run_2026_03_13_002809_switching_width_relaxation_correlation` already tested the full-scaling width alone against relaxation observables.";
lines(end+1) = "- `run_2026_03_13_011259_switching_width_dynamics_analysis` already tested width-only inverse, product, and ridge-motion hypotheses.";
lines(end+1) = "- Older runs such as `run_2026_03_10_233449_simple_switching_vs_relaxation_search` scanned derived observables from the earlier alignment-audit switching data, not from the full-scaling collapse run.";
lines(end+1) = "- The present run is therefore new only in the sense of scanning structured composites built from the full-scaling `w`, `S_peak`, and `I_peak` observables.";
lines(end+1) = "";
lines(end+1) = "## Main results";
if ~isempty(widthRow)
    lines(end+1) = sprintf("- Width baseline vs `A(T)`: Pearson `%.4f`, Spearman `%.4f`, shape mode `%s`.", widthRow.pearson_r(1), widthRow.spearman_r(1), char(widthRow.shape_mode(1)));
end
lines(end+1) = sprintf("- Best overall `A(T)` bridge in this scan: `%s` with Pearson `%.4f` and Spearman `%.4f`.", char(bestRow.observable_key(1)), bestRow.pearson_r(1), bestRow.spearman_r(1));
lines(end+1) = sprintf("- Best overall candidate relation class vs `A(T)`: `%s`.", char(bestRow.relation_to_A(1)));
if ~isempty(bestComposite)
    lines(end+1) = sprintf("- Best composite excluding width alone: `%s` with Pearson `%.4f`, Spearman `%.4f`, and shape mode `%s`.", char(bestComposite.observable_key(1)), bestComposite.pearson_r(1), bestComposite.spearman_r(1), char(bestComposite.shape_mode(1)));
    if ~isempty(widthRow)
        lines(end+1) = sprintf("- Improvement over width baseline for that composite: Delta Pearson `%.4f`, Delta Spearman `%.4f`.", bestComposite.width_baseline_pearson_delta(1), bestComposite.width_baseline_spearman_delta(1));
    end
end
lines(end+1) = "";
lines(end+1) = "## Named candidate checks";
if ~isempty(wOverSRow)
    lines(end+1) = sprintf("- `w/S_peak`: Pearson `%.4f`, Spearman `%.4f`, relation `%s`.", wOverSRow.pearson_r(1), wOverSRow.spearman_r(1), char(wOverSRow.relation_to_A(1)));
end
if ~isempty(SOverWRow)
    lines(end+1) = sprintf("- `S_peak/w`: Pearson `%.4f`, Spearman `%.4f`, relation `%s`.", SOverWRow.pearson_r(1), SOverWRow.spearman_r(1), char(SOverWRow.relation_to_A(1)));
end
if ~isempty(wTimesSRow)
    lines(end+1) = sprintf("- `w*S_peak`: Pearson `%.4f`, Spearman `%.4f`, relation `%s`.", wTimesSRow.pearson_r(1), wTimesSRow.spearman_r(1), char(wTimesSRow.relation_to_A(1)));
end
lines(end+1) = "";
lines(end+1) = "## Ridge-motion context";
lines(end+1) = sprintf("- Width alone vs saved ridge motion: Pearson `%.4f`, Spearman `%.4f`.", widthMotionPearson, widthMotionSpearman);
lines(end+1) = sprintf("- Best composite `%s` vs saved ridge motion: Pearson `%.4f`, Spearman `%.4f`.", char(bestRow.observable_key(1)), bestMotionPearson, bestMotionSpearman);
lines(end+1) = sprintf("- Proxy balance for the best composite: `%s`.", relationLabel);
lines(end+1) = "";
lines(end+1) = "## Interpretation";
lines(end+1) = "The comparison should be read as a descriptive composite scan over existing switching observables, not as evidence for a unique microscopic law.";
lines(end+1) = "The strongest bridge found here is a low-order composite dominated by large `I_peak`, narrow width, and small `S_peak`, so it is more naturally read as a joint geometric-activity descriptor than as a pure width scale.";
lines(end+1) = "A candidate is only worth highlighting if it improves over width alone and still has a clean physical interpretation rather than being a numerically accidental mixture.";
lines(end+1) = "";
lines(end+1) = "## Top candidates carried into model tests";
for i = 1:height(topCandidates.fitRows)
    key = topCandidates.fitRows.observable_key(i);
    fits = fitTbl(strcmp(fitTbl.observable_key, key), :);
    if isempty(fits)
        continue;
    end
    [~, bestIdx] = max(fits.r2);
    bestFit = fits(bestIdx, :);
    lines(end+1) = sprintf("- `%s`: best descriptive fit `%s` with `R^2 = %.4f` and `RMSE = %.4g`.", char(key), char(bestFit.model_label(1)), bestFit.r2(1), bestFit.rmse(1));
end
lines(end+1) = "";
lines(end+1) = "## Conclusion";
if ~isempty(bestComposite) && ~isempty(widthRow) && abs(bestComposite.spearman_r(1)) > abs(widthRow.spearman_r(1))
    lines(end+1) = "A simple derived switching observable does outperform `width(T)` alone as a bridge to relaxation activity in this structured scan.";
else
    lines(end+1) = "No simple derived switching observable clearly outperforms `width(T)` alone in a robust way.";
end
lines(end+1) = sprintf("Within this run, the most useful paper-level candidate is `%s`, but it should be presented as a descriptive composite rather than a clean standalone order parameter.", char(bestRow.observable_key(1)));
lines(end+1) = "";
lines(end+1) = "## Output files";
lines(end+1) = "- `tables/composite_observables_table.csv`";
lines(end+1) = "- `tables/correlation_summary.csv`";
lines(end+1) = "- `tables/top_candidate_fit_summary.csv`";
lines(end+1) = "- `figures/composite_correlation_heatmap.png`";
lines(end+1) = "- `figures/top_candidates_vs_A_overlay.png`";
lines(end+1) = "- `figures/top_candidates_scatter.png`";
lines(end+1) = "- `figures/normalized_top_candidates_overlay.png`";
lines(end+1) = "- `figures/top_candidate_fit_panels.png`";
lines(end+1) = "- `figures/top_candidates_vs_ridge_motion.png`";
lines(end+1) = "- `review/switching_composite_observable_scan_bundle.zip`";

reportText = strjoin(lines, newline);
end

function row = findCandidateRow(tbl, key)
row = tbl(strcmp(tbl.observable_key, string(key)), :);
if ~isempty(row)
    row = row(1, :);
end
end

function [pearsonR, spearmanR] = motionCorrelationPair(aligned, key)
y = aligned.(char(key));
mask = isfinite(aligned.motion_abs) & aligned.motion_valid_mask & isfinite(y);
pearsonR = corrSafe(y(mask), aligned.motion_abs(mask));
spearmanR = spearmanSafe(y(mask), aligned.motion_abs(mask));
end

function label = classifyProxyBalance(aPearson, motionPearson)
if abs(aPearson) >= abs(motionPearson) + 0.05
    label = "closer to a relaxation-activity proxy than a ridge-motion proxy";
elseif abs(motionPearson) >= abs(aPearson) + 0.05
    label = "closer to a ridge-motion proxy than a relaxation-activity proxy";
else
    label = "mixed between relaxation-activity and ridge-motion character";
end
end
function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
    return;
end
s.(fieldName) = defaultValue;
value = s;
end

function appendText(filePath, textToAppend)
fid = fopen(filePath, 'a');
if fid < 0
    error('Could not append to file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textToAppend);
end

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
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
zip(zipPath, {'tables', 'figures', 'reports'}, runDir);
end

function value = corrSafe(x, y)
if numel(x) < 2 || numel(y) < 2
    value = NaN;
    return;
end
x = x(:);
y = y(:);
if all(abs(x - x(1)) < 1e-12) || all(abs(y - y(1)) < 1e-12)
    value = NaN;
    return;
end
value = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
end

function value = spearmanSafe(x, y)
if numel(x) < 2 || numel(y) < 2
    value = NaN;
    return;
end
x = x(:);
y = y(:);
if all(abs(x - x(1)) < 1e-12) || all(abs(y - y(1)) < 1e-12)
    value = NaN;
    return;
end
value = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
end

function y = normalize01(x)
x = x(:);
mask = isfinite(x);
y = NaN(size(x));
if ~any(mask)
    return;
end
xMin = min(x(mask));
xMax = max(x(mask));
if ~isfinite(xMin) || ~isfinite(xMax) || abs(xMax - xMin) < 1e-12
    y(mask) = 0.5;
    return;
end
y(mask) = (x(mask) - xMin) ./ (xMax - xMin);
end

function rmse = computeRMSE(x, y)
mask = isfinite(x) & isfinite(y);
if ~any(mask)
    rmse = NaN;
    return;
end
rmse = sqrt(mean((x(mask) - y(mask)).^2));
end

function mae = computeMAE(x, y)
mask = isfinite(x) & isfinite(y);
if ~any(mask)
    mae = NaN;
    return;
end
mae = mean(abs(x(mask) - y(mask)));
end

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 2
    r2 = NaN;
    return;
end
yUse = y(mask);
yhatUse = yhat(mask);
ssRes = sum((yUse - yhatUse).^2);
ssTot = sum((yUse - mean(yUse)).^2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function peakT = findPeakT(T, y)
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    peakT = NaN;
    return;
end
T = T(mask);
y = y(mask);
[~, idx] = max(y);
peakT = T(idx);
end

function tf = isPeakBoundary(T, peakT)
if isempty(T) || ~isfinite(peakT)
    tf = false;
    return;
end
tf = abs(peakT - min(T)) < 1e-12 || abs(peakT - max(T)) < 1e-12;
end

function mode = chooseShapeMode(directRmse, inverseRmse)
if directRmse <= inverseRmse
    mode = "direct";
else
    mode = "inverse";
end
end

function relation = classifyRelationToA(pearsonR, directRmse, inverseRmse, cfg)
if isfinite(pearsonR) && pearsonR >= 0.4 && directRmse + cfg.classificationMargin < inverseRmse
    relation = "direct-like";
elseif isfinite(pearsonR) && pearsonR <= -0.4 && inverseRmse + cfg.classificationMargin < directRmse
    relation = "inverse-like";
else
    relation = "neither";
end
end





