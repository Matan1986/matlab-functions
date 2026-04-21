function result = analyzeAFM_FM_extrema_smoothed(run)
% analyzeAFM_FM_extrema_smoothed
%
% New simple extraction mode:
%   1) take raw M(T) trace
%   2) smooth with movmean window 11
%   3) FM = max(M_s), AFM = min(M_s)

result = struct();

result.FM_extrema_smoothed = NaN;
result.AFM_extrema_smoothed = NaN;
result.M_smoothed_extrema = [];

if ~isfield(run, 'DeltaM') || isempty(run.DeltaM)
    return;
end

M = run.DeltaM(:);
valid = isfinite(M);
if ~any(valid)
    return;
end

M_work = M;
if any(~valid)
    idx = find(valid);
    M_work(~valid) = interp1(idx, M(valid), find(~valid), 'linear', 'extrap');
end

M_s = movmean(M_work, 11);
result.M_smoothed_extrema = M_s;
result.FM_extrema_smoothed = max(M_s);
result.AFM_extrema_smoothed = min(M_s);

end
