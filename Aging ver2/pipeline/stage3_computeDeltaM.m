function state = stage3_computeDeltaM(state, cfg)
% =========================================================
% stage3_computeDeltaM
%
% PURPOSE:
%   Construct DeltaM(T) for each pause run.
%
% INPUTS:
%   state - struct with noPause and pauseRuns data
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated with pauseRuns and pauseRuns_raw
%
% Physics meaning:
%   AFM = dip in DeltaM (memory)
%   FM  = smooth background in DeltaM
%
% =========================================================

[state.pauseRuns, state.pauseRuns_raw] = computeDeltaM( ...
    state.noPause_T, state.noPause_M, state.pauseRuns, ...
    cfg.dip_window_K, cfg.subtractOrder, ...
    cfg.alignDeltaM, cfg.alignRef, cfg.alignWindow_K, ...
    cfg.doFilterDeltaM, cfg.filterMethod, cfg.sgolayOrder, cfg.sgolayFrame);

end
