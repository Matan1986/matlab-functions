function out = aging_F6I_legacy_fm_tau_from_curve(tw, y)
%AGING_F6I_LEGACY_FM_TAU_FROM_CURVE Diagnostic-only FM tau consensus aligned with aging_fm_timescale_analysis.m buildEffectiveFmTau.
% Labels: diagnostic_tau_only not_canonical not_physical_claim not_replacing_F4A_F4B
tw = tw(:);
y = y(:);
row = f6i_analyzeTpGroup(tw, y);
out = f6i_rowToOut(row);
end

function out = f6i_rowToOut(row)
out.tau_diagnostic_consensus_seconds = row.tau_effective_seconds;
out.tau_consensus_method_count = row.tau_consensus_method_count;
out.tau_consensus_methods = row.tau_consensus_methods;
out.tau_method_spread_decades = row.tau_method_spread_decades;
out.tau_logistic_half_seconds = row.tau_logistic_half_seconds;
out.tau_logistic_trusted = row.tau_logistic_trusted;
out.tau_logistic_rmse = row.tau_logistic_rmse;
out.tau_logistic_r2 = row.tau_logistic_r2;
out.tau_logistic_status = row.tau_logistic_status;
out.tau_stretched_half_seconds = row.tau_stretched_half_seconds;
out.tau_stretched_trusted = row.tau_stretched_trusted;
out.tau_stretched_rmse = row.tau_stretched_rmse;
out.tau_stretched_r2 = row.tau_stretched_r2;
out.tau_stretched_status = row.tau_stretched_status;
out.tau_stretched_beta = row.tau_stretched_beta;
out.tau_half_range_seconds = row.tau_half_range_seconds;
out.tau_half_range_status = row.tau_half_range_status;
out.n_points = row.n_points;
out.n_downturns = row.n_downturns;
end

function row = f6i_analyzeTpGroup(tw, y)
row = initTauRow();
tw = tw(:);
y = y(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    peakIdx = NaN;
    peakValue = NaN;
end

row.Tp = NaN;
row.n_points = numel(tw);
row.fragile_low_point_count = numel(tw) < 4;
row.tw_min_seconds = min(tw, [], 'omitnan');
row.tw_max_seconds = max(tw, [], 'omitnan');
if isfinite(peakIdx)
    row.peak_tw_seconds = tw(peakIdx);
end
row.Dip_depth_start = y(1);
row.Dip_depth_peak = peakValue;
row.Dip_depth_range_to_peak = peakValue - y(1);
row.n_downturns = nnz(diff(y) < 0);
row.source_run = "diagnostic";

logisticFit = fitLogisticInLogTime(tw, y);
row.tau_logistic_half_seconds = logisticFit.tau_half_seconds;
row.tau_logistic_sigma_decades = logisticFit.sigma_decades;
row.tau_logistic_rmse = logisticFit.rmse;
row.tau_logistic_r2 = logisticFit.r2;
row.tau_logistic_trusted = logisticFit.trusted;
row.tau_logistic_status = logisticFit.status;

stretchedFit = fitStretchedExponential(tw, y);
row.tau_stretched_half_seconds = stretchedFit.tau_half_seconds;
row.tau_stretched_char_seconds = stretchedFit.tau_char_seconds;
row.tau_stretched_beta = stretchedFit.beta;
row.tau_stretched_rmse = stretchedFit.rmse;
row.tau_stretched_r2 = stretchedFit.r2;
row.tau_stretched_trusted = stretchedFit.trusted;
row.tau_stretched_status = stretchedFit.status;

halfRange = estimateHalfRangeTime(tw, y);
row.tau_half_range_seconds = halfRange.tau_seconds;
row.tau_half_range_status = halfRange.status;

[row.tau_effective_seconds, row.tau_consensus_method_count, ...
    row.tau_consensus_methods, row.tau_method_spread_decades] = ...
    buildEffectiveFmTau(row);
end

function row = initTauRow()
row = struct( ...
    'Tp', NaN, ...
    'n_points', NaN, ...
    'fragile_low_point_count', false, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'peak_tw_seconds', NaN, ...
    'Dip_depth_start', NaN, ...
    'Dip_depth_peak', NaN, ...
    'Dip_depth_range_to_peak', NaN, ...
    'n_downturns', NaN, ...
    'tau_logistic_half_seconds', NaN, ...
    'tau_logistic_sigma_decades', NaN, ...
    'tau_logistic_rmse', NaN, ...
    'tau_logistic_r2', NaN, ...
    'tau_logistic_trusted', false, ...
    'tau_logistic_status', "", ...
    'tau_stretched_half_seconds', NaN, ...
    'tau_stretched_char_seconds', NaN, ...
    'tau_stretched_beta', NaN, ...
    'tau_stretched_rmse', NaN, ...
    'tau_stretched_r2', NaN, ...
    'tau_stretched_trusted', false, ...
    'tau_stretched_status', "", ...
    'tau_half_range_seconds', NaN, ...
    'tau_half_range_status', "", ...
    'tau_effective_seconds', NaN, ...
    'tau_consensus_method_count', NaN, ...
    'tau_consensus_methods', "", ...
    'tau_method_spread_decades', NaN, ...
    'source_run', "");
end

function fit = initFitResult(status)
if nargin < 1
    status = "not_run";
end
fit = struct( ...
    'tau_half_seconds', NaN, ...
    'tau_char_seconds', NaN, ...
    'sigma_decades', NaN, ...
    'beta', NaN, ...
    'rmse', NaN, ...
    'r2', NaN, ...
    'trusted', false, ...
    'status', string(status));
end

function fit = fitLogisticInLogTime(t, y)
fit = initFitResult("fit_failed");

if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end

x = log10(t(:));
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;

halfData = estimateHalfRangeTime(t, y);
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    muSeeds = [log10(halfData.tau_seconds), mean(x), median(x), x(1), x(end)];
else
    muSeeds = [mean(x), median(x), x(1), x(end)];
end
sigmaSeeds = [0.20, 0.40, 0.80, 1.20];
deltaSeeds = [max(rangeY / scaleY, 0.05), max(yScaled(end) - yScaled(1), 0.05), 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];

best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 4000, 'MaxFunEvals', 8000);

for y0 = y0Seeds
    for delta = deltaSeeds
        for mu = muSeeds
            for sigma = sigmaSeeds
                p0 = [y0, log(max(delta, 1e-6)), mu, log(max(sigma, 1e-6))];
                [p, sse] = fminsearch(@(pp) logisticObjective(pp, x, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end

if isempty(best)
    return;
end

params = unpackLogisticParams(best);
yHatScaled = logisticModel(params, x);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = 10.^params.mu;
rmseRel = rmse ./ max(rangeY, eps);

fit.tau_half_seconds = tauHalf;
fit.sigma_decades = params.sigma;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end

function fit = fitStretchedExponential(t, y)
fit = initFitResult("fit_failed");

if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end

t = t(:);
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;

halfData = estimateHalfRangeTime(t, y);
betaSeeds = [0.50, 0.80, 1.20, 1.60];
tauSeeds = [sqrt(t(1) * t(end)), median(t), t(end) / 2, t(1)];
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    tauSeeds(end + 1) = halfData.tau_seconds / (log(2) .^ (1 / betaSeeds(2)));
end
deltaSeeds = [max(rangeY / scaleY, 0.05), max(y(end) - y(1), 0.05) / scaleY, 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];

best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 5000, 'MaxFunEvals', 10000);

for y0 = y0Seeds
    for delta = deltaSeeds
        for tau = tauSeeds
            if ~isfinite(tau) || tau <= 0
                continue;
            end
            for beta = betaSeeds
                p0 = [y0, log(max(delta, 1e-6)), log(tau), betaToRaw(beta)];
                [p, sse] = fminsearch(@(pp) stretchedObjective(pp, t, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end

if isempty(best)
    return;
end

params = unpackStretchedParams(best);
yHatScaled = stretchedModel(params, t);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = params.tau_char .* (log(2) .^ (1 ./ params.beta));
rmseRel = rmse ./ max(rangeY, eps);

fit.tau_half_seconds = tauHalf;
fit.tau_char_seconds = params.tau_char;
fit.beta = params.beta;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end

function result = estimateHalfRangeTime(t, y)
result = struct('tau_seconds', NaN, 'status', "unresolved");

if numel(t) < 2 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    result.status = "insufficient_data";
    return;
end

t = t(:);
y = y(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    result.status = "missing_peak";
    return;
end

yStart = y(1);
if peakIdx == 1 || ~isfinite(yStart) || peakValue <= yStart
    result.status = "no_upward_crossing";
    return;
end

target = yStart + 0.5 * (peakValue - yStart);
crossIdx = find(y(1:peakIdx-1) <= target & y(2:peakIdx) >= target, 1, 'first');
if isempty(crossIdx)
    tol = eps(max(abs([target; y])));
    exactIdx = find(abs(y(1:peakIdx) - target) <= tol, 1, 'first');
    if isempty(exactIdx)
        result.status = "no_upward_crossing";
        return;
    end
    result.tau_seconds = t(exactIdx);
    result.status = "ok";
    return;
end

t1 = t(crossIdx);
t2 = t(crossIdx + 1);
y1 = y(crossIdx);
y2 = y(crossIdx + 1);
tol = eps(max(abs([y1; y2])));
if ~isfinite(y1) || ~isfinite(y2) || abs(y2 - y1) <= tol
    result.tau_seconds = sqrt(t1 * t2);
    result.status = "ok";
    return;
end

frac = (target - y1) ./ (y2 - y1);
frac = min(max(frac, 0), 1);
logTau = log10(t1) + frac .* (log10(t2) - log10(t1));
result.tau_seconds = 10.^logTau;
result.status = "ok";
end

function [tauEffective, nMethods, methodNames, spreadDecades] = buildEffectiveFmTau(row)
% Body copy from aging_fm_timescale_analysis.m (buildEffectiveFmTau).
tauValues = [];
names = strings(0, 1);
if row.tau_logistic_trusted && isfinite(row.tau_logistic_half_seconds) && row.tau_logistic_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_logistic_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "logistic_log_tw"; %#ok<AGROW>
end
if row.tau_stretched_trusted && isfinite(row.tau_stretched_half_seconds) && row.tau_stretched_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_stretched_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "stretched_exp"; %#ok<AGROW>
end
if row.tau_half_range_status == "ok" && isfinite(row.tau_half_range_seconds) && row.tau_half_range_seconds > 0
    tauValues(end + 1, 1) = row.tau_half_range_seconds; %#ok<AGROW>
    names(end + 1, 1) = "half_range"; %#ok<AGROW>
end
if isempty(tauValues)
    tauEffective = NaN;
    nMethods = 0;
    methodNames = "";
    spreadDecades = NaN;
    return;
end
logTau = log10(tauValues);
spreadDecades = max(logTau) - min(logTau);
if row.tau_half_range_status == "ok" && isfinite(row.tau_half_range_seconds) && row.tau_half_range_seconds > 0
    tauEffective = row.tau_half_range_seconds;
    nMethods = 1;
    methodNames = "half_range_primary";
else
    tauEffective = 10.^median(logTau);
    nMethods = numel(tauValues);
    methodNames = strjoin(names.', ', ');
end
end

function [sse, yHat] = logisticObjective(p, x, y)
params = unpackLogisticParams(p);
yHat = logisticModel(params, x);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackLogisticParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.mu = p(3);
params.sigma = exp(p(4));
end

function yHat = logisticModel(params, x)
z = -(x - params.mu) ./ max(params.sigma, eps);
yHat = params.y0 + params.delta ./ (1 + exp(z));
end

function [sse, yHat] = stretchedObjective(p, t, y)
params = unpackStretchedParams(p);
yHat = stretchedModel(params, t);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackStretchedParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.tau_char = exp(p(3));
params.beta = rawToBeta(p(4));
end

function yHat = stretchedModel(params, t)
scaledT = (t ./ max(params.tau_char, eps)) .^ params.beta;
yHat = params.y0 + params.delta .* (1 - exp(-scaledT));
end

function raw = betaToRaw(beta)
betaMax = 2.0;
beta = min(max(beta, 1e-4), betaMax - 1e-4);
raw = log(beta ./ (betaMax - beta));
end

function beta = rawToBeta(raw)
betaMax = 2.0;
beta = betaMax ./ (1 + exp(-raw));
end

function r2 = computeRsquared(y, yHat)
mask = isfinite(y) & isfinite(yHat);
if nnz(mask) < 2
    r2 = NaN;
    return;
end
ssRes = sum((y(mask) - yHat(mask)).^2);
ssTot = sum((y(mask) - mean(y(mask), 'omitnan')).^2);
if ssTot <= eps
    r2 = NaN;
else
    r2 = 1 - ssRes ./ ssTot;
end
end

function status = classifyModelStatus(rmseRel, tauHalf, t)
if ~isfinite(tauHalf) || tauHalf <= 0
    status = "fit_failed";
elseif ~isfinite(rmseRel)
    status = "fit_failed";
elseif rmseRel > 0.65
    status = "poor_match";
elseif tauHalf < min(t) || tauHalf > max(t)
    status = "extrapolated";
else
    status = "ok";
end
end