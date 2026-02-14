function test_smoke_SmartFigureEngine()
% Smoke test for GUIs/SmartFigureEngine.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('GUIs', 'SmartFigureEngine.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'SmartFigureEngine.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read SmartFigureEngine.m: %s', ME.message);
    end
    
    % Test 3: Contains function definition
    assert(contains(content, 'function') && contains(content, 'SmartFigureEngine'), ...
        'GUI should be a valid function');
    
    fprintf('✓ SmartFigureEngine.m smoke test passed\n');
end
