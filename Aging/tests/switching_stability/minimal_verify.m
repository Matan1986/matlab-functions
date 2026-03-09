%% Minimal verification - check that key functions exist and are callable
clc; clear; close all;

fprintf('======================================\n');
fprintf('MINIMAL VERIFICATION TEST\n');
fprintf('======================================\n\n');

% Setup paths
baseFolder = 'c:\Dev\matlab-functions';
addpath(genpath(baseFolder));
fprintf('[PASS] Paths configured\n\n');

%% Test 1: Check that stage7_reconstructSwitching accepts debugSwitching parameter
fprintf('Test 1: Checking stage7_reconstructSwitching function signature...\n');
try
    % Check if file exists
    stage7_path = which('stage7_reconstructSwitching');
    if isempty(stage7_path)
        fprintf('[FAIL] stage7_reconstructSwitching not found on path\n');
    else
        fprintf('[PASS] Found: %s\n', stage7_path);
        
        % Read the file to check for debugSwitching parameter
        fid = fopen(stage7_path, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        
        if contains(content, 'debugSwitching')
            fprintf('[PASS] Contains debugSwitching parameter\n');
        else
            fprintf('[FAIL]  Does NOT contain debugSwitching parameter\n');
        end
    end
catch ME
    fprintf('[ERROR] %s\n', ME.message);
end

fprintf('\n');

%% Test 2: Check that the directory structure exists
fprintf('Test 2: Verifying directory structure...\n');
test_dir = fullfile(baseFolder, 'Aging', 'tests', 'switching_stability');
if exist(test_dir, 'dir')
    fprintf('[PASS] Directory exists: %s\n', test_dir);
    
    % List files
    files = dir(fullfile(test_dir, '*.m'));
    fprintf('[INFO] Found %d .m files:\n', length(files));
    for i = 1:length(files)
        fprintf('       - %s\n', files(i).name);
    end
else
    fprintf('[FAIL] Directory NOT found: %s\n', test_dir);
end

fprintf('\n');

%% Test 3: Check agingConfig
fprintf('Test 3: Checking agingConfig structure...\n');
try
    cfg = agingConfig();
    fprintf('[PASS] agingConfig() executed successfully\n');
    
    if isfield(cfg, 'switchParams')
        fprintf('[PASS] cfg.switchParams exists\n');
        
        if isfield(cfg.switchParams, 'debugSwitching')
            fprintf('[PASS] cfg.switchParams.debugSwitching exists\n');
            fprintf('[INFO] Default value = %d\n', cfg.switchParams.debugSwitching);
        else
            fprintf('[INFO] cfg.switchParams.debugSwitching does NOT exist (will be added at runtime)\n');
        end
    else
        fprintf('[FAIL] cfg.switchParams does NOT exist\n');
    end
catch ME
    fprintf('[ERROR] %s\n', ME.message);
end

fprintf('\n');

%% Test 4: Verify key functions exist
fprintf('Test 4: Verifying key pipeline functions exist...\n');
required_functions = {
    'stage0_setupPaths'
    'stage1_loadData'
    'stage2_preprocess'
    'stage3_computeDeltaM'
    'stage4_analyzeAFM_FM'
    'stage5_fitFMGaussian'
    'stage6_extractMetrics'
    'stage7_reconstructSwitching'
};

all_found = true;
for i = 1:length(required_functions)
    func_path = which(required_functions{i});
    if isempty(func_path)
        fprintf('[FAIL] %s NOT FOUND\n', required_functions{i});
        all_found = false;
    else
        fprintf('[PASS] %s\n', required_functions{i});
    end
end

if all_found
    fprintf('\n[PASS] All required functions found\n');
else
    fprintf('\n[FAIL] Some functions are missing\n');
end

%% Summary
fprintf('\n======================================\n');
fprintf('VERIFICATION COMPLETE\n');
fprintf('======================================\n');
fprintf('[INFO] This minimal test verifies that:\n');
fprintf('       1. The test directory structure exists\n');
fprintf('       2. All pipeline functions are on the path\n');
fprintf('       3. The debugSwitching parameter is present\n');
fprintf('       4. Basic configuration loads successfully\n');
fprintf('\n[INFO] For full pipeline testing, run the data with actual files.\n');
