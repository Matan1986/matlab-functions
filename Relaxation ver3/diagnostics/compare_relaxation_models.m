%% compare_relaxation_models
% Diagnostics-only comparison between:
%   1) KWW: M(t) = Minf + dM * exp(-((t-t0)/tau)^beta)
%   2) LOG: M(t) = M0 - S*log(t)
%
% REQUIRED IN WORKSPACE:
%   allFits, Time_table, Moment_table
%
% This script does NOT modify existing pipeline behavior.

fprintf('\n=== Relaxation Model Comparison: KWW vs LOG ===\n');

%% ------------------------------------------------------------------------
% 0) Input validation
% -------------------------------------------------------------------------
if ~exist('allFits','var') || isempty(allFits)
    error('compare_relaxation_models:MissingAllFits', ...
        'allFits not found in workspace. Run main_relaxation first.');
end
if ~exist('Time_table','var') || isempty(Time_table)
    error('compare_relaxation_models:MissingTimeTable', ...
        'Time_table not found in workspace. Run main_relaxation first.');
end
if ~exist('Moment_table','var') || isempty(Moment_table)
    error('compare_relaxation_models:MissingMomentTable', ...
        'Moment_table not found in workspace. Run main_relaxation first.');
end

if isstruct(allFits)
    Tfit = struct2table(allFits);
else
    Tfit = allFits;
end

requiredCols = {'Temp_K','Minf','dM','tau','n','R2','t_start','t_end','data_idx'};
for k = 1:numel(requiredCols)
    if ~ismember(requiredCols{k}, Tfit.Properties.VariableNames)
        error('compare_relaxation_models:MissingColumn', ...
            'Missing required allFits column: %s', requiredCols{k});
    end
end

%% ------------------------------------------------------------------------
% 1) Real fits only (exclude fallback tau=Inf)
% -------------------------------------------------------------------------
isRealFit = isfinite(Tfit.tau) & (Tfit.tau < Inf) & ...
            isfinite(Tfit.n) & isfinite(Tfit.Minf) & isfinite(Tfit.dM) & ...
            isfinite(Tfit.t_start) & isfinite(Tfit.t_end) & isfinite(Tfit.Temp_K);

Treal = Tfit(isRealFit, :);

fprintf('Total rows in allFits: %d\n', height(Tfit));
fprintf('Rows used for model comparison (tau finite): %d\n', height(Treal));

if height(Treal) < 3
    error('compare_relaxation_models:TooFewRows', ...
        'Need at least 3 finite-tau rows for model comparison.');
end

%% ------------------------------------------------------------------------
% 2) Per-temperature metrics on same fit window used by KWW
% -------------------------------------------------------------------------
nRows = height(Treal);

Temp_K    = NaN(nRows,1);
R2_KWW    = NaN(nRows,1);
R2_LOG    = NaN(nRows,1);
RMSE_KWW  = NaN(nRows,1);
RMSE_LOG  = NaN(nRows,1);
AIC_KWW   = NaN(nRows,1);
AIC_LOG   = NaN(nRows,1);
Npts      = NaN(nRows,1);

% Optional extra outputs
M0_LOG    = NaN(nRows,1);
S_LOG     = NaN(nRows,1);

for i = 1:nRows
    row = Treal(i,:);
    Temp_K(i) = row.Temp_K;

    idx = row.data_idx;
    if ~isfinite(idx) || idx < 1 || idx > numel(Time_table) || idx > numel(Moment_table)
        continue;
    end

    t = Time_table{idx};
    m = Moment_table{idx};
    if isempty(t) || isempty(m)
        continue;
    end

    t = t(:); m = m(:);
    ok = isfinite(t) & isfinite(m);
    t = t(ok); m = m(ok);

    t0 = row.t_start;
    t1 = row.t_end;

    mask = (t >= t0) & (t <= t1);
    if ~any(mask)
        continue;
    end

    tSel = t(mask);
    mSel = m(mask);
    n = numel(tSel);
    if n < 5
        continue;
    end
    Npts(i) = n;

    % ---------- KWW prediction using stored final fit parameters ----------
    Minf = row.Minf;
    dM   = row.dM;
    tau  = row.tau;
    beta = row.n;

    z = max(0, (tSel - t0) ./ max(tau, eps));
    mHatKWW = Minf + dM .* exp(-(z.^beta));

    sseKWW = nansum((mSel - mHatKWW).^2);
    rmseKWW = sqrt(sseKWW / n);
    sst = nansum((mSel - mean(mSel,'omitnan')).^2);
    r2k = 1 - sseKWW / max(sst, eps);

    % ---------- LOG fit on same window ----------
    % M(t) = M0 - S*log(t) = a + b*log(t), where a=M0, b=-S
    % Need strictly positive time for log model.
    tPos = max(tSel, eps);
    x = log(tPos);

    X = [ones(n,1), x];
    p = X \ mSel;          % least squares
    mHatLOG = X * p;

    M0_log = p(1);
    S_log  = -p(2);

    sseLOG = nansum((mSel - mHatLOG).^2);
    rmseLOG = sqrt(sseLOG / n);
    r2l = 1 - sseLOG / max(sst, eps);

    % AIC (Gaussian residual, unknown variance)
    % AIC = n*log(SSE/n) + 2k
    kKWW = 4;   % Minf, dM, tau, beta (t0 fixed by window)
    kLOG = 2;   % M0, S
    aicK = n*log(max(sseKWW, eps)/n) + 2*kKWW;
    aicL = n*log(max(sseLOG, eps)/n) + 2*kLOG;

    R2_KWW(i)   = r2k;
    R2_LOG(i)   = r2l;
    RMSE_KWW(i) = rmseKWW;
    RMSE_LOG(i) = rmseLOG;
    AIC_KWW(i)  = aicK;
    AIC_LOG(i)  = aicL;
    M0_LOG(i)   = M0_log;
    S_LOG(i)    = S_log;
end

%% Build comparison table
preferred_model = strings(nRows,1);
for i = 1:nRows
    if ~isfinite(AIC_KWW(i)) || ~isfinite(AIC_LOG(i))
        preferred_model(i) = "NA";
    elseif AIC_LOG(i) < AIC_KWW(i)
        preferred_model(i) = "LOG";
    else
        preferred_model(i) = "KWW";
    end
end

modelComparison = table( ...
    Temp_K, R2_KWW, R2_LOG, RMSE_KWW, RMSE_LOG, AIC_KWW, AIC_LOG, preferred_model, ...
    'VariableNames', {'Temp_K','R2_KWW','R2_LOG','RMSE_KWW','RMSE_LOG','AIC_KWW','AIC_LOG','preferred_model'});

modelComparison = sortrows(modelComparison, 'Temp_K');

assignin('base','modelComparison', modelComparison);

fprintf('\n=== Model Comparison Table (sorted by Temp) ===\n');
disp(modelComparison);

%% ------------------------------------------------------------------------
% 3) Diagnostic plots
% -------------------------------------------------------------------------
valid = isfinite(modelComparison.Temp_K) & isfinite(modelComparison.R2_KWW) & ...
        isfinite(modelComparison.R2_LOG) & isfinite(modelComparison.AIC_KWW) & ...
        isfinite(modelComparison.AIC_LOG);

Tc = modelComparison.Temp_K(valid);
R2k = modelComparison.R2_KWW(valid);
R2l = modelComparison.R2_LOG(valid);
AICk = modelComparison.AIC_KWW(valid);
AICl = modelComparison.AIC_LOG(valid);

% A) R2 vs temperature
figR2 = figure('Name','R2: KWW vs LOG','Color','w');
plot(Tc, R2k, 'o-','LineWidth',1.7,'MarkerSize',6,'DisplayName','R2 KWW'); hold on;
plot(Tc, R2l, 's-','LineWidth',1.7,'MarkerSize',6,'DisplayName','R2 LOG');
grid on; box on;
xlabel('Temperature (K)');
ylabel('R^2');
title('Model comparison: R^2 vs Temperature');
legend('Location','best');

% B) AIC vs temperature
figAIC = figure('Name','AIC: KWW vs LOG','Color','w');
plot(Tc, AICk, 'o-','LineWidth',1.7,'MarkerSize',6,'DisplayName','AIC KWW'); hold on;
plot(Tc, AICl, 's-','LineWidth',1.7,'MarkerSize',6,'DisplayName','AIC LOG');
grid on; box on;
xlabel('Temperature (K)');
ylabel('AIC (lower is better)');
title('Model comparison: AIC vs Temperature');
legend('Location','best');

% C) Example overlays (low / mid / high T)
if nnz(valid) >= 3
    idxValid = find(valid);
    idxExamples = unique(round(linspace(1, numel(idxValid), 3)));
    exRows = idxValid(idxExamples);

    figExamples = figure('Name','Example Fits: KWW vs LOG','Color','w');
    tl = tiledlayout(1, numel(exRows), 'TileSpacing','compact', 'Padding','compact'); %#ok<NASGU>

    for ie = 1:numel(exRows)
        ir = exRows(ie);
        Ttarget = modelComparison.Temp_K(ir);

        % find matching row in Treal (temperature and nearest if duplicate temps)
        cand = find(abs(Treal.Temp_K - Ttarget) < 1e-9);
        if isempty(cand)
            cand = findClosestRow(Treal.Temp_K, Ttarget);
        else
            cand = cand(1);
        end

        row = Treal(cand,:);
        idx = row.data_idx;

        t = Time_table{idx};
        m = Moment_table{idx};
        t = t(:); m = m(:);
        ok = isfinite(t) & isfinite(m);
        t = t(ok); m = m(ok);

        t0 = row.t_start; t1 = row.t_end;
        mask = (t >= t0) & (t <= t1);
        tSel = t(mask); mSel = m(mask);

        if isempty(tSel)
            nexttile; axis off; title(sprintf('T=%.2f K (no data)', Ttarget));
            continue;
        end

        % KWW
        z = max(0, (tSel - t0) ./ max(row.tau, eps));
        mKWW = row.Minf + row.dM .* exp(-(z.^row.n));

        % LOG
        x = log(max(tSel, eps));
        X = [ones(numel(x),1), x];
        p = X \ mSel;
        mLOG = X*p;

        nexttile;
        plot(tSel, mSel, 'k.', 'MarkerSize',8, 'DisplayName','Data'); hold on;
        plot(tSel, mKWW, 'r-', 'LineWidth',1.8, 'DisplayName','KWW');
        plot(tSel, mLOG, 'b--', 'LineWidth',1.8, 'DisplayName','LOG');
        grid on; box on;
        xlabel('Time (s)');
        ylabel('M');
        title(sprintf('T=%.2f K', Ttarget));
        if ie == 1
            legend('Location','best');
        end
    end
end

%% ------------------------------------------------------------------------
% 4) Fraction of temperatures where LOG outperforms KWW
% -------------------------------------------------------------------------
validAIC = isfinite(modelComparison.AIC_KWW) & isfinite(modelComparison.AIC_LOG);
if any(validAIC)
    fracLOGbetter = mean(modelComparison.AIC_LOG(validAIC) < modelComparison.AIC_KWW(validAIC));
else
    fracLOGbetter = NaN;
end

fprintf('\n[7] Fraction of temperatures where LOG AIC < KWW AIC: %.3f\n', fracLOGbetter);

%% ------------------------------------------------------------------------
% 5) Interpretation summary
% -------------------------------------------------------------------------
dAIC = modelComparison.AIC_LOG - modelComparison.AIC_KWW;   % <0 => LOG better

nValid = nnz(validAIC);
nLOGbetter = nnz(validAIC & (dAIC < 0));
nKWWbetter = nnz(validAIC & (dAIC > 0));
nTie = nnz(validAIC & abs(dAIC) < 1e-9);

if nValid >= 3
    [rPrefTemp, pPrefTemp] = corr(modelComparison.Temp_K(validAIC), dAIC(validAIC), ...
        'type','Pearson','rows','complete');
else
    rPrefTemp = NaN; pPrefTemp = NaN;
end

fprintf('\n=== Interpretation Summary ===\n');

if nValid == 0
    fprintf('- No valid AIC comparisons available.\n');
else
    fprintf('- Valid temperatures compared: %d\n', nValid);
    fprintf('- LOG better (lower AIC): %d (%.1f%%)\n', nLOGbetter, 100*nLOGbetter/max(nValid,1));
    fprintf('- KWW better (lower AIC): %d (%.1f%%)\n', nKWWbetter, 100*nKWWbetter/max(nValid,1));
    fprintf('- Exact ties: %d\n', nTie);

    if fracLOGbetter > 0.7
        fprintf('- Logarithmic relaxation often outperforms KWW in this dataset.\n');
    elseif fracLOGbetter < 0.3
        fprintf('- KWW often outperforms logarithmic relaxation in this dataset.\n');
    else
        fprintf('- Models are mixed/close; no single model dominates strongly.\n');
    end

    % Rough indistinguishability check: many |dAIC| < 2
    indistFrac = mean(validAIC & (abs(dAIC) < 2));
    fprintf('- Fraction with |ΔAIC|<2 (often statistically close): %.1f%%\n', 100*indistFrac);

    if isfinite(rPrefTemp)
        fprintf('- Temperature dependence of preference (corr Temp vs ΔAIC): r=%.3f, p=%.3g\n', ...
            rPrefTemp, pPrefTemp);
        if abs(rPrefTemp) > 0.5
            fprintf('- Model preference appears temperature dependent.\n');
        else
            fprintf('- Model preference shows weak temperature trend.\n');
        end
    end
end

fprintf('\n(Outputs available in workspace variable: modelComparison)\n');

%% ------------------------------------------------------------------------
% Local helper
% -------------------------------------------------------------------------
function idx = findClosestRow(vec, val)
[~, idx] = min(abs(vec - val));
end
