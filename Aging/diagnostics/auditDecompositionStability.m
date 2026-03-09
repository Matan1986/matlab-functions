% auditDecompositionStability
% Diagnostics-only stability audit for current AFM/FM decomposition.
% Runs a compact settings grid over existing decomposition knobs and writes
% raw + aggregated robustness outputs.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'decomposition_stability');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3 s',   '3s';
    'MG119_36sec', '36 s',  '36s';
    'MG119_6min',  '6 min', '6min';
    'MG119_60min', '60 min','60min'
};

baseCfg = agingConfig('MG119_60min');
auditSettings = buildAuditSettings(baseCfg);

rows = repmat(initRawRow(), 0, 1);

for d = 1:size(datasets,1)
    datasetKey = datasets{d,1};
    waitLabel = datasets{d,2};

    cfgBase = agingConfig(datasetKey);
    cfgBase.doPlotting = false;
    cfgBase.saveTableMode = 'none';

    if isfield(cfgBase, 'debug') && isstruct(cfgBase.debug)
        cfgBase.debug.enable = false;
        cfgBase.debug.plotGeometry = false;
        cfgBase.debug.plotSwitching = false;
        cfgBase.debug.saveOutputs = false;
    end

    for s = 1:numel(auditSettings)
        cfg = applyAuditSetting(cfgBase, auditSettings(s));

        cfg = stage0_setupPaths(cfg);
        state = stage1_loadData(cfg);
        state = stage2_preprocess(state, cfg);
        state = stage3_computeDeltaM(state, cfg);
        state = stage4_analyzeAFM_FM(state, cfg);
        state = stage5_fitFMGaussian(state, cfg);

        pauseRuns = getPauseRuns(state);

        for i = 1:numel(pauseRuns)
            pr = pauseRuns(i);

            row = initRawRow();
            row.wait_time = string(waitLabel);
            row.dataset = string(datasetKey);
            row.Tp = getScalarOrNaN(pr, 'waitK');

            row.setting_id = string(auditSettings(s).id);
            row.setting_name = string(auditSettings(s).name);
            row.agingMetricMode = string(auditSettings(s).agingMetricMode);
            row.smoothWindow_K = auditSettings(s).smoothWindow_K;
            row.FM_plateau_K = auditSettings(s).FM_plateau_K;
            row.FM_buffer_K = auditSettings(s).FM_buffer_K;
            row.useRobustBaseline = logical(auditSettings(s).useRobustBaseline);
            row.FM_rightPlateauMode = string(auditSettings(s).FM_rightPlateauMode);
            row.excludeLowT_mode = string(auditSettings(s).excludeLowT_mode);
            row.sgolayFrame = auditSettings(s).sgolayFrame;

            row.Dip_area = getScalarOrNaN(pr, 'Dip_area');
            row.Dip_depth = getScalarOrNaN(pr, 'Dip_depth');
            row.Dip_sigma = getScalarOrNaN(pr, 'Dip_sigma');
            row.Dip_T0 = getScalarOrNaN(pr, 'Dip_T0');
            row.Tmin = getFirstFiniteScalar(pr, {'Tmin', 'Tmin_K'});

            row.FM_E = getScalarOrNaN(pr, 'FM_E');
            row.FM_abs = getScalarOrNaN(pr, 'FM_abs');
            row.FM_step_mag = getScalarOrNaN(pr, 'FM_step_mag');

            row.fit_R2 = getScalarOrNaN(pr, 'fit_R2');
            row.fit_RMSE = getScalarOrNaN(pr, 'fit_RMSE');
            row.recon_RMSE_direct = computeDirectReconRMSE(pr);

            row.FM_plateau_valid = getLogicalOrDefault(pr, 'FM_plateau_valid', false);
            row.FM_plateau_reason = getStringOrDefault(pr, 'FM_plateau_reason', "");
            row.baseline_status = getStringOrDefault(pr, 'baseline_status', "");

            row.flag_missing_dip = ~(isfinite(row.Dip_area) && isfinite(row.Dip_depth));
            row.flag_missing_fm = ~(isfinite(row.FM_step_mag) && isfinite(row.FM_abs));
            row.flag_fit_missing = ~(isfinite(row.fit_R2) && isfinite(row.fit_RMSE));
            row.flag_any_issue = logical(row.flag_missing_dip || row.flag_missing_fm || ...
                row.flag_fit_missing || ~row.FM_plateau_valid);

            rows(end+1,1) = row; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    error('auditDecompositionStability:noRows', 'No audit rows were collected.');
end

rawTbl = struct2table(rows);
rawTbl = sortrows(rawTbl, {'wait_time','Tp','setting_id'});
rawCsvPath = fullfile(outDir, 'decomposition_stability_raw.csv');
writetable(rawTbl, rawCsvPath);

summaryTbl = buildSummaryTable(rawTbl);
summaryTbl = sortrows(summaryTbl, {'wait_time','Tp'});
summaryCsvPath = fullfile(outDir, 'decomposition_stability_summary_by_wait_tp.csv');
writetable(summaryTbl, summaryCsvPath);

mapsPath = fullfile(outDir, 'decomposition_stability_maps.png');
plotStabilityMaps(summaryTbl, mapsPath);

fprintf('Saved raw audit CSV: %s\n', rawCsvPath);
fprintf('Saved summary CSV: %s\n', summaryCsvPath);
fprintf('Saved stability maps: %s\n', mapsPath);


function row = initRawRow()
row = struct();
row.wait_time = "";
row.dataset = "";
row.Tp = NaN;

row.setting_id = "";
row.setting_name = "";
row.agingMetricMode = "";
row.smoothWindow_K = NaN;
row.FM_plateau_K = NaN;
row.FM_buffer_K = NaN;
row.useRobustBaseline = false;
row.FM_rightPlateauMode = "";
row.excludeLowT_mode = "";
row.sgolayFrame = NaN;

row.Dip_area = NaN;
row.Dip_depth = NaN;
row.Dip_sigma = NaN;
row.Dip_T0 = NaN;
row.Tmin = NaN;

row.FM_E = NaN;
row.FM_abs = NaN;
row.FM_step_mag = NaN;

row.fit_R2 = NaN;
row.fit_RMSE = NaN;
row.recon_RMSE_direct = NaN;

row.FM_plateau_valid = false;
row.FM_plateau_reason = "";
row.baseline_status = "";

row.flag_missing_dip = false;
row.flag_missing_fm = false;
row.flag_fit_missing = false;
row.flag_any_issue = false;
end


function settings = buildAuditSettings(baseCfg)
dipW = baseCfg.dip_window_K;
defSmooth = baseCfg.smoothWindow_K;
defPlateau = baseCfg.FM_plateau_K;
defBuffer = baseCfg.FM_buffer_K;
defFrame = baseCfg.sgolayFrame;

settings = struct('id', {}, 'name', {}, 'agingMetricMode', {}, ...
    'smoothWindow_K', {}, 'FM_plateau_K', {}, 'FM_buffer_K', {}, ...
    'useRobustBaseline', {}, 'FM_rightPlateauMode', {}, ...
    'excludeLowT_mode', {}, 'sgolayFrame', {});

settings(end+1) = makeSetting(1,  'default',            'direct', defSmooth,       defPlateau, defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(2,  'smooth_low',         'direct', 3*dipW,           defPlateau, defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(3,  'smooth_high',        'direct', 6*dipW,           defPlateau, defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(4,  'plateau_narrow',     'direct', defSmooth,        4,          defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(5,  'plateau_wide',       'direct', defSmooth,        8,          defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(6,  'buffer_small',       'direct', defSmooth,        defPlateau, 4,         false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(7,  'buffer_large',       'direct', defSmooth,        defPlateau, 8,         false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(8,  'lowT_post',          'direct', defSmooth,        defPlateau, defBuffer, false, 'fixed',    'post', defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(9,  'right_relative',     'direct', defSmooth,        defPlateau, defBuffer, false, 'relative', 'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(10, 'robust_baseline',    'direct', defSmooth,        defPlateau, defBuffer, true,  'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(11, 'robust_plus_wide',   'direct', 6*dipW,           8,          defBuffer, true,  'fixed',    'pre',  defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(12, 'robust_relative',    'direct', defSmooth,        defPlateau, defBuffer, true,  'relative', 'post', defFrame); %#ok<AGROW>
settings(end+1) = makeSetting(13, 'filter_frame_9',     'direct', defSmooth,        defPlateau, defBuffer, false, 'fixed',    'pre',  9); %#ok<AGROW>
settings(end+1) = makeSetting(14, 'filter_frame_21',    'direct', defSmooth,        defPlateau, defBuffer, false, 'fixed',    'pre',  21); %#ok<AGROW>
settings(end+1) = makeSetting(15, 'aging_mode_fit',     'fit',    defSmooth,        defPlateau, defBuffer, false, 'fixed',    'pre',  defFrame); %#ok<AGROW>
end


function s = makeSetting(idNum, name, mode, smoothK, plateauK, bufferK, useRobust, rightMode, lowTmode, frame)
s = struct();
s.id = sprintf('S%02d', idNum);
s.name = string(name);
s.agingMetricMode = string(mode);
s.smoothWindow_K = smoothK;
s.FM_plateau_K = plateauK;
s.FM_buffer_K = bufferK;
s.useRobustBaseline = logical(useRobust);
s.FM_rightPlateauMode = string(rightMode);
s.excludeLowT_mode = string(lowTmode);
s.sgolayFrame = frame;
end


function cfg = applyAuditSetting(cfg, setting)
cfg.agingMetricMode = char(setting.agingMetricMode);
cfg.smoothWindow_K = setting.smoothWindow_K;
cfg.FM_plateau_K = setting.FM_plateau_K;
cfg.FM_buffer_K = setting.FM_buffer_K;
cfg.useRobustBaseline = logical(setting.useRobustBaseline);
cfg.FM_rightPlateauMode = char(setting.FM_rightPlateauMode);
cfg.excludeLowT_mode = char(setting.excludeLowT_mode);
cfg.sgolayFrame = setting.sgolayFrame;
end


function summaryTbl = buildSummaryTable(rawTbl)
[G, waitVals, tpVals] = findgroups(rawTbl.wait_time, rawTbl.Tp);

groupIds = unique(G(~isnan(G)));
nG = numel(groupIds);
summaryRows = repmat(initSummaryRow(), nG, 1);

for ii = 1:nG
    g = groupIds(ii);
    idx = (G == g);
    sub = rawTbl(idx, :);

    row = initSummaryRow();
    row.wait_time = string(waitVals(g));
    row.Tp = tpVals(g);
    row.n_settings = height(sub);

    [row.Dip_area_mean, row.Dip_area_std, row.Dip_area_cv] = metricStats(sub.Dip_area);
    [row.Dip_depth_mean, row.Dip_depth_std, row.Dip_depth_cv] = metricStats(sub.Dip_depth);
    [row.Dip_sigma_mean, row.Dip_sigma_std, row.Dip_sigma_cv] = metricStats(sub.Dip_sigma);
    [row.Dip_T0_mean, row.Dip_T0_std, ~] = metricStats(sub.Dip_T0);
    [row.Tmin_mean, row.Tmin_std, ~] = metricStats(sub.Tmin);

    [row.FM_E_mean, row.FM_E_std, row.FM_E_cv] = metricStats(sub.FM_E);
    [row.FM_abs_mean, row.FM_abs_std, row.FM_abs_cv] = metricStats(sub.FM_abs);
    [row.FM_step_mag_mean, row.FM_step_mag_std, row.FM_step_mag_cv] = metricStats(sub.FM_step_mag);

    [row.fit_R2_mean, row.fit_R2_std, ~] = metricStats(sub.fit_R2);
    [row.fit_RMSE_mean, row.fit_RMSE_std, row.fit_RMSE_cv] = metricStats(sub.fit_RMSE);
    [row.recon_RMSE_direct_mean, row.recon_RMSE_direct_std, row.recon_RMSE_direct_cv] = metricStats(sub.recon_RMSE_direct);

    fmSign = sub.FM_step_mag;
    validSign = isfinite(fmSign) & abs(fmSign) > eps;
    if any(validSign)
        signs = sign(fmSign(validSign));
        majority = sign(median(fmSign(validSign)));
        row.FM_step_majority_sign = majority;
        row.FM_step_sign_consistency = mean(signs == majority);
    else
        row.FM_step_majority_sign = NaN;
        row.FM_step_sign_consistency = NaN;
    end

    row.issue_rate = mean(double(sub.flag_any_issue), 'omitnan');
    row.missing_dip_rate = mean(double(sub.flag_missing_dip), 'omitnan');
    row.missing_fm_rate = mean(double(sub.flag_missing_fm), 'omitnan');
    row.fit_missing_rate = mean(double(sub.flag_fit_missing), 'omitnan');
    row.plateau_invalid_rate = mean(double(~sub.FM_plateau_valid), 'omitnan');

    reasons = strings(0,1);
    if isfinite(row.FM_step_mag_cv) && row.FM_step_mag_cv > 0.50
        reasons(end+1,1) = "high_FM_step_cv"; %#ok<AGROW>
    end
    if isfinite(row.Dip_area_cv) && row.Dip_area_cv > 0.50
        reasons(end+1,1) = "high_Dip_area_cv"; %#ok<AGROW>
    end
    if isfinite(row.FM_step_sign_consistency) && row.FM_step_sign_consistency < 0.75
        reasons(end+1,1) = "low_FM_sign_consistency"; %#ok<AGROW>
    end
    if isfinite(row.issue_rate) && row.issue_rate > 0.25
        reasons(end+1,1) = "high_issue_rate"; %#ok<AGROW>
    end

    row.stability_flag_unstable = ~isempty(reasons);
    if isempty(reasons)
        row.stability_reasons = "";
    else
        row.stability_reasons = strjoin(reasons, ';');
    end

    summaryRows(ii,1) = row;
end

summaryTbl = struct2table(summaryRows);
end


function row = initSummaryRow()
row = struct();
row.wait_time = "";
row.Tp = NaN;
row.n_settings = 0;

row.Dip_area_mean = NaN;
row.Dip_area_std = NaN;
row.Dip_area_cv = NaN;

row.Dip_depth_mean = NaN;
row.Dip_depth_std = NaN;
row.Dip_depth_cv = NaN;

row.Dip_sigma_mean = NaN;
row.Dip_sigma_std = NaN;
row.Dip_sigma_cv = NaN;

row.Dip_T0_mean = NaN;
row.Dip_T0_std = NaN;

row.Tmin_mean = NaN;
row.Tmin_std = NaN;

row.FM_E_mean = NaN;
row.FM_E_std = NaN;
row.FM_E_cv = NaN;

row.FM_abs_mean = NaN;
row.FM_abs_std = NaN;
row.FM_abs_cv = NaN;

row.FM_step_mag_mean = NaN;
row.FM_step_mag_std = NaN;
row.FM_step_mag_cv = NaN;

row.fit_R2_mean = NaN;
row.fit_R2_std = NaN;

row.fit_RMSE_mean = NaN;
row.fit_RMSE_std = NaN;
row.fit_RMSE_cv = NaN;

row.recon_RMSE_direct_mean = NaN;
row.recon_RMSE_direct_std = NaN;
row.recon_RMSE_direct_cv = NaN;

row.FM_step_majority_sign = NaN;
row.FM_step_sign_consistency = NaN;

row.issue_rate = NaN;
row.missing_dip_rate = NaN;
row.missing_fm_rate = NaN;
row.fit_missing_rate = NaN;
row.plateau_invalid_rate = NaN;

row.stability_flag_unstable = false;
row.stability_reasons = "";
end


function [mu, sig, cv] = metricStats(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    mu = NaN;
    sig = NaN;
    cv = NaN;
    return;
end

mu = mean(x, 'omitnan');
sig = std(x, 0, 'omitnan');
den = abs(mu);
if den > eps
    cv = sig / den;
else
    cv = NaN;
end
end


function plotStabilityMaps(summaryTbl, outPath)
waitOrder = ["3 s", "36 s", "6 min", "60 min"];
tpVals = unique(summaryTbl.Tp(isfinite(summaryTbl.Tp)));
tpVals = sort(tpVals(:)');

M_fm_cv = makeMatrix(summaryTbl, waitOrder, tpVals, 'FM_step_mag_cv');
M_dip_cv = makeMatrix(summaryTbl, waitOrder, tpVals, 'Dip_area_cv');
M_sign = makeMatrix(summaryTbl, waitOrder, tpVals, 'FM_step_sign_consistency');
M_fitR2 = makeMatrix(summaryTbl, waitOrder, tpVals, 'fit_R2_mean');

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1500 950]);
tl = tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>

ax1 = nexttile;
imagesc(ax1, tpVals, 1:numel(waitOrder), M_fm_cv);
set(ax1, 'YTick', 1:numel(waitOrder), 'YTickLabel', cellstr(waitOrder));
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Wait time');
title(ax1, 'FM step variability (CV)');
colorbar(ax1);
grid(ax1, 'on');

ax2 = nexttile;
imagesc(ax2, tpVals, 1:numel(waitOrder), M_dip_cv);
set(ax2, 'YTick', 1:numel(waitOrder), 'YTickLabel', cellstr(waitOrder));
xlabel(ax2, 'T_p (K)');
ylabel(ax2, 'Wait time');
title(ax2, 'Dip area variability (CV)');
colorbar(ax2);
grid(ax2, 'on');

ax3 = nexttile;
imagesc(ax3, tpVals, 1:numel(waitOrder), M_sign);
set(ax3, 'YTick', 1:numel(waitOrder), 'YTickLabel', cellstr(waitOrder));
caxis(ax3, [0 1]);
xlabel(ax3, 'T_p (K)');
ylabel(ax3, 'Wait time');
title(ax3, 'FM step sign consistency');
colorbar(ax3);
grid(ax3, 'on');

ax4 = nexttile;
imagesc(ax4, tpVals, 1:numel(waitOrder), M_fitR2);
set(ax4, 'YTick', 1:numel(waitOrder), 'YTickLabel', cellstr(waitOrder));
caxis(ax4, [0 1]);
xlabel(ax4, 'T_p (K)');
ylabel(ax4, 'Wait time');
title(ax4, 'Fit quality (mean R^2)');
colorbar(ax4);
grid(ax4, 'on');

saveas(figH, outPath);
close(figH);
end


function M = makeMatrix(tbl, waitOrder, tpVals, fieldName)
M = nan(numel(waitOrder), numel(tpVals));
for i = 1:height(tbl)
    w = string(tbl.wait_time(i));
    tp = tbl.Tp(i);
    wi = find(waitOrder == w, 1, 'first');
    ti = find(abs(tpVals - tp) < 1e-9, 1, 'first');
    if ~isempty(wi) && ~isempty(ti)
        M(wi, ti) = tbl.(fieldName)(i);
    end
end
end


function rmse = computeDirectReconRMSE(pr)
rmse = NaN;
if ~isfield(pr, 'DeltaM') || ~isfield(pr, 'DeltaM_sharp') || ~isfield(pr, 'DeltaM_smooth')
    return;
end

dM = pr.DeltaM(:);
sharp = pr.DeltaM_sharp(:);
smooth = pr.DeltaM_smooth(:);

n = min([numel(dM), numel(sharp), numel(smooth)]);
if n < 3
    return;
end

dM = dM(1:n);
recon = sharp(1:n) + smooth(1:n);

mask = isfinite(dM) & isfinite(recon);
if nnz(mask) < 3
    return;
end

r = dM(mask) - recon(mask);
rmse = sqrt(mean(r.^2, 'omitnan'));
end


function v = getScalarOrNaN(s, fieldName)
v = NaN;
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x) && isfinite(x)
        v = double(x);
    end
end
end


function v = getFirstFiniteScalar(s, fieldList)
v = NaN;
for k = 1:numel(fieldList)
    f = fieldList{k};
    if isfield(s, f)
        x = s.(f);
        if ~isempty(x) && isscalar(x) && isfinite(x)
            v = double(x);
            return;
        end
    end
end
end


function v = getLogicalOrDefault(s, fieldName, defaultVal)
v = logical(defaultVal);
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x)
        v = logical(x);
    end
end
end


function v = getStringOrDefault(s, fieldName, defaultVal)
v = string(defaultVal);
if isfield(s, fieldName)
    x = s.(fieldName);
    if isstring(x)
        if ~isempty(x)
            v = x(1);
        end
    elseif ischar(x)
        v = string(x);
    elseif iscellstr(x)
        if ~isempty(x)
            v = string(x{1});
        end
    end
end
end

