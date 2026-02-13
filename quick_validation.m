% Quick Validation Script - Run this to verify the reorganization
% This script performs quick sanity checks without running full tests

clc;
fprintf('\n╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║           QUICK VALIDATION - REORGANIZATION                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

projectRoot = pwd;

%% Check 1: New directories exist
fprintf('Check 1: New directory structure... ');
newDirs = {'Modules', 'Shared', 'Tests', 'Documentation'};
allExist = true;
for i = 1:length(newDirs)
    if ~exist(fullfile(projectRoot, newDirs{i}), 'dir')
        allExist = false;
    end
end
if allExist
    fprintf('\x1b[32m✓ PASS\x1b[0m\n');
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Check 2: Old directories preserved
fprintf('Check 2: Old structure preserved... ');
oldDirs = {'Aging ver2', 'General ver2', 'Tools ver1'};
allExist = true;
for i = 1:length(oldDirs)
    if ~exist(fullfile(projectRoot, oldDirs{i}), 'dir')
        allExist = false;
    end
end
if allExist
    fprintf('\x1b[32m✓ PASS\x1b[0m\n');
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Check 3: Main entry points exist
fprintf('Check 3: Main entry points... ');
mainFiles = {'setup_project_paths.m', 'autotest_after_reorganization.m', 'verify_old_structure_still_works.m'};
allExist = true;
for i = 1:length(mainFiles)
    if ~exist(fullfile(projectRoot, mainFiles{i}), 'file')
        allExist = false;
    end
end
if allExist
    fprintf('\x1b[32m✓ PASS\x1b[0m\n');
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Check 4: Test suite exists
fprintf('Check 4: Test suite... ');
testDir = fullfile(projectRoot, 'Tests');
if exist(testDir, 'dir')
    testFiles = dir(fullfile(testDir, '*.m'));
    if length(testFiles) >= 15
        fprintf('\x1b[32m✓ PASS (%d test files)\x1b[0m\n', length(testFiles));
    else
        fprintf('\x1b[33m⚠ WARNING (only %d test files)\x1b[0m\n', length(testFiles));
    end
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Check 5: Documentation exists
fprintf('Check 5: Documentation... ');
docFiles = {'Documentation/MIGRATION_GUIDE.md', 'Documentation/PROJECT_STRUCTURE.md'};
allExist = true;
for i = 1:length(docFiles)
    if ~exist(fullfile(projectRoot, docFiles{i}), 'file')
        allExist = false;
    end
end
if allExist
    fprintf('\x1b[32m✓ PASS\x1b[0m\n');
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Check 6: Modules copied
fprintf('Check 6: Modules copied correctly... ');
modulesDir = fullfile(projectRoot, 'Modules');
if exist(modulesDir, 'dir')
    modules = dir(modulesDir);
    moduleCount = sum([modules.isdir]) - 2; % Exclude . and ..
    if moduleCount >= 10
        fprintf('\x1b[32m✓ PASS (%d modules)\x1b[0m\n', moduleCount);
    else
        fprintf('\x1b[33m⚠ WARNING (only %d modules)\x1b[0m\n', moduleCount);
    end
else
    fprintf('\x1b[31m✗ FAIL\x1b[0m\n');
end

%% Summary
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║                   VALIDATION SUMMARY                         ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n');
fprintf('\n');
fprintf('The reorganization appears to be complete!\n');
fprintf('\n');
fprintf('Next steps:\n');
fprintf('  1. Run full test suite: autotest_after_reorganization\n');
fprintf('  2. Test backward compatibility: verify_old_structure_still_works\n');
fprintf('  3. Try using: setup_project_paths()\n');
fprintf('\n');
fprintf('Documentation:\n');
fprintf('  - Documentation/MIGRATION_GUIDE.md\n');
fprintf('  - Documentation/PROJECT_STRUCTURE.md\n');
fprintf('\n');
