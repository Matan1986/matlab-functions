function dbg(cfg, level, msg, varargin)
% =========================================================
% dbg — Structured debug logging with verbosity control
% =========================================================
%
% PURPOSE:
%   Centralized logging with configurable verbosity levels.
%   Supports console output and optional log file.
%
% INPUTS:
%   cfg     - configuration struct with cfg.debug fields
%   level   - logging level: "quiet" < "summary" < "full"
%   msg     - message format string (printf-style)
%   varargin - format arguments for msg
%
% BEHAVIOR:
%   If cfg.debug.level >= requested level → print + optionally log to file
%   Otherwise → silent
%
% EXAMPLES:
%   dbg(cfg, "summary", "Found %d pause runs", nPause)
%   dbg(cfg, "full", "Processing pause Tp=%.1f K", Tp)
%
% =========================================================

% Default verbosity level
if ~isfield(cfg, 'debug')
    cfg.debug = struct();
end

if ~isfield(cfg.debug, 'level')
    cfg.debug.level = "summary";  % default
end

if ~isfield(cfg.debug, 'logToFile')
    cfg.debug.logToFile = false;  % default
end

if ~isfield(cfg.debug, 'logFile')
    cfg.debug.logFile = '';  % default
end

% Convert level strings to numeric priority
levelMap = containers.Map({'quiet', 'summary', 'full'}, [0, 1, 2]);

requestedLevel = double(levelMap(level));
configLevel = double(levelMap(cfg.debug.level));

% Only print if config level >= requested level
if configLevel < requestedLevel
    return;  % Silent
end

% Format message if varargin provided
if nargin > 3
    formatted_msg = sprintf(msg, varargin{:});
else
    formatted_msg = msg;
end

% Print to console
fprintf('[%s] %s\n', char(level), formatted_msg);

% Optionally log to file
if cfg.debug.logToFile && ~isempty(cfg.debug.logFile)
    % Create directory if needed
    logDir = fileparts(cfg.debug.logFile);
    if ~isempty(logDir) && ~isfolder(logDir)
        mkdir(logDir);
    end
    
    % Append to log file with timestamp
    fid = fopen(cfg.debug.logFile, 'a');
    if fid > 0
        timestamp = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
        fprintf(fid, '[%s] [%s] %s\n', string(timestamp), char(level), formatted_msg);
        fclose(fid);
    end
end

end
