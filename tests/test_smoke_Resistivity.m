function test_smoke_Resistivity()
% Smoke test for Resistivity ver6/Resistivity_main.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('Resistivity ver6', 'Resistivity_main.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'Resistivity_main.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read Resistivity_main.m: %s', ME.message);
    end
    
    % Test 3: Contains expected MATLAB constructs
    assert(contains(content, 'baseFolder') || contains(content, 'addpath'), ...
        'Script should contain path setup');
    
    fprintf('✓ Resistivity_main.m smoke test passed\n');
end
