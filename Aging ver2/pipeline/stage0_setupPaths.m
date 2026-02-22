function cfg = stage0_setupPaths(cfg)
% =========================================================
% stage0_setupPaths
%
% PURPOSE:
%   Configure paths and extract sample metadata.
%
% INPUTS:
%   cfg - configuration struct
%
% OUTPUTS:
%   cfg - updated with sample_name and path setup
%
% Physics meaning:
%   AFM = not used
%   FM  = not used
%
% =========================================================

% Ensure local pipeline/models/plots/utils are on path
pipelineRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(pipelineRoot);
addpath(genpath(repoRoot));

% Add shared base folder if provided
if isfield(cfg, 'baseFolder') && ~isempty(cfg.baseFolder)
    addpath(genpath(cfg.baseFolder));
end

% Extract sample info
[growth_num, FIB_num] = extract_growth_FIB(cfg.dataDir, []);
cfg.growth_num = growth_num;
cfg.FIB_num = FIB_num;
cfg.sample_name = sprintf('MG %d', growth_num);

% Initialize debug output folder if enabled
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    if ~isfield(cfg.debug, 'runTag') || isempty(cfg.debug.runTag)
        cfg.debug.runTag = datestr(now, 'yyyymmdd_HHMMSS');
    end
    if ~isfield(cfg.debug, 'outputRoot') || isempty(cfg.debug.outputRoot)
        cfg.debug.outputRoot = fullfile(cfg.outputFolder, 'Debug');
    end
    cfg.debug.outFolder = fullfile(cfg.debug.outputRoot, cfg.debug.runTag);
end

end
