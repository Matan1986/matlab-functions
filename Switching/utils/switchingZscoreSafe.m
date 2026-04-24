function z = switchingZscoreSafe(x)
%SWITCHINGZSCORESAFE Z-score with safe handling of degenerate variance.

z = NaN(size(x));
v = isfinite(x);
if nnz(v) < 2, return; end
mu = mean(x(v), 'omitnan');
sd = std(x(v), 'omitnan');
if sd <= 0, return; end
z(v) = (x(v) - mu) ./ sd;
end
