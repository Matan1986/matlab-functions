function out = switching_ridge_motion_decomposition(cfg)
% switching_ridge_motion_decomposition
% Decompose ridge motion derivative dI_peak/dT into contributions from:
% X(T), width(T), and S_peak(T), where I_peak = X * width * S_peak.

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
runCfg.dataset = sprintf('switch:%s', char(source.switchRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching ridge-motion decomposition run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching ridge-motion decomposition started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));

data = loadSwitchingData(source.switchRunDir, cfg);
T = data.T_K(:);
I = data.I_peak_mA(:);
w = data.width_mA(:);
S = data.S_peak(:);
X = I ./ (w .* S);

[dIraw, dIsmooth, Ismooth, methodI] = derivativeProfiles(T, I, cfg);
[dwRaw, dwSmooth, wSmooth, methodW] = derivativeProfiles(T, w, cfg);
[dSRaw, dSSmooth, SSmooth, methodS] = derivativeProfiles(T, S, cfg);
[dXRaw, dXSmooth, XSmooth, methodX] = derivativeProfiles(T, X, cfg);

termX = dXSmooth .* wSmooth .* SSmooth;
termW = XSmooth .* dwSmooth .* SSmooth;
termS = XSmooth .* wSmooth .* dSSmooth;
sumTerms = termX + termW + termS;
residual = dIsmooth - sumTerms;

[fracXSigned, fracWSigned, fracSSigned] = signedFractions(termX, termW, termS, sumTerms);
[fracXAbs, fracWAbs, fracSAbs] = absoluteFractions(termX, termW, termS);
dominant = dominantComponentByPoint(termX, termW, termS);

contribTbl = table( ...
    T, I, w, S, X, ...
    Ismooth, wSmooth, SSmooth, XSmooth, ...
    dIraw, dIsmooth, ...
    dwRaw, dwSmooth, ...
    dSRaw, dSSmooth, ...
    dXRaw, dXSmooth, ...
    termX, termW, termS, sumTerms, residual, ...
    fracXSigned, fracWSigned, fracSSigned, ...
    fracXAbs, fracWAbs, fracSAbs, ...
    dominant, ...
    'VariableNames', { ...
    'T_K', ...
    'I_peak_mA', 'width_mA', 'S_peak', 'X', ...
    'I_peak_smoothed_mA', 'width_smoothed_mA', 'S_peak_smoothed', 'X_smoothed', ...
    'dI_peak_dT_raw_mA_per_K', 'dI_peak_dT_smoothed_mA_per_K', ...
    'dwidth_dT_raw_mA_per_K', 'dwidth_dT_smoothed_mA_per_K', ...
    'dS_peak_dT_raw_per_K', 'dS_peak_dT_smoothed_per_K', ...
    'dX_dT_raw_per_K', 'dX_dT_smoothed_per_K', ...
    'term_X_mA_per_K', 'term_width_mA_per_K', 'term_S_peak_mA_per_K', ...
    'sum_terms_mA_per_K', 'decomposition_residual_mA_per_K', ...
    'frac_X_signed', 'frac_width_signed', 'frac_S_peak_signed', ...
    'frac_X_abs', 'frac_width_abs', 'frac_S_peak_abs', ...
    'dominant_component'});

regionTbl = buildRegionSummary(T, dIsmooth, residual, termX, termW, termS, fracXAbs, fracWAbs, fracSAbs, cfg);

manifestTbl = table( ...
    string({'switching_full_scaling_parameters'}), ...
    source.switchRunName, ...
    string({source.switchPath}), ...
    string({'I_peak(T), width(T), S_peak(T) source table'}), ...
    string({sprintf('I:%s | w:%s | S:%s | X:%s', methodI, methodW, methodS, methodX)}), ...
    'VariableNames', {'source_role', 'source_run', 'source_file', 'role_note', 'smoothing'});

contribPath = save_run_table(contribTbl, 'ridge_motion_contributions_vs_temperature.csv', runDir);
regionPath = save_run_table(regionTbl, 'ridge_motion_region_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figPath = saveDecompositionFigure(T, dIsmooth, sumTerms, termX, termW, termS, fracXAbs, fracWAbs, fracSAbs, runDir);

reportText = buildReportText(source, cfg, methodI, methodW, methodS, methodX, regionTbl, ...
    contribPath, regionPath, figPath);
reportPath = save_run_report(reportText, 'report.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_ridge_motion_decomposition_bundle.zip');

appendText(run.notes_path, sprintf('Source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('Derivative smoothing = I:%s | w:%s | S:%s | X:%s\n', methodI, methodW, methodS, methodX));
appendText(run.notes_path, sprintf('Contributions table = %s\n', contribPath));
appendText(run.notes_path, sprintf('Region summary = %s\n', regionPath));
appendText(run.notes_path, sprintf('Figure = %s\n', figPath.png));
appendText(run.notes_path, sprintf('Report = %s\n', reportPath));

appendText(run.log_path, sprintf('[%s] switching ridge-motion decomposition complete\n', stampNow()));
appendText(run.log_path, sprintf('Contributions table: %s\n', contribPath));
appendText(run.log_path, sprintf('Region summary table: %s\n', regionPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Figure: %s\n', figPath.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.paths = struct( ...
    'contributions', string(contribPath), ...
    'regionSummary', string(regionPath), ...
    'manifest', string(manifestPath), ...
    'figure', string(figPath.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching ridge-motion decomposition complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Contributions table: %s\n', contribPath);
fprintf('Region summary table: %s\n', regionPath);
fprintf('Figure: %s\n', figPath.png);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_ridge_motion_decomposition');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefaultField(cfg, 'sgolayFrameLength', 5);
cfg = setDefaultField(cfg, 'movmeanWindow', 3);
cfg = setDefaultField(cfg, 'lowTSectorMinK', 8);
cfg = setDefaultField(cfg, 'lowTSectorMaxK', 12);
cfg = setDefaultField(cfg, 'cross26SectorMinK', 24);
cfg = setDefaultField(cfg, 'cross26SectorMaxK', 28);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.switchPath = fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');

if exist(source.switchRunDir, 'dir') ~= 7
    error('Required switching run directory not found: %s', source.switchRunDir);
end
if exist(source.switchPath, 'file') ~= 2
    error('Required switching source file not found: %s', source.switchPath);
end
end

function data = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.T_K) & isfinite(tbl.Ipeak_mA) & isfinite(tbl.width_chosen_mA) & isfinite(tbl.S_peak);
tbl = sortrows(tbl(mask, :), 'T_K');
if height(tbl) < 5
    error('Need at least 5 valid temperature rows after filtering.');
end

data = struct();
data.T_K = double(tbl.T_K(:));
data.I_peak_mA = double(tbl.Ipeak_mA(:));
data.width_mA = double(tbl.width_chosen_mA(:));
data.S_peak = double(tbl.S_peak(:));
end

function [dRaw, dSmooth, ySmooth, methodText] = derivativeProfiles(x, y, cfg)
x = x(:);
y = y(:);
dRaw = gradient(y, x);
ySmooth = y;
methodText = "none";

n = numel(y);
frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0
    frame = frame - 1;
end
poly = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

if exist('sgolayfilt', 'file') == 2 && frame >= 3 && frame > poly
    try
        ySmooth = sgolayfilt(y, poly, frame);
        methodText = sprintf('sgolayfilt(p=%d,frame=%d)', poly, frame);
    catch
        ySmooth = y;
    end
end

if strcmp(methodText, "none")
    w = min(max(1, round(cfg.movmeanWindow)), n);
    if mod(w, 2) == 0 && w > 1
        w = w - 1;
    end
    if w > 1
        ySmooth = smoothdata(y, 'movmean', w, 'omitnan');
        methodText = sprintf('movmean(window=%d)', w);
    end
end

dSmooth = gradient(ySmooth, x);
end

function [fx, fw, fs] = signedFractions(termX, termW, termS, denom)
fx = safeDivide(termX, denom);
fw = safeDivide(termW, denom);
fs = safeDivide(termS, denom);
end

function [fx, fw, fs] = absoluteFractions(termX, termW, termS)
den = abs(termX) + abs(termW) + abs(termS);
fx = safeDivide(abs(termX), den);
fw = safeDivide(abs(termW), den);
fs = safeDivide(abs(termS), den);
end

function y = safeDivide(a, b)
y = NaN(size(a));
mask = isfinite(a) & isfinite(b) & abs(b) > 1e-12;
y(mask) = a(mask) ./ b(mask);
end

function labels = dominantComponentByPoint(termX, termW, termS)
labels = strings(size(termX));
for i = 1:numel(termX)
    vals = [abs(termX(i)), abs(termW(i)), abs(termS(i))];
    if any(~isfinite(vals))
        labels(i) = "undefined";
        continue;
    end
    [~, idx] = max(vals);
    switch idx
        case 1
            labels(i) = "X_dynamics";
        case 2
            labels(i) = "width_reshaping";
        otherwise
            labels(i) = "S_peak_amplitude";
    end
end
end

function regionTbl = buildRegionSummary(T, dIsmooth, residual, termX, termW, termS, fracXAbs, fracWAbs, fracSAbs, cfg)
regions = {
    'lowT_around_10K', cfg.lowTSectorMinK, cfg.lowTSectorMaxK;
    'crossover_around_26K', cfg.cross26SectorMinK, cfg.cross26SectorMaxK;
    'full_temperature_range', min(T), max(T)
    };

nR = size(regions, 1);
rows = repmat(struct( ...
    'region_name', "", 'T_min_K', NaN, 'T_max_K', NaN, 'n_points', NaN, ...
    'mean_dI_peak_dT_smoothed_mA_per_K', NaN, 'mean_residual_mA_per_K', NaN, ...
    'sum_abs_term_X_mA_per_K', NaN, 'sum_abs_term_width_mA_per_K', NaN, 'sum_abs_term_S_peak_mA_per_K', NaN, ...
    'mean_abs_fraction_X', NaN, 'mean_abs_fraction_width', NaN, 'mean_abs_fraction_S_peak', NaN, ...
    'dominant_component', "", 'dominant_share_abs', NaN), nR, 1);

for i = 1:nR
    name = string(regions{i, 1});
    tMin = regions{i, 2};
    tMax = regions{i, 3};
    mask = T >= tMin & T <= tMax & isfinite(dIsmooth) & isfinite(termX) & isfinite(termW) & isfinite(termS);

    rows(i).region_name = name;
    rows(i).T_min_K = tMin;
    rows(i).T_max_K = tMax;
    rows(i).n_points = nnz(mask);
    rows(i).mean_dI_peak_dT_smoothed_mA_per_K = mean(dIsmooth(mask), 'omitnan');
    rows(i).mean_residual_mA_per_K = mean(residual(mask), 'omitnan');
    rows(i).sum_abs_term_X_mA_per_K = sum(abs(termX(mask)), 'omitnan');
    rows(i).sum_abs_term_width_mA_per_K = sum(abs(termW(mask)), 'omitnan');
    rows(i).sum_abs_term_S_peak_mA_per_K = sum(abs(termS(mask)), 'omitnan');
    rows(i).mean_abs_fraction_X = mean(fracXAbs(mask), 'omitnan');
    rows(i).mean_abs_fraction_width = mean(fracWAbs(mask), 'omitnan');
    rows(i).mean_abs_fraction_S_peak = mean(fracSAbs(mask), 'omitnan');

    absSums = [rows(i).sum_abs_term_X_mA_per_K, rows(i).sum_abs_term_width_mA_per_K, rows(i).sum_abs_term_S_peak_mA_per_K];
    den = sum(absSums, 'omitnan');
    if ~isfinite(den) || den <= 0
        rows(i).dominant_component = "undefined";
        rows(i).dominant_share_abs = NaN;
    else
        [mx, idx] = max(absSums);
        rows(i).dominant_share_abs = mx ./ den;
        switch idx
            case 1
                rows(i).dominant_component = "X_dynamics";
            case 2
                rows(i).dominant_component = "width_reshaping";
            otherwise
                rows(i).dominant_component = "S_peak_amplitude";
        end
    end
end

regionTbl = struct2table(rows);
end

function figPaths = saveDecompositionFigure(T, dIsmooth, sumTerms, termX, termW, termS, fracXAbs, fracWAbs, fracSAbs, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 16 12]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, T, dIsmooth, '-o', 'LineWidth', 2.3, 'MarkerSize', 5, ...
    'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], 'DisplayName', 'dI_{peak}/dT (smoothed)');
plot(ax1, T, termX, '-s', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'DisplayName', '(dX/dT) w S');
plot(ax1, T, termW, '-d', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', 'X (dw/dT) S');
plot(ax1, T, termS, '-^', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.47 0.67 0.19], 'MarkerFaceColor', [0.47 0.67 0.19], 'DisplayName', 'X w (dS_{peak}/dT)');
plot(ax1, T, sumTerms, '--', 'LineWidth', 2.0, 'Color', [0.45 0.45 0.45], 'DisplayName', 'sum of decomposition terms');
xline(ax1, 10, ':', '10 K', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
xline(ax1, 26, ':', '26 K', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
hold(ax1, 'off');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Derivative contribution (mA/K)');
title(ax1, 'Ridge-motion derivative decomposition');
legend(ax1, 'Location', 'best');
styleAxes(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, T, fracXAbs, '-s', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'DisplayName', '|X term| fraction');
plot(ax2, T, fracWAbs, '-d', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', '|width term| fraction');
plot(ax2, T, fracSAbs, '-^', 'LineWidth', 2.1, 'MarkerSize', 5, ...
    'Color', [0.47 0.67 0.19], 'MarkerFaceColor', [0.47 0.67 0.19], 'DisplayName', '|S_{peak} term| fraction');
xline(ax2, 10, ':', '10 K', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
xline(ax2, 26, ':', '26 K', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
hold(ax2, 'off');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Fraction of total |contribution|');
title(ax2, 'Fractional contribution summary vs temperature');
ylim(ax2, [0 1.05]);
legend(ax2, 'Location', 'best');
styleAxes(ax2);

title(tl, 'Switching ridge-motion decomposition by observable contributions');
figPaths = save_run_figure(fig, 'ridge_motion_decomposition', runDir);
close(fig);
end

function reportText = buildReportText(source, cfg, methodI, methodW, methodS, methodX, regionTbl, ...
    contribPath, regionPath, figPath)
lines = strings(0, 1);
lines(end + 1) = "# Ridge-motion decomposition report";
lines(end + 1) = "";
lines(end + 1) = "## Source";
lines(end + 1) = sprintf("- Switching source run: `%s`.", char(source.switchRunName));
lines(end + 1) = "- Source table: `tables/switching_full_scaling_parameters.csv`.";
lines(end + 1) = "- Loaded observables: `I_peak(T)=Ipeak_mA`, `width(T)=width_chosen_mA`, `S_peak(T)=S_peak`.";
lines(end + 1) = "";
lines(end + 1) = "## Definitions";
lines(end + 1) = "- `X(T) = I_peak(T) / (width(T) * S_peak(T))`.";
lines(end + 1) = "- Decomposition used:";
lines(end + 1) = "  `dI_peak/dT = (dX/dT) * width * S_peak + X * (dwidth/dT) * S_peak + X * width * (dS_peak/dT)`.";
lines(end + 1) = "";
lines(end + 1) = "## Derivative smoothing family";
lines(end + 1) = sprintf("- `I_peak(T)`: `%s`.", methodI);
lines(end + 1) = sprintf("- `width(T)`: `%s`.", methodW);
lines(end + 1) = sprintf("- `S_peak(T)`: `%s`.", methodS);
lines(end + 1) = sprintf("- `X(T)`: `%s`.", methodX);
lines(end + 1) = "- This matches the ridge-susceptibility smoothing family (`sgolay` with `movmean` fallback).";
lines(end + 1) = "";
lines(end + 1) = "## Dominance by region";
lines(end + 1) = "| Region | T range (K) | n | Dominant contribution | Dominant |share| | mean |X| frac | mean |width| frac | mean |S_peak| frac |";
lines(end + 1) = "| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |";
for i = 1:height(regionTbl)
    lines(end + 1) = sprintf("| %s | %.1f-%.1f | %d | %s | %.4f | %.4f | %.4f | %.4f |", ...
        regionTbl.region_name(i), regionTbl.T_min_K(i), regionTbl.T_max_K(i), regionTbl.n_points(i), ...
        regionTbl.dominant_component(i), regionTbl.dominant_share_abs(i), ...
        regionTbl.mean_abs_fraction_X(i), regionTbl.mean_abs_fraction_width(i), regionTbl.mean_abs_fraction_S_peak(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Requested outputs";
lines(end + 1) = "- Figure: `" + string(figPath.png) + "` (`ridge_motion_decomposition.png`).";
lines(end + 1) = "- Contributions-by-temperature table: `" + string(contribPath) + "`.";
lines(end + 1) = "- Region summary table: `" + string(regionPath) + "`.";
lines(end + 1) = "- Review bundle: `review/switching_ridge_motion_decomposition_bundle.zip`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 5 curves in the derivative panel and 3 curves in the fraction panel.";
lines(end + 1) = "- legend vs colormap: legend (<= 6 curves in each panel).";
lines(end + 1) = "- colormap used: none (line-only panels).";
lines(end + 1) = "- smoothing applied: same derivative smoothing family as ridge-susceptibility.";
lines(end + 1) = "- justification: direct line overlays are the clearest way to compare term magnitudes and dominance changes with temperature.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end + 1) = "Temperature sectors used: low-T [`" + cfg.lowTSectorMinK + "-" + cfg.lowTSectorMaxK + " K`], crossover [`" + cfg.cross26SectorMinK + "-" + cfg.cross26SectorMaxK + " K`].";
reportText = strjoin(lines, newline);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
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

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
