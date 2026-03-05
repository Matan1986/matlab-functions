function diagDir = dbgInitDiagnostics(cfg)
% =========================================================
% dbgInitDiagnostics — Initialize diagnostics directory structure
% =========================================================
%
% PURPOSE:
%   Create timestamped diagnostics directory and initialize log file.
%   Returns path for saving diagnostic files.
%
% INPUTS:
%   cfg - configuration struct
%
% OUTPUT:
%   diagDir - full path to diagnostics directory
%
% BEHAVIOR:
%   Creates cfg.outFolder/diagnostics/
%   Optionally creates YYYYMMdd_HHmmss subdirectory
%   Opens/clears log file for this run
%
% =========================================================

% Determine output folder
if isfield(cfg, 'outFolder') && ~isempty(cfg.outFolder)
    baseFolder = cfg.outFolder;
elseif isfield(cfg, 'outputFolder') && ~isempty(cfg.outputFolder)
    baseFolder = cfg.outputFolder;
else
    baseFolder = pwd;
end

% Create diagnostics directory
diagDir = fullfile(baseFolder, 'diagnostics');

% Optional: use timestamp subdirectory
if isfield(cfg, 'debug') && isfield(cfg.debug, 'useTimestamp') && cfg.debug.useTimestamp
    timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
    diagDir = fullfile(diagDir, char(timestamp));
end

% Create directory if needed
if ~isfolder(diagDir)
    mkdir(diagDir);
end

% Initialize log file
if isfield(cfg, 'debug') && isfield(cfg.debug, 'logFile') && ~isempty(cfg.debug.logFile)
    logFile = cfg.debug.logFile;
    logDir = fileparts(logFile);
    
    if ~isempty(logDir) && ~isfolder(logDir)
        mkdir(logDir);
    end
    
    % Clear/create log file with header
    fid = fopen(logFile, 'w');
    if fid > 0
        fprintf(fid, '=== AGING PIPELINE DIAGNOSTIC LOG ===\n');
        fprintf(fid, 'Started: %s\n', datetime('now'));
        fprintf(fid, '=====================================\n\n');
        fclose(fid);
    end
    
    % Log startup message
    dbg(cfg, "summary", "Diagnostics initialized in: %s", diagDir);
end

end
