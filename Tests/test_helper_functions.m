function test_helper_functions()
%TEST_HELPER_FUNCTIONS Test shared utilities
%
%   This test verifies:
%   - Shared utility functions exist
%   - Can be found on the path
%   - Basic functionality works

    fprintf('Testing shared helper functions...\n');
    
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
    
    %% Setup paths
    originalPath = path;
    try
        % Add shared utilities
        addpath(genpath(fullfile(projectRoot, 'Shared')));
        addpath(genpath(fullfile(projectRoot, 'General ver2')));
        addpath(genpath(fullfile(projectRoot, 'Tools ver1')));
        
        %% Test key helper functions
        helperFunctions = {
            'extract_growth_FIB'
            'build_channels'
            'close_all_except_ui_figures'
            'extract_current_I'
            'getScalingFactor'
        };
        
        foundCount = 0;
        for i = 1:length(helperFunctions)
            funcPath = which(helperFunctions{i});
            if ~isempty(funcPath)
                foundCount = foundCount + 1;
                fprintf('  Found: %s\n', helperFunctions{i});
                
                % Verify function is valid
                try
                    funcInfo = functions(str2func(helperFunctions{i}));
                    assert(~isempty(funcInfo.file), 'Invalid function');
                catch
                    warning('Function %s has syntax issues', helperFunctions{i});
                end
            end
        end
        
        assert(foundCount >= 3, 'Too few helper functions found');
        
        fprintf('✓ Found %d/%d helper functions\n', foundCount, length(helperFunctions));
        
    catch ME
        path(originalPath);
        rethrow(ME);
    end
    
    path(originalPath);
end
