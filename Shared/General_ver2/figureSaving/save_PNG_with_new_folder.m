function save_PNG_with_new_folder(base_directory, mode_flag, overwrite)
% save_PNG
% Saves all open MATLAB figures & UIFigures as PNG images.

if nargin < 3, overwrite = false; end       % ← חסר אצלך! קריטי!

if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end
if nargin < 2
    mode_flag = [];
end


% save_PNG
% Saves all open MATLAB figures & UIFigures as PNG images.
%
% שימוש:
%   save_PNG
%   save_PNG(dir)
%   save_PNG(dir,'f')
%   save_PNG(dir,'u')

%% --- Base directory ---
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

%% --- Choose folder by mode ---
if nargin < 2 || isempty(mode_flag)
    subfolder = 'PNGs';
else
    switch lower(mode_flag)
        case 'f'
            subfolder = 'Filtered PNGs';
        case 'u'
            subfolder = 'Unfiltered PNGs';
        otherwise
            warning('mode_flag "%s" אינו מוכר — משתמש בתיקיית PNGs רגילה.', mode_flag);
            subfolder = 'PNGs';
    end
end

%% --- Create directory ---
save_directory = fullfile(base_directory, subfolder);
if ~exist(save_directory, 'dir')
    mkdir(save_directory);
end

%% --- Find all figures (same as your save_all) ---
figs = findall(groot, 'Type', 'figure');

%% --- Save each figure ---
for i = 1:numel(figs)
    fig = figs(i);

    %% --- Skip GUI figures ---
    guiName = string(get(fig, 'Name'));

    % Automatic GUI detection (UIFigure / tools)
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));

    % Known GUIs to skip
    skipList = ["Appearance / Colormap Control", ...
        "refLineGUI", ...
        "Final Figure Formatter", ...
        "FigureTools"];

    if isGUIauto || any(guiName == skipList)
        fprintf("Skipping GUI: %s\n", guiName);
        continue;
    end


    % === Determine safe figure name ===
    rawName = get(fig, 'Name');
    if isempty(rawName)
        rawName = sprintf('Figure%d', fig.Number);
    end

    % Safe file-system friendly name
    safeName = regexprep(rawName, '[\\\/:\*\?"<>\|]', '_');

    % File path with unique name
    outFile = fullfile(save_directory, safeName + ".png");

    if overwrite
        pngFile = outFile;          % דורס
    else
        pngFile = unique_name(outFile);  % כמו היום
    end


    %% --- Save PNG using getframe (like JPEG version) ---
    try
        F = getframe(fig);
        imwrite(F.cdata, pngFile, 'png');
    catch ME
        warning('Failed to save PNG for "%s": %s', safeName, ME.message);
    end
end
end


%% === Unique filename helper ===
function fname = unique_name(base)
fname = base;
[p,n,e] = fileparts(base);
k = 1;
while exist(fname, 'file')
    fname = fullfile(p, sprintf('%s_%d%s', n, k, e));
    k = k + 1;
end
end
