function J = cost_step_gauss(p, T, y, Tp, yS, tS)
% =========================================================
% cost_step_gauss
%
% PURPOSE:
%   Cost function for step + Gaussian dip model used in FM/AFM fitting.
%
% INPUTS:
%   p   - parameter vector [C, m, Astep, w_hat, Adip, T0_hat, sigma_hat]
%   T   - temperature vector
%   y   - ΔM data
%   Tp  - pause temperature
%   yS  - y-scale
%   tS  - t-scale (window width)
%
% OUTPUTS:
%   J   - scalar cost (sum of squared residuals + penalties)
%
% Physics meaning:
%   AFM = Gaussian dip term
%   FM  = step-like background term
%
% =========================================================

C = p(1);
m = p(2);
A = p(3);
w = max(p(4) * tS, 0.5);
Ad = abs(p(5));
T0 = Tp + p(6) * tS;
s = max(p(7) * tS, 0.4);

yhat = C + m * (T - Tp) + A * tanh((T - Tp) / w) ...
    - Ad * exp(-(T - T0).^2 / (2 * s^2));

res = y - yhat;

pen = 0;
if s > 0.6 * tS
    pen = pen + 1e4 * (s - 0.6 * tS)^2;
end
if abs(T0 - Tp) > 1.5
    pen = pen + 1e4 * (abs(T0 - Tp) - 1.5)^2;
end

J = sum(res.^2) / (yS^2) + pen;
end
