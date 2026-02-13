function save_JPEG_with_new_folder(base_directory, mode_flag, overwrite)
if nargin < 3, overwrite = false; end
% save_JPEG
% Saves all open MATLAB figures & UIFigures as JPEG images.
%
% שימוש:
%   save_JPEG
%   save_JPEG(dir)
%   save_JPEG(dir,'f')
%   save_JPEG(dir,'u')

%% --- Base directory ---
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

%% --- Choose folder by mode ---
if nargin < 2 || isempty(mode_flag)
    subfolder = 'JPEGs';
else
    switch lower(mode_flag)
        case 'f'
            subfolder = 'Filtered JPEGs';
        case 'u'
            subfolder = 'Unfiltered JPEGs';
        otherwise
            warning('mode_flag "%s" אינו מוכר — משתמש בתיקיית JPEGs רגילה.', mode_flag);
            subfolder = 'JPEGs';
    end
end

%% --- Create directory ---
save_directory = fullfile(base_directory, subfolder);
if ~exist(save_directory, 'dir')
    mkdir(save_directory);
end

%% --- Find all figures (consistent with your save_all) ---
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


    % Name
    rawName = get(fig, 'Name');
    if isempty(rawName)
        rawName = sprintf('Figure%d', fig.Number);
    end

    % Safe name
    safeName = regexprep(rawName, '[\\\/:\*\?"<>\|]', '_');

    % JPEG path (create unique if needed)
    outFile = fullfile(save_directory, safeName + ".jpg");

    if overwrite
        jpegFile = outFile;
    else
        jpegFile = unique_name(outFile);
    end


    %% --- Save JPEG using getframe (same method as PNG version) ---
    try
        F = getframe(fig);
        imwrite(F.cdata, jpegFile, 'jpg', 'Quality', 95);
    catch ME
        warning('Failed to save JPEG for "%s": %s', safeName, ME.message);
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
