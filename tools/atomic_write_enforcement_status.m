function atomic_write_enforcement_status(runDir, enforcement_checked, modules_used, iBatch, batchSize)
% atomic_write_enforcement_status Write run_dir/enforcement_status.txt atomically.
% If iBatch or batchSize is empty, batch lines are omitted.

if nargin < 3
    error('atomic_write_enforcement_status requires runDir, enforcement_checked, modules_used.');
end
if nargin < 4
    iBatch = [];
end
if nargin < 5
    batchSize = [];
end

p = fullfile(char(string(runDir)), 'enforcement_status.txt');
atomic_write_text(p, @(fid) ae_status_body(fid, enforcement_checked, modules_used, iBatch, batchSize));
end

function ae_status_body(fid, enforcement_checked, modules_used, iBatch, batchSize)
if enforcement_checked
    fprintf(fid, 'ENFORCEMENT_CHECKED=YES\n');
else
    fprintf(fid, 'ENFORCEMENT_CHECKED=NO\n');
end
if isempty(modules_used)
    fprintf(fid, 'MODULES_USED=\n');
else
    fprintf(fid, 'MODULES_USED=%s\n', strjoin(modules_used, ','));
end
if ~isempty(iBatch) && ~isempty(batchSize)
    fprintf(fid, 'BATCH_INDEX=%d\n', iBatch);
    fprintf(fid, 'BATCH_SIZE=%d\n', batchSize);
end
end
