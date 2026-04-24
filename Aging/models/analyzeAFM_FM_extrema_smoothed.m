function result = analyzeAFM_FM_extrema_smoothed(run)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Stage4 extrema-based extractor for alternate AFM/FM observables.
%
% DECOMPOSITION TYPE:
% EXTREMA
%
% STAGE:
% stage4
%
% DOES:
% - smooth DeltaM with movmean
% - define extrema-based FM and AFM scalar quantities
%
% DOES NOT:
% - run tanh+Gaussian fitting
% - define default stage6 summary observables
%
% AFFECTS SUMMARY OBSERVABLES:
% YES
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
% ============================================================
% DIRECT DECOMPOSITION FAMILY - CANONICAL DOCUMENTATION
%
% OVERVIEW:
% All direct methods share the same physical structure:
%   DeltaM(T) = smooth background (FM-like) + dip (AFM-like)
%
% The dip extraction is IDENTICAL across variants:
%   dip = DeltaM - DeltaM_smooth
%
% The ONLY major difference between variants is how FM is defined.
%
% ------------------------------------------------------------
% VARIANTS:
%
% 1) CORE DIRECT
%    - FM: mean of two fixed plateau windows (left/right of dip)
%    - Local, window-based estimate
%
% 2) DERIVATIVE-ASSISTED DIRECT
%    - FM: median of all points outside dip window
%    - Global baseline estimate
%    - Derivative used for diagnostics only (not FM itself)
%
% 3) ROBUST-BASELINE DIRECT
%    - FM: median of automatically selected flat regions
%    - Robust to noise and outliers
%
% 4) EXTREMA-BASED (PARTIAL)
%    - Uses local extrema heuristics
%    - Not a full direct decomposition
%
% ------------------------------------------------------------
% IMPORTANT:
% - All variants share the SAME dip definition
% - Differences in AFM come ONLY from differences in FM
% - Changing FM changes AFM quantitatively
%
% DEFAULT BEHAVIOR:
% The default runtime path is:
%   derivative-assisted direct (FM override)
%
% ------------------------------------------------------------
% NOTE TO DEVELOPERS:
% Do NOT assume "direct" is a single method.
% Always specify which FM definition is used.
% ============================================================
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

% [EXTREMA_BASED]
M_s = movmean(M_work, 11);
result.M_smoothed_extrema = M_s;
% FM DEFINITION:
% This line defines FM using extrema-based partial direct-like extraction:
% global maximum of the smoothed DeltaM trace.
result.FM_extrema_smoothed = max(M_s);
result.AFM_extrema_smoothed = min(M_s);

end
