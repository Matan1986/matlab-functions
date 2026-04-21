function atomic_write_text(finalPath, writeFcn)
% atomic_write_text Write text via writeFcn(fid) to temp file, then commit to finalPath.
% writeFcn must be a function handle taking one file id (scalar double).

if nargin < 2 || ~isa(writeFcn, 'function_handle')
    error('atomic_write_text requires finalPath and writeFcn function handle.');
end
thisDir = fileparts(mfilename('fullpath'));
if exist(fullfile(thisDir, 'atomic_commit_file.m'), 'file') == 2
    addpath(thisDir);
end
finalPath = char(string(finalPath));
tmpPath = [finalPath '.tmp'];
fid = fopen(tmpPath, 'w');
if fid < 0
    error('atomic_write_text:OpenFailed', 'Cannot open %s', tmpPath);
end
try
    writeFcn(fid);
catch ME
    fclose(fid);
    if exist(tmpPath, 'file') == 2
        delete(tmpPath);
    end
    rethrow(ME);
end
fclose(fid);
atomic_commit_file(tmpPath, finalPath);
end
