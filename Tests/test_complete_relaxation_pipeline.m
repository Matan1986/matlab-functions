function test_complete_relaxation_pipeline()
%TEST_COMPLETE_RELAXATION_PIPELINE Verify Relaxation workflow components
%
%   This test verifies:
%   - Module structure is correct

    fprintf('Testing Relaxation pipeline...\n');
    
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
    
    %% Check module exists
    modulePath = fullfile(projectRoot, 'Modules', 'Relaxation_ver3');
    assert(exist(modulePath, 'dir') == 7, 'Relaxation_ver3 module not found');
    
    fprintf('✓ Relaxation pipeline structure verified\n');
end
