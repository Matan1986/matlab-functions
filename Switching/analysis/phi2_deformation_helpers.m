function varargout = phi2_deformation_helpers(action, varargin)
% phi2_deformation_helpers
% Shared helper routines for run_phi2_deformation_structure_test.m
switch action
    case 'unit_l2'
        [varargout{1}, varargout{2}] = localUnitL2(varargin{1});
    case 'fit_single_basis'
        [varargout{1}, varargout{2}, varargout{3}] = localFitSingleBasis(varargin{1}, varargin{2});
    case 'fit_two_basis'
        [varargout{1}, varargout{2}, varargout{3}, varargout{4}, varargout{5}] = localFitTwoBasis(varargin{1}, varargin{2}, varargin{3});
    case 'loo_two_basis'
        [varargout{1}, varargout{2}, varargout{3}, varargout{4}] = localLooTwoBasis(varargin{1}, varargin{2}, varargin{3});
    case 'stats'
        varargout{1} = localStats(varargin{1});
    otherwise
        error('phi2_deformation_helpers:UnknownAction', 'Unknown action: %s', string(action));
end

end

function [yn, m] = localUnitL2(y)
y = y(:);
m = find(isfinite(y));
if numel(m) < 5
    yn = NaN(size(y));
    return;
end
v = y(m);
nrm = norm(v);
if ~(isfinite(nrm) && nrm > eps)
    yn = NaN(size(y));
    return;
end
yn = NaN(size(y));
yn(m) = v / nrm;
end

function [c, r, alpha] = localFitSingleBasis(target, basis)
i1 = find(isfinite(target));
i2 = find(isfinite(basis));
idx = intersect(i1, i2, 'stable');
if numel(idx) < 5
    c = NaN; r = NaN; alpha = NaN;
    return;
end
t = target(idx);
b = basis(idx);
den = dot(b, b);
if ~(isfinite(den) && den > eps)
    c = NaN; r = NaN; alpha = NaN;
    return;
end
alpha = dot(t, b) / den;
yhat = alpha * b;
c = dot(t, yhat) / (norm(t) * norm(yhat) + eps);
r = sqrt(mean((t - yhat) .^ 2, 'omitnan'));
end

function [c, r, a, b, yhatFull] = localFitTwoBasis(target, b1, b2)
i1 = find(isfinite(target));
i2 = find(isfinite(b1));
i3 = find(isfinite(b2));
idx = intersect(intersect(i1, i2, 'stable'), i3, 'stable');
if numel(idx) < 5
    c = NaN; r = NaN; a = NaN; b = NaN; yhatFull = NaN(size(target));
    return;
end
t = target(idx);
X = [b1(idx), b2(idx)];
coef = X \ t;
a = coef(1);
b = coef(2);
yhat = X * coef;
c = dot(t, yhat) / (norm(t) * norm(yhat) + eps);
r = sqrt(mean((t - yhat) .^ 2, 'omitnan'));
yhatFull = NaN(size(target));
yhatFull(idx) = yhat;
end

function [aLoo, bLoo, cosLoo, rmseLoo] = localLooTwoBasis(target, b1, b2)
i1 = find(isfinite(target));
i2 = find(isfinite(b1));
i3 = find(isfinite(b2));
idxAll = intersect(intersect(i1, i2, 'stable'), i3, 'stable');
n = numel(idxAll);
aLoo = NaN(n, 1);
bLoo = NaN(n, 1);
cosLoo = NaN(n, 1);
rmseLoo = NaN(n, 1);
if n < 8
    return;
end
t = target(idxAll);
X = [b1(idxAll), b2(idxAll)];
for k = 1:n
    keepMask = true(n, 1);
    keepMask(k) = false;
    tk = t(keepMask);
    Xk = X(keepMask, :);
    if size(Xk, 1) < 5
        continue;
    end
    coef = Xk \ tk;
    aLoo(k) = coef(1);
    bLoo(k) = coef(2);
    yhat = X * coef;
    cosLoo(k) = dot(t, yhat) / (norm(t) * norm(yhat) + eps);
    rmseLoo(k) = sqrt(mean((t - yhat) .^ 2, 'omitnan'));
end
end

function s = localStats(v)
v = v(:);
m = isfinite(v);
if nnz(m) == 0
    s = struct('mean', NaN, 'std', NaN, 'min', NaN, 'max', NaN, 'cv', NaN);
    return;
end
vm = v(m);
s = struct();
s.mean = mean(vm, 'omitnan');
s.std = std(vm, 'omitnan');
s.min = min(vm, [], 'omitnan');
s.max = max(vm, [], 'omitnan');
s.cv = s.std / max(abs(s.mean), eps);
end
