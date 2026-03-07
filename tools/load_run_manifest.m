function manifest = load_run_manifest(runPath)
% load_run_manifest Read run_manifest.json from a run directory (or file path).
%
% Usage:
%   m = load_run_manifest('C:\repo\results\aging\runs\run_...');
%   m = load_run_manifest('C:\repo\results\aging\runs\run_...\run_manifest.json');

if nargin < 1 || isempty(runPath)
    error('load_run_manifest requires a run directory or manifest file path.');
end

runPath = char(string(runPath));
if isfolder(runPath)
    manifestPath = fullfile(runPath, 'run_manifest.json');
else
    manifestPath = runPath;
end

if exist(manifestPath, 'file') ~= 2
    error('run_manifest.json not found: %s', manifestPath);
end

raw = fileread(manifestPath);
manifest = jsondecode(raw);
end
