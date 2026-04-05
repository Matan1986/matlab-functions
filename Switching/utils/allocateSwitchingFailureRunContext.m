function run = allocateSwitchingFailureRunContext(repoRoot, cfg)
%ALLOCATESWITCHINGFAILURERUNCONTEXT Allocate a canonical Switching run_dir for failure handling only.
%
% Uses createSwitchingRunContext only (full manifest + fingerprints). No alternate folders and
% no silent fallback: if allocation fails, this function throws.

if nargin < 2 || ~isstruct(cfg)
    error('allocateSwitchingFailureRunContext:cfg', 'cfg struct is required.');
end
run = createSwitchingRunContext(repoRoot, cfg);

end
