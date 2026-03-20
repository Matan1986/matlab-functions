% Compatibility shim (auto-generated cleanup shim).
% Deprecated root entrypoint: moved to runs/experimental/run_geometry_deformation_wrapper.m

shimDir = fileparts(mfilename('fullpath'));
targetPath = fullfile(shimDir, 'runs', 'experimental', 'run_geometry_deformation_wrapper.m');
if exist(targetPath, 'file') ~= 2
    error('run_geometry_deformation_wrapper:MissingTarget', 'Moved wrapper not found: %s', targetPath);
end
warning('run_geometry_deformation_wrapper:DeprecatedEntrypoint', ...
    ['Deprecated root entrypoint. Use runs/experimental/run_geometry_deformation_wrapper.m instead. ', ...
     'This compatibility shim will be removed in a future cleanup.']);

prevDir = pwd;
cleanupObj = onCleanup(@() cd(prevDir)); %#ok<NASGU>
cd(shimDir);
run(targetPath);
