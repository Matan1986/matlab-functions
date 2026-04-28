function out = aging_F6I_canonical_exponential_fit(twVals, yVals)
%AGING_F6I_CANONICAL_EXPONENTIAL_FIT Diagnostic-only duplicate of single_exponential_approach_primary in run_aging_F4B_FM_physical_tau_replay.m
% Labels: diagnostic_tau_only not_canonical not_physical_claim not_replacing_F4A_F4B
% Gate: finite tau > 0, r2 >= 0.6, n_points >= 3 (same thresholds as F4B replay).

twVals = twVals(:);
yVals = yVals(:);
finiteMask = isfinite(twVals) & isfinite(yVals);
twVals = double(twVals(finiteMask));
yVals = double(yVals(finiteMask));
[twVals, sortIdx] = sort(twVals);
yVals = yVals(sortIdx);

nPoints = numel(twVals);
twMinRequired = 3;
qualityThresholdR2 = 0.6;

out.tau_seconds = NaN;
out.param_A = NaN;
out.param_B = NaN;
out.rmse = NaN;
out.r2 = NaN;
out.quality_pass = false;
out.gate_detail = "not_run";
out.n_points = nPoints;

if nPoints < twMinRequired
    out.gate_detail = "insufficient_points";
    return;
end

sst = sum((yVals - mean(yVals)).^2);

yMin = min(yVals);
yMax = max(yVals);
yRange = yMax - yMin;
if yRange == 0
    yRange = max(abs(yVals));
end
if yRange == 0
    yRange = 1e-12;
end
tauInit = median(twVals);
if ~isfinite(tauInit) || tauInit <= 0
    tauInit = 360;
end
AInit = yVals(1);
BInit = yVals(end) - yVals(1);
if ~isfinite(BInit) || abs(BInit) < 1e-12
    BInit = yRange;
end
theta0 = [AInit, BInit, log(tauInit)];

objective = @(theta) sum((yVals - (theta(1) + theta(2) .* (1 - exp(-twVals ./ exp(theta(3)))))).^2);
opts = optimset('Display', 'off', 'MaxIter', 5000, 'MaxFunEvals', 20000, 'TolX', 1e-12, 'TolFun', 1e-12);
[thetaFit, sseFit] = fminsearch(objective, theta0, opts);

AFit = thetaFit(1);
BFit = thetaFit(2);
tauFit = exp(thetaFit(3));
yHat = AFit + BFit .* (1 - exp(-twVals ./ tauFit));
rmsePrimary = sqrt(mean((yVals - yHat).^2));
if sst > 0
    r2Primary = 1 - sseFit / sst;
else
    r2Primary = 1;
end

out.tau_seconds = tauFit;
out.param_A = AFit;
out.param_B = BFit;
out.rmse = rmsePrimary;
out.r2 = r2Primary;

qualityOk = (nPoints >= twMinRequired) && isfinite(tauFit) && (tauFit > 0) && isfinite(r2Primary) && (r2Primary >= qualityThresholdR2);
out.quality_pass = qualityOk;
if qualityOk
    out.gate_detail = "pass";
else
    if ~(isfinite(tauFit) && tauFit > 0)
        out.gate_detail = "invalid_tau";
    elseif ~(isfinite(r2Primary) && r2Primary >= qualityThresholdR2)
        out.gate_detail = "r2_below_threshold";
    else
        out.gate_detail = "fail_other";
    end
end
end
