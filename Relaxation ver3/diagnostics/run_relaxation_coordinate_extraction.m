function out = run_relaxation_coordinate_extraction(cfg)
% run_relaxation_coordinate_extraction
% Extract minimal relaxation coordinates from existing temperature profile data.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(diagDir);

cfg.runLabel = getDef(cfg, 'runLabel', 'coordinate_extraction');
cfg.preferredMethod = getDef(cfg, 'preferredMethod', 'sg_010');

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation coordinate extraction run directory:\n%s\n', runDir);

profilePath = resolveProfilePath(repoRoot, cfg);
fprintf('Profile source: %s\n', profilePath);

srcTbl = readtable(profilePath);
[T, profile, meta] = extractProfile(srcTbl, cfg);

[A_relax, T_relax, skew_relax, shoulder_strength, detail] = compute_relaxation_coordinates(T, profile);

tRange = sprintf('%.3f-%.3f K', min(T), max(T));
coordTbl = table(string(tRange), A_relax, T_relax, skew_relax, shoulder_strength, ...
    'VariableNames', {'temperature_range','A_relax','T_relax','skew_relax','shoulder_strength'});
coordPath = save_run_table(coordTbl, 'coordinates_relaxation.csv', runDir);

fig = figure('Color','w','Visible','off','Position',[120 120 980 620]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14);
plot(ax, detail.T, detail.profile, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.10 0.35 0.75], ...
    'DisplayName', 'profile(T)=S_{max}(T)');
plot(ax, T_relax, A_relax, '^', 'MarkerSize', 10, 'MarkerFaceColor', [0.85 0.10 0.10], ...
    'MarkerEdgeColor', [0.45 0.05 0.05], 'DisplayName', 'T_{relax}, A_{relax}');

if isfinite(detail.half_level)
    yline(ax, detail.half_level, '--', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.6, 'DisplayName', 'half-level');
end
if isfinite(detail.T_left)
    xline(ax, detail.T_left, '--', 'Color', [0.10 0.55 0.10], 'LineWidth', 1.6, 'DisplayName', 'T_{left}');
end
if isfinite(detail.T_right)
    xline(ax, detail.T_right, '--', 'Color', [0.70 0.45 0.05], 'LineWidth', 1.6, 'DisplayName', 'T_{right}');
end
xline(ax, T_relax, '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.8, 'DisplayName', 'T_{relax}');

xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, 'S_{max}(T) (a.u.)', 'FontSize', 15);
title(ax, 'Relaxation Profile with Extracted Coordinates', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 12);
figPaths = save_run_figure(fig, 'profile_T_with_coordinates', runDir);
close(fig);

reportLines = [
"# Relaxation Coordinate Extraction"
""
"## Inputs"
"- Profile source table: `" + string(profilePath) + "`"
"- Profile metric: `S_max(T)`"
"- Preferred method filter: `" + string(meta.method_used) + "`"
""
"## Extracted Coordinates"
"- `A_relax = " + string(A_relax) + "`"
"- `T_relax = " + string(T_relax) + " K`"
"- `skew_relax = " + string(skew_relax) + "`"
"- `shoulder_strength = " + string(shoulder_strength) + "`"
"- `T_left = " + string(detail.T_left) + " K`"
"- `T_right = " + string(detail.T_right) + " K`"
""
"## Visualization choices"
"- number of curves: 1 profile curve + coordinate markers"
"- legend vs colormap: legend (no colormap, <=6 curves)"
"- smoothing applied: none (profile loaded from existing exported metric)"
"- justification: single profile inspection with explicit coordinate markers is most interpretable"
""
"## Artifacts"
"- `tables/coordinates_relaxation.csv`"
"- `figures/profile_T_with_coordinates.png`"
"- `figures/profile_T_with_coordinates.fig`"
];
reportPath = save_run_report(strjoin(reportLines, newline), 'relaxation_coordinate_extraction.md', runDir);

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, sprintf('relaxation_coordinate_extraction_%s.zip', run.run_id));
if exist(zipPath, 'file')
    delete(zipPath);
end
zipInputs = {
    'tables/coordinates_relaxation.csv', ...
    'figures/profile_T_with_coordinates.png', ...
    'figures/profile_T_with_coordinates.fig', ...
    'reports/relaxation_coordinate_extraction.md', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);

appendText(run.log_path, sprintf('[%s] coordinate extraction completed\n', stampNow()));
appendText(run.notes_path, sprintf('Coordinate extraction source: %s\n', profilePath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.profilePath = string(profilePath);
out.coordinatesPath = string(coordPath);
out.figurePng = string(figPaths.png);
out.figureFig = string(figPaths.fig);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.coordinates = coordTbl;

fprintf('\n=== Relaxation coordinate extraction complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Coordinates table: %s\n', coordPath);
fprintf('Figure PNG: %s\n', figPaths.png);
fprintf('ZIP: %s\n\n', zipPath);
end

function profilePath = resolveProfilePath(repoRoot, cfg)
if isfield(cfg, 'profileCsvPath') && ~isempty(cfg.profileCsvPath)
    profilePath = char(string(cfg.profileCsvPath));
    if exist(profilePath, 'file') ~= 2
        error('Provided profileCsvPath not found: %s', profilePath);
    end
    return;
end

runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
if exist(runsRoot, 'dir') ~= 7
    error('Relaxation runs directory not found: %s', runsRoot);
end

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No run directories found under %s', runsRoot);
end

names = string({runDirs.name});
valid = ~startsWith(names, "run_legacy", 'IgnoreCase', true);
runDirs = runDirs(valid);
if isempty(runDirs)
    error('No non-legacy run directories found under %s', runsRoot);
end

[~, ord] = sort({runDirs.name});
runDirs = runDirs(ord);

candidates = {
    fullfile('tables', 'S_ridge_peak_trajectory.csv'), ...
    fullfile('csv', 'S_ridge_peak_trajectory.csv'), ...
    fullfile('derivative_smoothing', 'S_ridge_peak_trajectory.csv') ...
};

profilePath = '';
for i = numel(runDirs):-1:1
    rd = fullfile(runDirs(i).folder, runDirs(i).name);
    for c = 1:numel(candidates)
        p = fullfile(rd, candidates{c});
        if exist(p, 'file') == 2
            profilePath = p;
            return;
        end
    end
end

error('Could not locate S_ridge_peak_trajectory.csv in recent relaxation runs.');
end

function [T, profile, meta] = extractProfile(srcTbl, cfg)
need = {'Temp_K','S_max'};
for k = 1:numel(need)
    if ~ismember(need{k}, srcTbl.Properties.VariableNames)
        error('Profile table missing required column: %s', need{k});
    end
end

useTbl = srcTbl;
methodUsed = "all";
if ismember('method', srcTbl.Properties.VariableNames)
    preferred = string(cfg.preferredMethod);
    m = string(srcTbl.method) == preferred;
    if any(m)
        useTbl = srcTbl(m,:);
        methodUsed = preferred;
    end
end

T = useTbl.Temp_K;
profile = useTbl.S_max;

% Aggregate duplicate temperatures (if present).
T = T(:);
profile = profile(:);
valid = isfinite(T) & isfinite(profile);
T = T(valid);
profile = profile(valid);

if isempty(T)
    error('No finite Temp_K/S_max rows after filtering.');
end

[Tu, ~, g] = unique(T, 'stable');
Pu = accumarray(g, profile, [numel(Tu), 1], @(x) mean(x, 'omitnan'), NaN);
T = Tu;
profile = Pu;

meta = struct('method_used', methodUsed);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = getDef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
