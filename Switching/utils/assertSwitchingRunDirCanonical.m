function assertSwitchingRunDirCanonical(run, repoRoot)
%ASSERTSWITCHINGRUNDIRCANONICAL Enforce run_dir under switchingCanonicalRunRoot.

if nargin < 2 || isempty(repoRoot)
    error('assertSwitchingRunDirCanonical:repoRoot', 'repoRoot is required.');
end

canonical = switchingCanonicalRunRoot(repoRoot);
if ~isstruct(run) || ~isfield(run, 'run_dir') || isempty(run.run_dir)
    error('assertSwitchingRunDirCanonical:run_dir', 'run.run_dir is required.');
end

rd = lower(strrep(run.run_dir, '/', '\'));
cr = lower(strrep(canonical, '/', '\'));
if isempty(cr) || ~startsWith(rd, cr)
    error('assertSwitchingRunDirCanonical:violation', ...
        'run_dir must be under canonical runs root %s (got %s).', canonical, run.run_dir);
end

end
