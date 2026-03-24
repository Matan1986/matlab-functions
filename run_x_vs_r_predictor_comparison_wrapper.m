function run_x_vs_r_predictor_comparison_wrapper()
% RUN_X_VS_R_PREDICTOR_COMPARISON_WRAPPER
% Compare switching-side predictors for aging competition observable R.

baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));

repoRoot = baseFolder;
analysisName = 'x_vs_r_predictor_comparison';
[outDir, run] = init_run_output_dir(repoRoot, 'switching', analysisName); %#ok<ASGLU>
runDir = resolve_run_dir(outDir, run);

% Inputs from existing run outputs.
axPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_13_115401_AX_functional_relation_analysis', 'tables', 'AX_aligned_data.csv');
rPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_22_001750_r_observable_export', 'observables.csv');

if exist(axPath, 'file') ~= 2
    error('Missing AX aligned data file: %s', axPath);
end
if exist(rPath, 'file') ~= 2
    error('Missing aging R file: %s', rPath);
end

ax = readtable(axPath);
rRaw = readtable(rPath);

Robs = extract_r_observable(rRaw);

switchingT = double(ax.T_K);
X = double(ax.X);
Ipeak = double(ax.I_peak_mA);
widthI = double(ax.width_mA);
Speak = double(ax.S_peak);

candidateNames = {
    'X', ...
    'I_peak', ...
    'width_I', ...
    'S_peak', ...
    'width_I_times_S_peak', ...
    'I_peak_over_width_I', ...
    'I_peak_over_S_peak'};

candidateUnits = {
    'arb.', ...
    'mA', ...
    'mA', ...
    'fraction', ...
    'mA*fraction', ...
    'unitless', ...
    'mA'};

candidateValues = {
    X, ...
    Ipeak, ...
    widthI, ...
    Speak, ...
    widthI .* Speak, ...
    Ipeak ./ widthI, ...
    Ipeak ./ Speak};

% Align by overlapping temperatures with finite R and finite predictor values.
[Tcommon, idxAx, idxR] = intersect(switchingT, Robs.T, 'stable');
if numel(Tcommon) < 3
    error('Need at least 3 overlapping temperatures between switching and R. Found %d.', numel(Tcommon));
end

Rcommon = Robs.R(idxR);
finiteR = isfinite(Rcommon);
Tcommon = Tcommon(finiteR);
idxAx = idxAx(finiteR);
Rcommon = Rcommon(finiteR);

aligned = table(Tcommon, Rcommon, 'VariableNames', {'T_K', 'R'});
for i = 1:numel(candidateNames)
    yi = candidateValues{i}(idxAx);
    aligned.(candidateNames{i}) = yi;
end

save_run_table(aligned, 'aligned_candidate_data.csv', runDir);

nCand = numel(candidateNames);
metrics = table('Size', [nCand 12], ...
    'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'candidate', 'units', 'n_points', 'pearson_r', 'spearman_rho', 'powerlaw_C', 'powerlaw_gamma', 'fit_rmse', 'fit_r2', 'T_peak_Y_K', 'dT_peak_vs_R_K', 'composite_score'});

TpeakR = NaN;
if ~isempty(Rcommon)
    [~, iRmax] = max(Rcommon);
    TpeakR = Tcommon(iRmax);
end

fitCurves = cell(nCand, 1);
for i = 1:nCand
    y = aligned.(candidateNames{i});
    stats = evaluate_candidate(y, Rcommon, Tcommon, TpeakR);
    metrics.candidate(i) = string(candidateNames{i});
    metrics.units(i) = string(candidateUnits{i});
    metrics.n_points(i) = stats.n;
    metrics.pearson_r(i) = stats.pearson;
    metrics.spearman_rho(i) = stats.spearman;
    metrics.powerlaw_C(i) = stats.C;
    metrics.powerlaw_gamma(i) = stats.gamma;
    metrics.fit_rmse(i) = stats.rmse;
    metrics.fit_r2(i) = stats.r2;
    metrics.T_peak_Y_K(i) = stats.TpeakY;
    metrics.dT_peak_vs_R_K(i) = stats.dTpeak;
    fitCurves{i} = stats.fitCurve;
end

scores = build_composite_scores(metrics);
metrics.composite_score = scores;

metrics = sortrows(metrics, {'composite_score', 'fit_r2', 'spearman_rho', 'pearson_r', 'fit_rmse'}, ...
    {'descend', 'descend', 'descend', 'descend', 'ascend'});
metrics.rank = (1:height(metrics))';

save_run_table(metrics, 'candidate_comparison_table.csv', runDir);

make_scatter_fit_figure(aligned, metrics, candidateNames, candidateUnits, fitCurves, runDir);
make_ranking_figure(metrics, runDir);

answer = build_explicit_answers(metrics);
reportText = build_summary_report(metrics, aligned, answer, axPath, rPath, runDir);
save_run_report(reportText, 'summary_report.md', runDir);

zipPath = fullfile(runDir, 'review', 'x_vs_r_predictor_comparison_package.zip');
ensure_dir(fullfile(runDir, 'review'));
create_run_zip(runDir, zipPath);

fprintf('Run complete: %s\n', runDir);
fprintf('ZIP package: %s\n', zipPath);
end

function Robs = extract_r_observable(rRaw)
vNames = rRaw.Properties.VariableNames;
obsCol = find(strcmpi(vNames, 'observable'), 1);
tempCol = find(strcmpi(vNames, 'temperature'), 1);
valCol = find(strcmpi(vNames, 'value'), 1);

if isempty(obsCol) || isempty(tempCol) || isempty(valCol)
    error('R table missing one of required columns: observable, temperature, value.');
end

obs = string(rRaw{:, obsCol});
t = str2double(string(rRaw{:, tempCol}));
r = str2double(string(rRaw{:, valCol}));

mask = strcmp(obs, "R") & isfinite(t);
Robs = table(t(mask), r(mask), 'VariableNames', {'T', 'R'});
Robs = sortrows(Robs, 'T');
end

function stats = evaluate_candidate(y, r, t, TpeakR)
maskFinite = isfinite(y) & isfinite(r);
yy = y(maskFinite);
rr = r(maskFinite);
tt = t(maskFinite);

stats = struct();
stats.n = numel(yy);
stats.pearson = NaN;
stats.spearman = NaN;
stats.C = NaN;
stats.gamma = NaN;
stats.rmse = NaN;
stats.r2 = NaN;
stats.TpeakY = NaN;
stats.dTpeak = NaN;
stats.fitCurve = table([], [], 'VariableNames', {'Y', 'R_fit'});

if numel(yy) < 3
    return;
end

stats.pearson = corr(yy, rr, 'type', 'Pearson');
stats.spearman = corr(yy, rr, 'type', 'Spearman');

if any(isfinite(yy))
    [~, iYmax] = max(yy);
    stats.TpeakY = tt(iYmax);
    if isfinite(TpeakR)
        stats.dTpeak = stats.TpeakY - TpeakR;
    end
end

maskPower = (yy > 0) & (rr > 0);
if nnz(maskPower) < 3
    return;
end

xp = yy(maskPower);
rp = rr(maskPower);
logx = log(xp);
logr = log(rp);
p = polyfit(logx, logr, 1);
stats.gamma = p(1);
stats.C = exp(p(2));

rFit = stats.C .* xp .^ stats.gamma;
stats.rmse = sqrt(mean((rp - rFit) .^ 2));
sst = sum((rp - mean(rp)) .^ 2);
if sst > 0
    stats.r2 = 1 - sum((rp - rFit) .^ 2) / sst;
end

[xpSorted, sidx] = sort(xp);
rfitSorted = rFit(sidx);
stats.fitCurve = table(xpSorted, rfitSorted, 'VariableNames', {'Y', 'R_fit'});
end

function scores = build_composite_scores(metrics)
absPear = abs(metrics.pearson_r);
absSpe = abs(metrics.spearman_rho);
r2 = metrics.fit_r2;
rmse = metrics.fit_rmse;
dT = abs(metrics.dT_peak_vs_R_K);

sPear = minmax_scale(absPear);
sSpe = minmax_scale(absSpe);
sR2 = minmax_scale(fillmissing(r2, 'constant', min(r2, [], 'omitnan')));
sRmse = 1 - minmax_scale(fillmissing(rmse, 'constant', max(rmse, [], 'omitnan')));
sPeak = 1 - minmax_scale(fillmissing(dT, 'constant', max(dT, [], 'omitnan')));

scores = 0.30 * sR2 + 0.25 * sSpe + 0.20 * sPear + 0.20 * sRmse + 0.05 * sPeak;
scores(~isfinite(scores)) = 0;
end

function s = minmax_scale(x)
x = double(x);
x(~isfinite(x)) = NaN;
if all(isnan(x))
    s = zeros(size(x));
    return;
end
xmin = min(x, [], 'omitnan');
xmax = max(x, [], 'omitnan');
if xmax <= xmin
    s = ones(size(x));
    s(~isfinite(x)) = 0;
    return;
end
s = (x - xmin) ./ (xmax - xmin);
s(~isfinite(s)) = 0;
end

function make_scatter_fit_figure(aligned, metrics, candidateNames, candidateUnits, fitCurves, runDir)
base_name = 'scatter_powerlaw_fits_all_candidates';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w');
tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for i = 1:numel(candidateNames)
    nexttile(i);
    y = aligned.(candidateNames{i});
    r = aligned.R;
    mask = isfinite(y) & isfinite(r);

    scatter(y(mask), r(mask), 60, 'filled', 'MarkerFaceColor', [0.00 0.45 0.74]);
    hold on;
    fc = fitCurves{i};
    if ~isempty(fc) && height(fc) > 0
        plot(fc.Y, fc.R_fit, '-', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10]);
        legend({'data', 'power-law fit'}, 'Location', 'best', 'FontSize', 10);
    else
        legend({'data'}, 'Location', 'best', 'FontSize', 10);
    end
    xlabel(sprintf('%s (%s)', candidateNames{i}, candidateUnits{i}), 'FontSize', 14);
    ylabel('R (unitless)', 'FontSize', 14);
    title(sprintf('%s | R^2=%.3f', candidateNames{i}, get_metric(metrics, candidateNames{i}, 'fit_r2')), 'FontSize', 12);
    set(gca, 'LineWidth', 1.2, 'FontSize', 12, 'Box', 'off');
    grid on;
end

nexttile(8);
axis off;
text(0, 1, sprintf('Overlap temperatures: %s K', num2str(aligned.T_K', ' %.0f')), 'FontSize', 12, 'VerticalAlignment', 'top');
text(0, 0.78, sprintf('N overlap = %d', height(aligned)), 'FontSize', 12, 'VerticalAlignment', 'top');
text(0, 0.60, 'Model: R ~ C * Y^{gamma}', 'FontSize', 12, 'VerticalAlignment', 'top');

nexttile(9);
axis off;
top = metrics(1:min(3, height(metrics)), :);
summaryLines = strings(height(top), 1);
for k = 1:height(top)
    summaryLines(k) = sprintf('%d) %s (score %.3f)', top.rank(k), top.candidate(k), top.composite_score(k));
end
text(0, 1, strjoin(["Top candidates:"; summaryLines], newline), 'FontSize', 12, 'VerticalAlignment', 'top');

save_run_figure(fig, base_name, runDir);
close(fig);
end

function make_ranking_figure(metrics, runDir)
base_name = 'candidate_ranking_composite_score';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w');

sorted = sortrows(metrics, 'composite_score', 'descend');
labels = cellstr(sorted.candidate);
scores = sorted.composite_score;

b = barh(scores, 'FaceColor', [0.2 0.6 0.5]);
set(b, 'LineWidth', 1.2);
set(gca, 'YDir', 'reverse', 'YTick', 1:numel(labels), 'YTickLabel', labels, ...
    'FontSize', 13, 'LineWidth', 1.2, 'Box', 'off');
xlabel('Composite performance score (higher is better)', 'FontSize', 14);
ylabel('Candidate observable', 'FontSize', 14);
grid on;

% Highlight X for direct model test visibility.
for i = 1:numel(labels)
    if strcmp(labels{i}, 'X')
        hold on;
        plot(scores(i), i, 'ko', 'MarkerSize', 9, 'LineWidth', 2);
    end
end

save_run_figure(fig, base_name, runDir);
close(fig);
end

function value = get_metric(metrics, candidateName, metricName)
row = strcmp(string(metrics.candidate), string(candidateName));
if any(row)
    value = metrics.(metricName)(find(row, 1));
else
    value = NaN;
end
end

function answer = build_explicit_answers(metrics)
bestName = string(metrics.candidate(1));

answer = struct();
answer.bestCandidate = bestName;
answer.xOutperforms = strcmp(bestName, "X");
answer.widthEnough = is_top_or_close(metrics, "width_I");
answer.speakEnough = is_top_or_close(metrics, "S_peak");
answer.ipeakEnough = is_top_or_close(metrics, "I_peak");
end

function tf = is_top_or_close(metrics, target)
row = find(strcmp(string(metrics.candidate), target), 1);
if isempty(row)
    tf = false;
    return;
end
top = metrics.composite_score(1);
score = metrics.composite_score(row);
tf = score >= (top - 0.05);
end

function reportText = build_summary_report(metrics, aligned, answer, axPath, rPath, runDir)
top3 = metrics(1:min(3, height(metrics)), :);

lines = strings(0, 1);
lines(end + 1) = '# X vs Simpler Predictors for Aging R';
lines(end + 1) = '';
lines(end + 1) = '## Scope';
lines(end + 1) = 'Test whether X is the best switching-side predictor of aging competition observable R using only existing run outputs.';
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
lines(end + 1) = sprintf('- AX aligned data: %s', axPath);
lines(end + 1) = sprintf('- Aging R data: %s', rPath);
lines(end + 1) = sprintf('- Overlap temperatures (K): %s', num2str(aligned.T_K', ' %.0f'));
lines(end + 1) = sprintf('- N overlap: %d', height(aligned));
lines(end + 1) = '';
lines(end + 1) = '## Candidate Set';
lines(end + 1) = '- X';
lines(end + 1) = '- I_peak';
lines(end + 1) = '- width_I';
lines(end + 1) = '- S_peak';
lines(end + 1) = '- width_I * S_peak';
lines(end + 1) = '- I_peak / width_I';
lines(end + 1) = '- I_peak / S_peak';
lines(end + 1) = '';
lines(end + 1) = '## Ranking (Top 3)';
for i = 1:height(top3)
    lines(end + 1) = sprintf('%d. %s | score=%.3f | R^2=%.3f | Pearson=%.3f | Spearman=%.3f | RMSE=%.3f', ...
        top3.rank(i), top3.candidate(i), top3.composite_score(i), top3.fit_r2(i), top3.pearson_r(i), top3.spearman_rho(i), top3.fit_rmse(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Required Explicit Answers';
lines(end + 1) = sprintf('- Does X outperform the simpler alternatives? %s', yesno(answer.xOutperforms));
lines(end + 1) = sprintf('- Is width_I alone enough? %s', yesno(answer.widthEnough));
lines(end + 1) = sprintf('- Is S_peak alone enough? %s', yesno(answer.speakEnough));
lines(end + 1) = sprintf('- Is I_peak alone enough? %s', yesno(answer.ipeakEnough));
lines(end + 1) = '';
lines(end + 1) = '## Interpretation';
lines(end + 1) = sprintf('- Best candidate by composite score: %s', answer.bestCandidate);
lines(end + 1) = '- X was evaluated directly against simpler one-factor and two-factor alternatives from switching observables.';
lines(end + 1) = '- Because overlap is limited, this comparison should be interpreted as directional evidence and not as final exclusion of near-tied candidates.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- Number of curves: one data series + one fitted curve per candidate panel.';
lines(end + 1) = '- Legend vs colormap: legend used (<= 6 curves per panel).';
lines(end + 1) = '- Colormap used: none (single-color scatter + single-color fit).';
lines(end + 1) = '- Smoothing applied: none.';
lines(end + 1) = '- Justification: direct scatter + power-law fit is the clearest test for predictor quality against R.';
lines(end + 1) = '';
lines(end + 1) = '## Artifacts';
lines(end + 1) = sprintf('- Run directory: %s', runDir);
lines(end + 1) = '- Figures: scatter/fits and ranking.';
lines(end + 1) = '- Tables: aligned data and ranked comparison metrics.';
lines(end + 1) = '- Review ZIP: review/x_vs_r_predictor_comparison_package.zip';

reportText = strjoin(lines, newline);
end

function txt = yesno(tf)
if tf
    txt = 'YES';
else
    txt = 'NO';
end
end

function ensure_dir(p)
if exist(p, 'dir') ~= 7
    mkdir(p);
end
end

function create_run_zip(runDir, zipPath)
files = [collect_files(fullfile(runDir, 'figures')); ...
    collect_files(fullfile(runDir, 'tables')); ...
    collect_files(fullfile(runDir, 'reports'))];

if isempty(files)
    warning('No files found to package into ZIP.');
    return;
end

if exist(zipPath, 'file') == 2
    delete(zipPath);
end

zip(zipPath, files, runDir);
fprintf('Created ZIP package: %s\n', zipPath);
end

function files = collect_files(folder)
files = {};
if exist(folder, 'dir') ~= 7
    return;
end
d = dir(fullfile(folder, '**', '*'));
for i = 1:numel(d)
    if ~d(i).isdir
        files{end + 1, 1} = fullfile(d(i).folder, d(i).name); %#ok<AGROW>
    end
end
end

function runDir = resolve_run_dir(outDir, run)
if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
    runDir = char(string(run.run_dir));
    return;
end

runDir = char(string(outDir));
while true
    [parentDir, dirName, ext] = fileparts(runDir);
    if isempty(dirName) && isempty(ext)
        break;
    end
    fullName = [dirName ext];
    if startsWith(string(fullName), "run_", 'IgnoreCase', true)
        return;
    end
    if strcmp(parentDir, runDir)
        break;
    end
    runDir = parentDir;
end

error('Could not resolve run directory from path: %s', outDir);
end