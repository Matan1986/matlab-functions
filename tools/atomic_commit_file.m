function atomic_commit_file(tmpPath, finalPath)
% atomic_commit_file Replace finalPath with tmpPath (delete final then move).
% Used for atomic artifact commits under run_dir.

if nargin < 2
    error('atomic_commit_file requires tmpPath and finalPath.');
end
tmpPath = char(string(tmpPath));
finalPath = char(string(finalPath));
if exist(tmpPath, 'file') ~= 2
    error('atomic_commit_file:MissingTmp', 'Temporary file missing: %s', tmpPath);
end
if exist(finalPath, 'file') == 2
    delete(finalPath);
end
movefile(tmpPath, finalPath, 'f');
end
