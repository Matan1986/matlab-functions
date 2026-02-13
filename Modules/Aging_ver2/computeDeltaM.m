function [pauseRuns, pauseRuns_raw] = computeDeltaM( ...
    noPause_T, noPause_M, pauseRuns, ...
    dip_window_K, subtractOrder, ...
    alignDeltaM, alignRef, alignWindow_K, ...
    doFilterDeltaM, filterMethod, sgolayOrder, sgolayFrame)

pauseRuns = analyzeAgingMemory( ...
    noPause_T, noPause_M, pauseRuns, dip_window_K, subtractOrder);

pauseRuns_raw = pauseRuns;

fprintf('\n=== Aging ΔM subtraction convention ===\n');
fprintf('ΔM definition: %s\n', pauseRuns(1).DeltaM_definition);
fprintf('======================================\n\n');

if alignDeltaM
    pauseRuns = alignDeltaM_y(pauseRuns, alignRef, alignWindow_K);
end

if doFilterDeltaM
    pauseRuns = filterAgingMemory( ...
        pauseRuns, filterMethod, sgolayOrder, sgolayFrame);
end
end
