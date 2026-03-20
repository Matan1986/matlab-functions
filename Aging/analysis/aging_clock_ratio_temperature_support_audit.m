function out = aging_clock_ratio_temperature_support_audit(cfg)
% aging_clock_ratio_temperature_support_audit
% Audit temperature inclusion logic for R(Tp) = tau_FM(Tp) / tau_dip(Tp).
%
% This analysis is read-only with respect to prior runs: it reuses existing
% run outputs and writes a new canonical run under results/aging/runs.

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
assert(exist(cfg.datasetPath, 'file') == 2, 'Dataset not found: %s', cfg.datasetPath);
assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'FM tau table not found: %s', cfg.fmTauPath);

runCfg = struct();
runCfg.runLabel = char(string(cfg.runLabel));
runCfg.dataset = sprintf('dataset:%s | dip:%s | fm:%s', ...
    char(string(cfg.datasetRunName)), char(string(cfg.dipRunName)), char(string(cfg.fmRunName)));
run = createRunContext('aging', runCfg);
runDir = run.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging clock-ratio temperature-support audit run root:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] aging_clock_ratio_temperature_support_audit started\n', stampNow()));
appendText(run.log_path, sprintf('datasetPath: %s\n', cfg.datasetPath));
appendText(run.log_path, sprintf('dipTauPath: %s\n', cfg.dipTauPath));
appendText(run.log_path, sprintf('fmTauPath: %s\n', cfg.fmTauPath));

datasetTbl = readNumericTable(cfg.datasetPath);
datasetTbl = normalizeDatasetTable(datasetTbl);

dipTauTbl = readNumericTable(cfg.dipTauPath);
dipTauTbl = normalizeTauTable(dipTauTbl);

fmTauTbl = readNumericTable(cfg.fmTauPath);
fmTauTbl = normalizeFmTauTable(fmTauTbl);

collapseTbl = table();
if exist(cfg.rescalingTauPath, 'file') == 2
    collapseTbl = readNumericTable(cfg.rescalingTauPath);
    collapseTbl = normalizeCollapseTauTable(collapseTbl);
end

preprocMetricsTbl = table();
if exist(cfg.decompositionRawPath, 'file') == 2
    decompRawTbl = readNumericTable(cfg.decompositionRawPath);
    preprocMetricsTbl = computePreprocessingSensitivity(decompRawTbl);
end

classTbl = buildClassificationTable(datasetTbl, dipTauTbl, fmTauTbl, collapseTbl, preprocMetricsTbl, cfg);
classTbl = sortrows(classTbl, 'Tp');

canonicalSupportTbl = classTbl(classTbl.canonical_R_support, :);
exploratoryFullSupportTbl = classTbl(classTbl.canonical_R_support | classTbl.exploratory_full_tau_support, :);
censoredTbl = classTbl(classTbl.censored_only_support, :);

classPath = save_run_table(classTbl, 'temperature_classification_table.csv', runDir);
canonicalPath = save_run_table(canonicalSupportTbl, 'canonical_R_support_table.csv', runDir);
explorPath = save_run_table(exploratoryFullSupportTbl, 'exploratory_extended_R_support_table.csv', runDir);
censoredPath = save_run_table(censoredTbl, 'censored_support_table.csv', runDir);

figVisibility = makeDipVisibilityFigure(datasetTbl, classTbl);
figVisibilityPaths = save_run_figure(figVisibility, 'dip_visibility_vs_tw_by_Tp', runDir);
close(figVisibility);

figExtraction = makeExtractionDiagnosticsFigure(classTbl);
figExtractionPaths = save_run_figure(figExtraction, 'tau_dip_extraction_diagnostics_vs_Tp', runDir);
close(figExtraction);

figHighT = makeHighTDiagnosticsFigure(datasetTbl, classTbl, preprocMetricsTbl, cfg.focusTemperaturesK);
figHighTPaths = save_run_figure(figHighT, 'highT_window_and_censoring_diagnostics', runDir);
close(figHighT);

reportText = buildReportText(runDir, cfg, classTbl, canonicalSupportTbl, exploratoryFullSupportTbl, censoredTbl, preprocMetricsTbl);
reportPath = save_run_report(reportText, 'aging_clock_ratio_temperature_support_audit_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_clock_ratio_temperature_support_audit_bundle.zip');

appendText(run.log_path, sprintf('[%s] classification table: %s\n', stampNow(), classPath));
appendText(run.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(run.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));
appendText(run.notes_path, sprintf('Canonical R support: %s K\n', fmtTpList(canonicalSupportTbl.Tp)));
appendText(run.notes_path, sprintf('Exploratory extended support (full tau): %s K\n', ...
    fmtTpList(exploratoryFullSupportTbl.Tp)));
appendText(run.notes_path, sprintf('Censored-only temperatures: %s K\n', ...
    fmtTpList(censoredTbl.Tp)));

fprintf('Audit complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Classification table: %s\n', classPath);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.classificationTable = classTbl;
out.canonicalSupportTable = canonicalSupportTbl;
out.exploratorySupportTable = exploratoryFullSupportTbl;
out.censoredTable = censoredTbl;
out.classificationPath = string(classPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'dip_visibility', string(figVisibilityPaths.png), ...
    'tau_diagnostics', string(figExtractionPaths.png), ...
    'highT', string(figHighTPaths.png));
out.extraTables = struct( ...
    'canonical', string(canonicalPath), ...
    'exploratory', string(explorPath), ...
    'censored', string(censoredPath));
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'clock_ratio_temperature_support_audit');
cfg = setDefault(cfg, 'datasetRunName', 'run_2026_03_12_211204_aging_dataset_build');
cfg = setDefault(cfg, 'dipRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefault(cfg, 'fmRunName', 'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefault(cfg, 'rescalingRunName', 'run_2026_03_12_233710_aging_time_rescaling_collapse');
cfg = setDefault(cfg, 'datasetPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.datasetRunName)), 'tables', 'aging_observable_dataset.csv'));
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.dipRunName)), 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.fmRunName)), 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefault(cfg, 'rescalingTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.rescalingRunName)), 'tables', 'tau_rescaling_estimates.csv'));
cfg = setDefault(cfg, 'decompositionRawPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_legacy_decomposition_stability', 'tables', 'decomposition_stability_raw.csv'));

cfg = setDefault(cfg, 'unstableSpreadThresholdDecades', 0.60);
cfg = setDefault(cfg, 'preprocSensitivityFractionThreshold', 0.40);
cfg = setDefault(cfg, 'modelAgreementThresholdDecades', 0.50);
cfg = setDefault(cfg, 'focusTemperaturesK', [30 34]);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    p = fullfile(runDir, char(folderName));
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
end

function tbl = readNumericTable(pathStr)
tbl = readtable(pathStr, 'Delimiter', ',', 'ReadVariableNames', true, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
tbl = standardizeColumnNames(tbl);
tbl = normalizeNumericColumns(tbl);
end

function tbl = standardizeColumnNames(tbl)
vns = tbl.Properties.VariableNames;
newNames = vns;
for i = 1:numel(vns)
    name = erase(string(vns{i}), '"');
    name = regexprep(name, '[^A-Za-z0-9_]', '');
    if strlength(name) == 0
        name = "col_" + string(i);
    end
    firstChar = char(extractBefore(name + " ", 2));
    if ~isempty(firstChar) && isstrprop(firstChar(1), 'digit')
        name = "v_" + name;
    end
    newNames{i} = char(name);
end
tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings(newNames);
end

function tbl = normalizeNumericColumns(tbl)
for i = 1:numel(tbl.Properties.VariableNames)
    vn = tbl.Properties.VariableNames{i};
    if isnumeric(tbl.(vn)) || islogical(tbl.(vn))
        continue;
    end
    values = str2double(erase(string(tbl.(vn)), '"'));
    raw = string(tbl.(vn));
    isMissingLike = ismissing(raw) | strcmpi(strtrim(raw), "NaN") | strlength(strtrim(raw)) == 0;
    if all(isfinite(values) | isMissingLike)
        tbl.(vn) = values;
    else
        tbl.(vn) = string(tbl.(vn));
    end
end
end

function tbl = normalizeDatasetTable(tbl)
required = {'Tp', 'tw', 'Dip_depth'};
missing = required(~ismember(required, tbl.Properties.VariableNames));
assert(isempty(missing), 'Dataset missing columns: %s', strjoin(missing, ', '));
if ~ismember('FM_abs', tbl.Properties.VariableNames)
    tbl.FM_abs = nan(height(tbl), 1);
end
if ~ismember('source_run', tbl.Properties.VariableNames)
    tbl.source_run = repmat("", height(tbl), 1);
else
    tbl.source_run = string(tbl.source_run);
end
tbl = sortrows(tbl, {'Tp', 'tw'});
end

function tbl = normalizeTauTable(tbl)
required = {'Tp', 'tau_effective_seconds'};
missing = required(~ismember(required, tbl.Properties.VariableNames));
assert(isempty(missing), 'Dip tau table missing columns: %s', strjoin(missing, ', '));
if ~ismember('tau_half_range_status', tbl.Properties.VariableNames)
    tbl.tau_half_range_status = repmat("", height(tbl), 1);
else
    tbl.tau_half_range_status = string(tbl.tau_half_range_status);
end
if ~ismember('tau_logistic_status', tbl.Properties.VariableNames)
    tbl.tau_logistic_status = repmat("", height(tbl), 1);
else
    tbl.tau_logistic_status = string(tbl.tau_logistic_status);
end
if ~ismember('tau_stretched_status', tbl.Properties.VariableNames)
    tbl.tau_stretched_status = repmat("", height(tbl), 1);
else
    tbl.tau_stretched_status = string(tbl.tau_stretched_status);
end
if ~ismember('tau_method_spread_decades', tbl.Properties.VariableNames)
    tbl.tau_method_spread_decades = nan(height(tbl), 1);
end
if ~ismember('fragile_low_point_count', tbl.Properties.VariableNames)
    tbl.fragile_low_point_count = false(height(tbl), 1);
end
if ~ismember('tau_logistic_trusted', tbl.Properties.VariableNames)
    tbl.tau_logistic_trusted = false(height(tbl), 1);
end
if ~ismember('tau_stretched_trusted', tbl.Properties.VariableNames)
    tbl.tau_stretched_trusted = false(height(tbl), 1);
end
tbl = sortrows(tbl, 'Tp');
end

function tbl = normalizeFmTauTable(tbl)
required = {'Tp', 'tau_effective_seconds'};
missing = required(~ismember(required, tbl.Properties.VariableNames));
assert(isempty(missing), 'FM tau table missing columns: %s', strjoin(missing, ', '));
tbl = sortrows(tbl, 'Tp');
end

function tbl = normalizeCollapseTauTable(tbl)
if ismember('Tp', tbl.Properties.VariableNames) && ismember('tau_estimate_seconds', tbl.Properties.VariableNames)
    tbl = sortrows(tbl, 'Tp');
else
    tbl = table();
end
end

function preprocTbl = computePreprocessingSensitivity(rawTbl)
required = {'Tp', 'setting_id', 'wait_time', 'Dip_depth'};
if ~all(ismember(required, rawTbl.Properties.VariableNames))
    preprocTbl = table();
    return;
end

rawTbl.tw_seconds = waitLabelToSeconds(rawTbl.wait_time);

tpValues = unique(rawTbl.Tp(isfinite(rawTbl.Tp)), 'sorted');
rows = repmat(struct( ...
    'Tp', NaN, ...
    'preproc_setting_count', 0, ...
    'preproc_peak_at_first_fraction', NaN, ...
    'preproc_half_range_ok_fraction', NaN, ...
    'preproc_tau_median_seconds', NaN, ...
    'preproc_tau_iqr_decades', NaN), 0, 1);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = rawTbl(rawTbl.Tp == tp, :);
    valid = isfinite(sub.tw_seconds) & sub.tw_seconds > 0 & isfinite(sub.Dip_depth);
    sub = sub(valid, :);
    if isempty(sub)
        continue;
    end

    settingIds = unique(string(sub.setting_id));
    nSettings = numel(settingIds);
    peakFirst = false(nSettings, 1);
    halfOk = false(nSettings, 1);
    tauVals = nan(nSettings, 1);

    for k = 1:nSettings
        sid = settingIds(k);
        g = sub(string(sub.setting_id) == sid, :);
        g = sortrows(g, 'tw_seconds');
        t = g.tw_seconds(:);
        y = g.Dip_depth(:);
        [~, peakIdx] = max(y, [], 'omitnan');
        if isempty(peakIdx) || ~isfinite(peakIdx)
            peakIdx = NaN;
        end
        peakFirst(k) = isfinite(peakIdx) && peakIdx == 1;
        half = estimateUpwardCrossing(t, y, 0.50);
        halfOk(k) = (half.status == "ok");
        tauVals(k) = half.tau_seconds;
    end

    logTau = log10(tauVals(halfOk & isfinite(tauVals) & tauVals > 0));
    iqrDec = NaN;
    if numel(logTau) >= 2
        q = quantile(logTau, [0.25 0.75]);
        iqrDec = q(2) - q(1);
    end

    row = struct();
    row.Tp = tp;
    row.preproc_setting_count = nSettings;
    row.preproc_peak_at_first_fraction = mean(peakFirst, 'omitnan');
    row.preproc_half_range_ok_fraction = mean(halfOk, 'omitnan');
    row.preproc_tau_median_seconds = median(tauVals(halfOk), 'omitnan');
    row.preproc_tau_iqr_decades = iqrDec;
    rows(end + 1, 1) = row; %#ok<AGROW>
end

preprocTbl = struct2table(rows);
preprocTbl = sortrows(preprocTbl, 'Tp');
end

function tw = waitLabelToSeconds(waitLabels)
labels = strtrim(string(waitLabels));
tw = nan(size(labels));
for i = 1:numel(labels)
    token = labels(i);
    if strlength(token) == 0 || ismissing(token)
        continue;
    end
    if endsWith(token, "s", 'IgnoreCase', true)
        numPart = strtrim(extractBefore(token, strlength(token)));
        tw(i) = str2double(numPart);
        continue;
    end
    if contains(lower(token), "min")
        numPart = strtrim(extractBefore(lower(token), "min"));
        tw(i) = 60 * str2double(numPart);
        continue;
    end
    tw(i) = str2double(token);
end
end

function classTbl = buildClassificationTable(datasetTbl, dipTauTbl, fmTauTbl, collapseTbl, preprocTbl, cfg)
tpValues = unique(datasetTbl.Tp(isfinite(datasetTbl.Tp)), 'sorted');

rows = repmat(initClassRow(), numel(tpValues), 1);
for i = 1:numel(tpValues)
    tp = tpValues(i);
    row = initClassRow();
    row.Tp = tp;

    sub = datasetTbl(datasetTbl.Tp == tp, :);
    sub = sub(isfinite(sub.tw) & sub.tw > 0 & isfinite(sub.Dip_depth), :);
    sub = sortrows(sub, 'tw');

    if ~isempty(sub)
        tw = sub.tw(:);
        y = sub.Dip_depth(:);
        [peakVal, peakIdx] = max(y, [], 'omitnan');
        if isempty(peakIdx) || ~isfinite(peakIdx)
            peakIdx = NaN;
            peakVal = NaN;
        end
        row.n_points = numel(tw);
        row.tw_min_seconds = min(tw, [], 'omitnan');
        row.tw_max_seconds = max(tw, [], 'omitnan');
        row.tw_values_seconds = strjoin(compose('%.0f', tw.'), ';');
        row.has_tw_3s = any(abs(tw - 3) < 1e-12);
        row.Dip_depth_start = y(1);
        row.Dip_depth_peak = peakVal;
        row.peak_tw_seconds = iff(isfinite(peakIdx), tw(peakIdx), NaN);
        row.Dip_depth_range_to_peak = peakVal - y(1);
        row.n_downturns = nnz(diff(y) < 0);
        row.peak_at_first_sample = isfinite(peakIdx) && peakIdx == 1;
        if row.peak_at_first_sample
            row.tau_dip_upper_bound_seconds = row.tw_min_seconds;
        end

        c25 = estimateUpwardCrossing(tw, y, 0.25);
        c50 = estimateUpwardCrossing(tw, y, 0.50);
        c75 = estimateUpwardCrossing(tw, y, 0.75);
        row.cross25_tau_seconds = c25.tau_seconds;
        row.cross25_status = c25.status;
        row.cross50_tau_seconds = c50.tau_seconds;
        row.cross50_status = c50.status;
        row.cross75_tau_seconds = c75.tau_seconds;
        row.cross75_status = c75.status;

        if numel(tw) >= 3
            c50s = estimateUpwardCrossing(tw(2:end), y(2:end), 0.50);
            row.cross50_from_second_tau_seconds = c50s.tau_seconds;
            row.cross50_from_second_status = c50s.status;
        end
    end

    dip = dipTauTbl(dipTauTbl.Tp == tp, :);
    if ~isempty(dip)
        d = dip(1, :);
        row.tau_dip_canonical_seconds = getOrNaN(d, 'tau_effective_seconds');
        row.tau_half_range_seconds = getOrNaN(d, 'tau_half_range_seconds');
        row.tau_half_range_status = getOrString(d, 'tau_half_range_status');
        row.tau_logistic_half_seconds = getOrNaN(d, 'tau_logistic_half_seconds');
        row.tau_logistic_trusted = getOrBool(d, 'tau_logistic_trusted');
        row.tau_logistic_status = getOrString(d, 'tau_logistic_status');
        row.tau_stretched_half_seconds = getOrNaN(d, 'tau_stretched_half_seconds');
        row.tau_stretched_trusted = getOrBool(d, 'tau_stretched_trusted');
        row.tau_stretched_status = getOrString(d, 'tau_stretched_status');
        row.tau_method_spread_decades = getOrNaN(d, 'tau_method_spread_decades');
        row.fragile_low_point_count = getOrBool(d, 'fragile_low_point_count');
    end

    fm = fmTauTbl(fmTauTbl.Tp == tp, :);
    if ~isempty(fm)
        f = fm(1, :);
        row.tau_FM_seconds = getOrNaN(f, 'tau_effective_seconds');
        row.has_fm_valid = isfinite(row.tau_FM_seconds) && row.tau_FM_seconds > 0;
    end

    collapse = collapseTbl(collapseTbl.Tp == tp, :);
    if ~isempty(collapse)
        row.tau_rescaling_seconds = getOrNaN(collapse(1, :), 'tau_estimate_seconds');
    end

    pre = table();
    if ~isempty(preprocTbl) && ismember('Tp', preprocTbl.Properties.VariableNames)
        pre = preprocTbl(preprocTbl.Tp == tp, :);
    end
    if ~isempty(pre)
        p = pre(1, :);
        row.preproc_setting_count = getOrNaN(p, 'preproc_setting_count');
        row.preproc_peak_at_first_fraction = getOrNaN(p, 'preproc_peak_at_first_fraction');
        row.preproc_half_range_ok_fraction = getOrNaN(p, 'preproc_half_range_ok_fraction');
        row.preproc_tau_median_seconds = getOrNaN(p, 'preproc_tau_median_seconds');
        row.preproc_tau_iqr_decades = getOrNaN(p, 'preproc_tau_iqr_decades');
    end

    if isfinite(row.tau_FM_seconds) && row.tau_FM_seconds > 0 && ...
            isfinite(row.tau_dip_canonical_seconds) && row.tau_dip_canonical_seconds > 0
        row.R_canonical = row.tau_FM_seconds / row.tau_dip_canonical_seconds;
    end
    if isfinite(row.tau_FM_seconds) && row.tau_FM_seconds > 0 && ...
            isfinite(row.tau_dip_upper_bound_seconds) && row.tau_dip_upper_bound_seconds > 0
        row.R_lower_bound_from_censoring = row.tau_FM_seconds / row.tau_dip_upper_bound_seconds;
    end

    [row.category_primary, row.category_flags, row.exclusion_driver, ...
        row.canonical_R_support, row.exploratory_full_tau_support, ...
        row.censored_only_support, row.inclusion_recommendation, ...
        row.assumption_notes] = classifyTemperature(row, cfg);

    rows(i) = row;
end

classTbl = struct2table(rows);
end

function row = initClassRow()
row = struct( ...
    'Tp', NaN, ...
    'n_points', NaN, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'tw_values_seconds', "", ...
    'has_tw_3s', false, ...
    'Dip_depth_start', NaN, ...
    'Dip_depth_peak', NaN, ...
    'peak_tw_seconds', NaN, ...
    'Dip_depth_range_to_peak', NaN, ...
    'n_downturns', NaN, ...
    'peak_at_first_sample', false, ...
    'cross25_tau_seconds', NaN, ...
    'cross25_status', "", ...
    'cross50_tau_seconds', NaN, ...
    'cross50_status', "", ...
    'cross75_tau_seconds', NaN, ...
    'cross75_status', "", ...
    'cross50_from_second_tau_seconds', NaN, ...
    'cross50_from_second_status', "", ...
    'tau_dip_upper_bound_seconds', NaN, ...
    'tau_dip_canonical_seconds', NaN, ...
    'tau_half_range_seconds', NaN, ...
    'tau_half_range_status', "", ...
    'tau_logistic_half_seconds', NaN, ...
    'tau_logistic_trusted', false, ...
    'tau_logistic_status', "", ...
    'tau_stretched_half_seconds', NaN, ...
    'tau_stretched_trusted', false, ...
    'tau_stretched_status', "", ...
    'tau_method_spread_decades', NaN, ...
    'fragile_low_point_count', false, ...
    'tau_rescaling_seconds', NaN, ...
    'tau_FM_seconds', NaN, ...
    'has_fm_valid', false, ...
    'R_canonical', NaN, ...
    'R_lower_bound_from_censoring', NaN, ...
    'preproc_setting_count', NaN, ...
    'preproc_peak_at_first_fraction', NaN, ...
    'preproc_half_range_ok_fraction', NaN, ...
    'preproc_tau_median_seconds', NaN, ...
    'preproc_tau_iqr_decades', NaN, ...
    'category_primary', "", ...
    'category_flags', "", ...
    'exclusion_driver', "", ...
    'canonical_R_support', false, ...
    'exploratory_full_tau_support', false, ...
    'censored_only_support', false, ...
    'inclusion_recommendation', "", ...
    'assumption_notes', "");
end

function [category, flags, exclusionDriver, canonicalSupport, exploratoryFull, censoredOnly, recommendation, assumptions] = classifyTemperature(row, cfg)
category = "excluded for clearly physical reasons";
flags = "";
exclusionDriver = "";
canonicalSupport = false;
exploratoryFull = false;
censoredOnly = false;
recommendation = "exclude";
assumptions = "";

tauDipFinite = isfinite(row.tau_dip_canonical_seconds) && row.tau_dip_canonical_seconds > 0;
tauFmFinite = isfinite(row.tau_FM_seconds) && row.tau_FM_seconds > 0;

if tauDipFinite
    unstable = row.fragile_low_point_count || ...
        (isfinite(row.tau_method_spread_decades) && row.tau_method_spread_decades > cfg.unstableSpreadThresholdDecades) || ...
        (isfinite(row.n_downturns) && row.n_downturns >= 2);
    if unstable
        category = "dip present but extraction unstable";
        flags = "finite_tau_dip_with_fragility_or_method_spread";
    else
        category = "clear dip present and tau_dip valid";
        flags = "finite_tau_dip_consensus";
    end
else
    noCross = (row.tau_half_range_status == "no_upward_crossing") || (row.cross50_status == "no_upward_crossing");
    dipAbsentLike = ~(isfinite(row.Dip_depth_range_to_peak) && row.Dip_depth_range_to_peak > 0);

    if noCross && row.peak_at_first_sample && tauFmFinite
        if isfinite(row.preproc_peak_at_first_fraction) && ...
                row.preproc_peak_at_first_fraction < cfg.preprocSensitivityFractionThreshold
            category = "excluded due threshold / fit-window / preprocessing choices";
            flags = "high_preprocessing_sensitivity_at_first_point";
            exclusionDriver = "preprocessing_sensitive_no_canonical_upward_crossing";
        else
            category = "FM background valid but dip invalid";
            flags = "fm_finite_dip_no_upward_crossing";
            exclusionDriver = "dip_peak_at_earliest_sample";
        end
    elseif noCross && ~dipAbsentLike
        category = "dip present but tau_dip unresolved within the current tw window";
        flags = "positive_dip_range_but_no_upward_half_crossing";
        exclusionDriver = "window_limited_unresolved";
    elseif dipAbsentLike
        category = "weak / ambiguous dip";
        flags = "nonpositive_dip_range";
        exclusionDriver = "ambiguous_dip_visibility";
    else
        category = "no visible dip";
        flags = "no_detectable_peak_structure";
        exclusionDriver = "no_visible_dip";
    end
end

if tauDipFinite && tauFmFinite
    canonicalSupport = true;
    recommendation = "canonical";
    assumptions = "none";
    return;
end

modelOnlyCandidate = false;
if ~tauDipFinite && tauFmFinite && row.tau_logistic_trusted && row.tau_stretched_trusted && ...
        (row.tau_logistic_status == "ok") && (row.tau_stretched_status == "ok") && ...
        isfinite(row.tau_logistic_half_seconds) && row.tau_logistic_half_seconds > 0 && ...
        isfinite(row.tau_stretched_half_seconds) && row.tau_stretched_half_seconds > 0
    spread = abs(log10(row.tau_logistic_half_seconds) - log10(row.tau_stretched_half_seconds));
    modelOnlyCandidate = spread <= cfg.modelAgreementThresholdDecades;
end

windowCandidate = false;
if ~tauDipFinite && tauFmFinite && isfinite(row.cross50_from_second_tau_seconds) && ...
        row.cross50_from_second_tau_seconds > 0 && ...
        (row.cross50_from_second_status == "ok") && ...
        row.peak_at_first_sample && ...
        isfinite(row.preproc_peak_at_first_fraction) && ...
        row.preproc_peak_at_first_fraction < cfg.preprocSensitivityFractionThreshold
    windowCandidate = true;
end

censoredCandidate = false;
if ~tauDipFinite && tauFmFinite && isfinite(row.tau_dip_upper_bound_seconds) && row.tau_dip_upper_bound_seconds > 0
    censoredCandidate = true;
end

exploratoryFull = modelOnlyCandidate || windowCandidate;
censoredOnly = censoredCandidate && ~exploratoryFull;

if exploratoryFull
    recommendation = "exploratory_only";
    if windowCandidate
        assumptions = "requires dropping earliest sampled point and treating canonical start as window-biased";
    else
        assumptions = "requires model-only tau extraction agreement without direct half-range support";
    end
elseif censoredCandidate
    recommendation = "exploratory_only";
    assumptions = "only censored support: tau_dip <= tw_min and R >= tau_FM / tw_min";
else
    recommendation = "exclude";
    assumptions = "no defensible full-tau recovery from existing evidence";
end
end

function result = estimateUpwardCrossing(t, y, frac)
result = struct('tau_seconds', NaN, 'status', "unresolved");

if nargin < 3 || ~isfinite(frac) || frac <= 0 || frac >= 1
    result.status = "invalid_fraction";
    return;
end
if numel(t) < 2 || any(~isfinite(t)) || any(t <= 0) || any(~isfinite(y))
    result.status = "insufficient_data";
    return;
end

t = t(:);
y = y(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    result.status = "missing_peak";
    return;
end

y0 = y(1);
if peakIdx == 1 || ~isfinite(y0) || peakValue <= y0
    result.status = "no_upward_crossing";
    return;
end

target = y0 + frac * (peakValue - y0);
idx = find(y(1:peakIdx-1) <= target & y(2:peakIdx) >= target, 1, 'first');
if isempty(idx)
    result.status = "no_upward_crossing";
    return;
end

t1 = t(idx);
t2 = t(idx + 1);
y1 = y(idx);
y2 = y(idx + 1);
if abs(y2 - y1) <= eps(max(abs([y1; y2])))
    result.tau_seconds = sqrt(t1 * t2);
    result.status = "ok";
    return;
end

alpha = (target - y1) ./ (y2 - y1);
alpha = min(max(alpha, 0), 1);
result.tau_seconds = 10 .^ (log10(t1) + alpha .* (log10(t2) - log10(t1)));
result.status = "ok";
end

function fig = makeDipVisibilityFigure(datasetTbl, classTbl)
fig = newFigure([2 2 18 11], 'off');
ax = axes(fig);
hold(ax, 'on');

tpValues = unique(datasetTbl.Tp(isfinite(datasetTbl.Tp)), 'sorted');
cmap = parula(256);
colormap(ax, cmap);
clim(ax, [min(tpValues), max(tpValues)]);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = datasetTbl(datasetTbl.Tp == tp, :);
    sub = sub(isfinite(sub.tw) & sub.tw > 0 & isfinite(sub.Dip_depth), :);
    sub = sortrows(sub, 'tw');
    if isempty(sub)
        continue;
    end
    clr = mapValueToColor(tp, [min(tpValues), max(tpValues)], cmap);
    cRow = classTbl(classTbl.Tp == tp, :);
    ls = '-';
    if ~isempty(cRow) && (cRow.fragile_low_point_count || cRow.peak_at_first_sample)
        ls = '--';
    end

    plot(ax, sub.tw, sub.Dip_depth, ls, 'Color', clr, 'LineWidth', 2.0, 'HandleVisibility', 'off');
    plot(ax, sub.tw, sub.Dip_depth, 'o', 'Color', clr, 'MarkerFaceColor', clr, ...
        'MarkerSize', 6.5, 'LineWidth', 1.4, 'HandleVisibility', 'off');
end

set(ax, 'XScale', 'log');
xlabel(ax, 'Waiting time t_w (s)');
ylabel(ax, 'Dip depth (arb.)');
title(ax, 'Dip visibility by stopping temperature');
set(ax, 'FontSize', 14, 'LineWidth', 1.5, 'TickDir', 'out', 'Box', 'off');
grid(ax, 'on');

cb = colorbar(ax);
cb.Label.String = 'T_p (K)';
cb.FontSize = 13;

h1 = plot(ax, nan, nan, '-k', 'LineWidth', 2.0, 'DisplayName', 'Standard trajectory');
h2 = plot(ax, nan, nan, '--k', 'LineWidth', 2.0, 'DisplayName', 'Fragile/high-T pattern');
legend(ax, [h1, h2], 'Location', 'eastoutside', 'FontSize', 12);
end

function fig = makeExtractionDiagnosticsFigure(classTbl)
fig = newFigure([2 2 18 10], 'off');
ax = axes(fig);
hold(ax, 'on');

tp = classTbl.Tp;
plot(ax, tp, classTbl.tau_half_range_seconds, '-^', ...
    'Color', [0.00 0.62 0.45], 'MarkerFaceColor', [0.00 0.62 0.45], ...
    'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', 'Half-range');
plot(ax, tp, classTbl.tau_logistic_half_seconds, '-o', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.0, 'MarkerSize', 7, 'DisplayName', 'Logistic');
plot(ax, tp, classTbl.tau_stretched_half_seconds, '-s', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.0, 'MarkerSize', 7, 'DisplayName', 'Stretched');
plot(ax, tp, classTbl.tau_dip_canonical_seconds, '-d', ...
    'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], ...
    'LineWidth', 2.4, 'MarkerSize', 7, 'DisplayName', 'Canonical tau_{dip}');

maskCensored = isfinite(classTbl.tau_dip_upper_bound_seconds) & ~isfinite(classTbl.tau_dip_canonical_seconds);
if any(maskCensored)
    plot(ax, tp(maskCensored), classTbl.tau_dip_upper_bound_seconds(maskCensored), 'v', ...
        'Color', [0.55 0.20 0.70], 'MarkerFaceColor', [0.55 0.20 0.70], ...
        'LineWidth', 1.4, 'MarkerSize', 8, 'DisplayName', 'Censored upper bound');
end

set(ax, 'YScale', 'log');
xlabel(ax, 'T_p (K)');
ylabel(ax, 'Timescale (s)');
title(ax, 'tau_{dip} extraction diagnostics by method');
grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.5, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside', 'FontSize', 12);
end

function fig = makeHighTDiagnosticsFigure(datasetTbl, classTbl, preprocTbl, focusTp)
fig = newFigure([2 2 20 9], 'off');
tlo = tiledlayout(fig, 1, numel(focusTp), 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(focusTp)
    tp = focusTp(i);
    ax = nexttile(tlo, i);
    hold(ax, 'on');

    sub = datasetTbl(datasetTbl.Tp == tp, :);
    sub = sub(isfinite(sub.tw) & sub.tw > 0 & isfinite(sub.Dip_depth), :);
    sub = sortrows(sub, 'tw');

    if isempty(sub)
        title(ax, sprintf('T_p = %.0f K (no data)', tp));
        continue;
    end

    plot(ax, sub.tw, sub.Dip_depth, '-o', ...
        'Color', [0.12 0.35 0.72], 'MarkerFaceColor', [0.12 0.35 0.72], ...
        'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', 'Canonical points');

    row = classTbl(classTbl.Tp == tp, :);
    if ~isempty(row)
        if isfinite(row.cross50_from_second_tau_seconds)
            xline(ax, row.cross50_from_second_tau_seconds, '--', ...
                'Color', [0.85 0.33 0.10], 'LineWidth', 2.0, ...
                'DisplayName', '\tau_{1/2} (from 2nd point)');
        end
        if isfinite(row.tau_dip_upper_bound_seconds)
            xline(ax, row.tau_dip_upper_bound_seconds, ':', ...
                'Color', [0.55 0.20 0.70], 'LineWidth', 2.2, ...
                'DisplayName', 'Censoring bound t_{min}');
        end

        txt = composeHighTAnnotation(row, preprocTbl);
        text(ax, 0.03, 0.97, txt, 'Units', 'normalized', ...
            'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
            'FontSize', 11, 'BackgroundColor', [1 1 1], 'Margin', 5);
    end

    set(ax, 'XScale', 'log');
    xlabel(ax, 't_w (s)');
    ylabel(ax, 'Dip depth (arb.)');
    title(ax, sprintf('T_p = %.0f K high-T diagnostics', tp));
    grid(ax, 'on');
    set(ax, 'FontSize', 14, 'LineWidth', 1.5, 'TickDir', 'out', 'Box', 'off');
    legend(ax, 'Location', 'southoutside', 'FontSize', 10);
end

title(tlo, 'High-temperature window/censoring diagnostics (30 K, 34 K)');
end

function txt = composeHighTAnnotation(row, preprocTbl)
pre = table();
if ~isempty(preprocTbl) && ismember('Tp', preprocTbl.Properties.VariableNames)
    pre = preprocTbl(preprocTbl.Tp == row.Tp, :);
end
if isempty(pre)
    peakFrac = NaN;
else
    peakFrac = pre.preproc_peak_at_first_fraction(1);
end

lines = strings(0, 1);
lines(end + 1) = sprintf('half-range status: %s', char(string(row.tau_half_range_status)));
lines(end + 1) = sprintf('peak@first sample: %s', tfText(row.peak_at_first_sample));
if isfinite(row.cross50_from_second_tau_seconds)
    lines(end + 1) = sprintf('tau_{1/2} from 2nd point: %.1f s', row.cross50_from_second_tau_seconds);
end
if isfinite(row.tau_dip_upper_bound_seconds)
    lines(end + 1) = sprintf('censored: tau_{dip} <= %.0f s', row.tau_dip_upper_bound_seconds);
end
if isfinite(peakFrac)
    lines(end + 1) = sprintf('preproc peak@first fraction: %.2f', peakFrac);
end
txt = strjoin(lines, newline);
end

function textOut = buildReportText(runDir, cfg, classTbl, canonicalTbl, exploratoryTbl, censoredTbl, preprocTbl)
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
focusMask = ismember(classTbl.Tp, cfg.focusTemperaturesK);
focusTbl = classTbl(focusMask, :);

tp30 = focusTbl(focusTbl.Tp == 30, :);
tp34 = focusTbl(focusTbl.Tp == 34, :);

lines = strings(0, 1);
lines(end + 1) = "# Aging clock-ratio temperature support audit";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", nowText);
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";

lines(end + 1) = "## Repository State Summary";
lines(end + 1) = "- Read repository policy docs before analysis: `docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/repository_structure.md`.";
lines(end + 1) = "- Confirmed no existing run performs this exact temperature-support audit for `R(T_p)` inclusion logic.";
lines(end + 1) = "- Existing runs already document that canonical overlap is `14, 18, 22, 26 K` and `30/34 K` fail direct dip half-range extraction.";
lines(end + 1) = "";

lines(end + 1) = "## What Existing Code Was Reused";
lines(end + 1) = "- Canonical dip timescale extraction outputs from `run_2026_03_12_223709_aging_timescale_extraction`.";
lines(end + 1) = "- Canonical FM timescale extraction outputs from `run_2026_03_13_013634_aging_fm_timescale_analysis`.";
lines(end + 1) = "- Canonical dataset build outputs from `run_2026_03_12_211204_aging_dataset_build`.";
lines(end + 1) = "- Existing exploratory collapse-based tau table from `run_2026_03_12_233710_aging_time_rescaling_collapse`.";
lines(end + 1) = "- Existing preprocessing-sensitivity sweep table from `run_legacy_decomposition_stability`.";
lines(end + 1) = "";

lines(end + 1) = "## What New Code Was Added";
lines(end + 1) = "- Added one new analysis script: `Aging/analysis/aging_clock_ratio_temperature_support_audit.m`.";
lines(end + 1) = "- No pipeline code, no existing run outputs, and no legacy scripts were modified.";
lines(end + 1) = "";

lines(end + 1) = "## Exact Run Inputs Used";
lines(end + 1) = sprintf("- Dataset: `%s`", cfg.datasetPath);
lines(end + 1) = sprintf("- Canonical dip tau table: `%s`", cfg.dipTauPath);
lines(end + 1) = sprintf("- Canonical FM tau table: `%s`", cfg.fmTauPath);
lines(end + 1) = sprintf("- Exploratory collapse tau table: `%s`", cfg.rescalingTauPath);
lines(end + 1) = sprintf("- Exploratory preprocessing-sensitivity table: `%s`", cfg.decompositionRawPath);
lines(end + 1) = "";

lines(end + 1) = "## Main Conclusions (Summary)";
lines(end + 1) = sprintf("- Canonical `R(T_p)` support remains `%s K`.", fmtTpList(canonicalTbl.Tp));
lines(end + 1) = "- `30 K` and `34 K` are excluded canonically because direct dip half-range extraction is unresolved (`no_upward_crossing`) in the canonical dataset.";
lines(end + 1) = "- `30 K` is not a clean physical no-dip case; it is strongly method/window/preprocessing sensitive and can only be included as exploratory.";
lines(end + 1) = "- `34 K` remains unresolved across current evidence and is only defensible as a censored point (`tau_dip <= 36 s`, hence lower bound on `R`).";
lines(end + 1) = "- Canonical overlap is produced by conservative extraction choices tied to direct half-range observability, not by FM availability limits.";
lines(end + 1) = "- FM background is finite at both `30 K` and `34 K`, so exclusion is dip-side only.";
lines(end + 1) = "- Existing model-only alternatives (logistic/stretched) disagree strongly at high `T_p`, so they are not canonical replacements.";
lines(end + 1) = sprintf("- Exploratory full-tau extension is `%s K` (non-canonical).", fmtTpList(exploratoryTbl.Tp));
lines(end + 1) = sprintf("- Censored-only support (no full tau point) is `%s K`.", fmtTpList(censoredTbl.Tp));
lines(end + 1) = "";

lines(end + 1) = "## Why This Run Is Under `results/aging/runs/`";
lines(end + 1) = "- The audited observable (`tau_dip`, `tau_FM`, and therefore `R(T_p)`) is defined inside the Aging module.";
lines(end + 1) = "- This task audits Aging inclusion logic before any cross-experiment robustness step, so the canonical location is `results/aging/runs/`.";
lines(end + 1) = "";

lines(end + 1) = "## Per-Temperature Classification";
lines(end + 1) = "| T_p (K) | Category | Canonical R support | Recommendation | Key reason |";
lines(end + 1) = "| ---: | :--- | :---: | :--- | :--- |";
for i = 1:height(classTbl)
    lines(end + 1) = sprintf("| %.0f | %s | %s | %s | %s |", ...
        classTbl.Tp(i), classTbl.category_primary(i), ...
        tfText(classTbl.canonical_R_support(i)), classTbl.inclusion_recommendation(i), ...
        summarizeReason(classTbl(i, :)));
end
lines(end + 1) = "";

lines(end + 1) = "## Targeted High-T Answers";
lines(end + 1) = sprintf("- **Why was 30 K excluded?** %s", targetedReason(tp30));
lines(end + 1) = sprintf("- **Why was 34 K excluded?** %s", targetedReason(tp34));
lines(end + 1) = sprintf("- **Are 30/34 outside dip sector or unresolved?** 30 K is unresolved under canonical extraction and highly choice-sensitive; 34 K remains unresolved and behaves like an early-time-censored dip clock.");
lines(end + 1) = sprintf("- **Can additional temperatures be included defensibly?** Canonical: no. Exploratory full-tau: `%s K`. Censored-only: `%s K`.", ...
    fmtTpList(exploratoryTbl.Tp), fmtTpList(censoredTbl.Tp));
lines(end + 1) = sprintf("- **Canonical support for R(T_p):** `%s K`.", fmtTpList(canonicalTbl.Tp));
lines(end + 1) = "";

lines(end + 1) = "## Physical Support vs Extraction Choices";
lines(end + 1) = "- The current canonical overlap (`14, 18, 22, 26 K`) is primarily the support produced by the current conservative dip extraction rule (direct half-range observability).";
lines(end + 1) = "- It is not equivalent to a proof that higher temperatures are physically dip-free.";
lines(end + 1) = "- High-`T_p` points are constrained by missing early waiting-time support (`t_w = 3 s` absent at 30/34 K) and by extraction instability.";
lines(end + 1) = "";

if ~isempty(preprocTbl) && ismember('Tp', preprocTbl.Properties.VariableNames)
    lines(end + 1) = "## Preprocessing/Window Sensitivity Check";
    lines(end + 1) = "| T_p (K) | settings | peak@first fraction | half-range-ok fraction |";
    lines(end + 1) = "| ---: | ---: | ---: | ---: |";
    for tp = cfg.focusTemperaturesK
        p = preprocTbl(preprocTbl.Tp == tp, :);
        if isempty(p)
            continue;
        end
        lines(end + 1) = sprintf("| %.0f | %.0f | %.3f | %.3f |", ...
            p.Tp(1), p.preproc_setting_count(1), ...
            p.preproc_peak_at_first_fraction(1), ...
            p.preproc_half_range_ok_fraction(1));
    end
    lines(end + 1) = "";
end

lines(end + 1) = "## Visualization Choices";
lines(end + 1) = "- `dip_visibility_vs_tw_by_Tp`: 8 curves, `parula` colormap + labeled colorbar, dashed style for fragile/high-T patterns.";
lines(end + 1) = "- `tau_dip_extraction_diagnostics_vs_Tp`: 4 method curves, explicit legend, log-y axis, no colormap.";
lines(end + 1) = "- `highT_window_and_censoring_diagnostics`: 2 focused panels (30 K, 34 K), explicit annotations for window and censoring assumptions.";
lines(end + 1) = "- Smoothing applied: none; all diagnostics use saved scalar observables directly.";
lines(end + 1) = "";

lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/temperature_classification_table.csv`";
lines(end + 1) = "- `tables/canonical_R_support_table.csv`";
lines(end + 1) = "- `tables/exploratory_extended_R_support_table.csv`";
lines(end + 1) = "- `tables/censored_support_table.csv`";
lines(end + 1) = "- `figures/dip_visibility_vs_tw_by_Tp.png`";
lines(end + 1) = "- `figures/tau_dip_extraction_diagnostics_vs_Tp.png`";
lines(end + 1) = "- `figures/highT_window_and_censoring_diagnostics.png`";
lines(end + 1) = "- `reports/aging_clock_ratio_temperature_support_audit_report.md`";
lines(end + 1) = "- `review/aging_clock_ratio_temperature_support_audit_bundle.zip`";

textOut = strjoin(lines, newline);
end

function reason = summarizeReason(rowTbl)
row = rowTbl(1, :);
parts = strings(0, 1);
if isfinite(row.tau_half_range_seconds)
    parts(end + 1) = "half-range resolved";
else
    parts(end + 1) = sprintf('half-range %s', char(string(row.tau_half_range_status)));
end
if row.peak_at_first_sample
    parts(end + 1) = "peak at earliest sample";
end
if isfinite(row.preproc_peak_at_first_fraction)
    parts(end + 1) = sprintf('preproc peak@first %.2f', row.preproc_peak_at_first_fraction);
end
if isfinite(row.tau_dip_upper_bound_seconds)
    parts(end + 1) = sprintf('tau_dip <= %.0f s', row.tau_dip_upper_bound_seconds);
end
reason = strjoin(parts, '; ');
end

function txt = targetedReason(tpRow)
if isempty(tpRow)
    txt = "No row available in this audit table.";
    return;
end
r = tpRow(1, :);
txt = sprintf('Canonical half-range is `%s` with earliest-point peak = `%s`; recommendation = `%s` (%s).', ...
    char(string(r.tau_half_range_status)), tfText(r.peak_at_first_sample), ...
    char(string(r.inclusion_recommendation)), char(string(r.assumption_notes)));
end

function fig = newFigure(positionCm, visibilityMode)
if exist('create_figure', 'file') == 2
    fig = create_figure('Visible', visibilityMode, 'Position', positionCm);
else
    fig = figure('Visible', visibilityMode, 'Color', 'w', 'Units', 'centimeters', 'Position', positionCm);
end
end

function colorValue = mapValueToColor(v, lims, cmap)
if lims(2) <= lims(1)
    idx = 1;
else
    frac = (v - lims(1)) ./ (lims(2) - lims(1));
    frac = max(min(frac, 1), 0);
    idx = 1 + round(frac * (size(cmap, 1) - 1));
end
colorValue = cmap(idx, :);
end

function value = getOrNaN(tblRow, vn)
if ismember(vn, tblRow.Properties.VariableNames)
    value = tblRow.(vn)(1);
else
    value = NaN;
end
end

function value = getOrBool(tblRow, vn)
if ismember(vn, tblRow.Properties.VariableNames)
    v = tblRow.(vn)(1);
    if islogical(v)
        value = v;
    elseif isnumeric(v)
        value = v ~= 0;
    else
        value = strcmpi(string(v), "true") || strcmp(string(v), "1");
    end
else
    value = false;
end
end

function value = getOrString(tblRow, vn)
if ismember(vn, tblRow.Properties.VariableNames)
    value = string(tblRow.(vn)(1));
else
    value = "";
end
end

function out = iff(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end

function out = tfText(tf)
if tf
    out = "yes";
else
    out = "no";
end
end

function txt = fmtTpList(tp)
if isempty(tp)
    txt = "(none)";
    return;
end
tp = tp(isfinite(tp));
if isempty(tp)
    txt = "(none)";
    return;
end
txt = char(strjoin(compose('%.0f', sort(tp(:)).'), ', '));
end

function appendText(pathStr, textLine)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textLine);
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
items = { ...
    fullfile(runDir, 'reports', 'aging_clock_ratio_temperature_support_audit_report.md'), ...
    fullfile(runDir, 'tables', 'temperature_classification_table.csv'), ...
    fullfile(runDir, 'tables', 'canonical_R_support_table.csv'), ...
    fullfile(runDir, 'tables', 'exploratory_extended_R_support_table.csv'), ...
    fullfile(runDir, 'tables', 'censored_support_table.csv'), ...
    fullfile(runDir, 'figures', 'dip_visibility_vs_tw_by_Tp.png'), ...
    fullfile(runDir, 'figures', 'tau_dip_extraction_diagnostics_vs_Tp.png'), ...
    fullfile(runDir, 'figures', 'highT_window_and_censoring_diagnostics.png')};
existing = items(cellfun(@(p) exist(p, 'file') == 2, items));
if isempty(existing)
    return;
end
zip(zipPath, existing, runDir);
end
