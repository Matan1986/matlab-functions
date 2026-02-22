function state = stage2_preprocess(state, cfg)
% =========================================================
% stage2_preprocess
%
% PURPOSE:
%   Apply unit conversion and preprocessing to imported data.
%
% INPUTS:
%   state - struct with noPause and pauseRuns data
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated data struct
%
% Physics meaning:
%   AFM = not used
%   FM  = not used
%
% =========================================================

% Step 3: Convert units to uB/Co if requested
if cfg.Bohar_units
    [state.noPause_M, state.pauseRuns] = convertToMuBperCo( ...
        state.noPause_M, state.pauseRuns);
end

end
