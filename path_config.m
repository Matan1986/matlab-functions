function config = path_config()
%PATH_CONFIG Configuration for project path mappings
%
%   Returns a structure containing path mappings and configuration
%   for the MATLAB project reorganization.
%
%   Usage:
%       config = path_config();
%
%   Returns:
%       config - Structure with fields:
%           .oldToNew - Cell array of old → new path mappings
%           .moduleNames - Cell array of module names
%           .sharedUtilities - Cell array of shared utility folders

    % Get project root
    projectRoot = getenv('MATLAB_PROJECT_ROOT');
    if isempty(projectRoot)
        % Fallback: try to detect from current location
        scriptDir = fileparts(mfilename('fullpath'));
        projectRoot = scriptDir;
    end
    
    %% Module Mappings
    config.oldToNew = {
        'Aging ver2',              'Modules/Aging_ver2'
        'FieldSweep ver3',         'Modules/FieldSweep_ver3'
        'AC HC MagLab ver8',       'Modules/AC_HC_MagLab_ver8'
        'HC ver1',                 'Modules/HC_ver1'
        'MH ver1',                 'Modules/MH_ver1'
        'MT ver2',                 'Modules/MT_ver2'
        'PS ver4',                 'Modules/PS_ver4'
        'Relaxation ver3',         'Modules/Relaxation_ver3'
        'Resistivity ver6',        'Modules/Resistivity_ver6'
        'Resistivity MagLab ver1', 'Modules/Resistivity_MagLab_ver1'
        'Susceptibility ver1',     'Modules/Susceptibility_ver1'
        'Switching ver12',         'Modules/Switching_ver12'
        'zfAMR ver11',             'Modules/zfAMR_ver11'
        'General ver2',            'Shared/General_ver2'
        'Tools ver1',              'Shared/Tools_ver1'
    };
    
    %% Module Names
    config.moduleNames = {
        'Aging_ver2'
        'FieldSweep_ver3'
        'AC_HC_MagLab_ver8'
        'HC_ver1'
        'MH_ver1'
        'MT_ver2'
        'PS_ver4'
        'Relaxation_ver3'
        'Resistivity_ver6'
        'Resistivity_MagLab_ver1'
        'Susceptibility_ver1'
        'Switching_ver12'
        'zfAMR_ver11'
    };
    
    %% Shared Utilities
    config.sharedUtilities = {
        'General_ver2'
        'Tools_ver1'
    };
    
    %% Project Root
    config.projectRoot = projectRoot;
    
    %% New Directory Structure
    config.newDirs = {
        'Modules'
        'Shared'
        'Tests'
        'Documentation'
        'GUIs_Organized'
    };
end
