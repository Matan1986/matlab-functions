function save_PNG(base_directory, overwrite)
% save_PNG
% ---------------------------------------------------------
% Saves all open MATLAB figures as PNG images
% directly into base_directory (NO subfolders).
%
% INPUTS:
%   base_directory (optional) : folder to save PNGs (default: pwd)
%   overwrite      (optional) : true  -> overwrite existing files
%                               false -> auto-generate unique names

if nargin < 2, overwrite = false; end
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

if ~exist(base_directory, 'dir')
    mkdir(base_directory);
end

%% --- Find all figures ---
figs = findall(groot, 'Type', 'figure');

%% --- Known GUI figures to skip ---
skipList = [ ...
    "Appearance / Colormap Control", ...
    "refLineGUI", ...
    "Final Figure Formatter", ...
    "FigureTools" ...
    ];

%% --- Save each figure ---
for i = 1:numel(figs)
    fig = figs(i);

    figName = string(get(fig, 'Name'));

    % Automatic GUI detection
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));

    if isGUIauto || any(figName == skipList)
        fprintf("Skipping GUI: %s\n", figName);
        continue;
    end

    %% --- Determine safe figure name ---
    if figName == ""
        figName = sprintf('Figure%d', fig.Number);
    end

    safeName = sanitizeFilename(figName);
    outFile = fullfile(base_directory, safeName + ".png");

    if overwrite
        pngFile = outFile;
    else
        pngFile = unique_name(outFile);
    end

    %% --- Save PNG ---
    try
        F = getframe(fig);
        imwrite(F.cdata, pngFile, 'png');
        fprintf("Saved PNG: %s\n", pngFile);
    catch ME
        warning('Failed to save PNG for "%s": %s', safeName, ME.message);
    end
end

fprintf("Done saving all PNG files.\n");
end

%% ---------------------------------------------------------
function fname = unique_name(base)
fname = base;
[p,n,e] = fileparts(base);
k = 1;
while exist(fname, 'file')
    fname = fullfile(p, sprintf('%s_%d%s', n, k, e));
    k = k + 1;
end
end
