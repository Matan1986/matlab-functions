function out = switching_translation_mode_test(cfg)
% switching_translation_mode_test
% Test whether dynamic shape mode phi_1(I) matches the ridge-translation mode.
%
% Theory:
%   dS/dT ~= -(dS/dI) * dIpeak/dT
% so the translation spatial profile should resemble:
%   psi_translation(I) = -<dS/dI>_T

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('dynamic_shape:%s | alignment:%s | full_scaling:%s', ...
    char(source.dynamicShapeRunId), char(source.alignmentRunId), char(source.fullScalingRunId));
run = createSwitchingRunContext(repoRoot, runCfg);
runDir = run.run_dir;

fprintf('Switching translation-mode test run directory:\n%s\n', runDir);
fprintf('Dynamic-shape source run: %s\n', source.dynamicShapeRunId);
fprintf('Alignment source run: %s\n', source.alignmentRunId);
fprintf('Full-scaling source run: %s\n', source.fullScalingRunId);

appendText(run.log_path, sprintf('[%s] switching translation-mode test started\n', stampNow()));
appendText(run.log_path, sprintf('Dynamic-shape source: %s\n', char(source.dynamicShapeRunId)));
appendText(run.log_path, sprintf('Alignment source: %s\n', char(source.alignmentRunId)));
appendText(run.log_path, sprintf('Full-scaling source: %s\n', char(source.fullScalingRunId)));

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);
paramsTbl = sortrows(paramsTbl, 'T_K');
phiTbl = readtable(source.dynamicPhiPath);

assert(ismember('phi_1', phiTbl.Properties.VariableNames), ...
    'Expected column phi_1 in %s', source.dynamicPhiPath);
assert(ismember('current_mA', phiTbl.Properties.VariableNames), ...
    'Expected column current_mA in %s', source.dynamicPhiPath);

tempsAll = core.temps(:);
currents = core.currents(:);
SmapAll = core.Smap;

tMask = paramsTbl.T_K >= cfg.temperatureMinK & paramsTbl.T_K <= cfg.temperatureMaxK;
paramsTbl = paramsTbl(tMask, :);
assert(~isempty(paramsTbl), 'No full-scaling rows remain in requested temperature range.');

[tempsCommon, iMap, iPar] = intersect(tempsAll, paramsTbl.T_K, 'stable');
assert(~isempty(tempsCommon), ...
    'No common temperatures between alignment map and full-scaling observables.');

Smap = SmapAll(iMap, :);
Ipeak = paramsTbl.Ipeak_mA(iPar);
Speak = paramsTbl.S_peak(iPar);

validRows = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak);
validRows = validRows & (Speak > cfg.speakFloorFraction * max(Speak, [], 'omitnan'));

temps = tempsCommon(validRows);
Smap = Smap(validRows, :);

assert(numel(temps) >= 3, 'Too few valid temperatures for dS/dI averaging.');

SmapFilled = fillMissingByColumn(Smap, temps);
SmapSmoothed = smoothAlongTemperature(SmapFilled, cfg.smoothWindowT);
dSdI = derivativeAlongCurrent(SmapSmoothed, currents);

psiTranslationRaw = -mean(dSdI, 1, 'omitnan')';
psiTranslation = normalizeL2(psiTranslationRaw);

phiCurrents = phiTbl.current_mA(:);
phi1 = phiTbl.phi_1(:);
phi1Norm = normalizeL2(phi1);

if numel(currents) ~= numel(phiCurrents) || any(abs(currents - phiCurrents) > 1e-9)
    psiOnPhiGrid = interp1(currents, psiTranslation, phiCurrents, 'linear', 'extrap');
else
    psiOnPhiGrid = psiTranslation;
end

corrValue = safeCorr(phi1Norm, psiOnPhiGrid);
absCorr = abs(corrValue);
isLikelyTranslation = absCorr >= cfg.translationCorrThreshold;

profilesTbl = table(phiCurrents, phi1, phi1Norm, psiOnPhiGrid, ...
    'VariableNames', {'current_mA', 'phi_1_raw', 'phi_1_norm', 'psi_translation_norm'});
profilesPath = save_run_table(profilesTbl, 'translation_mode_profiles.csv', runDir);

sourceManifestTbl = table( ...
    string({'dynamic_shape_phi'; 'alignment_core_map'; 'full_scaling_parameters'}), ...
    [source.dynamicShapeRunId; source.alignmentRunId; source.fullScalingRunId], ...
    string({source.dynamicPhiPath; source.alignmentCorePath; source.fullScalingParamsPath}), ...
    'VariableNames', {'source_role', 'source_run_id', 'source_file'});
sourceManifestPath = save_run_table(sourceManifestTbl, ...
    'translation_mode_sources.csv', runDir);

figCmp = makeLineFigure();
axCmp = axes(figCmp);
hold(axCmp, 'on');
plot(axCmp, phiCurrents, phi1Norm, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\phi_1(I)');
plot(axCmp, phiCurrents, psiOnPhiGrid, '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', '\psi_{translation}(I) = -\langle\partial_I S\rangle_T');
hold(axCmp, 'off');
xlabel(axCmp, 'Current (mA)');
ylabel(axCmp, 'Normalized spatial profile (a.u.)');
title(axCmp, sprintf('Translation-mode comparison: corr(\\phi_1, \\psi) = %.4f', corrValue));
legend(axCmp, 'Location', 'best');
styleAxes(axCmp);
figPath = save_run_figure(figCmp, 'translation_mode_comparison', runDir);
close(figCmp);

if isLikelyTranslation
    interpText = sprintf([ ...
        'abs(corr) = %.4f >= %.2f, so phi_1 is consistent with ridge translation (up to sign).\n'], ...
        absCorr, cfg.translationCorrThreshold);
else
    interpText = sprintf([ ...
        'abs(corr) = %.4f < %.2f, so phi_1 likely captures a non-translation deformation.\n'], ...
        absCorr, cfg.translationCorrThreshold);
end

corrLines = strings(0, 1);
corrLines(end + 1) = "Translation mode correlation test";
corrLines(end + 1) = "";
corrLines(end + 1) = "corr(phi_1, psi_translation) = " + sprintf('%.6f', corrValue);
corrLines(end + 1) = "abs(corr(phi_1, psi_translation)) = " + sprintf('%.6f', absCorr);
corrLines(end + 1) = "threshold_for_translation = " + sprintf('%.2f', cfg.translationCorrThreshold);
corrLines(end + 1) = "interpretation = " + string(strtrim(interpText));
corrLines(end + 1) = "";
corrLines(end + 1) = "Definition:";
corrLines(end + 1) = "psi_translation(I) = -mean_T(dS/dI).";
corrLines(end + 1) = "Normalization: L2 norm to unit length.";
corrLines(end + 1) = "";
corrLines(end + 1) = "Source runs:";
corrLines(end + 1) = "dynamic_shape_run = " + source.dynamicShapeRunId;
corrLines(end + 1) = "alignment_run = " + source.alignmentRunId;
corrLines(end + 1) = "full_scaling_run = " + source.fullScalingRunId;
corrReportPath = save_run_report(strjoin(corrLines, newline), ...
    'translation_mode_correlation.txt', runDir);

reportPath = save_run_report(buildReportText( ...
    source, temps, phiCurrents, corrValue, absCorr, cfg, ...
    profilesPath, sourceManifestPath, figPath, corrReportPath), ...
    'translation_mode_test_report.md', runDir);

appendText(run.notes_path, sprintf('corr(phi_1, psi_translation) = %.6f\n', corrValue));
appendText(run.notes_path, sprintf('abs(corr(phi_1, psi_translation)) = %.6f\n', absCorr));
appendText(run.notes_path, sprintf('translation threshold = %.2f\n', cfg.translationCorrThreshold));
appendText(run.notes_path, interpText);

zipPath = buildReviewZip(runDir, 'switching_translation_mode_test_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching translation-mode test complete\n', stampNow()));
appendText(run.log_path, sprintf('Profiles table: %s\n', profilesPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourceManifestPath));
appendText(run.log_path, sprintf('Comparison figure: %s\n', figPath.png));
appendText(run.log_path, sprintf('Correlation report: %s\n', corrReportPath));
appendText(run.log_path, sprintf('Summary report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.corrPhi1VsTranslation = corrValue;
out.absCorrPhi1VsTranslation = absCorr;
out.isLikelyTranslation = isLikelyTranslation;
out.paths = struct( ...
    'profilesTable', string(profilesPath), ...
    'sourceManifest', string(sourceManifestPath), ...
    'comparisonFigure', string(figPath.png), ...
    'correlationReport', string(corrReportPath), ...
    'summaryReport', string(reportPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching translation-mode test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(phi_1, psi_translation): %.6f\n', corrValue);
fprintf('abs(corr): %.6f\n', absCorr);
fprintf('Figure: %s\n', figPath.png);
fprintf('Correlation report: %s\n', corrReportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_translation_mode_test');
cfg = setDefault(cfg, 'dynamicShapeRunId', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'smoothWindowT', 3);
cfg = setDefault(cfg, 'speakFloorFraction', 1e-3);
cfg = setDefault(cfg, 'translationCorrThreshold', 0.70);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.dynamicShapeRunId = string(cfg.dynamicShapeRunId);
source.alignmentRunId = string(cfg.alignmentRunId);
source.fullScalingRunId = string(cfg.fullScalingRunId);
source.dynamicShapeRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), ...
    char(source.dynamicShapeRunId));
source.alignmentRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), ...
    char(source.alignmentRunId));
source.fullScalingRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), ...
    char(source.fullScalingRunId));

source.dynamicPhiPath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_modes_phi.csv');
source.alignmentCorePath = fullfile(source.alignmentRunDir, ...
    'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', ...
    'switching_full_scaling_parameters.csv');

requiredFiles = {source.dynamicPhiPath, source.alignmentCorePath, source.fullScalingParamsPath};
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, 'file') ~= 2
        error('Required source file missing: %s', requiredFiles{i});
    end
end
end

function reportText = buildReportText( ...
    source, temps, currents, corrValue, absCorr, cfg, ...
    profilesPath, sourceManifestPath, figPath, corrReportPath)

if absCorr >= cfg.translationCorrThreshold
    verdict = "Likely ridge translation (up to mode sign convention).";
else
    verdict = "Likely a different deformation mechanism (not pure ridge translation).";
end

lines = strings(0, 1);
lines(end + 1) = "# Switching translation-mode test report";
lines(end + 1) = "";
lines(end + 1) = "## Test question";
lines(end + 1) = "Does dynamic shape mode `\phi_1(I)` match the translation profile `-\partial_I S` averaged over temperature?";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- Dynamic shape mode run: `" + source.dynamicShapeRunId + "`.";
lines(end + 1) = "- Alignment map run: `" + source.alignmentRunId + "`.";
lines(end + 1) = "- Full-scaling observable run: `" + source.fullScalingRunId + "`.";
lines(end + 1) = "- Source manifest table: `" + string(sourceManifestPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "- Loaded `S(I,T)` from alignment core map used by dynamic-shape workflow.";
lines(end + 1) = "- Applied light temperature smoothing (`window = " + string(cfg.smoothWindowT) + "`) before derivatives.";
lines(end + 1) = "- Computed current derivative field `\partial_I S(I,T)` via finite differences along current.";
lines(end + 1) = "- Built translation profile `\psi_{translation}(I) = -\langle\partial_I S(I,T)\rangle_T`.";
lines(end + 1) = "- L2-normalized `\psi_{translation}(I)` and compared against normalized `\phi_1(I)`.";
lines(end + 1) = "- Correlation metric: `corr(\phi_1, \psi_{translation})`.";
lines(end + 1) = "";
lines(end + 1) = "## Result";
lines(end + 1) = "- `corr(\phi_1, \psi_{translation}) = " + sprintf('%.6f', corrValue) + "`.";
lines(end + 1) = "- `abs(corr) = " + sprintf('%.6f', absCorr) + "`.";
lines(end + 1) = "- Threshold check (`>= " + sprintf('%.2f', cfg.translationCorrThreshold) + "`): " + verdict;
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- Comparison figure: `" + string(figPath.png) + "`.";
lines(end + 1) = "- Correlation text file: `" + string(corrReportPath) + "`.";
lines(end + 1) = "- Profiles table: `" + string(profilesPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 2 (`\phi_1(I)`, `\psi_{translation}(I)`)";
lines(end + 1) = "- legend vs colormap: legend (<= 6 curves)";
lines(end + 1) = "- colormap used: none (line plot)";
lines(end + 1) = "- smoothing applied: moving-average over temperature with window = " + string(cfg.smoothWindowT);
lines(end + 1) = "- justification: direct two-curve overlay is the clearest test of shape matching";
lines(end + 1) = "";
lines(end + 1) = "Temperature rows used: `" + string(numel(temps)) + "`.";
lines(end + 1) = "Current points used: `" + string(numel(currents)) + "`.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

function fig = makeLineFigure()
fig = figure('Color', 'w', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 8.6 6.2], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 8.6 6.2], ...
    'PaperSize', [8.6 6.2]);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.0, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');
grid(ax, 'on');
end

function Xout = smoothAlongTemperature(Xin, window)
Xout = Xin;
if window <= 1
    return;
end
for j = 1:size(Xin, 2)
    Xout(:, j) = movmean(Xin(:, j), window, 'omitnan', 'Endpoints', 'shrink');
end
end

function Xfilled = fillMissingByColumn(Xin, xAxis)
Xfilled = Xin;
for j = 1:size(Xin, 2)
    col = Xin(:, j);
    finiteMask = isfinite(col);
    if nnz(finiteMask) < 2
        continue;
    end
    if any(~finiteMask)
        Xfilled(~finiteMask, j) = interp1(xAxis(finiteMask), col(finiteMask), ...
            xAxis(~finiteMask), 'linear', 'extrap');
    end
end
end

function dSdI = derivativeAlongCurrent(Smap, currents)
dSdI = NaN(size(Smap));
for it = 1:size(Smap, 1)
    dSdI(it, :) = gradient(Smap(it, :), currents);
end
end

function y = normalizeL2(x)
x = x(:);
xn = norm(x, 2);
if ~isfinite(xn) || xn <= eps
    y = zeros(size(x));
else
    y = x ./ xn;
end
end

function c = safeCorr(x, y)
x = x(:);
y = y(:);
m = isfinite(x) & isfinite(y);
if nnz(m) < 3
    c = NaN;
    return;
end
c = corr(x(m), y(m));
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
