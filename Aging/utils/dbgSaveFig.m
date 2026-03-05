function dbgSaveFig(cfg, h, name)
% =========================================================
% dbgSaveFig — Save figure to diagnostics directory
% =========================================================
%
% PURPOSE:
%   Save figure to a structured diagnostics folder.
%   Creates directory structure if needed.
%
% INPUTS:
%   cfg  - configuration struct with cfg.outFolder / cfg.outputFolder
%   h    - figure handle
%   name - filename (e.g., "tag_name.png")
%
% BEHAVIOR:
%   Saves to: cfg.outFolder/diagnostics/ or cfg.outputFolder/diagnostics/
%   Creates timestamped subfolder if cfg.debug.useTimestamp = true
%   Skips save if figure handle is empty
%
% EXAMPLES:
%   dbgSaveFig(cfg, h, "DeltaM_overview.png");
%   dbgSaveFig(cfg, h, "AFM_FM_channels.png");
%
% =========================================================

if isempty(h)
    return;  % Silent skip for empty handle
end

% Determine output folder
if isfield(cfg, 'outFolder') && ~isempty(cfg.outFolder)
    baseFolder = cfg.outFolder;
elseif isfield(cfg, 'outputFolder') && ~isempty(cfg.outputFolder)
    baseFolder = cfg.outputFolder;
else
    baseFolder = pwd;  % Current directory as fallback
end

% Diagnostics subdirectory
diagDir = fullfile(baseFolder, 'diagnostics');

% Optionally use timestamp subdirectory
if isfield(cfg, 'debug') && isfield(cfg.debug, 'useTimestamp') && cfg.debug.useTimestamp
    timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
    diagDir = fullfile(diagDir, char(timestamp));
end

% Create directory if needed
if ~isfolder(diagDir)
    mkdir(diagDir);
end

% Save figure as PNG
outPath = fullfile(diagDir, name);
try
    exportgraphics(h, outPath, 'Resolution', 150);
    % Fallback for older MATLAB versions
catch
    try
        print(h, outPath, '-dpng', '-r150');
    catch err
        warning('dbgSaveFig: Could not save figure to %s\n%s', outPath, err.message);
        return;
    end
end

end
