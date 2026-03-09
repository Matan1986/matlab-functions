function r = safeCorr(a, b, minPoints)
if nargin < 3 || isempty(minPoints)
    minPoints = 3;
end

if isempty(a) || isempty(b)
    r = NaN;
    return;
end

v = isfinite(a) & isfinite(b);
if nnz(v) < minPoints
    r = NaN;
    return;
end

r = corr(a(v), b(v), 'rows', 'complete');
end