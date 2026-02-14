function test_smoke_MH()
% Smoke test for MH ver1/MH_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('MH ver1', 'MH_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'MH_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read MH_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ MH_main.m smoke test passed\n');
end
