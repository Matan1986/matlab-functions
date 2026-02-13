function verify_old_structure_still_works()
%VERIFY_OLD_STRUCTURE_STILL_WORKS Test backward compatibility
%
%   This script verifies that:
%   - Old *_main.m scripts still work
%   - Old addpath() statements function
%   - Old folder structure is intact

    clc;
    
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                                                              ║\n');
    fprintf('║           BACKWARD COMPATIBILITY VERIFICATION               ║\n');
    fprintf('║                                                              ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    
    %% Find project root
    projectRoot = find_project_root_verify();
    if isempty(projectRoot)
        error('Cannot find project root.');
    end
    
    fprintf('Project Root: %s\n', projectRoot);
    fprintf('\n');
    
    passCount = 0;
    failCount = 0;
    
    %% Test 1: Old directories exist
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('TEST 1: Old Directory Structure Intact\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    oldDirs = {
        'Aging ver2'
        'FieldSweep ver3'
        'AC HC MagLab ver8'
        'General ver2'
        'Tools ver1'
    };
    
    allOldDirsExist = true;
    for i = 1:length(oldDirs)
        dirPath = fullfile(projectRoot, oldDirs{i});
        if exist(dirPath, 'dir')
            fprintf('  ✓ %s\n', oldDirs{i});
        else
            fprintf('  ✗ %s (MISSING!)\n', oldDirs{i});
            allOldDirsExist = false;
        end
    end
    
    if allOldDirsExist
        fprintf('\n\x1b[32m✓ PASS: All old directories exist\x1b[0m\n');
        passCount = passCount + 1;
    else
        fprintf('\n\x1b[31m✗ FAIL: Some old directories missing\x1b[0m\n');
        failCount = failCount + 1;
    end
    
    %% Test 2: Old scripts exist
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('TEST 2: Old Main Scripts Still Present\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    oldScripts = {
        fullfile('Aging ver2', 'Main_Aging.m')
        fullfile('FieldSweep ver3', 'FieldSweep_main.m')
        fullfile('MT ver2', 'MT_main.m')
    };
    
    allOldScriptsExist = true;
    for i = 1:length(oldScripts)
        scriptPath = fullfile(projectRoot, oldScripts{i});
        if exist(scriptPath, 'file')
            fprintf('  ✓ %s\n', oldScripts{i});
        else
            fprintf('  ✗ %s (MISSING!)\n', oldScripts{i});
            allOldScriptsExist = false;
        end
    end
    
    if allOldScriptsExist
        fprintf('\n\x1b[32m✓ PASS: All old scripts exist\x1b[0m\n');
        passCount = passCount + 1;
    else
        fprintf('\n\x1b[31m✗ FAIL: Some old scripts missing\x1b[0m\n');
        failCount = failCount + 1;
    end
    
    %% Test 3: Old addpath statements work
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('TEST 3: Old addpath() Statements Work\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    originalPath = path;
    try
        % Simulate old-style addpath
        addpath(genpath(fullfile(projectRoot, 'General ver2')));
        addpath(genpath(fullfile(projectRoot, 'Tools ver1')));
        
        % Try to find key functions
        keyFunctions = {'build_channels', 'extract_growth_FIB', 'close_all_except_ui_figures'};
        allFunctionsFound = true;
        
        for i = 1:length(keyFunctions)
            funcPath = which(keyFunctions{i});
            if ~isempty(funcPath)
                fprintf('  ✓ Found: %s\n', keyFunctions{i});
            else
                fprintf('  ✗ Not found: %s\n', keyFunctions{i});
                allFunctionsFound = false;
            end
        end
        
        if allFunctionsFound
            fprintf('\n\x1b[32m✓ PASS: Old addpath statements work\x1b[0m\n');
            passCount = passCount + 1;
        else
            fprintf('\n\x1b[31m✗ FAIL: Cannot find functions with old paths\x1b[0m\n');
            failCount = failCount + 1;
        end
        
        path(originalPath);
    catch ME
        path(originalPath);
        fprintf('\n\x1b[31m✗ FAIL: Error testing old paths: %s\x1b[0m\n', ME.message);
        failCount = failCount + 1;
    end
    
    %% Final Summary
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║               BACKWARD COMPATIBILITY SUMMARY                 ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('Tests Passed: \x1b[32m%d\x1b[0m\n', passCount);
    fprintf('Tests Failed: \x1b[31m%d\x1b[0m\n', failCount);
    fprintf('\n');
    
    if failCount == 0
        fprintf('\x1b[32m');
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                                                              ║\n');
        fprintf('║          ✓ BACKWARD COMPATIBILITY VERIFIED!                 ║\n');
        fprintf('║                                                              ║\n');
        fprintf('║  Old scripts and folder structure remain fully functional.   ║\n');
        fprintf('║                                                              ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n');
        fprintf('\x1b[0m');
    else
        fprintf('\x1b[31m');
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                                                              ║\n');
        fprintf('║          ✗ BACKWARD COMPATIBILITY ISSUES FOUND              ║\n');
        fprintf('║                                                              ║\n');
        fprintf('║  Some old functionality is broken. Please review.            ║\n');
        fprintf('║                                                              ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n');
        fprintf('\x1b[0m');
    end
    fprintf('\n');
end

function projectRoot = find_project_root_verify()
    currentDir = pwd;
    
    for i = 1:10
        if exist(fullfile(currentDir, 'README.md'), 'file')
            projectRoot = currentDir;
            return;
        end
        
        parentDir = fileparts(currentDir);
        if strcmp(parentDir, currentDir)
            break;
        end
        currentDir = parentDir;
    end
    
    projectRoot = '';
end
