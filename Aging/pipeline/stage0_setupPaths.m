function cfg = stage0_setupPaths(cfg)
% =========================================================
% stage0_setupPaths
%
% PURPOSE:
%   Configure paths, extract sample metadata, and initialize run context.
%
% INPUTS:
%   cfg - configuration struct
%
% OUTPUTS:
%   cfg - updated with sample_name and path setup
%
% Physics meaning:
%   AFM = not used
%   FM  = not used
%
% =========================================================

% Ensure local pipeline/models/plots/utils are on path
pipelineRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(pipelineRoot);
addpath(genpath(repoRoot));

% Add shared base folder if provided
if isfield(cfg, 'baseFolder') && ~isempty(cfg.baseFolder)
    addpath(genpath(cfg.baseFolder));
end

% Extract sample info
[growth_num, FIB_num] = extract_growth_FIB(cfg.dataDir, []);
cfg.growth_num = growth_num;
cfg.FIB_num = FIB_num;
cfg.sample_name = sprintf('MG %d', growth_num);

% Initialize run context (used by getResultsDir for run-scoped outputs)
if ~isfield(cfg, 'run') || ~isstruct(cfg.run) || ~isfield(cfg.run, 'run_id') || isempty(cfg.run.run_id)
    cfg.run = createRunContext('aging', cfg);
else
    setappdata(0, 'runContext', cfg.run);
    setappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT', cfg.run);
end

% Initialize debug output folder if enabled
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    if ~isfield(cfg.debug, 'runTag') || isempty(cfg.debug.runTag)
        cfg.debug.runTag = datestr(now, 'yyyymmdd_HHMMSS');
    end

    legacyDefaultDebugRoot = fullfile(repoRoot, 'results', 'aging', 'debug_runs');
    shouldUseRunScopedRoot = ~isfield(cfg.debug, 'outputRoot') || isempty(cfg.debug.outputRoot) || ...
        strcmpi(normalizePathForCompare(cfg.debug.outputRoot), normalizePathForCompare(legacyDefaultDebugRoot));

    if shouldUseRunScopedRoot
        cfg.debug.outputRoot = getResultsDir('aging', 'debug_runs');
    end

    cfg.debug.outFolder = fullfile(cfg.debug.outputRoot, cfg.debug.runTag);
end

end

function p = normalizePathForCompare(p)
if isempty(p)
    p = '';
    return;
end
p = char(string(p));
p = strrep(p, '/', filesep);
p = strrep(p, '\\', filesep);
if ~isempty(p) && (p(end) == filesep)
    p = p(1:end-1);
end
end

