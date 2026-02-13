function save_figs_with_new_folder(base_directory, mode_flag, overwrite)
if nargin < 3, overwrite = false; end

% save_figs
% Saves all open MATLAB figures as .fig files

if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

%% Folder names by mode
if nargin < 2 || isempty(mode_flag)
    subfolder = 'FIGs';
else
    switch lower(mode_flag)
        case 'f'
            subfolder = 'Filtered FIGs';
        case 'u'
            subfolder = 'Unfiltered FIGs';
        otherwise
            warning('mode_flag "%s" לא מוכר — משתמש ב-FIGs רגיל.', mode_flag);
            subfolder = 'FIGs';
    end
end

%% Create directory
save_directory = fullfile(base_directory, subfolder);
if ~exist(save_directory, 'dir')
    mkdir(save_directory);
end

%% Find all MATLAB figures
figs = findall(groot, 'Type', 'figure');

%% List of GUIs to skip by name
skipNames = [ ...
    "Appearance / Colormap Control", ...
    "refLineGUI", ...
    "Final Figure Formatter", ...
    "FigureTools" ...
    ];

%% Loop over figures
for i = 1:numel(figs)
    fig = figs(i);

    figName = string(get(fig,'Name'));

    % --- Auto-detect GUI figures (no number + NumberTitle off) ---
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));

    % --- Skip if GUI ---
    if isGUIauto || any(figName == skipNames)
        fprintf("Skipping GUI figure: %s\n", figName);
        continue;
    end

    % Fallback figure name
    if figName == ""
        figName = sprintf("Figure%d", fig.Number);
    end

    % Remove illegal characters
    safeName = regexprep(figName, '[\\/:*?"<>|]', '_');

    %% Unique filename
    outFile = fullfile(save_directory, safeName + ".fig");

    if overwrite
        figFile = outFile;
    else
        figFile = unique_name(outFile);
    end


    %% Save
    try
        savefig(fig, figFile);
        fprintf("Saved FIG: %s\n", figFile);
    catch
        fprintf("Skipped FIG for: %s (UIFigure or unsupported)\n", figName);
    end
end

fprintf("Done saving all figure files.\n");
end
function out = unique_name(base)
[p,n,e] = fileparts(base);
k = 1;
out = base;
while exist(out,'file')
    out = fullfile(p, sprintf('%s_%d%s', n, k, e));
    k = k + 1;
end
end
