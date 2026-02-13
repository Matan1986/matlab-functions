function result = run_test(testName, testFunc)
%RUN_TEST Execute a single test and return results
%
%   result = run_test(testName, testFunc)
%
%   Inputs:
%       testName - String name of the test
%       testFunc - Function handle to execute
%
%   Outputs:
%       result - Structure with fields:
%           .name - Test name
%           .passed - Boolean indicating pass/fail
%           .message - Success or error message
%           .duration - Execution time in seconds

    result.name = testName;
    result.passed = false;
    result.message = '';
    result.duration = 0;
    
    fprintf('  Running: %s ... ', testName);
    
    startTime = tic;
    try
        testFunc();
        result.passed = true;
        result.message = 'PASSED';
        result.duration = toc(startTime);
        fprintf('\x1b[32m✓ PASS\x1b[0m (%.2fs)\n', result.duration);
    catch ME
        result.passed = false;
        result.message = sprintf('FAILED: %s', ME.message);
        result.duration = toc(startTime);
        fprintf('\x1b[31m✗ FAIL\x1b[0m (%.2fs)\n', result.duration);
        fprintf('    Error: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('    Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end
end
