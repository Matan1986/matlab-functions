function runsRoot = switchingCanonicalRunRoot(repoRoot)
%SWITCHINGCANONICALRUNROOT Single canonical Switching run root: results/switching/runs.
%
%   runsRoot = switchingCanonicalRunRoot()
%   runsRoot = switchingCanonicalRunRoot(repoRoot)
%
% When repoRoot is omitted, it is derived from this file's location
% (Switching/utils -> repository root).

if nargin < 1 || isempty(repoRoot)
    thisFile = mfilename('fullpath');
    utilsDir = fileparts(thisFile);
    switchingDir = fileparts(utilsDir);
    repoRoot = fileparts(switchingDir);
end

runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');

end
