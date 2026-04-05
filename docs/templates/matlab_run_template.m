% Execution signaling contract:
% - execution_probe_top.txt is proof of script entry.
% - execution_probe_bottom.txt is proof of completion and is optional but recommended.
% - execution_status.csv is a mandatory artifact.
% Scripts that do not emit execution signals are considered non-executed,
% even if MATLAB exits successfully.

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(scriptDir));
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'template_run';

try
    run = createRunContext('aging', cfg);

    tablesDir = fullfile(run.run_dir, 'tables');
    reportsDir = fullfile(run.run_dir, 'reports');
    figuresDir = fullfile(run.run_dir, 'figures');

    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer < 0
        error('Template:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    resultTbl = table((1:5)', ((1:5)'.^2), 'VariableNames', {'x', 'x_squared'});
    resultCsvPath = fullfile(tablesDir, 'template_result.csv');
    writetable(resultTbl, resultCsvPath);

    fig = figure('Visible', 'off');
    plot(resultTbl.x, resultTbl.x_squared, 'o-', 'LineWidth', 1.5);
    xlabel('x');
    ylabel('x^2');
    title('Template Diagnostic');
    grid on;
    figurePath = fullfile(figuresDir, 'template_diagnostic.png');
    exportgraphics(fig, figurePath, 'Resolution', 300);
    close(fig);

    figuresManifest = table({figurePath}, {'template_diagnostic'}, {'PNG'}, ...
        'VariableNames', {'figure_path', 'figure_name', 'figure_format'});
    figuresManifestPath = fullfile(run.run_dir, 'figures_manifest.csv');
    writetable(figuresManifest, figuresManifestPath);

    reportPath = fullfile(reportsDir, 'report.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('Template:ReportWriteFailed', 'Failed to write report.md');
    end
    fprintf(fidReport, '# Run Report\n\n');
    fprintf(fidReport, '- STATUS: SUCCESS\n');
    fprintf(fidReport, '- RUN_DIR: %s\n', run.run_dir);
    fprintf(fidReport, '- RESULT_CSV: %s\n', resultCsvPath);
    fprintf(fidReport, '- FIGURE: %s\n', figurePath);
    fprintf(fidReport, '- FIGURES_MANIFEST: %s\n', figuresManifestPath);
    fclose(fidReport);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(resultTbl), {'template artifacts written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_template_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'template execution failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
