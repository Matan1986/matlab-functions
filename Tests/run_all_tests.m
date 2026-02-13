function results = run_all_tests()
%RUN_ALL_TESTS Main test orchestrator - runs all tests
%
%   results = run_all_tests()
%
%   Runs all tests in the test suite and returns results.
%
%   Returns:
%       results - Array of test result structures

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║    MATLAB PROJECT REORGANIZATION TEST SUITE           ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    
    %% Initialize results
    results = [];
    testCount = 0;
    
    %% Group 1: Path & Structure Verification
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('GROUP 1: Path & Structure Verification\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    testCount = testCount + 1;
    results(testCount) = run_test('verify_project_structure', @verify_project_structure);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_path_setup', @test_path_setup);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_old_paths_still_work', @test_old_paths_still_work);
    
    %% Group 2: Module Functionality
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('GROUP 2: Module Functionality Tests\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_module_imports', @test_module_imports);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_helper_functions', @test_helper_functions);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_main_scripts_syntax', @test_main_scripts_syntax);
    
    %% Group 3: Data Pipeline Tests
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('GROUP 3: Data Pipeline Tests\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_complete_aging_pipeline', @test_complete_aging_pipeline);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_complete_mt_pipeline', @test_complete_mt_pipeline);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_complete_fieldsweep_pipeline', @test_complete_fieldsweep_pipeline);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_complete_relaxation_pipeline', @test_complete_relaxation_pipeline);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_complete_hc_pipeline', @test_complete_hc_pipeline);
    
    %% Group 4: Cloud Storage Tests
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('GROUP 4: Cloud Storage Path Tests\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_google_drive_paths', @test_google_drive_paths);
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_network_paths', @test_network_paths);
    
    %% Group 5: GUI Tests
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('GROUP 5: GUI Initialization Tests\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    testCount = testCount + 1;
    results(testCount) = run_test('test_gui_launch', @test_gui_launch);
    
    %% Print Summary
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║                    TEST SUMMARY                        ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    
    totalTests = length(results);
    passedTests = sum([results.passed]);
    failedTests = totalTests - passedTests;
    
    fprintf('Total Tests:  %d\n', totalTests);
    fprintf('Passed:       \x1b[32m%d\x1b[0m\n', passedTests);
    fprintf('Failed:       \x1b[31m%d\x1b[0m\n', failedTests);
    fprintf('Success Rate: %.1f%%\n', (passedTests/totalTests)*100);
    
    fprintf('\n');
    if failedTests == 0
        fprintf('\x1b[32m✓ ALL TESTS PASSED!\x1b[0m\n');
    else
        fprintf('\x1b[31m✗ %d TEST(S) FAILED\x1b[0m\n', failedTests);
    end
    fprintf('\n');
end
