function out = aging_clock_ratio_lower_support_audit(cfg)
% aging_clock_ratio_lower_support_audit
% Audit the lower-temperature exclusion logic for R(T) = tau_FM / tau_dip.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg, repoRoot);
assert(exist(cfg.classificationPath, 'file') == 2, 'Missing source classification table: %s', cfg.classificationPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'Missing FM tau table: %s', cfg.fmTauPath);
assert(exist(cfg.dipTauPath, 'file') == 2, 'Missing dip tau table: %s', cfg.dipTauPath);
assert(exist(cfg.datasetPath, 'file') == 2, 'Missing dataset table: %s', cfg.datasetPath);

runCfg = struct();
runCfg.runLabel = char(string(cfg.runLabel));
runCfg.dataset = sprintf('support:%s | fm:%s | dip:%s', ...
    char(string(cfg.sourceSupportRun)), char(string(cfg.fmRunName)), char(string(cfg.dipRunName)));
run = createRunContext('aging', runCfg);
runDir = run.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging lower-support audit run root:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] aging_clock_ratio_lower_support_audit started\n', stampNow()));
appendText(run.log_path, sprintf('classificationPath: %s\n', cfg.classificationPath));
appendText(run.log_path, sprintf('fmTauPath: %s\n', cfg.fmTauPath));
appendText(run.log_path, sprintf('dipTauPath: %s\n', cfg.dipTauPath));

classTbl = readNumericTable(cfg.classificationPath);
fmTbl = readNumericTable(cfg.fmTauPath);
dipTbl = readNumericTable(cfg.dipTauPath);
datasetTbl = readNumericTable(cfg.datasetPath);

classTbl = sortrows(classTbl, 'Tp');
lowMask = isfinite(classTbl.Tp) & classTbl.Tp < cfg.lowerTemperatureCutoffK;
lowClassTbl = classTbl(lowMask, :);
assert(~isempty(lowClassTbl), 'No temperatures found below %.2f K.', cfg.lowerTemperatureCutoffK);

lowTp = unique(lowClassTbl.Tp, 'sorted');
rows = repmat(initLowerRow(), numel(lowTp), 1);
for i = 1:numel(lowTp)
    tp = lowTp(i);
    rows(i) = classifyLowerTemperature(tp, lowClassTbl, fmTbl, dipTbl, datasetTbl);
end
lowerTbl = struct2table(rows);
lowerTbl = sortrows(lowerTbl, 'T');

canonicalMask = isfinite(classTbl.Tp) & classTbl.canonical_R_support ~= 0;
canonicalTp = sort(classTbl.Tp(canonicalMask));
lowerBoundaryK = min(canonicalTp);
boundarySector = inferBoundarySector(lowerTbl, lowerBoundaryK);

boundaryTbl = table(lowerBoundaryK, string(boundarySector), ...
    'VariableNames', {'lower_boundary_K', 'boundary_set_by_sector'});

lowerPath = save_run_table(lowerTbl, 'lower_temperature_classification.csv', runDir);
boundaryPath = save_run_table(boundaryTbl, 'lower_boundary_summary.csv', runDir);

reportText = buildReportText(runDir, cfg, lowerTbl, lowerBoundaryK, boundarySector, canonicalTp);
reportPath = save_run_report(reportText, 'aging_clock_ratio_lower_support_audit_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_clock_ratio_lower_support_audit_bundle.zip');

appendText(run.notes_path, sprintf('Lower canonical boundary: %.0f K\n', lowerBoundaryK));
appendText(run.notes_path, sprintf('Boundary set by sector: %s\n', boundarySector));
appendText(run.log_path, sprintf('[%s] lower table: %s\n', stampNow(), lowerPath));
appendText(run.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(run.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));

fprintf('Lower-support audit complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Lower table: %s\n', lowerPath);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.lowerTable = lowerTbl;
out.lowerBoundaryK = lowerBoundaryK;
out.boundarySector = string(boundarySector);
out.lowerTablePath = string(lowerPath);
out.boundaryPath = string(boundaryPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'clock_ratio_lower_support_audit');
cfg = setDefault(cfg, 'sourceSupportRun', 'run_2026_03_14_133454_clock_ratio_temperature_support_audit');
cfg = setDefault(cfg, 'fmRunName', 'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefault(cfg, 'dipRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefault(cfg, 'datasetRunName', 'run_2026_03_12_211204_aging_dataset_build');
cfg = setDefault(cfg, 'lowerTemperatureCutoffK', 14);
cfg = setDefault(cfg, 'classificationPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.sourceSupportRun)), 'tables', 'temperature_classification_table.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.fmRunName)), 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.dipRunName)), 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'datasetPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.datasetRunName)), 'tables', 'aging_observable_dataset.csv'));
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
tbl = normalizeNumericColumns(tbl);
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

function row = initLowerRow()
row = struct( ...
    'T', NaN, ...
    'dip_visible', false, ...
    'tau_dip_status', "", ...
    'FM_present', false, ...
    'tau_FM_status', "", ...
    'canonical_R_possible', false, ...
    'exclusion_reason', "");
end

function row = classifyLowerTemperature(tp, lowClassTbl, fmTbl, dipTbl, datasetTbl)
row = initLowerRow();
row.T = tp;

classRow = lowClassTbl(lowClassTbl.Tp == tp, :);
fmRow = fmTbl(fmTbl.Tp == tp, :);
dipRow = dipTbl(dipTbl.Tp == tp, :);
dataRow = datasetTbl(datasetTbl.Tp == tp, :);

dipVisible = false;
if ~isempty(classRow) && ismember('Dip_depth_range_to_peak', classRow.Properties.VariableNames)
    dipVisible = isfinite(classRow.Dip_depth_range_to_peak(1)) && classRow.Dip_depth_range_to_peak(1) > 0;
elseif ~isempty(dataRow) && ismember('Dip_depth', dataRow.Properties.VariableNames)
    y = dataRow.Dip_depth;
    dipVisible = any(isfinite(y) & y > 0);
end
row.dip_visible = dipVisible;

tauDip = nan;
tauDipUpper = nan;
tauHalfStatus = "";
if ~isempty(classRow)
    if ismember('tau_dip_canonical_seconds', classRow.Properties.VariableNames)
        tauDip = classRow.tau_dip_canonical_seconds(1);
    end
    if ismember('tau_dip_upper_bound_seconds', classRow.Properties.VariableNames)
        tauDipUpper = classRow.tau_dip_upper_bound_seconds(1);
    end
    if ismember('tau_half_range_status', classRow.Properties.VariableNames)
        tauHalfStatus = string(classRow.tau_half_range_status(1));
    end
elseif ~isempty(dipRow)
    if ismember('tau_effective_seconds', dipRow.Properties.VariableNames)
        tauDip = dipRow.tau_effective_seconds(1);
    end
    if ismember('tau_half_range_status', dipRow.Properties.VariableNames)
        tauHalfStatus = string(dipRow.tau_half_range_status(1));
    end
end

if isfinite(tauDip) && tauDip > 0
    row.tau_dip_status = "valid";
elseif isfinite(tauDipUpper) && tauDipUpper > 0
    row.tau_dip_status = "censored";
elseif tauHalfStatus == "no_upward_crossing"
    row.tau_dip_status = "unresolved";
elseif dipVisible
    row.tau_dip_status = "unresolved";
else
    row.tau_dip_status = "absent";
end

fmPresent = false;
tauFm = nan;
if ~isempty(fmRow)
    if ismember('has_fm', fmRow.Properties.VariableNames)
        fmPresent = fmRow.has_fm(1) ~= 0;
    end
    if ismember('tau_effective_seconds', fmRow.Properties.VariableNames)
        tauFm = fmRow.tau_effective_seconds(1);
    end
end
if ~fmPresent && ~isempty(dataRow) && ismember('FM_abs', dataRow.Properties.VariableNames)
    fmPresent = any(isfinite(dataRow.FM_abs));
end
row.FM_present = fmPresent;

if isfinite(tauFm) && tauFm > 0 && fmPresent
    unstable = false;
    if ~isempty(fmRow)
        if ismember('fragile_low_point_count', fmRow.Properties.VariableNames)
            unstable = unstable || (fmRow.fragile_low_point_count(1) ~= 0);
        end
        if ismember('tau_half_range_status', fmRow.Properties.VariableNames)
            unstable = unstable || ~(string(fmRow.tau_half_range_status(1)) == "ok");
        end
    end
    if unstable
        row.tau_FM_status = "unstable";
    else
        row.tau_FM_status = "valid";
    end
else
    row.tau_FM_status = "invalid";
end

row.canonical_R_possible = (row.tau_dip_status == "valid") && (row.tau_FM_status == "valid");
if row.canonical_R_possible
    row.exclusion_reason = "";
    return;
end

if row.tau_dip_status == "valid" && row.tau_FM_status ~= "valid"
    row.exclusion_reason = "FM sector missing/invalid below 14 K (FM_abs unavailable, tau_FM not extractable)";
elseif row.tau_dip_status ~= "valid" && row.tau_FM_status == "valid"
    row.exclusion_reason = "dip-sector tau_dip unavailable";
elseif row.tau_dip_status ~= "valid" && row.tau_FM_status ~= "valid"
    row.exclusion_reason = "both sectors unavailable";
else
    row.exclusion_reason = "non-canonical status";
end
end

function sector = inferBoundarySector(lowerTbl, lowerBoundaryK)
below = lowerTbl(lowerTbl.T < lowerBoundaryK, :);
if isempty(below)
    sector = "undetermined";
    return;
end

dipValid = below.tau_dip_status == "valid";
fmValid = below.tau_FM_status == "valid";

if any(dipValid & ~fmValid) && ~any(~dipValid & fmValid)
    sector = "FM";
elseif any(~dipValid & fmValid) && ~any(dipValid & ~fmValid)
    sector = "dip";
elseif any(~dipValid & ~fmValid)
    sector = "both";
else
    sector = "mixed";
end
end

function textOut = buildReportText(runDir, cfg, lowerTbl, lowerBoundaryK, boundarySector, canonicalTp)
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

lines = strings(0, 1);
lines(end + 1) = "# Aging lower-temperature R(T) support audit";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", nowText);
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";

lines(end + 1) = "## Scope";
lines(end + 1) = sprintf("- Source canonical support run: `%s`.", cfg.sourceSupportRun);
lines(end + 1) = sprintf("- Lower-temperature window audited: `T < %.0f K`.", cfg.lowerTemperatureCutoffK);
lines(end + 1) = "";

lines(end + 1) = "## Classification Table";
lines(end + 1) = "| T (K) | dip_visible | tau_dip_status | FM_present | tau_FM_status | canonical_R_possible | exclusion_reason |";
lines(end + 1) = "| ---: | :---: | :--- | :---: | :--- | :---: | :--- |";
for i = 1:height(lowerTbl)
    lines(end + 1) = sprintf("| %.0f | %s | %s | %s | %s | %s | %s |", ...
        lowerTbl.T(i), tfText(lowerTbl.dip_visible(i)), lowerTbl.tau_dip_status(i), ...
        tfText(lowerTbl.FM_present(i)), lowerTbl.tau_FM_status(i), ...
        tfText(lowerTbl.canonical_R_possible(i)), lowerTbl.exclusion_reason(i));
end
lines(end + 1) = "";

lines(end + 1) = "## Lower Boundary Result";
lines(end + 1) = sprintf("- Canonical R(T) support temperatures remain: `%s K`.", fmtTpList(canonicalTp));
lines(end + 1) = sprintf("- True lower canonical boundary: `%.0f K`.", lowerBoundaryK);
lines(end + 1) = sprintf("- Boundary-setting sector: `%s`.", boundarySector);
lines(end + 1) = "";

lines(end + 1) = "## Interpretation";
if boundarySector == "FM"
    lines(end + 1) = "- Dip-sector tau_dip is already valid below 14 K, but FM-sector tau_FM is missing/invalid there.";
    lines(end + 1) = "- Therefore the lower bound is set by FM availability/extractability, not dip visibility.";
elseif boundarySector == "dip"
    lines(end + 1) = "- FM-sector is available below the boundary while dip-sector tau_dip fails.";
    lines(end + 1) = "- Therefore the lower bound is set by dip extraction.";
else
    lines(end + 1) = "- Both sectors contribute to the lower-bound exclusion below 14 K.";
end
lines(end + 1) = "";

lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/lower_temperature_classification.csv`";
lines(end + 1) = "- `tables/lower_boundary_summary.csv`";
lines(end + 1) = "- `reports/aging_clock_ratio_lower_support_audit_report.md`";
lines(end + 1) = "- `review/aging_clock_ratio_lower_support_audit_bundle.zip`";

textOut = strjoin(lines, newline);
end

function out = tfText(tf)
if tf
    out = "yes";
else
    out = "no";
end
end

function txt = fmtTpList(tp)
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
    fullfile(runDir, 'tables', 'lower_temperature_classification.csv'), ...
    fullfile(runDir, 'tables', 'lower_boundary_summary.csv'), ...
    fullfile(runDir, 'reports', 'aging_clock_ratio_lower_support_audit_report.md')};
existing = items(cellfun(@(p) exist(p, 'file') == 2, items));
if isempty(existing)
    return;
end
zip(zipPath, existing, runDir);
end
