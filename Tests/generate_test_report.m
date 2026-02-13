function generate_test_report(results, outputDir)
%GENERATE_TEST_REPORT Generate test reports in multiple formats
%
%   generate_test_report(results, outputDir)
%
%   Inputs:
%       results - Array of test result structures
%       outputDir - Directory to save reports (default: current directory)

    if nargin < 2
        outputDir = pwd;
    end
    
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    %% Calculate Statistics
    totalTests = length(results);
    passedTests = sum([results.passed]);
    failedTests = totalTests - passedTests;
    totalDuration = sum([results.duration]);
    
    %% Generate Text Summary
    summaryFile = fullfile(outputDir, 'TEST_RESULTS_SUMMARY.txt');
    fid = fopen(summaryFile, 'w');
    
    fprintf(fid, '===========================================\n');
    fprintf(fid, '  MATLAB PROJECT TEST RESULTS SUMMARY\n');
    fprintf(fid, '===========================================\n\n');
    fprintf(fid, 'Date: %s\n', datestr(now));
    fprintf(fid, 'Total Tests: %d\n', totalTests);
    fprintf(fid, 'Passed: %d\n', passedTests);
    fprintf(fid, 'Failed: %d\n', failedTests);
    fprintf(fid, 'Success Rate: %.1f%%\n', (passedTests/totalTests)*100);
    fprintf(fid, 'Total Duration: %.2f seconds\n\n', totalDuration);
    
    fprintf(fid, '-------------------------------------------\n');
    fprintf(fid, 'Individual Test Results:\n');
    fprintf(fid, '-------------------------------------------\n\n');
    
    for i = 1:length(results)
        status = '✓ PASS';
        if ~results(i).passed
            status = '✗ FAIL';
        end
        fprintf(fid, '[%s] %s (%.2fs)\n', status, results(i).name, results(i).duration);
        if ~results(i).passed
            fprintf(fid, '     Message: %s\n', results(i).message);
        end
    end
    
    fprintf(fid, '\n===========================================\n');
    if failedTests == 0
        fprintf(fid, '✓ ALL TESTS PASSED!\n');
    else
        fprintf(fid, '✗ %d TEST(S) FAILED\n', failedTests);
    end
    fprintf(fid, '===========================================\n');
    
    fclose(fid);
    
    %% Generate HTML Report
    htmlFile = fullfile(outputDir, 'test_results.html');
    fid = fopen(htmlFile, 'w');
    
    fprintf(fid, '<!DOCTYPE html>\n');
    fprintf(fid, '<html>\n<head>\n');
    fprintf(fid, '<title>MATLAB Project Test Results</title>\n');
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }\n');
    fprintf(fid, '.container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }\n');
    fprintf(fid, 'h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }\n');
    fprintf(fid, '.summary { background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }\n');
    fprintf(fid, '.stats { display: flex; justify-content: space-around; margin: 20px 0; }\n');
    fprintf(fid, '.stat-box { text-align: center; padding: 15px; background: white; border-radius: 5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }\n');
    fprintf(fid, '.stat-value { font-size: 32px; font-weight: bold; color: #4CAF50; }\n');
    fprintf(fid, '.stat-label { color: #666; margin-top: 5px; }\n');
    fprintf(fid, 'table { width: 100%%; border-collapse: collapse; margin-top: 20px; }\n');
    fprintf(fid, 'th { background: #4CAF50; color: white; padding: 12px; text-align: left; }\n');
    fprintf(fid, 'td { padding: 10px; border-bottom: 1px solid #ddd; }\n');
    fprintf(fid, 'tr:hover { background: #f5f5f5; }\n');
    fprintf(fid, '.pass { color: #4CAF50; font-weight: bold; }\n');
    fprintf(fid, '.fail { color: #f44336; font-weight: bold; }\n');
    fprintf(fid, '.error-msg { color: #666; font-size: 0.9em; font-style: italic; }\n');
    fprintf(fid, '</style>\n');
    fprintf(fid, '</head>\n<body>\n');
    fprintf(fid, '<div class="container">\n');
    fprintf(fid, '<h1>MATLAB Project Test Results</h1>\n');
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Test Date:</strong> %s</p>\n', datestr(now));
    fprintf(fid, '</div>\n');
    
    fprintf(fid, '<div class="stats">\n');
    fprintf(fid, '<div class="stat-box"><div class="stat-value">%d</div><div class="stat-label">Total Tests</div></div>\n', totalTests);
    fprintf(fid, '<div class="stat-box"><div class="stat-value" style="color:#4CAF50;">%d</div><div class="stat-label">Passed</div></div>\n', passedTests);
    fprintf(fid, '<div class="stat-box"><div class="stat-value" style="color:#f44336;">%d</div><div class="stat-label">Failed</div></div>\n', failedTests);
    fprintf(fid, '<div class="stat-box"><div class="stat-value">%.1f%%</div><div class="stat-label">Success Rate</div></div>\n', (passedTests/totalTests)*100);
    fprintf(fid, '</div>\n');
    
    fprintf(fid, '<table>\n');
    fprintf(fid, '<tr><th>Test Name</th><th>Status</th><th>Duration</th><th>Message</th></tr>\n');
    
    for i = 1:length(results)
        if results(i).passed
            statusClass = 'pass';
            statusText = '✓ PASS';
        else
            statusClass = 'fail';
            statusText = '✗ FAIL';
        end
        
        fprintf(fid, '<tr>\n');
        fprintf(fid, '  <td>%s</td>\n', results(i).name);
        fprintf(fid, '  <td class="%s">%s</td>\n', statusClass, statusText);
        fprintf(fid, '  <td>%.2fs</td>\n', results(i).duration);
        fprintf(fid, '  <td class="error-msg">%s</td>\n', strrep(results(i).message, 'FAILED: ', ''));
        fprintf(fid, '</tr>\n');
    end
    
    fprintf(fid, '</table>\n');
    fprintf(fid, '</div>\n');
    fprintf(fid, '</body>\n</html>\n');
    
    fclose(fid);
    
    %% Generate Log File
    logFile = fullfile(outputDir, 'test_log.txt');
    fid = fopen(logFile, 'w');
    
    fprintf(fid, 'MATLAB Project Test Log\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));
    
    for i = 1:length(results)
        fprintf(fid, '========================================\n');
        fprintf(fid, 'Test: %s\n', results(i).name);
        fprintf(fid, 'Status: %s\n', results(i).message);
        fprintf(fid, 'Duration: %.2f seconds\n', results(i).duration);
        fprintf(fid, '========================================\n\n');
    end
    
    fclose(fid);
    
    fprintf('\n✓ Reports generated:\n');
    fprintf('  - %s\n', summaryFile);
    fprintf('  - %s\n', htmlFile);
    fprintf('  - %s\n', logFile);
end
