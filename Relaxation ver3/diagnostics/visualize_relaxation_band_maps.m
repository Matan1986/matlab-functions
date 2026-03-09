function out = visualize_relaxation_band_maps(dataDir, cfg)
% visualize_relaxation_band_maps
% Diagnostics-only map builder focused on the true relaxation region.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'nLogGrid', 320);
cfg = setDef(cfg, 'smoothSpan', 1);          % keep minimal smoothing
cfg = setDef(cfg, 'tailFrac', 0.20);         % for plateau/noise estimation
cfg = setDef(cfg, 'smallFrac', 0.12);        % small threshold fraction (noise->peak)
cfg = setDef(cfg, 'spikeFrac', 0.92);        % spike threshold fraction (noise->peak)
cfg = setDef(cfg, 'minRunFrac', 0.03);       % minimum contiguous run to keep

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'geometry_maps_relaxband', dataDir); %#ok<ASGLU>
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

valid = isfinite(Tnom) & isfinite(tMin) & isfinite(tMax) & (tMax > tMin);
if ~any(valid)
    error('No valid relaxation curves found.');
end

Tvec = Tnom(valid);
[Ts, ordT] = sort(Tvec, 'ascend');
validIdx = find(valid);
validIdx = validIdx(ordT);

allTmin = tMin(validIdx);
allTmax = tMax(validIdx);
tLo = max(allTmin);
tHi = min(allTmax);
if ~(isfinite(tLo) && isfinite(tHi) && (tHi > tLo))
    error('Invalid common overlap time range.');
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
    Mgrid(r,:) = interp1(x, m, xGrid, 'pchip', nan);
end

if cfg.smoothSpan > 1
    for r = 1:nT
        Mgrid(r,:) = smoothdata(Mgrid(r,:), 'movmean', cfg.smoothSpan);
    end
end

Mnorm = Mgrid - Mgrid(:, end);
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

[bandMask, bandTbl] = detectRelaxationBand(Ts, tGrid, xGrid, Slope, Curv, cfg);
writetable(bandTbl, fullfile(outDir, 'relaxation_band_summary.csv'));

MnormBand = Mnorm;
SlopeBand = Slope;
CurvBand = Curv;
MnormBand(~bandMask) = NaN;
SlopeBand(~bandMask) = NaN;
CurvBand(~bandMask) = NaN;

fig1 = fullfile(outDir, 'relaxation_map_Mnorm_logt_relaxband.png');
fig2 = fullfile(outDir, 'relaxation_map_slope_relaxband.png');
fig3 = fullfile(outDir, 'relaxation_map_curvature_relaxband.png');
fig4 = fullfile(outDir, 'relaxation_band_window_vs_temp.png');

plotMapMasked(xGrid, Ts, MnormBand, ...
    'M_{norm}(T, log_{10}t) in detected relaxation band', 'M_{norm}', turbo, fig1);
plotMapMasked(xGrid, Ts, SlopeBand, ...
    'dM/dlog_{10}(t) in detected relaxation band', 'Slope', hot, fig2);
plotMapMasked(xGrid, Ts, CurvBand, ...
    'd^2M/d(log_{10}t)^2 in detected relaxation band', 'Curvature', cool, fig3);

plotBandWindowVsTemp(bandTbl, fig4);

zipPath = fullfile(outDir, 'relaxation_relaxband_figures.zip');
zipFiles = {fig1, fig2, fig3, fig4};
if exist(zipPath, 'file')
    delete(zipPath);
end
zip(zipPath, zipFiles);

out = struct();
out.dataDir = string(dataDir);
out.outDir = string(outDir);
out.nCurves = nT;
out.temps_K = Ts;
out.tGrid_s = tGrid;
out.bandSummary = bandTbl;
out.zipPath = string(zipPath);
out.figures = string(zipFiles);

fprintf('\n=== Relaxation band maps complete ===\n');
fprintf('Data dir: %s\n', dataDir);
fprintf('Valid curves: %d\n', nT);
fprintf('Common overlap: %.3f .. %.3f s\n', tLo, tHi);
fprintf('Figures ZIP: %s\n', zipPath);
fprintf('Output dir: %s\n\n', outDir);

end

function [mask, bandTbl] = detectRelaxationBand(Ts, tGrid, xGrid, Slope, Curv, cfg)
nT = size(Slope,1);
nX = size(Slope,2);
mask = false(nT, nX);

rows = repmat(emptyBandRow(), nT, 1);
minRun = max(3, round(cfg.minRunFrac * nX));

for r = 1:nT
    s = Slope(r,:);
    c = Curv(r,:);
    row = emptyBandRow();
    row.Temp_K = Ts(r);

    finite = isfinite(s);
    if nnz(finite) < 20
        rows(r) = row;
        continue;
    end

    absS = abs(s);
    n = numel(absS);
    iTail = max(1, floor((1 - cfg.tailFrac) * n));
    tailVals = absS(iTail:end);
    tailVals = tailVals(isfinite(tailVals));
    if isempty(tailVals)
        noise = median(absS(finite), 'omitnan');
    else
        noise = median(tailVals, 'omitnan');
    end
    peak = prctile(absS(finite), 95);

    if ~isfinite(noise), noise = 0; end
    if ~isfinite(peak), peak = prctile(absS(finite), 75); end
    if ~isfinite(peak) || peak <= noise
        peak = max(absS(finite));
    end

    smallThr = noise + cfg.smallFrac * max(peak - noise, eps);
    spikeThr = noise + cfg.spikeFrac * max(peak - noise, eps);

    active = finite & (absS > smallThr);

    spikeMask = false(1,n);
    spikeMask = spikeMask | (absS > spikeThr);
    if any(isfinite(c))
        cThr = prctile(abs(c(isfinite(c))), 99);
        if isfinite(cThr)
            spikeMask = spikeMask | (abs(c) > cThr);
        end
    end

    active(spikeMask) = false;
    active = removeShortRuns(active, minRun);

    [segStarts, segEnds] = findRuns(active);
    if isempty(segStarts)
        rows(r) = row;
        continue;
    end

    bestScore = -Inf;
    bestI = 1;
    for k = 1:numel(segStarts)
        st = segStarts(k);
        en = segEnds(k);
        segAmp = sum(absS(st:en), 'omitnan');
        segLen = en - st + 1;
        score = segAmp * log(1 + segLen);
        if score > bestScore
            bestScore = score;
            bestI = k;
        end
    end

    st = segStarts(bestI);
    en = segEnds(bestI);
    mask(r, st:en) = true;

    row.small_threshold = smallThr;
    row.spike_threshold = spikeThr;
    row.i_start = st;
    row.i_end = en;
    row.t_start_s = tGrid(st);
    row.t_end_s = tGrid(en);
    row.width_s = row.t_end_s - row.t_start_s;
    row.width_log10 = xGrid(en) - xGrid(st);
    row.coverage_frac = (en - st + 1) / nX;
    row.absSlope_median = median(absS(st:en), 'omitnan');
    rows(r) = row;
end

bandTbl = struct2table(rows);
bandTbl = sortrows(bandTbl, 'Temp_K');
end

function r = emptyBandRow()
r = struct('Temp_K', NaN, 'small_threshold', NaN, 'spike_threshold', NaN, ...
    'i_start', NaN, 'i_end', NaN, 't_start_s', NaN, 't_end_s', NaN, ...
    'width_s', NaN, 'width_log10', NaN, 'coverage_frac', NaN, 'absSlope_median', NaN);
end

function maskOut = removeShortRuns(maskIn, minLen)
maskOut = false(size(maskIn));
[st, en] = findRuns(maskIn);
for k = 1:numel(st)
    if (en(k) - st(k) + 1) >= minLen
        maskOut(st(k):en(k)) = true;
    end
end
end

function [st, en] = findRuns(mask)
mask = logical(mask(:)');
d = diff([false, mask, false]);
st = find(d == 1);
en = find(d == -1) - 1;
end

function plotMapMasked(xGrid, Tvec, Z, ttl, cblabel, cmap, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 930 560]);
ax = axes(fig); %#ok<LAXES>
h = imagesc(ax, xGrid, Tvec, Z);
set(ax, 'YDir', 'normal');
set(h, 'AlphaData', isfinite(Z));
set(ax, 'Color', [0.92 0.92 0.92]);

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
    clim = prctile(zv, [5 95]);
    if isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1)
        caxis(ax, clim);
    end
end

saveas(fig, outFile);
close(fig);
end

function plotBandWindowVsTemp(bandTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 760 520]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

ok = isfinite(bandTbl.Temp_K) & isfinite(bandTbl.t_start_s) & isfinite(bandTbl.t_end_s);
T = bandTbl.Temp_K(ok);
ts = bandTbl.t_start_s(ok);
te = bandTbl.t_end_s(ok);

if ~isempty(T)
    plot(ax, T, log10(ts), '-o', 'LineWidth', 1.6, 'MarkerSize', 5, 'DisplayName', 'log10(t_{start})');
    plot(ax, T, log10(te), '-s', 'LineWidth', 1.6, 'MarkerSize', 5, 'DisplayName', 'log10(t_{end})');
end

xlabel(ax, 'Temperature [K]');
ylabel(ax, 'log_{10}(time [s])');
title(ax, 'Detected relaxation-band window vs temperature');
legend(ax, 'Location', 'best');

saveas(fig, outFile);
close(fig);
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

