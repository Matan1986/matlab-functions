function out = aging_clock_ratio_temperature_scaling(cfg)
% aging_clock_ratio_temperature_scaling
% Test temperature power-law scaling of the Aging clock ratio:
%
%   R(T) = tau_FM(T) / tau_dip(T)
%
% Fit model:
%   log(R) = a + eta * log(T)
%
% using only temperatures where both clocks are defined and positive.
%
% Expected canonical overlap: 14, 18, 22, 26 K.
%
% Outputs:
%   tables/aging_clock_ratio_temperature_scaling.csv   (fit metrics)
%   tables/clock_ratio_data.csv                        (per-T data)
%   figures/R_vs_T.png
%   figures/logR_vs_logT.png
%   reports/aging_clock_ratio_temperature_scaling_report.md
%   review/aging_clock_ratio_temperature_scaling_bundle.zip

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

assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'FM tau table not found: %s', cfg.fmTauPath);

runCfg = struct();
runCfg.runLabel = char(string(cfg.runLabel));
runCfg.dip_source = char(string(cfg.dipRunName));
runCfg.fm_source = char(string(cfg.fmRunName));
run = createRunContext('aging', runCfg);
runDir = run.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging clock ratio temperature scaling run root:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] aging_clock_ratio_temperature_scaling started\n', stampNow()));
appendText(run.log_path, sprintf('dipTauPath: %s\n', cfg.dipTauPath));
appendText(run.log_path, sprintf('fmTauPath: %s\n', cfg.fmTauPath));

% --- Load and merge tables ---
dipTbl = loadTauTable(cfg.dipTauPath, 'tau_dip_seconds');
fmTbl  = loadTauTable(cfg.fmTauPath,  'tau_FM_seconds');

dataTbl = mergeTables(dipTbl, fmTbl);

% --- Step 3: keep only rows where both clocks are positive and finite ---
validMask = isfinite(dataTbl.tau_dip_seconds) & dataTbl.tau_dip_seconds > 0 & ...
            isfinite(dataTbl.tau_FM_seconds)  & dataTbl.tau_FM_seconds  > 0;
dataTbl = dataTbl(validMask, :);

assert(height(dataTbl) >= 2, 'Too few valid overlap temperatures to fit (found %d).', height(dataTbl));

% --- Step 4: compute ratio and log quantities ---
dataTbl.R         = dataTbl.tau_FM_seconds ./ dataTbl.tau_dip_seconds;
dataTbl.logT      = log(dataTbl.T_K);
dataTbl.logR      = log(dataTbl.R);
dataTbl.R_age_clock_ratio = dataTbl.R;

% --- Step 5: fit logR = a + eta * logT ---
fitResult = fitPowerLaw(dataTbl.logT, dataTbl.logR);

% --- Step 6: extract metrics table ---
metricsTbl = buildMetricsTable(fitResult);

identBundle = ['dip_tau_path=' char(string(cfg.dipTauPath)) ';fm_tau_path=' char(string(cfg.fmTauPath))];
metaRows = struct( ...
    'writer_family_id', 'WF_CLOCK_RATIO_R_AGE', ...
    'tau_or_R_flag', 'R', ...
    'tau_domain', 'AGING_CLOCK_RATIO_TEMPERATURE_SCALING', ...
    'tau_input_observable_identities', identBundle, ...
    'tau_input_observable_family', 'tau_FM_over_tau_dip_from_pair_files', ...
    'source_writer_script', 'Aging/analysis/aging_clock_ratio_temperature_scaling.m', ...
    'source_artifact_basename', 'clock_ratio_data.csv', ...
    'source_artifact_path', fullfile(runDir, 'tables', 'clock_ratio_data.csv'), ...
    'canonical_status', 'non_canonical_pending_lineage', ...
    'model_use_allowed', 'NO_UNLESS_PAIR_FILES_LINEAGE_LOCKED', ...
    'semantic_status', 'R_column_legacy_alias_use_R_age_clock_ratio_duplicate', ...
    'lineage_status', 'REQUIRES_DIP_FM_SOURCE_RUN_AND_DATASET_IDENTITY');
dataTbl = appendF7GTauRMetadataColumns(dataTbl, metaRows);

metaFit = metaRows;
metaFit.source_artifact_basename = 'aging_clock_ratio_temperature_scaling.csv';
metaFit.source_artifact_path = fullfile(runDir, 'tables', 'aging_clock_ratio_temperature_scaling.csv');
metaFit.tau_or_R_flag = 'R';
metaFit.semantic_status = 'POWER_LAW_FIT_SUMMARY_METADATA_NOT_ROWWISE_RATIO';
metricsTbl = appendF7GTauRMetadataColumns(metricsTbl, metaFit);

% --- Save tables ---
dataTablePath    = save_run_table(dataTbl, 'clock_ratio_data.csv', runDir);
metricsTablePath = save_run_table(metricsTbl, ...
    'aging_clock_ratio_temperature_scaling.csv', runDir);

% --- Step 7: generate figures ---
figRvsT = makeRvsTFigure(dataTbl, cfg);
set(figRvsT, 'Name', 'R_vs_T');
figRvsTpaths = save_run_figure(figRvsT, 'R_vs_T', runDir);
close(figRvsT);

figLogLog = makeLogLogFigure(dataTbl, fitResult, cfg);
set(figLogLog, 'Name', 'logR_vs_logT');
figLogLogPaths = save_run_figure(figLogLog, 'logR_vs_logT', runDir);
close(figLogLog);

% --- Step 9: report ---
reportText = buildReportText(runDir, cfg, dataTbl, fitResult, metricsTbl, run.run_id);
reportPath = save_run_report(reportText, ...
    'aging_clock_ratio_temperature_scaling_report.md', runDir);

% --- Step 11: ZIP bundle ---
zipPath = buildReviewZip(runDir, 'aging_clock_ratio_temperature_scaling_bundle.zip');

% --- Log completion ---
appendText(run.log_path, sprintf('[%s] data table: %s\n', stampNow(), dataTablePath));
appendText(run.log_path, sprintf('[%s] metrics table: %s\n', stampNow(), metricsTablePath));
appendText(run.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(run.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));
appendText(run.notes_path, sprintf('N_valid_T = %d   Temperatures: %s K\n', ...
    height(dataTbl), char(strjoin(compose('%.0f', dataTbl.T_K.'), ', '))));
appendText(run.notes_path, sprintf('eta = %.4g   R2 = %.4f   RMSE = %.4g\n', ...
    fitResult.eta, fitResult.R2, fitResult.RMSE));

fprintf('\n--- Aging clock ratio temperature scaling complete ---\n');
fprintf('RUN_ID: %s\n', run.run_id);
fprintf('eta    = %.4g\n', fitResult.eta);
fprintf('R2     = %.4f\n', fitResult.R2);
fprintf('RMSE   = %.4g\n', fitResult.RMSE);
fprintf('N_points = %d\n', fitResult.N_points);
fprintf('Temperatures used: %s K\n', ...
    char(strjoin(compose('%.0f', dataTbl.T_K.'), ', ')));
fprintf('Run root: %s\n', runDir);
fprintf('Metrics table: %s\n', metricsTablePath);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run        = run;
out.runDir     = string(runDir);
out.run_id     = string(run.run_id);
out.dataTable  = dataTbl;
out.fitResult  = fitResult;
out.metricsTable = metricsTbl;
out.dataTablePath    = string(dataTablePath);
out.metricsTablePath = string(metricsTablePath);
out.reportPath       = string(reportPath);
out.zipPath          = string(zipPath);
out.figures = struct( ...
    'R_vs_T',      string(figRvsTpaths.png), ...
    'logR_vs_logT', string(figLogLogPaths.png));
end

% =========================================================================
%  Configuration defaults
% =========================================================================

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'aging_clock_ratio_temperature_scaling');
cfg = setDefault(cfg, 'dipRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefault(cfg, 'fmRunName',  'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.dipRunName)), 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.fmRunName)),  'tables', 'tau_FM_vs_Tp.csv'));

colors = struct();
colors.dip    = [0.11 0.53 0.28];
colors.fm     = [0.80 0.26 0.15];
colors.ratio  = [0.12 0.35 0.72];
colors.fit    = [0.25 0.25 0.25];
cfg = setDefault(cfg, 'colors', colors);
end

% =========================================================================
%  Data loading and merging
% =========================================================================

function tbl = loadTauTable(pathStr, outputCol)
% Load a tau CSV (tau_vs_Tp or tau_FM_vs_Tp) and return a two-column table
% with columns T_K and <outputCol>.
raw = readtable(pathStr, 'Delimiter', ',', 'ReadVariableNames', true, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
raw = normalizeNumericColumns(raw);

assert(ismember('Tp', raw.Properties.VariableNames), ...
    'Tau table missing Tp column: %s', pathStr);
assert(ismember('tau_effective_seconds', raw.Properties.VariableNames), ...
    'Tau table missing tau_effective_seconds column: %s', pathStr);

T_K  = raw.Tp;
tau  = raw.tau_effective_seconds;

tbl = table(T_K, tau, 'VariableNames', {'T_K', outputCol});
tbl = sortrows(tbl, 'T_K');
end

function merged = mergeTables(dipTbl, fmTbl)
% Inner join on T_K: keep only temperatures present in both tables.
allT = unique([dipTbl.T_K; fmTbl.T_K], 'sorted');
T_K             = allT;
tau_dip_seconds = nan(numel(allT), 1);
tau_FM_seconds  = nan(numel(allT), 1);

for i = 1:numel(allT)
    t = allT(i);
    dRow = dipTbl(abs(dipTbl.T_K - t) < 1e-9, :);
    fRow = fmTbl(abs(fmTbl.T_K - t) < 1e-9, :);
    if ~isempty(dRow)
        tau_dip_seconds(i) = dRow.tau_dip_seconds(1);
    end
    if ~isempty(fRow)
        tau_FM_seconds(i) = fRow.tau_FM_seconds(1);
    end
end

merged = table(T_K, tau_dip_seconds, tau_FM_seconds);
end

function tbl = normalizeNumericColumns(tbl)
for i = 1:numel(tbl.Properties.VariableNames)
    vn = tbl.Properties.VariableNames{i};
    if isnumeric(tbl.(vn)) || islogical(tbl.(vn))
        continue;
    end
    raw    = string(tbl.(vn));
    values = str2double(erase(raw, '"'));
    missing = ismissing(raw) | strcmpi(strtrim(raw), 'NaN') | strlength(strtrim(raw)) == 0;
    if all(isfinite(values) | missing)
        tbl.(vn) = values;
    end
end
end

% =========================================================================
%  Power-law fit:  logR = a + eta * logT  (natural log)
% =========================================================================

function fit = fitPowerLaw(logT, logR)
fit = struct();
fit.N_points = numel(logT);
fit.eta      = NaN;
fit.a        = NaN;
fit.R2       = NaN;
fit.RMSE     = NaN;
fit.status   = 'insufficient_data';

if numel(logT) < 2
    return;
end

% polyfit: coeffs(1) = eta (slope), coeffs(2) = a (intercept)
coeffs = polyfit(logT, logR, 1);
fit.eta = coeffs(1);
fit.a   = coeffs(2);

logR_hat = polyval(coeffs, logT);
residuals = logR - logR_hat;
SS_res = sum(residuals .^ 2);
SS_tot = sum((logR - mean(logR)) .^ 2);

fit.RMSE   = sqrt(SS_res / numel(residuals));
if SS_tot > 0
    fit.R2 = 1 - SS_res / SS_tot;
else
    fit.R2 = NaN;
end
fit.logT_fit = logT;
fit.logR_fit = logR_hat;
fit.status = 'ok';
end

% =========================================================================
%  Output tables
% =========================================================================

function tbl = buildMetricsTable(fit)
slope_eta   = fit.eta;
intercept_a = fit.a;
R2          = fit.R2;
RMSE        = fit.RMSE;
N_points    = fit.N_points;
tbl = table(slope_eta, intercept_a, R2, RMSE, N_points);
end

% =========================================================================
%  Figures
% =========================================================================

function fig = makeRvsTFigure(dataTbl, cfg)
fig = newFigure([3 3 14 10], 'off');
ax = axes(fig);
hold(ax, 'on');

T = dataTbl.T_K;
R = dataTbl.R;

plot(ax, T, R, '-o', 'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'LineWidth', 2.2, 'MarkerSize', 8, 'DisplayName', 'R(T) = \tau_{FM}/\tau_{dip}');

for i = 1:numel(T)
    text(ax, T(i), R(i)*1.12, sprintf('%.0f K', T(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', cfg.colors.ratio);
end

% unity line for reference
xlims = [min(T)*0.9, max(T)*1.1];
yline(ax, 1, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.4, ...
    'DisplayName', 'R = 1 (clock parity)');

xlabel(ax, 'T_p (K)', 'FontSize', 14);
ylabel(ax, 'R = \tau_{FM} / \tau_{dip}', 'FontSize', 14);
title(ax, 'Aging clock ratio vs temperature', 'FontSize', 14);
legend(ax, 'Location', 'northwest', 'FontSize', 12);
set(ax, 'FontSize', 13, 'LineWidth', 1.5, 'TickDir', 'out', 'Box', 'off', ...
    'XLim', xlims);
grid(ax, 'on');
end

function fig = makeLogLogFigure(dataTbl, fitResult, cfg)
fig = newFigure([3 3 14 10], 'off');
ax = axes(fig);
hold(ax, 'on');

logT = dataTbl.logT;
logR = dataTbl.logR;

% Data points
plot(ax, logT, logR, 'o', 'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'MarkerSize', 9, 'LineWidth', 1.5, 'DisplayName', 'log R vs log T');

% Fit line
if strcmp(fitResult.status, 'ok')
    logT_smooth = linspace(min(logT)*0.98, max(logT)*1.02, 100);
    logR_smooth = fitResult.a + fitResult.eta * logT_smooth;
    plot(ax, logT_smooth, logR_smooth, '-', 'Color', cfg.colors.fit, ...
        'LineWidth', 2.2, ...
        'DisplayName', sprintf('Fit: log R = %.3g + %.3g \\cdot log T', ...
            fitResult.a, fitResult.eta));
    % Annotation
    annotation_str = sprintf('\\eta = %.3g\nR^2 = %.4f\nRMSE = %.3g\nN = %d', ...
        fitResult.eta, fitResult.R2, fitResult.RMSE, fitResult.N_points);
    text(ax, 0.05, 0.95, annotation_str, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'BackgroundColor', [1 1 1], 'Margin', 5);
end

% Temperature labels next to points
T = dataTbl.T_K;
for i = 1:numel(T)
    text(ax, logT(i), logR(i) + 0.08*(max(logR)-min(logR)), ...
        sprintf('%.0f K', T(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', cfg.colors.ratio);
end

xlabel(ax, 'log(T_p / K)', 'FontSize', 14);
ylabel(ax, 'log(R) = log(\tau_{FM}/\tau_{dip})', 'FontSize', 14);
title(ax, 'log R vs log T: power-law scaling test', 'FontSize', 14);
legend(ax, 'Location', 'southeast', 'FontSize', 12);
set(ax, 'FontSize', 13, 'LineWidth', 1.5, 'TickDir', 'out', 'Box', 'off');
grid(ax, 'on');
end

% =========================================================================
%  Report
% =========================================================================

function txt = buildReportText(runDir, cfg, dataTbl, fitResult, metricsTbl, runId)
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
T = dataTbl.T_K;
R = dataTbl.R;

lines = strings(0, 1);
lines(end+1) = "# Aging clock ratio temperature scaling";
lines(end+1) = "";
lines(end+1) = sprintf("Generated: %s", nowText);
lines(end+1) = sprintf("Run root: `%s`", runDir);
lines(end+1) = "";

lines(end+1) = "## Summary";
lines(end+1) = sprintf("- **RUN_ID**: `%s`", runId);
lines(end+1) = sprintf("- **eta (power-law exponent)**: %.4g", fitResult.eta);
lines(end+1) = sprintf("- **intercept a**: %.4g", fitResult.a);
lines(end+1) = sprintf("- **R²**: %.4f", fitResult.R2);
lines(end+1) = sprintf("- **RMSE** (in ln units): %.4g", fitResult.RMSE);
lines(end+1) = sprintf("- **N_points**: %d", fitResult.N_points);
lines(end+1) = "";

lines(end+1) = "## Data Sources";
lines(end+1) = sprintf("- Dip clock: `%s`", cfg.dipTauPath);
lines(end+1) = sprintf("- FM clock:  `%s`", cfg.fmTauPath);
lines(end+1) = "";

lines(end+1) = "## Temperatures Used";
lines(end+1) = sprintf("Canonical overlap temperatures: **%s K**", ...
    char(strjoin(compose('%.0f', T.'), ', ')));
lines(end+1) = "";
lines(end+1) = "| T_p (K) | tau_dip (s) | tau_FM (s) | R = tau_FM/tau_dip | log(T) | log(R) |";
lines(end+1) = "| ---: | ---: | ---: | ---: | ---: | ---: |";
for i = 1:height(dataTbl)
    lines(end+1) = sprintf("| %.0f | %.4g | %.4g | %.4g | %.4f | %.4f |", ...
        dataTbl.T_K(i), dataTbl.tau_dip_seconds(i), dataTbl.tau_FM_seconds(i), ...
        R(i), dataTbl.logT(i), dataTbl.logR(i));
end
lines(end+1) = "";

lines(end+1) = "## Power-Law Fit";
lines(end+1) = "The model is:";
lines(end+1) = "";
lines(end+1) = "```";
lines(end+1) = "log(R) = a + eta * log(T)";
lines(end+1) = "R(T)   = exp(a) * T^eta";
lines(end+1) = "```";
lines(end+1) = "";
lines(end+1) = sprintf("Fit result: `log(R) = %.4g + %.4g * log(T)`", fitResult.a, fitResult.eta);
lines(end+1) = "";
lines(end+1) = "| Metric | Value |";
lines(end+1) = "| :--- | ---: |";
lines(end+1) = sprintf("| slope_eta | %.4g |", fitResult.eta);
lines(end+1) = sprintf("| intercept_a | %.4g |", fitResult.a);
lines(end+1) = sprintf("| R² | %.4f |", fitResult.R2);
lines(end+1) = sprintf("| RMSE (ln units) | %.4g |", fitResult.RMSE);
lines(end+1) = sprintf("| N_points | %d |", fitResult.N_points);
lines(end+1) = "";

lines(end+1) = "## Interpretation";
lines(end+1) = interpretResult(fitResult, dataTbl);
lines(end+1) = "";

lines(end+1) = "## Figures";
lines(end+1) = "- `figures/R_vs_T.png`: ratio R(T) vs temperature, linear scale with unity reference line.";
lines(end+1) = "- `figures/logR_vs_logT.png`: log(R) vs log(T) with power-law fit line and fit annotation.";
lines(end+1) = "";

lines(end+1) = "## Outputs";
lines(end+1) = "- `tables/clock_ratio_data.csv`";
lines(end+1) = "- `tables/aging_clock_ratio_temperature_scaling.csv`";
lines(end+1) = "- `figures/R_vs_T.png`";
lines(end+1) = "- `figures/logR_vs_logT.png`";
lines(end+1) = "- `reports/aging_clock_ratio_temperature_scaling_report.md`";
lines(end+1) = "- `review/aging_clock_ratio_temperature_scaling_bundle.zip`";

txt = strjoin(lines, newline);
end

function interp = interpretResult(fitResult, dataTbl)
lines = strings(0, 1);
eta = fitResult.eta;
R2  = fitResult.R2;
N   = fitResult.N_points;
R   = dataTbl.R;

% Quality
if isfinite(R2) && R2 >= 0.99
    qualityStr = "excellent (R² ≥ 0.99)";
elseif isfinite(R2) && R2 >= 0.95
    qualityStr = "good (R² ≥ 0.95)";
elseif isfinite(R2) && R2 >= 0.85
    qualityStr = "moderate (R² ≥ 0.85)";
else
    qualityStr = "poor (R² < 0.85 or undefined)";
end

lines(end+1) = sprintf("The clock ratio R(T) = tau_FM / tau_dip spans from R = %.3g at %.0f K " + ...
    "to R = %.3g at %.0f K across the %d canonical overlap temperatures.", ...
    min(R), dataTbl.T_K(R == min(R)), max(R), dataTbl.T_K(R == max(R)), N);
lines(end+1) = "";

lines(end+1) = sprintf("**Power-law fit quality:** %s.", qualityStr);
lines(end+1) = "";

if isfinite(eta)
    if abs(eta) < 0.5
        lines(end+1) = sprintf("**Scaling regime:** The exponent eta = %.3g is near zero, " + ...
            "indicating R(T) is approximately temperature-independent (flat ratio). " + ...
            "The two clocks track each other nearly proportionally across temperature.", eta);
    elseif eta > 0 && eta < 3
        lines(end+1) = sprintf("**Scaling regime:** The exponent eta = %.3g indicates " + ...
            "moderate super-linear growth of R(T) with temperature. " + ...
            "The FM clock accelerates faster than the dip clock as T increases.", eta);
    elseif eta >= 3 && eta < 8
        lines(end+1) = sprintf("**Scaling regime:** The exponent eta = %.3g indicates " + ...
            "strong super-linear (steep power-law) growth of R(T) with temperature. " + ...
            "The FM sector becomes dramatically slower relative to the AFM dip clock at higher T.", eta);
    elseif eta >= 8
        lines(end+1) = sprintf("**Scaling regime:** The exponent eta = %.3g is very large, " + ...
            "consistent with a divergent or near-divergent separation of the two " + ...
            "timescale sectors approaching the FM phase boundary. " + ...
            "R(T) exhibits extremely steep temperature power-law scaling.", eta);
    elseif eta < 0 && eta > -3
        lines(end+1) = sprintf("**Scaling regime:** The exponent eta = %.3g indicates " + ...
            "that R(T) decreases with temperature (FM clock relatively faster at low T).", eta);
    else
        lines(end+1) = sprintf("**Scaling regime:** eta = %.3g (unusual negative value).", eta);
    end
end
lines(end+1) = "";
lines(end+1) = sprintf("**Physical interpretation:** R > 1 at high T indicates that the FM " + ...
    "relaxation channel takes significantly longer than the AFM memory recovery at the " + ...
    "same stopping temperature. The steep temperature dependence (if confirmed by eta >> 1) " + ...
    "suggests that the FM sector dynamics are governed by a different (slower) " + ...
    "characteristic energy scale than the AFM dip clock, leading to an " + ...
    "anomalous amplification of R(T) near the FM-AFM boundary.");

interp = strjoin(lines, newline);
end

% =========================================================================
%  Infrastructure utilities (local copies — no dependency on external files)
% =========================================================================

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    p = fullfile(runDir, char(folderName));
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
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

function fig = newFigure(positionCm, visibilityMode)
if exist('create_figure', 'file') == 2
    fig = create_figure('Visible', visibilityMode, 'Position', positionCm);
else
    fig = figure('Visible', visibilityMode, 'Color', 'w', ...
        'Units', 'centimeters', 'Position', positionCm);
end
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

collectDirs = {'figures', 'tables', 'reports'};
filesToZip = {};
for k = 1:numel(collectDirs)
    d = fullfile(runDir, collectDirs{k});
    if exist(d, 'dir') == 7
        items = dir(fullfile(d, '*'));
        for j = 1:numel(items)
            if ~items(j).isdir
                filesToZip{end+1} = fullfile(d, items(j).name); %#ok<AGROW>
            end
        end
    end
end

manifest = fullfile(runDir, 'run_manifest.json');
if exist(manifest, 'file') == 2
    filesToZip{end+1} = manifest;
end
notes = fullfile(runDir, 'run_notes.txt');
if exist(notes, 'file') == 2
    filesToZip{end+1} = notes;
end

if ~isempty(filesToZip)
    zip(zipPath, filesToZip);
end
end
