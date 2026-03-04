function adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, cfg)
% analyzeRelaxationAdvanced
% Add-on diagnostics + optional robust refits for relaxation analysis.
%
% Non-breaking design:
% - Consumes outputs from existing pipeline (`allFits`, tables).
% - Does not modify existing functions/signatures.
% - When cfg.useMultiStart/cfg.enableLogModel are false, it evaluates baseline fits only.
%
% Outputs (adv struct):
%   adv.results      table with per-curve diagnostics and model selection
%   adv.cfg          effective configuration
%   adv.figures      struct of generated figure handles
%
% Example:
%   cfg = struct('makePerCurvePlots',true,'debugResidualPlot',true);
%   adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, cfg);

if nargin < 5, cfg = struct(); end
cfg = localDefaults(cfg);

adv = struct();
adv.cfg = cfg;
adv.figures = struct('perCurve', gobjects(0), 'summary', gobjects(0), 'collapse', gobjects(0), ...
    'tauVsTemp', gobjects(0), 'betaVsTemp', gobjects(0), 'residuals', gobjects(0), 'tauDistribution', gobjects(0));

if isempty(allFits)
    warning('analyzeRelaxationAdvanced:NoFits', 'allFits is empty. Nothing to analyze.');
    adv.results = table();
    return;
end

if isstruct(allFits)
    Tfits = struct2table(allFits);
else
    Tfits = allFits;
end

required = {'data_idx','Minf','dM','tau','n','t_start','t_end','R2','Temp_K'};
for iReq = 1:numel(required)
    if ~ismember(required{iReq}, Tfits.Properties.VariableNames)
        error('analyzeRelaxationAdvanced:MissingColumn', ...
            'Missing required column in allFits: %s', required{iReq});
    end
end

nRows = height(Tfits);
rows = repmat(localEmptyRow(), nRows, 1);

for i = 1:nRows
    idx = Tfits.data_idx(i);
    if idx < 1 || idx > numel(Time_table)
        rows(i).fit_status = "bad_index";
        continue;
    end

    tRaw = Time_table{idx};
    mRaw = Moment_table{idx};
    if isempty(tRaw) || isempty(mRaw)
        rows(i).fit_status = "empty_data";
        continue;
    end

    [tFit, mFit] = localWindowData(tRaw, mRaw, Tfits.t_start(i), Tfits.t_end(i));
    if numel(tFit) < cfg.minPoints
        rows(i).fit_status = "too_few_points";
        rows(i).Npts = numel(tFit);
        continue;
    end

    rows(i).data_idx = idx;
    rows(i).Temp_K = Tfits.Temp_K(i);
    rows(i).Npts = numel(tFit);

    % Baseline model from existing fit outputs
    base = localEvalStretchModel(tFit, Tfits.Minf(i), Tfits.dM(i), Tfits.tau(i), Tfits.n(i), Tfits.t_start(i));
    [rows(i).RMSE_base, rows(i).AIC_base, rows(i).BIC_base] = localScoreModel(mFit, base, 4);
    rows(i).R2_base = Tfits.R2(i);

    % Optional robust multi-start stretched exponential re-fit
    stretch = struct('ok',false,'Minf',NaN,'dM',NaN,'tau',NaN,'beta',NaN,'t0',Tfits.t_start(i), ...
        'RMSE',NaN,'AIC',NaN,'BIC',NaN,'exitflag',NaN,'Mfit',nan(size(mFit)));
    if cfg.useMultiStart
        stretch = localFitStretchMultiStart(tFit, mFit, cfg);
    end

    % Optional alternative log model
    logm = struct('ok',false,'M0',NaN,'S',NaN,'RMSE',NaN,'AIC',NaN,'BIC',NaN,'Mfit',nan(size(mFit)));
    if cfg.enableLogModel
        logm = localFitLogModel(tFit, mFit, cfg);
    end

    rows(i).AIC_stretched = stretch.AIC;
    rows(i).BIC_stretched = stretch.BIC;
    rows(i).AIC_log = logm.AIC;
    rows(i).BIC_log = logm.BIC;

    % Model selection
    choice = "baseline";
    metricBase = rows(i).AIC_base;
    if strcmpi(cfg.modelCriterion, 'BIC')
        metricBase = rows(i).BIC_base;
    end

    metricStretch = inf;
    if stretch.ok
        metricStretch = pickMetric(stretch, cfg.modelCriterion);
    end
    metricLog = inf;
    if logm.ok
        metricLog = pickMetric(logm, cfg.modelCriterion);
    end

    switch lower(cfg.modelSelectionMode)
        case 'force_baseline'
            choice = "baseline";
        otherwise
            allMetrics = [metricBase, metricStretch, metricLog];
            [~, imin] = min(allMetrics);
            labels = ["baseline","stretched_multistart","log_model"];
            choice = labels(imin);
    end

    % Fill selected outputs
    rows(i).model_choice = choice;
    rows(i).exitflag = NaN;
    rows(i).tau = Tfits.tau(i);
    rows(i).beta = Tfits.n(i);
    rows(i).Minf = Tfits.Minf(i);
    rows(i).dM = Tfits.dM(i);
    rows(i).R2 = Tfits.R2(i);

    selectedFit = base;
    selectedRMSE = rows(i).RMSE_base;
    selectedAIC = rows(i).AIC_base;
    selectedBIC = rows(i).BIC_base;

    if choice == "stretched_multistart"
        rows(i).exitflag = stretch.exitflag;
        rows(i).tau = stretch.tau;
        rows(i).beta = stretch.beta;
        rows(i).Minf = stretch.Minf;
        rows(i).dM = stretch.dM;
        rows(i).R2 = localR2(mFit, stretch.Mfit);
        selectedFit = stretch.Mfit;
        selectedRMSE = stretch.RMSE;
        selectedAIC = stretch.AIC;
        selectedBIC = stretch.BIC;
    elseif choice == "log_model"
        rows(i).beta = NaN;
        rows(i).tau = NaN;
        rows(i).Minf = NaN;
        rows(i).dM = NaN;
        rows(i).R2 = localR2(mFit, logm.Mfit);
        selectedFit = logm.Mfit;
        selectedRMSE = logm.RMSE;
        selectedAIC = logm.AIC;
        selectedBIC = logm.BIC;
        rows(i).fit_status = "log_model";
    end

    rows(i).RMSE = selectedRMSE;
    rows(i).AIC = selectedAIC;
    rows(i).BIC = selectedBIC;

    tSpan = max(tFit) - min(tFit);
    tauVal = rows(i).tau;
    rows(i).tau_unresolved = isfinite(tauVal) && (tauVal > cfg.tauUnresolvedFactor * max(tSpan, eps));

    if rows(i).fit_status == ""
        if ~isfinite(selectedRMSE)
            rows(i).fit_status = "fit_failed";
            rows(i).fit_ok = false;
        elseif rows(i).tau_unresolved
            rows(i).fit_status = "tau_unresolved";
            rows(i).fit_ok = false;
        elseif rows(i).R2 < cfg.minR2_ok
            rows(i).fit_status = "low_r2";
            rows(i).fit_ok = false;
        else
            rows(i).fit_status = "ok";
            rows(i).fit_ok = true;
        end
    else
        rows(i).fit_ok = rows(i).fit_status == "ok";
    end

    if cfg.makePerCurvePlots
        adv.figures.perCurve(end+1) = localPlotPerCurve(i, tFit, mFit, selectedFit, rows(i), cfg); %#ok<AGROW>
    end

    if cfg.debugResidualPlot && cfg.makePerCurvePlots
        localPlotResidualDebug(i, tFit, mFit - selectedFit, rows(i));
    end

    if cfg.debug
        localPrintDebugDiagnostics(rows(i), cfg);
    end
end

adv.results = struct2table(rows);
adv.results = sortrows(adv.results, {'Temp_K','data_idx'});
plotArrhenius(adv.results);

if cfg.makeSummaryPlot
    adv.figures.summary = localPlotSummary(adv.results, cfg);
end
if cfg.makeCollapsePlot
    adv.figures.collapse = localPlotCollapse(adv.results, Time_table, Moment_table, Tfits, cfg);
end
if cfg.makePhysicsPlots
    [adv.figures.tauVsTemp, adv.figures.betaVsTemp] = localPlotPhysicsParams(adv.results, cfg);
end
if cfg.makeResidualDiagnostics
    adv.figures.residuals = localPlotResidualDiagnostics(adv.results, Time_table, Moment_table, Tfits, cfg);
end
if cfg.makeTauDistribution
    adv.figures.tauDistribution = localPlotTauDistribution(adv.results, cfg);
end
if cfg.advanced && cfg.debug
    localPrintAdvancedSummary(adv.results);
end

end

function cfg = localDefaults(cfg)
cfg = setDef(cfg,'useMultiStart',true);
cfg = setDef(cfg,'enableLogModel',true);
cfg = setDef(cfg,'modelCriterion','AIC'); % AIC | BIC
cfg = setDef(cfg,'modelSelectionMode','best_metric'); % best_metric | force_baseline
cfg = setDef(cfg,'nStarts',10);
cfg = setDef(cfg,'minPoints',15);
cfg = setDef(cfg,'tauUnresolvedFactor',2.0);
cfg = setDef(cfg,'minR2_ok',0.90);
cfg = setDef(cfg,'makePerCurvePlots',false);
cfg = setDef(cfg,'makeSummaryPlot',true);
cfg = setDef(cfg,'makeCollapsePlot',true);
cfg = setDef(cfg,'debugResidualPlot',false);
cfg = setDef(cfg,'advanced',false);
cfg = setDef(cfg,'debug',false);
cfg = setDef(cfg,'makePhysicsPlots',false);
cfg = setDef(cfg,'makeResidualDiagnostics',false);
cfg = setDef(cfg,'makeTauDistribution',false);
cfg = setDef(cfg,'tauDistBins',60);
cfg = setDef(cfg,'figureVisible','on');
end

function S = setDef(S, f, v)
if ~isfield(S,f), S.(f)=v; end
end

function row = localEmptyRow()
row = struct('data_idx',NaN,'Temp_K',NaN,'Npts',0,'fit_ok',false,'fit_status',"", ...
    'model_choice',"baseline",'exitflag',NaN,'R2',NaN,'R2_base',NaN,'RMSE',NaN,'RMSE_base',NaN, ...
    'AIC',NaN,'BIC',NaN,'AIC_base',NaN,'BIC_base',NaN,'AIC_stretched',NaN,'BIC_stretched',NaN, ...
    'AIC_log',NaN,'BIC_log',NaN,'tau',NaN,'beta',NaN,'Minf',NaN,'dM',NaN, ...
    'tau_unresolved',false);
end

function [tFit, mFit] = localWindowData(t, m, t0, t1)
t = t(:); m = m(:);
ok = isfinite(t) & isfinite(m);
t = t(ok); m = m(ok);
if isempty(t)
    tFit = []; mFit = [];
    return;
end
mask = t >= t0 & t <= t1;
tFit = t(mask);
mFit = m(mask);
end

function Mfit = localEvalStretchModel(t, Minf, dM, tau, beta, t0)
z = max(0, (t - t0) ./ max(tau,1e-12));
Mfit = Minf + dM .* exp(-(z.^beta));
end

function [rmse, aic, bic] = localScoreModel(y, yhat, k)
r = y - yhat;
rss = nansum(r.^2);
n = sum(isfinite(y) & isfinite(yhat));
if n <= k+1 || rss <= 0 || ~isfinite(rss)
    rmse = NaN; aic = NaN; bic = NaN; return;
end
rmse = sqrt(rss/n);
aic = n*log(rss/n) + 2*k;
bic = n*log(rss/n) + k*log(n);
end

function r2 = localR2(y, yhat)
ssr = nansum((y-yhat).^2);
sst = nansum((y-mean(y,'omitnan')).^2);
r2 = 1 - ssr/max(sst, eps);
end

function stretch = localFitStretchMultiStart(t, m, cfg)
stretch = struct('ok',false,'Minf',NaN,'dM',NaN,'tau',NaN,'beta',NaN,'t0',min(t), ...
    'RMSE',NaN,'AIC',NaN,'BIC',NaN,'exitflag',NaN,'Mfit',nan(size(m)));

tn = (t - min(t)) / max(max(t)-min(t), eps);
Minf0 = median(m(max(1,end-5):end),'omitnan');
dM0 = m(1)-Minf0;

lb = [-Inf, -Inf, 0.005, 0.05];
ub = [ Inf,  Inf, 50.0, 1.5];
opts = optimoptions('lsqcurvefit','Display','off','MaxFunctionEvaluations',6000,'MaxIterations',1200);

model = @(x,tt) x(1) + x(2).*exp(-((tt./x(3)).^x(4)));

bestX = [];
bestRSS = inf;
bestExit = NaN;

for s = 1:cfg.nStarts
    tau0 = 10^(log10(0.03) + (log10(2.0)-log10(0.03))*rand());
    beta0 = 0.25 + (1.1-0.25)*rand();
    x0 = [Minf0, dM0, tau0, beta0];
    try
        [x,resnorm,~,exitflag] = lsqcurvefit(model, x0, tn, m, lb, ub, opts);
        if isfinite(resnorm) && resnorm < bestRSS
            bestRSS = resnorm;
            bestX = x;
            bestExit = exitflag;
        end
    catch
    end
end

if isempty(bestX)
    return;
end

stretch.ok = true;
stretch.exitflag = bestExit;
stretch.Minf = bestX(1);
stretch.dM = bestX(2);
stretch.tau = bestX(3) * max(max(t)-min(t), eps);
stretch.beta = bestX(4);
stretch.Mfit = model(bestX, tn);
[stretch.RMSE, stretch.AIC, stretch.BIC] = localScoreModel(m, stretch.Mfit, 4);
end

function logm = localFitLogModel(t, m, cfg)
logm = struct('ok',false,'M0',NaN,'S',NaN,'RMSE',NaN,'AIC',NaN,'BIC',NaN,'Mfit',nan(size(m)));

x = t - min(t);
x = x + max(eps, min(x(x>0),[],'omitnan'));
ok = isfinite(x) & x>0 & isfinite(m);
if sum(ok) < cfg.minPoints
    return;
end
lx = log(x(ok));
y = m(ok);

p = polyfit(lx, y, 1); % y = p1*log(t)+p2 ; target model M0 - S*log(t)
Mhat = polyval(p, lx);
full = nan(size(m));
full(ok) = Mhat;

logm.ok = true;
logm.S = -p(1);
logm.M0 = p(2);
logm.Mfit = full;
[logm.RMSE, logm.AIC, logm.BIC] = localScoreModel(y, Mhat, 2);
end

function v = pickMetric(s, criterion)
if strcmpi(criterion,'BIC')
    v = s.BIC;
else
    v = s.AIC;
end
if ~isfinite(v), v = inf; end
end

function fig = localPlotPerCurve(i, t, m, mfit, row, cfg)
fig = figure('Color','w','Name',sprintf('Relax Fit %d',i),'Visible',cfg.figureVisible);
ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');

patch(ax, [min(t) max(t) max(t) min(t)]/60, [min(m) min(m) max(m) max(m)], ...
    [0.92 0.96 1.00], 'EdgeColor','none','FaceAlpha',0.5, 'DisplayName','Fit window');
plot(ax, t/60, m, 'k.', 'DisplayName','Data', 'MarkerSize',10);
plot(ax, t/60, mfit, '-', 'LineWidth',2.0, 'Color',[0.80 0.1 0.1], 'DisplayName','Selected fit');

xlabel(ax,'Time [min]');
ylabel(ax,'M');
set(ax,'FontSize',12,'LineWidth',1);

txt = sprintf(['T=%.2f K\nmodel=%s\n\\tau=%.3g s, \\beta=%.3g\nR^2=%.3f, RMSE=%.3g\nstatus=%s'], ...
    row.Temp_K, row.model_choice, row.tau, row.beta, row.R2, row.RMSE, row.fit_status);
text(ax, 0.02, 0.98, txt, 'Units','normalized', 'VerticalAlignment','top', ...
    'BackgroundColor','w', 'Margin',6, 'FontSize',10);

legend(ax,'Location','best');
end

function localPlotResidualDebug(i, t, resid, row)
figure('Color','w','Name',sprintf('Residual Debug %d',i));
semilogx(max(t-min(t),eps), resid, 'o-','LineWidth',1.1);
grid on; box on;
xlabel('Elapsed time [s] (log scale)');
ylabel('Residual M_{data}-M_{fit}');
title(sprintf('Residuals — T=%.2f K, model=%s', row.Temp_K, row.model_choice));
end

function fig = localPlotSummary(T, cfg)
fig = figure('Color','w','Name','AIC model comparison','Visible',cfg.figureVisible);
ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');

ok = isfinite(T.Temp_K);
if ~any(ok)
    text(0.2,0.5,'No finite temperatures for AIC comparison','Units','normalized');
    return;
end

plot(ax, T.Temp_K, T.AIC_base, 'o-', 'LineWidth',1.4, 'DisplayName','AIC baseline');
if any(isfinite(T.AIC_stretched))
    plot(ax, T.Temp_K, T.AIC_stretched, 's-', 'LineWidth',1.4, 'DisplayName','AIC stretched-multistart');
end
if any(isfinite(T.AIC_log))
    plot(ax, T.Temp_K, T.AIC_log, 'd-', 'LineWidth',1.4, 'DisplayName','AIC log-model');
end

xlabel(ax,'Temperature [K]');
ylabel(ax,'AIC');
title(ax,'AIC model comparison');
legend(ax,'Location','eastoutside');
end
function fig = localPlotCollapse(Tadv, Time_table, Moment_table, Tfits, cfg)
fig = figure('Color','w','Name','Collapse test','Visible',cfg.figureVisible);
ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');

for i = 1:height(Tadv)
    if ~isfinite(Tadv.tau(i)) || ~isfinite(Tadv.beta(i)) || ~isfinite(Tadv.Minf(i)) || ~isfinite(Tadv.dM(i))
        continue;
    end
    idx = Tadv.data_idx(i);
    if idx < 1 || idx > numel(Time_table), continue; end

    t = Time_table{idx};
    m = Moment_table{idx};
    if isempty(t) || isempty(m), continue; end

    msk = t >= Tfits.t_start(i) & t <= Tfits.t_end(i);
    t = t(msk); m = m(msk);
    if isempty(t), continue; end

    x = ((max(0,(t - min(t))) ./ max(Tadv.tau(i),eps))).^Tadv.beta(i);
    y = (m - Tadv.Minf(i)) ./ max(Tadv.dM(i), eps);
    plot(ax, x, y, '.', 'MarkerSize',8);
end

set(ax,'XScale','log');
xlabel(ax,'(t/\tau)^\beta');
ylabel(ax,'(M-M_\infty)/\Delta M');
title(ax,'Stretched-exponential collapse test');
end

function [figTau, figBeta] = localPlotPhysicsParams(T, cfg)
figTau = figure('Color','w','Name','tau(T)','Visible',cfg.figureVisible);
ax1 = axes(figTau); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
mTau = isfinite(T.Temp_K) & isfinite(T.tau) & T.model_choice ~= "log_model";
plot(ax1, T.Temp_K(mTau), T.tau(mTau), 'o-','LineWidth',1.6,'MarkerSize',6);
set(ax1,'YScale','log');
xlabel(ax1,'Temperature [K]'); ylabel(ax1,'\tau [s]');
title(ax1,'Characteristic relaxation time \tau(T)');

figBeta = figure('Color','w','Name','beta(T)','Visible',cfg.figureVisible);
ax2 = axes(figBeta); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
mBeta = isfinite(T.Temp_K) & isfinite(T.beta) & T.model_choice ~= "log_model";
plot(ax2, T.Temp_K(mBeta), T.beta(mBeta), 's-','LineWidth',1.6,'MarkerSize',6);
xlabel(ax2,'Temperature [K]'); ylabel(ax2,'\beta');
title(ax2,'Stretched exponent \beta(T)');
ylim(ax2,[0 1.2]);
end

function fig = localPlotResidualDiagnostics(Tadv, Time_table, Moment_table, Tfits, cfg)
fig = figure('Color','w','Name','Residual diagnostics','Visible',cfg.figureVisible);
ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
for i = 1:height(Tadv)
    idx = Tadv.data_idx(i);
    if idx < 1 || idx > numel(Time_table), continue; end
    if ~isfinite(Tadv.Minf(i)) || ~isfinite(Tadv.dM(i)) || ~isfinite(Tadv.tau(i)) || ~isfinite(Tadv.beta(i)), continue; end
    t = Time_table{idx}; m = Moment_table{idx};
    if isempty(t) || isempty(m), continue; end
    msk = t >= Tfits.t_start(i) & t <= Tfits.t_end(i);
    t = t(msk); m = m(msk);
    if numel(t) < 3, continue; end
    mfit = localEvalStretchModel(t, Tadv.Minf(i), Tadv.dM(i), Tadv.tau(i), Tadv.beta(i), min(t));
    semilogx(ax, max(t-min(t),eps), m-mfit, '.', 'DisplayName', sprintf('T=%.1fK', Tadv.Temp_K(i)));
end
xlabel(ax,'Elapsed time [s] (log scale)');
ylabel(ax,'Residual M_{data}-M_{fit}');
title(ax,'Residual diagnostics vs log(t)');
end

function fig = localPlotTauDistribution(T, cfg)
fig = figure('Color','w','Name','Relaxation-time distribution g(\tau)','Visible',cfg.figureVisible);
ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');

mask = isfinite(T.tau) & T.tau > 0 & isfinite(T.beta) & T.beta > 0 & T.model_choice ~= "log_model";
if ~any(mask)
    text(ax,0.1,0.5,'No valid stretched-exponential fits for g(\tau)','Units','normalized');
    return;
end

u = linspace(-3, 3, cfg.tauDistBins); % log-space offset from ln(tau_c)
for i = find(mask(:))'
    tauC = T.tau(i);
    beta = T.beta(i);
    tauGrid = tauC .* exp(u);
    width = max(0.08, 1.2*(1-beta));
    g = exp(-0.5*(u/width).^2) ./ (sqrt(2*pi)*width);
    g = g / trapz(log(tauGrid), g);
    plot(ax, tauGrid, g, 'LineWidth',1.0, 'DisplayName', sprintf('T=%.1fK, \\beta=%.2f', T.Temp_K(i), beta));
end
set(ax,'XScale','log');
xlabel(ax,'\tau [s]');
ylabel(ax,'g(\tau) (normalized)');
title(ax,'Approximate implied relaxation-time distributions');
end

function localPrintAdvancedSummary(T)
fprintf('\n=== Advanced Relaxation Summary ===\n\n');
fprintf('%-7s %-10s %-7s %-20s %-10s %-7s\n', 'T(K)', 'tau(s)', 'beta', 'model', 'RMSE', 'R2');
fprintf('%s\n', repmat('-',1,67));
for i = 1:height(T)
    fprintf('%-7.2f %-10.4g %-7.3f %-20s %-10.4g %-7.3f\n', ...
        T.Temp_K(i), T.tau(i), T.beta(i), string(T.model_choice(i)), T.RMSE(i), T.R2(i));
end
fprintf('\n');
end

function localPrintDebugDiagnostics(row, cfg)
fprintf('--- Fit diagnostics ---\n');
fprintf('T = %.3g K\n', row.Temp_K);
fprintf('Npts = %d\n', row.Npts);
fprintf('Model: %s\n', row.model_choice);
fprintf('AIC(baseline)  = %.6g\n', row.AIC_base);
if cfg.useMultiStart
    fprintf('AIC(stretched) = %.6g\n', row.AIC_stretched);
end
if cfg.enableLogModel
    fprintf('AIC(log)       = %.6g\n', row.AIC_log);
end
fprintf('Chosen model   = %s\n', row.model_choice);
fprintf('fit_status     = %s\n', row.fit_status);
fprintf('exitflag       = %.0f\n', row.exitflag);
fprintf('tau_unresolved = %d\n', row.tau_unresolved);
fprintf('tau = %.6g s\n', row.tau);
fprintf('beta = %.6g\n\n', row.beta);
end
