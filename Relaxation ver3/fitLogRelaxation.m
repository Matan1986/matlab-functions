function [fitParams, R2, yFit] = fitLogRelaxation(t, M, T, debug, fitParamsIn)
% fitLogRelaxation  Fit logarithmic relaxation model: M(t) = M0 - S*log(t)
%
% Inputs:
%   t          - time vector (s)
%   M          - moment vector
%   T          - nominal temperature (for diagnostics)
%   debug      - debug flag
%   fitParamsIn - optional struct with fields:
%                 .minTimeForLog  (default 1e-6)
%
% Outputs:
%   fitParams  - struct with fields M0, S, Minf, dM, tau, n
%   R2         - coefficient of determination
%   yFit       - fitted curve on input t

if nargin < 4 || isempty(debug), debug = false; end
if nargin < 5 || isempty(fitParamsIn), fitParamsIn = struct(); end

if isfield(fitParamsIn, 'minTimeForLog')
    minTimeForLog = fitParamsIn.minTimeForLog;
else
    minTimeForLog = 1e-6;
end

% Prepare vectors and finite mask
x = t(:);
y = M(:);
maskFinite = isfinite(x) & isfinite(y);
x = x(maskFinite);
y = y(maskFinite);

% Guard against non-positive times for log
xSafe = max(x, minTimeForLog);

% Linear least squares on [1, -log(t)]
X = [ones(size(xSafe)), -log(xSafe)];
coeff = X \ y;
M0 = coeff(1);
S = coeff(2);

% Build fit and statistics
yFit = M0 - S * log(xSafe);
ssRes = nansum((y - yFit).^2);
ssTot = nansum((y - nanmean(y)).^2);
if ssTot > 0
    R2 = 1 - ssRes / ssTot;
else
    R2 = 1;
end

% Keep legacy fields for compatibility
fitParams = struct();
fitParams.M0 = M0;
fitParams.S = S;
fitParams.Minf = NaN;
fitParams.dM = NaN;
fitParams.tau = NaN;
fitParams.n = NaN;

if debug
    fprintf('LOG fit @ T=%.2f K: M0=%.4g, S=%.4g, R2=%.4f\n', T, M0, S, R2);
end
end
