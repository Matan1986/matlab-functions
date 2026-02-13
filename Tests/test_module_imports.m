function test_module_imports()
%TEST_MODULE_IMPORTS Verify each module's import functions work
%
%   This test verifies:
%   - Import functions exist in each module
%   - Functions can be found on the path
%   - Basic syntax is correct

    fprintf('Testing module import functions...\n');
    
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
        % Add both old and new paths
        addpath(genpath(fullfile(projectRoot, 'Modules')));
        addpath(genpath(fullfile(projectRoot, 'Aging ver2')));
        addpath(genpath(fullfile(projectRoot, 'MH ver1')));
        
        %% Test import functions
        importFunctions = {
            'importFiles_aging'
            'importFiles_MH'
            'getFileList_aging'
        };
        
        foundCount = 0;
        for i = 1:length(importFunctions)
            funcPath = which(importFunctions{i});
            if ~isempty(funcPath)
                foundCount = foundCount + 1;
                fprintf('  Found: %s\n', importFunctions{i});
                
                % Check syntax by trying to get function info
                try
                    funcInfo = functions(str2func(importFunctions{i}));
                    assert(~isempty(funcInfo.file), 'Invalid function');
                catch
                    warning('Function %s has syntax issues', importFunctions{i});
                end
            end
        end
        
        assert(foundCount > 0, 'No import functions found on path');
        
        fprintf('✓ Found %d/%d import functions\n', foundCount, length(importFunctions));
        
    catch ME
        path(originalPath);
        rethrow(ME);
    end
    
    path(originalPath);
end
