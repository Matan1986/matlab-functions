function out = survey_relaxation_observables(dataDir, cfg)
% survey_relaxation_observables
% Observable stability survey for Relaxation ver3.
% This script does not modify core pipeline behavior.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'hThresh', 0.5);
cfg = setDef(cfg, 'absThreshold', 3e-5);
cfg = setDef(cfg, 'slopeThreshold', 1e-8);
cfg = setDef(cfg, 'fitStartVals', [0.00 0.05 0.10]);
cfg = setDef(cfg, 'fitEndVals', [0.00 0.05]);
cfg = setDef(cfg, 'nonfitSmoothVals', [1 5 11]);
cfg = setDef(cfg, 'windowA', [60 600]);
cfg = setDef(cfg, 'windowB', [120 1200]);
cfg = setDef(cfg, 'windowCurv', [60 1800]);

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'observable_survey', dataDir); %#ok<ASGLU>
if ~exist(outDir, 'dir'), mkdir(outDir); end

[fileList, ~, ~, ~, ~, massFromName] = getFileList_relaxation(char(dataDir), 'parula'); %#ok<ASGLU>
[Time_table, Temp_table, Field_table, Moment_table, massHeader] = ...
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
    if isempty(t) || isempty(m), continue; end
    ok = isfinite(t) & isfinite(m);
    t = t(ok);
    if isempty(t), continue; end
    tMin(i) = min(t);
    tMax(i) = max(t);
    nPts(i) = numel(t);
end

datasetTbl = table((1:nCurves)', string(fileList(:)), Tnom, tMin, tMax, nPts, ...
    'VariableNames', {'data_idx','file_name','Temp_K','t_min_s','t_max_s','n_points'});
writetable(datasetTbl, fullfile(outDir, 'dataset_structure.csv'));

geomRows = repmat(emptyGeomRow(), nCurves, 1);
for i = 1:nCurves
    t = Time_table{i};
    m = Moment_table{i};
    if isempty(t) || isempty(m), continue; end
    [geomRows(i), ok] = computeGeometryRow(i, Tnom(i), t, m, cfg);
    if ~ok
        geomRows(i) = emptyGeomRow();
        geomRows(i).data_idx = i;
        geomRows(i).Temp_K = Tnom(i);
    end
end
geometryTbl = struct2table(geomRows);
geometryTbl = sortrows(geometryTbl, {'Temp_K','data_idx'});
writetable(geometryTbl, fullfile(outDir, 'geometry_metrics.csv'));

% Plot geometry views
makeGeometryPlots(Time_table, Moment_table, Tnom, outDir);

% Fit parameter settings sweep
fitParams = struct();
fitParams.betaBoost = false;
fitParams.tauBoost = false;
fitParams.timeWeight = true;
fitParams.lowT_only = false;
fitParams.lowT_threshold = 15;
fitParams.debugFit = false;
fitParams.timeWeightFactor = 0.725;

fitRows = table();
sid = 0;
for a = 1:numel(cfg.fitStartVals)
    for b = 1:numel(cfg.fitEndVals)
        fs = cfg.fitStartVals(a);
        fe = cfg.fitEndVals(b);
        if fs + fe >= 0.40
            continue;
        end
        sid = sid + 1;
        settingId = sprintf('F%02d', sid);

        tLog = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
            false, cfg.hThresh, fitParams, fs, fe, cfg.absThreshold, cfg.slopeThreshold, fileList, 'log');
        tKww = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
            false, cfg.hThresh, fitParams, fs, fe, cfg.absThreshold, cfg.slopeThreshold, fileList, 'kww');

        rows = buildFitObservableRows(tLog, tKww, Time_table, Moment_table, settingId, fs, fe);
        if ~isempty(rows)
            fitRows = [fitRows; rows]; %#ok<AGROW>
        end
    end
end

if ~isempty(fitRows)
    fitRows = sortrows(fitRows, {'Temp_K','data_idx','setting_id'});
end
writetable(fitRows, fullfile(outDir, 'fit_observables_raw.csv'));

fitPerTemp = summarizeStabilityByTemp(fitRows, {'S_log','tau_kww','beta_kww','deltaAIC_log_minus_kww'}, 'setting_id');
fitOverall = summarizeStabilityOverall(fitPerTemp);
writetable(fitPerTemp, fullfile(outDir, 'fit_observable_stability_by_temp.csv'));
writetable(fitOverall, fullfile(outDir, 'fit_observable_stability_overall.csv'));

% Non-fit settings sweep
nonfitRows = table();
nsid = 0;
for w = 1:numel(cfg.nonfitSmoothVals)
    for winCase = 1:2
        nsid = nsid + 1;
        settingId = sprintf('N%02d', nsid);
        sw = cfg.nonfitSmoothVals(w);
        if winCase == 1
            winMain = cfg.windowA;
        else
            winMain = cfg.windowB;
        end

        for i = 1:nCurves
            t = Time_table{i};
            m = Moment_table{i};
            if isempty(t) || isempty(m), continue; end
            row = computeNonfitRow(i, Tnom(i), t, m, sw, winMain, cfg.windowCurv, settingId);
            nonfitRows = [nonfitRows; row]; %#ok<AGROW>
        end
    end
end

if ~isempty(nonfitRows)
    nonfitRows = sortrows(nonfitRows, {'Temp_K','data_idx','setting_id'});
end
writetable(nonfitRows, fullfile(outDir, 'nonfit_observables_raw.csv'));

nonfitPerTemp = summarizeStabilityByTemp(nonfitRows, {'dM_fixed','slope_log_fixed','curvature_log','slope_local_mean'}, 'setting_id');
nonfitOverall = summarizeStabilityOverall(nonfitPerTemp);
writetable(nonfitPerTemp, fullfile(outDir, 'nonfit_observable_stability_by_temp.csv'));
writetable(nonfitOverall, fullfile(outDir, 'nonfit_observable_stability_overall.csv'));

% Simple recommendation table
allOverall = [fitOverall; nonfitOverall];
allOverall.robust_flag = (allOverall.mean_coverage >= 0.85) & (allOverall.median_cv <= 0.35);
allOverall = sortrows(allOverall, {'robust_flag','median_cv'}, {'descend','ascend'});
writetable(allOverall, fullfile(outDir, 'recommended_observables.csv'));

out = struct();
out.dataDir = string(dataDir);
out.outDir = string(outDir);
out.dataset = datasetTbl;
out.geometry = geometryTbl;
out.fitRaw = fitRows;
out.fitStabilityByTemp = fitPerTemp;
out.fitStabilityOverall = fitOverall;
out.nonfitRaw = nonfitRows;
out.nonfitStabilityByTemp = nonfitPerTemp;
out.nonfitStabilityOverall = nonfitOverall;
out.recommendations = allOverall;

fprintf('\n=== Relaxation observable survey complete ===\n');
fprintf('Data dir: %s\n', dataDir);
fprintf('Curves: %d\n', nCurves);
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

function row = emptyGeomRow()
row = struct('data_idx',NaN,'Temp_K',NaN,'R2_log',NaN,'slope_log_global',NaN, ...
    'slope_early',NaN,'slope_late',NaN,'slope_ratio_late_over_early',NaN, ...
    'curvature_log',NaN,'deviation_rmse_loglin',NaN,'n_points_used',0);
end

function [row, okOut] = computeGeometryRow(idx, T, t, m, cfg)
row = emptyGeomRow();
row.data_idx = idx;
row.Temp_K = T;
okOut = false;

t = t(:); m = m(:);
ok = isfinite(t) & isfinite(m) & (t > 1);
t = t(ok); m = m(ok);
if numel(t) < 30
    return;
end

[t, ord] = sort(t);
m = m(ord);
[t, iu] = unique(t, 'stable');
m = m(iu);

x = log10(t);
P1 = polyfit(x, m, 1);
y1 = polyval(P1, x);
ssRes = nansum((m - y1).^2);
ssTot = nansum((m - mean(m,'omitnan')).^2);
R2 = 1 - ssRes / max(ssTot, eps);

P2 = polyfit(x, m, 2);
curv = P2(1);

dMdlog = gradient(m) ./ gradient(x);
earlyMask = (t >= 20) & (t <= 120);
lateMask  = (t >= 300) & (t <= 1800);
if ~any(earlyMask)
    earlyMask = (t >= prctile(t,10)) & (t <= prctile(t,35));
end
if ~any(lateMask)
    lateMask = (t >= prctile(t,65)) & (t <= prctile(t,90));
end
sEarly = median(dMdlog(earlyMask), 'omitnan');
sLate = median(dMdlog(lateMask), 'omitnan');
if ~isfinite(sEarly) || abs(sEarly) < eps
    ratio = NaN;
else
    ratio = sLate / sEarly;
end

row.R2_log = R2;
row.slope_log_global = P1(1);
row.slope_early = sEarly;
row.slope_late = sLate;
row.slope_ratio_late_over_early = ratio;
row.curvature_log = curv;
row.deviation_rmse_loglin = sqrt(mean((m-y1).^2, 'omitnan'));
row.n_points_used = numel(t);
okOut = true;

end

function makeGeometryPlots(Time_table, Moment_table, Tnom, outDir)
fig1 = figure('Color','w','Visible','off','Position',[100 100 1200 420]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
cols = parula(max(numel(Time_table),1));
for i = 1:numel(Time_table)
    t = Time_table{i}; m = Moment_table{i};
    if isempty(t) || isempty(m), continue; end
    ok = isfinite(t) & isfinite(m) & (t > 0);
    t = t(ok); m = m(ok);
    if numel(t) < 5, continue; end
    [t, ord] = sort(t); m = m(ord);
    plot(ax1, t, m, '-', 'Color', cols(i,:), 'LineWidth', 1.0);
    plot(ax2, log10(t), m, '-', 'Color', cols(i,:), 'LineWidth', 1.0);
end
xlabel(ax1, 't [s]'); ylabel(ax1, 'M'); title(ax1, 'M(t)');
xlabel(ax2, 'log10(t)'); ylabel(ax2, 'M'); title(ax2, 'M vs log10(t)');
saveas(fig1, fullfile(outDir, 'geometry_M_and_logM.png'));
close(fig1);

fig2 = figure('Color','w','Visible','off','Position',[100 100 700 500]);
ax = axes(fig2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i = 1:numel(Time_table)
    t = Time_table{i}; m = Moment_table{i};
    if isempty(t) || isempty(m), continue; end
    ok = isfinite(t) & isfinite(m) & (t > 1);
    t = t(ok); m = m(ok);
    if numel(t) < 10, continue; end
    [t, ord] = sort(t); m = m(ord);
    x = log10(t);
    d = gradient(m) ./ gradient(x);
    plot(ax, x, d, '-', 'LineWidth', 1.0);
end
xlabel(ax, 'log10(t)'); ylabel(ax, 'dM/dlog10(t)');
title(ax, 'Local slope vs log-time');
saveas(fig2, fullfile(outDir, 'geometry_local_slope.png'));
close(fig2);

if nargin > 2 %#ok<*ISMAT>
    %#ok<NASGU>
end
end

function rows = buildFitObservableRows(tLog, tKww, Time_table, Moment_table, settingId, fitStart, fitEnd)
rows = table();
if isempty(tLog) || isempty(tKww)
    return;
end

[~, ia, ib] = intersect(tLog.data_idx, tKww.data_idx);
if isempty(ia)
    return;
end

for k = 1:numel(ia)
    rL = tLog(ia(k),:);
    rK = tKww(ib(k),:);
    idx = rL.data_idx;
    if idx < 1 || idx > numel(Time_table)
        continue;
    end

    t = Time_table{idx};
    m = Moment_table{idx};
    if isempty(t) || isempty(m)
        continue;
    end

    ok = isfinite(t) & isfinite(m);
    t = t(ok); m = m(ok);
    mask = (t >= rL.t_start) & (t <= rL.t_end);
    tSel = t(mask); mSel = m(mask);
    if numel(tSel) < 10
        continue;
    end

    tLogSafe = max(tSel, 1e-6);
    yLog = rL.M0 - rL.S .* log(tLogSafe);
    z = max(0, (tSel - rK.t_start) ./ max(rK.tau, 1e-12));
    yKww = rK.Minf + rK.dM .* exp(-(z.^max(rK.n, 1e-12)));

    aicLog = computeAIC(mSel, yLog, 2);
    aicKww = computeAIC(mSel, yKww, 4);
    dAIC = aicLog - aicKww;

    rr = table(string(settingId), fitStart, fitEnd, idx, rL.Temp_K, rL.S, rK.tau, rK.n, ...
        dAIC, signSafe(dAIC), ...
        'VariableNames', {'setting_id','fit_start_frac','fit_end_frac','data_idx','Temp_K', ...
        'S_log','tau_kww','beta_kww','deltaAIC_log_minus_kww','pref_sign'});
    rows = [rows; rr]; %#ok<AGROW>
end
end

function row = computeNonfitRow(idx, T, t, m, smoothW, winMain, winCurv, settingId)
t = t(:); m = m(:);
ok = isfinite(t) & isfinite(m);
t = t(ok); m = m(ok);
[t, ord] = sort(t); m = m(ord);
[t, iu] = unique(t, 'stable'); m = m(iu);

if smoothW > 1
    m = smoothdata(m, 'movmean', smoothW);
end

mA = interpSafe(t, m, winMain(1));
mB = interpSafe(t, m, winMain(2));
dM = mA - mB;

slopeLog = localSlopeLog(t, m, winMain(1), winMain(2));
curvLog = localCurvLog(t, m, winCurv(1), winCurv(2));
localSlopeMean = localSlopeAvg(t, m, winMain(1), winMain(2));

row = table(string(settingId), smoothW, winMain(1), winMain(2), idx, T, ...
    dM, slopeLog, curvLog, localSlopeMean, ...
    'VariableNames', {'setting_id','smooth_win','tA_s','tB_s','data_idx','Temp_K', ...
    'dM_fixed','slope_log_fixed','curvature_log','slope_local_mean'});
end

function val = interpSafe(t, m, tq)
if isempty(t) || tq < min(t) || tq > max(t)
    val = NaN;
    return;
end
val = interp1(t, m, tq, 'linear', NaN);
end

function s = localSlopeLog(t, m, t0, t1)
mask = (t >= t0) & (t <= t1) & (t > 0);
if nnz(mask) < 5
    s = NaN;
    return;
end
x = log10(t(mask));
y = m(mask);
p = polyfit(x, y, 1);
s = p(1);
end

function c = localCurvLog(t, m, t0, t1)
mask = (t >= t0) & (t <= t1) & (t > 0);
if nnz(mask) < 8
    c = NaN;
    return;
end
x = log10(t(mask));
y = m(mask);
p = polyfit(x, y, 2);
c = p(1);
end

function s = localSlopeAvg(t, m, t0, t1)
mask = (t >= t0) & (t <= t1) & (t > 0);
if nnz(mask) < 6
    s = NaN;
    return;
end
x = log10(t(mask));
y = m(mask);
d = gradient(y) ./ gradient(x);
d = d(isfinite(d));
if isempty(d)
    s = NaN;
else
    s = mean(d, 'omitnan');
end
end

function aic = computeAIC(y, yhat, k)
yv = y(:); fh = yhat(:);
mask = isfinite(yv) & isfinite(fh);
yv = yv(mask); fh = fh(mask);
n = numel(yv);
if n <= 0
    aic = NaN;
    return;
end
sse = nansum((yv - fh).^2);
sse = max(sse, eps);
aic = n * log(sse / n) + 2 * k;
end

function outTbl = summarizeStabilityByTemp(rawTbl, obsVars, settingVar)
outTbl = table();
if isempty(rawTbl)
    return;
end

for v = 1:numel(obsVars)
    obs = obsVars{v};
    if ~ismember(obs, rawTbl.Properties.VariableNames)
        continue;
    end

    [G, temps] = findgroups(rawTbl.Temp_K);
    gIds = unique(G(~isnan(G)));
    for gi = 1:numel(gIds)
        g = gIds(gi);
        idx = (G == g);
        sub = rawTbl(idx,:);
        vals = sub.(obs);
        vals = vals(:);
        finiteMask = isfinite(vals);
        valsFin = vals(finiteMask);

        nTotal = numel(unique(string(sub.(settingVar))));
        nFinite = numel(valsFin);
        coverage = nFinite / max(nTotal,1);

        mu = mean(valsFin, 'omitnan');
        sig = std(valsFin, 'omitnan');
        den = max(abs(mu), eps);
        cv = sig / den;
        if isempty(valsFin)
            relRange = NaN;
        else
            relRange = (max(valsFin) - min(valsFin)) / den;
        end

        signCons = NaN;
        sgn = sign(valsFin);
        sgn = sgn(sgn ~= 0);
        if ~isempty(sgn)
            majority = mode(sgn);
            signCons = mean(sgn == majority);
        end

        row = table(string(obs), temps(g), nTotal, nFinite, coverage, mu, sig, cv, relRange, signCons, ...
            'VariableNames', {'observable','Temp_K','n_settings','n_finite','coverage', ...
            'mean_value','std_value','cv','rel_range','sign_consistency'});
        outTbl = [outTbl; row]; %#ok<AGROW>
    end
end

if ~isempty(outTbl)
    outTbl = sortrows(outTbl, {'observable','Temp_K'});
end
end

function outTbl = summarizeStabilityOverall(perTempTbl)
outTbl = table();
if isempty(perTempTbl)
    return;
end

obsList = unique(perTempTbl.observable);
for i = 1:numel(obsList)
    obs = obsList(i);
    sub = perTempTbl(perTempTbl.observable == obs, :);
    row = table(obs, ...
        mean(sub.coverage,'omitnan'), ...
        min(sub.coverage), ...
        median(sub.cv,'omitnan'), ...
        median(sub.rel_range,'omitnan'), ...
        mean(sub.sign_consistency,'omitnan'), ...
        'VariableNames', {'observable','mean_coverage','min_coverage','median_cv','median_rel_range','mean_sign_consistency'});
    outTbl = [outTbl; row]; %#ok<AGROW>
end
outTbl = sortrows(outTbl, {'median_cv','mean_coverage'}, {'ascend','descend'});
end

function y = signSafe(x)
if ~isfinite(x)
    y = NaN;
elseif x == 0
    y = 0;
else
    y = sign(x);
end
end



