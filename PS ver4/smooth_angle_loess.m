function yout = smooth_angle_loess(angDeg, y, Btesla, varargin)
% SMOOTH_ANGLE_LOESS — Fully adaptive LOESS smoothing vs. angle with
% dynamic span depending on field, global noise level, and local gradients.
%
%   yout = smooth_angle_loess(angDeg, y, Btesla, 'Name',Value,...)
%
% INPUTS
%   angDeg : angle vector (deg)
%   y      : data vector
%   Btesla : scalar field (T)
%
% NAME-VALUE PAIRS
%   'UseFiltering' (logical)  default: true
%   'SpanLow'      (scalar)   default: 0.18
%   'SpanMid'      (scalar)   default: 0.10
%   'SpanHigh'     (scalar)   default: 0.12
%   'Method'       (char)     default: 'loess'
%   'UseDynamic'   (logical)  default: true
%
% OUTPUT
%   yout : smoothed data vector (same length as input)
%
% Notes:
%   - span adapts continuously with field, noise, and gradient
%   - fallback to moving average if Curve Fitting Toolbox not found

    p = inputParser;
    addParameter(p, 'UseFiltering', true, @(x)islogical(x)&&isscalar(x));
    addParameter(p, 'SpanLow',  0.18, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'SpanMid',  0.10, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'SpanHigh', 0.12, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'Method', 'loess', @(s)ischar(s)||isstring(s));
    addParameter(p, 'UseDynamic', true, @(x)islogical(x)&&isscalar(x));
    parse(p, varargin{:});
    o = p.Results;

    % --- guards ---
    angDeg = angDeg(:);
    y      = y(:);
    if numel(angDeg) ~= numel(y) || numel(y) < 5 || ~o.UseFiltering
        yout = y;
        return;
    end

    % --- resolve NaNs ---
    if isnan(o.SpanLow),  o.SpanLow  = 0.18; end
    if isnan(o.SpanMid),  o.SpanMid  = 0.10; end
    if isnan(o.SpanHigh), o.SpanHigh = 0.12; end

    % --- (1) Base span as continuous function of field ---
    if ~isfinite(Btesla)
        span_field = o.SpanMid;
    else
        % smooth transition from low→mid→high field
        span_field = o.SpanLow - (o.SpanLow - o.SpanHigh) * min(max((Btesla - 3)/10, 0), 1);
    end

    % --- (2) Global noise estimate (σ/μ ratio) ---
    mu  = nanmean(y);
    sig = nanstd(y);
    noise_ratio = sig / (abs(mu) + eps);

    % noise-dependent scaling (↑noise → ↑span)
    noise_factor = 1 + 1.8 * min(noise_ratio, 0.4);  % saturates ~×1.7
    span_noise = span_field * noise_factor;

    % --- (3) Local gradient control (sharp regions → less smoothing) ---
    dy = gradient(y);
    grad_norm = abs(dy) / (nanmean(abs(dy)) + eps);
    local_factor = exp(-grad_norm);
    local_factor = 0.6 + 0.4 * (local_factor - min(local_factor)) / (max(local_factor) - min(local_factor) + eps);

    % --- (4) Combine all effects ---
    span_local = span_noise .* local_factor;
    span_local = min(max(span_local, 0.02), 0.45);  % constrain reasonable range

    % --- ensure unique angles ---
    [angU, ia] = unique(angDeg, 'stable');
    yU = y(ia);
    span_local = span_local(ia);

    % --- adaptive smoothing ---
    try
        yUs = zeros(size(yU));
        for k = 1:numel(yU)
            s = span_local(k);
            yUs(k) = smooth(angU, yU, s, o.Method);
        end
    catch
        win = max(5, round(numel(yU)*median(span_local)));
        yUs = movmean(yU, win, 'omitnan');
    end

    % --- map back to original order ---
    yout = y;
    yout(ia) = yUs;
end
