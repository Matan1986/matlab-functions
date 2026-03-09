%% diagnose_tau_beta_degeneracy
% Diagnostics-only audit for KWW parameter identifiability in Relaxation ver3.
%
% REQUIRED IN WORKSPACE:
%   allFits      - results table from fitAllRelaxations
%   Time_table   - cell array of time vectors
%   Moment_table - cell array of moment vectors
%
% This script does NOT modify existing pipeline behavior or overwrite results.

fprintf('\n=== Tau-Beta Degeneracy Diagnostics (KWW) ===\n');

%% ------------------------------------------------------------------------
% 0) Input validation
% -------------------------------------------------------------------------
if ~exist('allFits','var') || isempty(allFits)
    error('diagnose_tau_beta_degeneracy:MissingAllFits', ...
        'allFits not found in workspace. Run main_relaxation first.');
end
if ~exist('Time_table','var') || isempty(Time_table)
    error('diagnose_tau_beta_degeneracy:MissingTimeTable', ...
        'Time_table not found in workspace. Run main_relaxation first.');
end
if ~exist('Moment_table','var') || isempty(Moment_table)
    error('diagnose_tau_beta_degeneracy:MissingMomentTable', ...
        'Moment_table not found in workspace. Run main_relaxation first.');
end

if isstruct(allFits)
    allFitsTbl = struct2table(allFits);
else
    allFitsTbl = allFits;
end

requiredCols = {'Temp_K','Minf','dM','tau','n','R2','t_start','t_end','data_idx'};
for k = 1:numel(requiredCols)
    if ~ismember(requiredCols{k}, allFitsTbl.Properties.VariableNames)
        error('diagnose_tau_beta_degeneracy:MissingColumn', ...
            'Required column missing in allFits: %s', requiredCols{k});
    end
end

%% ------------------------------------------------------------------------
% 1) Keep only real fits (exclude fallback tau=Inf)
% -------------------------------------------------------------------------
isRealFit = isfinite(allFitsTbl.tau) & (allFitsTbl.tau < Inf) & ...
            isfinite(allFitsTbl.n) & isfinite(allFitsTbl.Temp_K) & ...
            isfinite(allFitsTbl.R2) & isfinite(allFitsTbl.Minf) & ...
            isfinite(allFitsTbl.dM);

fits = allFitsTbl(isRealFit, :);

fprintf('Total rows in allFits: %d\n', height(allFitsTbl));
fprintf('Real-fit rows (tau finite): %d\n', height(fits));

if height(fits) < 3
    error('diagnose_tau_beta_degeneracy:TooFewFits', ...
        'Need at least 3 real-fit rows (tau finite) for diagnostics.');
end

%% ------------------------------------------------------------------------
% 2) Pearson correlation: tau vs beta
% -------------------------------------------------------------------------
[rTauBeta, pTauBeta] = corr(fits.tau, fits.n, 'type','Pearson', 'rows','complete');

fprintf('\n[2] Pearson corr(tau, beta): r = %.4f, p = %.3g (N=%d)\n', ...
    rTauBeta, pTauBeta, height(fits));

%% ------------------------------------------------------------------------
% 3) Scatter plot beta vs tau with annotation
% -------------------------------------------------------------------------
figScatter = figure('Name','Tau-Beta Scatter (Real Fits)','Color','w');
scatter(fits.tau, fits.n, 65, fits.Temp_K, 'filled');
cb = colorbar;
cb.Label.String = 'Temp (K)';
set(gca, 'XScale','log');
grid on; box on;
xlabel('\tau (s) [log scale]');
ylabel('\beta (n)');
title('KWW diagnostics: \beta vs \tau (real fits only)');
text(0.02, 0.98, sprintf('r_{\\tau,\\beta}=%.3f  (p=%.2g)', rTauBeta, pTauBeta), ...
    'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', ...
    'FontWeight','bold', 'BackgroundColor','w', 'Margin',4);

%% ------------------------------------------------------------------------
% 4) Tau variability across temperature
% -------------------------------------------------------------------------
meanTau = mean(fits.tau, 'omitnan');
stdTau  = std(fits.tau, 'omitnan');
relTauVar = stdTau / max(abs(meanTau), eps);

fprintf('[4] tau mean = %.6g s, std = %.6g s, rel std/mean = %.4f\n', ...
    meanTau, stdTau, relTauVar);

%% ------------------------------------------------------------------------
% 5) Tau vs temperature systematic trend
% -------------------------------------------------------------------------
[rTauTemp, pTauTemp] = corr(fits.tau, fits.Temp_K, 'type','Pearson', 'rows','complete');

fprintf('[5] Pearson corr(tau, Temp_K): r = %.4f, p = %.3g\n', rTauTemp, pTauTemp);

figTauTemp = figure('Name','Tau vs Temperature (Real Fits)','Color','w');
plot(fits.Temp_K, fits.tau, 'o-', 'LineWidth',1.5, 'MarkerSize',6);
set(gca, 'YScale','log');
grid on; box on;
xlabel('Temperature (K)');
ylabel('\tau (s) [log scale]');
title('\tau vs Temperature (real fits only)');
text(0.02, 0.98, sprintf('r_{\\tau,T}=%.3f  (p=%.2g)', rTauTemp, pTauTemp), ...
    'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', ...
    'FontWeight','bold', 'BackgroundColor','w', 'Margin',4);

%% ------------------------------------------------------------------------
% 6) Error-surface scan for tau-beta tradeoff at representative temperatures
% -------------------------------------------------------------------------
fitsSorted = sortrows(fits, 'Temp_K');
nRep = min(3, height(fitsSorted));
idxRep = unique(round(linspace(1, height(fitsSorted), nRep)));
repRows = fitsSorted(idxRep, :);

figContours = figure('Name','Tau-Beta Error Surfaces','Color','w');
tl = tiledlayout(1, numel(idxRep), 'TileSpacing','compact', 'Padding','compact'); %#ok<NASGU>

valleyFlags = false(numel(idxRep),1);
valleyRatios = NaN(numel(idxRep),1);
valleyAreaFrac = NaN(numel(idxRep),1);

for iRep = 1:numel(idxRep)
    r = repRows(iRep,:);
    idxData = r.data_idx;

    if idxData < 1 || idxData > numel(Time_table) || idxData > numel(Moment_table)
        nexttile;
        axis off;
        title(sprintf('T=%.2f K (invalid data_idx)', r.Temp_K));
        continue;
    end

    t = Time_table{idxData};
    m = Moment_table{idxData};
    if isempty(t) || isempty(m)
        nexttile;
        axis off;
        title(sprintf('T=%.2f K (empty data)', r.Temp_K));
        continue;
    end

    t = t(:); m = m(:);
    ok = isfinite(t) & isfinite(m);
    t = t(ok); m = m(ok);

    t0 = r.t_start;
    t1 = r.t_end;
    Minf = r.Minf;
    dM = r.dM;
    tau0 = r.tau;

    mask = (t >= t0) & (t <= t1);
    tSel = t(mask);
    mSel = m(mask);

    if numel(tSel) < 10 || ~isfinite(tau0) || tau0 <= 0 || abs(dM) < eps
        nexttile;
        axis off;
        title(sprintf('T=%.2f K (insufficient fit window)', r.Temp_K));
        continue;
    end

    tauGrid = linspace(0.5*tau0, 2.0*tau0, 61);
    betaGrid = linspace(0.3, 0.8, 61);
    SSE = NaN(numel(betaGrid), numel(tauGrid));

    for ib = 1:numel(betaGrid)
        beta = betaGrid(ib);
        for it = 1:numel(tauGrid)
            tau = tauGrid(it);
            z = max(0, (tSel - t0) ./ max(tau, eps));
            mHat = Minf + dM .* exp(-(z.^beta));
            res = mSel - mHat;
            SSE(ib,it) = nansum(res.^2);
        end
    end

    minSSE = min(SSE(:));
    relSSE = SSE ./ max(minSSE, eps);

    % Valley diagnostics on near-optimal basin (within +2%)
    nearMinMask = relSSE <= 1.02;
    valleyAreaFrac(iRep) = nnz(nearMinMask) / numel(nearMinMask);

    [tauMesh, betaMesh] = meshgrid(tauGrid, betaGrid);
    tauPts = tauMesh(nearMinMask);
    betaPts = betaMesh(nearMinMask);

    if numel(tauPts) > 5
        X = [log10(tauPts(:)), betaPts(:)];
        C = cov(X);
        ev = eig(C);
        ev = sort(ev,'descend');
        if numel(ev) >= 2 && ev(2) > 0
            valleyRatios(iRep) = ev(1)/ev(2);
        end
    end

    valleyFlags(iRep) = isfinite(valleyRatios(iRep)) && (valleyRatios(iRep) > 10);

    nexttile;
    contourf(tauGrid, betaGrid, log10(relSSE), 20, 'LineColor','none');
    hold on;
    plot(tau0, r.n, 'wo', 'MarkerFaceColor','k', 'MarkerSize',6);
    set(gca,'XScale','log');
    xlabel('\tau (s)');
    ylabel('\beta');
    title(sprintf('T=%.2f K', r.Temp_K));
    cbh = colorbar;
    cbh.Label.String = 'log_{10}(SSE / SSE_{min})';
    grid on; box on;

    txt = sprintf('valley ratio=%.2f\nnear-min area=%.1f%%', ...
        valleyRatios(iRep), 100*valleyAreaFrac(iRep));
    text(0.03,0.97,txt,'Units','normalized','VerticalAlignment','top', ...
        'BackgroundColor','w','Margin',3);
end

%% ------------------------------------------------------------------------
% 7) Concise interpretation
% -------------------------------------------------------------------------
isStrongTauBetaCorr = isfinite(rTauBeta) && abs(rTauBeta) >= 0.7;
hasValley = any(valleyFlags);

if hasValley
    tauConstraintMsg = 'tau appears weakly constrained for at least part of the dataset (elongated valley detected).';
else
    tauConstraintMsg = 'tau appears reasonably constrained in tested representative slices (no strong elongated valley detected).';
end

if isStrongTauBetaCorr || hasValley
    physicalMsg = 'Interpret tau and beta with caution: potential tradeoff/degeneracy may reduce unique physical identifiability.';
else
    physicalMsg = 'tau and beta appear reasonably identifiable in this diagnostic pass; parameters are likely physically interpretable.';
end

fprintf('\n=== Interpretation ===\n');
fprintf('A) tau-beta correlation strong? %s  (r=%.3f, p=%.2g)\n', tf2yn(isStrongTauBetaCorr), rTauBeta, pTauBeta);
fprintf('B) Is tau constrained by data? %s\n', tauConstraintMsg);
fprintf('C) Physical meaningfulness: %s\n', physicalMsg);

fprintf('\nRepresentative temperatures tested (K): ');
fprintf('%.2f ', repRows.Temp_K);
fprintf('\nValley ratios: ');
fprintf('%.2f ', valleyRatios);
fprintf('\nNear-min basin area fraction (%%): ');
fprintf('%.1f ', 100*valleyAreaFrac);
fprintf('\n');

%% ------------------------------------------------------------------------
% Helper
% -------------------------------------------------------------------------
function out = tf2yn(tf)
if tf
    out = 'YES';
else
    out = 'NO';
end
end
