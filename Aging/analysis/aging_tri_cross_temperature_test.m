function out = aging_tri_cross_temperature_test(cfg)
% aging_tri_cross_temperature_test
% Cross-temperature structure audit for Aging DeltaM maps using existing
% structured-export runs and previously extracted dynamical clocks.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);
validateInputs(cfg);

cfgRun = struct();
cfgRun.runLabel = char(string(cfg.runLabel));
cfgRun.datasetName = 'aging_tri_cross_temperature_test';
cfgRun.dip_tau_source = char(string(cfg.dipTauPath));
cfgRun.fm_tau_source = char(string(cfg.fmTauPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging TRI cross-temperature test run root:\n%s\n', runDir);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Dip tau source: %s\n', cfg.dipTauPath));
appendText(runCtx.log_path, sprintf('FM tau source: %s\n', cfg.fmTauPath));

existingAnalyses = getExistingAnalysisSummary(cfg);
structuredRuns = resolveStructuredRuns(cfg);
rawData = loadStructuredRuns(structuredRuns);
commonT = buildCommonTemperatureGrid(rawData, cfg);
data = alignStructuredRuns(rawData, commonT);

dipTauTbl = loadTauTable(cfg.dipTauPath, 'tau_effective_seconds');
fmTauTbl = loadTauTable(cfg.fmTauPath, 'tau_effective_seconds');

[svdTbl, phiTbl, pairTbl, cosineTbl, l2Tbl, corrTbl, nearSummary, phiData] = ...
    computeDominantModeAnalysis(data, cfg);

[scenarioTbl, perTpTbl, perZTbl, ampTbl, scenarioModeTbl, comparisonTbl, scenarioMap] = ...
    computeMasterCurveAnalysis(data, dipTauTbl, fmTauTbl, phiData, cfg);

svdPath = save_run_table(svdTbl, 'dominant_mode_summary.csv', runDir);
phiPath = save_run_table(phiTbl, 'dominant_modes_vs_temperature.csv', runDir);
pairPath = save_run_table(pairTbl, 'phi_similarity_pairs.csv', runDir);
cosinePath = save_run_table(cosineTbl, 'phi_cosine_similarity_matrix.csv', runDir);
l2Path = save_run_table(l2Tbl, 'phi_l2_difference_matrix.csv', runDir);
corrPath = save_run_table(corrTbl, 'phi_correlation_matrix.csv', runDir);
scenarioPath = save_run_table(scenarioTbl, 'master_curve_scenario_metrics.csv', runDir);
perTpPath = save_run_table(perTpTbl, 'master_curve_per_tp_metrics.csv', runDir);
perZPath = save_run_table(perZTbl, 'master_curve_per_z_metrics.csv', runDir);
ampPath = save_run_table(ampTbl, 'master_curve_amplitudes.csv', runDir);
scenarioModePath = save_run_table(scenarioModeTbl, 'master_curve_master_modes.csv', runDir);
comparisonPath = save_run_table(comparisonTbl, 'master_curve_comparisons.csv', runDir);

figPhi = makePhiOverlayFigure(phiData);
figPhiPaths = save_run_figure(figPhi, 'phi_mode_overlays', runDir);
close(figPhi);

figSimilarity = makePhiSimilarityFigure(phiData);
figSimilarityPaths = save_run_figure(figSimilarity, 'phi_similarity_matrices', runDir);
close(figSimilarity);

figTp26 = makePhiVsReferenceFigure(svdTbl, phiData.reference_tp);
figTp26Paths = save_run_figure(figTp26, 'phi_vs_tp26_metrics', runDir);
close(figTp26);

figRank = makeRankMetricFigure(svdTbl, phiData.reference_tp);
figRankPaths = save_run_figure(figRank, 'rank1_metrics_vs_Tp', runDir);
close(figRank);

if isKey(scenarioMap, 'raw_overlap')
    figRaw = makeMasterCurveFigure(scenarioMap('raw_overlap'));
    figRawPaths = save_run_figure(figRaw, 'master_curve_attempt_raw_overlap', runDir);
    close(figRaw);
else
    figRawPaths = struct('pdf', "", 'png', "", 'fig', "");
end

if isKey(scenarioMap, 'tau_dip_native')
    figDip = makeMasterCurveFigure(scenarioMap('tau_dip_native'));
    figDipPaths = save_run_figure(figDip, 'master_curve_attempt_tau_dip', runDir);
    close(figDip);
else
    figDipPaths = struct('pdf', "", 'png', "", 'fig', "");
end

if isKey(scenarioMap, 'tau_fm_native')
    figFm = makeMasterCurveFigure(scenarioMap('tau_fm_native'));
    figFmPaths = save_run_figure(figFm, 'master_curve_attempt_tau_fm', runDir);
    close(figFm);
else
    figFmPaths = struct('pdf', "", 'png', "", 'fig', "");
end

figCompare = makeMasterMetricComparisonFigure(scenarioTbl, perTpTbl);
figComparePaths = save_run_figure(figCompare, 'master_curve_metrics_common_overlap', runDir);
close(figCompare);

reportText = buildReportText(runDir, existingAnalyses, structuredRuns, dipTauTbl, fmTauTbl, ...
    svdTbl, nearSummary, scenarioTbl, comparisonTbl, cfg);
reportPath = save_run_report(reportText, 'tri_cross_temperature_test_report.md', runDir);

zipPath = createReviewZip(runDir, cfg.reviewZipName);
appendRunNotes(runCtx.notes_path, svdTbl, nearSummary, scenarioTbl, comparisonTbl);

appendText(runCtx.log_path, sprintf('[%s] dominant-mode summary: %s\n', stampNow(), svdPath));
appendText(runCtx.log_path, sprintf('[%s] similarity pairs: %s\n', stampNow(), pairPath));
appendText(runCtx.log_path, sprintf('[%s] master-curve metrics: %s\n', stampNow(), scenarioPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] review zip: %s\n', stampNow(), zipPath));

fprintf('Aging TRI cross-temperature test complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Dominant-mode table: %s\n', svdPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.dominant_mode_summary = string(svdPath);
out.dominant_mode_vectors = string(phiPath);
out.similarity_pairs = string(pairPath);
out.scenario_metrics = string(scenarioPath);
out.per_tp_metrics = string(perTpPath);
out.per_z_metrics = string(perZPath);
out.phi_overlay_figure = string(figPhiPaths.png);
out.phi_similarity_figure = string(figSimilarityPaths.png);
out.reference_metric_figure = string(figTp26Paths.png);
out.rank_metric_figure = string(figRankPaths.png);
out.raw_overlap_figure = string(figRawPaths.png);
out.tau_dip_figure = string(figDipPaths.png);
out.tau_fm_figure = string(figFmPaths.png);
out.metric_comparison_figure = string(figComparePaths.png);
out.cosine_matrix = string(cosinePath);
out.l2_matrix = string(l2Path);
out.correlation_matrix = string(corrPath);
out.amplitude_table = string(ampPath);
out.master_mode_table = string(scenarioModePath);
out.comparison_table = string(comparisonPath);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'TRI_cross_temperature_test');
cfg = setDefault(cfg, 'tpValues', [6 10 14 18 22 26 30 34]);
cfg = setDefault(cfg, 'referenceTp', 26);
cfg = setDefault(cfg, 'nearReferenceTpValues', [22 26 30]);
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_223709_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_13_013634_aging_fm_timescale_analysis', 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefault(cfg, 'structuredRunsRoot', fullfile(repoRoot, 'results', 'aging', 'runs'));
cfg = setDefault(cfg, 'commonTemperatureCount', 400);
cfg = setDefault(cfg, 'zGridCount', 31);
cfg = setDefault(cfg, 'representativeSliceFractions', [0.15 0.50 0.85]);
cfg = setDefault(cfg, 'reviewZipName', 'TRI_cross_temperature_bundle.zip');
cfg = setDefault(cfg, 'crossTemperatureMinTp', 3);
end

function validateInputs(cfg)
assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'FM tau table not found: %s', cfg.fmTauPath);
assert(exist(cfg.structuredRunsRoot, 'dir') == 7, 'Structured-runs root not found: %s', cfg.structuredRunsRoot);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function existing = getExistingAnalysisSummary(cfg)
existing = struct([]);

existing(end + 1).run_id = "run_2026_03_11_082451_aging_shape_collapse_analysis"; %#ok<AGROW>
existing(end).scope = "Per-T_p near-separability audit and T_p = 26 K rank-1 check.";
existing(end).gap = "Did not compare dominant spatial modes phi(T) across T_p or build cross-temperature similarity matrices.";

existing(end + 1).run_id = "run_2026_03_12_223709_aging_timescale_extraction"; %#ok<AGROW>
existing(end).scope = sprintf('Extracted tau_dip(T_p) from `%s`.', cfg.dipTauPath);
existing(end).gap = "Used Dip_depth only, without testing cross-temperature map structure.";

existing(end + 1).run_id = "run_2026_03_13_013634_aging_fm_timescale_analysis"; %#ok<AGROW>
existing(end).scope = sprintf('Extracted tau_FM(T_p) from `%s` and tested FM_abs collapse.', cfg.fmTauPath);
existing(end).gap = "Did not test whether full DeltaM(T, t_w) maps share one dominant structural mode across temperatures.";

existing(end + 1).run_id = "run_2026_03_14_071151_tri_scaling_test"; %#ok<AGROW>
existing(end).scope = "Cross-temperature TRI-style audit with rank and rescaling metrics.";
existing(end).gap = "Did not export the explicit phi(T) pairwise similarity matrices or a dedicated master-curve factorization around a common spatial mode.";
end

function runs = resolveStructuredRuns(cfg)
entries = dir(fullfile(cfg.structuredRunsRoot, 'run_*_tp_*_structured_export'));
entries = entries([entries.isdir]);
names = string({entries.name});

runs = repmat(struct('Tp', NaN, 'run_id', "", 'run_dir', ""), numel(cfg.tpValues), 1);
for i = 1:numel(cfg.tpValues)
    tp = cfg.tpValues(i);
    token = sprintf('_tp_%g_structured_export', tp);
    matches = names(endsWith(names, token));
    assert(~isempty(matches), 'No structured export run found for T_p = %g K.', tp);
    matches = sort(matches);
    runId = matches(end);
    runs(i).Tp = tp;
    runs(i).run_id = runId;
    runs(i).run_dir = fullfile(cfg.structuredRunsRoot, char(runId));
end
end

function rawData = loadStructuredRuns(structuredRuns)
rawData = repmat(struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_raw', [], ...
    'tw_seconds', [], ...
    'wait_time', strings(0, 1), ...
    'M_raw', []), numel(structuredRuns), 1);

for i = 1:numel(structuredRuns)
    runDir = structuredRuns(i).run_dir;
    tTbl = readtable(fullfile(runDir, 'tables', 'T_axis.csv'));
    twTbl = readtable(fullfile(runDir, 'tables', 'tw_axis.csv'));
    mapTbl = readtable(fullfile(runDir, 'tables', 'DeltaM_map.csv'));

    T = extractFirstNumericColumn(tTbl);
    tw = twTbl.tw_seconds;
    waitTime = string(twTbl.wait_time);
    M = table2array(mapTbl);

    assert(size(M, 1) == numel(T), 'DeltaM rows do not match T axis in %s.', runDir);
    assert(size(M, 2) == numel(tw), 'DeltaM columns do not match tw axis in %s.', runDir);

    rawData(i).Tp = structuredRuns(i).Tp;
    rawData(i).run_id = string(structuredRuns(i).run_id);
    rawData(i).run_dir = string(runDir);
    rawData(i).T_raw = T(:);
    rawData(i).tw_seconds = tw(:);
    rawData(i).wait_time = waitTime(:);
    rawData(i).M_raw = M;
end
end

function commonT = buildCommonTemperatureGrid(rawData, cfg)
tMin = -inf;
tMax = inf;
for i = 1:numel(rawData)
    tMin = max(tMin, min(rawData(i).T_raw, [], 'omitnan'));
    tMax = min(tMax, max(rawData(i).T_raw, [], 'omitnan'));
end
assert(isfinite(tMin) && isfinite(tMax) && tMax > tMin, ...
    'Could not determine a common temperature interval for structured runs.');
commonT = linspace(tMin, tMax, cfg.commonTemperatureCount).';
end

function data = alignStructuredRuns(rawData, commonT)
data = repmat(struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_common', [], ...
    'tw_seconds', [], ...
    'wait_time', strings(0, 1), ...
    'M_common', []), numel(rawData), 1);

for i = 1:numel(rawData)
    MCommon = interp1(rawData(i).T_raw, rawData(i).M_raw, commonT, 'linear');

    data(i).Tp = rawData(i).Tp;
    data(i).run_id = rawData(i).run_id;
    data(i).run_dir = rawData(i).run_dir;
    data(i).T_common = commonT;
    data(i).tw_seconds = rawData(i).tw_seconds;
    data(i).wait_time = rawData(i).wait_time;
    data(i).M_common = MCommon;
end
end

function tauTbl = loadTauTable(pathStr, tauColumn)
tauTbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
for vn = {'Tp', tauColumn}
    name = vn{1};
    if ismember(name, tauTbl.Properties.VariableNames) && ~isnumeric(tauTbl.(name))
        tauTbl.(name) = str2double(erase(string(tauTbl.(name)), '"'));
    end
end
if ismember('has_fm', tauTbl.Properties.VariableNames) && ~islogical(tauTbl.has_fm)
    tauTbl.has_fm = logical(str2double(string(tauTbl.has_fm)));
end
tauTbl = sortrows(tauTbl, 'Tp');
end

function [svdTbl, phiTbl, pairTbl, cosineTbl, l2Tbl, corrTbl, nearSummary, phiData] = ...
    computeDominantModeAnalysis(data, cfg)
nTp = numel(data);
nT = numel(data(1).T_common);

tpValues = reshape([data.Tp], [], 1);
phis = nan(nT, nTp);
rows = repmat(initSvdRow(), nTp, 1);

for i = 1:nTp
    [U, S, ~] = svd(data(i).M_common, 'econ');
    s = diag(S);
    phi = U(:, 1);
    meanProfile = mean(data(i).M_common, 2, 'omitnan');
    if safeDot(phi, meanProfile) < 0
        phi = -phi;
    end

    phis(:, i) = phi;
    rows(i).Tp = data(i).Tp;
    rows(i).n_profiles = size(data(i).M_common, 2);
    rows(i).sigma1 = getSingularValue(s, 1);
    rows(i).sigma2 = getSingularValue(s, 2);
    rows(i).sigma3 = getSingularValue(s, 3);
    rows(i).sigma4 = getSingularValue(s, 4);
    rows(i).mode1_explained_variance = explainedVarianceFromSingularValues(s, 1);
    rows(i).sigma1_over_sigma2 = ratioOrNan(rows(i).sigma1, rows(i).sigma2);
    rows(i).source_run = data(i).run_id;
end

[~, refIdx] = min(abs(tpValues - cfg.referenceTp));
referenceTp = tpValues(refIdx);
referencePhi = phis(:, refIdx);
for i = 1:nTp
    if safeDot(phis(:, i), referencePhi) < 0
        phis(:, i) = -phis(:, i);
    end
end
referencePhi = phis(:, refIdx);

pairRows = repmat(initPairRow(), 0, 1);
cosineMatrix = nan(nTp, nTp);
l2Matrix = nan(nTp, nTp);
corrMatrix = nan(nTp, nTp);

for i = 1:nTp
    rows(i).cosine_to_reference = cosineSimilarity(phis(:, i), referencePhi);
    rows(i).l2_to_reference = l2Difference(phis(:, i), referencePhi);
    rows(i).correlation_to_reference = safeCorrelation(phis(:, i), referencePhi);

    for j = 1:nTp
        cosineMatrix(i, j) = cosineSimilarity(phis(:, i), phis(:, j));
        l2Matrix(i, j) = l2Difference(phis(:, i), phis(:, j));
        corrMatrix(i, j) = safeCorrelation(phis(:, i), phis(:, j));

        if j >= i
            pairRows(end + 1, 1) = struct( ... %#ok<AGROW>
                'Tp_i', tpValues(i), ...
                'Tp_j', tpValues(j), ...
                'cosine_similarity', cosineMatrix(i, j), ...
                'l2_difference', l2Matrix(i, j), ...
                'correlation_coefficient', corrMatrix(i, j));
        end
    end
end

svdTbl = sortrows(struct2table(rows), 'Tp');
pairTbl = sortrows(struct2table(pairRows), {'Tp_i', 'Tp_j'});
phiTbl = matrixToTable(phis, tpValues, 'phi', data(1).T_common);
cosineTbl = pairMatrixToTable(cosineMatrix, tpValues);
l2Tbl = pairMatrixToTable(l2Matrix, tpValues);
corrTbl = pairMatrixToTable(corrMatrix, tpValues);

nearMask = pairTbl.Tp_i < pairTbl.Tp_j & ...
    ismember(pairTbl.Tp_i, cfg.nearReferenceTpValues) & ...
    ismember(pairTbl.Tp_j, cfg.nearReferenceTpValues);
farMask = pairTbl.Tp_i < pairTbl.Tp_j & ~nearMask;

nearSummary = struct();
nearSummary.reference_tp = referenceTp;
nearSummary.near_tp_values = cfg.nearReferenceTpValues(:).';
nearSummary.mean_near_cosine = mean(pairTbl.cosine_similarity(nearMask), 'omitnan');
nearSummary.mean_far_cosine = mean(pairTbl.cosine_similarity(farMask), 'omitnan');
nearSummary.mean_near_l2 = mean(pairTbl.l2_difference(nearMask), 'omitnan');
nearSummary.mean_far_l2 = mean(pairTbl.l2_difference(farMask), 'omitnan');
nearSummary.mean_near_correlation = mean(pairTbl.correlation_coefficient(nearMask), 'omitnan');
nearSummary.mean_far_correlation = mean(pairTbl.correlation_coefficient(farMask), 'omitnan');
nearSummary.best_neighbor_row = bestReferenceNeighbor(pairTbl, referenceTp);

phiData = struct();
phiData.T_common = data(1).T_common;
phiData.tp_values = tpValues;
phiData.phi_matrix = phis;
phiData.reference_tp = referenceTp;
phiData.reference_index = refIdx;
phiData.reference_phi = referencePhi;
phiData.cosine_matrix = cosineMatrix;
phiData.l2_matrix = l2Matrix;
phiData.correlation_matrix = corrMatrix;
end

function row = initSvdRow()
row = struct( ...
    'Tp', NaN, ...
    'n_profiles', NaN, ...
    'sigma1', NaN, ...
    'sigma2', NaN, ...
    'sigma3', NaN, ...
    'sigma4', NaN, ...
    'mode1_explained_variance', NaN, ...
    'sigma1_over_sigma2', NaN, ...
    'cosine_to_reference', NaN, ...
    'l2_to_reference', NaN, ...
    'correlation_to_reference', NaN, ...
    'source_run', "");
end

function row = initPairRow()
row = struct( ...
    'Tp_i', NaN, ...
    'Tp_j', NaN, ...
    'cosine_similarity', NaN, ...
    'l2_difference', NaN, ...
    'correlation_coefficient', NaN);
end

function bestRow = bestReferenceNeighbor(pairTbl, referenceTp)
bestRow = [];
mask = pairTbl.Tp_i < pairTbl.Tp_j & (pairTbl.Tp_i == referenceTp | pairTbl.Tp_j == referenceTp);
sub = pairTbl(mask, :);
if isempty(sub)
    return;
end
sub = sortrows(sub, {'cosine_similarity', 'correlation_coefficient'}, {'descend', 'descend'});
bestRow = sub(1, :);
end

function tbl = matrixToTable(matrixValues, tpValues, columnPrefix, TCommon)
varNames = cellstr(matlab.lang.makeValidName(compose('%s_tp_%g', columnPrefix, tpValues)));
tbl = array2table(matrixValues, 'VariableNames', varNames);
tbl = addvars(tbl, TCommon(:), 'Before', 1, 'NewVariableNames', 'T_K');
end

function tbl = pairMatrixToTable(matrixValues, tpValues)
varNames = cellstr(matlab.lang.makeValidName(compose('Tp_%g', tpValues)));
tbl = array2table(matrixValues, 'VariableNames', varNames);
tbl = addvars(tbl, tpValues(:), 'Before', 1, 'NewVariableNames', 'Tp');
end

function [scenarioTbl, perTpTbl, perZTbl, ampTbl, scenarioModeTbl, comparisonTbl, scenarioMap] = ...
    computeMasterCurveAnalysis(data, dipTauTbl, fmTauTbl, phiData, cfg)
allTp = sort([data.Tp]);
dipTp = sort(intersect(allTp, finiteTauTp(dipTauTbl, 'tau_effective_seconds', false)));
fmTp = sort(intersect(allTp, finiteTauTp(fmTauTbl, 'tau_effective_seconds', true)));
overlapTp = sort(intersect(dipTp, fmTp));

scenarioDefs = {
    'raw_all',        'Raw t_w (all T_p)',          allTp,     'raw'
    'raw_dip_native', 'Raw t_w (dip coverage)',     dipTp,     'raw'
    'tau_dip_native', '\tau_{dip}(T_p)',            dipTp,     'dip'
    'raw_fm_native',  'Raw t_w (FM coverage)',      fmTp,      'raw'
    'tau_fm_native',  '\tau_{FM}(T_p)',             fmTp,      'fm'
    'raw_overlap',    'Raw t_w (common overlap)',   overlapTp, 'raw'
    'tau_dip_overlap','\tau_{dip}(T_p) overlap',    overlapTp, 'dip'
    'tau_fm_overlap', '\tau_{FM}(T_p) overlap',     overlapTp, 'fm'
    };

scenarios = cell(0, 1);
for i = 1:size(scenarioDefs, 1)
    tpValues = scenarioDefs{i, 3};
    if numel(tpValues) < cfg.crossTemperatureMinTp
        continue;
    end
    scenarios{end + 1, 1} = evaluateMasterCurveScenario( ... %#ok<AGROW>
        data, tpValues, scenarioDefs{i, 1}, scenarioDefs{i, 2}, scenarioDefs{i, 4}, ...
        dipTauTbl, fmTauTbl, phiData, cfg);
end

scenarioRows = repmat(initScenarioRow(), 0, 1);
perTpRows = repmat(initMasterPerTpRow(), 0, 1);
perZRows = repmat(initMasterPerZRow(), 0, 1);
ampRows = repmat(initAmplitudeRow(), 0, 1);
scenarioMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(scenarios)
    scenario = scenarios{i};
    scenarioRows(end + 1, 1) = scenario.summaryRow; %#ok<AGROW>
    perTpRows = [perTpRows; scenario.perTpRows]; %#ok<AGROW>
    perZRows = [perZRows; scenario.perZRows]; %#ok<AGROW>
    ampRows = [ampRows; scenario.amplitudeRows]; %#ok<AGROW>
    scenarioMap(char(scenario.name)) = scenario;
end

scenarioTbl = sortrows(struct2table(scenarioRows), 'scenario_name');
perTpTbl = sortrows(struct2table(perTpRows), {'scenario_name', 'Tp'});
perZTbl = sortrows(struct2table(perZRows), {'scenario_name', 'z_scaled'});
ampTbl = sortrows(struct2table(ampRows), {'scenario_name', 'Tp', 'z_scaled'});
scenarioModeTbl = buildScenarioModeTable(scenarios, phiData.T_common);
comparisonTbl = buildMasterComparisonTable(scenarioTbl);
end

function row = initScenarioRow()
row = struct( ...
    'scenario_name', "", ...
    'scenario_label', "", ...
    'tau_source', "", ...
    'tp_values', "", ...
    'n_tp', NaN, ...
    'z_min', NaN, ...
    'z_max', NaN, ...
    'n_z', NaN, ...
    'mean_pairwise_rmse_scaled', NaN, ...
    'mean_relative_residual', NaN, ...
    'median_relative_residual', NaN, ...
    'mean_profile_correlation', NaN, ...
    'mean_raw_mode1_explained_variance', NaN, ...
    'mean_scaled_mode1_explained_variance', NaN, ...
    'stack_mode1_explained_variance', NaN, ...
    'scaled_stack_mode1_explained_variance', NaN, ...
    'mean_amplitude_cv', NaN, ...
    'master_cosine_to_reference', NaN, ...
    'master_l2_to_reference', NaN, ...
    'master_correlation_to_reference', NaN);
end

function row = initMasterPerTpRow()
row = struct( ...
    'scenario_name', "", ...
    'tau_source', "", ...
    'Tp', NaN, ...
    'n_z_contributing', NaN, ...
    'mean_relative_residual', NaN, ...
    'mean_scaled_rmse_to_master', NaN, ...
    'mean_profile_correlation', NaN, ...
    'mean_amplitude_coefficient', NaN, ...
    'source_run', "");
end

function row = initMasterPerZRow()
row = struct( ...
    'scenario_name', "", ...
    'tau_source', "", ...
    'z_scaled', NaN, ...
    'mean_pairwise_rmse_scaled', NaN, ...
    'mean_relative_residual', NaN, ...
    'mean_profile_correlation', NaN, ...
    'raw_mode1_explained_variance', NaN, ...
    'scaled_mode1_explained_variance', NaN, ...
    'amplitude_cv', NaN);
end

function row = initAmplitudeRow()
row = struct( ...
    'scenario_name', "", ...
    'tau_source', "", ...
    'Tp', NaN, ...
    'z_scaled', NaN, ...
    'amplitude_coefficient', NaN);
end

function scenario = evaluateMasterCurveScenario(data, tpValues, name, label, tauSource, dipTauTbl, fmTauTbl, phiData, cfg)
selected = data(ismember([data.Tp], tpValues));
selected = sortStructByField(selected, 'Tp');
tauValues = resolveTauVector(selected, tauSource, dipTauTbl, fmTauTbl);

logZMin = -inf;
logZMax = inf;
for i = 1:numel(selected)
    logZ = log10(selected(i).tw_seconds ./ tauValues(i));
    logZMin = max(logZMin, min(logZ, [], 'omitnan'));
    logZMax = min(logZMax, max(logZ, [], 'omitnan'));
end
assert(isfinite(logZMin) && isfinite(logZMax) && logZMax > logZMin, ...
    'No common scaled-time overlap for scenario %s.', name);

logZGrid = linspace(logZMin, logZMax, cfg.zGridCount);
zGrid = 10 .^ logZGrid;
interpProfiles = cell(numel(selected), 1);
for i = 1:numel(selected)
    logZ = log10(selected(i).tw_seconds ./ tauValues(i));
    interpProfiles{i} = interp1(logZ, selected(i).M_common.', logZGrid, 'linear', NaN).';
end

stackMatrix = [];
for i = 1:numel(interpProfiles)
    stackMatrix = [stackMatrix, interpProfiles{i}]; %#ok<AGROW>
end
stackMatrix = stackMatrix(:, all(isfinite(stackMatrix), 1));

[UStack, ~, ~] = svd(stackMatrix, 'econ');
phiMaster = UStack(:, 1);
if safeDot(phiMaster, phiData.reference_phi) < 0
    phiMaster = -phiMaster;
end
phiMaster = phiMaster ./ max(norm(phiMaster), eps);

nTp = numel(selected);
nZ = numel(zGrid);
nT = numel(phiMaster);

scaledProfiles = cell(nTp, 1);
for i = 1:nTp
    scaledProfiles{i} = nan(nT, nZ);
end

amplitudeMatrix = nan(nTp, nZ);
residualMatrix = nan(nTp, nZ);
rmseToMasterMatrix = nan(nTp, nZ);
corrMatrix = nan(nTp, nZ);
pairwiseRmseScaled = nan(nZ, 1);
meanResidualByZ = nan(nZ, 1);
meanCorrByZ = nan(nZ, 1);
rawMode1Ev = nan(nZ, 1);
scaledMode1Ev = nan(nZ, 1);
ampCv = nan(nZ, 1);

perZRows = repmat(initMasterPerZRow(), nZ, 1);
amplitudeRows = repmat(initAmplitudeRow(), 0, 1);

for k = 1:nZ
    stackRaw = nan(nT, nTp);
    stackScaled = nan(nT, nTp);
    amplitudeVals = nan(nTp, 1);
    residualVals = nan(nTp, 1);
    corrVals = nan(nTp, 1);
    rmseToMasterVals = nan(nTp, 1);

    for i = 1:nTp
        profile = interpProfiles{i}(:, k);
        stackRaw(:, i) = profile;
        valid = isfinite(profile) & isfinite(phiMaster);
        coeff = sum(phiMaster(valid) .* profile(valid), 'omitnan') ./ ...
            max(sum(phiMaster(valid) .^ 2, 'omitnan'), eps);
        recon = coeff .* phiMaster;

        amplitudeVals(i) = coeff;
        residualVals(i) = norm(profile(valid) - recon(valid)) ./ max(norm(profile(valid)), eps);
        corrVals(i) = safeCorrelation(profile(valid), recon(valid));

        if isfinite(coeff) && abs(coeff) > eps
            scaledProfiles{i}(:, k) = profile ./ coeff;
            stackScaled(:, i) = scaledProfiles{i}(:, k);
            rmseToMasterVals(i) = sqrt(mean((scaledProfiles{i}(valid, k) - phiMaster(valid)) .^ 2, 'omitnan'));
        end

        amplitudeMatrix(i, k) = coeff;
        residualMatrix(i, k) = residualVals(i);
        rmseToMasterMatrix(i, k) = rmseToMasterVals(i);
        corrMatrix(i, k) = corrVals(i);

        amplitudeRows(end + 1, 1) = struct( ... %#ok<AGROW>
            'scenario_name', string(name), ...
            'tau_source', string(tauSource), ...
            'Tp', selected(i).Tp, ...
            'z_scaled', zGrid(k), ...
            'amplitude_coefficient', coeff);
    end

    pairwiseRmseScaled(k) = mean(computePairwiseProfileRmse(stackScaled), 'omitnan');
    meanResidualByZ(k) = mean(residualVals, 'omitnan');
    meanCorrByZ(k) = mean(corrVals, 'omitnan');
    rawMode1Ev(k) = mode1ExplainedVariance(stackRaw);
    scaledMode1Ev(k) = mode1ExplainedVariance(stackScaled);
    ampCv(k) = safeCoefficientVariation(amplitudeVals);

    perZRows(k).scenario_name = string(name);
    perZRows(k).tau_source = string(tauSource);
    perZRows(k).z_scaled = zGrid(k);
    perZRows(k).mean_pairwise_rmse_scaled = pairwiseRmseScaled(k);
    perZRows(k).mean_relative_residual = meanResidualByZ(k);
    perZRows(k).mean_profile_correlation = meanCorrByZ(k);
    perZRows(k).raw_mode1_explained_variance = rawMode1Ev(k);
    perZRows(k).scaled_mode1_explained_variance = scaledMode1Ev(k);
    perZRows(k).amplitude_cv = ampCv(k);
end

scaledStackMatrix = [];
for i = 1:nTp
    scaledStackMatrix = [scaledStackMatrix, scaledProfiles{i}]; %#ok<AGROW>
end
scaledStackMatrix = scaledStackMatrix(:, all(isfinite(scaledStackMatrix), 1));

perTpRows = repmat(initMasterPerTpRow(), nTp, 1);
for i = 1:nTp
    perTpRows(i).scenario_name = string(name);
    perTpRows(i).tau_source = string(tauSource);
    perTpRows(i).Tp = selected(i).Tp;
    perTpRows(i).n_z_contributing = nZ;
    perTpRows(i).mean_relative_residual = mean(residualMatrix(i, :), 'omitnan');
    perTpRows(i).mean_scaled_rmse_to_master = mean(rmseToMasterMatrix(i, :), 'omitnan');
    perTpRows(i).mean_profile_correlation = mean(corrMatrix(i, :), 'omitnan');
    perTpRows(i).mean_amplitude_coefficient = mean(amplitudeMatrix(i, :), 'omitnan');
    perTpRows(i).source_run = selected(i).run_id;
end

summaryRow = initScenarioRow();
summaryRow.scenario_name = string(name);
summaryRow.scenario_label = string(label);
summaryRow.tau_source = string(tauSource);
summaryRow.tp_values = join(string([selected.Tp]), ';');
summaryRow.n_tp = nTp;
summaryRow.z_min = zGrid(1);
summaryRow.z_max = zGrid(end);
summaryRow.n_z = nZ;
summaryRow.mean_pairwise_rmse_scaled = mean(pairwiseRmseScaled, 'omitnan');
summaryRow.mean_relative_residual = mean(residualMatrix(:), 'omitnan');
summaryRow.median_relative_residual = median(residualMatrix(:), 'omitnan');
summaryRow.mean_profile_correlation = mean(corrMatrix(:), 'omitnan');
summaryRow.mean_raw_mode1_explained_variance = mean(rawMode1Ev, 'omitnan');
summaryRow.mean_scaled_mode1_explained_variance = mean(scaledMode1Ev, 'omitnan');
summaryRow.stack_mode1_explained_variance = mode1ExplainedVariance(stackMatrix);
summaryRow.scaled_stack_mode1_explained_variance = mode1ExplainedVariance(scaledStackMatrix);
summaryRow.mean_amplitude_cv = mean(ampCv, 'omitnan');
summaryRow.master_cosine_to_reference = cosineSimilarity(phiMaster, phiData.reference_phi);
summaryRow.master_l2_to_reference = l2Difference(phiMaster, phiData.reference_phi);
summaryRow.master_correlation_to_reference = safeCorrelation(phiMaster, phiData.reference_phi);

repIdx = representativeIndices(nZ, cfg.representativeSliceFractions);

scenario = struct();
scenario.name = string(name);
scenario.label = string(label);
scenario.tau_source = string(tauSource);
scenario.tp_values = [selected.Tp];
scenario.z_grid = zGrid(:);
scenario.log_z_grid = logZGrid(:);
scenario.selected = selected;
scenario.tau_values = tauValues(:);
scenario.interp_profiles = interpProfiles;
scenario.scaled_profiles = scaledProfiles;
scenario.phi_master = phiMaster;
scenario.per_z_metrics = struct2table(perZRows);
scenario.summaryRow = summaryRow;
scenario.perTpRows = perTpRows;
scenario.perZRows = perZRows;
scenario.amplitudeRows = amplitudeRows;
scenario.rep_indices = repIdx;
end

function tpValues = finiteTauTp(tauTbl, tauColumn, requireHasFm)
mask = isfinite(tauTbl.(tauColumn)) & tauTbl.(tauColumn) > 0;
if requireHasFm && ismember('has_fm', tauTbl.Properties.VariableNames)
    mask = mask & logical(tauTbl.has_fm);
end
tpValues = tauTbl.Tp(mask).';
end

function selected = sortStructByField(selected, fieldName)
[~, order] = sort([selected.(fieldName)]);
selected = selected(order);
end

function tauValues = resolveTauVector(selected, tauSource, dipTauTbl, fmTauTbl)
tauValues = nan(numel(selected), 1);
for i = 1:numel(selected)
    tp = selected(i).Tp;
    switch lower(char(tauSource))
        case 'raw'
            tauValues(i) = 1;
        case 'dip'
            tauValues(i) = lookupTau(dipTauTbl, tp);
        case 'fm'
            tauValues(i) = lookupTau(fmTauTbl, tp);
        otherwise
            error('Unsupported tau source: %s', tauSource);
    end
end
assert(all(isfinite(tauValues) & tauValues > 0), ...
    'Scenario contains non-finite or non-positive tau values.');
end

function tauValue = lookupTau(tauTbl, tp)
mask = abs(tauTbl.Tp - tp) < 1e-9;
assert(any(mask), 'Could not find tau entry for T_p = %g K.', tp);
tauValue = tauTbl.tau_effective_seconds(find(mask, 1, 'first'));
end

function tbl = buildScenarioModeTable(scenarios, TCommon)
tbl = table(TCommon(:), 'VariableNames', {'T_K'});
for i = 1:numel(scenarios)
    name = matlab.lang.makeValidName(sprintf('phi_master_%s', char(scenarios{i}.name)));
    tbl.(name) = scenarios{i}.phi_master(:);
end
end

function comparisonTbl = buildMasterComparisonTable(scenarioTbl)
comparisonDefs = {
    'tau_dip_native', 'raw_dip_native'
    'tau_fm_native',  'raw_fm_native'
    'tau_dip_overlap','raw_overlap'
    'tau_fm_overlap', 'raw_overlap'
    };

rows = repmat(initComparisonRow(), 0, 1);
for i = 1:size(comparisonDefs, 1)
    scenarioName = string(comparisonDefs{i, 1});
    baselineName = string(comparisonDefs{i, 2});
    scenarioRow = scenarioTbl(string(scenarioTbl.scenario_name) == scenarioName, :);
    baselineRow = scenarioTbl(string(scenarioTbl.scenario_name) == baselineName, :);
    if isempty(scenarioRow) || isempty(baselineRow)
        continue;
    end

    rows(end + 1, 1) = struct( ... %#ok<AGROW>
        'scenario_name', scenarioName, ...
        'baseline_name', baselineName, ...
        'relative_residual_improvement_pct', percentReduction( ...
            baselineRow.mean_relative_residual, scenarioRow.mean_relative_residual), ...
        'pairwise_rmse_improvement_pct', percentReduction( ...
            baselineRow.mean_pairwise_rmse_scaled, scenarioRow.mean_pairwise_rmse_scaled), ...
        'amplitude_cv_improvement_pct', percentReduction( ...
            baselineRow.mean_amplitude_cv, scenarioRow.mean_amplitude_cv), ...
        'scaled_stack_mode1_ev_delta', ...
            scenarioRow.scaled_stack_mode1_explained_variance - baselineRow.scaled_stack_mode1_explained_variance, ...
        'master_correlation_delta', ...
            scenarioRow.master_correlation_to_reference - baselineRow.master_correlation_to_reference);
end

comparisonTbl = sortrows(struct2table(rows), 'scenario_name');
end

function row = initComparisonRow()
row = struct( ...
    'scenario_name', "", ...
    'baseline_name', "", ...
    'relative_residual_improvement_pct', NaN, ...
    'pairwise_rmse_improvement_pct', NaN, ...
    'amplitude_cv_improvement_pct', NaN, ...
    'scaled_stack_mode1_ev_delta', NaN, ...
    'master_correlation_delta', NaN);
end

function fig = makePhiOverlayFigure(phiData)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.8]);
ax = axes(fig);
hold(ax, 'on');

tpValues = phiData.tp_values(:);
cmap = parula(256);
tMin = min(tpValues);
tMax = max(tpValues);

for i = 1:numel(tpValues)
    colorValue = interpolateColor(tpValues(i), tMin, tMax, cmap);
    plot(ax, phiData.T_common, phiData.phi_matrix(:, i), '-', ...
        'Color', colorValue, 'LineWidth', 1.8);
end

plot(ax, phiData.T_common, phiData.reference_phi, '--', ...
    'Color', [0.05 0.05 0.05], 'LineWidth', 2.4);

xlabel(ax, 'Temperature (K)');
ylabel(ax, '\phi(T) (normalized)');
title(ax, 'Dominant spatial mode \phi(T) across stopping temperatures');
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
ylim(ax, paddedLimits(phiData.phi_matrix(:)));
colormap(ax, cmap);
clim(ax, [tMin, tMax]);
cb = colorbar(ax);
cb.Label.String = 'T_p (K)';
end

function fig = makePhiSimilarityFigure(phiData)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.8]);
tlo = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plotSimilarityHeatmap(ax1, phiData.tp_values, phiData.cosine_matrix, ...
    [0 1], 'Cosine similarity');

ax2 = nexttile(tlo, 2);
plotSimilarityHeatmap(ax2, phiData.tp_values, phiData.l2_matrix, ...
    [], 'L_2 difference');

ax3 = nexttile(tlo, 3);
plotSimilarityHeatmap(ax3, phiData.tp_values, phiData.correlation_matrix, ...
    [-1 1], 'Correlation coefficient');

title(tlo, 'Cross-temperature similarity of dominant spatial modes');
end

function plotSimilarityHeatmap(ax, tpValues, matrixValues, climits, cbLabel)
imagesc(ax, tpValues, tpValues, matrixValues);
axis(ax, 'xy');
colormap(ax, parula(256));
if ~isempty(climits)
    clim(ax, climits);
end
cb = colorbar(ax);
cb.Label.String = cbLabel;
xlabel(ax, 'T_p (K)');
ylabel(ax, 'T_p (K)');
title(ax, cbLabel);
set(ax, 'FontSize', 8, 'LineWidth', 1, 'Box', 'on');
end

function fig = makePhiVsReferenceFigure(svdTbl, referenceTp)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.8]);
tlo = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plotMetricToReference(ax1, svdTbl.Tp, svdTbl.cosine_to_reference, referenceTp, ...
    'Cosine to \phi_{ref}', 'Cosine similarity');

ax2 = nexttile(tlo, 2);
plotMetricToReference(ax2, svdTbl.Tp, svdTbl.l2_to_reference, referenceTp, ...
    'L_2 to \phi_{ref}', 'L_2 difference');

ax3 = nexttile(tlo, 3);
plotMetricToReference(ax3, svdTbl.Tp, svdTbl.correlation_to_reference, referenceTp, ...
    'Corr(\phi, \phi_{ref})', 'Correlation coefficient');

title(tlo, sprintf('Similarity to the dominant mode at T_p = %.0f K', referenceTp));
end

function plotMetricToReference(ax, x, y, referenceTp, yLabel, titleText)
plot(ax, x, y, '-o', 'Color', [0 0.4470 0.7410], ...
    'MarkerFaceColor', [0 0.4470 0.7410], 'LineWidth', 1.8, 'MarkerSize', 5);
hold(ax, 'on');
highlightTp(ax, x, y, referenceTp);
xlabel(ax, 'T_p (K)');
ylabel(ax, yLabel);
title(ax, titleText);
grid(ax, 'on');
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
end

function fig = makeRankMetricFigure(svdTbl, referenceTp)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.4]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plot(ax1, svdTbl.Tp, svdTbl.mode1_explained_variance, '-o', ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'LineWidth', 1.8, 'MarkerSize', 5);
hold(ax1, 'on');
highlightTp(ax1, svdTbl.Tp, svdTbl.mode1_explained_variance, referenceTp);
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Mode-1 explained variance');
title(ax1, 'Single-mode dominance');
ylim(ax1, [0 1.02]);
grid(ax1, 'on');
set(ax1, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

ax2 = nexttile(tlo, 2);
plot(ax2, svdTbl.Tp, log10(svdTbl.sigma1_over_sigma2), '-s', ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'LineWidth', 1.8, 'MarkerSize', 5);
hold(ax2, 'on');
highlightTp(ax2, svdTbl.Tp, log10(svdTbl.sigma1_over_sigma2), referenceTp);
xlabel(ax2, 'T_p (K)');
ylabel(ax2, 'log_{10}(\sigma_1 / \sigma_2)');
title(ax2, 'Rank separation');
grid(ax2, 'on');
set(ax2, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

title(tlo, 'Rank-1 diagnostics for M(T, t_w)');
end

function fig = makeMasterCurveFigure(scenario)
nTiles = numel(scenario.rep_indices);
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.2]);
tlo = tiledlayout(fig, 1, nTiles, 'TileSpacing', 'compact', 'Padding', 'compact');

nCurves = numel(scenario.selected);
useColorbar = nCurves > 5;

if useColorbar
    cmap = parula(256);
    tMin = min(scenario.tp_values);
    tMax = max(scenario.tp_values);
else
    cmap = lines(max(nCurves, 1));
    tMin = 0;
    tMax = 1;
end

for tileIdx = 1:nTiles
    k = scenario.rep_indices(tileIdx);
    ax = nexttile(tlo, tileIdx);
    hold(ax, 'on');
    values = scenario.phi_master;

    for i = 1:nCurves
        if useColorbar
            colorValue = interpolateColor(scenario.selected(i).Tp, tMin, tMax, cmap);
            displayName = '';
        else
            colorValue = cmap(i, :);
            displayName = sprintf('T_p = %.0f K', scenario.selected(i).Tp);
        end

        plot(ax, scenario.selected(i).T_common, scenario.scaled_profiles{i}(:, k), '-', ...
            'Color', colorValue, 'LineWidth', 1.5, 'DisplayName', displayName);
        values = [values; scenario.scaled_profiles{i}(:, k)]; %#ok<AGROW>
    end

    plot(ax, scenario.selected(1).T_common, scenario.phi_master, '--', ...
        'Color', [0.05 0.05 0.05], 'LineWidth', 2.2, 'DisplayName', 'Master mode');

    xlabel(ax, 'Temperature (K)');
    ylabel(ax, '\DeltaM / a(z)');
    title(ax, sprintf('z = %.3g, <r> = %.3f', ...
        scenario.z_grid(k), scenario.per_z_metrics.mean_relative_residual(k)));
    ylim(ax, paddedLimits(values));
    grid(ax, 'on');
    set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

    if ~useColorbar && tileIdx == nTiles
        lg = legend(ax, 'Location', 'eastoutside');
        lg.Box = 'off';
    end
end

if useColorbar
    colormap(fig, cmap);
    cb = colorbar(nexttile(tlo, nTiles));
    cb.Label.String = 'T_p (K)';
    clim([tMin, tMax]);
end

title(tlo, sprintf('Amplitude-scaled master-curve slices under %s', char(scenario.label)));
end

function fig = makeMasterMetricComparisonFigure(scenarioTbl, perTpTbl)
overlapTbl = scenarioTbl(ismember(string(scenarioTbl.scenario_name), ...
    ["raw_overlap", "tau_dip_overlap", "tau_fm_overlap"]), :);
order = ["raw_overlap", "tau_dip_overlap", "tau_fm_overlap"];
overlapTbl = reorderScenarioTable(overlapTbl, order);

fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 12.0]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
bar(ax1, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.mean_pairwise_rmse_scaled, ...
    'FaceColor', [0 0.4470 0.7410]);
xlabel(ax1, 'Scenario');
ylabel(ax1, 'Mean pairwise RMSE');
title(ax1, 'Shape mismatch after amplitude scaling');
grid(ax1, 'on');
set(ax1, 'FontSize', 8, 'LineWidth', 1, 'Box', 'off');

ax2 = nexttile(tlo, 2);
bar(ax2, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.mean_relative_residual, ...
    'FaceColor', [0.8500 0.3250 0.0980]);
xlabel(ax2, 'Scenario');
ylabel(ax2, 'Mean relative residual');
title(ax2, 'Residual to the common master mode');
grid(ax2, 'on');
set(ax2, 'FontSize', 8, 'LineWidth', 1, 'Box', 'off');

ax3 = nexttile(tlo, 3);
bar(ax3, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.scaled_stack_mode1_explained_variance, ...
    'FaceColor', [0.00 0.62 0.45]);
xlabel(ax3, 'Scenario');
ylabel(ax3, 'Scaled stack mode-1 variance');
ylim(ax3, [0 1.02]);
title(ax3, 'Single-mode strength after amplitude removal');
grid(ax3, 'on');
set(ax3, 'FontSize', 8, 'LineWidth', 1, 'Box', 'off');

ax4 = nexttile(tlo, 4);
hold(ax4, 'on');
plotPerTpScenario(ax4, perTpTbl, 'raw_overlap', 'raw', [0.3 0.3 0.3], 'o');
plotPerTpScenario(ax4, perTpTbl, 'tau_dip_overlap', '\tau_{dip}', [0 0.4470 0.7410], 's');
plotPerTpScenario(ax4, perTpTbl, 'tau_fm_overlap', '\tau_{FM}', [0.8500 0.3250 0.0980], '^');
xlabel(ax4, 'T_p (K)');
ylabel(ax4, 'Mean relative residual');
title(ax4, 'Per-T_p residual on the common overlap set');
grid(ax4, 'on');
set(ax4, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax4, 'Location', 'best', 'Box', 'off');

title(tlo, 'Cross-temperature master-curve metrics on the common overlap set');
end

function tbl = reorderScenarioTable(tbl, order)
key = strings(height(tbl), 1);
for i = 1:height(tbl)
    key(i) = string(find(order == string(tbl.scenario_name(i)), 1, 'first'));
end
tbl.order_key = str2double(key);
tbl = sortrows(tbl, 'order_key');
tbl.order_key = [];
end

function labels = shortScenarioLabels(names)
labels = strings(size(names));
for i = 1:numel(names)
    switch string(names(i))
        case "raw_overlap"
            labels(i) = "raw";
        case "tau_dip_overlap"
            labels(i) = "tau_dip";
        case "tau_fm_overlap"
            labels(i) = "tau_FM";
        otherwise
            labels(i) = string(names(i));
    end
end
end

function plotPerTpScenario(ax, perTpTbl, scenarioName, labelText, colorValue, markerSymbol)
sub = perTpTbl(string(perTpTbl.scenario_name) == string(scenarioName), :);
if isempty(sub)
    return;
end
sub = sortrows(sub, 'Tp');
plot(ax, sub.Tp, sub.mean_relative_residual, ['-' markerSymbol], ...
    'Color', colorValue, 'MarkerFaceColor', colorValue, ...
    'LineWidth', 1.6, 'MarkerSize', 5, 'DisplayName', labelText);
end

function reportText = buildReportText(runDir, existingAnalyses, structuredRuns, dipTauTbl, fmTauTbl, ...
    svdTbl, nearSummary, scenarioTbl, comparisonTbl, cfg)
lines = strings(0, 1);
lines(end + 1) = '# Aging TRI cross-temperature structure test';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', string(runDir));
lines(end + 1) = '';
lines(end + 1) = '## Repository scan summary';
lines(end + 1) = '- I checked the existing Aging runs and analyses before creating this run.';
for i = 1:numel(existingAnalyses)
    lines(end + 1) = sprintf('- `%s`: %s %s', existingAnalyses(i).run_id, ...
        existingAnalyses(i).scope, existingAnalyses(i).gap);
end
lines(end + 1) = '- Conclusion of the scan: the repository already contained partial ingredients for this question, but not one dedicated run that exported the phi(T) similarity matrices and the master-mode factorization requested here.';
lines(end + 1) = '';

lines(end + 1) = '## Inputs';
for i = 1:numel(structuredRuns)
    lines(end + 1) = sprintf('- Structured map: `T_p = %.0f K` -> `%s`', ...
        structuredRuns(i).Tp, structuredRuns(i).run_id);
end
lines(end + 1) = sprintf('- Dip clock source: `%s`', cfg.dipTauPath);
lines(end + 1) = sprintf('- FM clock source: `%s`', cfg.fmTauPath);
lines(end + 1) = sprintf('- Finite `tau_dip` coverage: `%s K`.', ...
    join(string(dipTauTbl.Tp(isfinite(dipTauTbl.tau_effective_seconds)).'), ';'));
lines(end + 1) = sprintf('- Finite `tau_FM` coverage: `%s K`.', ...
    join(string(fmTauTbl.Tp(isfinite(fmTauTbl.tau_effective_seconds) & fmTauTbl.has_fm).'), ';'));
lines(end + 1) = '';

lines(end + 1) = '## Methods';
lines(end + 1) = '- Each structured-export DeltaM(T, t_w) map was interpolated onto the shared temperature interval common to all selected T_p runs.';
lines(end + 1) = '- For each T_p, I recomputed the SVD of the aligned matrix and took the dominant spatial mode `phi(T) = u_1(T)` after fixing the arbitrary sign against the T_p = 26 K reference mode.';
lines(end + 1) = '- Cross-temperature phi(T) similarity was quantified by cosine similarity, L_2 difference, and correlation coefficient.';
lines(end + 1) = '- For the master-curve test, I formed the scaled time `z = t_w / tau(T_p)`, interpolated each map onto a common z grid, extracted one best common spatial mode from the stacked profiles, and fitted amplitudes `a(z)` by projection onto that mode.';
lines(end + 1) = '- Collapse quality was summarized by the mean profile residual to the common mode, pairwise RMSE after amplitude scaling, mode-1 explained variance of the stacked profiles, and the spread of fitted amplitudes across T_p at fixed z.';
lines(end + 1) = '';

bestRank = bestFiniteRow(svdTbl, 'mode1_explained_variance', 'descend');
tpRefRow = svdTbl(abs(svdTbl.Tp - nearSummary.reference_tp) < 1e-9, :);
bestNeighbor = nearSummary.best_neighbor_row;

lines(end + 1) = '## Dominant spatial mode phi(T)';
if ~isempty(bestRank)
    lines(end + 1) = sprintf('- The strongest single-mode map occurs at `T_p = %.0f K`, with mode-1 explained variance `%.4f` and `sigma_1 / sigma_2 = %.3f`.', ...
        bestRank.Tp, bestRank.mode1_explained_variance, bestRank.sigma1_over_sigma2);
end
if ~isempty(tpRefRow)
    lines(end + 1) = sprintf('- At `T_p = %.0f K`, the map remains strongly rank-1 with mode-1 explained variance `%.4f` and `sigma_1 / sigma_2 = %.3f`.', ...
        nearSummary.reference_tp, tpRefRow.mode1_explained_variance, tpRefRow.sigma1_over_sigma2);
end
if ~isempty(bestNeighbor)
    neighborTp = bestNeighbor.Tp_i;
    if abs(neighborTp - nearSummary.reference_tp) < 1e-9
        neighborTp = bestNeighbor.Tp_j;
    end
    lines(end + 1) = sprintf('- The closest dominant mode to `T_p = %.0f K` is at `T_p = %.0f K`, with cosine similarity `%.4f`, correlation `%.4f`, and L_2 difference `%.4f`.', ...
        nearSummary.reference_tp, neighborTp, bestNeighbor.cosine_similarity, ...
        bestNeighbor.correlation_coefficient, bestNeighbor.l2_difference);
end
lines(end + 1) = sprintf('- Averaging only the near-peak set `%s K`, the pairwise phi(T) metrics are cosine `%.4f`, correlation `%.4f`, and L_2 `%.4f`.', ...
    join(string(nearSummary.near_tp_values), ';'), nearSummary.mean_near_cosine, ...
    nearSummary.mean_near_correlation, nearSummary.mean_near_l2);
lines(end + 1) = sprintf('- For the remaining cross-temperature pairs, the corresponding averages are cosine `%.4f`, correlation `%.4f`, and L_2 `%.4f`.', ...
    nearSummary.mean_far_cosine, nearSummary.mean_far_correlation, nearSummary.mean_far_l2);
if isfinite(nearSummary.mean_near_cosine) && isfinite(nearSummary.mean_far_cosine)
    if nearSummary.mean_near_cosine > nearSummary.mean_far_cosine
        lines(end + 1) = '- The dominant spatial mode is more self-consistent in the neighborhood of 26 K than across the full T_p sweep, but the effect is quantitative rather than exact universality.';
    else
        lines(end + 1) = '- The dominant spatial mode near 26 K is not more self-consistent than the rest of the sweep, so there is no special universality window in these metrics.';
    end
end
lines(end + 1) = '';

rawOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "raw_overlap", :);
dipOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_overlap", :);
fmOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_overlap", :);
dipNative = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_native", :);
fmNative = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_native", :);
dipCompare = comparisonTbl(string(comparisonTbl.scenario_name) == "tau_dip_overlap", :);
fmCompare = comparisonTbl(string(comparisonTbl.scenario_name) == "tau_fm_overlap", :);

lines(end + 1) = '## Master-curve test';
if ~isempty(rawOverlap)
    lines(end + 1) = sprintf('- On the common overlap set `%s K`, the raw-time baseline gives mean residual `%.4f`, mean pairwise RMSE `%.4f`, and scaled-stack mode-1 explained variance `%.4f`.', ...
        rawOverlap.tp_values, rawOverlap.mean_relative_residual, rawOverlap.mean_pairwise_rmse_scaled, ...
        rawOverlap.scaled_stack_mode1_explained_variance);
end
if ~isempty(dipOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `tau_dip(T_p)` gives mean residual `%.4f`, mean pairwise RMSE `%.4f`, and scaled-stack mode-1 explained variance `%.4f`.', ...
        dipOverlap.mean_relative_residual, dipOverlap.mean_pairwise_rmse_scaled, ...
        dipOverlap.scaled_stack_mode1_explained_variance);
end
if ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `tau_FM(T_p)` gives mean residual `%.4f`, mean pairwise RMSE `%.4f`, and scaled-stack mode-1 explained variance `%.4f`.', ...
        fmOverlap.mean_relative_residual, fmOverlap.mean_pairwise_rmse_scaled, ...
        fmOverlap.scaled_stack_mode1_explained_variance);
end
if ~isempty(dipCompare)
    lines(end + 1) = sprintf('- Relative to raw time on the overlap set, `tau_dip` changes the mean residual by `%.2f%%`, the pairwise RMSE by `%.2f%%`, and the scaled stack mode-1 variance by `%.4f`.', ...
        dipCompare.relative_residual_improvement_pct, dipCompare.pairwise_rmse_improvement_pct, ...
        dipCompare.scaled_stack_mode1_ev_delta);
end
if ~isempty(fmCompare)
    lines(end + 1) = sprintf('- Relative to raw time on the overlap set, `tau_FM` changes the mean residual by `%.2f%%`, the pairwise RMSE by `%.2f%%`, and the scaled stack mode-1 variance by `%.4f`.', ...
        fmCompare.relative_residual_improvement_pct, fmCompare.pairwise_rmse_improvement_pct, ...
        fmCompare.scaled_stack_mode1_ev_delta);
end
if ~isempty(dipNative)
    lines(end + 1) = sprintf('- On its native coverage `%s K`, the dip-clock master mode has cosine `%.4f` to `phi(T)` at 26 K and mean amplitude-spread metric `%.4f`.', ...
        dipNative.tp_values, dipNative.master_cosine_to_reference, dipNative.mean_amplitude_cv);
end
if ~isempty(fmNative)
    lines(end + 1) = sprintf('- On its native coverage `%s K`, the FM-clock master mode has cosine `%.4f` to `phi(T)` at 26 K and mean amplitude-spread metric `%.4f`.', ...
        fmNative.tp_values, fmNative.master_cosine_to_reference, fmNative.mean_amplitude_cv);
end
lines(end + 1) = '';

lines(end + 1) = '## Interpretation';
lines(end + 1) = buildInterpretationLine(nearSummary, rawOverlap, dipOverlap, fmOverlap);
lines(end + 1) = '- The structural evidence is stronger than a scalar Dip-depth collapse test because it uses the full DeltaM(T, t_w) map, but it is still limited by the sparse waiting-time grid and by missing low-T_p FM and high-T_p Dip clocks.';
lines(end + 1) = '';

lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- `phi_mode_overlays`: 8 curves, so a `parula` colormap plus labeled colorbar is used; no smoothing.';
lines(end + 1) = '- `phi_similarity_matrices`: 3 heatmaps with labeled colorbars; no smoothing or interpolation beyond matrix display.';
lines(end + 1) = '- `phi_vs_tp26_metrics` and `rank1_metrics_vs_Tp`: one curve per panel, explicit markers, no colormap, no smoothing.';
lines(end + 1) = '- `master_curve_attempt_raw_overlap`: 4 curves plus the common master mode, explicit legend, no smoothing.';
lines(end + 1) = '- `master_curve_attempt_tau_dip` and `master_curve_attempt_tau_fm`: 6 ordered curves, so color encodes T_p and the shared master mode is shown as a dashed black reference.';
lines(end + 1) = '- `master_curve_metrics_common_overlap`: overlap-only summary bars plus a per-T_p residual comparison; no smoothing.';
lines(end + 1) = '';

lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/dominant_mode_summary.csv`';
lines(end + 1) = '- `tables/dominant_modes_vs_temperature.csv`';
lines(end + 1) = '- `tables/phi_similarity_pairs.csv`';
lines(end + 1) = '- `tables/phi_cosine_similarity_matrix.csv`';
lines(end + 1) = '- `tables/phi_l2_difference_matrix.csv`';
lines(end + 1) = '- `tables/phi_correlation_matrix.csv`';
lines(end + 1) = '- `tables/master_curve_scenario_metrics.csv`';
lines(end + 1) = '- `tables/master_curve_per_tp_metrics.csv`';
lines(end + 1) = '- `tables/master_curve_per_z_metrics.csv`';
lines(end + 1) = '- `tables/master_curve_amplitudes.csv`';
lines(end + 1) = '- `tables/master_curve_master_modes.csv`';
lines(end + 1) = '- `tables/master_curve_comparisons.csv`';
lines(end + 1) = '- `figures/phi_mode_overlays.png`';
lines(end + 1) = '- `figures/phi_similarity_matrices.png`';
lines(end + 1) = '- `figures/phi_vs_tp26_metrics.png`';
lines(end + 1) = '- `figures/rank1_metrics_vs_Tp.png`';
lines(end + 1) = '- `figures/master_curve_attempt_raw_overlap.png`';
lines(end + 1) = '- `figures/master_curve_attempt_tau_dip.png`';
lines(end + 1) = '- `figures/master_curve_attempt_tau_fm.png`';
lines(end + 1) = '- `figures/master_curve_metrics_common_overlap.png`';
lines(end + 1) = '- `reports/tri_cross_temperature_test_report.md`';
lines(end + 1) = '- `review/TRI_cross_temperature_bundle.zip`';

reportText = strjoin(lines, newline);
end

function line = buildInterpretationLine(nearSummary, rawOverlap, dipOverlap, fmOverlap)
nearUniversal = isfinite(nearSummary.mean_near_cosine) && isfinite(nearSummary.mean_far_cosine) && ...
    nearSummary.mean_near_cosine > nearSummary.mean_far_cosine && ...
    nearSummary.mean_near_correlation > nearSummary.mean_far_correlation;
dipImproves = ~isempty(rawOverlap) && ~isempty(dipOverlap) && ...
    dipOverlap.mean_relative_residual < rawOverlap.mean_relative_residual && ...
    dipOverlap.mean_pairwise_rmse_scaled < rawOverlap.mean_pairwise_rmse_scaled;
fmImproves = ~isempty(rawOverlap) && ~isempty(fmOverlap) && ...
    fmOverlap.mean_relative_residual < rawOverlap.mean_relative_residual && ...
    fmOverlap.mean_pairwise_rmse_scaled < rawOverlap.mean_pairwise_rmse_scaled;

if nearUniversal && dipImproves
    line = '- Around 26 K, the dominant spatial mode becomes more coherent than it is globally, and the Dip-derived clock improves the cross-temperature master-curve metrics. That is consistent with a limited one-clock structural collapse near the relaxation peak, but not with an exact universal master curve across the entire sweep.';
elseif nearUniversal
    line = '- Around 26 K, the dominant spatial mode is somewhat more coherent than it is globally, but the tested clocks do not convert that into a strong master-curve collapse. The data therefore support local structural similarity more than true temperature-independent universality.';
elseif dipImproves || fmImproves
    line = '- Time rescaling improves some master-curve metrics, but the dominant spatial mode itself is not especially universal near 26 K. That points to partial phenomenological alignment rather than a single structural mode taking over around the peak.';
else
    line = '- Neither the dominant-mode comparisons nor the rescaled master-curve metrics support a strong cross-temperature universal structure. The data look closer to a family of related but non-identical response shapes than to one shared master mode.';
end
end

function appendRunNotes(notesPath, svdTbl, nearSummary, scenarioTbl, comparisonTbl)
fid = fopen(notesPath, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

bestRank = bestFiniteRow(svdTbl, 'mode1_explained_variance', 'descend');
rawOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "raw_overlap", :);
dipOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_overlap", :);
fmOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_overlap", :);
dipCompare = comparisonTbl(string(comparisonTbl.scenario_name) == "tau_dip_overlap", :);
fmCompare = comparisonTbl(string(comparisonTbl.scenario_name) == "tau_fm_overlap", :);

if ~isempty(bestRank)
    fprintf(fid, 'Best rank-1 map: T_p = %.0f K, EV1 = %.4f\n', ...
        bestRank.Tp, bestRank.mode1_explained_variance);
end
fprintf(fid, 'Near-26 phi(T) cosine mean = %.4f, far-pair cosine mean = %.4f\n', ...
    nearSummary.mean_near_cosine, nearSummary.mean_far_cosine);
if ~isempty(rawOverlap)
    fprintf(fid, 'Raw overlap residual = %.4f, RMSE = %.4f\n', ...
        rawOverlap.mean_relative_residual, rawOverlap.mean_pairwise_rmse_scaled);
end
if ~isempty(dipOverlap)
    fprintf(fid, 'tau_dip overlap residual = %.4f, RMSE = %.4f\n', ...
        dipOverlap.mean_relative_residual, dipOverlap.mean_pairwise_rmse_scaled);
end
if ~isempty(fmOverlap)
    fprintf(fid, 'tau_FM overlap residual = %.4f, RMSE = %.4f\n', ...
        fmOverlap.mean_relative_residual, fmOverlap.mean_pairwise_rmse_scaled);
end
if ~isempty(dipCompare)
    fprintf(fid, 'tau_dip overlap residual improvement = %.2f%%\n', ...
        dipCompare.relative_residual_improvement_pct);
end
if ~isempty(fmCompare)
    fprintf(fid, 'tau_FM overlap residual improvement = %.2f%%\n', ...
        fmCompare.relative_residual_improvement_pct);
end
end

function zipPath = createReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function values = extractFirstNumericColumn(tbl)
values = table2array(tbl(:, 1));
if ~isnumeric(values)
    values = str2double(string(values));
end
end

function value = getSingularValue(values, idx)
if idx <= numel(values)
    value = values(idx);
else
    value = NaN;
end
end

function value = explainedVarianceFromSingularValues(s, idx)
value = NaN;
if isempty(s) || idx > numel(s)
    return;
end
energy = s .^ 2;
value = energy(idx) ./ max(sum(energy, 'omitnan'), eps);
end

function value = ratioOrNan(num, denom)
if isfinite(num) && isfinite(denom) && abs(denom) > eps
    value = num ./ denom;
else
    value = NaN;
end
end

function value = safeDot(x, y)
valid = isfinite(x) & isfinite(y);
if ~any(valid)
    value = 0;
else
    value = sum(x(valid) .* y(valid), 'omitnan');
end
end

function value = cosineSimilarity(x, y)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if isempty(x)
    value = NaN;
    return;
end
denom = norm(x) * norm(y);
if denom <= eps
    value = NaN;
else
    value = sum(x .* y) ./ denom;
end
end

function value = l2Difference(x, y)
valid = isfinite(x) & isfinite(y);
if ~any(valid)
    value = NaN;
else
    value = norm(x(valid) - y(valid));
end
end

function values = computePairwiseProfileRmse(M)
nProfiles = size(M, 2);
if nProfiles < 2
    values = NaN;
    return;
end
values = nan(nchoosek(nProfiles, 2), 1);
cursor = 0;
for i = 1:(nProfiles - 1)
    for j = (i + 1):nProfiles
        cursor = cursor + 1;
        delta = M(:, i) - M(:, j);
        values(cursor) = sqrt(mean(delta .^ 2, 'omitnan'));
    end
end
values = values(1:cursor);
end

function value = mode1ExplainedVariance(M)
validCols = all(isfinite(M), 1);
M = M(:, validCols);
if isempty(M)
    value = NaN;
    return;
end
[~, S, ~] = svd(M, 'econ');
s = diag(S);
value = explainedVarianceFromSingularValues(s, 1);
end

function idx = representativeIndices(nValues, fractions)
idx = round(1 + fractions(:) .* (nValues - 1));
idx = unique(min(max(idx, 1), nValues));
if numel(idx) < 3 && nValues >= 3
    idx = unique([1; round((nValues + 1) / 2); nValues]);
end
end

function r = safeCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 2
    r = NaN;
    return;
end
x = x - mean(x);
y = y - mean(y);
denom = sqrt(sum(x .^ 2) * sum(y .^ 2));
if denom <= eps
    r = NaN;
else
    r = sum(x .* y) ./ denom;
end
end

function cv = safeCoefficientVariation(values)
valid = isfinite(values);
values = values(valid);
if numel(values) < 2
    cv = NaN;
    return;
end
denom = mean(abs(values), 'omitnan');
if denom <= eps
    cv = NaN;
else
    cv = std(values, 0, 'omitnan') ./ denom;
end
end

function colorValue = interpolateColor(value, minValue, maxValue, cmap)
if maxValue <= minValue
    colorValue = cmap(1, :);
    return;
end
alpha = (value - minValue) ./ (maxValue - minValue);
alpha = min(max(alpha, 0), 1);
idx = 1 + round(alpha .* (size(cmap, 1) - 1));
colorValue = cmap(idx, :);
end

function row = bestFiniteRow(tbl, fieldName, direction)
row = [];
if isempty(tbl)
    return;
end
valid = isfinite(tbl.(fieldName));
if ~any(valid)
    return;
end
sub = tbl(valid, :);
sub = sortrows(sub, fieldName, direction);
row = sub(1, :);
end

function highlightTp(ax, x, y, targetTp)
mask = abs(x - targetTp) < 1e-9;
if any(mask)
    plot(ax, x(mask), y(mask), 'o', 'Color', [0.20 0.20 0.20], ...
        'MarkerFaceColor', [1 0.85 0.2], 'MarkerSize', 7, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
end
end

function lims = paddedLimits(values)
values = values(isfinite(values));
if isempty(values)
    lims = [0, 1];
    return;
end
vMin = min(values);
vMax = max(values);
if abs(vMax - vMin) < 1e-12
    pad = max(abs(vMax), 1) * 0.1;
else
    pad = 0.08 * (vMax - vMin);
end
lims = [vMin - pad, vMax + pad];
end

function pct = percentReduction(beforeVal, afterVal)
if ~(isfinite(beforeVal) && isfinite(afterVal))
    pct = NaN;
    return;
end
pct = 100 * (1 - afterVal ./ max(beforeVal, eps));
end

function appendText(pathStr, textStr)
fid = fopen(pathStr, 'a');
if fid < 0
    error('Could not open %s for append.', pathStr);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textStr);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
