function state = stage1_loadData(cfg)
% =========================================================
% stage1_loadData
%
% PURPOSE:
%   Load no-pause and pause data files into memory.
%
% INPUTS:
%   cfg - configuration struct
%
% OUTPUTS:
%   state - struct with noPause and pauseRuns data
%
% Physics meaning:
%   AFM = not used
%   FM  = not used
%
% =========================================================

state = struct();

% Step 1: Get file list
[state.file_noPause, state.pauseRuns] = getFileList_aging(cfg.dataDir);

% Step 2: Import data
[state.noPause_T, state.noPause_M] = importFiles_aging( ...
    state.file_noPause, cfg.normalizeByMass, cfg.debugMode);

for i = 1:numel(state.pauseRuns)
    [state.pauseRuns(i).T, state.pauseRuns(i).M] = importFiles_aging( ...
        state.pauseRuns(i).file, cfg.normalizeByMass, cfg.debugMode);
end

end
