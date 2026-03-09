function out = relaxation_corrected_geometry_analysis(dataDir, cfg)
% relaxation_corrected_geometry_analysis
% Corrected geometry analysis for Relaxation TRM curves using t_rel = t - t0.
% Diagnostics-only script. Does not modify core pipeline behavior.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'hThresh', 0.5);
cfg = setDef(cfg, 'nLogGrid', 320);
cfg = setDef(cfg, 'clipPrct', [5 95]);
cfg = setDef(cfg, 'minPostPts', 120);
cfg = setDef(cfg, 'minPostDuration_s', 200);
cfg = setDef(cfg, 'derivSmoothSpan', 11);

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'corrected_geometry', dataDir); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

[fileList, ~, ~, ~, ~, ~] = getFileList_relaxation(char(dataDir), 'parula');
[Time_table, Temp_table, Field_table, Moment_table, ~] = ...
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

rawRows = repmat(emptyRawRow(), nCurves, 1);
curve = repmat(emptyCurveStruct(), nCurves, 1);

for i = 1:nCurves
    t = Time_table{i};
    m = Moment_table{i};
    if i <= numel(Field_table)
        h = Field_table{i};
    else
        h = [];
    end
    Tnom = parseNominalTemp(fileList{i}, Temp_table{i});

    [t, m, h] = cleanAligned(t, m, h);
    if numel(t) < 30
        continue;
    end

    [idx0, t0, methodTag, hLowFrac] = detectRelaxStart(t, h, cfg.hThresh);

    tRel = t - t0;
    keep = (tRel >= 0) & isfinite(tRel) & isfinite(m);
    tRel = tRel(keep);
    mRel = m(keep);
    hRel = h(keep);

    pos = tRel > 0;
    tRelPos = tRel(pos);
    mRelPos = mRel(pos);
    hRelPos = hRel(pos);

    if numel(tRelPos) < cfg.minPostPts
        continue;
    end

    postDur = max(tRelPos) - min(tRelPos);
    if postDur < cfg.minPostDuration_s
        continue;
    end

    x = log10(tRelPos);
    d1 = gradient(mRelPos, x);
    d2 = gradient(d1, x);

    curve(i).idx = i;
    curve(i).Temp_K = Tnom;
    curve(i).tAbs = t;
    curve(i).MAbs = m;
    curve(i).HAbs = h;
    curve(i).tRel = tRelPos;
    curve(i).xRel = x;
    curve(i).MRel = mRelPos;
    curve(i).HRel = hRelPos;
    curve(i).Rate = -d1;
    curve(i).Curv = d2;
    curve(i).t0_abs_s = t0;
    curve(i).t0_idx = idx0;
    curve(i).t0_method = methodTag;

    rr = emptyRawRow();
    rr.data_idx = i;
    rr.file_name = string(fileList{i});
    rr.Temp_K = Tnom;
    rr.t_min_s = min(t);
    rr.t_max_s = max(t);
    rr.n_points = numel(t);
    rr.H_min = min(h, [], 'omitnan');
    rr.H_max = max(h, [], 'omitnan');
    rr.t0_abs_s = t0;
    rr.t0_idx = idx0;
    rr.t0_method = string(methodTag);
    rr.h_low_fraction_post_t0 = hLowFrac;
    rr.post_duration_s = postDur;
    rr.post_n_points = numel(tRelPos);
    rr.t_rel_min_pos_s = min(tRelPos);
    rr.t_rel_max_s = max(tRelPos);
    rawRows(i) = rr;
end

rawTbl = struct2table(rawRows);
valid = isfinite(rawTbl.Temp_K) & isfinite(rawTbl.t_rel_max_s) & rawTbl.post_n_points >= cfg.minPostPts;
rawTbl = rawTbl(valid,:);
rawTbl = sortrows(rawTbl, 'Temp_K');

if isempty(rawTbl)
    error('No valid post-switch relaxation curves after t0 detection.');
end

validIdx = rawTbl.data_idx;
Ts = rawTbl.Temp_K;

tRelMinCommon = max(rawTbl.t_rel_min_pos_s);
tRelMaxCommon = min(rawTbl.t_rel_max_s);
if ~(isfinite(tRelMinCommon) && isfinite(tRelMaxCommon) && tRelMaxCommon > tRelMinCommon)
    error('Invalid common t_rel overlap after t0 alignment.');
end

xGrid = linspace(log10(tRelMinCommon), log10(tRelMaxCommon), cfg.nLogGrid);
tGrid = 10.^xGrid;

nT = numel(validIdx);
Mmap = nan(nT, cfg.nLogGrid);
Rmap = nan(nT, cfg.nLogGrid);
Cmap = nan(nT, cfg.nLogGrid);

for r = 1:nT
    i = validIdx(r);
    x = curve(i).xRel;
    y = curve(i).MRel;
    if numel(x) < 20
        continue;
    end

    yi = interp1(x, y, xGrid, 'pchip', nan);
    Mmap(r,:) = yi;

    d1 = gradient(yi, xGrid);
    Rmap(r,:) = -d1;
    Cmap(r,:) = gradient(d1, xGrid);
end

dMmap = Mmap - Mmap(:, end);

% Representative times for time cuts (early / mid / late)
xRep = quantile(xGrid, [0.20 0.55 0.85]);
tRep = 10.^xRep;

% Build per-temperature geometry summary
sumRows = repmat(emptyGeomRow(), nT, 1);
for r = 1:nT
    i = validIdx(r);
    x = curve(i).xRel;
    y = curve(i).MRel;
    rate = curve(i).Rate;
    curv = curve(i).Curv;

    xEarly = quantile(x, [0.10 0.30]);
    xLate = quantile(x, [0.70 0.90]);
    mEarly = x >= xEarly(1) & x <= xEarly(2);
    mLate = x >= xLate(1) & x <= xLate(2);

    d1 = -rate;
    sEarly = median(d1(mEarly), 'omitnan');
    sLate = median(d1(mLate), 'omitnan');
    ratio = safeDiv(sLate, sEarly);

    [ratePk, iPk] = max(rate);
    xPk = x(iPk);

    signChange = any(curv(1:end-1).*curv(2:end) < 0);

    mRef = interp1(x, y, log10(tRelMaxCommon), 'pchip', nan);
    amp = y(1) - mRef;

    srow = emptyGeomRow();
    srow.Temp_K = Ts(r);
    srow.t0_abs_s = rawTbl.t0_abs_s(r);
    srow.post_duration_s = rawTbl.post_duration_s(r);
    srow.early_slope_dM_dlogt = sEarly;
    srow.late_slope_dM_dlogt = sLate;
    srow.slope_ratio_late_over_early = ratio;
    srow.rate_peak = ratePk;
    srow.rate_peak_log10_trel = xPk;
    srow.rate_early_mean = mean(rate(mEarly), 'omitnan');
    srow.rate_late_mean = mean(rate(mLate), 'omitnan');
    srow.curvature_early_mean = mean(curv(mEarly), 'omitnan');
    srow.curvature_late_mean = mean(curv(mLate), 'omitnan');
    srow.curvature_sign_change = double(signChange);
    srow.amplitude_to_tref = amp;

    % Time-cut values
    yRep = interp1(x, y, xRep, 'pchip', nan);
    rRep = interp1(x, rate, xRep, 'pchip', nan);
    srow.M_tEarly = yRep(1);
    srow.M_tMid = yRep(2);
    srow.M_tLate = yRep(3);
    srow.dM_tEarly = yRep(1) - mRef;
    srow.dM_tMid = yRep(2) - mRef;
    srow.dM_tLate = yRep(3) - mRef;
    srow.R_tEarly = rRep(1);
    srow.R_tMid = rRep(2);
    srow.R_tLate = rRep(3);

    sumRows(r) = srow;
end

summaryTbl = struct2table(sumRows);
summaryTbl = sortrows(summaryTbl, 'Temp_K');
writetable(summaryTbl, fullfile(outDir, 'relaxation_geometry_summary.csv'));
writetable(rawTbl, fullfile(outDir, 'relaxation_raw_inspect_t0.csv'));

% Maps
plotMap(xGrid, Ts, Mmap, cfg.clipPrct, 'M(T, log_{10}(t_{rel}))', 'M', parula, ...
    fullfile(outDir, 'relaxation_map_M_logtrel.png'));
plotMap(xGrid, Ts, dMmap, cfg.clipPrct, '\DeltaM(T, log_{10}(t_{rel}))', '\DeltaM', turbo, ...
    fullfile(outDir, 'relaxation_map_dM_logtrel.png'));
plotMap(xGrid, Ts, Rmap, cfg.clipPrct, 'R(T,t_{rel}) = -dM/dlog_{10}(t_{rel})', 'R', hot, ...
    fullfile(outDir, 'relaxation_map_rate_logtrel.png'));
plotMap(xGrid, Ts, Cmap, cfg.clipPrct, 'C(T,t_{rel}) = d^2M/d(log_{10}(t_{rel}))^2', 'C', cool, ...
    fullfile(outDir, 'relaxation_map_curvature_logtrel.png'));

% Temperature cuts
plotTempCuts(validIdx, Ts, curve, 'M', tRelMaxCommon, xRep, tRep, ...
    fullfile(outDir, 'relaxation_temperature_cuts_M.png'));
plotTempCuts(validIdx, Ts, curve, 'dM', tRelMaxCommon, xRep, tRep, ...
    fullfile(outDir, 'relaxation_temperature_cuts_dM.png'));
plotTempCuts(validIdx, Ts, curve, 'R', tRelMaxCommon, xRep, tRep, ...
    fullfile(outDir, 'relaxation_temperature_cuts_rate.png'));

% Time cuts
plotTimeCuts(summaryTbl, Ts, tRep, 'M', ...
    fullfile(outDir, 'relaxation_time_cuts_M.png'));
plotTimeCuts(summaryTbl, Ts, tRep, 'dM', ...
    fullfile(outDir, 'relaxation_time_cuts_dM.png'));
plotTimeCuts(summaryTbl, Ts, tRep, 'R', ...
    fullfile(outDir, 'relaxation_time_cuts_rate.png'));

% Package outputs
zipPath = fullfile(outDir, 'relaxation_corrected_geometry_figures.zip');
if exist(zipPath, 'file')
    delete(zipPath);
end
filesPng = dir(fullfile(outDir, '*.png'));
filesCsv = dir(fullfile(outDir, '*.csv'));
zipList = strings(0,1);
for k = 1:numel(filesPng)
    zipList(end+1) = string(fullfile(filesPng(k).folder, filesPng(k).name)); %#ok<AGROW>
end
for k = 1:numel(filesCsv)
    zipList(end+1) = string(fullfile(filesCsv(k).folder, filesCsv(k).name)); %#ok<AGROW>
end
zip(zipPath, cellstr(zipList));

out = struct();
out.dataDir = string(dataDir);
out.outDir = string(outDir);
out.zipPath = string(zipPath);
out.t0Table = rawTbl;
out.summaryTable = summaryTbl;
out.t_rel_common = [tRelMinCommon, tRelMaxCommon];
out.t_rep_s = tRep;
out.valid_temps = Ts;

fprintf('\n=== Corrected relaxation geometry analysis complete ===\n');
fprintf('Data dir: %s\n', dataDir);
fprintf('Valid temperatures: %d\n', numel(Ts));
fprintf('Common t_rel range: %.3f .. %.3f s\n', tRelMinCommon, tRelMaxCommon);
fprintf('Output dir: %s\n', outDir);
fprintf('ZIP: %s\n\n', zipPath);

end

function [t, m, h] = cleanAligned(t, m, h)
t = t(:);
m = m(:);
if isempty(h)
    h = nan(size(t));
else
    h = h(:);
end

n = min([numel(t), numel(m), numel(h)]);
t = t(1:n);
m = m(1:n);
h = h(1:n);

ok = isfinite(t) & isfinite(m);
t = t(ok);
m = m(ok);
h = h(ok);

[t, ord] = sort(t, 'ascend');
m = m(ord);
h = h(ord);

[t, iu] = unique(t, 'stable');
m = m(iu);
h = h(iu);
end

function [idx0, t0, methodTag, lowFrac] = detectRelaxStart(t, h, hThresh)
idx0 = 1;
t0 = t(1);
methodTag = "fallback_start";
lowFrac = NaN;

if isempty(h) || all(~isfinite(h))
    return;
end

hs = h;
span = min(11, numel(hs));
if mod(span,2)==0
    span = span - 1;
end
if span >= 3
    hs = smoothdata(hs, 'movmean', span);
end

below = abs(hs) < hThresh;
[st, en] = findRuns(below);
if isempty(st)
    return;
end

n = numel(t);
% Prefer a low-field run that extends to end-of-file.
cand = find(en >= n-1);
if isempty(cand)
    % Fallback: choose longest low-field run.
    [~, im] = max(en - st + 1);
    cand = im;
else
    cand = cand(end);
end

idx0 = st(cand);
t0 = t(idx0);
methodTag = "field_drop_to_lowH";
postMask = (1:n) >= idx0;
if any(postMask)
    lowFrac = mean(below(postMask));
else
    lowFrac = NaN;
end
end

function [st, en] = findRuns(mask)
mask = logical(mask(:)');
d = diff([false, mask, false]);
st = find(d == 1);
en = find(d == -1) - 1;
end

function rr = emptyRawRow()
rr = struct('data_idx',NaN,'file_name',"",'Temp_K',NaN,'t_min_s',NaN,'t_max_s',NaN, ...
    'n_points',NaN,'H_min',NaN,'H_max',NaN,'t0_abs_s',NaN,'t0_idx',NaN,'t0_method',"", ...
    'h_low_fraction_post_t0',NaN,'post_duration_s',NaN,'post_n_points',NaN, ...
    't_rel_min_pos_s',NaN,'t_rel_max_s',NaN);
end

function cc = emptyCurveStruct()
cc = struct('idx',NaN,'Temp_K',NaN,'tAbs',[],'MAbs',[],'HAbs',[],'tRel',[],'xRel',[], ...
    'MRel',[],'HRel',[],'Rate',[],'Curv',[],'t0_abs_s',NaN,'t0_idx',NaN,'t0_method',"");
end

function gg = emptyGeomRow()
gg = struct('Temp_K',NaN,'t0_abs_s',NaN,'post_duration_s',NaN, ...
    'early_slope_dM_dlogt',NaN,'late_slope_dM_dlogt',NaN,'slope_ratio_late_over_early',NaN, ...
    'rate_peak',NaN,'rate_peak_log10_trel',NaN,'rate_early_mean',NaN,'rate_late_mean',NaN, ...
    'curvature_early_mean',NaN,'curvature_late_mean',NaN,'curvature_sign_change',NaN, ...
    'amplitude_to_tref',NaN,'M_tEarly',NaN,'M_tMid',NaN,'M_tLate',NaN, ...
    'dM_tEarly',NaN,'dM_tMid',NaN,'dM_tLate',NaN,'R_tEarly',NaN,'R_tMid',NaN,'R_tLate',NaN);
end

function y = safeDiv(a,b)
if ~isfinite(a) || ~isfinite(b) || abs(b) < eps
    y = NaN;
else
    y = a / b;
end
end

function plotMap(xGrid, Tvec, Z, clipPrct, ttl, cblabel, cmap, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 900 560]);
ax = axes(fig); %#ok<LAXES>
imagesc(ax, xGrid, Tvec, Z);
set(ax,'YDir','normal');
xlabel(ax, 'log_{10}(t_{rel} [s])');
ylabel(ax, 'Temperature [K]');
title(ax, ttl);
cb = colorbar(ax);
ylabel(cb, cblabel);
colormap(ax, cmap);
grid(ax, 'on'); box(ax, 'on');

zv = Z(isfinite(Z));
if ~isempty(zv)
    clim = prctile(zv, clipPrct);
    if isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1)
        caxis(ax, clim);
    end
end

saveas(fig, outFile);
close(fig);
end

function plotTempCuts(validIdx, Ts, curve, mode, tRef, xRep, tRep, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 900 560]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = turbo(max(numel(validIdx),3));

for r = 1:numel(validIdx)
    i = validIdx(r);
    x = curve(i).xRel;
    y = curve(i).MRel;
    if numel(x) < 20
        continue;
    end

    switch upper(mode)
        case 'M'
            yy = y;
            ylab = 'M';
            ttl = 'Temperature cuts: M vs log_{10}(t_{rel})';
        case 'DM'
            mRef = interp1(x, y, log10(tRef), 'pchip', nan);
            yy = y - mRef;
            ylab = '\DeltaM = M - M(t_{ref})';
            ttl = 'Temperature cuts: \DeltaM vs log_{10}(t_{rel})';
        otherwise
            yy = curve(i).Rate;
            ylab = 'R = -dM/dlog_{10}(t_{rel})';
            ttl = 'Temperature cuts: R vs log_{10}(t_{rel})';
    end

    plot(ax, x, yy, '-', 'Color', cols(r,:), 'LineWidth', 1.1);
end

for k = 1:numel(xRep)
    xline(ax, xRep(k), '--', sprintf('%.0fs', tRep(k)), ...
        'LabelVerticalAlignment', 'middle', 'LabelOrientation', 'horizontal');
end

xlabel(ax, 'log_{10}(t_{rel} [s])');
ylabel(ax, ylab);
title(ax, ttl);
saveas(fig, outFile);
close(fig);
end

function plotTimeCuts(summaryTbl, Ts, tRep, mode, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 820 540]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cc = lines(3);

switch upper(mode)
    case 'M'
        y1 = summaryTbl.M_tEarly;
        y2 = summaryTbl.M_tMid;
        y3 = summaryTbl.M_tLate;
        ylab = 'M(T)';
        ttl = 'Time cuts: M(T)';
    case 'DM'
        y1 = summaryTbl.dM_tEarly;
        y2 = summaryTbl.dM_tMid;
        y3 = summaryTbl.dM_tLate;
        ylab = '\DeltaM(T)';
        ttl = 'Time cuts: \DeltaM(T)';
    otherwise
        y1 = summaryTbl.R_tEarly;
        y2 = summaryTbl.R_tMid;
        y3 = summaryTbl.R_tLate;
        ylab = 'R(T)';
        ttl = 'Time cuts: R(T)';
end

plot(ax, Ts, y1, '-o', 'Color', cc(1,:), 'LineWidth', 1.5, 'MarkerSize', 5, ...
    'DisplayName', sprintf('t_{rel}=%.0f s', tRep(1)));
plot(ax, Ts, y2, '-s', 'Color', cc(2,:), 'LineWidth', 1.5, 'MarkerSize', 5, ...
    'DisplayName', sprintf('t_{rel}=%.0f s', tRep(2)));
plot(ax, Ts, y3, '-d', 'Color', cc(3,:), 'LineWidth', 1.5, 'MarkerSize', 5, ...
    'DisplayName', sprintf('t_{rel}=%.0f s', tRep(3)));

xlabel(ax, 'Temperature [K]');
ylabel(ax, ylab);
title(ax, ttl);
legend(ax, 'Location', 'best');
saveas(fig, outFile);
close(fig);
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

function v = setDef(s, f, d)
if ~isfield(s, f)
    s.(f) = d;
end
v = s;
end



