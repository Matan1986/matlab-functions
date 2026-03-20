function out = switching_a1_integral_consistency_test(cfg)
% switching_a1_integral_consistency_test
% Test whether the dynamic shape mode a1(T) is consistent with being the
% temperature derivative of the switching amplitude S_peak(T).
%
% Hypothesis: if a1 ~ dS_peak/dT, then cumulative_integral(a1, T) should
% reproduce S_peak(T) up to a constant offset and overall normalization.
%
% Steps:
%   1. Load a1(T) and S_peak(T) from their respective source runs.
%   2. Align temperature vectors by intersection.
%   3. Compute S_reconstructed(T) = cumtrapz(T, a1(T)).
%   4. Normalize both signals to unit range.
%   5. Compute Pearson and Spearman correlations.
%   6. Determine peak alignment (T_peak of each normalized signal).
%   7. Produce overlay figure and scatter figure.
%   8. Save tables: a1_integral_series.csv, a1_integral_correlations.csv.
%   9. Write report: a1_integral_consistency_report.md.
%  10. Build review ZIP.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile    = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot    = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg    = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg          = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('a1:%s | Speak:%s', ...
    char(source.a1RunName), char(source.speakRunName));
run    = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1 integral consistency test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('S_peak source run: %s\n', source.speakRunName);
appendFileText(run.log_path, sprintf('[%s] switching_a1_integral_consistency_test started\n', stampNow()));
appendFileText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendFileText(run.log_path, sprintf('S_peak source run: %s\n', char(source.speakRunName)));

% ── 1. Load ────────────────────────────────────────────────────────────────
a1Data    = loadA1Data(source.a1Path, cfg.a1ColumnName);
speakData = loadSpeakData(source.speakPath, cfg.speakColumnName);

% ── 2. Align temperature vectors ──────────────────────────────────────────
[T, iA1, iSp] = intersect(a1Data.T_K, speakData.T_K, 'stable');
if isempty(T)
    error('No common temperatures between a1 source and S_peak source.');
end

a1    = double(a1Data.a1(iA1));
Speak = double(speakData.S_peak(iSp));

maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T     = double(T(maskRange));
a1    = a1(maskRange);
Speak = Speak(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

% Fill isolated NaNs by interpolation.
a1    = fillByInterp(T, a1);
Speak = fillByInterp(T, Speak);

% ── 3. Cumulative trapezoidal integral of a1(T) ───────────────────────────
% cumtrapz integrates column-by-column using trapezoidal rule.
S_reconstructed = cumtrapz(T, a1);

% ── 4. Normalize both signals to unit range [0, 1] ────────────────────────
Speak_norm  = normalize01(Speak);
Srec_norm   = normalize01(S_reconstructed);

% ── 5. Correlations ────────────────────────────────────────────────────────
valid = isfinite(Speak_norm) & isfinite(Srec_norm);
if nnz(valid) < 3
    error('Insufficient finite points after normalization for correlation.');
end

Tv          = T(valid);
SpNormV     = Speak_norm(valid);
SrecNormV   = Srec_norm(valid);

pearsonR    = safeCorr(SpNormV, SrecNormV, 'Pearson');
spearmanRho = safeCorr(SpNormV, SrecNormV, 'Spearman');

% ── 6. Peak alignment ─────────────────────────────────────────────────────
[speakPeakT,  speakPeakVal]  = peakOf(Tv, SpNormV,   false);
[srecPeakT,   srecPeakVal]   = peakOf(Tv, SrecNormV, false);
deltaPeakK = srecPeakT - speakPeakT;

% ── 7-8. Tables ────────────────────────────────────────────────────────────
corrTbl = table( ...
    nnz(valid), ...
    pearsonR, ...
    spearmanRho, ...
    speakPeakT, speakPeakVal, ...
    srecPeakT,  srecPeakVal, ...
    deltaPeakK, ...
    cfg.temperatureMinK, cfg.temperatureMaxK, ...
    source.a1RunName, source.speakRunName, ...
    string(source.a1Path), string(source.speakPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_Speak_vs_Srec', ...
    'spearman_Speak_vs_Srec', ...
    'T_peak_Speak_norm_K', 'S_peak_norm_at_peak', ...
    'T_peak_Srec_norm_K',  'S_rec_norm_at_peak', ...
    'delta_T_peak_K', ...
    'T_min_K', 'T_max_K', ...
    'a1_source_run', 'Speak_source_run', ...
    'a1_source_file', 'Speak_source_file'});

seriesTbl = table( ...
    Tv, ...
    Speak(valid), Speak_norm(valid), ...
    S_reconstructed(valid), Srec_norm(valid), ...
    a1(valid), ...
    'VariableNames', { ...
    'T_K', ...
    'S_peak', 'S_peak_norm', ...
    'S_reconstructed',  'S_reconstructed_norm', ...
    'a1'});

corrPath   = save_run_table(corrTbl,   'a1_integral_correlations.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_integral_series.csv',       runDir);

% ── 7. Figures ─────────────────────────────────────────────────────────────
figOverlay  = saveOverlayFigure(Tv, SpNormV, SrecNormV, pearsonR, spearmanRho, ...
    deltaPeakK, runDir);
figScatter  = saveScatterFigure(SpNormV, SrecNormV, pearsonR, spearmanRho, runDir);

% ── 9. Report ──────────────────────────────────────────────────────────────
reportText = buildReportText(source, cfg, corrTbl, ...
    figOverlay, figScatter, corrPath, seriesPath);
reportPath = save_run_report(reportText, 'a1_integral_consistency_report.md', runDir);

% ── 10. ZIP ────────────────────────────────────────────────────────────────
zipPath = buildReviewZip(runDir, 'a1_integral_consistency_bundle.zip');

% ── Log & notes ────────────────────────────────────────────────────────────
appendFileText(run.notes_path, sprintf('a1 source run = %s\n',         char(source.a1RunName)));
appendFileText(run.notes_path, sprintf('S_peak source run = %s\n',     char(source.speakRunName)));
appendFileText(run.notes_path, sprintf('n points = %d\n',              nnz(valid)));
appendFileText(run.notes_path, sprintf('Pearson(Speak, Srec) = %.6f\n', pearsonR));
appendFileText(run.notes_path, sprintf('Spearman(Speak, Srec) = %.6f\n', spearmanRho));
appendFileText(run.notes_path, sprintf('T_peak(S_peak_norm) = %.2f K\n', speakPeakT));
appendFileText(run.notes_path, sprintf('T_peak(Srec_norm) = %.2f K\n',   srecPeakT));
appendFileText(run.notes_path, sprintf('delta_T_peak = %.2f K\n',         deltaPeakK));
appendFileText(run.notes_path, sprintf('correlation table = %s\n',       corrPath));
appendFileText(run.notes_path, sprintf('series table = %s\n',            seriesPath));
appendFileText(run.notes_path, sprintf('overlay figure = %s\n',          figOverlay.png));
appendFileText(run.notes_path, sprintf('scatter figure = %s\n',          figScatter.png));
appendFileText(run.notes_path, sprintf('report = %s\n',                  reportPath));
appendFileText(run.notes_path, sprintf('zip = %s\n',                     zipPath));

appendFileText(run.log_path, sprintf('[%s] switching_a1_integral_consistency_test complete\n', stampNow()));
appendFileText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendFileText(run.log_path, sprintf('Series table: %s\n',      seriesPath));
appendFileText(run.log_path, sprintf('Overlay figure: %s\n',    figOverlay.png));
appendFileText(run.log_path, sprintf('Scatter figure: %s\n',    figScatter.png));
appendFileText(run.log_path, sprintf('Report: %s\n',            reportPath));
appendFileText(run.log_path, sprintf('ZIP: %s\n',               zipPath));

% ── Output struct ──────────────────────────────────────────────────────────
out = struct();
out.run    = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson',       pearsonR, ...
    'spearman',      spearmanRho, ...
    'T_peak_Speak',  speakPeakT, ...
    'T_peak_Srec',   srecPeakT, ...
    'delta_T_peak',  deltaPeakK, ...
    'n_points',      nnz(valid));
out.paths = struct( ...
    'correlation', string(corrPath), ...
    'series',      string(seriesPath), ...
    'overlay',     string(figOverlay.png), ...
    'scatter',     string(figScatter.png), ...
    'report',      string(reportPath), ...
    'zip',         string(zipPath));

fprintf('\n=== Switching a1 integral consistency test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(S_peak_norm, S_reconstructed_norm):  %.6f\n', pearsonR);
fprintf('Spearman(S_peak_norm, S_reconstructed_norm): %.6f\n', spearmanRho);
fprintf('T_peak(S_peak_norm):  %.2f K\n', speakPeakT);
fprintf('T_peak(S_rec_norm):   %.2f K\n', srecPeakT);
fprintf('Delta T_peak:         %.2f K\n', deltaPeakK);
fprintf('Correlation table: %s\n', corrPath);
fprintf('Overlay figure:    %s\n', figOverlay.png);
fprintf('Scatter figure:    %s\n', figScatter.png);
fprintf('Report:            %s\n', reportPath);
fprintf('ZIP:               %s\n\n', zipPath);
end

% ═══════════════════════════════════════════════════════════════════════════
% Configuration
% ═══════════════════════════════════════════════════════════════════════════

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',            'switching_a1_integral_consistency_test');
cfg = setDefaultField(cfg, 'a1RunName',           'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'speakRunName',        'run_2026_03_13_112155_switching_geometry_diagnostics');
cfg = setDefaultField(cfg, 'a1ColumnName',        'a_1');
cfg = setDefaultField(cfg, 'speakColumnName',     'S_peak');
cfg = setDefaultField(cfg, 'temperatureMinK',     4);
cfg = setDefaultField(cfg, 'temperatureMaxK',     30);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.a1RunName    = string(cfg.a1RunName);
source.speakRunName = string(cfg.speakRunName);

runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');

source.a1Path = fullfile(runsRoot, char(source.a1RunName), ...
    'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.speakPath = fullfile(runsRoot, char(source.speakRunName), ...
    'tables', 'switching_geometry_observables.csv');

if exist(source.a1Path, 'file') ~= 2
    error('Required a1 source file not found: %s', source.a1Path);
end
if exist(source.speakPath, 'file') ~= 2
    error('Required S_peak source file not found: %s', source.speakPath);
end
end

% ═══════════════════════════════════════════════════════════════════════════
% Data loading
% ═══════════════════════════════════════════════════════════════════════════

function data = loadA1Data(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    error('a1 table missing column "%s": %s', a1ColumnName, pathValue);
end
tbl     = sortrows(tbl, 'T_K');
data    = struct();
data.T_K = double(tbl.T_K(:));
data.a1  = double(tbl.(a1ColumnName)(:));
end

function data = loadSpeakData(pathValue, speakColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('S_peak table missing T_K column: %s', pathValue);
end
if ~ismember(speakColumnName, tbl.Properties.VariableNames)
    error('S_peak table missing column "%s": %s', speakColumnName, pathValue);
end
tbl      = sortrows(tbl, 'T_K');
data     = struct();
data.T_K  = double(tbl.T_K(:));
data.S_peak = double(tbl.(speakColumnName)(:));
end

% ═══════════════════════════════════════════════════════════════════════════
% Signal helpers
% ═══════════════════════════════════════════════════════════════════════════

function y = fillByInterp(x, yIn)
y    = yIn(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    return;
end
if any(~mask)
    y(~mask) = interp1(x(mask), y(mask), x(~mask), 'linear', 'extrap');
end
end

function y = normalize01(x)
x  = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

% ═══════════════════════════════════════════════════════════════════════════
% Statistics helpers
% ═══════════════════════════════════════════════════════════════════════════

function c = safeCorr(x, y, corrType)
x    = x(:);
y    = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    c = NaN;
    return;
end
try
    c = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
catch
    c = corr(x(mask), y(mask));
end
end

function [peakT, peakVal] = peakOf(T, y, useAbs)
peakT   = NaN;
peakVal = NaN;
if isempty(T) || isempty(y)
    return;
end
if useAbs
    [~, idx] = max(abs(y));
    peakVal  = y(idx);
else
    [peakVal, idx] = max(y);
end
if ~isempty(idx)
    peakT = T(idx);
end
end

% ═══════════════════════════════════════════════════════════════════════════
% Figure helpers
% ═══════════════════════════════════════════════════════════════════════════

function figOut = saveOverlayFigure(T, SpNorm, SrecNorm, pearsonR, spearmanRho, deltaPeakK, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
ax  = axes(fig);
hold(ax, 'on');

plot(ax, T, SpNorm, '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'S_{peak}(T) [unit-norm]');
plot(ax, T, SrecNorm, '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', '\integrala_1 dT  [unit-norm]');

hold(ax, 'off');
xlabel(ax, 'Temperature (K)',          'FontSize', 14);
ylabel(ax, 'Normalized amplitude (a.u.)', 'FontSize', 14);
title(ax, sprintf('a_1 integral consistency  |  Pearson r = %.4f   Spearman \x03C1 = %.4f   \x0394T_{peak} = %.1f K', ...
    pearsonR, spearmanRho, deltaPeakK), 'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 12);

figOut = robustSaveFigure(fig, 'a1_integral_consistency_overlay', runDir);
close(fig);
end

function figOut = saveScatterFigure(SpNorm, SrecNorm, pearsonR, spearmanRho, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');

scatter(ax, SpNorm, SrecNorm, 72, 'filled', ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerEdgeColor', [0.00 0.45 0.74], ...
    'DisplayName', 'Data points');

m = isfinite(SpNorm) & isfinite(SrecNorm);
if nnz(m) >= 2
    p  = polyfit(SpNorm(m), SrecNorm(m), 1);
    xg = linspace(min(SpNorm(m)), max(SpNorm(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('Linear fit: slope=%.3g', p(1)));
end

% Reference identity line
refX = linspace(0, 1, 50);
plot(ax, refX, refX, '--', 'LineWidth', 1.4, 'Color', [0.50 0.50 0.50], ...
    'DisplayName', 'Identity (perfect recovery)');

xlabel(ax, 'S_{peak}(T)  [unit-norm]',        'FontSize', 14);
ylabel(ax, '\integrala_1 dT  [unit-norm]', 'FontSize', 14);
title(ax, 'Scatter: S_{peak} vs \integrala_1 dT', 'FontSize', 13);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

xL    = xlim(ax);
yL    = ylim(ax);
textX = xL(1) + 0.04 * (xL(2) - xL(1));
textY = yL(2) - 0.04 * (yL(2) - yL(1));
text(ax, textX, textY, ...
    sprintf('Pearson r = %.4f\nSpearman \x03C1 = %.4f', pearsonR, spearmanRho), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
figOut = robustSaveFigure(fig, 'a1_integral_consistency_scatter', runDir);
close(fig);
end

function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_a1_integral_consistency_test:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut     = struct();
    figOut.png = fullfile(figuresDir, [baseName '.png']);
    figOut.fig = fullfile(figuresDir, [baseName '.fig']);
    figOut.pdf = fullfile(figuresDir, [baseName '.pdf']);
    exportgraphics(fig, figOut.png, 'Resolution', 300);
    savefig(fig, figOut.fig);
    try
        exportgraphics(fig, figOut.pdf, 'ContentType', 'vector');
    catch
        % PDF export is optional in fallback mode.
    end
end
end

% ═══════════════════════════════════════════════════════════════════════════
% Report
% ═══════════════════════════════════════════════════════════════════════════

function reportText = buildReportText(source, cfg, corrTbl, figOverlay, figScatter, corrPath, seriesPath)
r   = corrTbl.pearson_Speak_vs_Srec(1);
rho = corrTbl.spearman_Speak_vs_Srec(1);
dT  = corrTbl.delta_T_peak_K(1);
n   = corrTbl.n_points(1);
Tsp = corrTbl.T_peak_Speak_norm_K(1);
Tsr = corrTbl.T_peak_Srec_norm_K(1);

function s = classify(p)
    if isfinite(p) && abs(p) >= 0.90
        s = "very strong";
    elseif isfinite(p) && abs(p) >= 0.70
        s = "strong";
    elseif isfinite(p) && abs(p) >= 0.50
        s = "moderate";
    else
        s = "weak";
    end
end

strengthPearson  = classify(r);
strengthSpearman = classify(rho);

if isfinite(r) && abs(r) >= 0.90 && abs(dT) <= 4
    conclusion = "The cumulative integral of a1(T) reproduces S_peak(T) well: " + ...
        "the normalized overlap is very strong and peak temperatures are closely aligned. " + ...
        "This is consistent with a1(T) being the temperature derivative of S_peak(T).";
elseif isfinite(r) && abs(r) >= 0.70
    if abs(dT) <= 4
        conclusion = "The cumulative integral of a1(T) shows strong overlap with S_peak(T). " + ...
            "The derivative-integral consistency hypothesis is supported, " + ...
            "though not at the level of near-perfect reconstruction.";
    else
        conclusion = "The cumulative integral of a1(T) shows strong correlation with S_peak(T) " + ...
            "but a meaningful peak timing offset (delta = " + sprintf('%.1f K', dT) + ") " + ...
            "suggests either a phase contribution not captured by a1 alone, " + ...
            "or that integration constants shift the reconstructed profile.";
    end
elseif isfinite(r) && abs(r) >= 0.50
    conclusion = "Moderate correlation. The cumulative integral of a1 partially tracks S_peak(T) " + ...
        "but the reconstruction is incomplete. " + ...
        "a1 may capture only part of the thermal variation of S_peak.";
else
    conclusion = "Weak or negligible correlation. The cumulative integral of a1(T) does not " + ...
        "reproduce S_peak(T) in this temperature range. " + ...
        "a1 is not consistent with being the dominant temperature derivative of S_peak.";
end

lines = strings(0, 1);
lines(end+1) = "# a1(T) integral consistency test";
lines(end+1) = "";
lines(end+1) = "## Hypothesis";
lines(end+1) = "If a1(T) ≈ dS_peak/dT, then the cumulative trapezoidal integral";
lines(end+1) = "∫a1(T') dT' (integrated from T_min to T) should recover S_peak(T)";
lines(end+1) = "up to an additive constant and global scale factor.";
lines(end+1) = "This test checks that relationship by normalizing both signals to";
lines(end+1) = "unit range [0, 1] and computing their correlation and peak alignment.";
lines(end+1) = "";
lines(end+1) = "## Sources";
lines(end+1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end+1) = "- a1 source file: `" + string(source.a1Path) + "`";
lines(end+1) = "- S_peak source run: `" + source.speakRunName + "`";
lines(end+1) = "- S_peak source file: `" + string(source.speakPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Method";
lines(end+1) = "- Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end+1) = "- Temperature vectors aligned by intersection (`intersect`, stable sort).";
lines(end+1) = "- `S_reconstructed(T) = cumtrapz(T, a1(T))` (MATLAB `cumtrapz`, trapezoidal rule).";
lines(end+1) = "- Both `S_peak` and `S_reconstructed` normalized to range [0, 1] via min-max normalization.";
lines(end+1) = "- No derivative smoothing applied to a1(T) — stored amplitudes used directly.";
lines(end+1) = "";
lines(end+1) = "## Results";
lines(end+1) = sprintf("- Matched temperature points: `%d`.", n);
lines(end+1) = sprintf("- Pearson corr(`S_peak_norm`, `S_rec_norm`) = `%.6f` (%s).", r, strengthPearson);
lines(end+1) = sprintf("- Spearman corr(`S_peak_norm`, `S_rec_norm`) = `%.6f` (%s).", rho, strengthSpearman);
lines(end+1) = sprintf("- `T_peak(S_peak_norm) = %.2f K`.", Tsp);
lines(end+1) = sprintf("- `T_peak(S_rec_norm)  = %.2f K`.", Tsr);
lines(end+1) = sprintf("- `ΔT_peak = S_rec_peak − S_peak_peak = %.2f K`.", dT);
lines(end+1) = "";
lines(end+1) = "## Interpretation";
lines(end+1) = "- " + conclusion;
lines(end+1) = "";
lines(end+1) = "**Note on integration constant**: `cumtrapz` starts from 0 at the lowest";
lines(end+1) = "temperature included. The reconstruction therefore fixes the lower boundary";
lines(end+1) = "value, which is removed by min-max normalization before comparison.";
lines(end+1) = "Any offset between the two signals is absorbed by normalization.";
lines(end+1) = "";
lines(end+1) = "## Artifacts";
lines(end+1) = "- Correlation table: `" + string(corrPath) + "`";
lines(end+1) = "- Aligned-series table: `" + string(seriesPath) + "`";
lines(end+1) = "- Normalized overlay figure: `" + string(figOverlay.png) + "`";
lines(end+1) = "- Scatter figure: `" + string(figScatter.png) + "`";
lines(end+1) = "";
lines(end+1) = "![a1_integral_consistency_overlay](../figures/a1_integral_consistency_overlay.png)";
lines(end+1) = "";
lines(end+1) = "![a1_integral_consistency_scatter](../figures/a1_integral_consistency_scatter.png)";
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = "- Figure 1 (overlay): 2 curves, legend used (≤ 6 curves), no colormap.";
lines(end+1) = "- Figure 2 (scatter): data points + OLS line + identity reference + annotation.";
lines(end+1) = "- No derivative smoothing shown in figures (stored a1 amplitudes used directly).";
lines(end+1) = "- Both signals min-max normalized to unit range before plotting.";
lines(end+1) = "";
lines(end+1) = "---";
lines(end+1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

% ═══════════════════════════════════════════════════════════════════════════
% ZIP
% ═══════════════════════════════════════════════════════════════════════════

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end

files = { ...
    fullfile(runDir, 'figures',  'a1_integral_consistency_overlay.png'), ...
    fullfile(runDir, 'figures',  'a1_integral_consistency_scatter.png'), ...
    fullfile(runDir, 'tables',   'a1_integral_correlations.csv'), ...
    fullfile(runDir, 'tables',   'a1_integral_series.csv'), ...
    fullfile(runDir, 'reports',  'a1_integral_consistency_report.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
    fullfile(runDir, 'config_snapshot.m'), ...
    fullfile(runDir, 'log.txt'), ...
    fullfile(runDir, 'run_notes.txt')};

existing = {};
for i = 1:numel(files)
    if exist(files{i}, 'file') == 2
        existing{end+1} = files{i}; %#ok<AGROW>
    end
end

if ~isempty(existing)
    zip(zipPath, existing, runDir);
end
end

% ═══════════════════════════════════════════════════════════════════════════
% Utilities
% ═══════════════════════════════════════════════════════════════════════════

function appendFileText(filePath, textValue)
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

function cfg = setDefaultField(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end
