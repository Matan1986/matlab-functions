function writeRunValidityClassification(runDir, repoRoot, enforcement_checked, modules_used, switchingIsolated)
%WRITERUNVALIDITYCLASSIFICATION Detection-only: writes run_dir/run_validity.txt (never throws).
%
% Classification is informational; it does not block or alter execution outcomes.

if nargin < 5
    switchingIsolated = false;
end

try
    rd = char(string(runDir));
    rr = char(string(repoRoot));

    if isempty(strtrim(rd)) || exist(rd, 'dir') ~= 7
        % Cannot write run_validity.txt without a run directory.
        return;
    end

    esPath = fullfile(rd, 'execution_status.csv');
    if exist(esPath, 'file') ~= 2
        wsvc_writeFile(rd, 'INVALID', 'Missing execution_status.csv');
        return;
    end

    createOk = false;
    if ~isempty(strtrim(rr))
        expectedCreateRunContextPath = fullfile(rr, 'Aging', 'utils', 'createRunContext.m');
        expectedCreateRunContext = lower(strrep(expectedCreateRunContextPath, '/', '\'));
        resolvedCreateRunContext = lower(strrep(which('createRunContext'), '/', '\'));
        createOk = ~isempty(resolvedCreateRunContext) && strcmp(resolvedCreateRunContext, expectedCreateRunContext);
    end

    if isempty(modules_used)
        modList = {};
    elseif iscell(modules_used)
        modList = modules_used;
    else
        modList = cellstr(string(modules_used));
    end
    nmod = numel(modList);
    modulesEnforcedOk = (nmod <= 1) || logical(enforcement_checked);

    canonical = createOk && switchingIsolated && logical(enforcement_checked) && modulesEnforcedOk;

    if canonical
        wsvc_writeFile(rd, 'CANONICAL', 'All canonical conditions satisfied');
        return;
    end

    parts = strings(0, 1);
    if ~createOk
        parts(end+1) = "unexpected createRunContext path resolution";
    end
    if ~switchingIsolated
        parts(end+1) = "run not clearly switching-isolated";
    end
    if ~logical(enforcement_checked)
        parts(end+1) = "enforcement_checked false (module enforcement not fully evaluated)";
    end
    if nmod > 1 && ~logical(enforcement_checked)
        parts(end+1) = "modules_used not enforced";
    end
    if isempty(parts)
        parts = "deviation from canonical run profile";
    end
    wsvc_writeFile(rd, 'NON_CANONICAL', char(strjoin(parts, '; ')));

catch %#ok<CTCH>
    % Intentionally silent: validity layer must never block or fail the run.
end

end

function wsvc_writeFile(rd, validity, reason)
try
    thisFile = mfilename('fullpath');
    utilsDir = fileparts(thisFile);
    switchingDir = fileparts(utilsDir);
    repoRootWsvc = fileparts(switchingDir);
    toolsDirWsvc = fullfile(repoRootWsvc, 'tools');
    if exist(fullfile(toolsDirWsvc, 'atomic_commit_file.m'), 'file') == 2
        addpath(toolsDirWsvc);
    end

    p = fullfile(rd, 'run_validity.txt');
    tmpPath = [p '.tmp'];
    fid = fopen(tmpPath, 'w');
    if fid < 0
        return;
    end
    c = reason;
    c = strrep(strrep(strrep(char(string(c)), sprintf('\n'), ' '), char(13), ' '), '"', '''');
    fprintf(fid, 'RUN_VALIDITY=%s\n', char(string(validity)));
    fprintf(fid, 'REASON=%s\n', c);
    fclose(fid);
    atomic_commit_file(tmpPath, p);
catch %#ok<CTCH>
end
end
