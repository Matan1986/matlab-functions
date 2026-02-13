function pauseRuns = fitFMstep_plus_GaussianDip(pauseRuns, dip_window_K, opts)
% fitFMstep_plus_GaussianDip  (deterministic + fast + data-driven p0)
% ------------------------------------------------------------
% Simultaneous fit of:
%   FM-like background  = step (tanh) + small slope
%   Memory dip          = Gaussian
%
% Fit is done on RAW DeltaM over a wide window around Tp.
% No toolboxes.
%
% OUTPUT (per pauseRuns(i)):
%   .FM_step_A      = 2*|A_step|   (full step magnitude)
%   .Dip_A          = A_dip
%   .Dip_sigma
%   .Dip_T0
%   .fit_R2
%   .fit_RMSE
%   .fit_NRMSE
%   .fit_chi2_red
%   .fit_curve
%
% Also stores optional component metrics:
%   .FM_A, .FM_area_abs, .FM_E
%   .Dip_area, .Dip_E
% ------------------------------------------------------------

if nargin < 3, opts = struct(); end
opts = setDefault(opts,'windowFactor',4);
opts = setDefault(opts,'minWindow_K',25);
opts = setDefault(opts,'debugPlots',false);

% --- speed / robustness knobs ---
opts = setDefault(opts,'MaxIter',600);
opts = setDefault(opts,'MaxFunEvals',4000);
opts = setDefault(opts,'multiStart','small');   % 'none' | 'small' | 'medium'
opts = setDefault(opts,'useDataDrivenP0',true);

% --- debug plot cosmetics ---
opts = setDefault(opts,'plotFontSize',14);
opts = setDefault(opts,'plotLineWidth',2.2);
opts = setDefault(opts,'plotDataLineWidth',1.6);

% deterministic multi-start scales
switch lower(string(opts.multiStart))
    case "none"
        AstepSc = 1;  AdipSc = 1;  wSc = 1;    sigSc = 1;    dT0_K = 0;
    case "medium"
        AstepSc = [0.85 1.00 1.15];
        AdipSc  = [0.85 1.00 1.15];
        wSc     = [0.80 1.00 1.25];
        sigSc   = [0.80 1.00 1.25];
        dT0_K   = [-0.4 0 0.4];
    otherwise % "small"
        AstepSc = [0.90 1.10];
        AdipSc  = [0.90 1.10];
        wSc     = [0.85 1.15];
        sigSc   = [0.85 1.15];
        dT0_K   = [-0.3 0 0.3];
end

for i = 1:numel(pauseRuns)

    T  = pauseRuns(i).T_common(:);
    y  = pauseRuns(i).DeltaM(:);
    Tp = pauseRuns(i).waitK;

    % -------- wide fit window --------
    W = max(opts.minWindow_K, opts.windowFactor * dip_window_K);
    use = abs(T - Tp) <= W & isfinite(y);

    Tfit = T(use);
    yfit = y(use);

    if numel(Tfit) < 20
        warning('Pause %.1f K: not enough points for fit.', Tp);
        continue;
    end

    % -------- scaling --------
    yScale = max(abs(yfit));
    if ~isfinite(yScale) || yScale == 0
        warning('Pause %.1f K: yScale invalid.', Tp);
        continue;
    end
    tScale = W;

    % -------- build initial guess p0 --------
    % p = [C, m, Astep, w_hat, Adip, T0_hat, sigma_hat]
    if opts.useDataDrivenP0
        p0 = build_p0_from_data(Tfit, yfit, Tp, W, dip_window_K, yScale, tScale);
    else
        p0 = [0, 0, 0.3*yScale, 0.3, 0.5*yScale, 0, 0.15];
    end

    cost = @(p) cost_step_gauss(p, Tfit, yfit, Tp, yScale, tScale);

    bestJ = inf;
    bestP = [];

    opt = optimset('Display','off', ...
        'MaxIter',opts.MaxIter, ...
        'MaxFunEvals',opts.MaxFunEvals);

    % -------- deterministic multi-start --------
    for a = AstepSc
        for d = AdipSc
            for ww = wSc
                for ss = sigSc
                    for dT = dT0_K

                        p0_try = p0;
                        p0_try(3) = p0(3) * a;
                        p0_try(5) = max(eps, p0(5) * d);
                        p0_try(4) = max(0.5/tScale, p0(4) * ww);
                        p0_try(7) = max(0.4/tScale, p0(7) * ss);
                        p0_try(6) = p0(6) + dT / tScale;

                        p_try = fminsearch(cost, p0_try, opt);
                        J_try = cost(p_try);

                        if isfinite(J_try) && J_try < bestJ
                            bestJ = J_try;
                            bestP = p_try;
                        end
                    end
                end
            end
        end
    end

    if isempty(bestP)
        p = p0;
    else
        p = bestP;
    end

    % -------- decode --------
    C     = p(1);
    m     = p(2);
    Astep = p(3);
    w     = max(p(4)*tScale, 0.5);
    Adip  = abs(p(5));
    T0    = Tp + p(6)*tScale;
    sigma = max(p(7)*tScale, 0.4);


    % -------- curves --------
    bg   = C + m*(T-Tp) + Astep*tanh((T-Tp)/w);
    dip  = -Adip*exp(-(T-T0).^2/(2*sigma^2));
    fitY = bg + dip;

    % -------- optional component metrics (fit window) --------
    useWin = abs(T - Tp) <= W & isfinite(y);
    Twin = T(useWin);

    stepWin = Astep * tanh((Twin - Tp)/w);
    dipWin  = -Adip * exp(-(Twin - T0).^2/(2*sigma^2));

    stepAC = stepWin - mean(stepWin,'omitnan');

    pauseRuns(i).FM_area_abs = trapz(Twin, abs(stepWin));
    pauseRuns(i).FM_E        = sqrt(mean(stepAC.^2,'omitnan'));
    pauseRuns(i).Dip_E       = sqrt(mean(dipWin.^2,'omitnan'));


    % -------- quality metrics (fit window only) --------
    yhat_fit = C + m*(Tfit-Tp) + Astep*tanh((Tfit-Tp)/w) ...
        - Adip*exp(-(Tfit-T0).^2/(2*sigma^2));

    res = yfit - yhat_fit;

    R2 = 1 - sum(res.^2) / (sum((yfit-mean(yfit,'omitnan')).^2) + eps);

    N = numel(yfit);
    P = 7;

    RMSE  = sqrt(mean(res.^2,'omitnan'));
    NRMSE = RMSE / (max(yfit) - min(yfit) + eps);
    chi2_red = sum(res.^2,'omitnan') / max(N - P, 1);

    % -------- store quality --------
    pauseRuns(i).fit_R2       = R2;
    pauseRuns(i).fit_RMSE     = RMSE;
    pauseRuns(i).fit_NRMSE    = NRMSE;
    pauseRuns(i).fit_chi2_red = chi2_red;

    % -------- store --------
    pauseRuns(i).FM_step_A = 2*abs(Astep);
    pauseRuns(i).Dip_A     = Adip;
    pauseRuns(i).Dip_sigma = sigma;
    pauseRuns(i).Dip_T0    = T0;
    pauseRuns(i).fit_curve = fitY;
    % optional component metrics (keep header consistent)
    pauseRuns(i).FM_A     = 2*abs(Astep);
    pauseRuns(i).Dip_area = Adip * sqrt(2*pi) * sigma;
    % =========================================================
    % Debug plots
    % =========================================================
    if opts.debugPlots

        figName = sprintf('Fit: FM + Gaussian | Tp=%.1f K | W=%.0f K', Tp, W);
        figure('Color','w','Name',figName,'NumberTitle','off');
        ax = axes; hold(ax,'on');

        set(ax,'FontSize',opts.plotFontSize,'Box','on','TickDir','out');
        grid(ax,'on');

        colData = [0 0 0];
        colBG   = [0.00 0.45 0.74];
        colDip  = [0.85 0.33 0.10];
        colTot  = [0.13 0.55 0.13];

        plot(ax, T, y, '-', 'Color',colData, ...
            'LineWidth',opts.plotDataLineWidth);

        plot(ax, T, bg, '-', 'Color',colBG, ...
            'LineWidth',opts.plotLineWidth+0.8);

        plot(ax, T, dip, '-', 'Color',colDip, ...
            'LineWidth',opts.plotLineWidth+0.8);

        plot(ax, T, fitY, '--', 'Color',colTot, ...
            'LineWidth',opts.plotLineWidth+1.6);

        xline(ax, Tp, ':k','Tp');

        xmin = max(0, Tp - W);
        xmax = Tp + W;
        xlim(ax,[0 45]);

        xlabel(ax,'T (K)');
        ylabel(ax,'\DeltaM (arb.)');

        legend(ax, {'\DeltaM','FM background','Gaussian dip','Total fit'}, ...
            'Location','best','Box','off');

        txt = {
            sprintf('A_{FM} = %.3g', 2*abs(Astep))
            sprintf('A_{dip} = %.3g', Adip)
            sprintf('\\sigma = %.2f K', sigma)
            sprintf('T_0 = %.2f K', T0)
            ''
            sprintf('R^2 = %.3f', R2)
            sprintf('NRMSE = %.3f', NRMSE)
            sprintf('\\chi^2_{red} = %.3g', chi2_red)
            };

        text(ax, 0.98, 0.96, txt, ...
            'Units','normalized', ...
            'HorizontalAlignment','right', ...
            'VerticalAlignment','top', ...
            'FontSize',opts.plotFontSize-2, ...
            'BackgroundColor','w', ...
            'EdgeColor',[0.75 0.75 0.75], ...
            'Margin',6);

    end
end
end

% ============================================================
function J = cost_step_gauss(p,T,y,Tp,yS,tS)

C=p(1); m=p(2); A=p(3);
w  = max(p(4)*tS,0.5);
Ad = abs(p(5));
T0 = Tp + p(6)*tS;
s  = max(p(7)*tS,0.4);

yhat = C + m*(T-Tp) + A*tanh((T-Tp)/w) ...
    - Ad*exp(-(T-T0).^2/(2*s^2));

res = y - yhat;

pen = 0;
if s > 0.6*tS, pen = pen + 1e4*(s-0.6*tS)^2; end
if abs(T0-Tp) > 2, pen = pen + 1e4*(abs(T0-Tp)-2)^2; end

J = sum(res.^2)/(yS^2) + pen;
end

% ============================================================
function p0 = build_p0_from_data(Tfit, yfit, Tp, W, dip_window_K, yScale, tScale)

edgeMask = abs(Tfit - Tp) > 0.6*W;
if nnz(edgeMask) < 10, edgeMask = true(size(Tfit)); end
pp = polyfit(Tfit(edgeMask)-Tp, yfit(edgeMask),1);

m0 = pp(1);
C0 = pp(2);

dipMask = abs(Tfit-Tp) <= max(dip_window_K,2);
Tlocal = Tfit(dipMask);
ylocal = yfit(dipMask);
[~,kmin] = min(ylocal);

T0_init = Tlocal(kmin);
ybg0 = C0 + m0*(T0_init-Tp);
Adip0 = max(0.2*yScale, ybg0-ylocal(kmin));

sigma0 = max(0.8, 0.08*W);
w0     = max(0.8, 0.08*W);

p0 = [C0, m0, 0.2*yScale, w0/tScale, Adip0, ...
    (T0_init-Tp)/tScale, sigma0/tScale];
end

% ============================================================
function opts = setDefault(opts,f,v)
if ~isfield(opts,f), opts.(f)=v; end
end
