function importScientificColourMaps(rootDir, N)
% importScientificColourMaps
% Imports all ScientificColourMaps8 .mat files into base workspace as:
%   cmap_<name>
%
% Example:
%   importScientificColourMaps
%   importScientificColourMaps('C:\Dev\...\ScientificColourMaps8',256)

if nargin < 1 || isempty(rootDir)
    rootDir = 'C:\Dev\matlab-functions\github_repo\ScientificColourMaps8';
end

if nargin < 2
    N = [];
end

files = dir(fullfile(rootDir,'**','*.mat'));

for k = 1:numel(files)

    S = load(fullfile(files(k).folder,files(k).name));
    vars = fieldnames(S);

    for v = 1:numel(vars)

        name = vars{v};
        cmap = S.(name);

        % optional resample to N
        if ~isempty(N) && size(cmap,1) ~= N
            x  = linspace(0,1,size(cmap,1));
            xi = linspace(0,1,N);
            cmap = interp1(x,cmap,xi);
        end

        varName = ['cmap_' matlab.lang.makeValidName(lower(name))];

        assignin('base',varName,cmap);
    end
end

fprintf('Imported %d colormaps into base workspace.\n',numel(files));
end