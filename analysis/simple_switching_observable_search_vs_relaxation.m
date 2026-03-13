function out = simple_switching_observable_search_vs_relaxation(cfg)
% simple_switching_observable_search_vs_relaxation
% Thin cross-experiment search over simple, physically interpretable
% switching observables versus relaxation participation A(T).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg, repoRoot);
runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s', cfg.relaxRunName, cfg.switchRunName);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Repository State Summary:\n');
fprintf('- Reusing switching observable exports: S_peak(T), I_peak(T), width_I(T), halfwidth_diff_norm(T), asym(T).\n');
fprintf('- Reusing switching map data from switching_alignment_core_data.mat for the support-like observables only.\n');
fprintf('- Reusing relaxation A(T) as the primary target and R(T) as a secondary consistency check.\n');
fprintf('- New code is limited to one cross-experiment diagnostic script; no switching or relaxation pipeline code is modified.\n\n');

fprintf('Simple switching-observable search run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] simple switching-observable search started\n', stampNow()));

relax = loadRelaxationData(cfg.relaxRunDir);
switching = loadSwitchingData(cfg.switchRunDir, cfg);
defs = buildCandidateDefinitions(cfg);
[cand, overlay, sensitivity] = extractCandidateObservables(switching, cfg);
comparison = compareCandidates(defs, cand, relax, switching, sensitivity, cfg);
defTbl = definitionsToTable(defs);
candidateTbl = candidateObservablesTable(switching, cand, comparison);
summaryTbl = comparison.summaryTable;
[summaryTbl, shortlistNames, recommendedNames] = assignShortlist(summaryTbl, defs);
summaryTbl = sortrows(summaryTbl, {'recommendation_rank','combined_score'}, {'ascend','descend'});

candidatePath = save_run_table(candidateTbl, 'candidate_observables_vs_T.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'candidate_vs_relaxation_summary.csv', runDir);
defPath = save_run_table(defTbl, 'candidate_definition_table.csv', runDir);

figShort = saveShortlistFigure(relax, switching, cand, defs, summaryTbl, shortlistNames, runDir, 'shortlisted_candidates_vs_A');
figOverview = saveOverviewFigure(relax, switching, cand, defs, runDir, 'candidate_overview_normalized');
figMap = saveSupportOverlayFigure(switching, overlay, runDir, 'switching_map_support_overlays');
figSensitivity = saveSensitivityFigure(sensitivity, comparison, runDir, 'support_threshold_sensitivity');

reportText = buildReport(cfg, relax, switching, defs, summaryTbl, recommendedNames, shortlistNames, comparison, sensitivity);
reportPath = save_run_report(reportText, 'simple_switching_observable_search_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] search complete\n', stampNow()));
appendText(run.log_path, sprintf('Candidate table: %s\n', candidatePath));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Definition table: %s\n', defPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

appendText(run.notes_path, sprintf('Recommended candidate 1: %s\n', char(recommendedNames(1))));
if numel(recommendedNames) >= 2
    appendText(run.notes_path, sprintf('Recommended candidate 2: %s\n', char(recommendedNames(2))));
end

out = struct();
out.runDir = string(runDir);
out.relax = relax;
out.switching = switching;
out.comparison = comparison;
out.summaryTable = summaryTbl;
out.recommendedNames = recommendedNames;
out.shortlistNames = shortlistNames;
out.tables = struct('candidate', string(candidatePath), 'summary', string(summaryPath), 'definitions', string(defPath));
out.figures = struct('shortlist', string(figShort.png), 'overview', string(figOverview.png), 'map', string(figMap.png), 'sensitivity', string(figSensitivity.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Simple switching-observable search complete ===\n');
fprintf('Run dir: %s\n', runDir);
for i = 1:min(2, height(summaryTbl))
    fprintf('Top candidate %d: %s | Pearson(A)=%.3f | Spearman(A)=%.3f | Class=%s\n', ...
        i, summaryTbl.candidate_name(i), summaryTbl.pearson_A(i), summaryTbl.spearman_A(i), summaryTbl.observable_class(i));
end
fprintf('Report: %s\nZIP: %s\n\n', reportPath, zipPath);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefaultField(cfg, 'runLabel', 'simple_switching_vs_relaxation_search');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'comparisonSignalFloorFrac', 0.05);
cfg = setDefaultField(cfg, 'supportThreshold', 0.30);
cfg = setDefaultField(cfg, 'topFractionThreshold', 0.80);
cfg = setDefaultField(cfg, 'supportThresholdSweep', [0.20 0.30 0.40]);
cfg = setDefaultField(cfg, 'topFractionSweep', [0.70 0.80 0.90]);
cfg.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', cfg.relaxRunName);
cfg.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.switchRunName);
end

function relax = loadRelaxationData(relaxRunDir)
obsTbl = readtable(fullfile(relaxRunDir, 'tables', 'observables_relaxation.csv'));
tempTbl = readtable(fullfile(relaxRunDir, 'tables', 'temperature_observables.csv'));

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
if ismember('R_T', string(tempTbl.Properties.VariableNames))
    relax.R = tempTbl.R_T(:);
else
    relax.R = NaN(size(relax.T));
end
relax.Relax_T_peak = obsTbl.Relax_T_peak(1);
relax.Relax_peak_width = obsTbl.Relax_peak_width(1);
[relax.windowLow, relax.windowHigh, relax.windowWidth, ~] = halfmaxWindow(relax.T, relax.A);
if ~isfinite(relax.windowWidth)
    relax.windowWidth = relax.Relax_peak_width;
    relax.windowLow = relax.Relax_T_peak - 0.5 * relax.Relax_peak_width;
    relax.windowHigh = relax.Relax_T_peak + 0.5 * relax.Relax_peak_width;
end
relax.A_norm = normalizePositive(relax.A);
relax.R_norm = normalizePositive(relax.R);
end

function switching = loadSwitchingData(switchRunDir, cfg)
obsWide = readtable(fullfile(switchRunDir, 'observable_matrix.csv'));
obsLong = readtable(fullfile(switchRunDir, 'observables.csv'));
core = load(fullfile(switchRunDir, 'switching_alignment_core_data.mat'));

switching = struct();
switching.T = obsWide.T(:);
switching.S_peak = obsWide.S_peak(:);
switching.I_peak = obsWide.I_peak(:);
switching.width_I = obsWide.width_I(:);
switching.halfwidth_diff_norm = obsWide.halfwidth_diff_norm(:);
switching.asym = obsWide.asym(:);
switching.obsLong = obsLong;
switching.currents = core.currents(:);
switching.Smap = core.Smap;
switching.temps_map = core.temps(:);
switching.comparisonMask = isfinite(switching.T) & isfinite(switching.S_peak) & switching.S_peak >= cfg.comparisonSignalFloorFrac * max(switching.S_peak, [], 'omitnan');
end

function defs = buildCandidateDefinitions(cfg)
defs = repmat(struct('name',"",'family',"",'observableClass',"",'formulaRule',"",'dataSource',"",'physicalInterpretation',"",'parameters',"",'peakMeaningful',false,'shapeMode',"none",'interpretabilityScore',NaN,'interpretabilityNote',"",'sensitivityGroup',"none"), 13, 1);

defs(1) = makeDef("S_peak","A","amplitude-like","Direct ridge height S_peak(T)","observable_matrix.csv","Raw switching ridge amplitude; strongest local response at the ridge crest.","none",true,"positive",5,"Very simple but may track switching strength rather than participation.","none");
defs(2) = makeDef("I_peak","A","motion-like","Direct ridge current I_peak(T)","observable_matrix.csv","Current position of the switching ridge backbone.","none",false,"positive",5,"Very simple geometric ridge coordinate.","none");
defs(3) = makeDef("width_I","A","support-like","Existing half-maximum ridge width width_I(T)","observable_matrix.csv","Current span of the active switching band at half maximum.","relative threshold 0.5 of S_peak",true,"positive",5,"Simple existing support-like observable.","none");
defs(4) = makeDef("halfwidth_diff_norm","A","asymmetry-like","Existing normalized right-left half-width difference", "observable_matrix.csv", "Skew of the ridge flanks rather than total participation.", "relative threshold 0.5 of S_peak", false, "signed", 4, "Simple shape-asymmetry metric, but not obviously participation-like.", "none");
defs(5) = makeDef("asym","A","asymmetry-like","Existing area ratio asym(T)","observable_matrix.csv","Left-right ridge asymmetry around the crest.","existing alignment-audit definition",false,"positive",4,"Simple but may reflect shape bias rather than population size.","none");
defs(6) = makeDef("abs_step_dI_perK","B","motion-like","abs(central finite difference of I_peak with respect to T)","observable_matrix.csv","How strongly the ridge moves in current between neighboring temperatures.","central finite difference on irregular T grid",true,"positive",4,"Simple local motion activity metric.","none");
defs(7) = makeDef("abs_step_dS_perK","B","amplitude-like","abs(central finite difference of S_peak with respect to T)","observable_matrix.csv","How strongly the ridge height changes between neighboring temperatures.","central finite difference on irregular T grid",true,"positive",4,"Simple local amplitude-change metric.","none");
defs(8) = makeDef("signed_step_dI_perK","B","motion-like","central finite difference of I_peak with sign", "observable_matrix.csv", "Direction of ridge motion in current as temperature changes.", "central finite difference on irregular T grid", false, "signed", 3, "Direction is informative, but sign complicates direct participation comparison.", "none");
defs(9) = makeDef("signed_step_dS_perK","B","amplitude-like","central finite difference of S_peak with sign", "observable_matrix.csv", "Direction of ridge-height change as temperature changes.", "central finite difference on irregular T grid", false, "signed", 3, "Direction is informative, but sign complicates direct participation comparison.", "none");
defs(10) = makeDef("ridge_band_width_rel30","C","support-like","Width of contiguous ridge band with S >= 0.3*S_peak containing I_peak", "switching_alignment_core_data.mat", "How broad the locally active ridge-support band is at a low relative threshold.", sprintf('relative threshold %.2f of S_peak', cfg.supportThreshold), true, "positive", 5, "Very interpretable current-support metric.", "support_rel");
defs(11) = makeDef("ridge_supported_area_rel30","C","support-like","Integral of S over the same contiguous ridge band", "switching_alignment_core_data.mat", "Total switching weight carried by the local ridge-support band.", sprintf('relative threshold %.2f of S_peak', cfg.supportThreshold), true, "positive", 5, "Closest simple analog to participating switching weight.", "support_rel");
defs(12) = makeDef("ridge_participation_count_rel30","C","support-like","Number of sampled current points in the same contiguous ridge band", "switching_alignment_core_data.mat", "Discrete count of current samples participating in the ridge-support band.", sprintf('relative threshold %.2f of S_peak', cfg.supportThreshold), true, "positive", 5, "Very transparent discrete participation proxy.", "support_rel");
defs(13) = makeDef("ridge_top_fraction_width_rel80","C","support-like","Width of contiguous ridge crest with S >= 0.8*S_peak containing I_peak", "switching_alignment_core_data.mat", "How broad the very top of the ridge crest is.", sprintf('relative threshold %.2f of S_peak', cfg.topFractionThreshold), true, "positive", 4, "Simple crest-breadth metric, but more threshold-sensitive.", "top_rel");
end

function [cand, overlay, sensitivity] = extractCandidateObservables(switching, cfg)
T = switching.T(:);
Ipk = switching.I_peak(:);
Spk = switching.S_peak(:);

cand = struct();
cand.S_peak = Spk;
cand.I_peak = Ipk;
cand.width_I = switching.width_I(:);
cand.halfwidth_diff_norm = switching.halfwidth_diff_norm(:);
cand.asym = switching.asym(:);
[cand.signed_step_dI_perK, cand.abs_step_dI_perK] = localFiniteDifference(Ipk, T);
[cand.signed_step_dS_perK, cand.abs_step_dS_perK] = localFiniteDifference(Spk, T);
[supportLow, supportHigh, supportWidth, supportCount, supportArea] = ridgeBandMetrics(switching.Smap, switching.currents, switching.I_peak, switching.S_peak, cfg.supportThreshold);
[topLow, topHigh, topWidth, ~, ~] = ridgeBandMetrics(switching.Smap, switching.currents, switching.I_peak, switching.S_peak, cfg.topFractionThreshold);
cand.ridge_band_width_rel30 = supportWidth;
cand.ridge_supported_area_rel30 = supportArea;
cand.ridge_participation_count_rel30 = supportCount;
cand.ridge_top_fraction_width_rel80 = topWidth;

overlay = struct();
overlay.supportLow = supportLow;
overlay.supportHigh = supportHigh;
overlay.topLow = topLow;
overlay.topHigh = topHigh;

sensitivity = struct();
sensitivity.supportThresholds = cfg.supportThresholdSweep(:);
sensitivity.topThresholds = cfg.topFractionSweep(:);
nSupp = numel(sensitivity.supportThresholds);
nTop = numel(sensitivity.topThresholds);
sensitivity.bandWidth = NaN(numel(T), nSupp);
sensitivity.bandArea = NaN(numel(T), nSupp);
sensitivity.participationCount = NaN(numel(T), nSupp);
sensitivity.topWidth = NaN(numel(T), nTop);
for i = 1:nSupp
    [~, ~, wTmp, cTmp, aTmp] = ridgeBandMetrics(switching.Smap, switching.currents, switching.I_peak, switching.S_peak, sensitivity.supportThresholds(i));
    sensitivity.bandWidth(:, i) = wTmp;
    sensitivity.bandArea(:, i) = aTmp;
    sensitivity.participationCount(:, i) = cTmp;
end
for i = 1:nTop
    [~, ~, wTmp, ~, ~] = ridgeBandMetrics(switching.Smap, switching.currents, switching.I_peak, switching.S_peak, sensitivity.topThresholds(i));
    sensitivity.topWidth(:, i) = wTmp;
end
end

function comparison = compareCandidates(defs, cand, relax, switching, sensitivity, cfg)
comparison = struct();
comparison.T = switching.T(:);
comparison.A_interp = interp1(relax.T, relax.A, comparison.T, 'pchip', NaN);
comparison.R_interp = interp1(relax.T, relax.R, comparison.T, 'pchip', NaN);
comparison.baseMask = switching.comparisonMask & isfinite(comparison.A_interp);

rows = repmat(initSummaryRow(), numel(defs), 1);
for i = 1:numel(defs)
    def = defs(i);
    y = cand.(def.name);
    mask = comparison.baseMask & isfinite(y);
    pearsonA = corrSafe(comparison.A_interp(mask), y(mask));
    spearmanA = spearmanSafe(comparison.A_interp(mask), y(mask));
    pearsonR = corrSafe(comparison.R_interp(mask), y(mask));
    spearmanR = spearmanSafe(comparison.R_interp(mask), y(mask));

    peakT = NaN; peakDiff = NaN; overlap = NaN;
    if def.peakMeaningful
        [candidateLow, candidateHigh, ~, peakT] = halfmaxWindow(comparison.T(mask), positiveForm(y(mask), def.shapeMode));
        if isfinite(peakT)
            peakDiff = peakT - relax.Relax_T_peak;
            overlap = intervalOverlap(relax.windowLow, relax.windowHigh, candidateLow, candidateHigh);
        end
    end

    rmsNorm = NaN;
    if def.shapeMode == "positive"
        rmsNorm = rmsDifference(normalizePositive(comparison.A_interp(mask)), normalizePositive(y(mask)));
    end

    [sensitivityNote, sensitivityPenalty] = sensitivityAssessment(def, comparison, sensitivity, cfg);
    interpretabilityScore = def.interpretabilityScore;
    peakAlignScore = 0;
    if isfinite(peakDiff)
        peakAlignScore = max(0, 1 - abs(peakDiff) / 20);
    end
    shapeScore = 0;
    if isfinite(rmsNorm)
        shapeScore = max(0, 1 - min(rmsNorm, 1));
    end
    overlapScore = 0;
    if isfinite(overlap)
        overlapScore = overlap;
    end
    combinedScore = 0.35 * max(pearsonA, 0) + 0.25 * max(spearmanA, 0) + 0.15 * overlapScore + 0.15 * shapeScore + 0.05 * peakAlignScore + 0.05 * (interpretabilityScore / 5) - sensitivityPenalty;

    row = initSummaryRow();
    row.candidate_name = def.name;
    row.family = def.family;
    row.observable_class = def.observableClass;
    row.pearson_A = pearsonA;
    row.spearman_A = spearmanA;
    row.pearson_R = pearsonR;
    row.spearman_R = spearmanR;
    row.peak_T = peakT;
    row.peak_diff_from_A_K = peakDiff;
    row.window_overlap_with_A = overlap;
    row.rms_norm_vs_A = rmsNorm;
    row.interpretability_score = interpretabilityScore;
    row.interpretability_note = def.interpretabilityNote;
    row.sensitivity_note = sensitivityNote;
    row.combined_score = combinedScore;
    row.physical_note = physicalAssessment(def, pearsonA, spearmanA, overlap, peakDiff);
    rows(i) = row;
end
comparison.summaryTable = struct2table(rows);
end

function defTbl = definitionsToTable(defs)
defTbl = table(strings(numel(defs),1), strings(numel(defs),1), strings(numel(defs),1), strings(numel(defs),1), strings(numel(defs),1), strings(numel(defs),1), strings(numel(defs),1), false(numel(defs),1), strings(numel(defs),1), NaN(numel(defs),1), strings(numel(defs),1), ...
    'VariableNames', {'candidate_name','family','observable_class','formula_rule','data_source','physical_interpretation','parameters','peak_window_meaningful','shape_mode','interpretability_score','interpretability_note'});
for i = 1:numel(defs)
    defTbl.candidate_name(i) = defs(i).name;
    defTbl.family(i) = defs(i).family;
    defTbl.observable_class(i) = defs(i).observableClass;
    defTbl.formula_rule(i) = defs(i).formulaRule;
    defTbl.data_source(i) = defs(i).dataSource;
    defTbl.physical_interpretation(i) = defs(i).physicalInterpretation;
    defTbl.parameters(i) = defs(i).parameters;
    defTbl.peak_window_meaningful(i) = defs(i).peakMeaningful;
    defTbl.shape_mode(i) = defs(i).shapeMode;
    defTbl.interpretability_score(i) = defs(i).interpretabilityScore;
    defTbl.interpretability_note(i) = defs(i).interpretabilityNote;
end
end

function tbl = candidateObservablesTable(switching, cand, comparison)
tbl = table(switching.T(:), comparison.A_interp(:), comparison.R_interp(:), switching.comparisonMask(:), ...
    cand.S_peak(:), cand.I_peak(:), cand.width_I(:), cand.halfwidth_diff_norm(:), cand.asym(:), ...
    cand.abs_step_dI_perK(:), cand.abs_step_dS_perK(:), cand.signed_step_dI_perK(:), cand.signed_step_dS_perK(:), ...
    cand.ridge_band_width_rel30(:), cand.ridge_supported_area_rel30(:), cand.ridge_participation_count_rel30(:), cand.ridge_top_fraction_width_rel80(:), ...
    'VariableNames', {'T','A_interp','R_interp','comparison_mask', ...
    'S_peak','I_peak','width_I','halfwidth_diff_norm','asym', ...
    'abs_step_dI_perK','abs_step_dS_perK','signed_step_dI_perK','signed_step_dS_perK', ...
    'ridge_band_width_rel30','ridge_supported_area_rel30','ridge_participation_count_rel30','ridge_top_fraction_width_rel80'});
end

function [summaryTbl, shortlistNames, recommendedNames] = assignShortlist(summaryTbl, defs)
summaryTbl.recommendation_rank = NaN(height(summaryTbl), 1);
summaryTbl.shortlist_tier = repmat("not_shortlisted", height(summaryTbl), 1);

eligible = summaryTbl.combined_score > 0 & summaryTbl.interpretability_score >= 4 & ~startsWith(summaryTbl.candidate_name, "signed_");
eligibleTbl = summaryTbl(eligible, :);
eligibleTbl = sortrows(eligibleTbl, {'combined_score','pearson_A','spearman_A'}, {'descend','descend','descend'});

nShort = min(4, height(eligibleTbl));
shortlistNames = strings(0,1);
recommendedNames = strings(0,1);
if nShort > 0
    shortlistNames = eligibleTbl.candidate_name(1:nShort);
    recommendedNames = eligibleTbl.candidate_name(1:min(2, nShort));
end

for i = 1:numel(shortlistNames)
    idx = find(summaryTbl.candidate_name == shortlistNames(i), 1, 'first');
    summaryTbl.recommendation_rank(idx) = i;
    if i <= numel(recommendedNames)
        summaryTbl.shortlist_tier(idx) = "recommended";
    else
        summaryTbl.shortlist_tier(idx) = "shortlisted";
    end
end
end
function figPaths = saveShortlistFigure(relax, switching, cand, defs, summaryTbl, shortlistNames, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 800]);
tl = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:min(4, numel(shortlistNames))
    ax = nexttile(tl, i);
    def = defs(find(string({defs.name}) == shortlistNames(i), 1, 'first'));
    y = cand.(def.name);
    if def.shapeMode == "signed"
        yNorm = normalizeSigned(y);
        yLabel = 'signed-normalized candidate';
    else
        yNorm = normalizePositive(y);
        yLabel = 'normalized candidate';
    end
    plot(ax, relax.T, relax.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
    hold(ax, 'on');
    plot(ax, switching.T, yNorm, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', char(shortlistNames(i)));
    plot(ax, relax.T, relax.R_norm, '--', 'LineWidth', 1.8, 'DisplayName', 'R(T) / max');
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
    ylabel(ax, yLabel, 'FontSize', 14);
    title(ax, sprintf('%s vs A(T)', strrep(char(shortlistNames(i)), '_', '\_')), 'FontSize', 16, 'Interpreter', 'tex');
    legend(ax, 'Location', 'best');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2);
end
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveOverviewFigure(relax, switching, cand, defs, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 900]);
tl = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1); hold(ax1, 'on');
plot(ax1, relax.T, relax.A_norm, '-k', 'LineWidth', 2.4, 'DisplayName', 'A(T) / max');
plot(ax1, switching.T, normalizePositive(cand.S_peak), '-o', 'LineWidth', 2.0, 'DisplayName', 'S_peak');
plot(ax1, switching.T, normalizePositive(cand.I_peak), '-s', 'LineWidth', 2.0, 'DisplayName', 'I_peak');
plot(ax1, switching.T, normalizePositive(cand.width_I), '-^', 'LineWidth', 2.0, 'DisplayName', 'width_I');
grid(ax1, 'on'); xlabel(ax1, 'T (K)', 'FontSize', 14); ylabel(ax1, 'normalized value', 'FontSize', 14); title(ax1, 'Direct ridge observables', 'FontSize', 16); legend(ax1, 'Location', 'best'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl, 2); hold(ax2, 'on');
plot(ax2, relax.T, relax.A_norm, '-k', 'LineWidth', 2.4, 'DisplayName', 'A(T) / max');
plot(ax2, switching.T, normalizeSigned(cand.halfwidth_diff_norm), '-o', 'LineWidth', 2.0, 'DisplayName', 'halfwidth_diff_norm');
plot(ax2, switching.T, normalizePositive(cand.asym), '-s', 'LineWidth', 2.0, 'DisplayName', 'asym');
yline(ax2, 0, ':', 'LineWidth', 1.2, 'HandleVisibility', 'off');
grid(ax2, 'on'); xlabel(ax2, 'T (K)', 'FontSize', 14); ylabel(ax2, 'scaled value', 'FontSize', 14); title(ax2, 'Asymmetry-like observables', 'FontSize', 16); legend(ax2, 'Location', 'best'); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

ax3 = nexttile(tl, 3); hold(ax3, 'on');
plot(ax3, relax.T, relax.A_norm, '-k', 'LineWidth', 2.4, 'DisplayName', 'A(T) / max');
plot(ax3, switching.T, normalizePositive(cand.abs_step_dI_perK), '-o', 'LineWidth', 2.0, 'DisplayName', 'abs_step_dI_perK');
plot(ax3, switching.T, normalizePositive(cand.abs_step_dS_perK), '-s', 'LineWidth', 2.0, 'DisplayName', 'abs_step_dS_perK');
plot(ax3, switching.T, normalizeSigned(cand.signed_step_dI_perK), '--', 'LineWidth', 1.8, 'DisplayName', 'signed_step_dI_perK');
plot(ax3, switching.T, normalizeSigned(cand.signed_step_dS_perK), ':', 'LineWidth', 1.8, 'DisplayName', 'signed_step_dS_perK');
yline(ax3, 0, ':', 'LineWidth', 1.2, 'HandleVisibility', 'off');
grid(ax3, 'on'); xlabel(ax3, 'T (K)', 'FontSize', 14); ylabel(ax3, 'scaled value', 'FontSize', 14); title(ax3, 'Stepwise ridge dynamics', 'FontSize', 16); legend(ax3, 'Location', 'best'); set(ax3, 'FontSize', 14, 'LineWidth', 1.2);

ax4 = nexttile(tl, 4); hold(ax4, 'on');
plot(ax4, relax.T, relax.A_norm, '-k', 'LineWidth', 2.4, 'DisplayName', 'A(T) / max');
plot(ax4, switching.T, normalizePositive(cand.ridge_band_width_rel30), '-o', 'LineWidth', 2.0, 'DisplayName', 'band width rel30');
plot(ax4, switching.T, normalizePositive(cand.ridge_supported_area_rel30), '-s', 'LineWidth', 2.0, 'DisplayName', 'supported area rel30');
plot(ax4, switching.T, normalizePositive(cand.ridge_participation_count_rel30), '-^', 'LineWidth', 2.0, 'DisplayName', 'participation count rel30');
plot(ax4, switching.T, normalizePositive(cand.ridge_top_fraction_width_rel80), '-d', 'LineWidth', 2.0, 'DisplayName', 'top width rel80');
grid(ax4, 'on'); xlabel(ax4, 'T (K)', 'FontSize', 14); ylabel(ax4, 'normalized value', 'FontSize', 14); title(ax4, 'Support-like observables', 'FontSize', 16); legend(ax4, 'Location', 'best'); set(ax4, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSupportOverlayFigure(switching, overlay, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 680]);
ax = axes(fh);
imagesc(ax, switching.currents, switching.temps_map, switching.Smap);
axis(ax, 'xy');
colormap(ax, parula); cb = colorbar(ax); ylabel(cb, 'Switching signal S(T,I)', 'FontSize', 14);
hold(ax, 'on');
plot(ax, switching.I_peak, switching.T, 'k-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'I_peak ridge');
plot(ax, overlay.supportLow, switching.T, '--', 'LineWidth', 1.8, 'DisplayName', 'support band low (0.3)');
plot(ax, overlay.supportHigh, switching.T, '--', 'LineWidth', 1.8, 'DisplayName', 'support band high (0.3)');
plot(ax, overlay.topLow, switching.T, ':', 'LineWidth', 1.8, 'DisplayName', 'top crest low (0.8)');
plot(ax, overlay.topHigh, switching.T, ':', 'LineWidth', 1.8, 'DisplayName', 'top crest high (0.8)');
hold(ax, 'off');
xlabel(ax, 'Current I (mA)', 'FontSize', 14); ylabel(ax, 'Temperature T (K)', 'FontSize', 14); title(ax, 'Switching map with simple ridge-support overlays', 'FontSize', 16); legend(ax, 'Location', 'southwest'); set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSensitivityFigure(sensitivity, comparison, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 460]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1); hold(ax1, 'on');
pA_width = corrSweep(comparison.A_interp, sensitivity.bandWidth, comparison.baseMask);
pA_area = corrSweep(comparison.A_interp, sensitivity.bandArea, comparison.baseMask);
pA_count = corrSweep(comparison.A_interp, sensitivity.participationCount, comparison.baseMask);
plot(ax1, sensitivity.supportThresholds, pA_width, '-o', 'LineWidth', 2.0, 'DisplayName', 'band width');
plot(ax1, sensitivity.supportThresholds, pA_area, '-s', 'LineWidth', 2.0, 'DisplayName', 'supported area');
plot(ax1, sensitivity.supportThresholds, pA_count, '-^', 'LineWidth', 2.0, 'DisplayName', 'participation count');
grid(ax1, 'on'); xlabel(ax1, 'Relative threshold', 'FontSize', 14); ylabel(ax1, 'Pearson corr with A(T)', 'FontSize', 14); title(ax1, 'Support-threshold sensitivity', 'FontSize', 16); legend(ax1, 'Location', 'best'); set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl, 2); hold(ax2, 'on');
pA_top = corrSweep(comparison.A_interp, sensitivity.topWidth, comparison.baseMask);
plot(ax2, sensitivity.topThresholds, pA_top, '-o', 'LineWidth', 2.0, 'DisplayName', 'top-fraction width');
grid(ax2, 'on'); xlabel(ax2, 'Top-fraction threshold', 'FontSize', 14); ylabel(ax2, 'Pearson corr with A(T)', 'FontSize', 14); title(ax2, 'Top-width sensitivity', 'FontSize', 16); legend(ax2, 'Location', 'best'); set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReport(cfg, relax, switching, defs, summaryTbl, recommendedNames, shortlistNames, comparison, sensitivity)
lines = strings(0,1);
lines(end+1) = "# Simple Switching Observable Search vs Relaxation";
lines(end+1) = "";
lines(end+1) = "## Repository State / Reuse Summary";
lines(end+1) = "- Reused switching ridge observables from the alignment-audit run instead of recomputing them from scratch.";
lines(end+1) = "- Reused the saved switching map only to build the simple support-like observables around the existing ridge crest.";
lines(end+1) = "- Reused relaxation `A(T)` as the primary target and `R(T)` only as a secondary consistency check.";
lines(end+1) = "- Added one run-scoped cross-experiment diagnostic only; no production pipelines were modified.";
lines(end+1) = "";
lines(end+1) = "## Candidate Families and Rationale";
lines(end+1) = "- Group A: direct ridge observables already present in the switching observable layer.";
lines(end+1) = "- Group B: nearest-neighbor step metrics to test whether local ridge motion or local ridge-height change tracks participation better than raw amplitudes.";
lines(end+1) = "- Group C: simple support-like observables that ask how wide, heavy, or populated the local ridge-support band is in current.";
lines(end+1) = "";
lines(end+1) = "## Comparison Framework";
lines(end+1) = sprintf('- Relaxation A(T) was interpolated onto the switching temperature grid using pchip because the two runs do not share common sampled temperatures.');
lines(end+1) = sprintf('- All candidate comparisons use a common switching-ridge presence mask: S_peak(T) >= %.2f * max(S_peak).', cfg.comparisonSignalFloorFrac);
lines(end+1) = "- Candidates were judged by Pearson and Spearman correlation, normalized shape similarity, peak/window comparison where meaningful, physical interpretability, and threshold sensitivity when applicable.";
lines(end+1) = "";
lines(end+1) = "## Shortlist";
for i = 1:numel(shortlistNames)
    row = summaryTbl(summaryTbl.candidate_name == shortlistNames(i), :);
    lines(end+1) = sprintf('- %s | class=%s | Pearson(A)=%.3f | Spearman(A)=%.3f | note: %s', row.candidate_name, row.observable_class, row.pearson_A, row.spearman_A, row.physical_note);
end
lines(end+1) = "";
lines(end+1) = "## Recommended Next-Step Candidates";
for i = 1:numel(recommendedNames)
    row = summaryTbl(summaryTbl.candidate_name == recommendedNames(i), :);
    lines(end+1) = sprintf('- %s: %s', row.candidate_name, row.physical_note);
end
lines(end+1) = "";
lines(end+1) = "## Physical Interpretation";
negS = summaryTbl(summaryTbl.candidate_name == "S_peak", :);
if ~isempty(negS)
    lines(end+1) = sprintf('- `S_peak(T)` gives Pearson(A)=%.3f, which shows why raw switching strength alone is not the right participation analog here: the largest switching amplitude sits at low T where A(T) is still small.', negS.pearson_A);
end
posSupport = summaryTbl(summaryTbl.observable_class == "support-like", :);
if ~isempty(posSupport)
    bestSupport = posSupport(1, :);
    lines(end+1) = sprintf('- The best support-like candidate in this run was `%s`, which is physically closest to a participation picture because it counts or integrates how much of the ridge-support band is active, not just how high the crest is.', bestSupport.candidate_name);
end
motionRows = summaryTbl(summaryTbl.observable_class == "motion-like", :);
if ~isempty(motionRows)
    bestMotion = motionRows(1, :);
    lines(end+1) = sprintf('- The best motion-like candidate was `%s`, which captures where the ridge is rearranging most strongly with temperature rather than how large the switching amplitude is.', bestMotion.candidate_name);
end
lines(end+1) = "";
lines(end+1) = "## Remaining Uncertainties";
lines(end+1) = "- The support-like metrics depend on relative thresholds, although the sweep here was deliberately kept small and transparent.";
lines(end+1) = "- The switching temperature grid is sparse, so the local step metrics are quantized by the available temperature spacing.";
lines(end+1) = "- Some simple candidates may capture only one aspect of the relaxation participation picture, such as local rearrangement activity or support width, rather than the full A(T) shape.";
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = "- number of curves: the overview figure uses four family panels with at most five curves per panel; the shortlist figure uses one candidate per panel plus A(T) and R(T); the sensitivity figure uses at most three curves per panel";
lines(end+1) = "- legend vs colormap: legends only for all line plots because each panel stays at 6 or fewer curves; parula plus colorbar for the map figure";
lines(end+1) = "- colormap used: parula";
lines(end+1) = "- smoothing applied: none beyond pchip interpolation of A(T) and R(T) onto the switching temperature grid";
lines(end+1) = "- justification: the figure set is designed to keep the candidate family compact and physically legible rather than turning the search into a feature factory";
reportText = strjoin(lines, newline);
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'simple_switching_observable_search.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function def = makeDef(name, family, obsClass, formulaRule, dataSource, physicalInterpretation, parameters, peakMeaningful, shapeMode, interpretabilityScore, interpretabilityNote, sensitivityGroup)
def = struct('name', name, 'family', family, 'observableClass', obsClass, 'formulaRule', formulaRule, 'dataSource', dataSource, 'physicalInterpretation', physicalInterpretation, 'parameters', parameters, 'peakMeaningful', peakMeaningful, 'shapeMode', shapeMode, 'interpretabilityScore', interpretabilityScore, 'interpretabilityNote', interpretabilityNote, 'sensitivityGroup', sensitivityGroup);
end

function row = initSummaryRow()
row = struct('candidate_name', "", 'family', "", 'observable_class', "", 'pearson_A', NaN, 'spearman_A', NaN, 'pearson_R', NaN, 'spearman_R', NaN, 'peak_T', NaN, 'peak_diff_from_A_K', NaN, 'window_overlap_with_A', NaN, 'rms_norm_vs_A', NaN, 'interpretability_score', NaN, 'interpretability_note', "", 'sensitivity_note', "", 'combined_score', NaN, 'physical_note', "");
end
function [signedStep, absStep] = localFiniteDifference(y, T)
y = y(:); T = T(:); signedStep = NaN(size(y)); absStep = NaN(size(y));
valid = isfinite(y) & isfinite(T);
idx = find(valid);
if numel(idx) < 2
    return;
end
for k = 1:numel(idx)
    ii = idx(k);
    if k == 1
        jj = idx(k + 1);
        dy = y(jj) - y(ii); dT = T(jj) - T(ii);
    elseif k == numel(idx)
        jj = idx(k - 1);
        dy = y(ii) - y(jj); dT = T(ii) - T(jj);
    else
        j1 = idx(k - 1); j2 = idx(k + 1);
        dy = y(j2) - y(j1); dT = T(j2) - T(j1);
    end
    if isfinite(dT) && abs(dT) > eps
        signedStep(ii) = dy / dT;
        absStep(ii) = abs(signedStep(ii));
    end
end
end

function [bandLow, bandHigh, bandWidth, bandCount, bandArea] = ridgeBandMetrics(Smap, currents, Ipeak, Speak, relThreshold)
nT = numel(Ipeak);
bandLow = NaN(nT,1); bandHigh = NaN(nT,1); bandWidth = NaN(nT,1); bandCount = NaN(nT,1); bandArea = NaN(nT,1);
for it = 1:nT
    row = Smap(it,:);
    valid = isfinite(row) & isfinite(currents.');
    if nnz(valid) < 2 || ~isfinite(Ipeak(it)) || ~isfinite(Speak(it)) || Speak(it) <= 0
        continue;
    end
    cur = currents(valid);
    sig = row(valid);
    [~, idxPeak] = min(abs(cur - Ipeak(it)));
    thr = relThreshold * Speak(it);
    if ~(isfinite(thr) && thr >= 0)
        continue;
    end
    if sig(idxPeak) < thr
        continue;
    end
    iL = idxPeak;
    iR = idxPeak;
    while iL > 1 && sig(iL - 1) >= thr
        iL = iL - 1;
    end
    while iR < numel(sig) && sig(iR + 1) >= thr
        iR = iR + 1;
    end
    bandLow(it) = cur(iL);
    bandHigh(it) = cur(iR);
    bandWidth(it) = cur(iR) - cur(iL);
    bandCount(it) = iR - iL + 1;
    if iR > iL
        bandArea(it) = trapz(cur(iL:iR), sig(iL:iR));
    else
        bandArea(it) = 0;
    end
end
end

function yOut = positiveForm(y, shapeMode)
y = y(:);
if shapeMode == "positive"
    yOut = y;
else
    yOut = NaN(size(y));
end
end

function [note, penalty] = sensitivityAssessment(def, comparison, sensitivity, cfg)
note = "none";
penalty = 0;
if def.sensitivityGroup == "support_rel"
    rngVals = supportCorrelationRange(def.name, comparison, sensitivity);
    note = sprintf('support-threshold Pearson(A) range over %.2f-%.2f: %.3f to %.3f', min(cfg.supportThresholdSweep), max(cfg.supportThresholdSweep), rngVals(1), rngVals(2));
    penalty = sensitivityPenaltyFromRange(rngVals);
elseif def.sensitivityGroup == "top_rel"
    vals = corrSweep(comparison.A_interp, sensitivity.topWidth, comparison.baseMask);
    rngVals = [min(vals, [], 'omitnan'), max(vals, [], 'omitnan')];
    note = sprintf('top-threshold Pearson(A) range over %.2f-%.2f: %.3f to %.3f', min(cfg.topFractionSweep), max(cfg.topFractionSweep), rngVals(1), rngVals(2));
    penalty = sensitivityPenaltyFromRange(rngVals);
else
    note = "not threshold-based";
end
end

function rngVals = supportCorrelationRange(name, comparison, sensitivity)
switch name
    case "ridge_band_width_rel30"
        vals = corrSweep(comparison.A_interp, sensitivity.bandWidth, comparison.baseMask);
    case "ridge_supported_area_rel30"
        vals = corrSweep(comparison.A_interp, sensitivity.bandArea, comparison.baseMask);
    case "ridge_participation_count_rel30"
        vals = corrSweep(comparison.A_interp, sensitivity.participationCount, comparison.baseMask);
    otherwise
        vals = NaN(3,1);
end
rngVals = [min(vals, [], 'omitnan'), max(vals, [], 'omitnan')];
end

function vals = corrSweep(A, Ymat, maskBase)
vals = NaN(size(Ymat, 2), 1);
for i = 1:size(Ymat, 2)
    mask = maskBase & isfinite(Ymat(:, i));
    vals(i) = corrSafe(A(mask), Ymat(mask, i));
end
end

function penalty = sensitivityPenaltyFromRange(rngVals)
penalty = 0;
if all(isfinite(rngVals))
    span = rngVals(2) - rngVals(1);
    if span > 0.25
        penalty = 0.10;
    elseif span > 0.10
        penalty = 0.05;
    end
end
end

function note = physicalAssessment(def, pearsonA, spearmanA, overlap, peakDiff)
if def.observableClass == "amplitude-like" && isfinite(pearsonA) && pearsonA < 0
    note = "Anti-correlated with A(T): this mostly tracks raw switching strength, not participation.";
elseif def.observableClass == "support-like" && isfinite(pearsonA) && pearsonA > 0.4
    note = "Captures how broad or heavy the active ridge-support band is, which is a plausible switching-side participation proxy.";
elseif def.observableClass == "motion-like" && isfinite(pearsonA) && pearsonA > 0.4
    note = "Captures ridge rearrangement activity; useful if participation is tied to geometric ridge motion rather than amplitude.";
elseif def.observableClass == "asymmetry-like"
    note = "Mostly measures left-right ridge skew, so a weak match would mean participation is not governed by asymmetry alone.";
elseif isfinite(pearsonA) && pearsonA > 0
    note = "Partially tracks the relaxation window, but only one aspect of the participation picture.";
else
    note = "Does not resemble the relaxation participation window in a simple physical way.";
end
if isfinite(overlap) && isfinite(peakDiff) && overlap > 0.3 && abs(peakDiff) <= 5
    note = note + " Peak/window alignment is also reasonably close.";
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
[xs, order] = sort(x(valid));
ranks = zeros(size(xs));
i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j + 1) == xs(i)
        j = j + 1;
    end
    ranks(i:j) = mean(i:j);
    i = j + 1;
end
rValid = zeros(size(xs));
rValid(order) = ranks;
r(valid) = rValid;
end

function y = normalizePositive(x)
x = x(:);
y = NaN(size(x));
m = max(x, [], 'omitnan');
if isfinite(m) && m > 0
    y = x ./ m;
end
end

function y = normalizeSigned(x)
x = x(:);
y = NaN(size(x));
m = max(abs(x), [], 'omitnan');
if isfinite(m) && m > 0
    y = x ./ m;
end
end

function [lowT, highT, widthT, peakT] = halfmaxWindow(T, y)
T = T(:); y = y(:); lowT = NaN; highT = NaN; widthT = NaN; peakT = NaN;
mask = isfinite(T) & isfinite(y);
T = T(mask); y = y(mask);
if numel(T) < 3
    return;
end
[peakVal, idxPeak] = max(y);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end
peakT = T(idxPeak);
halfVal = 0.5 * peakVal;
leftIdx = find(y(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx)
    lowT = T(1);
elseif leftIdx == idxPeak
    lowT = T(idxPeak);
else
    lowT = crossInterp(T(leftIdx), T(leftIdx + 1), y(leftIdx) - halfVal, y(leftIdx + 1) - halfVal);
end
rightRel = find(y(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel)
    highT = T(end);
else
    rightIdx = idxPeak + rightRel - 1;
    if rightIdx == idxPeak
        highT = T(idxPeak);
    else
        highT = crossInterp(T(rightIdx - 1), T(rightIdx), y(rightIdx - 1) - halfVal, y(rightIdx) - halfVal);
    end
end
widthT = highT - lowT;
end
function out = intervalOverlap(aLow, aHigh, bLow, bHigh)
out = NaN;
if ~all(isfinite([aLow aHigh bLow bHigh]))
    return;
end
interWidth = max(0, min(aHigh, bHigh) - max(aLow, bLow));
unionWidth = max(aHigh, bHigh) - min(aLow, bLow);
if unionWidth > 0
    out = interWidth / unionWidth;
end
end

function c = corrSafe(x, y)
x = x(:); y = y(:);
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

function out = rmsDifference(x, y)
out = NaN;
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    return;
end
out = sqrt(mean((x(mask) - y(mask)).^2));
end

function x0 = crossInterp(x1, x2, y1, y2)
if ~all(isfinite([x1 x2 y1 y2]))
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1 x2]);
else
    x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
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

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end
