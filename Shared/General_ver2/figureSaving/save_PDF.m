function save_PDF(base_directory, overwrite)
% save_PDF_with_new_folder
% ---------------------------------------------------------
% Saves all open MATLAB figures as vector-PDF files
% directly into base_directory (NO subfolders).
% Optimized for post-editing (Illustrator / Inkscape).

if nargin < 2, overwrite = false; end
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

if ~exist(base_directory, 'dir')
    mkdir(base_directory);
end

%% --- Find all real figures ---
figs = findall(groot, 'Type', 'figure');

%% --- Skip GUI figures ---
skipList = [ ...
    "Appearance / Colormap Control", ...
    "refLineGUI", ...
    "Final Figure Formatter", ...
    "FigureTools" ...
    ];

%% --- Save each figure as PDF ---
for i = 1:numel(figs)
    fig = figs(i);
    figName = string(get(fig,'Name'));

    % Auto GUI detect
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));
    if isGUIauto || any(figName == skipList)
        fprintf("Skipping GUI: %s\n", figName);
        continue;
    end

    %% --- Build safe filename ---
    if figName == ""
        figName = sprintf('Figure%d', fig.Number);
    end

    safeName = sanitizeFilename(figName);
    outFile  = fullfile(base_directory, safeName + ".pdf");

    if overwrite
        pdfFile = outFile;
    else
        pdfFile = unique_name(outFile);
    end

    %% --- Enforce editable fonts ---
    set(findall(fig,'-property','FontName'), 'FontName', 'Arial');


  %% --- Prevent PDF clipping & export ---
try
    if strcmp(fig.PaperPositionMode,'auto')
        % fallback: use on-screen size ONLY if no paper layout was defined
        oldUnits = fig.Units;
        fig.Units = 'inches';
        pos = fig.Position;
        fig.Units = oldUnits;

        fig.PaperUnits    = 'inches';
        fig.PaperPosition = [0 0 pos(3) pos(4)];
        fig.PaperSize     = [pos(3) pos(4)];
    end

    % 🔒 lock paper geometry
    fig.PaperPositionMode = 'manual';

    % Fully vector, editable PDF
    print(fig, pdfFile, '-dpdf', '-painters');

    fprintf("Saved PDF: %s\n", pdfFile);

catch ME
    warning('Failed to save PDF for "%s": %s', safeName, ME.message);
end

end

fprintf("Done saving all PDF files.\n");
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
