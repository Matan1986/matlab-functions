function [A_relax, T_relax, skew_relax, shoulder_strength, detail] = compute_relaxation_coordinates(T, profile)
% compute_relaxation_coordinates
% Compute minimal geometric coordinates from a temperature activity profile.
%
% Inputs:
%   T       - temperature vector (K)
%   profile - activity profile(T), e.g. S_max(T)
%
% Outputs:
%   A_relax          - max(profile)
%   T_relax          - T at max(profile)
%   skew_relax       - normalized asymmetry around half-maximum
%   shoulder_strength- max(profile(T < T_relax)) / A_relax
%   detail           - struct with half-level and crossing temperatures

T = T(:);
profile = profile(:);

valid = isfinite(T) & isfinite(profile);
T = T(valid);
profile = profile(valid);

if numel(T) < 3
    [A_relax, T_relax, skew_relax, shoulder_strength, detail] = emptyOutputs();
    return;
end

% Sort and merge duplicate temperatures by mean profile.
[T, ord] = sort(T, 'ascend');
profile = profile(ord);
[Tu, ~, g] = unique(T, 'stable');
pu = accumarray(g, profile, [numel(Tu), 1], @(x) mean(x, 'omitnan'), NaN);
T = Tu;
profile = pu;

if numel(T) < 3 || all(~isfinite(profile))
    [A_relax, T_relax, skew_relax, shoulder_strength, detail] = emptyOutputs();
    return;
end

[A_relax, ipk] = max(profile);
if ~isfinite(A_relax)
    [A_relax, T_relax, skew_relax, shoulder_strength, detail] = emptyOutputs();
    return;
end
T_relax = T(ipk);

half_level = A_relax / 2;
T_left = crossingLowSide(T, profile, half_level, ipk);
T_right = crossingHighSide(T, profile, half_level, ipk);

width_left = T_relax - T_left;
width_right = T_right - T_relax;

if isfinite(width_left) && isfinite(width_right)
    den = width_right + width_left;
    if den > 0
        skew_relax = (width_right - width_left) / den;
    else
        skew_relax = NaN;
    end
else
    skew_relax = NaN;
end

lowMask = T < T_relax;
if any(lowMask)
    lowPeak = max(profile(lowMask));
    if isfinite(lowPeak) && A_relax > 0
        shoulder_strength = lowPeak / A_relax;
    else
        shoulder_strength = NaN;
    end
else
    shoulder_strength = NaN;
end

detail = struct();
detail.T_left = T_left;
detail.T_right = T_right;
detail.half_level = half_level;
detail.width_left = width_left;
detail.width_right = width_right;
detail.T = T;
detail.profile = profile;
end

function Tcross = crossingLowSide(T, p, half_level, ipk)
Tcross = NaN;
if ipk <= 1
    return;
end
f = p - half_level;
idx = find(f(1:ipk-1) <= 0 & f(2:ipk) >= 0, 1, 'last');
if isempty(idx)
    idx = find(f(1:ipk-1) >= 0 & f(2:ipk) <= 0, 1, 'last');
end
if isempty(idx)
    return;
end
Tcross = interpCross(T(idx), T(idx+1), f(idx), f(idx+1));
end

function Tcross = crossingHighSide(T, p, half_level, ipk)
Tcross = NaN;
if ipk >= numel(T)
    return;
end
f = p - half_level;
idx = find(f(ipk:end-1) >= 0 & f(ipk+1:end) <= 0, 1, 'first');
if isempty(idx)
    idx = find(f(ipk:end-1) <= 0 & f(ipk+1:end) >= 0, 1, 'first');
end
if isempty(idx)
    return;
end
j = ipk + idx - 1;
Tcross = interpCross(T(j), T(j+1), f(j), f(j+1));
end

function x0 = interpCross(x1, x2, y1, y2)
if ~isfinite(x1) || ~isfinite(x2)
    x0 = NaN;
    return;
end
if ~isfinite(y1) || ~isfinite(y2) || y1 == y2
    x0 = mean([x1, x2], 'omitnan');
    return;
end
x0 = x1 + (0 - y1) * (x2 - x1) / (y2 - y1);
end

function [A_relax, T_relax, skew_relax, shoulder_strength, detail] = emptyOutputs()
A_relax = NaN;
T_relax = NaN;
skew_relax = NaN;
shoulder_strength = NaN;
detail = struct('T_left', NaN, 'T_right', NaN, 'half_level', NaN, ...
    'width_left', NaN, 'width_right', NaN, 'T', [], 'profile', []);
end
