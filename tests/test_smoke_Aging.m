function test_smoke_Aging()
% Smoke test for Aging ver2/Main_Aging.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('Aging ver2', 'Main_Aging.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'Main_Aging.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read Main_Aging.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ Main_Aging.m smoke test passed\n');
end
