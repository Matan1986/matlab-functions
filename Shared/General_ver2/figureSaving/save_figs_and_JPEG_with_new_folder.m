function save_figs_and_JPEG_with_new_folder(base_directory, mode_flag)
% save_figs_and_JPEGs
% Saves all open MATLAB figures as BOTH .fig and .jpg
%
% שימוש:
%   save_figs_and_JPEGs
%   save_figs_and_JPEGs(dir)
%   save_figs_and_JPEGs(dir,'f')
%   save_figs_and_JPEGs(dir,'u')

%% --- Base directory ---
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

%% --- Choose subfolders by mode ---
if nargin < 2 || isempty(mode_flag)
    subFIG  = 'FIGs';
    subJPEG = 'JPEGs';
else
    switch lower(mode_flag)
        case 'f'
            subFIG  = 'Filtered FIGs';
            subJPEG = 'Filtered JPEGs';
        case 'u'
            subFIG  = 'Unfiltered FIGs';
            subJPEG = 'Unfiltered JPEGs';
        otherwise
            warning('mode_flag "%s" לא מוכר — משתמש בתיקיות רגילות.', mode_flag);
            subFIG  = 'FIGs';
            subJPEG = 'JPEGs';
    end
end

%% --- Create directories ---
dirFIG  = fullfile(base_directory, subFIG);
dirJPEG = fullfile(base_directory, subJPEG);

if ~exist(dirFIG, 'dir'),  mkdir(dirFIG); end
if ~exist(dirJPEG, 'dir'), mkdir(dirJPEG); end

%% --- Find all figures ---
figs = findall(groot, 'Type', 'figure');

%% --- Loop over all figures ---
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


    %% Determine safe figure name
    rawName = get(fig, 'Name');
    if isempty(rawName)
        rawName = sprintf('Figure%d', fig.Number);
    end
    safeName = regexprep(rawName, '[\\\/:\*\?"<>\|]', '_');

    %% --- .FIG file ---
    figFile = unique_name(fullfile(dirFIG, safeName + ".fig"));

    try
        savefig(fig, figFile);
    catch
        % UIFigure cannot be saved as .fig
    end

    %% --- .JPEG file ---
    jpegFile = unique_name(fullfile(dirJPEG, safeName + ".jpg"));

    try
        F = getframe(fig);
        imwrite(F.cdata, jpegFile, 'jpg', 'Quality', 95);
    catch ME
        warning('Failed to save JPEG for "%s": %s', safeName, ME.message);
    end
end

end


%% === Helper for unique filenames ===
function fname = unique_name(base)
fname = base;
[p,n,e] = fileparts(base);
k = 1;
while exist(fname, 'file')
    fname = fullfile(p, sprintf('%s_%d%s', n, k, e));
    k = k + 1;
end
end
