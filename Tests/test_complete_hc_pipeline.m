function test_complete_hc_pipeline()
%TEST_COMPLETE_HC_PIPELINE Verify HC workflow components
%
%   This test verifies:
%   - HC_main.m exists
%   - Module structure is correct

    fprintf('Testing HC pipeline...\n');
    
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
    mainScript = fullfile(projectRoot, 'Modules', 'HC_ver1', 'HC_main.m');
    assert(exist(mainScript, 'file') == 2, 'HC_main.m not found in new location');
    
    fprintf('✓ HC pipeline structure verified\n');
end
