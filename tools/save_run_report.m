function outPath = save_run_report(report_text, report_name, run_output_dir)
% save_run_report Save a text report into the canonical run reports directory.
%
% Usage:
%   outPath = save_run_report(reportText, 'run_summary.md', run_output_dir)
%   outPath = save_run_report(reportText, 'interpretation_notes', run_output_dir)
%
% Inputs:
%   report_text     - Text, string, or char content to write
%   report_name     - Filename with or without .txt/.md extension
%   run_output_dir  - Run root directory, e.g. results/<experiment>/runs/run_...
%
% Output:
%   outPath         - Full path written to disk

if nargin < 3
    error('save_run_report requires report_text, report_name, and run_output_dir.');
end

report_name = char(string(report_name));
run_output_dir = char(string(run_output_dir));
if isempty(strtrim(report_name))
    error('save_run_report requires a non-empty report_name.');
end
if isempty(strtrim(run_output_dir))
    error('save_run_report requires a non-empty run_output_dir.');
end

if isstring(report_text)
    report_text = strjoin(report_text, newline);
elseif ischar(report_text)
    % keep as-is
else
    error('save_run_report requires report_text to be string or char content.');
end

report_text = char(report_text);

[~, baseName, ext] = fileparts(report_name);
if isempty(ext)
    ext = '.txt';
    fileName = [baseName ext];
else
    fileName = [baseName ext];
end

ext = lower(ext);
if ~ismember(ext, {'.txt', '.md'})
    error('save_run_report supports only .txt and .md outputs.');
end

run_output_dir = resolve_run_root(run_output_dir);
reports_dir = fullfile(run_output_dir, 'reports');
if exist(reports_dir, 'dir') ~= 7
    mkdir(reports_dir);
end

outPath = fullfile(reports_dir, fileName);
fid = fopen(outPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('save_run_report could not open %s for writing.', outPath);
end

cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', report_text);
clear cleanupObj;

fprintf('Saved report: %s\n', outPath);
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