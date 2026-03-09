function plotDecompositionExamples(state, cfg)
% =========================================================
% plotDecompositionExamples
%
% PURPOSE:
%   Plot AFM/FM decomposition for selected pauses.
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   none (creates figures)
%
% =========================================================

allPauseK = [state.pauseRuns.waitK];

if cfg.showAllPauses_AFmFM
    pauseList = allPauseK;
else
    pauseList = cfg.examplePause_K;
end

for k = 1:numel(pauseList)

    Tp_req = pauseList(k);
    idx = find(allPauseK == Tp_req, 1);

    if isempty(idx)
        warning('Requested pause %.1f K not found. Skipping.', Tp_req);
        continue;
    end

    plotAFM_FM_decomposition(state.pauseRuns(idx));

end

end
