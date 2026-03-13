function metadata_path = write_repair_metadata(output_directory, metadata)
% write_repair_metadata Write figure repair metadata as JSON.

if nargin < 2
    error('write_repair_metadata:InvalidInput', ...
        'write_repair_metadata requires output_directory and metadata.');
end

output_directory = char(string(output_directory));
if isempty(strtrim(output_directory))
    error('write_repair_metadata:InvalidOutputDir', 'A non-empty output_directory is required.');
end
if exist(output_directory, 'dir') ~= 7
    mkdir(output_directory);
end
if ~isstruct(metadata)
    error('write_repair_metadata:InvalidMetadata', 'metadata must be a struct.');
end

metadata = populate_required_fields(metadata);
metadata_path = fullfile(output_directory, 'repair_metadata.json');
json_text = jsonencode(metadata);
write_text_file(metadata_path, json_text);
end

function metadata = populate_required_fields(metadata)
metadata = set_default_field(metadata, 'source_figure', 'unknown');
metadata = set_default_field(metadata, 'source_path', '');
metadata = set_default_field(metadata, 'source_run', '');
metadata = set_default_field(metadata, 'repair_date', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')));
metadata = set_default_field(metadata, 'style_guide_version', resolve_style_guide_version());
metadata = set_default_field(metadata, 'repair_actions', {});
metadata = set_default_field(metadata, 'repair_classification', 'manual_review_required');
metadata = set_default_field(metadata, 'repair_requested_by', resolve_requested_by());
metadata = set_default_field(metadata, 'inspection_summary', struct());
metadata = set_default_field(metadata, 'quality_check_result', struct('issue_count', 0, 'issues', struct('id', {}, 'message', {})));
metadata = set_default_field(metadata, 'repair_warnings', {});
end

function metadata = set_default_field(metadata, field_name, default_value)
if ~isfield(metadata, field_name) || isempty(metadata.(field_name))
    metadata.(field_name) = default_value;
end
end

function requested_by = resolve_requested_by()
requested_by = getenv('USERNAME');
if isempty(requested_by)
    requested_by = getenv('USER');
end
if isempty(requested_by)
    requested_by = 'unknown';
end
end

function version = resolve_style_guide_version()
version = 'unknown';
this_file = mfilename('fullpath');
repo_root = fileparts(fileparts(fileparts(this_file)));
style_guide_path = fullfile(repo_root, 'docs', 'figure_style_guide.md');
if exist(style_guide_path, 'file') ~= 2
    return;
end

try
    content = fileread(style_guide_path);
    token = regexp(content, 'Last updated:\s*([^\r\n]+)', 'tokens', 'once');
    if ~isempty(token)
        version = strtrim(token{1});
    end
catch
    version = 'unknown';
end
end

function write_text_file(file_path, text_value)
fid = fopen(file_path, 'w');
if fid == -1
    error('write_repair_metadata:FileOpenFailed', 'Unable to write metadata file: %s', file_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text_value);
end
