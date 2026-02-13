function setup_project_paths()
%SETUP_PROJECT_PATHS Intelligent path setup for MATLAB project
%
%   This function automatically:
%   - Detects the project root directory
%   - Detects MATLAB version
%   - Detects cloud storage paths (Google Drive)
%   - Adds both old (backward compatible) and new paths
%   - Handles spaces in folder names
%   - Works from any directory
%
%   Usage:
%       setup_project_paths()
%
%   The function can be called from any directory within the project.

    fprintf('\n=== MATLAB Project Path Setup ===\n');
    
    %% 1. Detect Project Root
    currentDir = pwd;
    scriptDir = fileparts(mfilename('fullpath'));
    
    % Try to find project root by looking for README.md
    projectRoot = find_project_root(scriptDir);
    
    if isempty(projectRoot)
        error('Could not find project root. Please run from within the project directory.');
    end
    
    fprintf('Project Root: %s\n', projectRoot);
    
    %% 2. Detect MATLAB Version
    matlabVersion = version('-release');
    fprintf('MATLAB Version: %s\n', matlabVersion);
    
    %% 3. Detect Cloud Storage Paths
    googleDrivePath = detect_google_drive();
    if ~isempty(googleDrivePath)
        fprintf('Google Drive Detected: %s\n', googleDrivePath);
    end
    
    %% 4. Define Path Mappings (Old → New)
    pathMappings = get_path_mappings(projectRoot);
    
    %% 5. Add All Paths
    fprintf('\nAdding paths to MATLAB search path...\n');
    
    % Add project root
    addpath(projectRoot);
    
    % Add OLD paths (for backward compatibility)
    for i = 1:size(pathMappings, 1)
        oldPath = pathMappings{i, 1};
        if exist(oldPath, 'dir')
            addpath(genpath(oldPath));
            fprintf('  [OLD] %s\n', pathMappings{i, 3});
        end
    end
    
    % Add NEW paths
    for i = 1:size(pathMappings, 1)
        newPath = pathMappings{i, 2};
        if exist(newPath, 'dir')
            addpath(genpath(newPath));
            fprintf('  [NEW] %s\n', pathMappings{i, 4});
        end
    end
    
    % Add github_repo (colormaps, etc.)
    githubRepoPath = fullfile(projectRoot, 'github_repo');
    if exist(githubRepoPath, 'dir')
        addpath(genpath(githubRepoPath));
        fprintf('  [AUX] github_repo (colormaps)\n');
    end
    
    %% 6. Set Environment Variables
    setenv('MATLAB_PROJECT_ROOT', projectRoot);
    
    fprintf('\n✓ Path setup complete!\n');
    fprintf('  Total paths added: %d\n', length(strsplit(path(), pathsep)));
    fprintf('\n');
end

%% Helper Functions

function projectRoot = find_project_root(startDir)
    % Find project root by looking for README.md or .git
    currentDir = startDir;
    maxLevels = 10;
    
    for i = 1:maxLevels
        % Check for README.md
        if exist(fullfile(currentDir, 'README.md'), 'file')
            projectRoot = currentDir;
            return;
        end
        
        % Check for .git
        if exist(fullfile(currentDir, '.git'), 'dir')
            projectRoot = currentDir;
            return;
        end
        
        % Move up one directory
        parentDir = fileparts(currentDir);
        if strcmp(parentDir, currentDir)
            % Reached root
            break;
        end
        currentDir = parentDir;
    end
    
    projectRoot = '';
end

function googleDrivePath = detect_google_drive()
    % Detect Google Drive path on different operating systems
    googleDrivePath = '';
    
    if ispc
        % Windows
        possiblePaths = {
            fullfile(getenv('USERPROFILE'), 'Google Drive')
            fullfile(getenv('USERPROFILE'), 'My Drive')
            'G:\My Drive'
            'G:\Shared drives'
        };
    elseif ismac
        % macOS
        possiblePaths = {
            fullfile(getenv('HOME'), 'Google Drive')
            fullfile(getenv('HOME'), 'My Drive')
        };
    else
        % Linux
        possiblePaths = {
            fullfile(getenv('HOME'), 'Google Drive')
            fullfile(getenv('HOME'), 'My Drive')
        };
    end
    
    for i = 1:length(possiblePaths)
        if exist(possiblePaths{i}, 'dir')
            googleDrivePath = possiblePaths{i};
            return;
        end
    end
end

function pathMappings = get_path_mappings(projectRoot)
    % Define mappings: {oldPath, newPath, oldName, newName}
    pathMappings = {
        fullfile(projectRoot, 'Aging ver2'),              fullfile(projectRoot, 'Modules', 'Aging_ver2'),              'Aging ver2',              'Modules/Aging_ver2'
        fullfile(projectRoot, 'FieldSweep ver3'),         fullfile(projectRoot, 'Modules', 'FieldSweep_ver3'),         'FieldSweep ver3',         'Modules/FieldSweep_ver3'
        fullfile(projectRoot, 'AC HC MagLab ver8'),       fullfile(projectRoot, 'Modules', 'AC_HC_MagLab_ver8'),       'AC HC MagLab ver8',       'Modules/AC_HC_MagLab_ver8'
        fullfile(projectRoot, 'HC ver1'),                 fullfile(projectRoot, 'Modules', 'HC_ver1'),                 'HC ver1',                 'Modules/HC_ver1'
        fullfile(projectRoot, 'MH ver1'),                 fullfile(projectRoot, 'Modules', 'MH_ver1'),                 'MH ver1',                 'Modules/MH_ver1'
        fullfile(projectRoot, 'MT ver2'),                 fullfile(projectRoot, 'Modules', 'MT_ver2'),                 'MT ver2',                 'Modules/MT_ver2'
        fullfile(projectRoot, 'PS ver4'),                 fullfile(projectRoot, 'Modules', 'PS_ver4'),                 'PS ver4',                 'Modules/PS_ver4'
        fullfile(projectRoot, 'Relaxation ver3'),         fullfile(projectRoot, 'Modules', 'Relaxation_ver3'),         'Relaxation ver3',         'Modules/Relaxation_ver3'
        fullfile(projectRoot, 'Resistivity ver6'),        fullfile(projectRoot, 'Modules', 'Resistivity_ver6'),        'Resistivity ver6',        'Modules/Resistivity_ver6'
        fullfile(projectRoot, 'Resistivity MagLab ver1'), fullfile(projectRoot, 'Modules', 'Resistivity_MagLab_ver1'), 'Resistivity MagLab ver1', 'Modules/Resistivity_MagLab_ver1'
        fullfile(projectRoot, 'Susceptibility ver1'),     fullfile(projectRoot, 'Modules', 'Susceptibility_ver1'),     'Susceptibility ver1',     'Modules/Susceptibility_ver1'
        fullfile(projectRoot, 'Switching ver12'),         fullfile(projectRoot, 'Modules', 'Switching_ver12'),         'Switching ver12',         'Modules/Switching_ver12'
        fullfile(projectRoot, 'zfAMR ver11'),             fullfile(projectRoot, 'Modules', 'zfAMR_ver11'),             'zfAMR ver11',             'Modules/zfAMR_ver11'
        fullfile(projectRoot, 'General ver2'),            fullfile(projectRoot, 'Shared', 'General_ver2'),             'General ver2',            'Shared/General_ver2'
        fullfile(projectRoot, 'Tools ver1'),              fullfile(projectRoot, 'Shared', 'Tools_ver1'),               'Tools ver1',              'Shared/Tools_ver1'
    };
end
