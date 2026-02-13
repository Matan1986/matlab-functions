function autotest_after_reorganization()
%AUTOTEST_AFTER_REORGANIZATION Main entry point for testing reorganization
%
%   This is the ONE command users run to test everything.
%
%   Usage:
%       autotest_after_reorganization
%
%   This script:
%   1. Runs all tests in sequence
%   2. Generates colored console output (green=PASS, red=FAIL)
%   3. Creates TEST_RESULTS_SUMMARY.txt with detailed results
%   4. Creates HTML report (test_results.html)
%   5. Creates detailed log file (test_log.txt)
%   6. Reports overall status

    clc;
    
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                                                              ║\n');
    fprintf('║    MATLAB PROJECT REORGANIZATION - AUTOMATED TEST SUITE     ║\n');
    fprintf('║                                                              ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('Starting comprehensive test suite...\n');
    fprintf('This will verify:\n');
    fprintf('  ✓ Project structure reorganization\n');
    fprintf('  ✓ Path management and backward compatibility\n');
    fprintf('  ✓ Module functionality\n');
    fprintf('  ✓ Data pipelines\n');
    fprintf('  ✓ Cloud storage integration\n');
    fprintf('  ✓ GUI availability\n');
    fprintf('\n');
    
    %% Find project root and setup
    projectRoot = find_project_root_auto();
    if isempty(projectRoot)
        error('Cannot find project root. Please run from within the project directory.');
    end
    
    fprintf('Project Root: %s\n', projectRoot);
    fprintf('\n');
    
    %% Change to Tests directory
    testsDir = fullfile(projectRoot, 'Tests');
    if ~exist(testsDir, 'dir')
        error('Tests directory not found. Please run from the project root.');
    end
    
    originalDir = pwd;
    cd(testsDir);
    
    try
        %% Run all tests
        startTime = tic;
        results = run_all_tests();
        totalTime = toc(startTime);
        
        %% Generate reports
        fprintf('\n');
        fprintf('Generating test reports...\n');
        generate_test_report(results, projectRoot);
        
        %% Print final summary
        fprintf('\n');
        fprintf('╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║                       FINAL RESULTS                          ║\n');
        fprintf('╚══════════════════════════════════════════════════════════════╝\n');
        fprintf('\n');
        
        totalTests = length(results);
        passedTests = sum([results.passed]);
        failedTests = totalTests - passedTests;
        
        fprintf('Total Execution Time: %.2f seconds\n', totalTime);
        fprintf('Total Tests:          %d\n', totalTests);
        fprintf('Passed:               \x1b[32m%d\x1b[0m\n', passedTests);
        fprintf('Failed:               \x1b[31m%d\x1b[0m\n', failedTests);
        fprintf('\n');
        
        if failedTests == 0
            fprintf('\x1b[32m');
            fprintf('╔══════════════════════════════════════════════════════════════╗\n');
            fprintf('║                                                              ║\n');
            fprintf('║                  ✓ ALL TESTS PASSED!                        ║\n');
            fprintf('║                                                              ║\n');
            fprintf('║  The project reorganization was successful!                  ║\n');
            fprintf('║  All functionality verified and backward compatible.         ║\n');
            fprintf('║                                                              ║\n');
            fprintf('╚══════════════════════════════════════════════════════════════╝\n');
            fprintf('\x1b[0m');
        else
            fprintf('\x1b[31m');
            fprintf('╔══════════════════════════════════════════════════════════════╗\n');
            fprintf('║                                                              ║\n');
            fprintf('║                  ✗ %d FAILURE(S) FOUND                      ║\n', failedTests);
            fprintf('║                                                              ║\n');
            fprintf('║  Please review the test results and fix the issues.          ║\n');
            fprintf('║                                                              ║\n');
            fprintf('╚══════════════════════════════════════════════════════════════╝\n');
            fprintf('\x1b[0m');
            
            fprintf('\nFailed tests:\n');
            for i = 1:length(results)
                if ~results(i).passed
                    fprintf('  - %s\n', results(i).name);
                end
            end
        end
        
        fprintf('\n');
        fprintf('Reports saved to:\n');
        fprintf('  - TEST_RESULTS_SUMMARY.txt\n');
        fprintf('  - test_results.html\n');
        fprintf('  - test_log.txt\n');
        fprintf('\n');
        
        %% Restore directory
        cd(originalDir);
        
    catch ME
        cd(originalDir);
        fprintf('\x1b[31mError during test execution:\x1b[0m\n');
        fprintf('%s\n', ME.message);
        rethrow(ME);
    end
end

function projectRoot = find_project_root_auto()
    % Find project root automatically
    currentDir = pwd;
    
    for i = 1:10
        if exist(fullfile(currentDir, 'README.md'), 'file')
            projectRoot = currentDir;
            return;
        end
        
        if exist(fullfile(currentDir, '.git'), 'dir')
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
