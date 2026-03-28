clear; clc;

try
    repoRoot = 'C:/Dev/matlab-functions';
    manifestHint = 'run_manifest.json'; %#ok<NASGU>

    tablesDir = fullfile(repoRoot, 'tables');
    reportsDir = fullfile(repoRoot, 'reports');
    if ~exist(tablesDir, 'dir')
        mkdir(tablesDir);
    end
    if ~exist(reportsDir, 'dir')
        mkdir(reportsDir);
    end

    % Use explicit namespace naming; never use plain R.
    R_relax = [1; 2; 3]; %#ok<NASGU>

    T = table([1;2;3], [4;5;6], 'VariableNames', {'A','B'});
    writetable(T, fullfile(repoRoot, 'tables', 'minimal_test.csv'));

    fid = fopen(fullfile(repoRoot, 'reports', 'minimal_test.md'),'w');
    if fid == -1
        error('FileOpenFailed:Report', 'Could not open report file for writing.');
    end
    fprintf(fid, 'Minimal run success\n');
    fclose(fid);

    status = table({'SUCCESS'}, {'YES'}, {''}, 3, {'minimal table/report written'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(status, fullfile(repoRoot, 'reports', 'minimal_status.csv'));
catch ME
    try
        repoRoot = 'C:/Dev/matlab-functions';
        reportsDir = fullfile(repoRoot, 'reports');
        if ~exist(reportsDir, 'dir')
            mkdir(reportsDir);
        end

        fid = fopen(fullfile(repoRoot, 'reports', 'minimal_test.md'),'w');
        if fid ~= -1
            fprintf(fid, 'Minimal run failure: %s\n', ME.message);
            fclose(fid);
        end

        status = table({'FAIL'}, {'NO'}, {ME.message}, 0, {'execution failed'}, ...
            'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
        writetable(status, fullfile(repoRoot, 'reports', 'minimal_status.csv'));
    catch
        % Intentionally no rethrow to keep script non-crashing in wrapper context.
    end
end
