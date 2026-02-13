function test_path_setup()
%TEST_PATH_SETUP Verify setup_project_paths.m works from all directories
%
%   This test verifies:
%   - setup_project_paths.m exists
%   - Can be run from project root
%   - Detects project root correctly
%   - Adds all necessary paths

    fprintf('Testing path setup functionality...\n');
    
    %% Find project root
    projectRoot = pwd;
    if ~exist(fullfile(projectRoot, 'README.md'), 'file')
        for i = 1:3
            parentDir = fileparts(projectRoot);
            if exist(fullfile(parentDir, 'README.md'), 'file')
                projectRoot = parentDir;
                break;
            end
            projectRoot = parentDir;
        end
    end
    
    %% Check that setup_project_paths.m exists
    setupScript = fullfile(projectRoot, 'setup_project_paths.m');
    assert(exist(setupScript, 'file') == 2, ...
        'setup_project_paths.m not found');
    
    %% Save current path
    originalPath = path;
    
    try
        %% Change to project root and run setup
        currentDir = pwd;
        cd(projectRoot);
        
        % Run the setup script
        setup_project_paths();
        
        %% Verify paths were added
        currentPathList = strsplit(path, pathsep);
        
        % Check that new module paths are in the path
        modulePath = fullfile(projectRoot, 'Modules', 'Aging_ver2');
        assert(any(contains(currentPathList, modulePath)), ...
            'New module paths not added');
        
        % Check that old paths are still in the path (backward compatibility)
        oldPath = fullfile(projectRoot, 'Aging ver2');
        if exist(oldPath, 'dir')
            assert(any(contains(currentPathList, oldPath)), ...
                'Old paths not added (backward compatibility broken)');
        end
        
        % Check that shared utilities are in the path
        sharedPath = fullfile(projectRoot, 'Shared', 'General_ver2');
        assert(any(contains(currentPathList, sharedPath)), ...
            'Shared utility paths not added');
        
        % Check environment variable
        envRoot = getenv('MATLAB_PROJECT_ROOT');
        assert(~isempty(envRoot), ...
            'MATLAB_PROJECT_ROOT environment variable not set');
        
        fprintf('✓ Path setup works correctly!\n');
        
        %% Restore original directory
        cd(currentDir);
        
    catch ME
        % Restore original path and directory
        path(originalPath);
        cd(currentDir);
        rethrow(ME);
    end
    
    % Restore original path for test isolation
    path(originalPath);
end
