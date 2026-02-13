function out = estimate_fold_fourier_ls(thetaDeg, y, opts)
% estimate_fold_fourier_ls
% Robust harmonic decomposition for angular scans (AMR/HC/etc.)
% Works with non-uniform sampling and partial coverage.
%
% out fields:
%   .n          : (1:maxHarm)
%   .A, .B      : cosine/sine coeffs
%   .Amp        : sqrt(A.^2 + B.^2)
%   .phiDeg     : phase in degrees (atan2)
%   .R2         : goodness of fit (global)
%   .fold1      : dominant harmonic index (candidate fold)
%   .score      : dominance score Amp(1)/Amp(2) etc.
%   .yFit       : fitted signal at input theta
%
% opts:
%   .maxHarm    (default 12)
%   .doDetrend  (default true)
%   .removeMean (default true)
%   .useWeights (default false)  % if you have sigma per point
%   .w          (optional weights vector)

if nargin < 3, opts = struct(); end
if ~isfield(opts,'maxHarm'),    opts.maxHarm = 12; end
if ~isfield(opts,'doDetrend'),  opts.doDetrend = true; end
if ~isfield(opts,'removeMean'), opts.removeMean = true; end
if ~isfield(opts,'useWeights'), opts.useWeights = false; end

thetaDeg = thetaDeg(:);
y        = y(:);

% sort by angle (important for plotting, not required for LS)
[thetaDeg, idx] = sort(thetaDeg);
y = y(idx);

% preprocess
y0 = y;
if opts.removeMean
    y0 = y0 - mean(y0,'omitnan');
end
if opts.doDetrend
    y0 = detrend(y0);
end

maxH = opts.maxHarm;
nvec = (1:maxH).';

% design matrix: [1, cos(θ), sin(θ), cos(2θ), sin(2θ), ...]
X = ones(numel(thetaDeg), 1);
for n = 1:maxH
    X = [X, cosd(n*thetaDeg), sind(n*thetaDeg)]; %#ok<AGROW>
end

% weights (optional)
if opts.useWeights && isfield(opts,'w') && numel(opts.w)==numel(y0)
    w = opts.w(:);
    W = diag(w);
    beta = (X'*W*X)\(X'*W*y0);
    yFit = X*beta;
else
    beta = X\y0;
    yFit = X*beta;
end

% extract coefficients
a0 = beta(1);
A  = zeros(maxH,1);
B  = zeros(maxH,1);
for n = 1:maxH
    A(n) = beta(2*n);
    B(n) = beta(2*n+1);
end

Amp    = hypot(A,B);
phiDeg = atan2d(B,A);

% goodness of fit
res  = y0 - yFit;
SSE  = sum(res.^2,'omitnan');
SST  = sum((y0 - mean(y0,'omitnan')).^2,'omitnan');
R2   = 1 - SSE/max(SST,eps);

% choose dominant harmonic (avoid n=1 if you expect even symmetry)
[ampSorted, is] = sort(Amp,'descend');
fold1 = is(1);
score = ampSorted(1)/max(ampSorted(2),eps);

out = struct();
out.thetaDeg = thetaDeg;
out.yUsed    = y0;
out.yFit     = yFit + a0; % include DC from fit (after preprocess it’s small anyway)
out.n        = nvec;
out.A        = A;
out.B        = B;
out.Amp      = Amp;
out.phiDeg   = phiDeg;
out.R2       = R2;
out.fold1    = fold1;
out.score    = score;

end
