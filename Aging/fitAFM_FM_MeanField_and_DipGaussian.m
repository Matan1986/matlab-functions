function pauseRuns = fitAFM_FM_MeanField_and_DipGaussian(pauseRuns, dip_window_K, opts)
% fitAFM_FM_MeanField_and_DipGaussian
% ------------------------------------------------------------
% FM component  : Mean-field step model
% Dip component : Gaussian (memory dip)
%
% No toolboxes (fminsearch only)
%
% INPUT expects pauseRuns(i) to contain:
%   .T_common
%   .DeltaM
%   .DeltaM_smooth
%   .DeltaM_sharp
%   .waitK
%
% OUTPUT adds:
%   .FM_MF_params        = [A, Tc, C]
%   .FM_MF_curve
%   .Dip_Gauss_params   = [Adip, T0, sigma]
%   .Dip_Gauss_curve
%   .DeltaM_fit_total
%   .fit_quality.R2 , .SSE
% ------------------------------------------------------------

if nargin < 3 || isempty(opts), opts = struct(); end

% ---------------- defaults ----------------
opts = setDefault(opts,'fitFM',true);
opts = setDefault(opts,'fitDip',true);

opts = setDefault(opts,'excludeLowT_FM',true);
opts = setDefault(opts,'excludeLowT_K',5);

opts = setDefault(opts,'FM_fit_useSmoothComponent',true);
opts = setDefault(opts,'FM_fit_Tmin_extraK',12);
opts = setDefault(opts,'FM_fit_Tmax_extraK',12);

opts = setDefault(opts,'dipFitWindow_K',3*dip_window_K);
opts = setDefault(opts,'useSharpComponentForDip',true);

opts = setDefault(opts,'debugPlots',false);

% ============================================================
for i = 1:numel(pauseRuns)

    T  = pauseRuns(i).T_common(:);
    dM = pauseRuns(i).DeltaM(:);
    Tp = pauseRuns(i).waitK;

    hasComp = isfield(pauseRuns(i),'DeltaM_smooth') && ...
        isfield(pauseRuns(i),'DeltaM_sharp');

    %% =======================================================
    %% (1) FM — Mean Field
    %% =======================================================
    FM_curve  = zeros(size(T));
    FM_params = [NaN NaN NaN];

    if opts.fitFM

        if opts.FM_fit_useSmoothComponent && hasComp
            yFM = pauseRuns(i).DeltaM_smooth(:);
        else
            yFM = dM;
        end

        valid = isfinite(T) & isfinite(yFM);

        if opts.excludeLowT_FM
            valid = valid & (T >= opts.excludeLowT_K);
        end

        % avoid dip region
        valid = valid & abs(T - Tp) > max(1.5*dip_window_K,2);

        % local window
        valid = valid & ...
            T >= Tp - opts.FM_fit_Tmin_extraK & ...
            T <= Tp + opts.FM_fit_Tmax_extraK;

        Tfit = T(valid);
        yfit = yFM(valid);

        if numel(Tfit) >= 8

            C0  = median(yfit);
            A0  = max(yfit) - min(yfit);
            Tc0 = max(Tfit) + 2;

            p0 = [A0, Tc0, C0];

            costFM = @(p) costMeanField(p, Tfit, yfit);
            pFM = fminsearch(costFM, p0, optimset('Display','off'));

            FM_params = sanitizeFM(pFM, Tfit);
            FM_curve  = meanFieldModel(FM_params, T);
        else
            FM_curve  = zeros(size(T));
            FM_params = [0 NaN 0];
        end
    end

    %% =======================================================
    %% (2) Dip — Gaussian
    %% =======================================================
    Dip_curve  = zeros(size(T));
    Dip_params = [NaN NaN NaN];

    if opts.fitDip

        if opts.useSharpComponentForDip && hasComp
            yDip = pauseRuns(i).DeltaM_sharp(:);
        else
            yDip = dM - FM_curve;
        end

        valid = isfinite(T) & isfinite(yDip);
        valid = valid & abs(T - Tp) <= opts.dipFitWindow_K;

        Tfit = T(valid);
        yfit = yDip(valid);

        if numel(Tfit) >= 7

            % ---- scaling (dimensionless fit) ----
            A0 = abs(min(yfit));
            dT = opts.dipFitWindow_K;

            scale.A0 = max(A0, eps);
            scale.dT = dT;

            % p = [A_hat, T0_hat, sigma_hat]
            % A     = A_hat * A0
            % T0    = Tp + T0_hat * dT
            % sigma = sigma_hat * dT
            p0 = [1, 0, 0.25];

            costDip = @(p) costGauss_optimized(p, Tfit, yfit, Tp, scale);

            p_hat = fminsearch(costDip, p0, optimset('Display','off'));

            % ---- decode physical parameters ----
            Ad = p_hat(1) * scale.A0;
            T0 = Tp + p_hat(2) * scale.dT;
            s  = max(p_hat(3) * scale.dT, 0.15);

            Dip_params = [Ad, T0, s];
            Dip_curve  = -Ad * exp(-(T - T0).^2 ./ (2*s.^2));
        end

    end

    %% =======================================================
    %% Store
    %% =======================================================
    pauseRuns(i).FM_MF_params      = FM_params;
    pauseRuns(i).FM_MF_curve       = FM_curve;

    pauseRuns(i).Dip_Gauss_params  = Dip_params;
    pauseRuns(i).Dip_Gauss_curve   = Dip_curve;

    pauseRuns(i).DeltaM_fit_total  = FM_curve + Dip_curve;

    %% quality
    good = isfinite(T) & isfinite(dM);
    y0 = dM(good);
    y1 = pauseRuns(i).DeltaM_fit_total(good);

    SSE = sum((y0 - y1).^2);
    SST = sum((y0 - mean(y0)).^2) + eps;

    pauseRuns(i).fit_quality.SSE = SSE;
    pauseRuns(i).fit_quality.R2  = 1 - SSE/SST;

    %% debug
    if opts.debugPlots
        figure('Color','w'); hold on
        plot(T,dM,'k','LineWidth',1)
        plot(T,FM_curve,'b','LineWidth',2)
        plot(T,Dip_curve,'r','LineWidth',2)
        plot(T,pauseRuns(i).DeltaM_fit_total,'--','LineWidth',2)
        xline(Tp,':k')
        legend('\DeltaM','FM MF','Dip Gaussian','Total','Location','best')
        grid on
    end
end
end

%% ============================================================
%% Helper functions
%% ============================================================

function y = meanFieldModel(p,T)
A  = p(1); Tc = p(2); C = p(3);
x = max(0,1 - T./max(Tc,eps));
y = C + A*sqrt(x);
end

function J = costMeanField(p,T,y)
A=p(1); Tc=p(2);
pen = 0;
if Tc <= min(T)+0.2, pen = 1e6; end
yhat = meanFieldModel(p,T);
J = sum((y-yhat).^2) + pen;
end

function p = sanitizeFM(p,T)
A=p(1); Tc=p(2); C=p(3);
if Tc <= min(T), Tc=min(T)+0.2; end
if ~isfinite(A), A=0; end
if ~isfinite(C), C=0; end
p=[A,Tc,C];
end

% -------- Gaussian dip --------
function y = gaussDipModel(p,T)
Ad=p(1); T0=p(2); s=max(p(3),eps);
y = -Ad*exp(-(T-T0).^2./(2*s.^2));
end

function J = costGauss_optimized(p, T, y, Tp, scale)
% p = [a_hat, t0_hat, s_hat] (dimensionless)
% scale = struct with fields A0, dT

A  = p(1) * scale.A0;
T0 = Tp + p(2) * scale.dT;
s  = p(3) * scale.dT;

yhat = -A * exp(-(T-T0).^2 ./ (2*s.^2));

% ---- FIXED weights (NO sigma feedback!) ----
w0 = 0.6 * scale.dT;
w  = exp(-(T-Tp).^2 ./ (2*w0^2));

res = y - yhat;

pen = 0;

% soft physical constraints
if A < 0
    pen = pen + 1e6*A^2;
end
if abs(T0 - Tp) > 2
    pen = pen + 1e4*(abs(T0-Tp)-2)^2;
end
if s < 0.4
    pen = pen + 1e4*(0.4 - s)^2;
end
if s > 0.8*scale.dT
    pen = pen + 1e4*(s - 0.8*scale.dT)^2;
end

J = sum(w .* res.^2) + pen;

end


function p = sanitizeGauss(p,T)
Ad=p(1); T0=p(2); s=p(3);
if Ad<0, Ad=abs(Ad); end
if s<=0, s=0.5; end
T0=min(max(T0,min(T)),max(T));
p=[Ad,T0,s];
end

