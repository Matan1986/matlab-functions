function out = estimateRobustBaseline(T, Y, Tmin, cfg, varargin)
% Wrapper to canonical baseline estimator implementation.

if nargin >= 5
    out = estimateRobustBaseline_canonical(T, Y, Tmin, cfg, varargin{1});
else
    out = estimateRobustBaseline_canonical(T, Y, Tmin, cfg);
end

end