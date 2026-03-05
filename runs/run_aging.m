% runs/run_aging.m
projectRoot = fileparts(fileparts(mfilename('fullpath')));

% Add code to path (core engine)
addpath(genpath(fullfile(projectRoot, 'Aging')));

% ---- local machine paths (NOT version controlled) ----
if exist('localPaths.m','file') == 2
    paths = localPaths();
else
    error(['localPaths.m not found. Copy runs/localPaths_example.m to runs/localPaths.m ' ...
           'and edit paths.dataRoot / paths.outputRoot.']);
end

% ---- config ----
cfg = agingConfig('MG119_60min'); % 'MG119_60min' | 'MG119_6min' | 'MG119_36sec' | 'MG119_3sec'
cfg.debug.enable = true;
cfg.debug.plotGeometry = true;
cfg.debug.plotSwitching = true;
cfg.doPlotting = true;

% Pick dataset folder under your dataRoot:
% Example: full path should resolve to the folder that contains the analyzed aging files.
cfg.outputDir = paths.outputRoot;


disp("DATA DIR:")
disp(cfg.dataDir)

disp("Does folder exist?")
disp(isfolder(cfg.dataDir))

% ---- run ----
state = Main_Aging(cfg);