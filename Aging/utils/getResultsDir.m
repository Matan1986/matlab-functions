function outDir = getResultsDir(experiment, analysis, varargin)
% getResultsDir Return standardized results directory and create it if needed.
%
% Usage:
%   outDir = getResultsDir('aging', 'svd_pca');
%   outDir = getResultsDir('cross_analysis', 'aging_vs_switching', 'subdir');
%
% Run-aware behavior:
%   If an active run context exists, paths resolve to:
%   results/<experiment>/runs/<run_id>/<analysis>/...
%   Otherwise, legacy behavior is preserved:
%   results/<experiment>/<analysis>/...

if nargin < 2
    error('getResultsDir requires at least experiment and analysis.');
end

experiment = char(string(experiment));
analysis = char(string(analysis));

thisFile = mfilename('fullpath');
utilsDir = fileparts(thisFile);
agingDir = fileparts(utilsDir);
repoRoot = fileparts(agingDir);

runCtx = getActiveRunContext();
if ~isempty(runCtx) && isfield(runCtx, 'run_id') && ~isempty(runCtx.run_id)
    outDir = fullfile(repoRoot, 'results', experiment, 'runs', runCtx.run_id, analysis, varargin{:});
else
    outDir = fullfile(repoRoot, 'results', experiment, analysis, varargin{:});
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end
end

function runCtx = getActiveRunContext()
runCtx = [];
keys = {'runContext', 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT'};

for i = 1:numel(keys)
    key = keys{i};
    if isappdata(0, key)
        candidate = getappdata(0, key);
        if isstruct(candidate) && isfield(candidate, 'run_id') && ~isempty(candidate.run_id)
            runCtx = candidate;
            return;
        end
    end
end
end
