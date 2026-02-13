function [pars, R2, stats] = fitStretchedExp(t, M, T, debug, params)
% fitStretchedExp — flexible stretched-exponential fit
%
% Controlled entirely by external parameters (params struct)

if nargin < 4, debug = false; end
if nargin < 5, params = struct(); end

%% --- Default params if missing ---
params = setDefault(params, 'betaBoost', false);
params = setDefault(params, 'tauBoost', false);
params = setDefault(params, 'timeWeight', false);
params = setDefault(params, 'lowT_only', false);
params = setDefault(params, 'lowT_threshold', 20);
params = setDefault(params, 'timeWeightFactor', 4);

%% --- Clean input ---
t = t(:); M = M(:);
ok = isfinite(t) & isfinite(M);
t = t(ok); M = M(ok);
if numel(t) < 10
    pars = emptyPars(); R2 = NaN; stats = struct();
    return;
end

%% --- Normalize time ---
tmin = min(t);
dt   = max(eps, max(t) - tmin);
tn   = (t - tmin) / dt;

%% --- Base initial guesses ---
Minf0 = median(M(max(1,end-5):end),'omitnan');
dM0   = M(1) - Minf0;
tau0n = 0.3;
beta0 = 0.6;

%% --- Determine if special modes apply ---
applyBoost = true;
if params.lowT_only
    applyBoost = (~isnan(T) && T <= params.lowT_threshold);
end

%% --- Apply optional boosts ---
if params.betaBoost && applyBoost
    beta0 = 0.9;
end

if params.tauBoost && applyBoost
    tau0n = 0.6;
end

x0 = [Minf0, dM0, tau0n, beta0];

%% --- Core model ---
model_core = @(x,xdata) x(1) + x(2).*exp(-(xdata./x(3)).^x(4));

%% --- Bounds ---
lb = [-Inf, -Inf, 0.01, 0.10];
ub = [ Inf,  Inf, 10.00, 1.30];

%% --- Weighting if requested ---
if params.timeWeight && applyBoost
    w      = 1 + params.timeWeightFactor * (1 - tn);  % stronger weight at early times
    w_sqrt = sqrt(w);
    model  = @(x,xdata) w_sqrt .* model_core(x,xdata);
    ydata  = w_sqrt .* M;
else
    model  = @(x,xdata) model_core(x,xdata);
    ydata  = M;
end


%% --- lsqcurvefit options ---
opts = optimoptions('lsqcurvefit',...
    'Display','off',...
    'MaxFunctionEvaluations',5000,...
    'MaxIterations',1000);

%% --- Fit ---
try
    x = lsqcurvefit(model, x0, tn, ydata, lb, ub, opts);
catch
    pars = emptyPars(); R2 = NaN; stats = struct();
    return;
end

%% --- Extract parameters ---
Minf  = x(1);
dM    = x(2);
tau_n = x(3);
beta  = x(4);

tau = tau_n * dt;
M0  = Minf + dM;
t0  = tmin;

if abs(dM) < 1e-7
    tau  = NaN;
    beta = 1;
end
%% --- Optional vertical anchoring to early-time data ---
if params.timeWeight    % or simply: if true
    % Use the first 10% of normalized time for anchoring
    anchorFrac = 0.10;
    earlyMask  = (tn <= anchorFrac);
    if any(earlyMask)
        % Target: mean of measured M in early window
        M_early_data = mean(M(earlyMask));

        % Model with current parameters on the same points
        M_model_full = model_core(x, tn);
        M_early_model = mean(M_model_full(earlyMask));

        % Shift Minf so early-time model matches early-time data on average
        delta = M_early_data - M_early_model;
        Minf  = Minf + delta;
        x(1)  = Minf;          % keep internal parameter consistent

        % Update derived quantities
        M0 = Minf + dM;
    end
end

%% --- R² ---
Mfit  = model_core(x, tn);
SSres = nansum((M - Mfit).^2);
SStot = nansum((M - mean(M,'omitnan')).^2);
R2    = 1 - SSres / max(eps,SStot);

pars = struct('Minf',Minf,'dM',dM,'tau',tau,'n',beta,'t0',t0,'M0',M0);

%% --- Stats ---
if nargout > 2
    stats = struct('residuals',M-Mfit,'Mfit',Mfit,...
                   'SSres',SSres,'SStot',SStot);
end

if debug
    fprintf('Fit(T=%.2f): Minf=%.3g, dM=%.3g, τ=%.3g, β=%.3f, R²=%.3f\n',...
        T, Minf, dM, tau, beta, R2);
end

end


%% Utility functions
function p = emptyPars()
p = struct('Minf',NaN,'dM',NaN,'tau',NaN,'n',NaN,'t0',NaN,'M0',NaN);
end

function S = setDefault(S, field, val)
if ~isfield(S, field)
    S.(field) = val;
end
end
