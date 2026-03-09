function out = visualize_relaxation_geometry(dataDir, cfg)
% visualize_relaxation_geometry
% Geometric visualization of relaxation curves M(T,t) on a common log-time grid.
% This is a diagnostics-only script and does not modify the core pipeline.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'nLogGrid', 320);
cfg = setDef(cfg, 'smoothSpan', 1);  % keep minimal smoothing by default

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'geometry_maps', dataDir); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

[fileList, ~, ~, ~, ~, ~] = getFileList_relaxation(char(dataDir), 'parula');
[Time_table, Temp_table, ~, Moment_table, ~] = ...
    importFiles_relaxation(char(dataDir), fileList, cfg.normalizeByMass, false);

if cfg.convertToMuBCo
    x_Co = 1/3;
    m_mol = 58.9332/3 + 180.948 + 2*32.066;
    muB = 9.274e-21;
    NA  = 6.022e23;
    convFactor = m_mol / (NA * muB * x_Co);
    for i = 1:numel(Moment_table)
        if ~isempty(Moment_table{i})
            Moment_table{i} = Moment_table{i} * convFactor;
        end
    end
end

nCurves = numel(Time_table);
Tnom = nan(nCurves,1);
tMin = nan(nCurves,1);
tMax = nan(nCurves,1);
nPts = nan(nCurves,1);

for i = 1:nCurves
    Tnom(i) = parseNominalTemp(fileList{i}, Temp_table{i});
    t = Time_table{i};
    m = Moment_table{i};
    if isempty(t) || isempty(m)
        continue;
    end
    ok = isfinite(t) & isfinite(m) & (t > 0);
    t = t(ok);
    if isempty(t)
        continue;
    end
    [t, iu] = unique(t, 'stable');
    tMin(i) = min(t);
    tMax(i) = max(t);
    nPts(i) = numel(iu);
end

summaryTbl = table((1:nCurves)', string(fileList(:)), Tnom, tMin, tMax, nPts, ...
    'VariableNames', {'data_idx','file_name','Temp_K','t_min_s','t_max_s','n_points'});
summaryTbl = sortrows(summaryTbl, 'Temp_K');
writetable(summaryTbl, fullfile(outDir, 'geometry_dataset_summary.csv'));

% Keep only valid curves
valid = isfinite(Tnom) & isfinite(tMin) & isfinite(tMax) & (tMax > tMin);
if ~any(valid)
    error('No valid relaxation curves found for geometry visualization.');
end

Tvec = Tnom(valid);
[Ts, ordT] = sort(Tvec, 'ascend');
validIdx = find(valid);
validIdx = validIdx(ordT);

% Common log-time grid over overlap region
allTmin = tMin(validIdx);
allTmax = tMax(validIdx);
tLo = max(allTmin);
tHi = min(allTmax);
if ~(isfinite(tLo) && isfinite(tHi) && (tHi > tLo))
    error('Invalid common time overlap across temperatures.');
end

xGrid = linspace(log10(tLo), log10(tHi), cfg.nLogGrid);
tGrid = 10.^xGrid;

nT = numel(validIdx);
Mgrid = nan(nT, cfg.nLogGrid);
for r = 1:nT
    i = validIdx(r);
    t = Time_table{i};
    m = Moment_table{i};
    ok = isfinite(t) & isfinite(m) & (t > 0);
    t = t(ok);
    m = m(ok);
    [t, ord] = sort(t, 'ascend');
    m = m(ord);
    [t, iu] = unique(t, 'stable');
    m = m(iu);

    if numel(t) < 10
        continue;
    end

    x = log10(t);
    y = m;
    Mgrid(r,:) = interp1(x, y, xGrid, 'pchip', nan);
end

if cfg.smoothSpan > 1
    for r = 1:nT
        Mgrid(r,:) = smoothdata(Mgrid(r,:), 'movmean', cfg.smoothSpan);
    end
end

% Derived maps
Mnorm = Mgrid - Mgrid(:,end);

Slope = nan(size(Mgrid));
Curv = nan(size(Mgrid));
for r = 1:nT
    y = Mgrid(r,:);
    if any(~isfinite(y))
        continue;
    end
    d1 = gradient(y, xGrid);
    d2 = gradient(d1, xGrid);
    Slope(r,:) = d1;
    Curv(r,:) = d2;
end

% A) M(T,log t)
plotMap(xGrid, Ts, Mgrid, 'M(T, log_{10}t)', 'Magnetization M', parula, ...
    fullfile(outDir, 'relaxation_map_M_logt.png'));

% B) Offset-normalized M(T,log t)
plotMap(xGrid, Ts, Mnorm, 'M(T, log_{10}t) - M(T, t_{ref})', 'M_{norm}', turbo, ...
    fullfile(outDir, 'relaxation_map_Mnorm_logt.png'));

% C) Slope map dM/dlog10(t)
plotMap(xGrid, Ts, Slope, 'dM/dlog_{10}(t)', 'Slope', hot, ...
    fullfile(outDir, 'relaxation_map_slope.png'));

% D) Curvature map d^2M/d(log10(t))^2
plotMap(xGrid, Ts, Curv, 'd^2M/d(log_{10}(t))^2', 'Curvature', cool, ...
    fullfile(outDir, 'relaxation_map_curvature.png'));

% Temperature cuts: M vs log(t), slope vs log(t)
figCuts = figure('Color','w','Visible','off','Position',[100 100 1350 520]);
tl = tiledlayout(figCuts,1,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
lineCols = turbo(max(nT,3));
for r = 1:nT
    c = lineCols(r,:);
    plot(ax1, xGrid, Mgrid(r,:), '-', 'Color', c, 'LineWidth', 1.2);
    plot(ax2, xGrid, Slope(r,:), '-', 'Color', c, 'LineWidth', 1.2);
end
xlabel(ax1, 'log_{10}(t [s])'); ylabel(ax1, 'M');
title(ax1, 'Temperature cuts: M vs log_{10}(t)');
xlabel(ax2, 'log_{10}(t [s])'); ylabel(ax2, 'dM/dlog_{10}(t)');
title(ax2, 'Temperature cuts: slope vs log_{10}(t)');
colormap(ax1, turbo);
colormap(ax2, turbo);
saveas(figCuts, fullfile(outDir, 'relaxation_temperature_cuts.png'));
close(figCuts);

% Time cuts: M(T) at representative times (early/intermediate/late)
repTimes = chooseRepresentativeTimes(tLo, tHi);
repIdx = zeros(size(repTimes));
for k = 1:numel(repTimes)
    [~, repIdx(k)] = min(abs(tGrid - repTimes(k)));
end

figTimeCuts = figure('Color','w','Visible','off','Position',[120 120 760 520]);
ax = axes(figTimeCuts); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cc = lines(numel(repTimes));
for k = 1:numel(repTimes)
    yk = Mgrid(:, repIdx(k));
    plot(ax, Ts, yk, '-o', 'Color', cc(k,:), 'LineWidth', 1.6, 'MarkerSize', 5, ...
        'DisplayName', sprintf('t = %.0f s', tGrid(repIdx(k))));
end
xlabel(ax, 'Temperature [K]');
ylabel(ax, 'M(T)');
title(ax, 'Time cuts: M(T) at early/intermediate/late times');
legend(ax, 'Location', 'best');
saveas(figTimeCuts, fullfile(outDir, 'relaxation_time_cuts.png'));
close(figTimeCuts);

out = struct();
out.dataDir = string(dataDir);
out.outDir = string(outDir);
out.nCurves = nT;
out.temps_K = Ts;
out.tGrid_s = tGrid;
out.Mgrid = Mgrid;
out.Mnorm = Mnorm;
out.Slope = Slope;
out.Curv = Curv;
out.summary = summaryTbl;
out.repTimes_s = tGrid(repIdx);

fprintf('\n=== Relaxation geometry diagnostics complete ===\n');
fprintf('Data dir: %s\n', dataDir);
fprintf('Valid curves: %d\n', nT);
fprintf('Common time range: %.3f .. %.3f s\n', tLo, tHi);
fprintf('Output dir: %s\n\n', outDir);

end

function v = setDef(s, f, d)
if ~isfield(s, f)
    s.(f) = d;
end
v = s;
end

function T = parseNominalTemp(fname, Tvec)
T = NaN;
m = regexp(char(fname), '([0-9]+\.?[0-9]*)\s*[Kk]', 'tokens', 'once');
if ~isempty(m)
    T = str2double(m{1});
end
if ~isfinite(T) && ~isempty(Tvec)
    tv = Tvec(isfinite(Tvec));
    if ~isempty(tv)
        T = mean(tv, 'omitnan');
    end
end
end

function plotMap(xGrid, Tvec, Z, ttl, cblabel, cmap, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 900 560]);
ax = axes(fig); %#ok<LAXES>
imagesc(ax, xGrid, Tvec, Z);
set(ax, 'YDir', 'normal');
xlabel(ax, 'log_{10}(t [s])');
ylabel(ax, 'Temperature [K]');
title(ax, ttl);
cb = colorbar(ax);
ylabel(cb, cblabel);
colormap(ax, cmap);
grid(ax, 'on');
box(ax, 'on');

zv = Z(isfinite(Z));
if ~isempty(zv)
    clim = prctile(zv, [2 98]);
    if isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1)
        caxis(ax, clim);
    end
end

saveas(fig, outFile);
close(fig);
end

function repTimes = chooseRepresentativeTimes(tLo, tHi)
base = [60 600 2400];
keep = base(base > tLo & base < tHi);
if numel(keep) >= 3
    repTimes = keep(1:3);
    return;
end
x = linspace(log10(tLo), log10(tHi), 5);
repTimes = [10.^x(2), 10.^x(3), 10.^x(4)];
end

