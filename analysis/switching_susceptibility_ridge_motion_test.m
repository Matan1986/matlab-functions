function out = switching_susceptibility_ridge_motion_test(cfg)
% switching_susceptibility_ridge_motion_test
% Test whether chi_dyn(T) is primarily explained by ridge motion.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSources(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('suscept:%s | switch:%s | motion:%s', ...
    char(source.susceptRunName), char(source.switchRunName), char(source.motionRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Susceptibility ridge-motion run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] susceptibility ridge-motion test started\n', stampNow()));
appendText(run.log_path, sprintf('Susceptibility source: %s\n', char(source.susceptRunName)));
appendText(run.log_path, sprintf('Switching map source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Motion source: %s\n', char(source.motionRunName)));

susTbl = sortrows(readtable(source.susceptTablePath), 'T_K');
required = {'T_K','chi_dyn','chi_dyn_ridge','I_peak_mA','width_I_mA','S_peak','ridge_left_mA','ridge_right_mA'};
for i = 1:numel(required)
    if ~ismember(required{i}, susTbl.Properties.VariableNames)
        error('Missing required column %s in susceptibility table.', required{i});
    end
end

T = double(susTbl.T_K(:));
chi = double(susTbl.chi_dyn(:));
chiRidge = double(susTbl.chi_dyn_ridge(:));
Ipeak = double(susTbl.I_peak_mA(:));
widthI = double(susTbl.width_I_mA(:));
Speak = double(susTbl.S_peak(:));
ridgeL = double(susTbl.ridge_left_mA(:));
ridgeR = double(susTbl.ridge_right_mA(:));

motionSaved = NaN(size(T));
if exist(source.motionTablePath, 'file') == 2
    motionTbl = readtable(source.motionTablePath);
    if ismember('T_K', motionTbl.Properties.VariableNames) && ismember('motion_abs_dI_peak_dT', motionTbl.Properties.VariableNames)
        [lia, loc] = ismember(T, double(motionTbl.T_K(:)));
        motionSaved(lia) = double(motionTbl.motion_abs_dI_peak_dT(loc(lia)));
    end
end

dIpeak = finiteDiff(T, Ipeak);
motionRaw = abs(dIpeak);
ridgeCenter = 0.5 * (ridgeL + ridgeR);
ridgeSpan = ridgeR - ridgeL;
motionCenter = abs(finiteDiff(T, ridgeCenter));
motionSpan = abs(finiteDiff(T, ridgeSpan));
motionWidth = abs(finiteDiff(T, widthI));

model = fitShiftMotionModel(source, T, Ipeak, dIpeak, cfg);

chiNorm = normalizeMax(chi);
motionRawNorm = normalizeMax(motionRaw);
motionSavedNorm = normalizeMax(motionSaved);
motionCenterNorm = normalizeMax(motionCenter);
motionSpanNorm = normalizeMax(motionSpan);
chiPredNorm = normalizeMax(model.chiPredInterp);
chiResNorm = normalizeMax(model.chiResInterp);

alignedTbl = table(T, chi, chiNorm, chiRidge, Ipeak, widthI, Speak, ...
    motionRaw, motionRawNorm, motionSaved, motionSavedNorm, ...
    motionCenter, motionCenterNorm, motionSpan, motionSpanNorm, motionWidth, ...
    model.chiPredInterp, chiPredNorm, model.chiResInterp, chiResNorm, ...
    'VariableNames', {'T_K','chi_dyn','chi_dyn_norm','chi_dyn_ridge','I_peak_mA','width_I_mA','S_peak', ...
    'abs_dI_peak_dT_raw','abs_dI_peak_dT_raw_norm','abs_dI_peak_dT_saved','abs_dI_peak_dT_saved_norm', ...
    'abs_dI_ridge_center_dT','abs_dI_ridge_center_dT_norm','abs_d_ridge_span_dT','abs_d_ridge_span_dT_norm','abs_dwidthI_dT', ...
    'chi_dyn_model_pred','chi_dyn_model_pred_norm','chi_dyn_model_residual','chi_dyn_model_residual_norm'});

corrTbl = buildCorrelationTable(chi, chiRidge, motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, model.chiPredInterp, model.chiResInterp);
peakTbl = buildPeakTable(T, chi, chiRidge, motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, model.chiPredInterp, model.chiResInterp);
modelTbl = buildModelTable(model);
sourceTbl = buildSourceTable(source);

alignedPath = save_run_table(alignedTbl, 'susceptibility_ridge_motion_aligned.csv', runDir);
corrPath = save_run_table(corrTbl, 'susceptibility_ridge_motion_correlations.csv', runDir);
peakPath = save_run_table(peakTbl, 'susceptibility_ridge_motion_peaks.csv', runDir);
modelPath = save_run_table(modelTbl, 'susceptibility_ridge_motion_model_summary.csv', runDir);
sourcePath = save_run_table(sourceTbl, 'source_run_manifest.csv', runDir);

figOverlay1 = saveOverlayMain(T, chiNorm, motionRawNorm, motionSavedNorm, runDir, 'chi_dyn_vs_dIpeak_overlay');
figOverlay2 = saveOverlayOptional(T, chiNorm, motionCenterNorm, motionSpanNorm, runDir, 'chi_dyn_optional_ridge_coordinates_overlay');
figModel = saveModelFigure(T, chiNorm, chiPredNorm, chiResNorm, model, runDir, 'chi_dyn_motion_model_overlay');
figMap = saveMapFigure(model, runDir, 'dS_dT_motion_factorization_map_test');

reportText = buildReport(source, T, chi, motionRaw, corrTbl, model, cfg);
reportPath = save_run_report(reportText, 'switching_susceptibility_ridge_motion_test.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_susceptibility_ridge_motion_test_bundle.zip');

appendText(run.notes_path, sprintf('chi_dyn peak T = %.6g K\n', peakAtT(T, chi)));
appendText(run.notes_path, sprintf('|dI_peak/dT| peak T = %.6g K\n', peakAtT(T, motionRaw)));
appendText(run.notes_path, sprintf('Pearson(chi_dyn, |dI_peak/dT|) = %.6g\n', corrSafe(chi, motionRaw)));
appendText(run.notes_path, sprintf('Spearman(chi_dyn, |dI_peak/dT|) = %.6g\n', spearmanSafe(chi, motionRaw)));
appendText(run.notes_path, sprintf('Map factorization R2 = %.6g\n', model.mapR2));

appendText(run.log_path, sprintf('[%s] susceptibility ridge-motion test complete\n', stampNow()));
appendText(run.log_path, sprintf('Aligned table: %s\n', alignedPath));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Peak table: %s\n', peakPath));
appendText(run.log_path, sprintf('Model table: %s\n', modelPath));
appendText(run.log_path, sprintf('Source table: %s\n', sourcePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.tables = struct('aligned', string(alignedPath), 'correlations', string(corrPath), ...
    'peaks', string(peakPath), 'model', string(modelPath), 'source', string(sourcePath));
out.figures = struct('overlay_main', string(figOverlay1.png), 'overlay_optional', string(figOverlay2.png), ...
    'model_overlay', string(figModel.png), 'map_model', string(figMap.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.model = model;

fprintf('\n=== Susceptibility ridge-motion test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(chi_dyn, |dI_peak/dT|) = %.4f\n', corrSafe(chi, motionRaw));
fprintf('Spearman(chi_dyn, |dI_peak/dT|) = %.4f\n', spearmanSafe(chi, motionRaw));
fprintf('Map factorization R2 = %.4f\n', model.mapR2);
fprintf('Pearson(chi_obs, chi_pred) = %.4f\n', model.chiPredPearson);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_susceptibility_ridge_motion_test');
cfg = setDefault(cfg, 'susceptRunName', 'run_2026_03_14_063231_switching_dynamical_susceptibility');
cfg = setDefault(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'motionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefault(cfg, 'tempSmoothWindow', 3);
cfg = setDefault(cfg, 'modelUGridStep', 1.0);
cfg = setDefault(cfg, 'modelMinAbsMotion', 1e-6);
cfg = setDefault(cfg, 'interpMethod', 'pchip');
end

function source = resolveSources(repoRoot, cfg)
source = struct();
source.susceptRunName = string(cfg.susceptRunName);
source.switchRunName = string(cfg.switchRunName);
source.motionRunName = string(cfg.motionRunName);
source.susceptRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.susceptRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.motionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.motionRunName));
source.susceptTablePath = fullfile(source.susceptRunDir, 'tables', 'susceptibility_observables.csv');
source.switchMapPath = fullfile(source.switchRunDir, 'switching_alignment_core_data.mat');
source.switchObsPath = fullfile(source.switchRunDir, 'observable_matrix.csv');
source.motionTablePath = fullfile(source.motionRunDir, 'tables', 'relaxation_switching_motion_table.csv');

need = {
    source.susceptRunDir, source.susceptTablePath;
    source.switchRunDir, source.switchMapPath;
    source.switchRunDir, source.switchObsPath
    };
for i = 1:size(need,1)
    if exist(need{i,1}, 'dir') ~= 7
        error('Missing source run directory: %s', need{i,1});
    end
    if exist(need{i,2}, 'file') ~= 2
        error('Missing source file: %s', need{i,2});
    end
end
end
function model = fitShiftMotionModel(source, T, Ipeak, dIpeak, cfg)
cfgSwitch = struct();
cfgSwitch.switchRunName = char(source.switchRunName);
cfgSwitch.tempSmoothWindow = cfg.tempSmoothWindow;
res = switching_dynamical_susceptibility(cfgSwitch);

Tmap = double(res.temps(:));
I = double(res.currents(:));
dS = double(res.dS_dT);

IpeakMap = interp1(T, Ipeak, Tmap, 'nearest', NaN);
dIpeakMap = interp1(T, dIpeak, Tmap, 'nearest', NaN);

validRows = isfinite(IpeakMap) & isfinite(dIpeakMap) & abs(dIpeakMap) >= cfg.modelMinAbsMotion;
step = max(cfg.modelUGridStep, eps);

uMin = inf;
uMax = -inf;
for it = 1:numel(Tmap)
    if ~validRows(it)
        continue;
    end
    u = I - IpeakMap(it);
    uMin = min(uMin, min(u));
    uMax = max(uMax, max(u));
end

if ~(isfinite(uMin) && isfinite(uMax) && uMax > uMin)
    uGrid = NaN(0,1);
    kernel = NaN(0,1);
    pred = NaN(size(dS));
else
    uGrid = (ceil(uMin / step) * step):step:(floor(uMax / step) * step);
    if numel(uGrid) < 5
        uGrid = linspace(uMin, uMax, max(5, numel(I)));
    end

    scaledRows = NaN(numel(Tmap), numel(uGrid));
    for it = 1:numel(Tmap)
        if ~validRows(it)
            continue;
        end
        y = dS(it,:).';
        u = I - IpeakMap(it);
        m = isfinite(y) & isfinite(u);
        if nnz(m) < 3
            continue;
        end
        scaledRows(it,:) = interp1(u(m), (y(m) ./ dIpeakMap(it)), uGrid, 'linear', NaN);
    end

    kernel = nanmean(scaledRows(validRows,:),1);
    pred = NaN(size(dS));
    for it = 1:numel(Tmap)
        if ~validRows(it)
            continue;
        end
        kRow = interp1(uGrid, kernel, I - IpeakMap(it), 'linear', NaN);
        pred(it,:) = (dIpeakMap(it) .* kRow(:)).';
    end
end

resid = dS - pred;
chiObs = rowRMS(dS);
chiPred = rowRMS(pred);
chiRes = rowRMS(resid);

model = struct();
model.temps = Tmap;
model.currents = I;
model.Ipeak = IpeakMap;
model.dIpeak = dIpeakMap;
model.uGrid = uGrid(:);
model.kernel = kernel(:);
model.dSobs = dS;
model.dSpred = pred;
model.dSres = resid;
model.chiObs = chiObs;
model.chiPred = chiPred;
model.chiRes = chiRes;
model.chiPredInterp = interp1(Tmap, chiPred, T, cfg.interpMethod, NaN);
model.chiResInterp = interp1(Tmap, chiRes, T, cfg.interpMethod, NaN);
model.mapR2 = r2Safe(dS(:), pred(:));
model.mapRMSE = rmseSafe(dS(:), pred(:));
model.relResidual = sqrt(sum(resid(:).^2, 'omitnan') / max(sum(dS(:).^2, 'omitnan'), eps));
model.chiPredPearson = corrSafe(chiObs, chiPred);
model.chiPredSpearman = spearmanSafe(chiObs, chiPred);
model.chiObsPeakT = peakAtT(Tmap, chiObs);
model.chiPredPeakT = peakAtT(Tmap, chiPred);
model.peakDeltaK = model.chiPredPeakT - model.chiObsPeakT;
model.fitRowsUsed = nnz(validRows);
end

function tbl = buildCorrelationTable(chi, chiRidge, motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, chiPred, chiRes)
target = strings(0,1);
metric = strings(0,1);
pearson_r = [];
spearman_r = [];
n_points = [];

names = {'abs_dI_peak_dT_raw','abs_dI_peak_dT_saved','abs_dI_ridge_center_dT', ...
    'abs_d_ridge_span_dT','abs_dwidthI_dT','chi_dyn_model_pred','chi_dyn_model_residual'};
vals = {motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, chiPred, chiRes};

for i = 1:numel(names)
    x = vals{i};
    [p, s, n] = pairCorr(chi, x);
    target(end+1,1) = "chi_dyn";
    metric(end+1,1) = string(names{i});
    pearson_r(end+1,1) = p;
    spearman_r(end+1,1) = s;
    n_points(end+1,1) = n;

    [p, s, n] = pairCorr(chiRidge, x);
    target(end+1,1) = "chi_dyn_ridge";
    metric(end+1,1) = string(names{i});
    pearson_r(end+1,1) = p;
    spearman_r(end+1,1) = s;
    n_points(end+1,1) = n;
end

tbl = table(target, metric, pearson_r, spearman_r, n_points);
end

function tbl = buildPeakTable(T, chi, chiRidge, motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, chiPred, chiRes)
name = strings(0,1);
peak_T_K = [];
peak_value = [];

names = {'chi_dyn','chi_dyn_ridge','abs_dI_peak_dT_raw','abs_dI_peak_dT_saved', ...
    'abs_dI_ridge_center_dT','abs_d_ridge_span_dT','abs_dwidthI_dT','chi_dyn_model_pred','chi_dyn_model_residual'};
vals = {chi, chiRidge, motionRaw, motionSaved, motionCenter, motionSpan, motionWidth, chiPred, chiRes};

for i = 1:numel(names)
    y = vals{i};
    name(end+1,1) = string(names{i});
    peak_T_K(end+1,1) = peakAtT(T, y);
    peak_value(end+1,1) = peakValue(y);
end

delta_vs_chi_dyn_K = peak_T_K - peakAtT(T, chi);
tbl = table(name, peak_T_K, peak_value, delta_vs_chi_dyn_K);
end

function tbl = buildModelTable(model)
metric = strings(0,1);
value = [];
units = strings(0,1);
note = strings(0,1);

[metric,value,units,note] = addMetric(metric,value,units,note,'map_r2',model.mapR2,'unitless','Centered R^2 for dS/dT');
[metric,value,units,note] = addMetric(metric,value,units,note,'map_rmse',model.mapRMSE,'signal/K','RMSE on finite map entries');
[metric,value,units,note] = addMetric(metric,value,units,note,'map_relative_residual',model.relResidual,'unitless','sqrt(sum(res^2)/sum(obs^2))');
[metric,value,units,note] = addMetric(metric,value,units,note,'chi_pred_vs_obs_pearson',model.chiPredPearson,'unitless','corr(chi_obs,chi_pred)');
[metric,value,units,note] = addMetric(metric,value,units,note,'chi_pred_vs_obs_spearman',model.chiPredSpearman,'unitless','spearman(chi_obs,chi_pred)');
[metric,value,units,note] = addMetric(metric,value,units,note,'chi_obs_peak_T_K',model.chiObsPeakT,'K','Observed chi_dyn peak on map grid');
[metric,value,units,note] = addMetric(metric,value,units,note,'chi_pred_peak_T_K',model.chiPredPeakT,'K','Predicted chi_dyn peak on map grid');
[metric,value,units,note] = addMetric(metric,value,units,note,'chi_peak_delta_K',model.peakDeltaK,'K','Predicted minus observed');
[metric,value,units,note] = addMetric(metric,value,units,note,'fit_rows_used',model.fitRowsUsed,'count','Rows used in factorization fit');
[metric,value,units,note] = addMetric(metric,value,units,note,'u_grid_points',numel(model.uGrid),'count','Shifted-current grid points');

tbl = table(metric, value, units, note);
end

function tbl = buildSourceTable(source)
run_role = string({'susceptibility';'switching_map';'ridge_motion'});
run_name = string({char(source.susceptRunName);char(source.switchRunName);char(source.motionRunName)});
run_dir = string({source.susceptRunDir;source.switchRunDir;source.motionRunDir});
key_file = string({source.susceptTablePath;source.switchMapPath;source.motionTablePath});
key_file_exists = [exist(source.susceptTablePath,'file')==2; exist(source.switchMapPath,'file')==2; exist(source.motionTablePath,'file')==2];
tbl = table(run_role, run_name, run_dir, key_file, key_file_exists);
end

function [metric,value,units,note] = addMetric(metric,value,units,note,m,v,u,n)
metric(end+1,1) = string(m);
value(end+1,1) = v;
units(end+1,1) = string(u);
note(end+1,1) = string(n);
end
function figPaths = saveOverlayMain(T, chiNorm, motionRawNorm, motionSavedNorm, runDir, name)
fig = create_figure('Visible','off','Position',[2 2 8.6 6.8]);
ax = axes(fig);
hold(ax,'on');
plot(ax,T,chiNorm,'-o','Color',[0 0 0],'LineWidth',2.1,'MarkerSize',5,'MarkerFaceColor',[0 0 0],'DisplayName','\chi_{dyn}(T) / max');
plot(ax,T,motionRawNorm,'-s','Color',[0 0.4470 0.6980],'LineWidth',1.9,'MarkerSize',5,'MarkerFaceColor',[0 0.4470 0.6980],'DisplayName','|dI_{peak}/dT|_{raw} / max');
if any(isfinite(motionSavedNorm))
    plot(ax,T,motionSavedNorm,'--^','Color',[0.8350 0.3690 0],'LineWidth',1.8,'MarkerSize',5,'MarkerFaceColor',[0.8350 0.3690 0],'DisplayName','|dI_{peak}/dT|_{saved} / max');
end
hold(ax,'off');
xlabel(ax,'Temperature (K)');
ylabel(ax,'Normalized amplitude (arb. units)');
title(ax,'\chi_{dyn}(T) vs ridge-motion magnitude');
legend(ax,'Location','best','Box','off');
ylim(ax,[-0.02 1.05]);
xlim(ax,[min(T) max(T)]);
styleAxis(ax,false);
figPaths = save_run_figure(fig, name, runDir);
close(fig);
end

function figPaths = saveOverlayOptional(T, chiNorm, motionCenterNorm, motionSpanNorm, runDir, name)
fig = create_figure('Visible','off','Position',[2 2 8.6 6.8]);
ax = axes(fig);
hold(ax,'on');
plot(ax,T,chiNorm,'-o','Color',[0 0 0],'LineWidth',2.1,'MarkerSize',5,'MarkerFaceColor',[0 0 0],'DisplayName','\chi_{dyn}(T) / max');
plot(ax,T,motionCenterNorm,'-d','Color',[0.4940 0.1840 0.5560],'LineWidth',1.8,'MarkerSize',5,'MarkerFaceColor',[0.4940 0.1840 0.5560],'DisplayName','|dI_{ridge,center}/dT| / max');
plot(ax,T,motionSpanNorm,'--','Color',[0 0.6190 0.4510],'LineWidth',1.8,'DisplayName','|d(width_{ridge})/dT| / max');
hold(ax,'off');
xlabel(ax,'Temperature (K)');
ylabel(ax,'Normalized amplitude (arb. units)');
title(ax,'Optional ridge-coordinate overlays');
legend(ax,'Location','best','Box','off');
ylim(ax,[-0.02 1.05]);
xlim(ax,[min(T) max(T)]);
styleAxis(ax,false);
figPaths = save_run_figure(fig, name, runDir);
close(fig);
end

function figPaths = saveModelFigure(T, chiNorm, chiPredNorm, chiResNorm, model, runDir, name)
fig = create_figure('Visible','off','Position',[2 2 17.8 7.0]);
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

ax1 = nexttile(tl,1);
hold(ax1,'on');
plot(ax1,T,chiNorm,'-o','Color',[0 0 0],'LineWidth',2.1,'MarkerSize',5,'MarkerFaceColor',[0 0 0],'DisplayName','\chi_{dyn}^{obs} / max');
plot(ax1,T,chiPredNorm,'-s','Color',[0 0.4470 0.6980],'LineWidth',1.9,'MarkerSize',5,'MarkerFaceColor',[0 0.4470 0.6980],'DisplayName','\chi_{dyn}^{pred} / max');
plot(ax1,T,chiResNorm,'--^','Color',[0.8350 0.3690 0],'LineWidth',1.8,'MarkerSize',5,'MarkerFaceColor',[0.8350 0.3690 0],'DisplayName','\chi_{dyn}^{res} / max');
hold(ax1,'off');
xlabel(ax1,'Temperature (K)');
ylabel(ax1,'Normalized amplitude (arb. units)');
title(ax1,'Observed, predicted, residual susceptibility');
legend(ax1,'Location','best','Box','off');
ylim(ax1,[-0.02 1.05]);
xlim(ax1,[min(T) max(T)]);
styleAxis(ax1,false);
text(ax1,0.03,0.97,'a','Units','normalized','VerticalAlignment','top','FontWeight','bold','FontSize',11);

ax2 = nexttile(tl,2);
mask = isfinite(chiPredNorm) & isfinite(chiNorm);
scatter(ax2, chiPredNorm(mask), chiNorm(mask), 34, T(mask), 'filled');
hold(ax2,'on');
if nnz(mask) >= 2
    xFit = linspace(min(chiPredNorm(mask)), max(chiPredNorm(mask)), 100);
    p = polyfit(chiPredNorm(mask), chiNorm(mask), 1);
    plot(ax2, xFit, polyval(p, xFit), '--', 'Color',[0.15 0.15 0.15], 'LineWidth',1.8);
end
hold(ax2,'off');
cb = colorbar(ax2);
cb.Label.String = 'Temperature (K)';
xlabel(ax2,'\chi_{dyn}^{pred}(T) / max');
ylabel(ax2,'\chi_{dyn}^{obs}(T) / max');
title(ax2,'Factorized-model susceptibility check');
styleAxis(ax2,false);
text(ax2,0.04,0.96,sprintf('Pearson = %.3f\\newlineSpearman = %.3f',model.chiPredPearson,model.chiPredSpearman), ...
    'Units','normalized','VerticalAlignment','top','BackgroundColor','w','Margin',5);
text(ax2,0.03,0.97,'b','Units','normalized','VerticalAlignment','top','FontWeight','bold','FontSize',11);

figPaths = save_run_figure(fig, name, runDir);
close(fig);
end

function figPaths = saveMapFigure(model, runDir, name)
fig = create_figure('Visible','off','Position',[2 2 17.8 6.2]);
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
absMax = max(abs([model.dSobs(:); model.dSpred(:); model.dSres(:)]),[],'omitnan');
if ~(isfinite(absMax) && absMax > 0)
    absMax = 1;
end

maps = {model.dSobs, model.dSpred, model.dSres};
titles = {'Observed dS/dT','Predicted dS/dT','Residual dS/dT'};
for i = 1:3
    ax = nexttile(tl,i);
    imagesc(ax, model.currents, model.temps, maps{i});
    axis(ax,'xy');
    hold(ax,'on');
    plot(ax, model.Ipeak, model.temps, 'k-', 'LineWidth', 1.5);
    hold(ax,'off');
    caxis(ax,[-absMax absMax]);
    colormap(ax, blueWhiteRedMap(256));
    cb = colorbar(ax);
    cb.Label.String = 'signal / K';
    xlabel(ax,'Current (mA)');
    ylabel(ax,'Temperature (K)');
    title(ax,titles{i});
    styleAxis(ax,true);
end

figPaths = save_run_figure(fig, name, runDir);
close(fig);
end

function textOut = buildReport(source, T, chi, motionRaw, corrTbl, model, cfg)
chiPeak = peakAtT(T, chi);
motionPeak = peakAtT(T, motionRaw);
pearsonRaw = corrSafe(chi, motionRaw);
spearmanRaw = spearmanSafe(chi, motionRaw);
rowPred = corrTbl(strcmp(corrTbl.target,'chi_dyn') & strcmp(corrTbl.metric,'chi_dyn_model_pred'), :);
if isempty(rowPred)
    predPearson = NaN;
    predSpearman = NaN;
else
    predPearson = rowPred.pearson_r(1);
    predSpearman = rowPred.spearman_r(1);
end

L = strings(0,1);
L(end+1) = '# Switching Susceptibility Ridge-Motion Test';
L(end+1) = '';
L(end+1) = '## Repository-state summary';
L(end+1) = sprintf('- Reused susceptibility run: `%s`.', source.susceptRunName);
L(end+1) = sprintf('- Reused switching map run: `%s`.', source.switchRunName);
L(end+1) = sprintf('- Optional reused motion run: `%s`.', source.motionRunName);
L(end+1) = '';
L(end+1) = '## Main quantitative results';
L(end+1) = sprintf('- `chi_dyn(T)` peak temperature: %.3f K.', chiPeak);
L(end+1) = sprintf('- `|dI_peak/dT|` peak temperature: %.3f K (delta = %+0.3f K).', motionPeak, motionPeak - chiPeak);
L(end+1) = sprintf('- `chi_dyn` vs `|dI_peak/dT|` Pearson/Spearman: %.4f / %.4f.', pearsonRaw, spearmanRaw);
L(end+1) = sprintf('- `chi_dyn` vs model-predicted susceptibility Pearson/Spearman: %.4f / %.4f.', predPearson, predSpearman);
L(end+1) = '';
L(end+1) = '## Shift-motion approximation';
L(end+1) = sprintf('- Map-level factorization `R^2`: %.4f.', model.mapR2);
L(end+1) = sprintf('- Map-level RMSE: %.4g signal/K.', model.mapRMSE);
L(end+1) = sprintf('- Relative residual norm `sqrt(sum(res^2)/sum(obs^2))`: %.4f.', model.relResidual);
L(end+1) = sprintf('- Predicted susceptibility peak temperature: %.3f K (delta vs observed: %+0.3f K).', model.chiPredPeakT, model.peakDeltaK);
L(end+1) = '';
L(end+1) = '## Interpretation';
if model.mapR2 >= 0.7 && model.chiPredPearson >= 0.8 && abs(model.peakDeltaK) <= 2
    L(end+1) = '- The data are broadly consistent with a ridge-motion-dominated susceptibility picture.';
else
    L(end+1) = '- Ridge motion alone is insufficient: substantial residual structure remains or susceptibility peak/shape alignment is weak.';
end
L(end+1) = '- Therefore `chi_dyn(T)` contains additional contributions beyond simple threshold translation.';
L(end+1) = '';
L(end+1) = '## Visualization choices';
L(end+1) = '- number of curves: 2-3 curves per overlay panel; one triptych for observed/predicted/residual `dS/dT`.';
L(end+1) = '- legend vs colormap: legends for line overlays; diverging colormap with colorbars for signed heatmaps.';
L(end+1) = '- colormap used: custom blue-white-red with symmetric zero-centered limits in the map comparison.';
L(end+1) = sprintf('- smoothing applied: %d-point temperature smoothing in the reused susceptibility derivative pipeline.', cfg.tempSmoothWindow);
L(end+1) = '- justification: overlays capture peak/correlation behavior, and the map triptych directly audits factorization residuals.';

textOut = strjoin(L, newline);
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
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end
function [p,s,n] = pairCorr(x,y)
mask = isfinite(x) & isfinite(y);
n = nnz(mask);
if n < 3
    p = NaN;
    s = NaN;
    return;
end
p = corrSafe(x(mask), y(mask));
s = spearmanSafe(x(mask), y(mask));
end

function d = finiteDiff(T, y)
T = double(T(:));
y = double(y(:));
d = NaN(size(y));
mask = isfinite(T) & isfinite(y);
if nnz(mask) < 2
    return;
end
d(mask) = gradient(y(mask), T(mask));
end

function y = normalizeMax(x)
x = double(x(:));
y = NaN(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
m = max(abs(x(mask)), [], 'omitnan');
if ~(isfinite(m) && m > 0)
    return;
end
y(mask) = x(mask) ./ m;
end

function y = rowRMS(X)
X = double(X);
y = NaN(size(X,1),1);
for i = 1:size(X,1)
    row = X(i,:);
    row = row(isfinite(row));
    if ~isempty(row)
        y(i) = sqrt(mean(row.^2));
    end
end
end

function t = peakAtT(T, y)
T = double(T(:));
y = double(y(:));
t = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tv = T(mask);
t = Tv(idx);
end

function v = peakValue(y)
y = double(y(:));
y = y(isfinite(y));
if isempty(y)
    v = NaN;
else
    v = max(y);
end
end

function c = corrSafe(x,y)
x = double(x(:));
y = double(y(:));
mask = isfinite(x) & isfinite(y);
c = NaN;
if nnz(mask) < 3
    return;
end
C = corrcoef(x(mask), y(mask));
if numel(C) >= 4
    c = C(1,2);
end
end

function rho = spearmanSafe(x,y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = double(x(:));
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj+1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end

function r2 = r2Safe(y, yhat)
y = double(y(:));
yhat = double(yhat(:));
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 3
    r2 = NaN;
    return;
end
yv = y(mask);
yhv = yhat(mask);
ssRes = sum((yv - yhv).^2);
ssTot = sum((yv - mean(yv)).^2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function rmse = rmseSafe(y, yhat)
y = double(y(:));
yhat = double(yhat(:));
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    rmse = NaN;
else
    rmse = sqrt(mean((y(mask) - yhat(mask)).^2));
end
end

function cmap = blueWhiteRedMap(n)
if nargin < 1 || isempty(n)
    n = 256;
end
half = floor(n / 2);
blue = [0.23 0.30 0.75];
white = [1.00 1.00 1.00];
red = [0.71 0.02 0.15];
down = [linspace(blue(1), white(1), half)', linspace(blue(2), white(2), half)', linspace(blue(3), white(3), half)'];
up = [linspace(white(1), red(1), n - half)', linspace(white(2), red(2), n - half)', linspace(white(3), red(3), n - half)'];
cmap = [down; up];
end

function styleAxis(ax, isHeatmap)
if nargin < 2
    isHeatmap = false;
end
if isHeatmap
    boxMode = 'on';
else
    boxMode = 'off';
end
set(ax, 'FontName', 'Helvetica', 'LineWidth', 1.0, 'TickDir', 'out', 'Box', boxMode, ...
    'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, value)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = value;
end
end
