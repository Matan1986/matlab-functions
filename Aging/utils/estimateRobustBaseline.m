function out = estimateRobustBaseline(T, Y, Tmin, cfg, varargin)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Utility wrapper entrypoint to canonical robust baseline estimator.
%
% DECOMPOSITION TYPE:
% DIRECT
%
% STAGE:
% other
%
% DOES:
% - forward baseline estimation calls to estimateRobustBaseline_canonical
%
% DOES NOT:
% - implement decomposition logic by itself
% - define stage6 summary observables
%
% AFFECTS SUMMARY OBSERVABLES:
% NO
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
% Wrapper to canonical baseline estimator implementation.

% [DIRECT_DECOMPOSITION]
if nargin >= 5
    out = estimateRobustBaseline_canonical(T, Y, Tmin, cfg, varargin{1});
else
    out = estimateRobustBaseline_canonical(T, Y, Tmin, cfg);
end

end
