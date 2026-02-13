function save_PDF_with_new_folder(base_directory, mode_flag, overwrite)
% save_PDF
% Saves all open MATLAB figures as vector-PDF files, optimized for editing.

if nargin < 3, overwrite = false; end
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end
if nargin < 2
    mode_flag = [];
end

%% --- Choose subfolder by mode ---
if nargin < 2 || isempty(mode_flag)
    subfolder = 'PDFs';
else
    switch lower(mode_flag)
        case 'f'
            subfolder = 'Filtered PDFs';
        case 'u'
            subfolder = 'Unfiltered PDFs';
        otherwise
            warning('mode_flag "%s" not recognized — using regular PDFs folder.', mode_flag);
            subfolder = 'PDFs';
    end
end

%% --- Create directory ---
save_directory = fullfile(base_directory, subfolder);
if ~exist(save_directory, 'dir')
    mkdir(save_directory);
end

%% --- Find all real figures ---
figs = findall(groot, 'Type', 'figure');

%% --- Skip GUI figures ---
skipList = ["Appearance / Colormap Control", ...
            "refLineGUI", ...
            "Final Figure Formatter", ...
            "FigureTools"];

%% --- Save each figure as PDF ---
for i = 1:numel(figs)
    fig = figs(i);
    guiName = string(get(fig, 'Name'));

    % Auto GUI detect
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));
    if isGUIauto || any(guiName == skipList)
        fprintf("Skipping GUI: %s\n", guiName);
        continue;
    end

    %% --- Build safe filename ---
    rawName = get(fig,'Name');
    if isempty(rawName)
        rawName = sprintf('Figure%d', fig.Number);
    end

    safeName = regexprep(rawName, '[\\\/:\*\?"<>\|]', '_');
    outFile  = fullfile(save_directory, safeName + ".pdf");

    if overwrite
        pdfFile = outFile;
    else
        pdfFile = unique_name(outFile);
    end

    %% --- Improve EDITABILITY: enforce editable fonts ---
    set(findall(fig,'-property','FontName'), 'FontName', 'Arial');   % ← חשוב!!

    %% --- Prevent PDF clipping ---
    try
        set(fig, 'Units', 'inches');
        pos = fig.Position;

        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperPosition', [0 0 pos(3) pos(4)]);
        set(fig, 'PaperSize',     [pos(3) pos(4)]);

        % HIGH QUALITY, FULLY EDITABLE PDF:
        print(fig, pdfFile, '-dpdf', '-painters');

        fprintf("Saved PDF → %s\n", pdfFile);

    catch ME
        warning('Failed to save PDF for "%s": %s', safeName, ME.message);
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
