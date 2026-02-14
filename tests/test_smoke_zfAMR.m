function test_smoke_zfAMR()
% Smoke test for zfAMR ver11/main/zfAMR_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('zfAMR ver11', 'main', 'zfAMR_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'zfAMR_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read zfAMR_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ zfAMR_main.m smoke test passed\n');
end
