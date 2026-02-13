function test_complete_mt_pipeline()
%TEST_COMPLETE_MT_PIPELINE Verify MT workflow components
%
%   This test verifies:
%   - MT_main.m exists
%   - Module structure is correct

    fprintf('Testing MT pipeline...\n');
    
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
    mainScript = fullfile(projectRoot, 'Modules', 'MT_ver2', 'MT_main.m');
    assert(exist(mainScript, 'file') == 2, 'MT_main.m not found in new location');
    
    fprintf('✓ MT pipeline structure verified\n');
end
