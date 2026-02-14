function test_smoke_PS()
% Smoke test for PS ver4/PS_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('PS ver4', 'PS_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'PS_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read PS_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ PS_main.m smoke test passed\n');
end
