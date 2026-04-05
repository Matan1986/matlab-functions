function out = switching_ridge_susceptibility_test(cfg)
% switching_ridge_susceptibility_test
% Test hypothesis a1(T) proportional to dI_peak(T)/dT.

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
runCfg.dataset = sprintf('dynamic_shape:%s | full_scaling:%s', ...
    char(source.dynamicShapeRunId), char(source.fullScalingRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching ridge-susceptibility run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] switching ridge susceptibility test started\n', stampNow()));
appendText(run.log_path, sprintf('Dynamic-shape source: %s\n', char(source.dynamicShapeRunId)));
appendText(run.log_path, sprintf('Dynamic amplitude file: %s\n', source.dynamicAmplitudePath));
appendText(run.log_path, sprintf('Full-scaling source: %s\n', char(source.fullScalingRunId)));
appendText(run.log_path, sprintf('I_peak source file: %s\n', source.fullScalingParamsPath));

ampTbl = sortrows(readtable(source.dynamicAmplitudePath), 'T_K');
scaleTbl = sortrows(readtable(source.fullScalingParamsPath), 'T_K');

assert(ismember('a_1', ampTbl.Properties.VariableNames), ...
    'Dynamic-shape amplitude table is missing column a_1.');
assert(ismember('T_K', ampTbl.Properties.VariableNames), ...
    'Dynamic-shape amplitude table is missing column T_K.');
assert(ismember('T_K', scaleTbl.Properties.VariableNames), ...
    'Full-scaling table is missing column T_K.');
assert(ismember('Ipeak_mA', scaleTbl.Properties.VariableNames), ...
    'Full-scaling table is missing column Ipeak_mA.');

maskA = ampTbl.T_K >= cfg.temperatureMinK & ampTbl.T_K <= cfg.temperatureMaxK;
maskS = scaleTbl.T_K >= cfg.temperatureMinK & scaleTbl.T_K <= cfg.temperatureMaxK;
ampTbl = ampTbl(maskA, :);
scaleTbl = scaleTbl(maskS, :);

[temps, ia, ib] = intersect(double(ampTbl.T_K(:)), double(scaleTbl.T_K(:)), 'stable');
assert(~isempty(temps), 'No overlapping temperatures between a1(T) and I_peak(T) tables.');

a1 = double(ampTbl.a_1(ia));
Ipeak = double(scaleTbl.Ipeak_mA(ib));

valid = isfinite(temps) & isfinite(a1) & isfinite(Ipeak);
temps = temps(valid);
a1 = a1(valid);
Ipeak = Ipeak(valid);

assert(numel(temps) >= 5, 'Need at least 5 common points for derivative/correlation analysis.');

[dIraw, dIsmooth, IpeakSmooth, smoothMethod] = derivativeProfiles(temps, Ipeak, cfg);

[pearsonR, nPoints] = safeCorr(a1, dIsmooth, 'Pearson');
[spearmanRho, ~] = safeCorr(a1, dIsmooth, 'Spearman');

[slopeC, yHat, residuals, r2] = fitThroughOrigin(dIsmooth, a1);

profilesTbl = table( ...
    temps(:), a1(:), Ipeak(:), IpeakSmooth(:), dIraw(:), dIsmooth(:), yHat(:), residuals(:), ...
    'VariableNames', {'T_K', 'a1', 'I_peak_mA', 'I_peak_smoothed_mA', ...
    'dI_peak_dT_raw_mA_perK', 'dI_peak_dT_smoothed_mA_perK', ...
    'a1_fit_from_smoothed_dIpeak_dT', 'fit_residual_a1'});
profilesPath = save_run_table(profilesTbl, 'a1_vs_dIpeak_profiles.csv', runDir);

summaryTbl = table( ...
    string(source.dynamicShapeRunId), string(source.fullScalingRunId), ...
    string(source.dynamicAmplitudePath), string(source.fullScalingParamsPath), ...
    string(smoothMethod), cfg.sgolayPolynomialOrder, cfg.sgolayFrameLength, cfg.movmeanWindow, ...
    nPoints, pearsonR, spearmanRho, slopeC, r2, ...
    'VariableNames', {'dynamic_shape_run_id', 'full_scaling_run_id', ...
    'a1_source_file', 'ipeak_source_file', ...
    'derivative_smoothing_method', 'sgolay_polynomial_order', ...
    'sgolay_frame_length', 'movmean_window', ...
    'n_points', 'pearson_r', 'spearman_rho', 'fit_slope_c', 'fit_r2'});
summaryPath = save_run_table(summaryTbl, 'a1_vs_dIpeak_correlation.csv', runDir);

sourceManifestTbl = table( ...
    string({'a1_dynamic_mode_amplitude'; 'I_peak_full_scaling_parameters'}), ...
    [source.dynamicShapeRunId; source.fullScalingRunId], ...
    string({source.dynamicAmplitudePath; source.fullScalingParamsPath}), ...
    'VariableNames', {'source_role', 'source_run_id', 'source_file'});
sourceManifestPath = save_run_table(sourceManifestTbl, 'switching_ridge_susceptibility_sources.csv', runDir);

figProfile = plotTemperatureProfiles(temps, a1, dIsmooth, runDir);
figScatter = plotScatterFit(dIsmooth, a1, yHat, slopeC, pearsonR, spearmanRho, r2, runDir);

reportText = buildReportText(source, cfg, smoothMethod, nPoints, pearsonR, spearmanRho, slopeC, r2, ...
    profilesPath, summaryPath, sourceManifestPath, figProfile, figScatter);
reportPath = save_run_report(reportText, 'switching_ridge_susceptibility_test_report.md', runDir);

appendText(run.notes_path, sprintf('n points = %d\n', nPoints));
appendText(run.notes_path, sprintf('Derivative smoothing method = %s\n', smoothMethod));
appendText(run.notes_path, sprintf('Pearson(a1, dIpeak/dT) = %.6g\n', pearsonR));
appendText(run.notes_path, sprintf('Spearman(a1, dIpeak/dT) = %.6g\n', spearmanRho));
appendText(run.notes_path, sprintf('Linear fit slope c = %.6g\n', slopeC));
appendText(run.notes_path, sprintf('Linear fit R2 = %.6g\n', r2));

zipPath = buildReviewZip(runDir, 'switching_ridge_susceptibility_test_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching ridge susceptibility test complete\n', stampNow()));
appendText(run.log_path, sprintf('Profiles table: %s\n', profilesPath));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourceManifestPath));
appendText(run.log_path, sprintf('Profile figure: %s\n', figProfile.png));
appendText(run.log_path, sprintf('Scatter figure: %s\n', figScatter.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.pearson = pearsonR;
out.spearman = spearmanRho;
out.fitSlope = slopeC;
out.fitR2 = r2;
out.paths = struct( ...
    'profiles', string(profilesPath), ...
    'summary', string(summaryPath), ...
    'sources', string(sourceManifestPath), ...
    'profileFigure', string(figProfile.png), ...
    'scatterFigure', string(figScatter.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching ridge susceptibility test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson corr(a1, dIpeak/dT): %.4f\n', pearsonR);
fprintf('Spearman corr(a1, dIpeak/dT): %.4f\n', spearmanRho);
fprintf('Fit slope c: %.6f\n', slopeC);
fprintf('Fit R2: %.4f\n', r2);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_ridge_susceptibility_test');
cfg = setDefault(cfg, 'dynamicShapeRunId', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefault(cfg, 'sgolayFrameLength', 5);
cfg = setDefault(cfg, 'movmeanWindow', 3);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.dynamicShapeRunId = string(cfg.dynamicShapeRunId);
source.fullScalingRunId = string(cfg.fullScalingRunId);

source.phi1Guard = enforce_canonical_phi1_source({source.dynamicShapeRunId}, 'switching_ridge_susceptibility_test');

source.dynamicShapeRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.dynamicShapeRunId));
source.dynamicAmplitudePath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_mode_amplitudes.csv');
source.dynamicSourcesPath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_sources.csv');

source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.fullScalingRunId));
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', ...
    'switching_full_scaling_parameters.csv');

if exist(source.dynamicSourcesPath, 'file') == 2
    srcTbl = readtable(source.dynamicSourcesPath);
    if all(ismember({'source_role', 'source_file'}, srcTbl.Properties.VariableNames))
        role = string(srcTbl.source_role);
        idx = find(role == "full_scaling_parameters", 1, 'first');
        if ~isempty(idx)
            source.fullScalingParamsPath = char(string(srcTbl.source_file(idx)));
            if ismember('source_run_id', srcTbl.Properties.VariableNames)
                source.fullScalingRunId = string(srcTbl.source_run_id(idx));
                source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
                    char(source.fullScalingRunId));
            end
        end
    end
end

required = {source.dynamicAmplitudePath, source.fullScalingParamsPath};
for i = 1:numel(required)
    assert(exist(required{i}, 'file') == 2, 'Required source file missing: %s', required{i});
end
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

function [r, n] = safeCorr(x, y, corrType)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
n = nnz(mask);
if n < 3
    r = NaN;
    return;
end
r = corr(x(mask), y(mask), 'Type', corrType);
end

function [c, yHat, residuals, r2] = fitThroughOrigin(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
xv = x(mask);
yv = y(mask);

if isempty(xv) || sum(xv .^ 2) <= eps
    c = NaN;
    yHat = NaN(size(y));
    residuals = NaN(size(y));
    r2 = NaN;
    return;
end

c = (xv' * yv) / max(xv' * xv, eps);
yHat = c .* x;
residuals = y - yHat;

sse = sum((yv - c .* xv) .^ 2);
sst = sum((yv - mean(yv, 'omitnan')) .^ 2);
if sst <= eps
    r2 = NaN;
else
    r2 = 1 - (sse / sst);
end
end

function figPaths = plotTemperatureProfiles(T, a1, dI, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 11]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
yyaxis(ax1, 'left');
plot(ax1, T, a1, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T)');
ylabel(ax1, 'a_1(T) (a.u.)');
yyaxis(ax1, 'right');
plot(ax1, T, dI, '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'dI_{peak}/dT');
ylabel(ax1, 'dI_{peak}/dT (mA/K)');
xlabel(ax1, 'Temperature (K)');
title(ax1, 'Raw-unit comparison: a_1(T) and dI_{peak}(T)/dT');
legend(ax1, {'a_1(T)', 'dI_{peak}/dT'}, 'Location', 'best');
styleAxes(ax1);
hold(ax1, 'off');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, T, normalize01(a1), '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T) normalized');
plot(ax2, T, normalize01(dI), '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'dI_{peak}/dT normalized');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Normalized (0 to 1)');
title(ax2, 'Normalized temperature-profile comparison');
legend(ax2, 'Location', 'best');
styleAxes(ax2);
hold(ax2, 'off');

title(tl, 'Ridge susceptibility profile comparison');
figPaths = save_run_figure(fig, 'temperature_profiles_comparison', runDir);
close(fig);
end

function figPaths = plotScatterFit(x, y, yHat, c, pearsonR, spearmanRho, r2, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax = axes(fig);
hold(ax, 'on');

scatter(ax, x, y, 64, 'filled', ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerEdgeColor', [0.00 0.45 0.74], ...
    'DisplayName', 'Data: (dI_{peak}/dT, a_1)');

if any(isfinite(yHat))
    m = isfinite(x) & isfinite(yHat);
    [xs, idx] = sort(x(m));
    ys = yHat(m);
    ys = ys(idx);
    plot(ax, xs, ys, '-', 'LineWidth', 2.4, ...
        'Color', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('Fit: a_1 = c*dI_{peak}/dT, c = %.4g', c));
end

xlabel(ax, 'dI_{peak}/dT (mA/K)');
ylabel(ax, 'a_1(T) (a.u.)');
title(ax, 'a_1(T) vs dI_{peak}(T)/dT');
styleAxes(ax);
legend(ax, 'Location', 'best');

xL = xlim(ax);
yL = ylim(ax);
textX = xL(1) + 0.03 * (xL(2) - xL(1));
textY = yL(2) - 0.06 * (yL(2) - yL(1));
txt = sprintf('Pearson r = %.4f\nSpearman \\rho = %.4f\nR^2 (through origin) = %.4f', ...
    pearsonR, spearmanRho, r2);
text(ax, textX, textY, txt, ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
figPaths = save_run_figure(fig, 'a1_vs_dIpeak_dT', runDir);
close(fig);
end

function reportText = buildReportText(source, cfg, smoothMethod, nPoints, pearsonR, spearmanRho, slopeC, r2, ...
    profilesPath, summaryPath, sourceManifestPath, figProfile, figScatter)

strengthText = "weak or moderate";
if isfinite(pearsonR) && abs(pearsonR) > 0.7 && isfinite(spearmanRho) && abs(spearmanRho) > 0.7
    strengthText = "strong";
end

lines = strings(0, 1);
lines(end + 1) = "# Switching ridge susceptibility test";
lines(end + 1) = "";
lines(end + 1) = "Hypothesis tested: `a_1(T) \\propto dI_{peak}(T)/dT`.";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- Dynamic shape run (`a_1(T)`): `" + source.dynamicShapeRunId + "`.";
lines(end + 1) = "- Full scaling run (`I_{peak}(T)`): `" + source.fullScalingRunId + "`.";
lines(end + 1) = "- Dynamic amplitude table: `" + string(source.dynamicAmplitudePath) + "`.";
lines(end + 1) = "- Full scaling parameter table: `" + string(source.fullScalingParamsPath) + "`.";
lines(end + 1) = "- Temperature range used: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Derivative settings";
lines(end + 1) = "- Method used: `" + string(smoothMethod) + "`.";
lines(end + 1) = "- Raw derivative is from `gradient(I_{peak}, T)`; reported test uses smoothed derivative.";
lines(end + 1) = "";
lines(end + 1) = "## Results";
lines(end + 1) = sprintf('- Matched points: `%d`.', nPoints);
lines(end + 1) = sprintf('- Pearson corr(`a_1`, `dI_{peak}/dT`) = `%.4f`.', pearsonR);
lines(end + 1) = sprintf('- Spearman corr(`a_1`, `dI_{peak}/dT`) = `%.4f`.', spearmanRho);
lines(end + 1) = sprintf('- Fit `a_1 = c*(dI_{peak}/dT)`: `c = %.6g`.', slopeC);
lines(end + 1) = sprintf('- Fit `R^2` (through origin) = `%.4f`.', r2);
lines(end + 1) = "- Correlation strength by requested criterion (`>0.7`) is **" + strengthText + "**.";
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- Figure: `" + string(figScatter.png) + "` (`a1_vs_dIpeak_dT.png`).";
lines(end + 1) = "- Figure: `" + string(figProfile.png) + "` (`temperature_profiles_comparison.png`).";
lines(end + 1) = "- Correlation table: `" + string(summaryPath) + "`.";
lines(end + 1) = "- Profiles table: `" + string(profilesPath) + "`.";
lines(end + 1) = "- Source manifest: `" + string(sourceManifestPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_dIpeak_dT](../figures/a1_vs_dIpeak_dT.png)";
lines(end + 1) = "";
lines(end + 1) = "![temperature_profiles_comparison](../figures/temperature_profiles_comparison.png)";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
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


