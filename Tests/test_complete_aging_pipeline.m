function test_complete_aging_pipeline()
%TEST_COMPLETE_AGING_PIPELINE Verify Aging workflow components
%
%   This test verifies:
%   - Main_Aging.m exists
%   - Required functions are available
%   - Basic structure is correct

    fprintf('Testing Aging pipeline...\n');
    
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
    
    %% Check main script exists
    mainScript = fullfile(projectRoot, 'Modules', 'Aging_ver2', 'Main_Aging.m');
    assert(exist(mainScript, 'file') == 2, 'Main_Aging.m not found in new location');
    
    %% Setup paths and check for required functions
    originalPath = path;
    try
        addpath(genpath(fullfile(projectRoot, 'Modules', 'Aging_ver2')));
        addpath(genpath(fullfile(projectRoot, 'Shared')));
        
        requiredFunctions = {
            'importFiles_aging'
            'getFileList_aging'
            'computeDeltaM'
            'analyzeAFM_FM_components'
        };
        
        for i = 1:length(requiredFunctions)
            funcPath = which(requiredFunctions{i});
            assert(~isempty(funcPath), ...
                sprintf('Required function not found: %s', requiredFunctions{i}));
        end
        
        fprintf('✓ Aging pipeline structure verified\n');
        
    catch ME
        path(originalPath);
        rethrow(ME);
    end
    
    path(originalPath);
end
