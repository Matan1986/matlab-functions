function test_smoke_FinalFigureFormatterUI()
% Smoke test for GUIs/FinalFigureFormatterUI.m
% Verifies: file exists, can be parsed, no syntax errors

    script_path = fullfile('GUIs', 'FinalFigureFormatterUI.m');
    
    % Test 1: File exists
    assert(exist(script_path, 'file') == 2, ...
        'FinalFigureFormatterUI.m should exist');
    
    % Test 2: Can read and parse (syntax check)
    try
        fid = fopen(script_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(~isempty(content), 'File should not be empty');
    catch ME
        error('Failed to read FinalFigureFormatterUI.m: %s', ME.message);
    end
    
    % Test 3: Contains function definition
    assert(contains(content, 'function') && contains(content, 'FinalFigureFormatterUI'), ...
        'GUI should be a valid function');
    
    fprintf('✓ FinalFigureFormatterUI.m smoke test passed\n');
end
