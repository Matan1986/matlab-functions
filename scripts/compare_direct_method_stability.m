% compare_direct_method_stability
% Compare stability of three direct methods on one DeltaM(T) trace.
%
% Required workspace variables:
%   T         : temperature vector
%   DeltaM    : signal vector
%
% Optional workspace variables:
%   DeltaM_signed : signed signal vector
%   Tp (or waitK) : pause temperature used as dip center
%
% Output:
%   Prints baseline values and a summary table:
%   Method | AFM_param_var | AFM_noise_var | FM_param_var | FM_noise_var

%% Input checks and setup
if ~exist('T', 'var') || ~exist('DeltaM', 'var')
    error('compare_direct_method_stability:MissingInput', ...
        'This script requires workspace variables T and DeltaM.');
end

T = T(:);
DeltaM = DeltaM(:);
n = min(numel(T), numel(DeltaM));
T = T(1:n);
DeltaM = DeltaM(1:n);

DeltaM_signed_local = [];
if exist('DeltaM_signed', 'var')
    DeltaM_signed_local = DeltaM_signed(:);
    nSigned = min(n, numel(DeltaM_signed_local));
    T = T(1:nSigned);
    DeltaM = DeltaM(1:nSigned);
    DeltaM_signed_local = DeltaM_signed_local(1:nSigned);
end

if exist('Tp', 'var') && isscalar(Tp) && isfinite(Tp)
    Tp_local = Tp;
elseif exist('waitK', 'var') && isscalar(waitK) && isfinite(waitK)
    Tp_local = waitK;
else
    [~, iMin] = min(DeltaM);
    Tp_local = T(iMin);
    fprintf('Tp not provided. Using Tmin of DeltaM as fallback: %.6g K\n', Tp_local);
end

cfgBase = struct();
cfgBase.dip_window_K = 1;
cfgBase.smoothWindow_K = 2;
cfgBase.excludeLowT_FM = false;
cfgBase.excludeLowT_K = -inf;
cfgBase.FM_plateau_K = 6;
cfgBase.excludeLowT_mode = 'pre';
cfgBase.FM_buffer_K = 3;
cfgBase.AFM_metric_main = 'area';
cfgBase.FMConvention = 'leftMinusRight';
cfgBase.doFilterDeltaM = false;

% Robust-baseline defaults
cfgBase.dip_margin_K = 2;
cfgBase.plateau_nPoints = 6;
cfgBase.dropLowestN = 1;
cfgBase.dropHighestN = 0;
cfgBase.plateau_agg = 'median';
cfgBase.FM_plateau_minWidth_K = 1.0;
cfgBase.FM_plateau_minPoints = 12;
cfgBase.FM_plateau_maxAllowedSlope = 0.02;
cfgBase.FM_plateau_allowNarrowFallback = true;

%% STEP 1 - Baseline run
[AFM_core,  FM_core]   = runCoreDirect(T, DeltaM, DeltaM_signed_local, Tp_local, cfgBase);
[AFM_deriv, FM_deriv]  = runDerivative(T, DeltaM, DeltaM_signed_local, Tp_local, cfgBase);
[AFM_rob,   FM_rob]    = runRobustDirect(T, DeltaM, DeltaM_signed_local, Tp_local, cfgBase);

fprintf('\n=== Baseline run ===\n');
fprintf('AFM_core  = %.6g, FM_core  = %.6g\n', AFM_core, FM_core);
fprintf('AFM_deriv = %.6g, FM_deriv = %.6g\n', AFM_deriv, FM_deriv);
fprintf('AFM_rob   = %.6g, FM_rob   = %.6g\n', AFM_rob, FM_rob);

%% STEP 2 - Parameter sensitivity
smoothWindow_K_list = [1, 2, 3, 4];
dip_window_K_list   = [0.5, 1, 2];

AFM_core_param = [];
FM_core_param  = [];
AFM_der_param  = [];
FM_der_param   = [];
AFM_rob_param  = [];
FM_rob_param   = [];

for iS = 1:numel(smoothWindow_K_list)
    for iD = 1:numel(dip_window_K_list)
        cfg = cfgBase;
        cfg.smoothWindow_K = smoothWindow_K_list(iS);
        cfg.dip_window_K = dip_window_K_list(iD);

        [a1, f1] = runCoreDirect(T, DeltaM, DeltaM_signed_local, Tp_local, cfg);
        [a2, f2] = runDerivative(T, DeltaM, DeltaM_signed_local, Tp_local, cfg);
        [a3, f3] = runRobustDirect(T, DeltaM, DeltaM_signed_local, Tp_local, cfg);

        AFM_core_param(end+1,1) = a1; %#ok<SAGROW>
        FM_core_param(end+1,1)  = f1; %#ok<SAGROW>
        AFM_der_param(end+1,1)  = a2; %#ok<SAGROW>
        FM_der_param(end+1,1)   = f2; %#ok<SAGROW>
        AFM_rob_param(end+1,1)  = a3; %#ok<SAGROW>
        FM_rob_param(end+1,1)   = f3; %#ok<SAGROW>
    end
end

%% STEP 3 - Noise robustness
noise_levels = [0, 0.01, 0.02, 0.05];
nNoiseRealizations = 25;
rng(1);

AFM_core_noise = [];
FM_core_noise  = [];
AFM_der_noise  = [];
FM_der_noise   = [];
AFM_rob_noise  = [];
FM_rob_noise   = [];

for iL = 1:numel(noise_levels)
    sigma = noise_levels(iL);
    for r = 1:nNoiseRealizations
        noisyDeltaM = DeltaM + sigma * randn(size(DeltaM));
        noisySigned = [];
        if ~isempty(DeltaM_signed_local)
            noisySigned = DeltaM_signed_local + sigma * randn(size(DeltaM_signed_local));
        end

        [a1, f1] = runCoreDirect(T, noisyDeltaM, noisySigned, Tp_local, cfgBase);
        [a2, f2] = runDerivative(T, noisyDeltaM, noisySigned, Tp_local, cfgBase);
        [a3, f3] = runRobustDirect(T, noisyDeltaM, noisySigned, Tp_local, cfgBase);

        AFM_core_noise(end+1,1) = a1; %#ok<SAGROW>
        FM_core_noise(end+1,1)  = f1; %#ok<SAGROW>
        AFM_der_noise(end+1,1)  = a2; %#ok<SAGROW>
        FM_der_noise(end+1,1)   = f2; %#ok<SAGROW>
        AFM_rob_noise(end+1,1)  = a3; %#ok<SAGROW>
        FM_rob_noise(end+1,1)   = f3; %#ok<SAGROW>
    end
end

%% STEP 4 - Metrics
AFM_param_var_core = safeCV(AFM_core_param);
AFM_param_var_der  = safeCV(AFM_der_param);
AFM_param_var_rob  = safeCV(AFM_rob_param);

AFM_noise_var_core = safeCV(AFM_core_noise);
AFM_noise_var_der  = safeCV(AFM_der_noise);
AFM_noise_var_rob  = safeCV(AFM_rob_noise);

FM_param_var_core = safeCV(FM_core_param);
FM_param_var_der  = safeCV(FM_der_param);
FM_param_var_rob  = safeCV(FM_rob_param);

FM_noise_var_core = safeCV(FM_core_noise);
FM_noise_var_der  = safeCV(FM_der_noise);
FM_noise_var_rob  = safeCV(FM_rob_noise);

%% STEP 5 - Output
Method = {'core direct'; 'derivative-assisted'; 'robust-baseline'};
AFM_param_var = [AFM_param_var_core; AFM_param_var_der; AFM_param_var_rob];
AFM_noise_var = [AFM_noise_var_core; AFM_noise_var_der; AFM_noise_var_rob];
FM_param_var  = [FM_param_var_core; FM_param_var_der; FM_param_var_rob];
FM_noise_var  = [FM_noise_var_core; FM_noise_var_der; FM_noise_var_rob];

summaryTbl = table(Method, AFM_param_var, AFM_noise_var, FM_param_var, FM_noise_var);

fprintf('\n=== Stability summary ===\n');
disp(summaryTbl);

afmScore = AFM_param_var + AFM_noise_var;
fmScore  = FM_param_var + FM_noise_var;

[~, idxAFM] = minFinite(afmScore);
[~, idxFM]  = minFinite(fmScore);

if ~isnan(idxAFM)
    fprintf('Most stable AFM method = %s\n', Method{idxAFM});
else
    fprintf('Most stable AFM method = unavailable (all AFM stability metrics are NaN)\n');
end

if ~isnan(idxFM)
    fprintf('Most stable FM method = %s\n', Method{idxFM});
else
    fprintf('Most stable FM method = unavailable (all FM stability metrics are NaN)\n');
end

%% Local functions
function [afmVal, fmVal] = runCoreDirect(T, dM, dM_signed, Tp, cfg)
afmVal = NaN;
fmVal = NaN;
try
    cfgLocal = cfg;
    cfgLocal.useRobustBaseline = false;

    runIn = makeRunStruct(T, dM, dM_signed, Tp);
    out = analyzeAFM_FM_components( ...
        runIn, cfgLocal.dip_window_K, cfgLocal.smoothWindow_K, ...
        cfgLocal.excludeLowT_FM, cfgLocal.excludeLowT_K, ...
        cfgLocal.FM_plateau_K, cfgLocal.excludeLowT_mode, cfgLocal.FM_buffer_K, ...
        cfgLocal.AFM_metric_main, cfgLocal);

    afmVal = extractAFM(out(1), cfgLocal.AFM_metric_main);
    fmVal  = extractFM(out(1));
catch
    afmVal = NaN;
    fmVal = NaN;
end
end

function [afmVal, fmVal] = runDerivative(T, dM, dM_signed, Tp, cfg)
afmVal = NaN;
fmVal = NaN;
try
    cfgLocal = cfg;
    cfgLocal.agingMetricMode = 'derivative';

    if ~isempty(dM_signed)
        dM_in = dM_signed;
    else
        dM_in = dM;
    end

    out = analyzeAFM_FM_derivative(T, dM_in, Tp, cfgLocal);
    afmVal = extractAFM(out, cfgLocal.AFM_metric_main);
    fmVal  = extractFM(out);
catch
    afmVal = NaN;
    fmVal = NaN;
end
end

function [afmVal, fmVal] = runRobustDirect(T, dM, dM_signed, Tp, cfg)
afmVal = NaN;
fmVal = NaN;
try
    cfgLocal = cfg;
    cfgLocal.useRobustBaseline = true;

    runIn = makeRunStruct(T, dM, dM_signed, Tp);
    out = analyzeAFM_FM_components( ...
        runIn, cfgLocal.dip_window_K, cfgLocal.smoothWindow_K, ...
        cfgLocal.excludeLowT_FM, cfgLocal.excludeLowT_K, ...
        cfgLocal.FM_plateau_K, cfgLocal.excludeLowT_mode, cfgLocal.FM_buffer_K, ...
        cfgLocal.AFM_metric_main, cfgLocal);

    afmVal = extractAFM(out(1), cfgLocal.AFM_metric_main);
    fmVal  = extractFM(out(1));
catch
    afmVal = NaN;
    fmVal = NaN;
end
end

function runIn = makeRunStruct(T, dM, dM_signed, Tp)
runIn = struct();
runIn.T_common = T(:);
runIn.DeltaM = dM(:);
runIn.waitK = Tp;
if ~isempty(dM_signed)
    runIn.DeltaM_signed = dM_signed(:);
end
end

function afmVal = extractAFM(s, afmMetric)
afmVal = NaN;
if strcmpi(afmMetric, 'height')
    if isfield(s, 'AFM_amp') && isfinite(s.AFM_amp)
        afmVal = s.AFM_amp;
    elseif isfield(s, 'AFM_area') && isfinite(s.AFM_area)
        afmVal = s.AFM_area;
    end
else
    if isfield(s, 'AFM_area') && isfinite(s.AFM_area)
        afmVal = s.AFM_area;
    elseif isfield(s, 'AFM_amp') && isfinite(s.AFM_amp)
        afmVal = s.AFM_amp;
    end
end
end

function fmVal = extractFM(s)
fmVal = NaN;
if isfield(s, 'FM_step_raw') && isfinite(s.FM_step_raw)
    fmVal = s.FM_step_raw;
elseif isfield(s, 'FM_step_mag') && isfinite(s.FM_step_mag)
    fmVal = s.FM_step_mag;
elseif isfield(s, 'FM_abs') && isfinite(s.FM_abs)
    fmVal = s.FM_abs;
end
end

function cv = safeCV(x)
x = x(:);
x = x(isfinite(x));
if numel(x) < 2
    cv = NaN;
    return;
end
mu = mean(x, 'omitnan');
sd = std(x, 0, 'omitnan');
if abs(mu) <= eps
    cv = NaN;
else
    cv = sd / abs(mu);
end
end

function [minVal, idx] = minFinite(x)
idx = NaN;
minVal = NaN;
mask = isfinite(x);
if ~any(mask)
    return;
end
xMasked = x;
xMasked(~mask) = inf;
[minVal, idx] = min(xMasked);
end
