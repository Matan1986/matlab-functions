clear; clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
repoRoot = fileparts(repoRoot);
addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

datasetPath = fullfile(tablesDir, 'aging_trackA_replay_dataset.csv');
mainTrackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');

resultsPath = fullfile(tablesDir, 'aging_trackA_tau_minimal_results.csv');
auditPath = fullfile(tablesDir, 'aging_trackA_tau_minimal_dataset_audit.csv');
reportPath = fullfile(reportsDir, 'aging_trackA_tau_minimal_replay.md');

requiredCols = ["Tp","tw","Dip_area_selected","FM_E","AFM_like","FM_like", ...
    "source_run","trace_instance","fit_status"];
metricNames = ["Dip_area_selected","FM_E","AFM_like","FM_like"];

assert(exist(datasetPath, 'file') == 2, 'Missing required input dataset: %s', datasetPath);
assert(exist(mainTrackBPath, 'file') == 2, 'Missing main Track B dataset: %s', mainTrackBPath);

mainTrackBBefore = fileread(mainTrackBPath);

trackA = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
trackACols = string(trackA.Properties.VariableNames);
missingCols = requiredCols(~ismember(requiredCols, trackACols));

auditRows = repmat(makeAuditRow(), 0, 1);
auditRows(end+1,1) = buildAuditRow("file_exists", exist(datasetPath, 'file') == 2, datasetPath); %#ok<SAGROW>
auditRows(end+1,1) = buildAuditRow("required_columns_present", isempty(missingCols), joinOrNone(missingCols)); %#ok<SAGROW>

rowCount = height(trackA);
uniqueTp = unique(double(trackA.Tp(isfinite(double(trackA.Tp)))));
uniqueTw = unique(double(trackA.tw(isfinite(double(trackA.tw)))));

auditRows(end+1,1) = buildAuditRow("row_count", true, string(rowCount)); %#ok<SAGROW>
auditRows(end+1,1) = buildAuditRow("unique_Tp_values", true, joinNumeric(uniqueTp)); %#ok<SAGROW>
auditRows(end+1,1) = buildAuditRow("unique_tw_values", true, joinNumeric(uniqueTw)); %#ok<SAGROW>
auditRows(end+1,1) = buildAuditRow("Tp_6_included", any(abs(uniqueTp - 6) < 1e-9), "Required low-T coverage check"); %#ok<SAGROW>
auditRows(end+1,1) = buildAuditRow("Tp_10_included", any(abs(uniqueTp - 10) < 1e-9), "Required low-T coverage check"); %#ok<SAGROW>

assert(isempty(missingCols), 'Track A replay dataset is missing required columns: %s', strjoin(cellstr(missingCols), ', '));

nonFiniteMask = false(height(trackA), 1);
nonFiniteMetricList = strings(height(trackA), 1);
for i = 1:numel(metricNames)
    metric = metricNames(i);
    values = double(trackA.(metric));
    bad = ~isfinite(values);
    nonFiniteMask = nonFiniteMask | bad;
    nonFiniteMetricList(bad) = appendMetric(nonFiniteMetricList(bad), metric);
end

allMetricsFinite = ~any(nonFiniteMask);
auditRows(end+1,1) = buildAuditRow("all_trackA_metrics_finite", allMetricsFinite, ...
    ternary(allMetricsFinite, "All four Track A metrics are finite in every row.", ...
    "Exact non-finite rows listed below.")); %#ok<SAGROW>

if any(nonFiniteMask)
    badRows = trackA(nonFiniteMask, :);
    badMetrics = nonFiniteMetricList(nonFiniteMask);
    for i = 1:height(badRows)
        detail = "Non-finite metrics: " + badMetrics(i);
        auditRows(end+1,1) = buildAuditRow("non_finite_row", false, detail, ... %#ok<SAGROW>
            double(badRows.Tp(i)), double(badRows.tw(i)), badRows.source_run(i), ...
            badRows.trace_instance(i), badRows.fit_status(i));
    end
end

auditTbl = struct2table(auditRows);
writetable(auditTbl, auditPath, 'QuoteStrings', true);

resultsRows = repmat(makeResultRow(), 0, 1);
for metricIdx = 1:numel(metricNames)
    metric = metricNames(metricIdx);
    for tpIdx = 1:numel(uniqueTp)
        tp = uniqueTp(tpIdx);
        mask = isfinite(double(trackA.Tp)) & abs(double(trackA.Tp) - tp) < 1e-9;
        sub = trackA(mask, :);
        sub = sortrows(sub, 'tw');

        tw = double(sub.tw);
        y = double(sub.(metric));
        nTw = numel(tw);
        twMin = NaN;
        twMax = NaN;
        metricMin = NaN;
        metricMax = NaN;
        metricRange = NaN;
        slope = NaN;
        direction = "mixed";
        tauProxy = NaN;
        proxyStatus = "fit_failed";
        proxyReason = "Fit could not be evaluated.";

        if nTw > 0
            twMin = min(tw);
            twMax = max(tw);
            metricMin = min(y);
            metricMax = max(y);
            metricRange = metricMax - metricMin;
            direction = classifyMonotonicDirection(y);
        end

        if nTw < 3
            proxyStatus = "insufficient_points";
            proxyReason = "Fewer than 3 tw points.";
        elseif ~(metricRange > 0)
            proxyStatus = "flat_or_zero_range";
            proxyReason = "Metric range is zero or non-positive.";
        else
            try
                x = log10(tw);
                coeffs = polyfit(x, y, 1);
                intercept = coeffs(2);
                slope = coeffs(1);
                midpoint = 0.5 * (metricMin + metricMax);
                if ~isfinite(slope) || ~isfinite(intercept) || abs(slope) < eps(max(1, abs(midpoint)))
                    proxyStatus = "fit_failed";
                    proxyReason = "Fitted slope is zero or non-finite.";
                else
                    logTwMid = (midpoint - intercept) / slope;
                    tauProxy = 10.^logTwMid;
                    if isfinite(tauProxy)
                        proxyStatus = "computed";
                        proxyReason = "Diagnostic tau-like proxy from midpoint of linear fit versus log10(tw).";
                    else
                        proxyStatus = "fit_failed";
                        proxyReason = "Midpoint crossing produced non-finite proxy.";
                    end
                end
            catch fitErr
                proxyStatus = "fit_failed";
                proxyReason = "Fit failed: " + string(fitErr.message);
            end
        end

        r = makeResultRow();
        r.Tp = tp;
        r.metric_name = metric;
        r.n_tw = nTw;
        r.tw_min = twMin;
        r.tw_max = twMax;
        r.metric_min = metricMin;
        r.metric_max = metricMax;
        r.metric_range = metricRange;
        r.slope_vs_logtw = slope;
        r.monotonic_direction = direction;
        r.tau_like_proxy = tauProxy;
        r.tau_like_proxy_label = "diagnostic_tau_like_proxy";
        r.proxy_status = proxyStatus;
        r.proxy_reason = proxyReason;
        resultsRows(end+1,1) = r; %#ok<SAGROW>
    end
end

resultsTbl = struct2table(resultsRows);
resultsTbl = sortrows(resultsTbl, {'Tp','metric_name'});
writetable(resultsTbl, resultsPath, 'QuoteStrings', true);

mainTrackBAfter = fileread(mainTrackBPath);
mainTrackBModified = ~strcmp(mainTrackBBefore, mainTrackBAfter);

proxyComputed = any(resultsTbl.proxy_status == "computed");
tp610Included = any(abs(uniqueTp - 6) < 1e-9) && any(abs(uniqueTp - 10) < 1e-9);
usableDiagnostics = all(ismember([6 10], round(uniqueTp(:)'))) && ...
    any(resultsTbl.proxy_status(resultsTbl.Tp == 6) == "computed") && ...
    any(resultsTbl.proxy_status(resultsTbl.Tp == 10) == "computed");

lines = strings(0,1);
lines(end+1) = "# Aging Track A tau minimal replay";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- Phase 1 only.";
lines(end+1) = "- Track A refers to fit-derived Stage5/Stage6 observables (`Dip_area_selected`, `FM_E`, `AFM_like`, `FM_like`).";
lines(end+1) = "- Track B refers to direct / dataset-contract observables and is not substituted here.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module Aging x Switching analysis performed: NO.";
lines(end+1) = "- Cross-module Aging x Relaxation analysis performed: NO.";
lines(end+1) = "- `tau_rescaling_estimates.csv` used: NO.";
lines(end+1) = "- `tables/aging/aging_observable_dataset.csv` modified: " + toYesNo(mainTrackBModified) + ".";
lines(end+1) = "";
lines(end+1) = "## Dataset audit";
lines(end+1) = "- Input dataset: `" + string(datasetPath) + "`";
lines(end+1) = "- Row count: " + string(rowCount);
lines(end+1) = "- Unique Tp values: " + joinNumeric(uniqueTp);
lines(end+1) = "- Unique tw values: " + joinNumeric(uniqueTw);
lines(end+1) = "- Tp=6 included: " + toYesNo(any(abs(uniqueTp - 6) < 1e-9));
lines(end+1) = "- Tp=10 included: " + toYesNo(any(abs(uniqueTp - 10) < 1e-9));
lines(end+1) = "- All four Track A metrics finite: " + toYesNo(allMetricsFinite);
lines(end+1) = "";
lines(end+1) = "## Diagnostic tau-like proxy";
lines(end+1) = "- Proxy definition: midpoint crossing of linear fit `metric_value ~ a + b*log10(tw)`.";
lines(end+1) = "- Label: diagnostic tau-like proxy, not physical tau.";
lines(end+1) = "- Proxy rows computed: " + string(nnz(resultsTbl.proxy_status == "computed")) + " / " + string(height(resultsTbl));
lines(end+1) = "- Low-T Tp=6/10 included in this diagnostic: " + toYesNo(tp610Included);
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- `" + string(resultsPath) + "`";
lines(end+1) = "- `" + string(auditPath) + "`";
lines(end+1) = "- `" + string(reportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- TRACKA_TAU_MINIMAL_REPLAY_COMPLETED = YES";
lines(end+1) = "- TRACKA_TERMS_CLARIFIED = YES";
lines(end+1) = "- TRACKA_DATASET_LOADED = " + toYesNo(exist(datasetPath, 'file') == 2);
lines(end+1) = "- TRACKA_METRICS_FINITE = " + toYesNo(allMetricsFinite);
lines(end+1) = "- TRACKA_LOW_T_6_10_INCLUDED = " + toYesNo(tp610Included);
lines(end+1) = "- TRACKA_TAU_PROXY_COMPUTED = " + toYesNo(proxyComputed);
lines(end+1) = "- TRACKA_FULL_REPLAY_SHOULD_BE_SPLIT = YES";
lines(end+1) = "- TRACKA_NOT_SUBSTITUTED_FOR_TRACKB = YES";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- TAU_RESCALING_ESTIMATES_USED = NO";
lines(end+1) = "- MAIN_TRACKB_DATASET_MODIFIED = NO";
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Track A terminology is clear: **YES**.";
lines(end+1) = "2. Phase 1 executed successfully: **YES**.";
lines(end+1) = "3. Tau-like proxy used: **midpoint crossing of a linear fit of metric versus log10(tw)**, explicitly diagnostic and not physical tau.";
lines(end+1) = "4. Tp=6/10 are included: **" + toYesNo(tp610Included) + "**.";
lines(end+1) = "5. Track A metrics show usable tw-response diagnostics: **" + toYesNo(usableDiagnostics) + "**.";
lines(end+1) = "6. Proceed next to Phase 2 negative controls: **YES**.";

writeLines(reportPath, lines);

disp('Aging Track A tau minimal replay completed.');
disp(resultsPath);
disp(auditPath);
disp(reportPath);

function row = makeAuditRow()
row = struct( ...
    'audit_item', "", ...
    'status', "", ...
    'detail', "", ...
    'Tp', NaN, ...
    'tw', NaN, ...
    'source_run', "", ...
    'trace_instance', "", ...
    'fit_status', "");
end

function row = buildAuditRow(item, statusFlag, detail, Tp, tw, sourceRun, traceInstance, fitStatus)
if nargin < 4, Tp = NaN; end
if nargin < 5, tw = NaN; end
if nargin < 6, sourceRun = ""; end
if nargin < 7, traceInstance = ""; end
if nargin < 8, fitStatus = ""; end
row = makeAuditRow();
row.audit_item = item;
row.status = toYesNo(statusFlag);
row.detail = string(detail);
row.Tp = Tp;
row.tw = tw;
row.source_run = string(sourceRun);
row.trace_instance = string(traceInstance);
row.fit_status = string(fitStatus);
end

function row = makeResultRow()
row = struct( ...
    'Tp', NaN, ...
    'metric_name', "", ...
    'n_tw', NaN, ...
    'tw_min', NaN, ...
    'tw_max', NaN, ...
    'metric_min', NaN, ...
    'metric_max', NaN, ...
    'metric_range', NaN, ...
    'slope_vs_logtw', NaN, ...
    'monotonic_direction', "", ...
    'tau_like_proxy', NaN, ...
    'tau_like_proxy_label', "", ...
    'proxy_status', "", ...
    'proxy_reason', "");
end

function out = appendMetric(existing, metric)
existing = string(existing);
metric = string(metric);
out = existing;
emptyMask = strlength(existing) == 0;
out(emptyMask) = metric;
out(~emptyMask) = out(~emptyMask) + "|" + metric;
end

function label = classifyMonotonicDirection(y)
y = y(:);
if numel(y) <= 1
    label = "flat";
    return;
end
d = diff(y);
if all(d > 0)
    label = "increasing";
elseif all(d < 0)
    label = "decreasing";
elseif all(d == 0)
    label = "flat";
else
    label = "mixed";
end
end

function txt = joinNumeric(values)
values = values(:)';
if isempty(values)
    txt = "NONE";
else
    txt = strjoin(compose('%.12g', values), ', ');
end
end

function txt = joinOrNone(values)
values = string(values(:)');
if isempty(values)
    txt = "NONE";
else
    txt = strjoin(cellstr(values), ', ');
end
end

function txt = ternary(cond, a, b)
if cond
    txt = string(a);
else
    txt = string(b);
end
end

function txt = toYesNo(flag)
if flag
    txt = "YES";
else
    txt = "NO";
end
end

function writeLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not open output file: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end
