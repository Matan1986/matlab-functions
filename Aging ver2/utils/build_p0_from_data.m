function p0 = build_p0_from_data(Tfit, yfit, Tp, W, dip_window_K, yScale, tScale)
% =========================================================
% build_p0_from_data
%
% PURPOSE:
%   Data-driven initial guess for step + Gaussian dip fit.
%
% INPUTS:
%   Tfit         - fit temperature vector
%   yfit         - fit data vector
%   Tp           - pause temperature
%   W            - half window size
%   dip_window_K - dip window size
%   yScale       - y-scale
%   tScale       - t-scale
%
% OUTPUTS:
%   p0           - initial parameter vector
%
% Physics meaning:
%   AFM = Gaussian dip term
%   FM  = step-like background term
%
% =========================================================

edgeMask = abs(Tfit - Tp) > 0.6 * W;
if nnz(edgeMask) < 10
    edgeMask = true(size(Tfit));
end
pp = polyfit(Tfit(edgeMask) - Tp, yfit(edgeMask), 1);

m0 = pp(1);
C0 = pp(2);

dipMask = abs(Tfit - Tp) <= max(dip_window_K, 2);
Tlocal = Tfit(dipMask);
ylocal = yfit(dipMask);
[~, kmin] = min(ylocal);

T0_init = Tlocal(kmin);
ybg0 = C0 + m0 * (T0_init - Tp);
Adip0 = max(0.2 * yScale, ybg0 - ylocal(kmin));

sigma0 = max(0.8, 0.08 * W);
w0     = max(0.8, 0.08 * W);

p0 = [C0, m0, 0.2 * yScale, w0 / tScale, Adip0, ...
    (T0_init - Tp) / tScale, sigma0 / tScale];
end
