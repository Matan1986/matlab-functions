%% ===== Local function: shifted-angle single-sine fit =====
function [A, x0_deg, d, stats, fitobj] = fit_single_curve_shifted(x, y, fold1, traceLabel)
% Fits:
%   y = A * sin( f*(x - x0)*pi/180 ) + d
% x0 = angle offset (in degrees), physically meaningful
%
% MUCH more stable than using φ when angle range < 360°.

if nargin < 4
    traceLabel = '(unnamed)';
end

% Remove NaN
good = ~isnan(x) & ~isnan(y);
x = x(good);
y = y(good);

% ensure column
x = x(:);
y = y(:);

% Sort by angle (very important!)
[x, order] = sort(x);
y = y(order);

if numel(x) < 5
    warning('fit_single_curve_shifted:TooFewPoints', ...
        'Too few points for fit in "%s" (n=%d).', traceLabel, numel(x));
    A = NaN; x0_deg = NaN; d = NaN;
    stats = [NaN NaN NaN NaN];
    fitobj = [];
    return;
end

% Initial guesses
A0 = (max(y) - min(y)) / 2;
d0 = mean(y);

% crude estimate for x0: angle of maximum
[~, idxMax] = max(y);
x0_0 = x(idxMax);

% fitting model
ft = fittype( ...
    'A * sin( f*(x - x0)*pi/180 ) + d', ...
    'independent','x', ...
    'coefficients',{'A','x0','d'}, ...
    'problem','f' ...
);

opts = fitoptions('Method','NonlinearLeastSquares', ...
                  'StartPoint',[A0, x0_0, d0], ...
                  'MaxIter', 2000, 'TolFun',1e-12);

[fitobj, g] = fit(x, y, ft, opts, 'problem', fold1);

A      = fitobj.A;
x0_deg = fitobj.x0;
d      = fitobj.d;

stats = [g.sse, g.rsquare, g.adjrsquare, g.rmse];
end
