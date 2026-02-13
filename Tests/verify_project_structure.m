function verify_project_structure()
%VERIFY_PROJECT_STRUCTURE Check that all files are in correct locations
%
%   This test verifies:
%   - New directory structure exists
%   - All module folders copied correctly
%   - Shared utilities copied correctly
%   - Old structure still intact (backward compatibility)

    fprintf('Verifying project structure...\n');
    
    %% Get project root
    projectRoot = pwd;
    if exist(fullfile(projectRoot, 'README.md'), 'file')
        % We're in the right place
    else
        % Try to find project root
        for i = 1:3
            parentDir = fileparts(projectRoot);
            if exist(fullfile(parentDir, 'README.md'), 'file')
                projectRoot = parentDir;
                break;
            end
            projectRoot = parentDir;
        end
    end
    
    %% Check new directory structure
    newDirs = {'Modules', 'Shared', 'Tests', 'Documentation'};
    for i = 1:length(newDirs)
        dirPath = fullfile(projectRoot, newDirs{i});
        assert(exist(dirPath, 'dir') == 7, ...
            sprintf('New directory missing: %s', newDirs{i}));
    end
    
    %% Check module folders
    modules = {
        'Aging_ver2', 'FieldSweep_ver3', 'AC_HC_MagLab_ver8', 
        'HC_ver1', 'MH_ver1', 'MT_ver2', 'PS_ver4', 
        'Relaxation_ver3', 'Resistivity_ver6', 'Resistivity_MagLab_ver1',
        'Susceptibility_ver1', 'Switching_ver12', 'zfAMR_ver11'
    };
    
    for i = 1:length(modules)
        modulePath = fullfile(projectRoot, 'Modules', modules{i});
        assert(exist(modulePath, 'dir') == 7, ...
            sprintf('Module folder missing: Modules/%s', modules{i}));
    end
    
    %% Check shared utilities
    sharedUtils = {'General_ver2', 'Tools_ver1'};
    for i = 1:length(sharedUtils)
        utilPath = fullfile(projectRoot, 'Shared', sharedUtils{i});
        assert(exist(utilPath, 'dir') == 7, ...
            sprintf('Shared utility missing: Shared/%s', sharedUtils{i}));
    end
    
    %% Verify old structure still intact (backward compatibility)
    oldDirs = {
        'Aging ver2', 'FieldSweep ver3', 'AC HC MagLab ver8',
        'HC ver1', 'MH ver1', 'MT ver2', 'PS ver4',
        'Relaxation ver3', 'Resistivity ver6', 'Resistivity MagLab ver1',
        'Susceptibility ver1', 'Switching ver12', 'zfAMR ver11',
        'General ver2', 'Tools ver1'
    };
    
    for i = 1:length(oldDirs)
        oldPath = fullfile(projectRoot, oldDirs{i});
        assert(exist(oldPath, 'dir') == 7, ...
            sprintf('Old directory removed (should be preserved): %s', oldDirs{i}));
    end
    
    %% Check that key scripts exist in new locations
    % Check a few main scripts
    mainScripts = {
        fullfile('Modules', 'Aging_ver2', 'Main_Aging.m')
        fullfile('Modules', 'FieldSweep_ver3', 'FieldSweep_main.m')
        fullfile('Modules', 'MT_ver2', 'MT_main.m')
    };
    
    for i = 1:length(mainScripts)
        scriptPath = fullfile(projectRoot, mainScripts{i});
        assert(exist(scriptPath, 'file') == 2, ...
            sprintf('Main script missing: %s', mainScripts{i}));
    end
    
    fprintf('✓ All structure checks passed!\n');
end
