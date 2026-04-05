function dirPath = resolve_results_input_dir(repoRoot, experiment, analysisName)
% resolve_results_input_dir Resolve the latest run-scoped analysis dir.

if nargin < 3
    error('resolve_results_input_dir requires repoRoot, experiment, and analysisName.');
end

repoRoot = char(string(repoRoot));
experiment = char(string(experiment));
analysisName = char(string(analysisName));

runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
dirPath = '';

if exist(runsRoot, 'dir') == 7
    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    if ~isempty(runDirs)
        [~, order] = sort({runDirs.name});
        runDirs = runDirs(order);
        for i = numel(runDirs):-1:1
            runDir = fullfile(runsRoot, runDirs(i).name);
            [runStatus, ~] = get_run_status_value(runDir);
            if runStatus == "PARTIAL"
                error('PARTIAL_RUN_NOT_ALLOWED');
            end
            if runStatus ~= "CANONICAL"
                continue;
            end
            candidate = fullfile(runDir, analysisName);
            if exist(candidate, 'dir') == 7
                dirPath = candidate;
                return;
            end
        end
    end
end

error('No run-scoped results directory found for %s/%s under %s.', experiment, analysisName, runsRoot);
end
