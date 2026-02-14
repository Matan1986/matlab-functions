function run_all_smoke_tests()
% Run all smoke tests for main entry scripts
% Returns success status and prints summary

    fprintf('===========================================\n');
    fprintf('Running Smoke Tests for Main Entry Scripts\n');
    fprintf('===========================================\n\n');
    
    % Add tests directory to path
    addpath(fullfile(pwd, 'tests'));
    
    % List of all smoke test functions
    tests = {
        'test_smoke_ACHC'
        'test_smoke_ACHC_RH'
        'test_smoke_Aging'
        'test_smoke_FieldSweep'
        'test_smoke_HC'
        'test_smoke_MH'
        'test_smoke_MT'
        'test_smoke_PS'
        'test_smoke_Relaxation'
        'test_smoke_Resistivity'
        'test_smoke_Susceptibility'
        'test_smoke_Switching'
        'test_smoke_zfAMR'
        'test_smoke_FinalFigureFormatterUI'
        'test_smoke_SmartFigureEngine'
    };
    
    passed = 0;
    failed = 0;
    failed_tests = {};
    
    % Run each test
    for i = 1:length(tests)
        test_name = tests{i};
        fprintf('\n[%d/%d] Running %s...\n', i, length(tests), test_name);
        
        try
            % Call the test function
            feval(test_name);
            passed = passed + 1;
        catch ME
            failed = failed + 1;
            failed_tests{end+1} = test_name; %#ok<AGROW>
            fprintf('✗ FAILED: %s\n', ME.message);
        end
    end
    
    % Print summary
    fprintf('\n===========================================\n');
    fprintf('Test Summary\n');
    fprintf('===========================================\n');
    fprintf('Total tests:  %d\n', length(tests));
    fprintf('Passed:       %d\n', passed);
    fprintf('Failed:       %d\n', failed);
    
    if failed > 0
        fprintf('\nFailed tests:\n');
        for i = 1:length(failed_tests)
            fprintf('  - %s\n', failed_tests{i});
        end
    end
    
    fprintf('\n');
    
    if failed == 0
        fprintf('✓ All smoke tests passed!\n');
    else
        fprintf('✗ Some tests failed. See details above.\n');
    end
    
    fprintf('===========================================\n');
end
