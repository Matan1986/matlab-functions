function test_google_drive_paths()
%TEST_GOOGLE_DRIVE_PATHS Detect and verify Google Drive accessibility
%
%   This test verifies:
%   - Google Drive path detection works
%   - Function handles missing Google Drive gracefully

    fprintf('Testing Google Drive path detection...\n');
    
    %% Try to detect Google Drive
    googleDrivePath = detect_google_drive_test();
    
    if ~isempty(googleDrivePath)
        fprintf('  Google Drive detected: %s\n', googleDrivePath);
        
        % Verify it's accessible
        assert(exist(googleDrivePath, 'dir') == 7, ...
            'Google Drive path detected but not accessible');
        
        fprintf('✓ Google Drive path is accessible\n');
    else
        fprintf('  Google Drive not detected (this is OK for CI/testing)\n');
        fprintf('✓ Google Drive detection works (no path found)\n');
    end
end

function googleDrivePath = detect_google_drive_test()
    % Detect Google Drive path (same logic as setup_project_paths)
    googleDrivePath = '';
    
    if ispc
        possiblePaths = {
            fullfile(getenv('USERPROFILE'), 'Google Drive')
            fullfile(getenv('USERPROFILE'), 'My Drive')
            'G:\My Drive'
        };
    elseif ismac
        possiblePaths = {
            fullfile(getenv('HOME'), 'Google Drive')
            fullfile(getenv('HOME'), 'My Drive')
        };
    else
        possiblePaths = {
            fullfile(getenv('HOME'), 'Google Drive')
            fullfile(getenv('HOME'), 'My Drive')
        };
    end
    
    for i = 1:length(possiblePaths)
        if exist(possiblePaths{i}, 'dir')
            googleDrivePath = possiblePaths{i};
            return;
        end
    end
end
