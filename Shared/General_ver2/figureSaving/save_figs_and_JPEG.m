function save_figs_and_JPEG(base_directory)
% save_figs_and_JPEG
% ---------------------------------------------------------
% Saves all open MATLAB figures as BOTH .fig and .jpg
% directly into base_directory (NO subfolders).
%
% USAGE:
%   save_figs_and_JPEG
%   save_figs_and_JPEG(dir)

%% --- Base directory ---
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

if ~exist(base_directory, 'dir')
    mkdir(base_directory);
end

%% --- Find all figures ---
figs = findall(groot, 'Type', 'figure');

%% --- Known GUIs to skip ---
skipList = [ ...
    "Appearance / Colormap Control", ...
    "refLineGUI", ...
    "Final Figure Formatter", ...
    "FigureTools" ...
    ];

%% --- Loop over all figures ---
for i = 1:numel(figs)
    fig = figs(i);

    figName = string(get(fig, 'Name'));

    % Automatic GUI detection
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));

    if isGUIauto || any(figName == skipList)
        fprintf("Skipping GUI: %s\n", figName);
        continue;
    end

    %% --- Safe figure name ---
    if figName == ""
        figName = sprintf('Figure%d', fig.Number);
    end

    safeName = regexprep(figName, '[\\\/:\*\?"<>\|]', '_');

    %% --- Save .FIG ---
    figFile = unique_name(fullfile(base_directory, safeName + ".fig"));
    try
        savefig(fig, figFile);
        fprintf("Saved FIG:  %s\n", figFile);
    catch
        % UIFigure or unsupported → silently skip
    end

    %% --- Save .JPEG ---
    jpegFile = unique_name(fullfile(base_directory, safeName + ".jpg"));
    try
        F = getframe(fig);
        imwrite(F.cdata, jpegFile, 'jpg', 'Quality', 95);
        fprintf("Saved JPEG: %s\n", jpegFile);
    catch ME
        warning('Failed to save JPEG for "%s": %s', safeName, ME.message);
    end
end

fprintf("Done saving FIG + JPEG files.\n");
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
