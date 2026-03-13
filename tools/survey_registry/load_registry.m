function registry = load_registry(registryPath)
% load_registry Load the rolling survey registry JSON file.
%
% Usage:
%   registry = load_registry();
%   registry = load_registry('C:\repo\surveys\registry.json');

if nargin < 1 || isempty(registryPath)
    thisFile = mfilename('fullpath');
    toolDir = fileparts(thisFile);
    repoRoot = fileparts(fileparts(toolDir));
    registryPath = fullfile(repoRoot, 'surveys', 'registry.json');
end

registryPath = char(string(registryPath));
if exist(registryPath, 'file') ~= 2
    error('Survey registry not found: %s', registryPath);
end

registry = jsondecode(fileread(registryPath));

if ~isstruct(registry) || ~isfield(registry, 'surveys')
    error('Invalid survey registry format: missing "surveys" field.');
end
end
