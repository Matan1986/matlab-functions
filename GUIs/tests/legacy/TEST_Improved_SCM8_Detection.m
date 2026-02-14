function TEST_Improved_SCM8_Detection()
% TEST_IMPROVED_SCM8_DETECTION - Verify the new multi-stage detection logic

fprintf('\n===== TESTING IMPROVED SCM8 DETECTION =====\n\n');

% Create a temporary mock SCM8 directory with test colormaps
tmpDir = tempdir;
testScm8Dir = fullfile(tmpDir, 'test_scientificColourMaps8');

fprintf('1. Creating mock SCM8 directory: %s\n', testScm8Dir);
if isfolder(testScm8Dir)
    rmdir(testScm8Dir, 's');
end
mkdir(testScm8Dir);

% Create simple test colormap functions in the temp directory
fprintf('2. Creating test colormap functions...\n');

% testdavos.m
fid = fopen(fullfile(testScm8Dir, 'testdavos.m'), 'w');
fprintf(fid, 'function cm = testdavos(m)\n');
fprintf(fid, 'if nargin < 1, m = 256; end\n');
fprintf(fid, 'cm = [linspace(0,1,m)'', linspace(0.5,0.3,m)'', linspace(1,0,m)''];\n');
fprintf(fid, 'cm = max(0, min(1, cm));\n');
fprintf(fid, 'end\n');
fclose(fid);

% testbatlow.m
fid = fopen(fullfile(testScm8Dir, 'testbatlow.m'), 'w');
fprintf(fid, 'function cm = testbatlow(m)\n');
fprintf(fid, 'if nargin < 1, m = 256; end\n');
fprintf(fid, 'cm = [linspace(0,1,m)'', linspace(0.2,0.8,m)'', linspace(0.8,0.2,m)''];\n');
fprintf(fid, 'cm = max(0, min(1, cm));\n');
fprintf(fid, 'end\n');
fclose(fid);

% testroma.m
fid = fopen(fullfile(testScm8Dir, 'testroma.m'), 'w');
fprintf(fid, 'function cm = testroma(m)\n');
fprintf(fid, 'if nargin < 1, m = 256; end\n');
fprintf(fid, 'cm = [linspace(0.5,0.5,m)'', linspace(0,1,m)'', linspace(1,0,m)''];\n');
fprintf(fid, 'cm = max(0, min(1, cm));\n');
fprintf(fid, 'end\n');
fclose(fid);

fprintf('3. Adding mock directory to MATLAB path...\n');
addpath(testScm8Dir);

fprintf('4. Running detection logic...\n\n');

% Mimic the detection code from FinalFigureFormatterUI.m
scm8Maps = {};

try
    scm8_dir = '';
    
    % Stage 1: Try main function
    scm8_func_path = which('scientificColourMaps8', '-all');
    if ~isempty(scm8_func_path)
        fprintf('   ✓ Stage 1: Found scientificColourMaps8.m\n');
        if ischar(scm8_func_path), scm8_func_path = {scm8_func_path}; end
        scm8_dir = fileparts(scm8_func_path{1});
    end
    
    % Stage 2: Search for known functions
    if isempty(scm8_dir)
        fprintf('   Stage 2: Searching for known colormap functions...\n');
        knownScm8Maps = {'davos', 'batlow', 'batlowS', 'batlowW', 'cmc', 'grayC', ...
            'nuuk', 'oleron', 'oslo', 'roma', 'romaO', 'tofino', 'turku', 'vanimo'};
        
        for idx_map = 1:numel(knownScm8Maps)
            mapName = knownScm8Maps{idx_map};
            % Use test versions
            testMapName = ['test' mapName];
            mapPath = which(testMapName, '-all');
            
            if ~isempty(mapPath)
                fprintf('      Found: %s\n', testMapName);
                if ischar(mapPath), mapPath = {mapPath}; end
                testDir = fileparts(mapPath{1});
                
                if isfolder(testDir)
                    dirContents = dir(fullfile(testDir, '*.m'));
                    if numel(dirContents) > 1
                        scm8_dir = testDir;
                        fprintf('   ✓ Stage 2: Found SCM8 directory\n');
                        break;
                    end
                end
            end
        end
    end
    
    % Stage 3: Extract colormaps
    if ~isempty(scm8_dir) && isfolder(scm8_dir)
        fprintf('   Stage 3: Extracting colormaps from: %s\n', scm8_dir);
        scm8_files = dir(fullfile(scm8_dir, '*.m'));
        
        for f = 1:numel(scm8_files)
            fname = scm8_files(f).name(1:end-2);
            if ~strcmpi(fname, 'scientificColourMaps8')
                scm8Maps{end+1} = fname;
            end
        end
        
        fprintf('   Extracted %d colormap functions\n', numel(scm8Maps));
        
        % Stage 4: Validate at least one works
        if ~isempty(scm8Maps)
            fprintf('   Stage 4: Validating colormaps...\n');
            validMapFound = false;
            for verify_idx = 1:min(3, numel(scm8Maps))
                try
                    testCmap = feval(scm8Maps{verify_idx}, 8);
                    if ismatrix(testCmap) && size(testCmap,2) == 3 && ...
                       isdouble(testCmap) && ~any(isnan(testCmap(:))) && ...
                       all(testCmap(:) >= 0) && all(testCmap(:) <= 1)
                        fprintf('      ✓ %s: Valid\n', scm8Maps{verify_idx});
                        validMapFound = true;
                        break;
                    end
                catch
                    fprintf('      ✗ %s: Failed\n', scm8Maps{verify_idx});
                end
            end
            
            if ~validMapFound
                warning('Colormaps detected but cannot execute');
                scm8Maps = {};
            end
        end
    end
    
    % Final cleanup
    if ~isempty(scm8Maps)
        scm8Maps = unique(scm8Maps);
    end
    
catch ME
    fprintf('   ✗ Detection error: %s\n', ME.message);
    scm8Maps = {};
end

% Report results
fprintf('\n===== DETECTION RESULTS =====\n');
if ~isempty(scm8Maps)
    fprintf('✓ SUCCESS: Found %d colormaps\n', numel(scm8Maps));
    for k = 1:numel(scm8Maps)
        fprintf('  - %s\n', scm8Maps{k});
    end
else
    fprintf('✗ FAILED: No colormaps detected\n');
end

% Cleanup
fprintf('\n5. Cleaning up...\n');
rmpath(testScm8Dir);
rmdir(testScm8Dir, 's');

fprintf('Done.\n\n');

end
