function [statusValue, statusPath] = get_run_status_value(runDir)
% get_run_status_value Read or initialize run_status.csv for a run directory.

runDir = char(string(runDir));
if exist(runDir, 'dir') ~= 7
    error('Run directory does not exist: %s', runDir);
end

statusPath = fullfile(runDir, 'run_status.csv');
if exist(statusPath, 'file') ~= 2
    write_default_status(statusPath, 'INVALID');
    statusValue = "INVALID";
    return;
end

statusValue = "INVALID";
try
    t = readtable(statusPath, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    if ~isempty(t)
        vnames = lower(strtrim(string(t.Properties.VariableNames)));
        idx = find(vnames == "run_status", 1);
        if ~isempty(idx)
            value = string(t{1, idx});
        elseif width(t) >= 2
            keyCol = string(t{:, 1});
            valCol = string(t{:, 2});
            keyHit = find(lower(strtrim(keyCol)) == "run_status", 1);
            if ~isempty(keyHit)
                value = valCol(keyHit);
            else
                value = string(t{1, 1});
            end
        else
            value = string(t{1, 1});
        end
        statusValue = upper(strtrim(value));
    end
catch
    statusValue = "INVALID";
end

if ~ismember(statusValue, ["CANONICAL", "PARTIAL", "INVALID"])
    statusValue = "INVALID";
end
end

function write_default_status(statusPath, value)
fid = fopen(statusPath, 'w');
if fid < 0
    error('Failed to create run status file: %s', statusPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'run_status\n');
fprintf(fid, '%s\n', char(string(value)));
end
