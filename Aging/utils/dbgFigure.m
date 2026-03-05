function h = dbgFigure(cfg, tag)
% =========================================================
% dbgFigure — Controlled figure creation with tag-based filtering
% =========================================================
%
% PURPOSE:
%   Create figures only when appropriate based on debug settings.
%   Enforces maximum figure limit and visibility control.
%
% INPUTS:
%   cfg - configuration struct with cfg.debug fields
%   tag - figure identifier string (e.g., "DeltaM_overview")
%
% OUTPUT:
%   h   - figure handle (empty [] if figure not created)
%
% BEHAVIOR:
%   cfg.debug.plots == "none"  → return [] (no figures)
%   cfg.debug.plots == "key"   → only if tag ∈ cfg.debug.keyPlotTags
%   cfg.debug.plots == "all"   → create figure
%   Respects maximum figure limit (cfg.debug.maxFigures)
%   Applies visibility setting (cfg.debug.plotVisible)
%
% EXAMPLES:
%   h = dbgFigure(cfg, "DeltaM_overview");
%   if ~isempty(h), figure(h); plot(...); end
%
% =========================================================

h = [];  % default: no figure

% Initialize defaults if needed
if ~isfield(cfg, 'debug')
    cfg.debug = struct();
end

if ~isfield(cfg.debug, 'plots')
    cfg.debug.plots = "key";  % default
end

if ~isfield(cfg.debug, 'maxFigures')
    cfg.debug.maxFigures = 8;  % default
end

if ~isfield(cfg.debug, 'plotVisible')
    cfg.debug.plotVisible = "off";  % default
end

if ~isfield(cfg.debug, 'keyPlotTags')
    cfg.debug.keyPlotTags = [
        "DeltaM_overview"
        "AFM_FM_channels"
        "Rsw_vs_T"
        "global_J_fit"
    ];
end

% Check if we should create any figures
if strcmp(cfg.debug.plots, "none")
    return;  % No figures at all
end

% Check key plot filtering
if strcmp(cfg.debug.plots, "key")
    % Only create if tag is in the approved list
    if ~any(strcmp(tag, cfg.debug.keyPlotTags))
        return;  % Not a key plot
    end
end

% Check figure limit
currentNumFigs = length(findobj('Type', 'figure'));
if currentNumFigs >= cfg.debug.maxFigures
    warning('dbgFigure: Max figures (%d) reached. Skipping tag "%s"', ...
        cfg.debug.maxFigures, tag);
    return;
end

% Create figure with appropriate visibility
h = figure('Name', tag, 'NumberTitle', 'off');

if strcmp(cfg.debug.plotVisible, "off")
    set(h, 'Visible', 'off');
end

end
