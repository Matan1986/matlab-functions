function run = createSwitchingRunContext(repoRoot, cfg)
%CREATESWITCHINGRUNCONTEXT createRunContext('switching',...) with canonical pre-manifest checks.
%
% All Switching analysis scripts must allocate runs only via this helper (not
% createRunContext directly) so experiment tag and run_dir are enforced before
% run_manifest.json is written.

if nargin < 2 || ~isstruct(cfg)
    cfg = struct();
end
if nargin < 1 || isempty(char(string(repoRoot)))
    error('createSwitchingRunContext:repoRoot', 'repoRoot is required.');
end
repoRoot = char(string(repoRoot));

resolved = which('createRunContext');
if isempty(resolved)
    error('createSwitchingRunContext:createRunContextMissing', 'createRunContext not on path.');
end
repoFromAging = fileparts(fileparts(fileparts(resolved)));
a = lower(strrep(repoFromAging, '/', '\'));
b = lower(strrep(repoRoot, '/', '\'));
if ~strcmp(a, b)
    error('createSwitchingRunContext:repoRootMismatch', ...
        'repoRoot must match repository containing Aging/utils/createRunContext.m.');
end

cfg.beforeManifestWrite = @(run) assertSwitchingRunDirCanonical(run, repoRoot);
run = createRunContext('switching', cfg);

end
