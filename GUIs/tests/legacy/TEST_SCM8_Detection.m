function TEST_SCM8_Detection()
% TEST_SCM8_DETECTION - Verify ScientificColourMaps8 detection logic
% This test creates a minimal version of the detection code with debug enabled

fprintf('\n===== SCM8 DETECTION TEST =====\n\n');

% Test Stage 1: Look for main function
fprintf('Stage 1: Looking for scientificColourMaps8.m...\n');
scm8_func_path = which('scientificColourMaps8', '-all');
if ~isempty(scm8_func_path)
    if ischar(scm8_func_path), scm8_func_path = {scm8_func_path}; end
    fprintf('  ✓ Found at: %s\n', scm8_func_path{1});
else
    fprintf('  ✗ Not found\n');
end

% Test Stage 2: Look for known colormap functions
fprintf('\nStage 2: Looking for known SCM8 colormap functions...\n');
knownScm8Maps = {'davos', 'batlow', 'batlowS', 'batlowW', 'cmc', 'grayC', 'nuuk', ...
    'oleron', 'oslo', 'roma', 'romaO', 'tofino', 'turku', 'vanimo'};

found_maps = {};
for k = 1:numel(knownScm8Maps)
    testFunc = knownScm8Maps{k};
    testPath = which(testFunc, '-all');
    if ~isempty(testPath)
        if ischar(testPath), testPath = {testPath}; end
        fprintf('  ✓ Found: %s at %s\n', testFunc, fileparts(testPath{1}));
        found_maps{end+1} = testFunc;
    end
end

if ~isempty(found_maps)
    % Extract directory from first found map
    testPath = which(found_maps{1}, '-all');
    if ischar(testPath), testPath = {testPath}; end
    scm8_dir = fileparts(testPath{1});
    
    fprintf('\nStage 3: Scanning directory for all colormaps...\n');
    fprintf('  Directory: %s\n', scm8_dir);
    
    allFiles = dir(fullfile(scm8_dir, '*.m'));
    fprintf('  Found %d .m files\n', numel(allFiles));
    
    % Extract colormap names
    scm8Maps = {};
    for f = 1:numel(allFiles)
        fname = allFiles(f).name(1:end-2);
        if ~strcmpi(fname, 'scientificColourMaps8')
            scm8Maps{end+1} = fname;
        end
    end
    
    scm8Maps = unique(scm8Maps);
    fprintf('  Extracted %d unique colormaps (excluding main function)\n', numel(scm8Maps));
    
    % Test a few
    fprintf('\nStage 4: Validating colormaps...\n');
    for test_idx = 1:min(3, numel(scm8Maps))
        testMapName = scm8Maps{test_idx};
        try
            testCmap = feval(testMapName, 8);
            if ismatrix(testCmap) && size(testCmap,2) == 3 && ...
               ~any(isnan(testCmap(:))) && all(testCmap(:) >= 0) && all(testCmap(:) <= 1)
                fprintf('  ✓ %s: OK (format %dx3)\n', testMapName, size(testCmap,1));
            else
                fprintf('  ✗ %s: Invalid format\n', testMapName);
            end
        catch ME
            fprintf('  ✗ %s: %s\n', testMapName, ME.message);
        end
    end
    
    fprintf('\n===== DETECTION SUCCESS =====\n');
    fprintf('Total colormaps available: %d\n\n', numel(scm8Maps));
else
    fprintf('\n===== DETECTION FAILED =====\n');
    fprintf('Could not find any known SCM8 colormaps\n\n');
end

end
