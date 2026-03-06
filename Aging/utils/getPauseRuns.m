function pauseRuns = getPauseRuns(state)
% =========================================================
% getPauseRuns — Robust accessor for pauseRuns across pipeline
% =========================================================
%
% PURPOSE:
%   Safely retrieve pauseRuns from state struct, which may be stored
%   in different locations depending on pipeline stage/variant.
%
% SYNTAX:
%   pauseRuns = getPauseRuns(state)
%
% INPUT:
%   state - pipeline state struct
%
% OUTPUT:
%   pauseRuns - struct array with pause run data
%
% SEARCH ORDER:
%   1. state.pauseRuns
%   2. state.stage7.pauseRuns
%   3. state.stage6.pauseRuns
%
% ERROR:
%   Raises informative error if pauseRuns not found in any location,
%   listing all available fields for debugging.
%
% EXAMPLES:
%   pauseRuns = getPauseRuns(state);
%   Tp = [pauseRuns.waitK];
%   n = numel(pauseRuns);
%
% =========================================================

% Check direct location
if isfield(state, 'pauseRuns') && ~isempty(state.pauseRuns)
    pauseRuns = state.pauseRuns;
    return;
end

% Check stage7
if isfield(state, 'stage7') && isfield(state.stage7, 'pauseRuns') && ~isempty(state.stage7.pauseRuns)
    pauseRuns = state.stage7.pauseRuns;
    return;
end

% Check stage6
if isfield(state, 'stage6') && isfield(state.stage6, 'pauseRuns') && ~isempty(state.stage6.pauseRuns)
    pauseRuns = state.stage6.pauseRuns;
    return;
end

% Not found — provide helpful error
available = strjoin(fieldnames(state), ', ');
error(['pauseRuns not found in state. Checked:', newline, ...
       '  - state.pauseRuns', newline, ...
       '  - state.stage7.pauseRuns', newline, ...
       '  - state.stage6.pauseRuns', newline, ...
       'Available top-level fields: %s'], available);

end
