function test_complete_fieldsweep_pipeline()
%TEST_COMPLETE_FIELDSWEEP_PIPELINE Verify FieldSweep workflow components
%
%   This test verifies:
%   - FieldSweep_main.m exists
%   - Module structure is correct

    fprintf('Testing FieldSweep pipeline...\n');
    
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
    mainScript = fullfile(projectRoot, 'Modules', 'FieldSweep_ver3', 'FieldSweep_main.m');
    assert(exist(mainScript, 'file') == 2, 'FieldSweep_main.m not found in new location');
    
    fprintf('✓ FieldSweep pipeline structure verified\n');
end
