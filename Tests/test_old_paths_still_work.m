function test_old_paths_still_work()
%TEST_OLD_PATHS_STILL_WORK Confirm backward compatibility
%
%   This test verifies:
%   - Old folder structure is preserved
%   - Old scripts can still be found
%   - Functions in old locations are accessible

    fprintf('Testing backward compatibility...\n');
    
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
    
    %% Check old directories exist
    oldDirs = {
        'Aging ver2'
        'FieldSweep ver3'
        'General ver2'
        'Tools ver1'
    };
    
    for i = 1:length(oldDirs)
        dirPath = fullfile(projectRoot, oldDirs{i});
        assert(exist(dirPath, 'dir') == 7, ...
            sprintf('Old directory removed: %s (breaks backward compatibility)', oldDirs{i}));
    end
    
    %% Check that old scripts exist
    oldScripts = {
        fullfile('Aging ver2', 'Main_Aging.m')
        fullfile('FieldSweep ver3', 'FieldSweep_main.m')
    };
    
    for i = 1:length(oldScripts)
        scriptPath = fullfile(projectRoot, oldScripts{i});
        assert(exist(scriptPath, 'file') == 2, ...
            sprintf('Old script removed: %s (breaks backward compatibility)', oldScripts{i}));
    end
    
    %% Test that we can add old paths and find functions
    originalPath = path;
    try
        % Add old paths
        addpath(genpath(fullfile(projectRoot, 'General ver2')));
        addpath(genpath(fullfile(projectRoot, 'Tools ver1')));
        
        % Try to find some key functions
        % (These functions should exist in General ver2 or Tools ver1)
        keyFunctions = {
            'build_channels'
            'extract_growth_FIB'
            'close_all_except_ui_figures'
        };
        
        for i = 1:length(keyFunctions)
            funcPath = which(keyFunctions{i});
            assert(~isempty(funcPath), ...
                sprintf('Cannot find function %s in old paths', keyFunctions{i}));
        end
        
        fprintf('✓ Backward compatibility maintained!\n');
        
    catch ME
        path(originalPath);
        rethrow(ME);
    end
    
    % Restore original path
    path(originalPath);
end
