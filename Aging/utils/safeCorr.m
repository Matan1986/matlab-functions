function [r, status, n] = safeCorr(x, y)
% =========================================================
% safeCorr — Robust correlation with NaN/constant handling
% =========================================================
%
% PURPOSE:
%   Compute Pearson correlation robustly, returning NaN with
%   descriptive status if inputs are problematic.
%
% SYNTAX:
%   [r, status, n] = safeCorr(x, y)
%
% INPUT:
%   x, y - vectors or arrays; NaNs and Infs are filtered
%
% OUTPUT:
%   r      - correlation coefficient [-1, 1] or NaN if invalid
%   status - string: "ok", "too_few_points", or "constant_vector"
%   n      - number of valid (finite) points used
%
% BEHAVIOR:
%   1. Remove NaNs: mask = isfinite(x) & isfinite(y)
%   2. If n < 3: return NaN, "too_few_points", n
%   3. If std(x)==0 or std(y)==0: return NaN, "constant_vector", n
%   4. Otherwise: compute r = corr(x,y), return "ok", n
%
% EXAMPLE:
%   x = [1 2 3 NaN 5];
%   y = [2 4 6 8 10];
%   [r, status, n] = safeCorr(x, y);
%   % r = 1.0, status = "ok", n = 4
%
% NOTE:
%   This function preserves backward compatibility by returning
%   NaN (which prints as NaN) instead of crashing on bad input.
%
% =========================================================

% Ensure column vectors
x = x(:);
y = y(:);

% Remove NaNs and Infs
mask = isfinite(x) & isfinite(y);
x_clean = x(mask);
y_clean = y(mask);

% Count valid points
n = numel(x_clean);

% Check for insufficient data
if n < 3
    r = NaN;
    status = "too_few_points";
    return;
end

% Check for constant vectors
if std(x_clean) == 0 || std(y_clean) == 0
    r = NaN;
    status = "constant_vector";
    return;
end

% Compute correlation
r = corr(x_clean, y_clean);
status = "ok";

end
