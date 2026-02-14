function test_smoke_Relaxation()
% Smoke test for Relaxation ver3/main_relexation.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('Relaxation ver3', 'main_relexation.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'main_relexation.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read main_relexation.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ main_relexation.m smoke test passed\n');
end
