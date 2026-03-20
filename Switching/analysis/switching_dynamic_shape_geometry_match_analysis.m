function out = switching_dynamic_shape_geometry_match_analysis(cfg)
% switching_dynamic_shape_geometry_match_analysis
% Match the dynamic shape-mode amplitude a1(T) against geometric observables
% extracted from saved switching run outputs and the immutable S(I,T) map.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('dynamic_shape:%s | effective_obs:%s', ...
    char(source.dynamicShapeRunId), char(source.effectiveObsRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching dynamic-shape geometry-match run directory:\n%s\n', runDir);
fprintf('Dynamic shape source run: %s\n', source.dynamicShapeRunId);
fprintf('Effective-observables source run: %s\n', source.effectiveObsRunId);
fprintf('Alignment core source: %s\n', source.alignmentCorePath);

appendText(run.log_path, sprintf('[%s] switching dynamic-shape geometry match started\n', stampNow()));
appendText(run.log_path, sprintf('Dynamic shape source: %s\n', char(source.dynamicShapeRunId)));
appendText(run.log_path, sprintf('Effective-observables source: %s\n', char(source.effectiveObsRunId)));
appendText(run.log_path, sprintf('Alignment core source: %s\n', char(source.alignmentCorePath)));

ampTbl = readtable(source.dynamicAmplitudePath);
effTbl = readtable(source.effectiveObservablesPath);
core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');

ampTbl = sortrows(ampTbl, 'T_K');
effTbl = sortrows(effTbl, 'T_K');

assert(ismember('a_1', ampTbl.Properties.VariableNames), ...
    'Dynamic-shape amplitude table is missing required column a_1.');

requiredObsCols = {'I_peak_mA', 'width_mA', 'S_peak', 'asym', 'collapse_defect'};
for iCol = 1:numel(requiredObsCols)
    assert(ismember(requiredObsCols{iCol}, effTbl.Properties.VariableNames), ...
        'Effective-observables table is missing required column %s.', requiredObsCols{iCol});
end

maskA = ampTbl.T_K >= cfg.temperatureMinK & ampTbl.T_K <= cfg.temperatureMaxK;
maskE = effTbl.T_K >= cfg.temperatureMinK & effTbl.T_K <= cfg.temperatureMaxK;
ampTbl = ampTbl(maskA, :);
effTbl = effTbl(maskE, :);

tempsMap = core.temps(:);
currents = core.currents(:);
Smap = core.Smap;

[tempsCommon, iaAmp, iaEff] = intersect(ampTbl.T_K, effTbl.T_K, 'stable');
[temps, iCommon, iMap] = intersect(tempsCommon, tempsMap, 'stable');

assert(~isempty(temps), 'No common temperatures across dynamic, effective, and map sources.');

a1 = ampTbl.a_1(iaAmp(iCommon));
effAligned = effTbl(iaEff(iCommon), :);
SmapAligned = Smap(iMap, :);

finiteRows = isfinite(a1) & isfinite(effAligned.I_peak_mA) & isfinite(effAligned.width_mA) ...
    & isfinite(effAligned.S_peak);

temps = temps(finiteRows);
a1 = a1(finiteRows);
effAligned = effAligned(finiteRows, :);
SmapAligned = SmapAligned(finiteRows, :);

assert(numel(temps) >= 5, ...
    'Too few valid temperature rows for correlation analysis after alignment/filtering.');

extraTbl = computeAdditionalObservables(currents, SmapAligned, effAligned, cfg);

observablesTbl = table( ...
    temps(:), a1(:), ...
    effAligned.I_peak_mA(:), effAligned.width_mA(:), effAligned.S_peak(:), ...
    effAligned.asym(:), effAligned.collapse_defect(:), ...
    extraTbl.profile_skewness(:), extraTbl.profile_kurtosis(:), ...
    extraTbl.curvature_at_peak(:), extraTbl.tail_weight_outside_1width(:), ...
    extraTbl.peak_sharpness(:), ...
    'VariableNames', {'T_K', 'a1', 'I_peak_mA', 'width_mA', 'S_peak', ...
    'asym', 'collapse_defect', 'profile_skewness', 'profile_kurtosis', ...
    'curvature_at_peak', 'tail_weight_outside_1width', 'peak_sharpness'});

obsMeta = observableMetadata();
corrTbl = buildCorrelationTable(observablesTbl, obsMeta);

observablesPath = save_run_table(observablesTbl, ...
    'switching_dynamic_shape_geometry_observables.csv', runDir);
correlationsPath = save_run_table(corrTbl, ...
    'switching_dynamic_shape_geometry_correlations.csv', runDir);

sourceManifestTbl = table( ...
    string({'dynamic_shape_mode_amplitudes'; 'effective_observables_table'; 'alignment_core_map'}), ...
    [source.dynamicShapeRunId; source.effectiveObsRunId; source.alignmentRunId], ...
    string({source.dynamicAmplitudePath; source.effectiveObservablesPath; source.alignmentCorePath}), ...
    'VariableNames', {'source_role', 'source_run_id', 'source_file'});
sourceManifestPath = save_run_table(sourceManifestTbl, ...
    'switching_dynamic_shape_geometry_sources.csv', runDir);

figWidth = plotObservableVsA1(temps, a1, observablesTbl.width_mA, ...
    'width(T)', 'width (mA)', runDir, ...
    'switching_dynamic_shape_width_vs_a1');
figSkewness = plotObservableVsA1(temps, a1, observablesTbl.profile_skewness, ...
    'skewness(T)', 'profile skewness (dimensionless)', runDir, ...
    'switching_dynamic_shape_skewness_vs_a1');
figCurvature = plotObservableVsA1(temps, a1, observablesTbl.curvature_at_peak, ...
    'curvature(T)', 'd^2S/dI^2 at I_{peak} (P2P percent/mA^2)', runDir, ...
    'switching_dynamic_shape_curvature_vs_a1');
figTail = plotObservableVsA1(temps, a1, observablesTbl.tail_weight_outside_1width, ...
    'tail weight(T)', 'tail weight outside \pm1 width (fraction)', runDir, ...
    'switching_dynamic_shape_tail_weight_vs_a1');
figSharpness = plotObservableVsA1(temps, a1, observablesTbl.peak_sharpness, ...
    'peak sharpness(T)', '-(d^2S/dI^2)/S_{peak} at I_{peak} (1/mA^2)', runDir, ...
    'switching_dynamic_shape_peak_sharpness_vs_a1');

bestRow = corrTbl(1, :);
bestObservable = string(bestRow.observable_key(1));
bestLabel = string(bestRow.observable_label(1));
bestPearson = bestRow.pearson_r(1);
bestSpearman = bestRow.spearman_rho(1);
deformationScope = classifyDeformationScope(bestObservable);
interpretationText = physicalInterpretation(bestObservable, bestPearson);

reportText = buildReportText( ...
    source, observablesTbl, corrTbl, bestLabel, bestObservable, ...
    bestPearson, bestSpearman, deformationScope, interpretationText, ...
    figWidth, figSkewness, figCurvature, figTail, figSharpness, ...
    observablesPath, correlationsPath, sourceManifestPath, cfg);
reportPath = save_run_report(reportText, ...
    'switching_dynamic_shape_geometry_match_report.md', runDir);

appendText(run.notes_path, sprintf('Best observable = %s\n', char(bestObservable)));
appendText(run.notes_path, sprintf('Best Pearson corr(a1, obs) = %.4f\n', bestPearson));
appendText(run.notes_path, sprintf('Best Spearman corr(a1, obs) = %.4f\n', bestSpearman));
appendText(run.notes_path, sprintf('Deformation scope = %s\n', char(deformationScope)));

zipPath = buildReviewZip(runDir, 'switching_dynamic_shape_geometry_match_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching dynamic-shape geometry match complete\n', stampNow()));
appendText(run.log_path, sprintf('Observables: %s\n', observablesPath));
appendText(run.log_path, sprintf('Correlations: %s\n', correlationsPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourceManifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.bestObservable = bestObservable;
out.bestPearson = bestPearson;
out.bestSpearman = bestSpearman;
out.deformationScope = deformationScope;
out.paths = struct( ...
    'observables', string(observablesPath), ...
    'correlations', string(correlationsPath), ...
    'sources', string(sourceManifestPath), ...
    'report', string(reportPath), ...
    'zip', string(zipPath), ...
    'widthFigure', string(figWidth.png), ...
    'skewnessFigure', string(figSkewness.png), ...
    'curvatureFigure', string(figCurvature.png), ...
    'tailFigure', string(figTail.png), ...
    'sharpnessFigure', string(figSharpness.png));

fprintf('\n=== Switching dynamic-shape geometry match complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best observable: %s\n', char(bestLabel));
fprintf('Pearson corr(a1, obs): %.4f\n', bestPearson);
fprintf('Spearman corr(a1, obs): %.4f\n', bestSpearman);
fprintf('Deformation scope: %s\n', char(deformationScope));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_dynamic_shape_geometry_match');
cfg = setDefault(cfg, 'dynamicShapeRunId', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'effectiveObsRunId', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefault(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'currentSmoothWindow', 3);
cfg = setDefault(cfg, 'tailWidthMultiplier', 1.0);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.dynamicShapeRunId = string(cfg.dynamicShapeRunId);
source.effectiveObsRunId = string(cfg.effectiveObsRunId);
source.alignmentRunId = string(cfg.alignmentRunId);

source.dynamicShapeRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.dynamicShapeRunId));
source.effectiveObsRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.effectiveObsRunId));

source.dynamicAmplitudePath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_mode_amplitudes.csv');
source.dynamicSourcesPath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_sources.csv');
source.effectiveObservablesPath = fullfile(source.effectiveObsRunDir, 'tables', ...
    'switching_effective_observables_table.csv');

fallbackAlignmentCorePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.alignmentRunId), 'switching_alignment_core_data.mat');
source.alignmentCorePath = fallbackAlignmentCorePath;

if exist(source.dynamicSourcesPath, 'file') == 2
    srcTbl = readtable(source.dynamicSourcesPath);
    if all(ismember({'source_role', 'source_file'}, srcTbl.Properties.VariableNames))
        role = string(srcTbl.source_role);
        hit = find(role == "alignment_core_map", 1, 'first');
        if ~isempty(hit)
            source.alignmentCorePath = char(string(srcTbl.source_file(hit)));
            if ismember('source_run_id', srcTbl.Properties.VariableNames)
                source.alignmentRunId = string(srcTbl.source_run_id(hit));
            end
        end
    end
end

requiredFiles = { ...
    source.dynamicAmplitudePath, ...
    source.effectiveObservablesPath, ...
    source.alignmentCorePath};
for i = 1:numel(requiredFiles)
    assert(exist(requiredFiles{i}, 'file') == 2, ...
        'Required source file missing: %s', requiredFiles{i});
end
end

function tbl = computeAdditionalObservables(currents, Smap, effTbl, cfg)
nRows = height(effTbl);

skewnessVec = NaN(nRows, 1);
kurtosisVec = NaN(nRows, 1);
curvatureVec = NaN(nRows, 1);
tailWeightVec = NaN(nRows, 1);
sharpnessVec = NaN(nRows, 1);

for i = 1:nRows
    profile = double(Smap(i, :));
    valid = isfinite(currents) & isfinite(profile(:));
    if nnz(valid) < 5
        continue;
    end

    I = double(currents(valid));
    S = profile(valid);
    [I, sortIdx] = sort(I);
    S = S(sortIdx);

    smoothWindow = min(numel(S), max(1, round(cfg.currentSmoothWindow)));
    if mod(smoothWindow, 2) == 0 && smoothWindow > 1
        smoothWindow = smoothWindow - 1;
    end
    if smoothWindow > 1
        S = smoothdata(S, 'movmean', smoothWindow, 'omitnan');
    end

    baseline = min(S, [], 'omitnan');
    weights = max(S - baseline, 0);
    sumW = sum(weights, 'omitnan');
    if ~isfinite(sumW) || sumW <= eps
        weights = max(S, 0);
        sumW = sum(weights, 'omitnan');
    end
    if ~isfinite(sumW) || sumW <= eps
        continue;
    end

    Ipeak = double(effTbl.I_peak_mA(i));
    width = abs(double(effTbl.width_mA(i)));
    if ~isfinite(width) || width <= eps
        width = max(std(I, 'omitnan'), eps);
    end

    z = (I - Ipeak) ./ width;
    m2 = sum(weights .* (z .^ 2), 'omitnan') / sumW;
    if isfinite(m2) && m2 > eps
        m3 = sum(weights .* (z .^ 3), 'omitnan') / sumW;
        m4 = sum(weights .* (z .^ 4), 'omitnan') / sumW;
        skewnessVec(i) = m3 / (m2 ^ 1.5);
        kurtosisVec(i) = m4 / (m2 ^ 2);
    end

    tailMask = abs(z) > abs(cfg.tailWidthMultiplier);
    tailWeightVec(i) = sum(weights(tailMask), 'omitnan') / sumW;

    d1 = gradient(S, I);
    d2 = gradient(d1, I);
    d2AtPeak = interp1(I, d2, Ipeak, 'linear', 'extrap');
    curvatureVec(i) = d2AtPeak;

    Speak = double(effTbl.S_peak(i));
    if isfinite(Speak) && abs(Speak) > eps
        sharpnessVec(i) = -d2AtPeak / abs(Speak);
    end
end

tbl = table(skewnessVec, kurtosisVec, curvatureVec, tailWeightVec, sharpnessVec, ...
    'VariableNames', {'profile_skewness', 'profile_kurtosis', ...
    'curvature_at_peak', 'tail_weight_outside_1width', 'peak_sharpness'});
end

function meta = observableMetadata()
meta = struct( ...
    'key', { ...
    'I_peak_mA', 'width_mA', 'S_peak', 'asym', 'collapse_defect', ...
    'profile_skewness', 'profile_kurtosis', 'curvature_at_peak', ...
    'tail_weight_outside_1width', 'peak_sharpness'}, ...
    'label', { ...
    'I_{peak}(T)', 'width(T)', 'S_{peak}(T)', 'asymmetry(T)', 'collapse defect(T)', ...
    'profile skewness(T)', 'profile kurtosis(T)', 'curvature at ridge peak(T)', ...
    'tail weight outside \pm1 width(T)', 'peak sharpness(T)'}, ...
    'group', { ...
    'existing', 'existing', 'existing', 'existing', 'existing', ...
    'computed', 'computed', 'computed', 'computed', 'computed'});
end

function corrTbl = buildCorrelationTable(obsTbl, obsMeta)
nObs = numel(obsMeta);
rows = strings(nObs, 1);
labels = strings(nObs, 1);
groups = strings(nObs, 1);
pearson = NaN(nObs, 1);
spearman = NaN(nObs, 1);
nPoints = zeros(nObs, 1);

a1 = obsTbl.a1(:);
for i = 1:nObs
    key = string(obsMeta(i).key);
    y = obsTbl.(char(key));
    rows(i) = key;
    labels(i) = string(obsMeta(i).label);
    groups(i) = string(obsMeta(i).group);
    [pearson(i), nPoints(i)] = safeCorr(a1, y, 'Pearson');
    [spearman(i), ~] = safeCorr(a1, y, 'Spearman');
end

absPearson = abs(pearson);
corrTbl = table(rows, labels, groups, pearson, spearman, absPearson, nPoints, ...
    'VariableNames', {'observable_key', 'observable_label', 'observable_group', ...
    'pearson_r', 'spearman_rho', 'abs_pearson_r', 'n_points'});
corrTbl = sortrows(corrTbl, 'abs_pearson_r', 'descend', 'MissingPlacement', 'last');
corrTbl.rank_by_abs_pearson = (1:height(corrTbl))';
end

function figPaths = plotObservableVsA1(temps, a1, obs, obsName, obsYLabel, runDir, figName)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 11]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axRaw = nexttile(tl, 1);
hold(axRaw, 'on');
yyaxis(axRaw, 'left');
plot(axRaw, temps, a1, '-o', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'a_1(T)');
ylabel(axRaw, 'a_1(T) (a.u.)');
yyaxis(axRaw, 'right');
plot(axRaw, temps, obs, '-s', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', obsName);
ylabel(axRaw, obsYLabel);
xlabel(axRaw, 'Temperature (K)');
title(axRaw, sprintf('%s vs a_1(T)', obsName));
styleAxes(axRaw);
legend(axRaw, {'a_1(T)', obsName}, 'Location', 'best');
hold(axRaw, 'off');

axNorm = nexttile(tl, 2);
hold(axNorm, 'on');
plot(axNorm, temps, normalize01(a1), '-o', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'a_1(T) normalized');
plot(axNorm, temps, normalize01(obs), '-s', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', [obsName ' normalized']);
xlabel(axNorm, 'Temperature (K)');
ylabel(axNorm, 'Normalized (0 to 1)');
title(axNorm, sprintf('Normalized comparison: a_1(T) and %s', obsName));
styleAxes(axNorm);
legend(axNorm, 'Location', 'best');
hold(axNorm, 'off');

title(tl, sprintf('Shape-mode comparison: %s', obsName));
figPaths = save_run_figure(fig, figName, runDir);
close(fig);
end

function scope = classifyDeformationScope(observableKey)
key = string(observableKey);
if key == "width_mA"
    scope = "global (ridge-width dominated)";
else
    scope = "local (peak/shoulder/tail dominated)";
end
end

function textOut = physicalInterpretation(observableKey, pearsonValue)
key = string(observableKey);
r = abs(pearsonValue);
switch key
    case "width_mA"
        textOut = sprintf(['The shape mode is mainly a global dilation/compression of the ridge width. ', ...
            'This points to broad scale re-normalization of the switching profile rather than a localized profile distortion. ', ...
            '(|r| = %.3f)'], r);
    case "profile_skewness"
        textOut = sprintf(['The shape mode primarily tracks left-right imbalance near the ridge, indicating asymmetric shoulder reweighting ', ...
            'instead of a uniform width change. (|r| = %.3f)'], r);
    case "profile_kurtosis"
        textOut = sprintf(['The shape mode mainly controls peak-versus-flank concentration (tailedness), consistent with a redistribution ', ...
            'between central ridge weight and outer-current shoulders. (|r| = %.3f)'], r);
    case "curvature_at_peak"
        textOut = sprintf(['The shape mode is tied to local curvature at the ridge maximum, meaning the dominant deformation is a local ', ...
            'peak-rounding/peak-narrowing effect near I_{peak}. (|r| = %.3f)'], r);
    case "tail_weight_outside_1width"
        textOut = sprintf(['The shape mode is controlled by tail intensity outside the core ridge width, indicating redistribution between ', ...
            'the central peak and high-|I-I_{peak}| tails. (|r| = %.3f)'], r);
    case "peak_sharpness"
        textOut = sprintf(['The shape mode is dominated by normalized peak sharpness, consistent with a local stiffening/softening of the ', ...
            'ridge apex rather than global rescaling. (|r| = %.3f)'], r);
    case "asym"
        textOut = sprintf(['The shape mode best matches the asymmetry coordinate, indicating a local left-right deformation of the ridge ', ...
            'shape around I_{peak}. (|r| = %.3f)'], r);
    case "collapse_defect"
        textOut = sprintf(['The shape mode best follows collapse defect, meaning the dominant deformation corresponds to departure from ', ...
            'single-curve scaling across temperature rather than pure position/width drift. (|r| = %.3f)'], r);
    case "I_peak_mA"
        textOut = sprintf(['The shape mode couples strongest to ridge motion in current space, suggesting that geometric profile changes ', ...
            'are secondary to temperature-driven ridge displacement. (|r| = %.3f)'], r);
    case "S_peak"
        textOut = sprintf(['The shape mode is primarily amplitude-linked through S_{peak}, indicating shape mode strength follows the ', ...
            'peak switching intensity envelope across temperature. (|r| = %.3f)'], r);
    otherwise
        textOut = sprintf('The shape mode follows %s most strongly (|r| = %.3f).', key, r);
end
end

function reportText = buildReportText( ...
    source, observablesTbl, corrTbl, bestLabel, bestKey, bestPearson, bestSpearman, ...
    deformationScope, interpretationText, ...
    figWidth, figSkewness, figCurvature, figTail, figSharpness, ...
    observablesPath, correlationsPath, sourceManifestPath, cfg)

topN = min(6, height(corrTbl));
mdRank = correlationMarkdown(corrTbl(1:topN, :));

lines = strings(0, 1);
lines(end + 1) = "# Switching dynamic shape-mode geometric match report";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- Dynamic shape-mode run: `" + source.dynamicShapeRunId + "` (`a_1(T)` source).";
lines(end + 1) = "- Effective-observables run: `" + source.effectiveObsRunId + "` (`I_peak`, `width`, `S_peak`, `asym`, `collapse_defect`).";
lines(end + 1) = "- Alignment core map: `" + string(source.alignmentCorePath) + "` (`S(I,T)` source, no recomputation).";
lines(end + 1) = "- Temperature window: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end + 1) = "- Number of matched temperatures: `" + string(height(observablesTbl)) + "`.";
lines(end + 1) = "- Source manifest table: `" + string(sourceManifestPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Observable definitions used";
lines(end + 1) = "- Existing: `I_peak(T)`, `width(T)`, `S_peak(T)`, `asymmetry(T)`, `collapse defect(T)` from saved effective-observables table.";
lines(end + 1) = "- Computed from saved `S(I,T)`: profile skewness, profile kurtosis, curvature at `I_peak`, tail weight outside `\\pm1 width`, and normalized peak sharpness.";
lines(end + 1) = "";
lines(end + 1) = "## Correlation ranking (by |Pearson corr(a1, observable)|)";
lines(end + 1) = mdRank;
lines(end + 1) = "";
lines(end + 1) = "## Requested conclusions";
lines(end + 1) = "1. Best geometric match to shape mode: `" + bestLabel + "` (`" + bestKey + "`), with Pearson `r = " + sprintf('%.4f', bestPearson) + "` and Spearman `\\rho = " + sprintf('%.4f', bestSpearman) + "`.";
lines(end + 1) = "2. Global vs local deformation: **" + deformationScope + "**.";
lines(end + 1) = "3. Physical interpretation: " + interpretationText;
lines(end + 1) = "";
lines(end + 1) = "## Requested figures";
lines(end + 1) = "- width(T) vs a_1(T): `" + string(figWidth.png) + "`.";
lines(end + 1) = "- skewness(T) vs a_1(T): `" + string(figSkewness.png) + "`.";
lines(end + 1) = "- curvature(T) vs a_1(T): `" + string(figCurvature.png) + "`.";
lines(end + 1) = "- tail weight(T) vs a_1(T): `" + string(figTail.png) + "`.";
lines(end + 1) = "- peak sharpness(T) vs a_1(T): `" + string(figSharpness.png) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![width_vs_a1](../figures/switching_dynamic_shape_width_vs_a1.png)";
lines(end + 1) = "";
lines(end + 1) = "![skewness_vs_a1](../figures/switching_dynamic_shape_skewness_vs_a1.png)";
lines(end + 1) = "";
lines(end + 1) = "![curvature_vs_a1](../figures/switching_dynamic_shape_curvature_vs_a1.png)";
lines(end + 1) = "";
lines(end + 1) = "![tail_vs_a1](../figures/switching_dynamic_shape_tail_weight_vs_a1.png)";
lines(end + 1) = "";
lines(end + 1) = "![sharpness_vs_a1](../figures/switching_dynamic_shape_peak_sharpness_vs_a1.png)";
lines(end + 1) = "";
lines(end + 1) = "## Output tables";
lines(end + 1) = "- Matched observables table: `" + string(observablesPath) + "`.";
lines(end + 1) = "- Correlation ranking table: `" + string(correlationsPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: each figure has two raw curves (`a_1` and one observable) plus two normalized curves in a second panel.";
lines(end + 1) = "- legend vs colormap: explicit legends were used in all panels (`<= 2` curves/panel).";
lines(end + 1) = "- colormap used: none (line overlays only).";
lines(end + 1) = "- smoothing applied: light `movmean` smoothing along current (window = " + string(cfg.currentSmoothWindow) + ") before current-derivative based curvature/sharpness metrics.";
lines(end + 1) = "- justification: paired raw+normalized overlays make correlation strength and shape similarity visible while preserving physical units.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

function out = correlationMarkdown(corrTbl)
lines = strings(0, 1);
lines(end + 1) = "| rank | observable | Pearson r | Spearman rho | n |";
lines(end + 1) = "| --- | --- | ---: | ---: | ---: |";
for i = 1:height(corrTbl)
    lines(end + 1) = sprintf('| %d | %s | %.4f | %.4f | %d |', ...
        corrTbl.rank_by_abs_pearson(i), ...
        char(corrTbl.observable_label(i)), ...
        corrTbl.pearson_r(i), ...
        corrTbl.spearman_rho(i), ...
        corrTbl.n_points(i));
end
out = strjoin(lines, newline);
end

function [r, n] = safeCorr(x, y, corrType)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
n = nnz(mask);
if n < 3
    r = NaN;
    return;
end
if nargin < 3 || isempty(corrType) || strcmpi(corrType, 'Pearson')
    r = corr(x(mask), y(mask), 'Type', 'Pearson');
else
    r = corr(x(mask), y(mask), 'Type', corrType);
end
end

function y = normalize01(x)
x = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.2, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');
grid(ax, 'on');
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
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
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
