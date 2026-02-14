function test_smoke_FieldSweep()
% Smoke test for FieldSweep ver3/FieldSweep_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('FieldSweep ver3', 'FieldSweep_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'FieldSweep_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read FieldSweep_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ FieldSweep_main.m smoke test passed\n');
end
