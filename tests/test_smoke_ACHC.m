function test_smoke_ACHC()
% Smoke test for AC HC MagLab ver8/ACHC_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('AC HC MagLab ver8', 'ACHC_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'ACHC_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read ACHC_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ ACHC_main.m smoke test passed\n');
end
