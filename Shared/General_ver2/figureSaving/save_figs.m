function save_figs(base_directory, overwrite)
if nargin < 2, overwrite = false; end

% save_figs
% ---------------------------------------------------------
% Saves all open MATLAB figures as .fig files
% directly into base_directory (NO subfolders).
%
% Skips known GUI figures automatically.
%
% INPUTS:
%   base_directory (optional) : folder to save figures (default: pwd)
%   overwrite      (optional) : true  -> overwrite existing files
%                               false -> auto-generate unique names

%% Base directory
if nargin < 1 || isempty(base_directory)
    base_directory = pwd;
end

if ~exist(base_directory, 'dir')
    mkdir(base_directory);
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

    % --- Auto-detect GUI figures ---
    isGUIauto = strcmp(get(fig,'NumberTitle'),'off') && isempty(get(fig,'Number'));

    % --- Skip GUI figures ---
    if isGUIauto || any(figName == skipNames)
        fprintf("Skipping GUI figure: %s\n", figName);
        continue;
    end

    % Fallback figure name
    if figName == ""
        figName = sprintf("Figure%d", fig.Number);
    end

    % Remove illegal filename characters
    safeName = sanitizeFilename(figName);

    %% Output filename
    outFile = fullfile(base_directory, safeName + ".fig");

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

%% ---------------------------------------------------------
function out = unique_name(base)
[p,n,e] = fileparts(base);
k = 1;
out = base;
while exist(out,'file')
    out = fullfile(p, sprintf('%s_%d%s', n, k, e));
    k = k + 1;
end
end
