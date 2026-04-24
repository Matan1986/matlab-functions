function pauseRuns = fitAFM_FM_MeanField_and_DipLorentzian(pauseRuns, dip_window_K, opts)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Legacy standalone fit method (mean-field FM + Lorentzian dip).
%
% DECOMPOSITION TYPE:
% LEGACY
%
% STAGE:
% other
%
% DOES:
% - fit mean-field FM background and Lorentzian dip components
% - produce DeltaM_fit_total and legacy fit parameter fields
%
% DOES NOT:
% - participate in Main_Aging default pipeline routing
% - define default stage6 AFM_like / FM_like observables
%
% AFFECTS SUMMARY OBSERVABLES:
% NO
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
% fitAFM_FM_MeanField_and_DipLorentzian
% ------------------------------------------------------------
% Adds a NEW fitting layer:
%   (1) FM component (smooth/background)  -> Mean-field step-like model
%   (2) Dip component (sharp/memory dip)  -> Lorentzian around Tp
%
% Toolboxes: NONE (uses fminsearch)
%
% Expected fields in pauseRuns(i):
%   .T_common, .DeltaM
%   .DeltaM_smooth, .DeltaM_sharp   (from analyzeAFM_FM_components)
%   .waitK  (pause temperature)
%
% Writes back fields:
%   .FM_MF_params        = [A, Tc, C]
%   .FM_MF_curve         (vector over T_common)
%   .Dip_Lor_params      = [Adip, T0, gamma]
%   .Dip_Lor_curve
%   .DeltaM_fit_total    = FM + Dip
%   .fit_quality         struct with SSE/R2 (optional)
% ------------------------------------------------------------

if nargin < 3 || isempty(opts), opts = struct(); end

% ---- defaults ----
opts = setDefault(opts,'fitFM',true);
opts = setDefault(opts,'fitDip',true);

opts = setDefault(opts,'excludeLowT_FM',true);
opts = setDefault(opts,'excludeLowT_K',5);

opts = setDefault(opts,'FM_fit_useSmoothComponent',true);
opts = setDefault(opts,'FM_fit_Tmax_extraK',12);
opts = setDefault(opts,'FM_fit_Tmin_extraK',12);

opts = setDefault(opts,'dipFitWindow_K',3*dip_window_K);
opts = setDefault(opts,'useSharpComponentForDip',true);

opts = setDefault(opts,'debugPlots',false);

for i = 1:numel(pauseRuns)

    if ~isfield(pauseRuns(i),'T_common') || ~isfield(pauseRuns(i),'DeltaM')
        warning('pauseRuns(%d) missing T_common/DeltaM. Skipping.', i);
        continue;
    end

    T  = pauseRuns(i).T_common(:);
    dM = pauseRuns(i).DeltaM(:);

    Tp = NaN;
    if isfield(pauseRuns(i),'waitK') && ~isempty(pauseRuns(i).waitK)
        Tp = pauseRuns(i).waitK;
    end

    % Make sure we have components
    hasComponents = isfield(pauseRuns(i),'DeltaM_smooth') && isfield(pauseRuns(i),'DeltaM_sharp');

    % -------------------------------
    % (A) Fit FM by Mean-Field model
    % -------------------------------
    % [LEGACY]
    FM_curve = zeros(size(T));
    FM_params = [NaN NaN NaN];

    if opts.fitFM

        if opts.FM_fit_useSmoothComponent && hasComponents
            yFM = pauseRuns(i).DeltaM_smooth(:);
        else
            yFM = dM;
        end

        valid = isfinite(T) & isfinite(yFM);

        % Exclude low T if requested
        if opts.excludeLowT_FM
            valid = valid & (T >= opts.excludeLowT_K);
        end

        % Define a "reasonable" fit window around Tp (if Tp exists)
        if isfinite(Tp)
            % exclude immediate dip vicinity to prevent dip leakage into FM fit
            % (use dip_window_K and FM buffers already baked into your decomposition,
            %  but still keep a safety exclusion around Tp)
            dipExcl = (abs(T - Tp) <= max(1.5*dip_window_K, 2));
            valid = valid & ~dipExcl;

            TminFit = max(min(T(valid)), Tp - opts.FM_fit_Tmin_extraK);
            TmaxFit = min(max(T(valid)), Tp + opts.FM_fit_Tmax_extraK);
            valid   = valid & (T >= TminFit) & (T <= TmaxFit);
        end

        Tfit = T(valid);
        yfit = yFM(valid);

        if numel(Tfit) >= 8
            % Initial guesses
            C0  = median(yfit);
            % Rough amplitude from dynamic range
            A0  = max(yfit) - min(yfit);
            if A0 == 0, A0 = std(yfit) + eps; end

            % Tc guess: slightly above max T in window (step ends near Tc)
            Tc0 = max(Tfit) + 2;

            p0  = [A0, Tc0, C0];

            % Fit with fminsearch (penalized to keep Tc in range)
            costFM = @(p) costMeanField(p, Tfit, yfit);

            pFM = fminsearch(costFM, p0, optimset('Display','off'));

            FM_params = sanitizeFMparams(pFM, Tfit);

            FM_curve = meanFieldModel(FM_params, T);

        else
            % Not enough points, fallback to "flat" FM
            FM_params = [0, NaN, nanmedian(yfit)];
            FM_curve  = FM_params(3) * ones(size(T));
        end
    end

    % -------------------------------
    % (B) Fit dip by Lorentzian
    % -------------------------------
    % [LEGACY]
    Dip_curve  = zeros(size(T));
    Dip_params = [NaN NaN NaN];

    if opts.fitDip

        if opts.useSharpComponentForDip && hasComponents
            yDip = pauseRuns(i).DeltaM_sharp(:);
        else
            % If no sharp component, try removing FM estimate from total
            yDip = dM - FM_curve;
        end

        validDip = isfinite(T) & isfinite(yDip);

        if opts.excludeLowT_FM
            validDip = validDip & (T >= opts.excludeLowT_K);
        end

        if isfinite(Tp)
            validDip = validDip & (abs(T - Tp) <= opts.dipFitWindow_K);
        end

        TfitD = T(validDip);
        yfitD = yDip(validDip);

        if numel(TfitD) >= 7
            % Initial guesses
            [ymin, idxMin] = min(yfitD);
            T0 = TfitD(idxMin);

            Ad0 = abs(ymin);           % dip depth
            if Ad0 == 0, Ad0 = std(yfitD) + eps; end

            gamma0 = max(0.6, 0.25*opts.dipFitWindow_K);

            p0D = [Ad0, T0, gamma0];

            costDip = @(p) costLorentz(p, TfitD, yfitD);

            pD = fminsearch(costDip, p0D, optimset('Display','off'));

            Dip_params = sanitizeDipparams(pD, TfitD);

            Dip_curve  = lorentzDipModel(Dip_params, T);

        else
            Dip_params = [0, Tp, NaN];
            Dip_curve  = zeros(size(T));
        end
    end

    % -------------------------------
    % Combine
    % -------------------------------
    pauseRuns(i).FM_MF_params = FM_params;          % [A, Tc, C]
    pauseRuns(i).FM_MF_curve  = FM_curve;

    pauseRuns(i).Dip_Lor_params = Dip_params;      % [Adip, T0, gamma]
    pauseRuns(i).Dip_Lor_curve  = Dip_curve;

    pauseRuns(i).DeltaM_fit_total = FM_curve + Dip_curve;

    % Quality metrics (optional)
    good = isfinite(T) & isfinite(dM);
    y0 = dM(good);
    yhat = pauseRuns(i).DeltaM_fit_total(good);
    pauseRuns(i).fit_quality = struct();
    if numel(y0) >= 5
        SSE = sum((y0 - yhat).^2);
        SST = sum((y0 - mean(y0)).^2) + eps;
        R2  = 1 - SSE/SST;
        pauseRuns(i).fit_quality.SSE = SSE;
        pauseRuns(i).fit_quality.R2  = R2;
    else
        pauseRuns(i).fit_quality.SSE = NaN;
        pauseRuns(i).fit_quality.R2  = NaN;
    end

    if opts.debugPlots
        figure('Color','w','Name',sprintf('MF+Lor fit (pause %.1fK)',Tp)); hold on;
        plot(T, dM, 'k-', 'LineWidth', 1.2);
        plot(T, FM_curve, '-', 'LineWidth', 1.8);
        plot(T, Dip_curve, '-', 'LineWidth', 1.8);
        plot(T, pauseRuns(i).DeltaM_fit_total, '--', 'LineWidth', 2.0);
        xlabel('T (K)'); ylabel('\DeltaM');
        legend('\DeltaM','FM MF fit','Dip Lor fit','Total fit','Location','best');
        grid on;
    end

end

end

% ================== helpers ==================


% ---- Mean-field model: C + A*sqrt(1 - T/Tc) below Tc, else C
function y = meanFieldModel(p, T)
A  = p(1);
Tc = p(2);
C  = p(3);

x = 1 - (T./max(Tc, eps));
x = max(x, 0);
y = C + A*sqrt(x);
% For T > Tc, sqrt(x)=0 -> y=C
end

function J = costMeanField(p, T, y)
% Penalize unphysical parameters softly
A  = p(1);
Tc = p(2);
C  = p(3);

% Enforce Tc > min(T) + small margin
Tmin = min(T);
Tmax = max(T);

pen = 0;

if ~isfinite(Tc) || Tc <= Tmin + 0.2
    pen = pen + 1e6*(Tmin + 0.2 - Tc)^2;
end
if Tc > Tmax + 50
    pen = pen + 1e4*(Tc - (Tmax + 50))^2;
end
if ~isfinite(A) || ~isfinite(C)
    pen = pen + 1e8;
end

yhat = meanFieldModel([A,Tc,C], T);
res  = y - yhat;

J = sum(res.^2) + pen;
end

function p = sanitizeFMparams(p, Tfit)
% Keep Tc in a sensible range post-fit
A  = p(1);
Tc = p(2);
C  = p(3);

Tmin = min(Tfit);
Tmax = max(Tfit);

if ~isfinite(Tc) || Tc <= Tmin + 0.2
    Tc = Tmin + 0.2;
end
if Tc > Tmax + 50
    Tc = Tmax + 50;
end

if ~isfinite(A), A = 0; end
if ~isfinite(C), C = median(Tfit)*0; end %#ok<NASGU> (dummy safeguard)
p = [A, Tc, p(3)];
end

% ---- Lorentzian dip: -Adip * gamma^2 / ((T-T0)^2 + gamma^2)
function y = lorentzDipModel(p, T)
Ad = p(1);
T0 = p(2);
g  = max(p(3), eps);

y = -Ad * (g.^2) ./ ((T - T0).^2 + g.^2);
end

function J = costLorentz(p, T, y)
Ad = p(1);
T0 = p(2);
g  = p(3);

pen = 0;
if ~isfinite(Ad) || Ad < 0
    pen = pen + 1e6*(min(0,Ad))^2 + 1e6*(~isfinite(Ad));
end
if ~isfinite(g) || g <= 0
    pen = pen + 1e6*(0.1 - g)^2 + 1e6*(~isfinite(g));
end

% T0 within range (soft)
Tmin = min(T); Tmax = max(T);
if ~isfinite(T0)
    pen = pen + 1e8;
elseif T0 < Tmin - 2
    pen = pen + 1e4*(Tmin - 2 - T0)^2;
elseif T0 > Tmax + 2
    pen = pen + 1e4*(T0 - (Tmax + 2))^2;
end

yhat = lorentzDipModel([Ad,T0,g], T);
res  = y - yhat;

J = sum(res.^2) + pen;
end

function p = sanitizeDipparams(p, Tfit)
Ad = p(1);
T0 = p(2);
g  = p(3);

if ~isfinite(Ad) || Ad < 0, Ad = abs(Ad); end
if ~isfinite(g)  || g <= 0,  g = 0.5; end

Tmin = min(Tfit); Tmax = max(Tfit);
if ~isfinite(T0), T0 = (Tmin+Tmax)/2; end
T0 = min(max(T0, Tmin-2), Tmax+2);

p = [Ad, T0, g];
end
