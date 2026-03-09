function outPath = save_run_table(table_data, table_name, run_output_dir)
% save_run_table Save a numeric table into the canonical run tables directory.
%
% Usage:
%   outPath = save_run_table(T, 'observables.csv', run_output_dir)
%   outPath = save_run_table(T, 'fit_summary', run_output_dir)
%
% Inputs:
%   table_data      - MATLAB table to save
%   table_name      - Filename with or without .csv/.tsv extension
%   run_output_dir  - Run root directory, e.g. results/<experiment>/runs/run_...
%
% Output:
%   outPath         - Full path written to disk

if nargin < 3
    error('save_run_table requires table_data, table_name, and run_output_dir.');
end
if ~istable(table_data)
    error('save_run_table requires table_data to be a MATLAB table.');
end

table_name = char(string(table_name));
run_output_dir = char(string(run_output_dir));
if isempty(strtrim(table_name))
    error('save_run_table requires a non-empty table_name.');
end
if isempty(strtrim(run_output_dir))
    error('save_run_table requires a non-empty run_output_dir.');
end

[~, baseName, ext] = fileparts(table_name);
if isempty(ext)
    ext = '.csv';
    fileName = [baseName ext];
else
    fileName = [baseName ext];
end

ext = lower(ext);
if ~ismember(ext, {'.csv', '.tsv'})
    error('save_run_table supports only .csv and .tsv outputs.');
end

run_output_dir = resolve_run_root(run_output_dir);
tables_dir = fullfile(run_output_dir, 'tables');
if exist(tables_dir, 'dir') ~= 7
    mkdir(tables_dir);
end

outPath = fullfile(tables_dir, fileName);
if strcmp(ext, '.tsv')
    writetable(table_data, outPath, 'FileType', 'text', 'Delimiter', '\t');
else
    writetable(table_data, outPath);
end

fprintf('Saved table: %s\n', outPath);
end

function run_root_dir = resolve_run_root(run_output_dir)
run_output_dir = char(string(run_output_dir));
run_root_dir = run_output_dir;

while true
    [parentDir, dirName, ext] = fileparts(run_root_dir);
    if isempty(dirName) && isempty(ext)
        break;
    end

    fullName = [dirName ext];
    if startsWith(string(fullName), "run_", 'IgnoreCase', true)
        return;
    end

    if strcmp(parentDir, run_root_dir)
        break;
    end

    run_root_dir = parentDir;
end

run_root_dir = run_output_dir;
end