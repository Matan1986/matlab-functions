function outDir = getResultsDir(experiment, analysis, varargin)
% getResultsDir Return standardized results directory and create it if needed.
%
% Usage:
%   outDir = getResultsDir('aging', 'svd_pca');
%   outDir = getResultsDir('cross_analysis', 'aging_vs_switching', 'subdir');

if nargin < 2
    error('getResultsDir requires at least experiment and analysis.');
end

experiment = char(string(experiment));
analysis = char(string(analysis));

thisFile = mfilename('fullpath');
utilsDir = fileparts(thisFile);
agingDir = fileparts(utilsDir);
repoRoot = fileparts(agingDir);

outDir = fullfile(repoRoot, 'results', experiment, analysis, varargin{:});
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
end
